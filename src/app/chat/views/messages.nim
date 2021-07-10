import NimQml, Tables, json, sequtils, chronicles, times, re, sugar, strutils, os, strformat, algorithm

import ../../../status/[status, contacts, types, mailservers]
import ../../../status/signals/types as signal_types
import ../../../status/ens as status_ens
import ../../../status/chat as status_chat
import ../../../status/messages as status_messages
import ../../../status/utils as status_utils
import ../../../status/chat/[chat, message]
import ../../../status/profile/profile
import ../../../status/tasks/[qt, task_runner_impl]

import communities, chat_item, channels_list, communities, community_list, message_list, channel

# TODO: remove me
import ../../../status/libstatus/chat as libstatus_chat

logScope:
  topics = "messages-view"

type
  ChatViewRoles {.pure.} = enum
    MessageList = UserRole + 1

type
  AsyncMessageLoadTaskArg = ref object of QObjectTaskArg
    chatId: string

const asyncMessageLoadTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncMessageLoadTaskArg](argEncoded)
  var messages: JsonNode
  var msgCallSuccess: bool
  let msgCallResult = status_chat.rpcChatMessages(arg.chatId, newJString(""), 20, msgCallSuccess)
  if(msgCallSuccess):
    messages = msgCallResult.parseJson()["result"]

  var reactions: JsonNode
  var reactionsCallSuccess: bool
  let reactionsCallResult = status_chat.rpcReactions(arg.chatId, newJString(""), 20, reactionsCallSuccess)
  if(reactionsCallSuccess):
    reactions = reactionsCallResult.parseJson()["result"]

  var pinnedMessages: JsonNode
  var pinnedMessagesCallSuccess: bool
  let pinnedMessagesCallResult = status_chat.rpcPinnedChatMessages(arg.chatId, newJString(""), 20, pinnedMessagesCallSuccess)
  if(pinnedMessagesCallSuccess):
    pinnedMessages = pinnedMessagesCallResult.parseJson()["result"]

  let responseJson = %*{
    "chatId": arg.chatId,
    "messages": messages,
    "reactions": reactions,
    "pinnedMessages": pinnedMessages
  }
  arg.finish(responseJson)

proc asyncMessageLoad[T](self: T, slot: string, chatId: string) =
  let arg = AsyncMessageLoadTaskArg(
    tptr: cast[ByteAddress](asyncMessageLoadTask),
    vptr: cast[ByteAddress](self.vptr),
    slot: slot,
    chatId: chatId
  )
  self.status.tasks.threadpool.start(arg)

