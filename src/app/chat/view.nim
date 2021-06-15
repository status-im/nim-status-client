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
import views/[channels_list, message_list, chat_item, suggestions_list, reactions, stickers, groups, transactions, communities, community_list, community_item, format_input]
import ../utils/image_utils
import ../../status/tasks/[qt, task_runner_impl]
import ../../status/tasks/marathon/mailserver/worker

logScope:
  topics = "chats-view"

type
  ChatViewRoles {.pure.} = enum
    MessageList = UserRole + 1
  GetLinkPreviewDataTaskArg = ref object of QObjectTaskArg
    link: string
    uuid: string
  AsyncMessageLoadTaskArg = ref object of QObjectTaskArg
    chatId: string
  ResolveEnsTaskArg = ref object of QObjectTaskArg
    ens: string

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

proc asyncMessageLoad[T](self: T, slot: string, chatId: string) =
  let arg = AsyncMessageLoadTaskArg(
    tptr: cast[ByteAddress](asyncMessageLoadTask),
    vptr: cast[ByteAddress](self.vptr),
    slot: slot,
    chatId: chatId
  )
  self.status.tasks.threadpool.start(arg)

const resolveEnsTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let
    arg = decode[ResolveEnsTaskArg](argEncoded)
    output = %* { "address": status_ens.address(arg.ens), "pubkey": status_ens.pubkey(arg.ens) }
  arg.finish(output)

proc resolveEns[T](self: T, slot: string, ens: string) =
  let arg = ResolveEnsTaskArg(
    tptr: cast[ByteAddress](resolveEnsTask),
    vptr: cast[ByteAddress](self.vptr),
    slot: slot,
    ens: ens
  )
  self.status.tasks.threadpool.start(arg)

