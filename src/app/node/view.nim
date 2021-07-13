import NimQml, chronicles, strutils, json
import ../../status/[status, node, types, settings, accounts]

logScope:
  topics = "node-view"

QtObject:
  type NodeView* = ref object of QObject
    status*: Status
    callResult: string
    lastMessage*: string
    wakuBloomFilterMode*: bool

  proc setup(self: NodeView) =
    self.QObject.setup

  proc newNodeView*(status: Status): NodeView =
    new(result)
    result.status = status
    result.callResult = "Use this tool to call JSONRPC methods"
    result.lastMessage = ""
    result.wakuBloomFilterMode = false
    result.setup

  proc delete*(self: NodeView) =
    self.QObject.delete

  proc callResult*(self: NodeView): string {.slot.} =
    result = self.callResult

  proc callResultChanged*(self: NodeView, callResult: string) {.signal.}

  proc setCallResult(self: NodeView, callResult: string) {.slot.} =
    if self.callResult == callResult: return
    self.callResult = callResult
    self.callResultChanged(callResult)

  proc `callResult=`*(self: NodeView, callResult: string) = self.setCallResult(callResult)

  QtProperty[string] callResult:
    read = callResult
    write = setCallResult
    notify = callResultChanged

  proc onSend*(self: NodeView, inputJSON: string) {.slot.} =
    self.setCallResult(self.status.node.sendRPCMessageRaw(inputJSON))
    echo "Done!: ", self.callResult

  proc onMessage*(self: NodeView, message: string) {.slot.} =
    self.setCallResult(message)
    echo "Received message: ", message

  proc lastMessage*(self: NodeView): string {.slot.} =
    result = self.lastMessage

  proc receivedMessage*(self: NodeView, lastMessage: string) {.signal.}

  proc setLastMessage*(self: NodeView, lastMessage: string) {.slot.} =
    self.lastMessage = lastMessage
    self.receivedMessage(lastMessage)

  QtProperty[string] lastMessage:
    read = lastMessage
    write = setLastMessage
    notify = receivedMessage

  proc initialized(self: NodeView) {.signal.}

  proc getWakuBloomFilterMode*(self: NodeView): bool {.slot.} =
    result = self.wakuBloomFilterMode

  QtProperty[bool] wakuBloomFilterMode:
    read = getWakuBloomFilterMode
    notify = receivedMessage

  proc setWakuBloomFilterMode*(self: NodeView, bloomFilterMode: bool) {.slot.} =
    discard self.status.settings.saveSetting(Setting.WakuBloomFilterMode, bloomFilterMode)
    var fleetStr = self.status.settings.getSetting[:string](Setting.Fleet)
    let fleet = if fleetStr == "": Fleet.PROD else: parseEnum[Fleet](fleetStr)
    let installationId = self.status.settings.getSetting[:string](Setting.InstallationId)
    let updatedNodeConfig = self.status.accounts.getNodeConfig(self.status.fleet.config, installationId, $self.status.settings.getCurrentNetwork(), fleet, bloomFilterMode)    
    discard self.status.settings.saveSetting(Setting.NodeConfig, updatedNodeConfig)
    quit(QuitSuccess) # quits the app TODO: change this to logout instead when supported

  proc init*(self: NodeView) {.slot.} =
    self.wakuBloomFilterMode = self.status.settings.getSetting[:bool](Setting.WakuBloomFilterMode)



