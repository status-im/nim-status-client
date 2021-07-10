import strformat, json, sequtils, tables
from message import Message
import ../types

type ChatType* {.pure.}= enum
  Unknown = 0,
  OneToOne = 1, 
  Public = 2,
  PrivateGroupChat = 3,
  Profile = 4,
  Timeline = 5
  CommunityChat = 6

type ActivityCenterNotificationType* {.pure.}= enum
  Unknown = 0,
  NewOneToOne = 1, 
  NewPrivateGroupChat = 2,
  Mention = 3
  Reply = 4

proc isOneToOne*(self: ChatType): bool = self == ChatType.OneToOne
proc isTimeline*(self: ChatType): bool = self == ChatType.Timeline

type ChatMember* = object
  admin*: bool
  id*: string
  joined*: bool
  identicon*: string
  userName*: string
  localNickname*: string

proc toJsonNode*(self: ChatMember): JsonNode =
  result = %* {
    "id": self.id,
    "admin": self.admin,
    "joined": self.joined
  }

proc toJsonNode*(self: seq[ChatMember]): seq[JsonNode] =
  result = map(self, proc(x: ChatMember): JsonNode = x.toJsonNode)

type ChatMembershipEvent* = object
  chatId*: string
  clockValue*: int64
  fromKey*: string
  name*: string
  members*: seq[string]
  rawPayload*: string
  signature*: string 
  eventType*: int

proc toJsonNode*(self: ChatMembershipEvent): JsonNode =
  result = %* {
    "chatId": self.chatId,
    "name": self.name,
    "clockValue": self.clockValue,
    "from": self.fromKey,
    "members": self.members,
    "rawPayload": self.rawPayload,
    "signature": self.signature,
    "type": self.eventType
  }

proc toJsonNode*(self: seq[ChatMembershipEvent]): seq[JsonNode] =
  result = map(self, proc(x: ChatMembershipEvent): JsonNode = x.toJsonNode)

type Chat* = ref object
  id*: string # ID is the id of the chat, for public chats it is the name e.g. status, for one-to-one is the hex encoded public key and for group chats is a random uuid appended with the hex encoded pk of the creator of the chat
  communityId*: string
  private*: bool
  categoryId*: string
  name*: string
  description*: string
  color*: string
  identicon*: string
  isActive*: bool # indicates whether the chat has been soft deleted
  chatType*: ChatType
  timestamp*: int64 # indicates the last time this chat has received/sent a message
  joined*: int64 # indicates when the user joined the chat last time
  lastClockValue*: int64 # indicates the last clock value to be used when sending messages
  deletedAtClockValue*: int64 # indicates the clock value at time of deletion, messages with lower clock value of this should be discarded
  unviewedMessagesCount*: int
  lastMessage*: Message
  members*: seq[ChatMember]
  membershipUpdateEvents*: seq[ChatMembershipEvent]
  mentionsCount*: int
  muted*: bool
  canPost*: bool
  ensName*: string

type CommunityAccessLevel* = enum
  unknown = 0
  public = 1
  invitationOnly = 2
  onRequest = 3

type CommunityMembershipRequest* = object
  id*: string
  publicKey*: string
  chatId*: string
  communityId*: string
  state*: int
  our*: string

type CommunityCategory* = object
  id*: string
  name*: string
  position*: int

type StatusUpdateType* {.pure.}= enum
  Unknown = 0,
  Online = 1, 
  DoNotDisturb = 2

type StatusUpdate* = object
  publicKey*: string
  statusType*: StatusUpdateType
  clock*: int64
  text*: string

type Community* = object
  id*: string
  name*: string
  lastChannelSeen*: string
  description*: string
  chats*: seq[Chat]
  categories*: seq[CommunityCategory]
  members*: seq[string]
  access*: int
  unviewedMessagesCount*: int
  admin*: bool
  joined*: bool
  verified*: bool
  ensOnly*: bool
  canRequestAccess*: bool
  canManageUsers*: bool
  canJoin*: bool
  isMember*: bool
  muted*: bool
  communityImage*: IdentityImage
  membershipRequests*: seq[CommunityMembershipRequest]
  communityColor*: string
  memberStatus*: OrderedTable[string, StatusUpdate]

type ActivityCenterNotification* = ref object of RootObj
  id*: string # ID is the id of the chat, for public chats it is the name e.g. status, for one-to-one is the hex encoded public key and for group chats is a random uuid appended with the hex encoded pk of the creator of the chat
  chatId*: string
  name*: string
  author*: string
  notificationType*: ActivityCenterNotificationType
  message*: Message
  timestamp*: int64
  read*: bool
  dismissed*: bool
  accepted*: bool

proc `$`*(self: Chat): string =
  result = fmt"Chat(id:{self.id}, name:{self.name}, active:{self.isActive}, type:{self.chatType})"

proc `$`*(self: Community): string =
  result = fmt"Community(id:{self.id}, name:{self.name}, description:{self.description}"

proc toJsonNode*(self: Chat): JsonNode =
  result = %* {
    "active": self.isActive,
    "chatType": self.chatType.int,
    "color": self.color,
    "deletedAtClockValue": self.deletedAtClockValue,
    "id": self.id,
    "lastClockValue": self.lastClockValue,
    "lastMessage": nil,
    "members": self.members.toJsonNode,
    "membershipUpdateEvents": self.membershipUpdateEvents.toJsonNode,
    "name": (if self.ensName != "": self.ensName else: self.name),
    "timestamp": self.timestamp,
    "unviewedMessagesCount": self.unviewedMessagesCount,
    "joined": self.joined
  }

proc findIndexById*(self: seq[Chat], id: string): int =
  result = -1
  var idx = -1
  for item in self:
    inc idx
    if(item.id == id):
      result = idx
      break

proc findIndexById*(self: seq[Community], id: string): int =
  result = -1
  var idx = -1
  for item in self:
    inc idx
    if(item.id == id):
      result = idx
      break

proc findIndexById*(self: seq[CommunityMembershipRequest], id: string): int =
  result = -1
  var idx = -1
  for item in self:
    inc idx
    if(item.id == id):
      result = idx
      break

proc findIndexById*(self: seq[CommunityCategory], id: string): int =
  result = -1
  var idx = -1
  for item in self:
    inc idx
    if(item.id == id):
      result = idx
      break

proc isMember*(self: Chat, pubKey: string): bool =
  for member in self.members:
    if member.id == pubKey:
      return member.joined
  return false

proc isMemberButNotJoined*(self: Chat, pubKey: string): bool =
  for member in self.members:
    if member.id == pubKey:
      return not member.joined
  return false

proc contains*(self: Chat, pubKey: string): bool =
  for member in self.members:
    if member.id == pubKey: return true
  return false

proc isAdmin*(self: Chat, pubKey: string): bool =
  for member in self.members:
    if member.id == pubKey:
      return member.joined and member.admin
  return false
