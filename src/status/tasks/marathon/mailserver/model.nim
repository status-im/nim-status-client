import
  algorithm, chronos, chronicles, json, math, os, random, sequtils, sets, sugar,
  tables
from times import cpuTime

import
  ../../../libstatus/settings as status_settings,
  ../../../libstatus/mailservers as status_mailservers,
  ../../../libstatus/core as status_core, ../../../libstatus/chat as status_chat,
  ../../../libstatus/types, ../../../fleet,
  ./events as mailserver_events

logScope:
  topics = "mailserver model"

################################################################################
##                                                                            ##
## NOTE: MailserverModel runs on a separate (long-running) thread             ##
##                                                                            ##
## How do mailservers work ?                                                  ##
##                                                                            ##
## - We send a request to the mailserver, we are only interested in the       ##
##   messages since `last-request` up to the last seven days                  ##
##   and the last 24 hours for topics that were just joined                   ##
## - The mailserver doesn't directly respond to the request and               ##
##   instead we start receiving messages in the filters for the requested     ##
##   topics.                                                                  ##
## - If the mailserver was not ready when we tried for instance to request    ##
##   the history of a topic after joining a chat, the request will be done    ##
##   as soon as the mailserver becomes available                              ##
##                                                                            ##
################################################################################
type
  MailserverModel* = ref object
    mailservers*: seq[string]
    events*: MailserverEvents
    nodes*: Table[string, MailserverStatus]
    activeMailserver*: string
    lastConnectionAttempt*: float
    fleet*: FleetModel

  MailserverStatus* = enum
    Unknown = -1,
    Disconnected = 0,
    Connecting = 1
    Connected = 2, 

proc cmpMailserverReply(x, y: (string, int)): int =
  if x[1] > y[1]: 1
  elif x[1] == y[1]: 0
  else: -1

proc poolSize(fleetSize: int): int = ceil(fleetSize / 4).int

proc newMailserverModel*(vptr: ByteAddress): MailserverModel =
  result = MailserverModel()
  result.events = newMailserverEvents(vptr)
  result.nodes = initTable[string, MailserverStatus]()
  result.activeMailserver = ""

proc init*(self: MailserverModel) =
  trace "MailserverModel::init()"
  let fleets =
    if defined(windows) and defined(production):
      "/../resources/fleets.json"
    else:
      "/../fleets.json"
  let fleetConfig = readFile(joinPath(getAppDir(), fleets))
  self.fleet = newFleetModel(fleetConfig)
  self.mailservers = toSeq(self.fleet.config.getMailservers(status_settings.getFleet()).values)
  for mailserver in status_settings.getMailservers().getElems():
    self.mailservers.add(mailserver["address"].getStr())

proc getActiveMailserver*(self: MailserverModel): string = self.activeMailserver

proc isActiveMailserverAvailable*(self: MailserverModel): bool =
  if not self.nodes.hasKey(self.activeMailserver): 
    result = false
  else:
    result = self.nodes[self.activeMailserver] == MailserverStatus.Connected

proc connect(self: MailserverModel, enode: string) =
  debug "Connecting to mailserver", enode=enode.substr[enode.len-40..enode.len-1]
  var connected = false
  # TODO: this should come from settings
  var knownMailservers = initHashSet[string]()
  for m in self.mailservers:
    knownMailservers.incl m
  if not knownMailservers.contains(enode): 
    warn "Mailserver not known", enode
    return

  self.activeMailserver = enode
  self.events.emit("mailserver:changed", MailserverArgs(peer: enode))

  # Adding a peer and marking it as connected can't be executed sync, because
  # There's a delay between requesting a peer being added, and a signal being 
  # received after the peer was added. So we first set the peer status as 
  # Connecting and once a peerConnected signal is received, we mark it as 
  # Connected

  if self.nodes.hasKey(enode) and self.nodes[enode] == MailserverStatus.Connected:
    connected = true
  else:
    # Attempt to connect to mailserver by adding it as a peer
    status_mailservers.update(enode)
    self.nodes[enode] = MailserverStatus.Connecting
    self.lastConnectionAttempt = cpuTime()

  if connected:
    self.events.emit("mailserverAvailable", MailserverArgs())

