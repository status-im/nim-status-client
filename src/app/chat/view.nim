import NimQml, Tables, json, sequtils, chronicles, strutils, os, strformat
import ../../status/[status]
import ../../status/constants
import ../../status/utils as status_utils
import ../../status/chat as status_chat
import ../../status/messages as status_messages
import ../../status/contacts as status_contacts
import ../../status/ens as status_ens
import ../../status/chat/[chat, message]
import ../../status/profile/profile
import web3/[conversions, ethtypes]
import views/[channels_list, message_list, chat_item, suggestions_list, reactions, stickers, groups, transactions, communities, community_list, community_item, format_input, ens, activity_notification_list, channel, messages, message_item]
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
  GetLinkPreviewDataTaskArg = ref object of QObjectTaskArg
    link: string
    uuid: string
  AsyncActivityNotificationLoadTaskArg = ref object of QObjectTaskArg

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
      messageView*: MessageView
      currentSuggestions*: SuggestionsList
      activityNotificationList*: ActivityNotificationList
      callResult: string
      reactions*: ReactionView
      stickers*: StickersView
      groups*: GroupsView
      transactions*: TransactionsView
      communities*: CommunitiesView
      replyTo: string
      connected: bool
      timelineChat: Chat
      pubKey*: string

  proc setup(self: ChatsView) = self.QAbstractListModel.setup

  proc delete(self: ChatsView) = 
    self.formatInputView.delete
    self.ensView.delete
    self.currentSuggestions.delete
    self.activityNotificationList.delete
    self.reactions.delete
    self.stickers.delete
    self.groups.delete
    self.transactions.delete
    self.communities.delete
    self.QAbstractListModel.delete

  proc newChatsView*(status: Status): ChatsView =
    new(result, delete)
    result.status = status
    result.formatInputView = newFormatInputView()
    result.ensView = newEnsView(status)
    result.communities = newCommunitiesView(status)
    result.channelView = newChannelView(status, result.communities)
    result.messageView = newMessageView(status, result.channelView, result.communities)
    result.connected = false
    result.currentSuggestions = newSuggestionsList()
    result.activityNotificationList = newActivityNotificationList(status)
    result.reactions = newReactionView(status, result.messageView.messageList.addr, result.channelView.activeChannel)
    result.stickers = newStickersView(status, result.channelView.activeChannel)
    result.groups = newGroupsView(status,result.channelView.activeChannel)
    result.transactions = newTransactionsView(status)

    result.setup()

  proc setPubKey*(self: ChatsView, pubKey: string) =
    self.pubKey = pubKey
    self.messageView.pubKey = pubKey

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
    self.messageView.activeChannelChanged()
    self.triggerActiveChannelChange()

  proc getMessageView*(self: ChatsView): QVariant {.slot.} = newQVariant(self.messageView)
  QtProperty[QVariant] messageView:
    read = getMessageView

  proc plainText(self: ChatsView, input: string): string {.slot.} =
    result = plain_text(input)

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

  proc appReady*(self: ChatsView) {.signal.}

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

  proc updateUsernames*(self:ChatsView, contacts: seq[Profile]) =
    if contacts.len > 0:
      # Updating usernames for all the messages list
      for k in self.messageView.messageList.keys:
        self.messageView.messageList[k].updateUsernames(contacts)
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

  proc pushChatItem*(self: ChatsView, chatItem: Chat) =
    discard self.channelView.chats.addChatItemToList(chatItem)
    self.messageView.messagePushed(self.messageView.messageList[chatItem.id].messages.len - 1)

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

  proc asyncActivityNotificationLoad*(self: ChatsView) {.slot.} =
    self.asyncActivityNotificationLoad("asyncActivityNotificationLoaded")

  proc asyncActivityNotificationLoaded*(self: ChatsView, rpcResponse: string) {.slot.} =
    let rpcResponseObj = rpcResponse.parseJson

    if(rpcResponseObj["activityNotifications"].kind != JNull):
      let activityNotifications = parseActivityCenterNotifications(rpcResponseObj["activityNotifications"])
      self.status.chat.activityCenterNotifications(activityNotifications[0], activityNotifications[1])

  proc removeChat*(self: ChatsView, chatId: string) =
    discard self.channelView.chats.removeChatItemFromList(chatId)
    if (self.messageView.messageList.hasKey(chatId)):
      let index = self.messageView.getMessageListIndexById(chatId)
      self.beginRemoveRows(newQModelIndex(), index, index)
      self.messageView.messageList[chatId].delete
      self.messageView.messageList.del(chatId)
      self.endRemoveRows()

  proc toggleReaction*(self: ChatsView, messageId: string, emojiId: int) {.slot.} =
    if self.channelView.activeChannel.id == status_utils.getTimelineChatId():
      let message = self.messageView.messageList[status_utils.getTimelineChatId()].getMessageById(messageId)
      self.reactions.toggle(messageId, message.chatId, emojiId)
    else:
      self.reactions.toggle(messageId, self.channelView.activeChannel.id, emojiId)

  proc removeMessagesFromTimeline*(self: ChatsView, chatId: string) =
    self.messageView.messageList[status_utils.getTimelineChatId()].deleteMessagesByChatId(chatId)
    self.channelView.activeChannelChanged()

  proc updateChats*(self: ChatsView, chats: seq[Chat]) =
    for chat in chats:
      if (chat.communityId != ""):
        self.communities.updateCommunityChat(chat)
        return
      self.messageView.upsertChannel(chat.id)
      self.channelView.chats.updateChat(chat)
      if(self.channelView.activeChannel.id == chat.id):
        self.channelView.activeChannel.setChatItem(chat)
        self.activeChannelChanged()
        self.currentSuggestions.setNewData(self.status.contacts.getContacts())
      if self.channelView.contextChannel.id == chat.id:
        self.channelView.contextChannel.setChatItem(chat)
        self.channelView.contextChannelChanged()
    self.messageView.calculateUnreadMessages()

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

  proc isActiveMailserverResult(self: ChatsView, resultEncoded: string) {.slot.} =
    let isActiveMailserverAvailable = decode[bool](resultEncoded)
    if isActiveMailserverAvailable:
      self.messageView.setLoadingMessages(true)
      let
        mailserverWorker = self.status.tasks.marathon[MailserverWorker().name]
        task = RequestMessagesTaskArg(`method`: "requestMessages")
      mailserverWorker.start(task)

  proc requestAllHistoricMessagesResult(self: ChatsView, resultEncoded: string) {.slot.} =
    self.messageView.setLoadingMessages(true)

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
    self.channelView.setActiveChannel(channel)
    self.messageView.activeChannelChanged()

  proc requestMoreMessages*(self: ChatsView, fetchRange: int) {.slot.} =
    self.messageView.loadingMessages = true
    self.messageView.loadingMessagesChanged(true)
    let mailserverWorker = self.status.tasks.marathon[MailserverWorker().name]
    let task = RequestMessagesTaskArg( `method`: "requestMoreMessages", chatId: self.channelView.activeChannel.id)
    mailserverWorker.start(task)

  proc pushMessages*(self: ChatsView, messages: var seq[Message]) =
    self.messageView.pushMessages(messages)

  proc pushPinnedMessages*(self: ChatsView, pinnedMessages: var seq[Message]) =
    self.messageView.pushPinnedMessages(pinnedMessages)

  proc hideLoadingIndicator*(self: ChatsView) {.slot.} =
    self.messageView.hideLoadingIndicator()

  proc deleteMessage*(self: ChatsView, channelId: string, messageId: string) =
    self.messageView.deleteMessage(channelId, messageId)

  proc addPinnedMessages*(self: ChatsView, pinnedMessages: seq[Message]) =
    self.messageView.addPinnedMessages(pinnedMessages)

  proc clearMessages*(self: ChatsView, id: string) =
    self.messageView.clearMessages(id)

  proc asyncMessageLoad*(self: ChatsView, chatId: string) {.slot.} =
    self.messageView.asyncMessageLoad(chatId)

  proc calculateUnreadMessages*(self: ChatsView) =
    self.messageView.calculateUnreadMessages()

  proc sendingMessage*(self: ChatsView) = 
    self.messageView.sendingMessage()

  proc sendingMessageFailed*(self: ChatsView) =
    self.messageView.sendingMessageFailed()

  proc markMessageAsSent*(self: ChatsView, chat: string, messageId: string) =
    self.messageView.markMessageAsSent(chat, messageId)