QtObject:
  type MessageView* = ref object of QAbstractListModel
    status: Status
    messageList*: OrderedTable[string, ChatMessageList]
    pinnedMessagesList*: OrderedTable[string, ChatMessageList]
    channelView*: ChannelView
    communities*: CommunitiesView
    pubKey*: string
    loadingMessages*: bool
    unreadMessageCnt: int
    channelOpenTime*: Table[string, int64]

  proc setup(self: MessageView) = self.QAbstractListModel.setup
  proc delete*(self: MessageView) =
    for msg in self.messageList.values:
      msg.delete
    for msg in self.pinnedMessagesList.values:
      msg.delete
    self.messageList = initOrderedTable[string, ChatMessageList]()
    self.pinnedMessagesList = initOrderedTable[string, ChatMessageList]()
    self.channelOpenTime = initTable[string, int64]()
    # self.QObject.delete
    self.QAbstractListModel.delete

  proc newMessageView*(status: Status, channelView: ChannelView, communitiesView: CommunitiesView): MessageView =
    new(result, delete)
    result.status = status
    result.channelView = channelView
    result.communities = communitiesView
    result.messageList = initOrderedTable[string, ChatMessageList]()
    result.pinnedMessagesList = initOrderedTable[string, ChatMessageList]()
    result.messageList[status_utils.getTimelineChatId()] = newChatMessageList(status_utils.getTimelineChatId(), result.status, false)
    result.loadingMessages = false
    result.unreadMessageCnt = 0
    result.setup

  # proc getMessageListIndexById(self: MessageView, id: string): int

  proc replaceMentionsWithPubKeys(self: MessageView, mentions: seq[string], contacts: seq[Profile], message: string, predicate: proc (contact: Profile): string): string =
    var updatedMessage = message
    for mention in mentions:
      let matches = contacts.filter(c => "@" & predicate(c).toLowerAscii == mention.toLowerAscii).map(c => c.address)
      if matches.len > 0:
        let pubKey = matches[0]
        var startIndex = 0
        var index = updatedMessage.find(mention)

        while index > -1:
          if index == 0 or updatedMessage[index-1] == ' ':
            updatedMessage = updatedMessage.replaceWord(mention, '@' & pubKey)
          startIndex = index + mention.len
          index = updatedMessage.find(mention, startIndex)

    result = updatedMessage

  proc hideMessage(self: MessageView, mId: string) {.signal.}

  proc sendOrEditMessage*(self: MessageView, message: string, replyTo: string, contentType: int = ContentType.Message.int, isStatusUpdate: bool = false, contactsString: string = "", isEdit: bool = false, messageId: string = "") {.slot.} =
    let aliasPattern = re(r"(@[A-z][a-z]+ [A-z][a-z]* [A-z][a-z]*)", flags = {reStudy, reIgnoreCase})
    let ensPattern = re(r"(@\w+(?=(\.stateofus)?\.eth))", flags = {reStudy, reIgnoreCase})
    let namePattern = re(r"(@\w+)", flags = {reStudy, reIgnoreCase})

    var contacts: seq[Profile]
    if (contactsString == ""):
      contacts = self.status.contacts.getContacts()
    else:
      let contactsJSON = parseJson(contactsString)
      contacts = @[]
      for contact in contactsJSON:
        contacts.add(Profile(
          address: contact["address"].str,
          alias: contact["alias"].str,
          ensName: contact["ensName"].str
        ))

    let aliasMentions = findAll(message, aliasPattern)
    let ensMentions = findAll(message, ensPattern)
    let nameMentions = findAll(message, namePattern)

    var m = self.replaceMentionsWithPubKeys(aliasMentions, contacts, message, (c => c.alias))
    m = self.replaceMentionsWithPubKeys(ensMentions, contacts, m, (c => c.ensName))
    m = self.replaceMentionsWithPubKeys(nameMentions, contacts, m, (c => c.ensName.split(".")[0]))

    var channelId = self.channelView.activeChannel.id

    if isStatusUpdate:
      channelId = "@" & self.pubKey

    if not isEdit:
      self.status.chat.sendMessage(channelId, m, replyTo, contentType)
    else:
      self.status.chat.editMessage(messageId, m)

  proc sendMessage*(self: MessageView, message: string, replyTo: string, contentType: int = ContentType.Message.int, isStatusUpdate: bool = false, contactsString: string = "") {.slot.} =
    self.sendOrEditMessage(message, replyTo, contentType, isStatusUpdate, contactsString, false, "")

  proc verifyMessageSent*(self: MessageView, data: string) {.slot.} =
    let messageData = data.parseJson
    self.messageList[messageData["chatId"].getStr].checkTimeout(messageData["id"].getStr)

  proc resendMessage*(self: MessageView, chatId: string, messageId: string) {.slot.} =
    self.status.messages.trackMessage(messageId, chatId)
    self.status.chat.resendMessage(messageId)
    self.messageList[chatId].resetTimeOut(messageId)

  proc sendingMessage*(self: MessageView) {.signal.}

  proc sendingMessageFailed*(self: MessageView) {.signal.}

  proc messageEdited(self: MessageView, editedMessageId: string, editedMessageContent: string) {.signal.}

  proc editMessage*(self: MessageView, messageId: string, originalMessageId: string, message: string, contactsString: string = "") {.slot.} =
    self.sendOrEditMessage(message, "", ContentType.Message.int, false, contactsString, true, originalMessageId)
    self.messageEdited(originalMessageId, message)

  proc messagePushed*(self: MessageView, messageIndex: int) {.signal.}
  proc newMessagePushed*(self: MessageView) {.signal.}

  proc messagesCleared*(self: MessageView) {.signal.}

  proc clearMessages*(self: MessageView, id: string) =
    let channel = self.channelView.getChannelById(id)
    if (channel == nil):
      return
    self.messageList[id].clear(not channel.isNil and channel.chatType != ChatType.Profile)
    self.messagesCleared()

  proc upsertChannel*(self: MessageView, channel: string) =
    var chat: Chat = nil
    if self.status.chat.channels.hasKey(channel):
      chat = self.status.chat.channels[channel]
    else:
      chat = self.communities.getChannel(channel)
    if not self.messageList.hasKey(channel):
      self.beginInsertRows(newQModelIndex(), self.messageList.len, self.messageList.len)
      self.messageList[channel] = newChatMessageList(channel, self.status, not chat.isNil and chat.chatType != ChatType.Profile)
      self.channelOpenTime[channel] = now().toTime.toUnix * 1000
      self.endInsertRows();
    if not self.pinnedMessagesList.hasKey(channel):
      self.pinnedMessagesList[channel] = newChatMessageList(channel, self.status, false)

  proc pushPinnedMessages*(self:MessageView, pinnedMessages: var seq[Message]) =
    for msg in pinnedMessages.mitems:
      self.upsertChannel(msg.chatId)

      var message = self.messageList[msg.chatId].getMessageById(msg.id)
      message.pinnedBy = msg.pinnedBy
      message.isPinned = true

      self.pinnedMessagesList[msg.chatId].add(message)
      # put the message as pinned in the message list
      self.messageList[msg.chatId].changeMessagePinned(msg.id, true, msg.pinnedBy)

  proc isAddedContact*(self: MessageView, id: string): bool {.slot.} =
    result = self.status.contacts.isAdded(id)

  proc messageNotificationPushed*(self: MessageView, chatId: string, text: string, messageType: string, chatType: int, timestamp: string, identicon: string, username: string, hasMention: bool, isAddedContact: bool, channelName: string) {.signal.}

  proc pushMessages*(self:MessageView, messages: var seq[Message]) =
    for msg in messages.mitems:
      self.upsertChannel(msg.chatId)
      msg.userName = self.status.chat.getUserName(msg.fromAuthor, msg.alias)
      var msgIndex:int;
      if self.status.chat.channels.hasKey(msg.chatId):
        let chat = self.status.chat.channels[msg.chatId]
        if (chat.chatType == ChatType.Profile):
          let timelineChatId = status_utils.getTimelineChatId()
          self.messageList[timelineChatId].add(msg)
          # if self.channelView.activeChannel.id == timelineChatId: self.activeChannelChanged()
          if self.channelView.activeChannel.id == timelineChatId: self.channelView.activeChannelChanged()
          msgIndex = self.messageList[timelineChatId].messages.len - 1
        else:
          self.messageList[msg.chatId].add(msg)
          if self.pinnedMessagesList[msg.chatId].contains(msg):
            self.pinnedMessagesList[msg.chatId].add(msg)
          msgIndex = self.messageList[msg.chatId].messages.len - 1
      self.messagePushed(msgIndex)
      if self.channelOpenTime.getOrDefault(msg.chatId, high(int64)) < msg.timestamp.parseFloat.fromUnixFloat.toUnix:
        var channel = self.channelView.chats.getChannelById(msg.chatId)
        if (channel == nil):
          channel = self.communities.getChannel(msg.chatId)
          if (channel == nil):
            continue          
        if msg.chatId == self.channelView.activeChannel.id:
          discard self.status.chat.markMessagesSeen(msg.chatId, @[msg.id])
          self.newMessagePushed()

        if not channel.muted:
          let isAddedContact = channel.chatType.isOneToOne and self.isAddedContact(channel.id)
          if msg.editedAt == "0": # Do not push notifications for edit messages
            self.messageNotificationPushed(msg.chatId, escape_html(msg.text), msg.messageType, channel.chatType.int, msg.timestamp, msg.identicon, msg.userName, msg.hasMention, isAddedContact, channel.name)

  proc markMessageAsSent*(self:MessageView, chat: string, messageId: string) =
    if self.messageList.contains(chat):
      self.messageList[chat].markMessageAsSent(messageId)
    else:
      error "Message could not be marked as sent", chat, messageId

  proc getMessageIndex(self: MessageView, chatId: string, messageId: string): int {.slot.} =
    if (not self.messageList.hasKey(chatId)):
      return -1
    result = self.messageList[chatId].getMessageIndex(messageId)

  proc getMessageData(self: MessageView, chatId: string,  index: int, data: string): string {.slot.} =
    if (not self.messageList.hasKey(chatId)):
      return

    return self.messageList[chatId].getMessageData(index, data)

  proc getMessageList(self: MessageView): QVariant {.slot.} =
    self.upsertChannel(self.channelView.activeChannel.id)
    return newQVariant(self.messageList[self.channelView.activeChannel.id])

  proc activeChannelChanged*(self: MessageView) {.signal.}

  QtProperty[QVariant] messageList:
    read = getMessageList
    notify = activeChannelChanged

  proc getPinnedMessagesList(self: MessageView): QVariant {.slot.} =
    self.upsertChannel(self.channelView.activeChannel.id)
    return newQVariant(self.pinnedMessagesList[self.channelView.activeChannel.id])

  QtProperty[QVariant] pinnedMessagesList:
    read = getPinnedMessagesList
    notify = activeChannelChanged

  proc messagesLoaded*(self: MessageView) {.signal.}

  proc loadMoreMessages*(self: MessageView) {.slot.} =
    trace "Loading more messages", chaId = self.channelView.activeChannel.id
    self.status.chat.chatMessages(self.channelView.activeChannel.id, false)
    self.status.chat.chatReactions(self.channelView.activeChannel.id, false)
    self.messagesLoaded();

  proc loadMoreMessagesWithIndex*(self: MessageView, channelIndex: int) {.slot.} =
    if (self.channelView.chats.chats.len == 0): return
    let selectedChannel = self.channelView.getChannel(channelIndex)
    if (selectedChannel == nil): return
    trace "Loading more messages", chaId = selectedChannel.id
    self.status.chat.chatMessages(selectedChannel.id, false)
    self.status.chat.chatReactions(selectedChannel.id, false)
    self.messagesLoaded();

  proc loadingMessagesChanged*(self: MessageView, value: bool) {.signal.}

  proc asyncMessageLoad*(self: MessageView, chatId: string) {.slot.} =
    self.asyncMessageLoad("asyncMessageLoaded", chatId)

  proc asyncMessageLoaded*(self: MessageView, rpcResponse: string) {.slot.} =
    let
      rpcResponseObj = rpcResponse.parseJson
      chatId = rpcResponseObj{"chatId"}.getStr

    if chatId == "": # .getStr() returns "" when field is not found
      return

    let messages = rpcResponseObj{"messages"}
    if(messages != nil and messages.kind != JNull):
      let chatMessages = libstatus_chat.parseChatMessagesResponse(messages)
      self.status.chat.chatMessages(chatId, true, chatMessages[0], chatMessages[1])

    let rxns = rpcResponseObj{"reactions"}
    if(rxns != nil and rxns.kind != JNull):
      let reactions = status_chat.parseReactionsResponse(chatId, rxns)
      self.status.chat.chatReactions(chatId, true, reactions[0], reactions[1])

    let pinnedMsgs = rpcResponseObj{"pinnedMessages"}
    if(pinnedMsgs != nil and pinnedMsgs.kind != JNull):
      let pinnedMessages = libstatus_chat.parseChatPinnedMessagesResponse(pinnedMsgs)
      self.status.chat.pinnedMessagesByChatID(chatId, pinnedMessages[0], pinnedMessages[1])

  proc hideLoadingIndicator*(self: MessageView) {.slot.} =
    self.loadingMessages = false
    self.loadingMessagesChanged(false)

  proc setLoadingMessages*(self: MessageView, value: bool) {.slot.} =
    self.loadingMessages = value
    self.loadingMessagesChanged(value)

  proc isLoadingMessages(self: MessageView): QVariant {.slot.} =
    return newQVariant(self.loadingMessages)

  QtProperty[QVariant] loadingMessages:
    read = isLoadingMessages
    write = setLoadingMessages
    notify = loadingMessagesChanged

  proc fillGaps*(self: MessageView, messageId: string) {.slot.} =
    self.loadingMessages = true
    self.loadingMessagesChanged(true)
    discard self.status.mailservers.fillGaps(self.channelView.activeChannel.id, @[messageId])

  proc unreadMessages*(self: MessageView): int {.slot.} =
    result = self.unreadMessageCnt

  proc unreadMessagesCntChanged*(self: MessageView) {.signal.}

  QtProperty[int] unreadMessagesCount:
    read = unreadMessages
    notify = unreadMessagesCntChanged

  proc calculateUnreadMessages*(self: MessageView) =
    var unreadTotal = 0
    for chatItem in self.channelView.chats.chats:
      unreadTotal = unreadTotal + chatItem.unviewedMessagesCount
    if unreadTotal != self.unreadMessageCnt:
      self.unreadMessageCnt = unreadTotal
      self.unreadMessagesCntChanged()

  proc deleteMessage*(self: MessageView, channelId: string, messageId: string) =
    self.messageList[channelId].deleteMessage(messageId)
    self.hideMessage(messageId)

  proc removeMessagesByUserId(self: MessageView, publicKey: string) {.slot.} =
    for k in self.messageList.keys:
      self.messageList[k].removeMessagesByUserId(publicKey)

  proc getMessageListIndex(self: MessageView): int {.slot.} =
    var idx = -1
    for msg in toSeq(self.messageList.values):
      idx = idx + 1
      if(self.channelView.activeChannel.id == msg.id): return idx
    return idx

  proc getMessageListIndexById*(self: MessageView, id: string): int {.slot.} =
    var idx = -1
    for msg in toSeq(self.messageList.values):
      idx = idx + 1
      if(id == msg.id): return idx
    return idx

  proc addPinMessage*(self: MessageView, messageId: string, chatId: string, pinnedBy: string) =
    self.upsertChannel(chatId)
    if self.messageList[chatId].changeMessagePinned(messageId, true, pinnedBy):
      var message = self.messageList[chatId].getMessageById(messageId)
      message.pinnedBy = pinnedBy
      self.pinnedMessagesList[chatId].add(message)

  proc removePinMessage*(self: MessageView, messageId: string, chatId: string) =
    self.upsertChannel(chatId)
    if self.messageList[chatId].changeMessagePinned(messageId, false, ""):
      try:
        self.pinnedMessagesList[chatId].remove(messageId)
      except Exception as e:
        error "Error removing ", msg = e.msg

  proc pinMessage*(self: MessageView, messageId: string, chatId: string) {.slot.} =
    self.status.chat.setPinMessage(messageId, chatId, true)
    self.addPinMessage(messageId, chatId, self.pubKey)

  proc unPinMessage*(self: MessageView, messageId: string, chatId: string) {.slot.} =
    self.status.chat.setPinMessage(messageId, chatId, false)
    self.removePinMessage(messageId, chatId)

  proc addPinnedMessages*(self: MessageView, pinnedMessages: seq[Message]) =
    for pinnedMessage in pinnedMessages:
      if (pinnedMessage.isPinned):
        self.addPinMessage(pinnedMessage.id, pinnedMessage.localChatId, pinnedMessage.pinnedBy)
      else:
        self.removePinMessage(pinnedMessage.id, pinnedMessage.localChatId)

  method rowCount*(self: MessageView, index: QModelIndex = nil): int = 
    result = self.messageList.len

  method data(self: MessageView, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.messageList.len:
      return
    return newQVariant(toSeq(self.messageList.values)[index.row])

  method roleNames(self: MessageView): Table[int, string] =
    {
      ChatViewRoles.MessageList.int:"messages"
    }.toTable
