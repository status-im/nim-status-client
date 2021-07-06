import json, chronicles, json_serialization, tables
import ../types
import ../chat/[chat, message]
import ../profile/[profile, devices]
import ../../eventemitter

type Signal* = ref object of Args
  signalType* {.serializedFieldName("type").}: SignalType

type StatusGoError* = object
  error*: string

type NodeSignal* = ref object of Signal
  event*: StatusGoError

type WalletSignal* = ref object of Signal
  content*: string
  eventType*: string
  blockNumber*: int
  accounts*: seq[string]
  baseFeePerGas*: string
  # newTransactions*: ???
  erc20*: bool

type EnvelopeSentSignal* = ref object of Signal
  messageIds*: seq[string]

type EnvelopeExpiredSignal* = ref object of Signal
  messageIds*: seq[string]

type MessageSignal* = ref object of Signal
  messages*: seq[Message]
  pinnedMessages*: seq[Message]
  chats*: seq[Chat]
  contacts*: seq[Profile]
  installations*: seq[Installation]
  emojiReactions*: seq[Reaction]
  communities*: seq[Community]
  membershipRequests*: seq[CommunityMembershipRequest]
  activityCenterNotification*: seq[ActivityCenterNotification]

type CommunitySignal* = ref object of Signal
  community*: Community

type MailserverRequestCompletedSignal* = ref object of Signal
  requestID*: string
  lastEnvelopeHash*: string
  cursor*: string
  errorMessage*: string
  error*: bool
  
type MailserverRequestExpiredSignal* = ref object of Signal
  # TODO

type Filter* = object
  chatId*: string
  symKeyId*: string
  listen*: bool
  filterId*: string
  identity*: string
  topic*: string

type WhisperFilterSignal* = ref object of Signal
  filters*: seq[Filter]

type DiscoverySummarySignal* = ref object of Signal
  enodes*: seq[string]
