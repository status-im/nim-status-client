import NimQml, Tables, json, sequtils, chronicles, times, re, sugar, strutils, os, strformat, algorithm
import ../../status/[status, mailservers]
import ../../status/constants
import ../../status/utils as status_utils
import ../../status/chat as status_chat
import ../../status/messages as status_messages
import ../../status/contacts as status_contacts
import ../../status/ens as status_ens
import ../../status/chat/[chat, message]
import ../../status/profile/profile
import web3/[conversions, ethtypes]
import views/[channels_list, message_list, chat_item, suggestions_list, reactions, stickers, groups, transactions, communities, community_list, community_item, format_input, ens, activity_notification_list, channel]
import ../utils/image_utils
import ../../status/tasks/[qt, task_runner_impl]
import ../../status/tasks/marathon/mailserver/worker
import ../../status/signals/types as signal_types
import ../../status/types

# TODO: remove me
import ../../status/libstatus/chat as libstatus_chat

logScope:
  topics = "chats-view"

type
  ChatViewRoles {.pure.} = enum
    MessageList = UserRole + 1
  GetLinkPreviewDataTaskArg = ref object of QObjectTaskArg
    link: string
    uuid: string
  AsyncActivityNotificationLoadTaskArg = ref object of QObjectTaskArg
  AsyncMessageLoadTaskArg = ref object of QObjectTaskArg
    chatId: string

const getLinkPreviewDataTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[GetLinkPreviewDataTaskArg](argEncoded)
  var success: bool
  let
    response = status_chat.getLinkPreviewData(arg.link, success)
    responseJson = %* { "result": %response, "success": %success, "uuid": %arg.uuid }
  arg.finish(responseJson)

proc getLinkPreviewData[T](self: T, slot: string, link: string, uuid: string) =
  let arg = GetLinkPreviewDataTaskArg(
    tptr: cast[ByteAddress](getLinkPreviewDataTask),
    vptr: cast[ByteAddress](self.vptr),
    slot: slot,
    link: link,
    uuid: uuid
  )
  self.status.tasks.threadpool.start(arg)

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

const asyncActivityNotificationLoadTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncActivityNotificationLoadTaskArg](argEncoded)
  var activityNotifications: JsonNode
  var activityNotificationsCallSuccess: bool
  let activityNotificationsCallResult = libstatus_chat.rpcActivityCenterNotifications(newJString(""), 20, activityNotificationsCallSuccess)
  if(activityNotificationsCallSuccess):
    activityNotifications = activityNotificationsCallResult.parseJson()["result"]

  let responseJson = %*{
    "activityNotifications": activityNotifications
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

proc asyncActivityNotificationLoad[T](self: T, slot: string) =
  let arg = AsyncActivityNotificationLoadTaskArg(
    tptr: cast[ByteAddress](asyncActivityNotificationLoadTask),
    vptr: cast[ByteAddress](self.vptr),
    slot: slot
  )
  self.status.tasks.threadpool.start(arg)

QtObject:
  type
    ChatsView* = ref object of QAbstractListModel
      status: Status
      formatInputView: FormatInputView
      ensView: EnsView
      channelView*: ChannelView
      currentSuggestions*: SuggestionsList
      activityNotificationList*: ActivityNotificationList
      callResult: string
      messageList*: ChatMessageList
      pinnedMessagesList*: ChatMessageList
      timelineMessageList*: ChatMessageList
      reactions*: ReactionView
      stickers*: StickersView
      groups*: GroupsView
      transactions*: TransactionsView
      communities*: CommunitiesView
      replyTo: string
      channelOpenTime*: Table[string, int64]
      connected: bool
      unreadMessageCnt: int
      loadingMessages: bool
      timelineChat: Chat
      pubKey*: string

  proc setup(self: ChatsView) = self.QAbstractListModel.setup

  proc delete(self: ChatsView) = 
    self.formatInputView.delete
    self.ensView.delete
    self.currentSuggestions.delete
    self.activityNotificationList.delete
    self.messageList.delete
    self.pinnedMessagesList.delete
    self.timelineMessageList.delete
    self.reactions.delete
    self.stickers.delete
    self.groups.delete
    self.transactions.delete
    self.communities.delete
    self.channelOpenTime = initTable[string, int64]()
    self.QAbstractListModel.delete

  proc newChatsView*(status: Status): ChatsView =
    new(result, delete)
    result.status = status
    result.formatInputView = newFormatInputView()
    result.ensView = newEnsView(status)
    result.communities = newCommunitiesView(status)
    result.channelView = newChannelView(status, result.communities)
    result.connected = false
    result.currentSuggestions = newSuggestionsList()
    result.activityNotificationList = newActivityNotificationList(status)
    result.messageList = newChatMessageList("", status, true)
    result.pinnedMessagesList = newChatMessageList("", status, false)
    result.timelineMessageList = newChatMessageList(status_utils.getTimelineChatId(), result.status, false)
    result.reactions = newReactionView(status, result.messageList.addr, result.timelineMessageList.addr, result.channelView.activeChannel)
    result.stickers = newStickersView(status, result.channelView.activeChannel)
    result.groups = newGroupsView(status,result.channelView.activeChannel)
    result.transactions = newTransactionsView(status)
    result.unreadMessageCnt = 0
    result.loadingMessages = false

    result.setup()

  proc getFormatInput(self: ChatsView): QVariant {.slot.} = newQVariant(self.formatInputView)
  QtProperty[QVariant] formatInputView:
    read = getFormatInput

  proc getEns(self: ChatsView): QVariant {.slot.} = newQVariant(self.ensView)
  QtProperty[QVariant] ensView:
    read = getEns

  proc getCommunities*(self: ChatsView): QVariant {.slot.} = newQVariant(self.communities)
  QtProperty[QVariant] communities:
    read = getCommunities

  proc getChannelView*(self: ChatsView): QVariant {.slot.} = newQVariant(self.channelView)
  QtProperty[QVariant] channelView:
    read = getChannelView

  proc triggerActiveChannelChange*(self:ChatsView) {.signal.}

  proc activeChannelChanged*(self: ChatsView) {.slot.} =
    self.channelView.activeChannelChanged()
    self.triggerActiveChannelChange()

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

  proc sendMessage*(self: ChatsView, message: string, replyTo: string, contentType: int = ContentType.Message.int, isStatusUpdate: bool = false, contactsString: string = "") {.slot.} =
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

    self.status.chat.sendMessage(channelId, m, replyTo, contentType)
 
  proc verifyMessageSent*(self: ChatsView, data: string) {.slot.} =
    let messageData = data.parseJson
    if messageData["chatId"].getStr != self.channelView.activeChannel.id: return
    self.messageList.checkTimeout(messageData["id"].getStr)                          # TODO: extract timeout check to chat/view

  proc resendMessage*(self: ChatsView, chatId: string, messageId: string) {.slot.} =
    self.status.messages.trackMessage(messageId, chatId)
    self.status.chat.resendMessage(messageId)
    if chatId != self.channelView.activeChannel.id: return
    self.messageList.resetTimeOut(messageId)   # TODO: extract timeout check to chat/view

  proc sendImage*(self: ChatsView, imagePath: string, isStatusUpdate: bool = false): string {.slot.} =
    result = ""
    try:
      var image = image_utils.formatImagePath(imagePath)
      let tmpImagePath = image_resizer(image, 2000, TMPDIR)

      var channelId = self.channelView.activeChannel.id
      
      if isStatusUpdate:
        channelId = "@" & self.pubKey

      self.status.chat.sendImage(channelId, tmpImagePath)
      removeFile(tmpImagePath)
    except Exception as e:
      error "Error sending the image", msg = e.msg
      result = fmt"Error sending the image: {e.msg}"

  proc sendImages*(self: ChatsView, imagePathsArray: string): string {.slot.} =
    result = ""
    try:
      var images = Json.decode(imagePathsArray, seq[string])
      let channelId = self.channelView.activeChannel.id

      for imagePath in images.mitems:
        var image = image_utils.formatImagePath(imagePath)
        imagePath = image_resizer(image, 2000, TMPDIR)

      self.status.chat.sendImages(channelId, images)

      for imagePath in images.items:
        removeFile(imagePath)
    except Exception as e:
      error "Error sending images", msg = e.msg
      result = fmt"Error sending images: {e.msg}"

  proc sendingMessage*(self: ChatsView) {.signal.}

  proc appReady*(self: ChatsView) {.signal.}

  proc sendingMessageFailed*(self: ChatsView) {.signal.}

  proc alias*(self: ChatsView, pubKey: string): string {.slot.} =
    if (pubKey == ""):
      return ""
    generateAlias(pubKey)

  proc userNameOrAlias*(self: ChatsView, pubKey: string): string {.slot.} =
    if self.status.chat.contacts.hasKey(pubKey):
      return status_ens.userNameOrAlias(self.status.chat.contacts[pubKey])
    generateAlias(pubKey)

  proc getCurrentSuggestions(self: ChatsView): QVariant {.slot.} =
    return newQVariant(self.currentSuggestions)

  QtProperty[QVariant] suggestionList:
    read = getCurrentSuggestions

  proc activityNotificationsChanged*(self: ChatsView) {.signal.}

  proc getActivityNotificationList(self: ChatsView): QVariant {.slot.} =
    return newQVariant(self.activityNotificationList)

  QtProperty[QVariant] activityNotificationList:
    read = getActivityNotificationList
    notify = activityNotificationsChanged

  proc upsertChannel(self: ChatsView, channel: string) =
    var chat: Chat = nil
    if self.status.chat.channels.hasKey(channel):
      chat = self.status.chat.channels[channel]
    else:
      chat = self.communities.getChannel(channel)
      self.channelOpenTime[channel] = now().toTime.toUnix * 1000

  proc messagePushed*(self: ChatsView, messageIndex: int) {.signal.}
  proc newMessagePushed*(self: ChatsView) {.signal.}

  proc messageNotificationPushed*(self: ChatsView, chatId: string, text: string, messageType: string, chatType: int, timestamp: string, identicon: string, username: string, hasMention: bool, isAddedContact: bool, channelName: string) {.signal.}

  proc messagesCleared*(self: ChatsView) {.signal.}

  proc clearMessages*(self: ChatsView) =
    self.messageList.clear(true)
    self.pinnedMessagesList.clear(false)
    self.messagesCleared()

  proc isAddedContact*(self: ChatsView, id: string): bool {.slot.} =
    result = self.status.contacts.isAdded(id)

  proc pushPinnedMessages*(self:ChatsView, pinnedMessages: var seq[Message]) =
    for msg in pinnedMessages.mitems:
      self.upsertChannel(msg.chatId)

      if msg.chatId != self.channelView.activeChannel.id: continue

      var message = self.messageList.getMessageById(msg.id)
      message.pinnedBy = msg.pinnedBy
      message.isPinned = true

      self.pinnedMessagesList.add(message)
      # put the message as pinned in the message list
      self.messageList.changeMessagePinned(msg.id, true, msg.pinnedBy)

  proc pushActivityCenterNotifications*(self:ChatsView, activityCenterNotifications: seq[ActivityCenterNotification]) =
    self.activityNotificationList.addActivityNotificationItemsToList(activityCenterNotifications)
    self.activityNotificationsChanged()

  proc addActivityCenterNotification*(self:ChatsView, activityCenterNotifications: seq[ActivityCenterNotification]) =
    for activityCenterNotification in activityCenterNotifications:
      self.activityNotificationList.addActivityNotificationItemToList(activityCenterNotification)
    self.activityNotificationsChanged()

  proc setActiveChannelToTimeline*(self: ChatsView) {.slot.} =
    if not self.channelView.activeChannel.chatItem.isNil:
      self.channelView.previousActiveChannelIndex = self.channelView.chats.chats.findIndexById(self.channelView.activeChannel.id)
    self.channelView.activeChannel.setChatItem(self.timelineChat)
    self.activeChannelChanged()

  proc pushMessages*(self:ChatsView, messages: var seq[Message]) =
    for msg in messages.mitems:
      self.upsertChannel(msg.chatId)
      msg.userName = self.status.chat.getUserName(msg.fromAuthor, msg.alias)
      var msgIndex:int;
      if self.status.chat.channels.hasKey(msg.chatId):
        let chat = self.status.chat.channels[msg.chatId]
        if (chat.chatType == ChatType.Profile):
          let timelineChatId = status_utils.getTimelineChatId()
          self.timelineMessageList.add(msg)
          if self.channelView.activeChannel.id == timelineChatId: 
            self.activeChannelChanged()
          msgIndex = self.timelineMessageList.messages.len - 1
        else:
          if msg.chatId != self.channelView.activeChannel.id: continue
          self.messageList.add(msg)
          msgIndex = self.messageList.messages.len - 1
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
          self.messageNotificationPushed(msg.chatId, escape_html(msg.text), msg.messageType, channel.chatType.int, msg.timestamp, msg.identicon, msg.userName, msg.hasMention, isAddedContact, channel.name)

  proc updateUsernames*(self:ChatsView, contacts: seq[Profile]) =
    if contacts.len > 0:
      self.messageList.updateUsernames(contacts)
      self.channelView.activeChannel.contactsUpdated()

  proc updateChannelForContacts*(self: ChatsView, contacts: seq[Profile]) =
    for contact in contacts:
      let channel = self.channelView.chats.getChannelById(contact.id)
      if not channel.isNil:
        if contact.localNickname == "":
          if channel.name == "" or channel.name == channel.id:
            if channel.ensName != "":
              channel.name = channel.ensName
            else: 
              channel.name = contact.username
        else:
          channel.name = contact.localNickname
        self.channelView.chats.updateChat(channel)
        if (self.channelView.activeChannel.id == channel.id):
          self.channelView.activeChannel.setChatItem(channel)
          self.activeChannelChanged()


  proc markMessageAsSent*(self:ChatsView, chat: string, messageId: string) =
    if chat != self.channelView.activeChannel.id: return
    self.messageList.markMessageAsSent(messageId)      
  
  proc getMessageIndex(self: ChatsView, chatId: string, messageId: string): int {.slot.} =
    if chatId != self.channelView.activeChannel.id: return -1
    result = self.messageList.getMessageIndex(messageId)

  proc getMessageData(self: ChatsView, chatId: string,  index: int, data: string): string {.slot.} =
    if chatId != self.channelView.activeChannel.id: return
    return self.messageList.getMessageData(index, data)

  proc getMessageList(self: ChatsView): QVariant {.slot.} =
    self.upsertChannel(self.channelView.activeChannel.id)
    return newQVariant(self.messageList)

  QtProperty[QVariant] messageList:
    read = getMessageList
    notify = triggerActiveChannelChange

  proc getTimelineMessageList(self: ChatsView): QVariant {.slot.} =
    return newQVariant(self.timelineMessageList)

  QtProperty[QVariant] timelineMessageList:
    read = getTimelineMessageList

  proc getPinnedMessagesList(self: ChatsView): QVariant {.slot.} =
    self.upsertChannel(self.channelView.activeChannel.id)
    return newQVariant(self.pinnedMessagesList)

  QtProperty[QVariant] pinnedMessagesList:
    read = getPinnedMessagesList
    notify = triggerActiveChannelChange

  proc setTimelineChat*(self: ChatsView, chatItem: Chat) =
    self.timelineChat = chatItem

  proc copyToClipboard*(self: ChatsView, content: string) {.slot.} =
    setClipBoardText(content)

  proc linkPreviewDataWasReceived*(self: ChatsView, previewData: string) {.signal.}

  proc linkPreviewDataReceived(self: ChatsView, previewData: string) {.slot.} =
    self.linkPreviewDataWasReceived(previewData)

  proc getLinkPreviewData*(self: ChatsView, link: string, uuid: string) {.slot.} =
    self.getLinkPreviewData("linkPreviewDataReceived", link, uuid)

  proc getChatType*(self: ChatsView, channel: string): int {.slot.} =
    let selectedChannel = self.channelView.getChannelById(channel)
    if selectedChannel == nil:
      return -1
    selectedChannel.chatType.int

  proc messagesLoaded*(self: ChatsView) {.signal.}

  proc loadMoreMessages*(self: ChatsView) {.slot.} =
    debug "Loading more messages", chaId = self.channelView.activeChannel.id
    self.status.chat.chatMessages(self.channelView.activeChannel.id, false)
    self.status.chat.chatReactions(self.channelView.activeChannel.id, false)
    self.messagesLoaded();

  proc loadMoreMessagesWithIndex*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.channelView.chats.chats.len == 0): return
    let selectedChannel = self.channelView.getChannel(channelIndex)
    if (selectedChannel == nil): return
    debug "Loading more messages with idx", chaId = selectedChannel.id
    self.status.chat.chatMessages(selectedChannel.id, false)
    self.status.chat.chatReactions(selectedChannel.id, false)
    self.messagesLoaded();

  proc loadingMessagesChanged*(self: ChatsView, value: bool) {.signal.}

  proc asyncMessageLoad*(self: ChatsView, chatId: string) {.slot.} =
    self.asyncMessageLoad("asyncMessageLoaded", chatId)

  proc asyncActivityNotificationLoad*(self: ChatsView) {.slot.} =
    self.asyncActivityNotificationLoad("asyncActivityNotificationLoaded")

  proc asyncMessageLoaded*(self: ChatsView, rpcResponse: string) {.slot.} =
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
      let pinnedMessages = libstatus_chat.parseChatMessagesResponse(pinnedMsgs)
      self.status.chat.pinnedMessagesByChatID(chatId, pinnedMessages[0], pinnedMessages[1])

  proc asyncActivityNotificationLoaded*(self: ChatsView, rpcResponse: string) {.slot.} =
    let rpcResponseObj = rpcResponse.parseJson

    if(rpcResponseObj["activityNotifications"].kind != JNull):
      let activityNotifications = parseActivityCenterNotifications(rpcResponseObj["activityNotifications"])
      self.status.chat.activityCenterNotifications(activityNotifications[0], activityNotifications[1])

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
    let mailserverWorker = self.status.tasks.marathon[MailserverWorker().name]
    let task = RequestMessagesTaskArg( `method`: "requestMoreMessages", chatId: self.channelView.activeChannel.id)
    mailserverWorker.start(task)

  proc fillGaps*(self: ChatsView, messageId: string) {.slot.} =
    self.loadingMessages = true
    self.loadingMessagesChanged(true)
    discard self.status.mailservers.fillGaps(self.channelView.activeChannel.id, @[messageId])

  proc removeChat*(self: ChatsView, chatId: string) =
    discard self.channelView.chats.removeChatItemFromList(chatId)

  proc toggleReaction*(self: ChatsView, messageId: string, emojiId: int) {.slot.} =
    if self.channelView.activeChannel.id == status_utils.getTimelineChatId():
      let message = self.timelineMessageList.getMessageById(messageId)
      self.reactions.toggle(messageId, message.chatId, emojiId)
    else:
      self.reactions.toggle(messageId, self.channelView.activeChannel.id, emojiId)

  proc removeMessagesFromTimeline*(self: ChatsView, chatId: string) =
    self.timelineMessageList.deleteMessagesByChatId(chatId)
    self.activeChannelChanged()

  proc unreadMessages*(self: ChatsView): int {.slot.} =
    result = self.unreadMessageCnt

  proc unreadMessagesCntChanged*(self: ChatsView) {.signal.}

  QtProperty[int] unreadMessagesCount:
    read = unreadMessages
    notify = unreadMessagesCntChanged

  proc calculateUnreadMessages*(self: ChatsView) =
    var unreadTotal = 0
    for chatItem in self.channelView.chats.chats:
      unreadTotal = unreadTotal + chatItem.unviewedMessagesCount
    if unreadTotal != self.unreadMessageCnt:
      self.unreadMessageCnt = unreadTotal
      self.unreadMessagesCntChanged()

  proc updateChats*(self: ChatsView, chats: seq[Chat]) =
    for chat in chats:
      if (chat.communityId != ""):
        self.communities.updateCommunityChat(chat)
        return
      self.upsertChannel(chat.id)
      self.channelView.chats.updateChat(chat)
      if(self.channelView.activeChannel.id == chat.id):
        self.channelView.activeChannel.setChatItem(chat)
        self.activeChannelChanged()
        self.currentSuggestions.setNewData(self.status.contacts.getContacts())
      if self.channelView.contextChannel.id == chat.id:
        self.channelView.contextChannel.setChatItem(chat)
        self.channelView.contextChannelChanged()
    self.calculateUnreadMessages()

  proc deleteMessage*(self: ChatsView, channelId: string, messageId: string) =
    if channelId != self.channelView.activeChannel.id: return
    self.messageList.deleteMessage(messageId)

  proc isConnected*(self: ChatsView): bool {.slot.} =
    result = self.status.network.isConnected

  proc onlineStatusChanged(self: ChatsView, connected: bool) {.signal.}

  proc setConnected*(self: ChatsView, connected: bool) =
    self.connected = connected
    self.onlineStatusChanged(connected)

  QtProperty[bool] isOnline:
    read = isConnected
    notify = onlineStatusChanged

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

  proc removeMessagesByUserId(self: ChatsView, publicKey: string) {.slot.} =
    self.messageList.removeMessagesByUserId(publicKey)

  proc addPinMessage*(self: ChatsView, messageId: string, chatId: string, pinnedBy: string) =
    self.upsertChannel(chatId)
    if chatId != self.channelView.activeChannel.id: return
    self.messageList.changeMessagePinned(messageId, true, pinnedBy)
    var message = self.messageList.getMessageById(messageId)
    message.pinnedBy = pinnedBy
    self.pinnedMessagesList.add(message)

  proc removePinMessage*(self: ChatsView, messageId: string, chatId: string) =
    self.upsertChannel(chatId)
    if chatId != self.channelView.activeChannel.id: return
    self.messageList.changeMessagePinned(messageId, false, "")
    try:
      self.pinnedMessagesList.remove(messageId)
    except Exception as e:
      error "Error removing ", msg = e.msg

  proc pinMessage*(self: ChatsView, messageId: string, chatId: string) {.slot.} =
    self.status.chat.setPinMessage(messageId, chatId, true)
    self.addPinMessage(messageId, chatId, self.pubKey)

  proc unPinMessage*(self: ChatsView, messageId: string, chatId: string) {.slot.} =
    self.status.chat.setPinMessage(messageId, chatId, false)
    self.removePinMessage(messageId, chatId)

  proc addPinnedMessages*(self: ChatsView, pinnedMessages: seq[Message]) =
    for pinnedMessage in pinnedMessages:
      if (pinnedMessage.isPinned):
        self.addPinMessage(pinnedMessage.id, pinnedMessage.localChatId, pinnedMessage.pinnedBy)
      else:
        self.removePinMessage(pinnedMessage.id, pinnedMessage.localChatId)

  proc isActiveMailserverResult(self: ChatsView, resultEncoded: string) {.slot.} =
    let isActiveMailserverAvailable = decode[bool](resultEncoded)
    if isActiveMailserverAvailable:
      self.setLoadingMessages(true)
      let
        mailserverWorker = self.status.tasks.marathon[MailserverWorker().name]
        task = RequestMessagesTaskArg(`method`: "requestMessages")
      mailserverWorker.start(task)

  proc requestAllHistoricMessagesResult(self: ChatsView, resultEncoded: string) {.slot.} =
    self.setLoadingMessages(true)

  proc createCommunityChannel*(self: ChatsView, communityId: string, name: string, description: string, categoryId: string): string {.slot.} =
    try:
      let chat = self.status.chat.createCommunityChannel(communityId, name, description)
      if categoryId != "":
        self.status.chat.reorderCommunityChannel(communityId, categoryId, chat.id.replace(communityId, ""), 0)

      chat.categoryId = categoryId
      self.communities.joinedCommunityList.addChannelToCommunity(communityId, chat)
      self.communities.activeCommunity.addChatItemToList(chat)
      self.channelView.setActiveChannel(chat.id)
    except RpcException as e:
      error "Error creating channel", msg=e.msg, name, description
      result = StatusGoError(error: e.msg).toJson

  proc editCommunityChannel*(self: ChatsView, communityId: string, channelId: string, name: string, description: string, categoryId: string): string {.slot.} =
    try:
      let chat = self.status.chat.editCommunityChannel(communityId, channelId, name, description)

      chat.categoryId = categoryId
      self.communities.joinedCommunityList.replaceChannelInCommunity(communityId, chat)
      self.communities.activeCommunity.updateChatItemInList(chat)
      self.channelView.setActiveChannel(chat.id)
    except RpcException as e:
      error "Error editing channel", msg=e.msg, channelId, name, description
      result = StatusGoError(error: e.msg).toJson

  proc getChannelNameById*(self: ChatsView, channelId: string): string {.slot.} =
    if self.status.chat.channels.hasKey(channelId):
      result = self.status.chat.channels[channelId].name

  proc setActiveChannelByIndex*(self: ChatsView, index: int) {.slot.} =
    self.channelView.setActiveChannelByIndex(index)

  proc restorePreviousActiveChannel*(self: ChatsView) {.slot.} =
    self.channelView.restorePreviousActiveChannel()

  proc setActiveChannel*(self: ChatsView, channel: string) {.slot.} =
    let timelineChatId = status_utils.getTimelineChatId()
    if channel != timelineChatId:
      self.channelView.setActiveChannel(channel)

