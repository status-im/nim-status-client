import NimQml, Tables, sets
import ../../../status/status
import ../../../status/accounts
import ../../../status/chat
import ../../../status/chat/[message,stickers]
import ../../../status/profile/profile
import ../../../status/ens
import strformat, strutils

type
  ChatMessageRoles {.pure.} = enum
    UserName = UserRole + 1,
    Message = UserRole + 2,
    Timestamp = UserRole + 3
    Identicon = UserRole + 4
    IsCurrentUser = UserRole + 5
    ContentType = UserRole + 6
    Sticker = UserRole + 7
    FromAuthor = UserRole + 8
    Clock = UserRole + 9
    ChatId = UserRole + 10
    SectionIdentifier = UserRole + 11
    Id = UserRole + 12
    OutgoingStatus = UserRole + 13
    ResponseTo = UserRole + 14
    PlainText = UserRole + 15
    Index = UserRole + 16
    ImageUrls = UserRole + 17
    Timeout = UserRole + 18
    Image = UserRole + 19
    Audio = UserRole + 20
    AudioDurationMs = UserRole + 21
    EmojiReactions = UserRole + 22

QtObject:
  type
    ChatMessageList* = ref object of QAbstractListModel
      messages*: seq[Message]
      status: Status
      messageIndex: Table[string, int]
      timedoutMessages: HashSet[string]

  proc delete(self: ChatMessageList) =
    self.messages = @[]
    self.messageIndex = initTable[string, int]()
    self.timedoutMessages = initHashSet[string]()
    self.QAbstractListModel.delete

  proc setup(self: ChatMessageList) =
    self.QAbstractListModel.setup

  include message_format

  proc chatIdentifier(self: ChatMessageList, chatId:string): Message =
    result = Message()
    result.contentType = ContentType.ChatIdentifier;
    result.chatId = chatId

  proc newChatMessageList*(chatId: string, status: Status): ChatMessageList =
    new(result, delete)
    result.messages = @[result.chatIdentifier(chatId)]
    result.messageIndex = initTable[string, int]()
    result.timedoutMessages = initHashSet[string]()
    result.status = status
    result.setup

  proc resetTimeOut*(self: ChatMessageList, messageId: string) =
    if not self.messageIndex.hasKey(messageId): return
    let msgIdx = self.messageIndex[messageId]
    self.timedoutMessages.excl(messageId)
    let topLeft = self.createIndex(msgIdx, 0, nil)
    let bottomRight = self.createIndex(msgIdx, 0, nil)
    self.dataChanged(topLeft, bottomRight, @[ChatMessageRoles.Timeout.int])

  proc checkTimeout*(self: ChatMessageList, messageId: string) =
    if not self.messageIndex.hasKey(messageId): return

    let msgIdx = self.messageIndex[messageId]
    if self.messages[msgIdx].outgoingStatus != "sending": return

    self.timedoutMessages.incl(messageId)

    let topLeft = self.createIndex(msgIdx, 0, nil)
    let bottomRight = self.createIndex(msgIdx, 0, nil)
    self.dataChanged(topLeft, bottomRight, @[ChatMessageRoles.Timeout.int])

  method rowCount(self: ChatMessageList, index: QModelIndex = nil): int =
    return self.messages.len

  method data(self: ChatMessageList, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.messages.len:
      return
    let message = self.messages[index.row]
    let chatMessageRole = role.ChatMessageRoles
    case chatMessageRole:
      of ChatMessageRoles.UserName: result = newQVariant(message.alias)
      of ChatMessageRoles.Message: result = newQVariant(self.renderBlock(message))
      of ChatMessageRoles.PlainText: result = newQVariant(message.text)
      of ChatMessageRoles.Timestamp: result = newQVariant(message.timestamp)
      of ChatMessageRoles.Clock: result = newQVariant($message.clock)
      of ChatMessageRoles.Identicon: result = newQVariant(message.identicon)
      of ChatMessageRoles.IsCurrentUser: result = newQVariant(message.isCurrentUser)
      of ChatMessageRoles.ContentType: result = newQVariant(message.contentType.int)
      of ChatMessageRoles.Sticker: result = newQVariant(message.stickerHash.decodeContentHash())
      of ChatMessageRoles.FromAuthor: result = newQVariant(message.fromAuthor)
      of ChatMessageRoles.ChatId: result = newQVariant(message.chatId)
      of ChatMessageRoles.SectionIdentifier: result = newQVariant(sectionIdentifier(message))
      of ChatMessageRoles.Id: result = newQVariant(message.id)
      of ChatMessageRoles.OutgoingStatus: result = newQVariant(message.outgoingStatus)
      of ChatMessageRoles.ResponseTo: result = newQVariant(message.responseTo)
      of ChatMessageRoles.Index: result = newQVariant(index.row)
      of ChatMessageRoles.ImageUrls: result = newQVariant(message.imageUrls)
      of ChatMessageRoles.Timeout: result = newQVariant(self.timedoutMessages.contains(message.id))
      of ChatMessageRoles.Image: result = newQVariant(message.image)
      of ChatMessageRoles.Audio: result = newQVariant(message.audio)
      of ChatMessageRoles.AudioDurationMs: result = newQVariant(message.audioDurationMs)
      of ChatMessageRoles.EmojiReactions: result = newQVariant(message.emojiReactions)

  method roleNames(self: ChatMessageList): Table[int, string] =
    {
      ChatMessageRoles.UserName.int:"userName",
      ChatMessageRoles.Message.int:"message",
      ChatMessageRoles.PlainText.int:"plainText",
      ChatMessageRoles.Timestamp.int:"timestamp",
      ChatMessageRoles.Clock.int:"clock",
      ChatMessageRoles.Identicon.int:"identicon",
      ChatMessageRoles.IsCurrentUser.int:"isCurrentUser",
      ChatMessageRoles.ContentType.int:"contentType",
      ChatMessageRoles.Sticker.int:"sticker",
      ChatMessageRoles.FromAuthor.int:"fromAuthor",
      ChatMessageRoles.ChatId.int:"chatId",
      ChatMessageRoles.SectionIdentifier.int: "sectionIdentifier",
      ChatMessageRoles.Id.int: "messageId",
      ChatMessageRoles.OutgoingStatus.int: "outgoingStatus",
      ChatMessageRoles.ResponseTo.int: "responseTo",
      ChatMessageRoles.Index.int: "index",
      ChatMessageRoles.ImageUrls.int: "imageUrls",
      ChatMessageRoles.Timeout.int: "timeout",
      ChatMessageRoles.Image.int: "image",
      ChatMessageRoles.Audio.int: "audio",
      ChatMessageRoles.AudioDurationMs.int: "audioDurationMs",
      ChatMessageRoles.EmojiReactions.int: "emojiReactions"
    }.toTable

  proc getMessageIndex(self: ChatMessageList, messageId: string): int {.slot.} =
    if not self.messageIndex.hasKey(messageId): return -1
    result = self.messageIndex[messageId]

  # TODO: see how to use data() instead of this function
  proc getMessageData(self: ChatMessageList, index: int, data: string): string {.slot.} =
    if index < 0 or index >= self.messages.len: return ("")

    let message = self.messages[index]
    case data:
    of "userName": result = (message.alias)
    of "message": result = (message.text)
    of "identicon": result = (message.identicon)
    of "timestamp": result = $(message.timestamp)
    of "image": result = $(message.image)
    of "contentType": result = $(message.contentType.int)
    else: result = ("")

  proc add*(self: ChatMessageList, message: Message) =
    if self.messageIndex.hasKey(message.id): return # duplicated msg

    self.beginInsertRows(newQModelIndex(), self.messages.len, self.messages.len)
    self.messageIndex[message.id] = self.messages.len
    self.messages.add(message)
    self.endInsertRows()

  proc add*(self: ChatMessageList, messages: seq[Message]) =
    self.beginInsertRows(newQModelIndex(), self.messages.len, self.messages.len)
    for message in messages:
      if self.messageIndex.hasKey(message.id): continue
      self.messageIndex[message.id] = self.messages.len
      self.messages.add(message)
    self.endInsertRows()

  proc getMessageById*(self: ChatMessageList, messageId: string): Message =
    if (not self.messageIndex.hasKey(messageId)): return
    return self.messages[self.messageIndex[messageId]]

  proc clear*(self: ChatMessageList) =
    self.beginResetModel()
    self.messages = @[]
    self.endResetModel()

  proc setMessageReactions*(self: ChatMessageList, messageId: string, newReactions: string)=
    let msgIdx = self.messageIndex[messageId]
    self.messages[msgIdx].emojiReactions = newReactions
    let topLeft = self.createIndex(msgIdx, 0, nil)
    let bottomRight = self.createIndex(msgIdx, 0, nil)
    self.dataChanged(topLeft, bottomRight, @[ChatMessageRoles.EmojiReactions.int])

  proc markMessageAsSent*(self: ChatMessageList, messageId: string)=
    let topLeft = self.createIndex(0, 0, nil)
    let bottomRight = self.createIndex(self.messages.len, 0, nil)
    for m in self.messages.mitems:
      if m.id == messageId:
        m.outgoingStatus = "sent"
        break
    self.dataChanged(topLeft, bottomRight, @[ChatMessageRoles.OutgoingStatus.int])

  proc updateUsernames*(self: ChatMessageList, contacts: seq[Profile]) =
    let topLeft = self.createIndex(0, 0, nil)
    let bottomRight = self.createIndex(self.messages.len, 0, nil)

    # TODO: change this once the contact list uses a table
    for c in contacts:
      for m in self.messages.mitems:
        if m.fromAuthor == c.id:
          m.alias = userNameOrAlias(c)

    self.dataChanged(topLeft, bottomRight, @[ChatMessageRoles.Username.int])
