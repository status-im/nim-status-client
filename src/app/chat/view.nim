import NimQml, Tables, json, sequtils, chronicles, times, re, sugar, strutils, os, strformat, algorithm
import ../../status/status
import ../../status/mailservers
import ../../status/libstatus/chat as libstatus_chat
import ../../status/libstatus/accounts/constants
import ../../status/libstatus/mailservers as status_mailservers
import ../../status/libstatus/types
import ../../status/libstatus/core
import ../../status/libstatus/chat as core_chat
import ../../status/libstatus/utils as status_utils
import ../../status/accounts as status_accounts
import ../../status/chat as status_chat
import ../../status/messages as status_messages
import ../../status/contacts as status_contacts
import ../../status/ens as status_ens
import ../../status/chat/[chat, message]
import ../../status/profile/profile
import web3/[conversions, ethtypes]
import ../../status/threads
import views/[channels_list, message_list, chat_item, suggestions_list, reactions, stickers, groups, transactions, community_list, community_item]
import json_serialization
import ../utils/image_utils

logScope:
  topics = "chats-view"


type
  ChatViewRoles {.pure.} = enum
    MessageList = UserRole + 1

QtObject:
  type
    ChatsView* = ref object of QAbstractListModel
      status: Status
      chats*: ChannelsList
      currentSuggestions*: SuggestionsList
      callResult: string
      messageList*: OrderedTable[string, ChatMessageList]
      reactions*: ReactionView
      stickers*: StickersView
      groups*: GroupsView
      transactions*: TransactionsView
      activeChannel*: ChatItemView
      contextChannel*: ChatItemView
      previousActiveChannelIndex: int
      activeCommunity*: CommunityItemView
      observedCommunity*: CommunityItemView
      communityList*: CommunityList
      joinedCommunityList*: CommunityList
      replyTo: string
      channelOpenTime*: Table[string, int64]
      connected: bool
      unreadMessageCnt: int
      oldestMessageTimestamp: int64
      loadingMessages: bool
      timelineChat: Chat
      pubKey*: string

  proc setup(self: ChatsView) = self.QAbstractListModel.setup

  proc delete(self: ChatsView) = 
    self.chats.delete
    self.activeChannel.delete
    self.contextChannel.delete
    self.observedCommunity.delete
    self.activeCommunity.delete
    self.currentSuggestions.delete
    for msg in self.messageList.values:
      msg.delete
    self.reactions.delete
    self.stickers.delete
    self.groups.delete
    self.transactions.delete
    self.messageList = initOrderedTable[string, ChatMessageList]()
    self.channelOpenTime = initTable[string, int64]()
    self.QAbstractListModel.delete

  proc newChatsView*(status: Status): ChatsView =
    new(result, delete)
    result.status = status
    result.connected = false
    result.chats = newChannelsList(status)
    result.activeChannel = newChatItemView(status)
    result.contextChannel = newChatItemView(status)
    result.activeCommunity = newCommunityItemView(status)
    result.observedCommunity = newCommunityItemView(status)
    result.currentSuggestions = newSuggestionsList()
    result.messageList = initOrderedTable[string, ChatMessageList]()
    result.reactions = newReactionView(status, result.messageList.addr, result.activeChannel)
    result.stickers = newStickersView(status, result.activeChannel)
    result.groups = newGroupsView(status,result.activeChannel)
    result.communityList = newCommunityList(status)
    result.joinedCommunityList = newCommunityList(status)
    result.transactions = newTransactionsView(status)
    result.unreadMessageCnt = 0
    result.loadingMessages = false
    result.previousActiveChannelIndex = -1
    result.messageList[status_utils.getTimelineChatId()] = newChatMessageList(status_utils.getTimelineChatId(), result.status, false)

    result.setup()

  proc oldestMessageTimestampChanged*(self: ChatsView) {.signal.}

  proc getOldestMessageTimestamp*(self: ChatsView): QVariant {.slot.}  =
    newQVariant($self.oldestMessageTimestamp)

  QtProperty[QVariant] oldestMsgTimestamp:
    read = getOldestMessageTimestamp
    notify = oldestMessageTimestampChanged

  proc setLastMessageTimestamp*(self: ChatsView, force = false) = 
    if self.status.chat.lastMessageTimestamps.hasKey(self.activeChannel.id):
      if force or self.status.chat.lastMessageTimestamps[self.activeChannel.id] <= self.oldestMessageTimestamp:
        self.oldestMessageTimestamp = self.status.chat.lastMessageTimestamps[self.activeChannel.id]
    else:
      let topics = self.status.mailservers.getMailserverTopicsByChatId(self.activeChannel.id)
      if topics.len > 0:
        self.oldestMessageTimestamp = topics[0].lastRequest
      else:
        self.oldestMessageTimestamp = times.toUnix(times.getTime())
    self.oldestMessageTimestampChanged()

  proc getChatsList(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.chats)

  QtProperty[QVariant] chats:
    read = getChatsList

  proc getChannelColor*(self: ChatsView, channel: string): string {.slot.} =
    self.chats.getChannelColor(channel)

  proc replaceMentionsWithPubKeys(self: ChatsView, mentions: seq[string], contacts: seq[Profile], message: string, predicate: proc (contact: Profile): string): string =
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

  proc plainText(self: ChatsView, input: string): string {.slot.} =
    result = plain_text(input)

  proc sendMessage*(self: ChatsView, message: string, replyTo: string, contentType: int = ContentType.Message.int, isStatusUpdate: bool = false) {.slot.} =
    let aliasPattern = re(r"(@[A-z][a-z]+ [A-z][a-z]* [A-z][a-z]*)", flags = {reStudy, reIgnoreCase})
    let ensPattern = re(r"(@\w+(?=(\.stateofus)?\.eth))", flags = {reStudy, reIgnoreCase})
    let namePattern = re(r"(@\w+)", flags = {reStudy, reIgnoreCase})

    let contacts = self.status.contacts.getContacts()

    let aliasMentions = findAll(message, aliasPattern)
    let ensMentions = findAll(message, ensPattern)
    let nameMentions = findAll(message, namePattern)

    var m = self.replaceMentionsWithPubKeys(aliasMentions, contacts, message, (c => c.alias))
    m = self.replaceMentionsWithPubKeys(ensMentions, contacts, m, (c => c.ensName))
    m = self.replaceMentionsWithPubKeys(nameMentions, contacts, m, (c => c.ensName.split(".")[0]))

    var channelId = self.activeChannel.id

    if isStatusUpdate:
      channelId = "@" & self.pubKey

    self.status.chat.sendMessage(channelId, m, replyTo, contentType)

  proc verifyMessageSent*(self: ChatsView, data: string) {.slot.} =
    let messageData = data.parseJson
    self.messageList[messageData["chatId"].getStr].checkTimeout(messageData["id"].getStr)

  proc resendMessage*(self: ChatsView, chatId: string, messageId: string) {.slot.} =
    self.status.messages.trackMessage(messageId, chatId)
    self.status.chat.resendMessage(messageId)
    self.messageList[chatId].resetTimeOut(messageId)

  proc sendImage*(self: ChatsView, imagePath: string, isStatusUpdate: bool = false): string {.slot.} =
    result = ""
    try:
      var image = image_utils.formatImagePath(imagePath)
      let tmpImagePath = image_resizer(image, 2000, USRTMPDIR)

      var channelId = self.activeChannel.id
      
      if isStatusUpdate:
        channelId = "@" & self.pubKey

      self.status.chat.sendImage(channelId, tmpImagePath)
      removeFile(tmpImagePath)
    except Exception as e:
      error "Error sending the image", msg = e.msg
      result = fmt"Error sending the image: {e.msg}"

  proc activeChannelChanged*(self: ChatsView) {.signal.}

  proc contextChannelChanged*(self: ChatsView) {.signal.}

  proc sendingMessage*(self: ChatsView) {.signal.}

  proc appReady*(self: ChatsView) {.signal.}

  proc sendingMessageFailed*(self: ChatsView) {.signal.}

  proc alias*(self: ChatsView, pubKey: string): string {.slot.} =
    generateAlias(pubKey)

  proc userNameOrAlias*(self: ChatsView, pubKey: string): string {.slot.} =
    if self.status.chat.contacts.hasKey(pubKey):
      return status_ens.userNameOrAlias(self.status.chat.contacts[pubKey])
    generateAlias(pubKey)

  proc markAllChannelMessagesReadByIndex*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return
    discard self.status.chat.markAllChannelMessagesRead(selectedChannel.id)

  proc clearUnreadIfNeeded*(self: ChatsView, channel: var Chat) =
    if (not channel.isNil and (channel.unviewedMessagesCount > 0 or channel.hasMentions)):
      var response = self.status.chat.markAllChannelMessagesRead(channel.id)
      if not response.hasKey("error"):
        self.chats.clearUnreadMessagesCount(channel)

  proc setActiveChannelByIndex*(self: ChatsView, index: int) {.slot.} =
    if((self.activeCommunity.active and self.activeCommunity.chats.chats.len == 0) or (not self.activeCommunity.active and self.chats.chats.len == 0)): return

    var selectedChannel =
      if (self.activeCommunity.active):
        self.activeCommunity.chats.getChannel(index)
      else:
        self.chats.getChannel(index)

    self.clearUnreadIfNeeded(self.activeChannel.chatItem)
    self.clearUnreadIfNeeded(selectedChannel)

    if self.activeChannel.id == selectedChannel.id: return

    if selectedChannel.chatType.isOneToOne and selectedChannel.id == selectedChannel.name:
        selectedChannel.name = self.userNameOrAlias(selectedChannel.id)

    self.previousActiveChannelIndex = index
    self.activeChannel.setChatItem(selectedChannel)
    self.status.chat.setActiveChannel(selectedChannel.id)

  proc getActiveChannelIdx(self: ChatsView): int {.slot.} =
    if (self.activeCommunity.active):
      return self.activeCommunity.chats.chats.findIndexById(self.activeChannel.id)
    else:
      return self.chats.chats.findIndexById(self.activeChannel.id)

  QtProperty[int] activeChannelIndex:
    read = getActiveChannelIdx
    write = setActiveChannelByIndex
    notify = activeChannelChanged

  proc setActiveChannel*(self: ChatsView, channel: string) {.slot.} =
    if(channel == ""): return

    let selectedChannel =
        if (self.activeCommunity.active):
          self.activeCommunity.chats.getChannel(self.activeCommunity.chats.chats.findIndexById(channel))
        else:
          self.chats.getChannel(self.chats.chats.findIndexById(channel))

    self.activeChannel.setChatItem(selectedChannel)
    
    discard self.status.chat.markAllChannelMessagesRead(self.activeChannel.id)
    self.setLastMessageTimestamp(true)
    self.activeChannelChanged()

  proc getActiveChannel*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.activeChannel)

  QtProperty[QVariant] activeChannel:
    read = getActiveChannel
    write = setActiveChannel
    notify = activeChannelChanged

  proc setContextChannel*(self: ChatsView, channel: string) {.slot.} =
    let contextChannel = self.chats.getChannel(self.chats.chats.findIndexById(channel))
    self.contextChannel.setChatItem(contextChannel)
    self.contextChannelChanged()

  proc getContextChannel*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.contextChannel)
  
  QtProperty[QVariant] contextChannel:
    read = getContextChannel
    write = setContextChannel
    notify = contextChannelChanged

  proc setActiveChannelToTimeline*(self: ChatsView) {.slot.} =
    if not self.activeChannel.chatItem.isNil:
      self.previousActiveChannelIndex = self.chats.chats.findIndexById(self.activeChannel.id)
    self.activeChannel.setChatItem(self.timelineChat)
    self.activeChannelChanged()

  proc restorePreviousActiveChannel*(self: ChatsView) {.slot.} =
    if self.activeChannel.id == self.timelineChat.id and not self.previousActiveChannelIndex == -1:
      self.setActiveChannelByIndex(self.previousActiveChannelIndex)

  proc getCurrentSuggestions(self: ChatsView): QVariant {.slot.} =
    return newQVariant(self.currentSuggestions)

  QtProperty[QVariant] suggestionList:
    read = getCurrentSuggestions

  proc upsertChannel(self: ChatsView, channel: string) =
    var chat: Chat = nil
    if self.status.chat.channels.hasKey(channel):
      chat = self.status.chat.channels[channel]
    if not self.messageList.hasKey(channel):
      self.beginInsertRows(newQModelIndex(), self.messageList.len, self.messageList.len)
      self.messageList[channel] = newChatMessageList(channel, self.status, not chat.isNil and chat.chatType != ChatType.Profile)
      self.channelOpenTime[channel] = now().toTime.toUnix * 1000
      self.endInsertRows();

  proc messagePushed*(self: ChatsView, messageIndex: int) {.signal.}
  proc newMessagePushed*(self: ChatsView) {.signal.}

  proc messageNotificationPushed*(self: ChatsView, chatId: string, text: string, messageType: string, chatType: int, timestamp: string, identicon: string, username: string, hasMention: bool, isAddedContact: bool, channelName: string) {.signal.}

  proc messagesCleared*(self: ChatsView) {.signal.}

  proc clearMessages*(self: ChatsView, id: string) =
    let channel = self.chats.getChannelById(id)
    if (channel == nil):
      return
    self.messageList[id].clear(not channel.isNil and channel.chatType != ChatType.Profile)
    self.messagesCleared()
  
  proc isAddedContact*(self: ChatsView, id: string): bool {.slot.} =
    result = self.status.contacts.isAdded(id)

  proc pushMessages*(self:ChatsView, messages: var seq[Message]) =
    for msg in messages.mitems:
      self.upsertChannel(msg.chatId)
      msg.userName = self.status.chat.getUserName(msg.fromAuthor, msg.alias)
      var msgIndex:int;
      if self.status.chat.channels.hasKey(msg.chatId):
        let chat = self.status.chat.channels[msg.chatId]
        if (chat.chatType == ChatType.Profile):
          let timelineChatId = status_utils.getTimelineChatId()
          self.messageList[timelineChatId].add(msg)
          if self.activeChannel.id == timelineChatId: self.activeChannelChanged()
          msgIndex = self.messageList[timelineChatId].messages.len - 1
        else:
          self.messageList[msg.chatId].add(msg)
          msgIndex = self.messageList[msg.chatId].messages.len - 1
      self.messagePushed(msgIndex)
      if self.channelOpenTime.getOrDefault(msg.chatId, high(int64)) < msg.timestamp.parseFloat.fromUnixFloat.toUnix:
        let channel = self.chats.getChannelById(msg.chatId)
        if (channel == nil):
          continue

        if msg.chatId == self.activeChannel.id:
          discard self.status.chat.markMessagesSeen(msg.chatId, @[msg.id])
          self.newMessagePushed()

        if not channel.muted:
          let isAddedContact = channel.chatType.isOneToOne and self.isAddedContact(channel.id)
          self.messageNotificationPushed(
            msg.chatId,
            escape_html(msg.text),
            msg.messageType,
            channel.chatType.int,
            msg.timestamp,
            msg.identicon,
            msg.alias,
            msg.hasMention,
            isAddedContact,
            channel.name)

  proc updateUsernames*(self:ChatsView, contacts: seq[Profile]) =
    if contacts.len > 0:
      # Updating usernames for all the messages list
      for k in self.messageList.keys:
        self.messageList[k].updateUsernames(contacts)
      self.activeChannel.contactsUpdated()

  proc updateChannelForContacts*(self: ChatsView, contacts: seq[Profile]) =
    for contact in contacts:
      let channel = self.chats.getChannelById(contact.id)
      if not channel.isNil:
        if contact.localNickname == "":
          if channel.name == "" or channel.name == channel.id:
            if channel.ensName != "":
              channel.name = channel.ensName
            else: 
              channel.name = contact.username
        else:
          channel.name = contact.localNickname
        self.chats.updateChat(channel)
        if (self.activeChannel.id == channel.id):
          self.activeChannel.setChatItem(channel)
          self.activeChannelChanged()


  proc markMessageAsSent*(self:ChatsView, chat: string, messageId: string) =
    self.messageList[chat].markMessageAsSent(messageId)

  proc getMessageList(self: ChatsView): QVariant {.slot.} =
    self.upsertChannel(self.activeChannel.id)
    return newQVariant(self.messageList[self.activeChannel.id])

  QtProperty[QVariant] messageList:
    read = getMessageList
    notify = activeChannelChanged

  proc pushChatItem*(self: ChatsView, chatItem: Chat) =
    discard self.chats.addChatItemToList(chatItem)
    self.messagePushed(self.messageList[chatItem.id].messages.len - 1)
  
  proc setTimelineChat*(self: ChatsView, chatItem: Chat) =
    self.timelineChat = chatItem

  proc copyToClipboard*(self: ChatsView, content: string) {.slot.} =
    setClipBoardText(content)

  proc linkPreviewDataWasReceived*(self: ChatsView, previewData: string) {.signal.}

  proc linkPreviewDataReceived(self: ChatsView, previewData: string) {.slot.} =
    self.linkPreviewDataWasReceived(previewData)

  proc getLinkPreviewData*(self: ChatsView, link: string, uuid: string) {.slot.} =
    spawnAndSend(self, "linkPreviewDataReceived") do:
      var success: bool
      # We need to call directly on libstatus because going through the status model is not thread safe
      let response = libstatus_chat.getLinkPreviewData(link, success)
      $(%* { "result": %response, "success": %success, "uuid": %uuid })

  proc joinChat*(self: ChatsView, channel: string, chatTypeInt: int): int {.slot.} =
    self.status.chat.join(channel, ChatType(chatTypeInt))
    self.setActiveChannel(channel)

  proc joinChatWithENS*(self: ChatsView, channel: string, ensName: string): int {.slot.} =
    self.status.chat.join(channel, ChatType.OneToOne, ensName=status_ens.addDomain(ensName))
    self.setActiveChannel(channel)

  proc messagesLoaded*(self: ChatsView) {.signal.}

  proc loadMoreMessages*(self: ChatsView) {.slot.} =
    trace "Loading more messages", chaId = self.activeChannel.id
    self.status.chat.chatMessages(self.activeChannel.id, false)
    self.status.chat.chatReactions(self.activeChannel.id, false)
    if self.status.chat.msgCursor[self.activeChannel.id] == "":
      self.setLastMessageTimestamp()
    self.messagesLoaded();

  proc loadMoreMessagesWithIndex*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return
    trace "Loading more messages", chaId = selectedChannel.id
    self.status.chat.chatMessages(selectedChannel.id, false)
    self.status.chat.chatReactions(selectedChannel.id, false)
    self.setLastMessageTimestamp()
    self.messagesLoaded();

  proc loadingMessagesChanged*(self: ChatsView, value: bool) {.signal.}

  proc asyncMessageLoad*(self: ChatsView, chatId: string) {.slot.} =
    spawnAndSend(self, "asyncMessageLoaded") do: # Call self.ensResolved(string) when ens is resolved

      var messages: JsonNode
      var msgCallSuccess: bool
      let msgCallResult = rpcChatMessages(chatId, newJString(""), 20, msgCallSuccess)
      if(msgCallSuccess):
        messages = msgCallResult.parseJson()["result"]

      var reactions: JsonNode
      var reactionsCallSuccess: bool
      let reactionsCallResult = rpcReactions(chatId, newJString(""), 20, reactionsCallSuccess)
      if(reactionsCallSuccess):
        reactions = reactionsCallResult.parseJson()["result"]


      $(%*{
        "chatId": chatId,
        "messages": messages,
        "reactions": reactions
      })

  proc asyncMessageLoaded*(self: ChatsView, rpcResponse: string) {.slot.} =
    let rpcResponseObj = rpcResponse.parseJson

    if(rpcResponseObj["messages"].kind != JNull):
      let chatMessages = parseChatMessagesResponse(rpcResponseObj["chatId"].getStr, rpcResponseObj["messages"])
      self.status.chat.chatMessages(rpcResponseObj["chatId"].getStr, true, chatMessages[0], chatMessages[1])

    if(rpcResponseObj["reactions"].kind != JNull):
      let reactions = parseReactionsResponse(rpcResponseObj["chatId"].getStr, rpcResponseObj["reactions"])
      self.status.chat.chatReactions(rpcResponseObj["chatId"].getStr, true, reactions[0], reactions[1])

  proc hideLoadingIndicator*(self: ChatsView) {.slot.} =
    self.loadingMessages = false
    self.loadingMessagesChanged(false)

  proc setLoadingMessages*(self: ChatsView, value: bool) {.slot.} =
    self.loadingMessages = value
    self.loadingMessagesChanged(value)

  proc isLoadingMessages(self: ChatsView): QVariant {.slot.} =
    return newQVariant(self.loadingMessages)

  QtProperty[QVariant] loadingMessages:
    read = isLoadingMessages
    write = setLoadingMessages
    notify = loadingMessagesChanged

  proc requestMoreMessages*(self: ChatsView, fetchRange: int) {.slot.} =
    self.loadingMessages = true
    self.loadingMessagesChanged(true)

    var allTopics: seq[string] = @[]
    if(self.activeChannel.isTimelineChat):
      for contact in self.status.contacts.getContacts():
        for t in self.status.mailservers.getMailserverTopicsByChatId(getTimelineChatId(contact.id)).map(topic => topic.topic):
          allTopics.add(t)
    else:
      allTopics = self.status.mailservers.getMailserverTopicsByChatId(self.activeChannel.id).map(topic => topic.topic)

    let currentOldestMessageTimestamp = self.oldestMessageTimestamp
    self.oldestMessageTimestamp = self.oldestMessageTimestamp - fetchRange

    self.status.mailservers.requestMessages(allTopics, self.oldestMessageTimestamp, currentOldestMessageTimestamp, true)
    self.oldestMessageTimestampChanged()
    self.messagesLoaded();

  proc leaveChatByIndex*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return
    self.status.chat.leave(selectedChannel.id)
    self.status.mailservers.deleteMailserverTopic(selectedChannel.id)

  proc leaveActiveChat*(self: ChatsView) {.slot.} =
    self.status.chat.leave(self.activeChannel.id)
    self.status.mailservers.deleteMailserverTopic(self.activeChannel.id)

  proc removeChat*(self: ChatsView, chatId: string) =
    discard self.chats.removeChatItemFromList(chatId)
    if (self.messageList.hasKey(chatId)):
      self.messageList[chatId].delete
      self.messageList.del(chatId)

  proc toggleReaction*(self: ChatsView, messageId: string, emojiId: int) {.slot.} =
    if self.activeChannel.id == status_utils.getTimelineChatId():
      let message = self.messageList[status_utils.getTimelineChatId()].getMessageById(messageId)
      self.reactions.toggle(messageId, message.chatId, emojiId)
    else:
      self.reactions.toggle(messageId, self.activeChannel.id, emojiId)

  proc removeMessagesFromTimeline*(self: ChatsView, chatId: string) =
    self.messageList[status_utils.getTimelineChatId()].deleteMessagesByChatId(chatId)
    self.activeChannelChanged()

  proc clearChatHistory*(self: ChatsView, id: string) {.slot.} =
    self.status.chat.clearHistory(id)

  proc clearChatHistoryByIndex*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return
    self.status.chat.clearHistory(selectedChannel.id)

  proc unreadMessages*(self: ChatsView): int {.slot.} =
    result = self.unreadMessageCnt

  proc unreadMessagesCntChanged*(self: ChatsView) {.signal.}

  QtProperty[int] unreadMessagesCount:
    read = unreadMessages
    notify = unreadMessagesCntChanged

  proc calculateUnreadMessages*(self: ChatsView) =
    var unreadTotal = 0
    for chatItem in self.chats.chats:
      unreadTotal = unreadTotal + chatItem.unviewedMessagesCount
    if unreadTotal != self.unreadMessageCnt:
      self.unreadMessageCnt = unreadTotal
      self.unreadMessagesCntChanged()

  proc updateChats*(self: ChatsView, chats: seq[Chat]) =
    for chat in chats:
      if (chat.communityId != ""):
        return
      self.upsertChannel(chat.id)
      self.chats.updateChat(chat)
      if(self.activeChannel.id == chat.id):
        self.activeChannel.setChatItem(chat)
        self.currentSuggestions.setNewData(self.status.contacts.getContacts())
    self.calculateUnreadMessages()

  proc deleteMessage*(self: ChatsView, channelId: string, messageId: string) =
    self.messageList[channelId].deleteMessage(messageId)

  proc isEnsVerified*(self: ChatsView, id: string): bool {.slot.} =
    if id == "": return false
    let contact = self.status.contacts.getContactByID(id)
    if contact == nil:
      return false
    result = contact.ensVerified

  proc formatENSUsername*(self: ChatsView, username: string): string {.slot.} =
    result = status_ens.addDomain(username)

  # Resolving a ENS name
  proc resolveENS*(self: ChatsView, ens: string) {.slot.} =
    spawnAndSend(self, "ensResolved") do: # Call self.ensResolved(string) when ens is resolved
      status_ens.pubkey(ens)

  proc ensWasResolved*(self: ChatsView, resolvedPubKey: string) {.signal.}

  proc ensResolved(self: ChatsView, pubKey: string) {.slot.} =
    self.ensWasResolved(pubKey)

  proc isConnected*(self: ChatsView): bool {.slot.} =
    result = self.status.network.isConnected

  proc onlineStatusChanged(self: ChatsView, connected: bool) {.signal.}

  proc setConnected*(self: ChatsView, connected: bool) =
    self.connected = connected
    self.onlineStatusChanged(connected)

  QtProperty[bool] isOnline:
    read = isConnected
    notify = onlineStatusChanged

  proc muteCurrentChannel*(self: ChatsView) {.slot.} =
    self.activeChannel.mute()
    let channel = self.chats.getChannelById(self.activeChannel.id())
    channel.muted = true
    self.chats.updateChat(channel)

  proc unmuteCurrentChannel*(self: ChatsView) {.slot.} =
    self.activeChannel.unmute()
    let channel = self.chats.getChannelById(self.activeChannel.id())
    channel.muted = false
    self.chats.updateChat(channel)

  proc muteChannel*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return
    if (selectedChannel.id == self.activeChannel.id):
      self.muteCurrentChannel()
      return
    selectedChannel.muted = true
    self.status.chat.muteChat(selectedChannel)
    self.chats.updateChat(selectedChannel)

  proc unmuteChannel*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return
    if (selectedChannel.id == self.activeChannel.id):
      self.unmuteCurrentChannel()
      return
    selectedChannel.muted = false
    self.status.chat.unmuteChat(selectedChannel)
    self.chats.updateChat(selectedChannel)
  

  proc channelIsMuted*(self: ChatsView, channelIndex: int): bool {.slot.} =
    if (self.chats.chats.len == 0): return false
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return false
    result = selectedChannel.muted  

  proc getReactions*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.reactions)

  QtProperty[QVariant] reactions:
    read = getReactions

  proc getStickers*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.stickers)

  QtProperty[QVariant] stickers:
    read = getStickers

  proc getGroups*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.groups)

  QtProperty[QVariant] groups:
    read = getGroups

  proc getTransactions*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.transactions)

  QtProperty[QVariant] transactions:
    read = getTransactions
  proc communitiesChanged*(self: ChatsView) {.signal.}

  proc getCommunitiesIfNotFetched*(self: ChatsView): CommunityList =
    if (not self.communityList.fetched):
      let communities = self.status.chat.getAllComunities()
      self.communityList.setNewData(communities)
      self.communityList.fetched = true
    return self.communityList

  proc getComunities*(self: ChatsView): QVariant {.slot.} =
    return newQVariant(self.getCommunitiesIfNotFetched())

  QtProperty[QVariant] communities:
    read = getComunities
    notify = communitiesChanged

  proc joinedCommunitiesChanged*(self: ChatsView) {.signal.}
    
  proc getJoinedComunities*(self: ChatsView): QVariant {.slot.} =
    if (not self.joinedCommunityList.fetched):
      let communities = self.status.chat.getJoinedComunities()
      self.joinedCommunityList.setNewData(communities)
      self.joinedCommunityList.fetched = true

    return newQVariant(self.joinedCommunityList)

  QtProperty[QVariant] joinedCommunities:
    read = getJoinedComunities
    notify = joinedCommunitiesChanged

  proc addCommunityToList*(self: ChatsView, community: Community) =
    let communityCheck = self.communityList.getCommunityById(community.id)
    if (communityCheck.id == ""):
      self.communityList.addCommunityItemToList(community)
    else:
      self.communityList.replaceCommunity(community)

    if (community.joined == true):
      let joinedCommunityCheck = self.joinedCommunityList.getCommunityById(community.id)
      if (joinedCommunityCheck.id == ""):
        self.joinedCommunityList.addCommunityItemToList(community)
      else:
        self.joinedCommunityList.replaceCommunity(community)

  proc createCommunity*(self: ChatsView, name: string, description: string, color: string, imagePath: string): string {.slot.} =
    result = ""
    try:
        # TODO Change this to get it from the user choices
      let access = ord(CommunityAccessLevel.public)
      var image = image_utils.formatImagePath(imagePath)
      let tmpImagePath = image_resizer(image, 2000, USRTMPDIR)
      let community = self.status.chat.createCommunity(name, description, color, tmpImagePath, access)
      removeFile(tmpImagePath)
     
      if (community.id == ""):
        return "Community was not created. Please try again later"

      self.communityList.addCommunityItemToList(community)
      self.joinedCommunityList.addCommunityItemToList(community)
      self.communitiesChanged()
    except Exception as e:
      error "Error creating the community", msg = e.msg
      result = fmt"Error creating the community: {e.msg}"

  proc createCommunityChannel*(self: ChatsView, communityId: string, name: string, description: string): string {.slot.} =
    result = ""
    try:
      let chat = self.status.chat.createCommunityChannel(communityId, name, description)
     
      if (chat.id == ""):
        return "Chat was not created. Please try again later"

      self.joinedCommunityList.addChannelToCommunity(communityId, chat)
      discard self.activeCommunity.chats.addChatItemToList(chat)
    except Exception as e:
      error "Error creating the channel", msg = e.msg
      result = fmt"Error creating the channel: {e.msg}"

  proc activeCommunityChanged*(self: ChatsView) {.signal.}

  proc setActiveCommunity*(self: ChatsView, communityId: string) {.slot.} =
    if(communityId == ""): return
    self.activeCommunity.setCommunityItem(self.joinedCommunityList.getCommunityById(communityId))
    self.activeCommunity.setActive(true)
    self.activeCommunityChanged()

  proc getActiveCommunity*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.activeCommunity)

  QtProperty[QVariant] activeCommunity:
    read = getActiveCommunity
    write = setActiveCommunity
    notify = activeCommunityChanged

  proc observedCommunityChanged*(self: ChatsView) {.signal.}

  proc setObservedCommunity*(self: ChatsView, communityId: string) {.slot.} =
    if(communityId == ""): return
    var community = self.communityList.getCommunityById(communityId) 
    if (community.id == ""):
      discard self.getCommunitiesIfNotFetched()
      community = self.communityList.getCommunityById(communityId) 
    self.observedCommunity.setCommunityItem(community)
    self.observedCommunityChanged()

  proc getObservedCommunity*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.observedCommunity)

  QtProperty[QVariant] observedCommunity:
    read = getObservedCommunity
    write = setObservedCommunity
    notify = observedCommunityChanged

  proc joinCommunity*(self: ChatsView, communityId: string): string {.slot.} =
    result = ""
    try:
      self.status.chat.joinCommunity(communityId)
      self.joinedCommunityList.addCommunityItemToList(self.communityList.getCommunityById(communityId))
      self.setActiveCommunity(communityId)
    except Exception as e:
      error "Error joining the community", msg = e.msg
      result = fmt"Error joining the community: {e.msg}"

  proc leaveCommunity*(self: ChatsView, communityId: string): string {.slot.} =
    result = ""
    try:
      self.status.chat.leaveCommunity(communityId)
      if (communityId == self.activeCommunity.communityItem.id):
        self.activeCommunity.setActive(false)
      self.joinedCommunityList.removeCommunityItemFromList(communityId)
      var updatedCommunity = self.communityList.getCommunityById(communityId)
      updatedCommunity.joined = false
      self.communityList.replaceCommunity(updatedCommunity)
    except Exception as e:
      error "Error leaving the community", msg = e.msg
      result = fmt"Error leaving the community: {e.msg}"

  proc leaveCurrentCommunity*(self: ChatsView): string {.slot.} =
    result = self.leaveCommunity(self.activeCommunity.communityItem.id)

  proc inviteUserToCommunity*(self: ChatsView, pubKey: string): string {.slot.} =
    try:
      self.status.chat.inviteUserToCommunity(self.activeCommunity.id(), pubKey)
    except Exception as e:
      error "Error inviting to the community", msg = e.msg
      result = fmt"Error inviting to the community: {e.msg}"

  proc exportComumnity*(self: ChatsView): string {.slot.} =
    try:
      result = self.status.chat.exportCommunity(self.activeCommunity.communityItem.id)
    except Exception as e:
      error "Error exporting the community", msg = e.msg
      result = fmt"Error exporting the community: {e.msg}"

  proc importCommunity*(self: ChatsView, communityKey: string) {.slot.} =
    try:
      self.status.chat.importCommunity(communityKey)
    except Exception as e:
      error "Error importing the community", msg = e.msg

  proc removeUserFromCommunity*(self: ChatsView, pubKey: string) {.slot.} =
    try:
      self.status.chat.removeUserFromCommunity(self.activeCommunity.id(), pubKey)
      self.activeCommunity.removeMember(pubKey)
    except Exception as e:
      error "Error removing user from the community", msg = e.msg


  method rowCount*(self: ChatsView, index: QModelIndex = nil): int = 
    result = self.messageList.len

  method data(self: ChatsView, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.messageList.len:
      return
    return newQVariant(toSeq(self.messageList.values)[index.row])

  method roleNames(self: ChatsView): Table[int, string] =
    {
      ChatViewRoles.MessageList.int:"messages"
    }.toTable

  proc getMessageListIndex(self: ChatsView):int {.slot.} =
    var idx = -1
    for msg in toSeq(self.messageList.values):
      idx = idx + 1
      if(self.activeChannel.id == msg.id): return idx
    return idx
