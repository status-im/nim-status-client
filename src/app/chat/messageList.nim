import NimQml, messages, Tables

type
  ChatMessageRoles {.pure.} = enum
    UserName = UserRole + 1,
    Message = UserRole + 2,
    Timestamp = UserRole + 3
    IsCurrentUser = UserRole + 4

QtObject:
  type
    ChatMessageList* = ref object of QAbstractListModel
      messages*: seq[ChatMessage]

  proc delete(self: ChatMessageList) =
    self.QAbstractListModel.delete
    for message in self.messages:
      message.delete
    self.messages = @[]

  proc setup(self: ChatMessageList) =
    self.QAbstractListModel.setup

  proc newChatMessageList*(): ChatMessageList =
    new(result, delete)
    result.messages = @[]
    result.setup

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
      of ChatMessageRoles.UserName: result = newQVariant(message.userName)
      of ChatMessageRoles.Message: result = newQVariant(message.message)
      of ChatMessageRoles.Timestamp: result = newQVariant(message.timestamp)
      of ChatMessageRoles.IsCurrentUser: result = newQVariant(message.isCurrentUser)

  method roleNames(self: ChatMessageList): Table[int, string] =
    { 
      ChatMessageRoles.UserName.int:"userName",
      ChatMessageRoles.Message.int:"message",
      ChatMessageRoles.Timestamp.int:"timestamp",
      ChatMessageRoles.IsCurrentUser.int:"isCurrentUser"
    }.toTable

  proc add*(self: ChatMessageList, message: ChatMessage) =
    self.beginInsertRows(newQModelIndex(), self.messages.len, self.messages.len)
    self.messages.add(message)
    self.endInsertRows()