proc peerSummaryChange*(self: MailserverModel, peers: seq[string]) =
  # When a node is added as a peer, or disconnected
  # a DiscoverySummary signal is emitted. In here we
  # change the status of the nodes the app is connected to
  # Connected / Disconnected and emit peerConnected / peerDisconnected
  # events.

  var mailserverAvailable = false
  for knownPeer in self.nodes.keys:
    if not peers.contains(knownPeer) and self.nodes[knownPeer] != MailserverStatus.Disconnected: 
      debug "Peer disconnected", peer=knownPeer
      self.nodes[knownPeer] = MailserverStatus.Disconnected
      self.events.emit("peerDisconnected", MailserverArgs(peer: knownPeer))
      if self.activeMailserver == knownPeer:
        warn "Active mailserver disconnected!", peer = knownPeer
        self.activeMailserver = ""
  
  for peer in peers:
    if self.nodes.hasKey(peer) and (self.nodes[peer] == MailserverStatus.Connected): continue
    debug "Peer connected", peer
    self.nodes[peer] = MailserverStatus.Connected
    self.events.emit("peerConnected", MailserverArgs(peer: peer))

    if peer == self.activeMailserver:
      if self.nodes.hasKey(self.activeMailserver):
        if self.activeMailserver == peer:
          mailserverAvailable = true
      
  if mailserverAvailable:
    debug "Mailserver available"
    self.events.emit("mailserverAvailable", MailserverArgs())

proc requestMessages*(self: MailserverModel) =
  debug "Requesting messages from", mailserver=self.activeMailserver
  discard status_mailservers.requestAllHistoricMessages()

proc requestStoreMessages*(self: MailserverModel, topics: seq[string], fromValue: int64 = 0, toValue: int64 = 0, force: bool = false) =
  debug "Requesting messages from", mailserver=self.activeMailserver
  let generatedSymKey = status_chat.generateSymKeyFromPassword()
  status_mailservers.requestStoreMessages(topics, generatedSymKey, self.activeMailserver, 1000, fromValue, toValue, force)

proc requestMoreMessages*(self: MailserverModel, chatId: string) =
  debug "Requesting more messages from", mailserver=self.activeMailserver, chatId=chatId
  discard status_mailservers.syncChatFromSyncedFrom(chatId)

proc findNewMailserver(self: MailserverModel) =
  warn "Finding a new mailserver..."
  
  let mailserversReply = parseJson(status_mailservers.ping(self.mailservers, 500))["result"]
  
  var availableMailservers:seq[(string, int)] = @[]
  for reply in mailserversReply: 
    if(reply["error"].kind != JNull): continue # The results with error are ignored
    availableMailservers.add((reply["address"].getStr, reply["rttMs"].getInt))
  availableMailservers.sort(cmpMailserverReply)

  # No mailservers where returned... do nothing.
  if availableMailservers.len == 0: return

  # Picks a random mailserver amongs the ones with the lowest latency
  # The pool size is 1/4 of the mailservers were pinged successfully
  randomize()

  let mailServer = availableMailservers[rand(poolSize(availableMailservers.len - 1))][0]

  self.connect(mailserver)

proc cycleMailservers(self: MailserverModel) =
  warn "Automatically switching mailserver"
  if self.activeMailserver != "":
    warn "Disconnecting active mailserver", peer=self.activeMailserver
    self.nodes[self.activeMailserver] = MailserverStatus.Disconnected
    removePeer(self.activeMailserver)
    self.activeMailserver = ""
  self.findNewMailserver()

proc checkConnection*(self: MailserverModel) {.async.} =
  while true:
    debug "Verifying mailserver connection state..."
    let pinnedMailserver = status_settings.getPinnedMailserver()
    if pinnedMailserver != "" and self.activeMailserver != pinnedMailserver:
      # connect to current mailserver from the settings
      self.mailservers.add(pinnedMailserver)
      self.connect(pinnedMailserver) 
    else:
      # or setup a random mailserver:
      if not self.isActiveMailserverAvailable:
        # TODO: have a timeout for reconnection before changing to a different server
        self.cycleMailservers()
    await sleepAsync(10.seconds)