QtObject:
  type
    ChatsView* = ref object of QAbstractListModel
      status: Status
      formatInputView: FormatInputView
      chats*: ChannelsList
      currentSuggestions*: SuggestionsList
      callResult: string
      messageList*: OrderedTable[string, ChatMessageList]
      pinnedMessagesList*: OrderedTable[string, ChatMessageList]
      reactions*: ReactionView
      stickers*: StickersView
      groups*: GroupsView
      transactions*: TransactionsView
      activeChannel*: ChatItemView
      contextChannel*: ChatItemView
      communities*: CommunitiesView
      previousActiveChannelIndex: int
      replyTo: string
      channelOpenTime*: Table[string, int64]
      connected: bool
      unreadMessageCnt: int
      loadingMessages: bool
      timelineChat: Chat
      pubKey*: string

  proc setup(self: ChatsView) = self.QAbstractListModel.setup

  proc delete(self: ChatsView) = 
    self.chats.delete
    self.formatInputView.delete
    self.activeChannel.delete
    self.contextChannel.delete
    self.currentSuggestions.delete
    for msg in self.messageList.values:
      msg.delete
    for msg in self.pinnedMessagesList.values:
      msg.delete
    self.reactions.delete
    self.stickers.delete
    self.groups.delete
    self.transactions.delete
    self.messageList = initOrderedTable[string, ChatMessageList]()
    self.pinnedMessagesList = initOrderedTable[string, ChatMessageList]()
    self.communities.delete
    self.channelOpenTime = initTable[string, int64]()
    self.QAbstractListModel.delete

  proc newChatsView*(status: Status): ChatsView =
    new(result, delete)
    result.status = status
    result.formatInputView = newFormatInputView()

    result.connected = false
    result.chats = newChannelsList(status)
    result.activeChannel = newChatItemView(status)
    result.contextChannel = newChatItemView(status)
    result.currentSuggestions = newSuggestionsList()
    result.messageList = initOrderedTable[string, ChatMessageList]()
    result.pinnedMessagesList = initOrderedTable[string, ChatMessageList]()
    result.reactions = newReactionView(status, result.messageList.addr, result.activeChannel)
    result.stickers = newStickersView(status, result.activeChannel)
    result.groups = newGroupsView(status,result.activeChannel)
    result.transactions = newTransactionsView(status)
    result.communities = newCommunitiesView(status)
    result.unreadMessageCnt = 0
    result.loadingMessages = false
    result.previousActiveChannelIndex = -1
    result.messageList[status_utils.getTimelineChatId()] = newChatMessageList(status_utils.getTimelineChatId(), result.status, false)

    result.setup()

  proc getFormatInput(self: ChatsView): QVariant {.slot.} = newQVariant(self.formatInputView)
  QtProperty[QVariant] formatInputView:
    read = getFormatInput

  proc getMessageListIndexById(self: ChatsView, id: string): int

  proc getChannel*(self: ChatsView, index: int): Chat =
    if (self.communities.activeCommunity.active):
      return self.communities.activeCommunity.chats.getChannel(index)
    else:
      return self.chats.getChannel(index)
  
  proc getCommunityChannelById(self: ChatsView, channel: string): Chat =
    let index = self.communities.activeCommunity.chats.chats.findIndexById(channel)
    if (index > -1):
      return self.communities.activeCommunity.chats.getChannel(index)
    let chan = self.communities.activeCommunity.chats.getChannelByName(channel)
    if not chan.isNil:
      return chan

  proc getChannelById*(self: ChatsView, channel: string): Chat =
    if self.communities.activeCommunity.active:
      result = self.getCommunityChannelById(channel)
      if not result.isNil:
        return result
    # even if communities are active, if we don't find a chat, it's possibly
    # because we are looking for a normal chat, so continue below
    let index = self.chats.chats.findIndexById(channel)
    if index > -1:
      return self.chats.getChannel(index)

  proc updateChannelInRightList*(self: ChatsView, channel: Chat) =
    if (self.communities.activeCommunity.active):
      self.communities.activeCommunity.chats.updateChat(channel)
    else:
      self.chats.updateChat(channel)

  proc getChatsList(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.chats)

  QtProperty[QVariant] chats:
    read = getChatsList

  proc getCommunities*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.communities)

  QtProperty[QVariant] communities:
    read = getCommunities

  proc getChannelColor*(self: ChatsView, channel: string): string {.slot.} =
    if (channel == ""): return
    let selectedChannel = self.getChannelById(channel)
    if (selectedChannel.isNil or selectedChannel.id == "") : return
    return selectedChannel.color

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
      let tmpImagePath = image_resizer(image, 2000, TMPDIR)

      var channelId = self.activeChannel.id
      
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
      let channelId = self.activeChannel.id

      for imagePath in images.mitems:
        var image = image_utils.formatImagePath(imagePath)
        imagePath = image_resizer(image, 2000, TMPDIR)

      self.status.chat.sendImages(channelId, images)

      for imagePath in images.items:
        removeFile(imagePath)
    except Exception as e:
      error "Error sending images", msg = e.msg
      result = fmt"Error sending images: {e.msg}"

  proc activeChannelChanged*(self: ChatsView) {.signal.}

  proc contextChannelChanged*(self: ChatsView) {.signal.}

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

  proc markAllChannelMessagesReadByIndex*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return
    discard self.status.chat.markAllChannelMessagesRead(selectedChannel.id)

  proc clearUnreadIfNeeded*(self: ChatsView, channel: var Chat) =
    if (not channel.isNil and (channel.unviewedMessagesCount > 0 or channel.hasMentions)):
      var response = self.status.chat.markAllChannelMessagesRead(channel.id)
      if not response.hasKey("error"):
        self.chats.clearUnreadMessagesCount(channel)

  proc setActiveChannelByIndexWithForce*(self: ChatsView, index: int, forceUpdate: bool) {.slot.} =
    if((self.communities.activeCommunity.active and self.communities.activeCommunity.chats.chats.len == 0) or (not self.communities.activeCommunity.active and self.chats.chats.len == 0)): return

    var selectedChannel = self.getChannel(index)

    self.clearUnreadIfNeeded(self.activeChannel.chatItem)
    self.clearUnreadIfNeeded(selectedChannel)

    if (self.communities.activeCommunity.active and self.communities.activeCommunity.communityItem.lastChannelSeen != selectedChannel.id):
      self.communities.activeCommunity.communityItem.lastChannelSeen = selectedChannel.id
      self.communities.joinedCommunityList.replaceCommunity(self.communities.activeCommunity.communityItem)

    if not forceUpdate and self.activeChannel.id == selectedChannel.id: return

    if selectedChannel.chatType.isOneToOne and selectedChannel.id == selectedChannel.name:
      selectedChannel.name = self.userNameOrAlias(selectedChannel.id)

    self.previousActiveChannelIndex = index
    self.activeChannel.setChatItem(selectedChannel)
    self.status.chat.setActiveChannel(selectedChannel.id)

  proc setActiveChannelByIndex*(self: ChatsView, index: int) {.slot.} =
    self.setActiveChannelByIndexWithForce(index, false)

  proc getActiveChannelIdx(self: ChatsView): int {.slot.} =
    if (self.communities.activeCommunity.active):
      return self.communities.activeCommunity.chats.chats.findIndexById(self.activeChannel.id)
    else:
      return self.chats.chats.findIndexById(self.activeChannel.id)

  QtProperty[int] activeChannelIndex:
    read = getActiveChannelIdx
    write = setActiveChannelByIndex
    notify = activeChannelChanged

  proc setActiveChannel*(self: ChatsView, channel: string) {.slot.} =
    if (self.activeChannel.id == "" and channel == backToFirstChat):
      self.setActiveChannelByIndex(0)
      return

    if(channel == "" or channel == backToFirstChat): return
    let selectedChannel = self.getChannelById(channel)

    self.activeChannel.setChatItem(selectedChannel)
    
    discard self.status.chat.markAllChannelMessagesRead(self.activeChannel.id)
    self.activeChannelChanged()

  proc getActiveChannel*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.activeChannel)

  QtProperty[QVariant] activeChannel:
    read = getActiveChannel
    write = setActiveChannel
    notify = activeChannelChanged

  proc setContextChannel*(self: ChatsView, channel: string) {.slot.} =
    let contextChannel = self.getChannelById(channel)
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
    if self.previousActiveChannelIndex != -1:
      self.setActiveChannelByIndexWithForce(self.previousActiveChannelIndex, true)

  proc getCurrentSuggestions(self: ChatsView): QVariant {.slot.} =
    return newQVariant(self.currentSuggestions)

  QtProperty[QVariant] suggestionList:
    read = getCurrentSuggestions

  proc upsertChannel(self: ChatsView, channel: string) =
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

  proc messagePushed*(self: ChatsView, messageIndex: int) {.signal.}
  proc newMessagePushed*(self: ChatsView) {.signal.}

  proc messageNotificationPushed*(self: ChatsView, chatId: string, text: string, messageType: string, chatType: int, timestamp: string, identicon: string, username: string, hasMention: bool, isAddedContact: bool, channelName: string) {.signal.}

  proc messagesCleared*(self: ChatsView) {.signal.}

  proc clearMessages*(self: ChatsView, id: string) =
    let channel = self.getChannelById(id)
    if (channel == nil):
      return
    self.messageList[id].clear(not channel.isNil and channel.chatType != ChatType.Profile)
    self.messagesCleared()
  
  proc isAddedContact*(self: ChatsView, id: string): bool {.slot.} =
    result = self.status.contacts.isAdded(id)

  proc pushPinnedMessages*(self:ChatsView, pinnedMessages: var seq[Message]) =
    for msg in pinnedMessages.mitems:
      self.upsertChannel(msg.chatId)

      var message = self.messageList[msg.chatId].getMessageById(msg.id)
      message.pinnedBy = msg.pinnedBy
      message.isPinned = true

      self.pinnedMessagesList[msg.chatId].add(message)
      # put the message as pinned in the message list
      self.messageList[msg.chatId].changeMessagePinned(msg.id, true, msg.pinnedBy)

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
        var channel = self.chats.getChannelById(msg.chatId)
        if (channel == nil):
          channel = self.communities.getChannel(msg.chatId)
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
            msg.userName,
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
    if self.messageList.contains(chat):
      self.messageList[chat].markMessageAsSent(messageId)
    else:
      error "Message could not be marked as sent", chat, messageId
      

  proc getMessageList(self: ChatsView): QVariant {.slot.} =
    self.upsertChannel(self.activeChannel.id)
    return newQVariant(self.messageList[self.activeChannel.id])

  QtProperty[QVariant] messageList:
    read = getMessageList
    notify = activeChannelChanged

  proc getPinnedMessagesList(self: ChatsView): QVariant {.slot.} =
    self.upsertChannel(self.activeChannel.id)
    return newQVariant(self.pinnedMessagesList[self.activeChannel.id])

  QtProperty[QVariant] pinnedMessagesList:
    read = getPinnedMessagesList
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
    self.getLinkPreviewData("linkPreviewDataReceived", link, uuid)

  proc getChatType*(self: ChatsView, channel: string): int {.slot.} =
    let selectedChannel = self.getChannelById(channel)
    if selectedChannel == nil:
      return -1
    selectedChannel.chatType.int

  proc joinPublicChat*(self: ChatsView, channel: string): int {.slot.} =
    self.status.chat.createPublicChat(channel)
    self.setActiveChannel(channel)
    ChatType.Public.int

  proc joinPrivateChat*(self: ChatsView, pubKey: string, ensName: string): int {.slot.} =
    self.status.chat.createOneToOneChat(pubKey, if ensName != "": status_ens.addDomain(ensName) else: "")
    self.setActiveChannel(pubKey)
    ChatType.OneToOne.int

  proc messagesLoaded*(self: ChatsView) {.signal.}

  proc loadMoreMessages*(self: ChatsView) {.slot.} =
    trace "Loading more messages", chaId = self.activeChannel.id
    self.status.chat.chatMessages(self.activeChannel.id, false)
    self.status.chat.chatReactions(self.activeChannel.id, false)
    self.messagesLoaded();

  proc loadMoreMessagesWithIndex*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return
    trace "Loading more messages", chaId = selectedChannel.id
    self.status.chat.chatMessages(selectedChannel.id, false)
    self.status.chat.chatReactions(selectedChannel.id, false)
    self.messagesLoaded();

  proc loadingMessagesChanged*(self: ChatsView, value: bool) {.signal.}

  proc asyncMessageLoad*(self: ChatsView, chatId: string) {.slot.} =
    self.asyncMessageLoad("asyncMessageLoaded", chatId)

  proc asyncMessageLoaded*(self: ChatsView, rpcResponse: string) {.slot.} =
    let
      rpcResponseObj = rpcResponse.parseJson
      chatId = rpcResponseObj{"chatId"}.getStr

    if chatId == "": # .getStr() returns "" when field is not found
      return

    let messages = rpcResponseObj{"messages"}
    if(messages != nil and messages.kind != JNull):
      let chatMessages = status_chat.parseChatMessagesResponse(chatId, messages)
      self.status.chat.chatMessages(chatId, true, chatMessages[0], chatMessages[1])

    let rxns = rpcResponseObj{"reactions"}
    if(rxns != nil and rxns.kind != JNull):
      let reactions = status_chat.parseReactionsResponse(chatId, rxns)
      self.status.chat.chatReactions(chatId, true, reactions[0], reactions[1])

    let pinnedMsgs = rpcResponseObj{"pinnedMessages"}
    if(pinnedMsgs != nil and pinnedMsgs.kind != JNull):
      let pinnedMessages = status_chat.parseChatMessagesResponse(chatId, pinnedMsgs, true)
      self.status.chat.pinnedMessagesByChatID(chatId, pinnedMessages[0], pinnedMessages[1])

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
    let task = RequestMessagesTaskArg(
      `method`: "requestMoreMessages",
      chatId: self.activeChannel.id
    )
    mailserverWorker.start(task)

  proc leaveChatByIndex*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return
    if (self.activeChannel.id == selectedChannel.id):
      self.activeChannel.chatItem = nil
    self.status.chat.leave(selectedChannel.id)

  proc fillGaps*(self: ChatsView, messageId: string) {.slot.} =
    self.loadingMessages = true
    self.loadingMessagesChanged(true)
    discard self.status.mailservers.fillGaps(self.activeChannel.id, @[messageId])

  proc leaveActiveChat*(self: ChatsView) {.slot.} =
    self.status.chat.leave(self.activeChannel.id)

  proc removeChat*(self: ChatsView, chatId: string) =
    discard self.chats.removeChatItemFromList(chatId)
    if (self.messageList.hasKey(chatId)):
      let index = self.getMessageListIndexById(chatId)
      self.beginRemoveRows(newQModelIndex(), index, index)
      self.messageList[chatId].delete
      self.messageList.del(chatId)
      self.endRemoveRows()

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
    let selectedChannel = self.getChannel(channelIndex)
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
        self.communities.updateCommunityChat(chat)
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
    self.resolveEns("ensResolved", ens) # Call self.ensResolved(string) when ens is resolved

  proc ensWasResolved*(self: ChatsView, resolvedPubKey: string, resolvedAddress: string) {.signal.}

  proc ensResolved(self: ChatsView, addressPubkeyJson: string) {.slot.} =
    var
      parsed = addressPubkeyJson.parseJson
      address = parsed["address"].to(string)
      pubkey = parsed["pubkey"].to(string)
    self.ensWasResolved(pubKey, address)

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
    let channel = self.getChannelById(self.activeChannel.id())
    channel.muted = true
    self.updateChannelInRightList(channel)

  proc unmuteCurrentChannel*(self: ChatsView) {.slot.} =
    self.activeChannel.unmute()
    let channel = self.getChannelById(self.activeChannel.id())
    channel.muted = false
    self.updateChannelInRightList(channel)

  proc muteChannel*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return
    if (selectedChannel.id == self.activeChannel.id):
      self.muteCurrentChannel()
      return
    selectedChannel.muted = true
    self.status.chat.muteChat(selectedChannel)
    self.updateChannelInRightList(selectedChannel)

  proc unmuteChannel*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return
    if (selectedChannel.id == self.activeChannel.id):
      self.unmuteCurrentChannel()
      return
    selectedChannel.muted = false
    self.status.chat.unmuteChat(selectedChannel)
    self.updateChannelInRightList(selectedChannel)

  proc channelIsMuted*(self: ChatsView, channelIndex: int): bool {.slot.} =
    if (self.chats.chats.len == 0): return false
    let selectedChannel = self.getChannel(channelIndex)
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

  proc removeMessagesByUserId(self: ChatsView, publicKey: string) {.slot.} =
    for k in self.messageList.keys:
      self.messageList[k].removeMessagesByUserId(publicKey)

  proc getMessageListIndex(self: ChatsView): int {.slot.} =
    var idx = -1
    for msg in toSeq(self.messageList.values):
      idx = idx + 1
      if(self.activeChannel.id == msg.id): return idx
    return idx

  proc getMessageListIndexById(self: ChatsView, id: string): int {.slot.} =
    var idx = -1
    for msg in toSeq(self.messageList.values):
      idx = idx + 1
      if(id == msg.id): return idx
    return idx

  proc addPinMessage*(self: ChatsView, messageId: string, chatId: string, pinnedBy: string) =
    self.upsertChannel(chatId)
    self.messageList[chatId].changeMessagePinned(messageId, true, pinnedBy)
    var message = self.messageList[chatId].getMessageById(messageId)
    message.pinnedBy = pinnedBy
    self.pinnedMessagesList[chatId].add(message)

  proc removePinMessage*(self: ChatsView, messageId: string, chatId: string) =
    self.upsertChannel(chatId)
    self.messageList[chatId].changeMessagePinned(messageId, false, "")
    try:
      self.pinnedMessagesList[chatId].remove(messageId)
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
