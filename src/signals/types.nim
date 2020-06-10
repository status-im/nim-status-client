import json
import chronicles
import ../status/libstatus/types
import json_serialization

type SignalSubscriber* = ref object of RootObj

type Signal* = ref object of RootObj
  signalType* {.serializedFieldName("type").}: SignalType

type StatusGoError* = object
  error*: string

type NodeSignal* = ref object of Signal
  event*: StatusGoError

type WalletSignal* = ref object of Signal
  content*: string

type ContentType* {.pure.} = enum
  ChatIdentifier = -1,
  Unknown = 0,
  Message = 1,
  Sticker = 2,
  Status = 3,
  Emoji = 4,
  Transaction = 5,
  Group = 6

type Message* = object
  alias*: string
  chatId*: string
  clock*: int
  # commandParameters*:   # ???
  contentType*: ContentType      # ???
  ensName*: string        # ???
  fromAuthor*: string
  id*: string
  identicon*: string
  lineCount*: int
  localChatId*: string
  messageType*: string    # ???
  # parsedText:          # ???
  # quotedMessage:       # ???
  replace*: string        # ???
  responseTo*: string     # ???
  rtl*: bool              # ???
  seen*: bool
  # sticker:             # ???
  text*: string
  timestamp*: string
  whisperTimestamp*: string
  isCurrentUser*: bool
  stickerHash*: string

# Override this method
method onSignal*(self: SignalSubscriber, data: Signal) {.base.} =
  error "onSignal must be overriden in controller. Signal is unhandled"

type ChatType* {.pure.}= enum
  Unknown = 0,
  OneToOne = 1, 
  Public = 2,
  PrivateGroupChat = 3

proc isOneToOne*(self: ChatType): bool = self == ChatType.OneToOne

type ChatMember* = object
  admin*: bool
  id*: string
  joined*: bool

type Chat* = ref object
  id*: string # ID is the id of the chat, for public chats it is the name e.g. status, for one-to-one is the hex encoded public key and for group chats is a random uuid appended with the hex encoded pk of the creator of the chat
  name*: string
  color*: string
  identicon*: string
  active*: bool # indicates whether the chat has been soft deleted
  chatType*: ChatType
  timestamp*: int64 # indicates the last time this chat has received/sent a message
  lastClockValue*: int64 # indicates the last clock value to be used when sending messages
  deletedAtClockValue*: int64 # indicates the clock value at time of deletion, messages with lower clock value of this should be discarded
  unviewedMessagesCount*: int
  lastMessage*: Message
  members*: seq[ChatMember]
  # membershipUpdateEvents # ?

type MessageSignal* = ref object of Signal
  messages*: seq[Message]
  chats*: seq[Chat]
  
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

proc findIndexById*(self: seq[Chat], id: string): int =
  result = -1
  var idx = -1
  for item in self:
    inc idx
    if(item.id == id):
      result = idx
      break

proc isMember*(self: Chat, pubKey: string): bool =
  for member in self.members:
    if member.id == pubKey and member.joined: return true
  return false

