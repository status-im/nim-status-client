import NimQml, Tables, json, sequtils, chronicles, times, re, sugar, strutils, os
import ../../status/status
import ../../status/libstatus/accounts/constants
import ../../status/accounts as status_accounts
import ../../status/chat as status_chat
import ../../status/messages as status_messages
import ../../status/libstatus/wallet as status_wallet
import ../../status/contacts as status_contacts
import ../../status/ens as status_ens
import ../../status/chat/[chat, message]
import ../../status/libstatus/types
import ../../status/profile/profile
import ../../status/audio/encoder
import eth/common/eth_types
import ../../status/threads
import views/channels_list, views/message_list, views/chat_item, views/sticker_pack_list, views/sticker_list, views/suggestions_list
import json_serialization
from eth/common/utils import parseAddress

var phAacEncoder: AACENCODER = nil


logScope:
  topics = "chats-view"

QtObject:
  type
    ChatsView* = ref object of QAbstractListModel
      status: Status
      chats*: ChannelsList
      currentSuggestions*: SuggestionsList
      callResult: string
      messageList*: Table[string, ChatMessageList]
      activeChannel*: ChatItemView
      stickerPacks*: StickerPackList
      recentStickers*: StickerList
      replyTo: string
      pubKey*: string
      channelOpenTime*: Table[string, int64]
      connected: bool
      unreadMessageCnt: int
      audioRecorder: QAudioRecorder

  proc setup(self: ChatsView) = self.QAbstractListModel.setup

  proc delete(self: ChatsView) = 
    self.chats.delete
    self.activeChannel.delete
    self.currentSuggestions.delete
    for msg in self.messageList.values:
      msg.delete
    self.messageList = initTable[string, ChatMessageList]()
    self.channelOpenTime = initTable[string, int64]()
    self.audioRecorder.delete
    self.QAbstractListModel.delete

  proc newChatsView*(status: Status): ChatsView =
    new(result, delete)
    result.status = status
    result.connected = false
    result.chats = newChannelsList(status)
    result.activeChannel = newChatItemView(status)
    result.currentSuggestions = newSuggestionsList()
    result.messageList = initTable[string, ChatMessageList]()
    result.stickerPacks = newStickerPackList()
    result.recentStickers = newStickerList()
    result.unreadMessageCnt = 0
    result.pubKey = ""
    result.setup()

  proc addStickerPackToList*(self: ChatsView, stickerPack: StickerPack, isInstalled, isBought: bool) =
    self.stickerPacks.addStickerPackToList(stickerPack, newStickerList(stickerPack.stickers), isInstalled, isBought)
  
  proc getStickerPackList(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.stickerPacks)

  QtProperty[QVariant] stickerPacks:
    read = getStickerPackList

  proc obtainAvailableStickerPacks*(self: ChatsView) =
    spawnAndSend(self, "setAvailableStickerPacks") do:
      let availableStickerPacks = status_chat.getAvailableStickerPacks()
      var packs: seq[StickerPack] = @[]
      for packId, stickerPack in availableStickerPacks.pairs:
        packs.add(stickerPack)
      $(%*(packs))

  proc setAvailableStickerPacks*(self: ChatsView, availableStickersJSON: string) {.slot.} =
    let currAcct = status_wallet.getWalletAccounts()[0] # TODO: make generic
    let currAddr = parseAddress(currAcct.address)
    let installedStickerPacks = self.status.chat.getInstalledStickerPacks()
    let purchasedStickerPacks = self.status.chat.getPurchasedStickerPacks(currAddr)
    let availableStickers = JSON.decode($availableStickersJSON, seq[StickerPack])

    for stickerPack in availableStickers:
      let isInstalled = installedStickerPacks.hasKey(stickerPack.id)
      let isBought = purchasedStickerPacks.contains(stickerPack.id)
      self.status.chat.availableStickerPacks[stickerPack.id] = stickerPack
      self.addStickerPackToList(stickerPack, isInstalled, isBought)

  proc getChatsList(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.chats)

  QtProperty[QVariant] chats:
    read = getChatsList

  proc getChannelColor*(self: ChatsView, channel: string): string {.slot.} =
    self.chats.getChannelColor(channel)

  proc replaceMentionsWithPubKeys(self: ChatsView, mentions: seq[string], contacts: seq[Profile], message: string, predicate: proc (contact: Profile): string): string =
    result = message
    for mention in mentions:
      let matches = contacts.filter(c => "@" & predicate(c).toLowerAscii == mention.toLowerAscii).map(c => c.address)
      if matches.len > 0:
        let pubKey = matches[0]
        result = message.replace(mention, "@" & pubKey)

  proc plainText(self: ChatsView, input: string): string {.slot.} =
    result = plain_text(input)

  proc sendMessage*(self: ChatsView, message: string, replyTo: string, contentType: int = ContentType.Message.int) {.slot.} =
    let aliasPattern = re(r"(@[A-z][a-z]* [A-z][a-z]* [A-z][a-z]*)", flags = {reStudy, reIgnoreCase})
    let ensPattern = re(r"(@\w*(?=\.stateofus\.eth))", flags = {reStudy, reIgnoreCase})
    let namePattern = re(r"(@\w*)", flags = {reStudy, reIgnoreCase})

    let contacts = self.status.contacts.getContacts()

    let aliasMentions = findAll(message, aliasPattern)
    let ensMentions = findAll(message, ensPattern)
    let nameMentions = findAll(message, namePattern)

    var m = self.replaceMentionsWithPubKeys(aliasMentions, contacts, message, (c => c.alias))
    m = self.replaceMentionsWithPubKeys(ensMentions, contacts, m, (c => c.ensName))
    m = self.replaceMentionsWithPubKeys(nameMentions, contacts, m, (c => c.ensName.split(".")[0]))
    self.status.chat.sendMessage(self.activeChannel.id, m, replyTo, contentType)

  proc verifyMessageSent*(self: ChatsView, data: string) {.slot.} =
    let messageData = data.parseJson
    self.messageList[messageData["chatId"].getStr].checkTimeout(messageData["id"].getStr)

  proc resendMessage*(self: ChatsView, chatId: string, messageId: string) {.slot.} =
    self.status.messages.trackMessage(messageId, chatId)
    self.status.chat.resendMessage(messageId)
    self.messageList[chatId].resetTimeOut(messageId)

  proc sendImage*(self: ChatsView, imagePath: string) {.slot.} =
    let image = replace(imagePath, "file://", "")
    let tmpImagePath = image_resizer(image, 2000, TMPDIR)
    self.status.chat.sendImage(self.activeChannel.id, tmpImagePath)
    removeFile(tmpImagePath)

  proc activeChannelChanged*(self: ChatsView) {.signal.}

  proc sendingMessage*(self: ChatsView) {.signal.}

  proc appReady*(self: ChatsView) {.signal.}

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

  proc setActiveChannelByIndex*(self: ChatsView, index: int) {.slot.} =
    if(self.chats.chats.len == 0): return
    if(not self.activeChannel.chatItem.isNil and self.activeChannel.chatItem.unviewedMessagesCount > 0):
      var response = self.status.chat.markAllChannelMessagesRead(self.activeChannel.id)
      if not response.hasKey("error"):
        self.chats.clearUnreadMessagesCount(self.activeChannel.chatItem)
    let selectedChannel = self.chats.getChannel(index)
    if self.activeChannel.id == selectedChannel.id: return

    if selectedChannel.chatType.isOneToOne:
      selectedChannel.name = self.userNameOrAlias(selectedChannel.id)

    self.activeChannel.setChatItem(selectedChannel)
    self.status.chat.setActiveChannel(selectedChannel.id)
    discard self.status.chat.markAllChannelMessagesRead(selectedChannel.id)
    self.currentSuggestions.setNewData(self.status.contacts.getContacts())
    self.activeChannelChanged()

  proc getActiveChannelIdx(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.chats.chats.findIndexById(self.activeChannel.id))

  QtProperty[QVariant] activeChannelIndex:
    read = getActiveChannelIdx
    write = setActiveChannelByIndex
    notify = activeChannelChanged

  proc installStickerPack*(self: ChatsView, packId: int) {.slot.} =
    self.status.chat.installStickerPack(packId)
    self.stickerPacks.updateStickerPackInList(packId, true)
  
  proc uninstallStickerPack*(self: ChatsView, packId: int) {.slot.} =
    self.status.chat.uninstallStickerPack(packId)
    self.status.chat.removeRecentStickers(packId)
    self.stickerPacks.updateStickerPackInList(packId, false)
    self.recentStickers.removeStickersFromList(packId)

  proc getRecentStickerList*(self: ChatsView): QVariant {.slot.} =
    result = newQVariant(self.recentStickers)

  QtProperty[QVariant] recentStickers:
    read = getRecentStickerList

  proc setActiveChannel*(self: ChatsView, channel: string) {.slot.} =
    if(channel == ""): return
    self.activeChannel.setChatItem(self.chats.getChannel(self.chats.chats.findIndexById(channel)))
    discard self.status.chat.markAllChannelMessagesRead(self.activeChannel.id)
    self.currentSuggestions.setNewData(self.status.contacts.getContacts())
    self.activeChannelChanged()

  proc getActiveChannel*(self: ChatsView): QVariant {.slot.} =
    newQVariant(self.activeChannel)

  QtProperty[QVariant] activeChannel:
    read = getActiveChannel
    write = setActiveChannel
    notify = activeChannelChanged


  proc getCurrentSuggestions(self: ChatsView): QVariant {.slot.} =
    return newQVariant(self.currentSuggestions)

  QtProperty[QVariant] suggestionList:
    read = getCurrentSuggestions

  proc upsertChannel(self: ChatsView, channel: string) =
    if not self.messageList.hasKey(channel):
      self.messageList[channel] = newChatMessageList(channel, self.status)
      self.channelOpenTime[channel] = now().toTime.toUnix * 1000

  proc messagePushed*(self: ChatsView) {.signal.}
  proc newMessagePushed*(self: ChatsView) {.signal.}

  proc messageNotificationPushed*(self: ChatsView, chatId: string, text: string, messageType: string, chatType: int, timestamp: string, identicon: string, username: string) {.signal.}

  proc messagesCleared*(self: ChatsView) {.signal.}

  proc clearMessages*(self: ChatsView, id: string) =
    self.messageList[id].clear()
    self.messagesCleared()

  proc pushMessages*(self:ChatsView, messages: var seq[Message]) =
    for msg in messages.mitems:
      self.upsertChannel(msg.chatId)
      msg.alias = self.status.chat.getUserName(msg.fromAuthor, msg.alias)
      self.messageList[msg.chatId].add(msg)
      self.messagePushed()
      if self.channelOpenTime.getOrDefault(msg.chatId, high(int64)) < msg.timestamp.parseFloat.fromUnixFloat.toUnix:
        if msg.chatId != self.activeChannel.id:
          let channel = self.chats.getChannelById(msg.chatId)
          if not channel.muted:
            self.messageNotificationPushed(msg.chatId, msg.text, msg.messageType, channel.chatType.int, msg.timestamp, msg.identicon, msg.alias)
        else:
          discard self.status.chat.markMessagesSeen(msg.chatId, @[msg.id])
          self.newMessagePushed()

  proc messageEmojiReactionId(self: ChatsView, chatId: string, messageId: string, emojiId: int): string =
    let message = self.messageList[chatId].getMessageById(messageId)
    if (message.emojiReactions == "") :
      return ""

    let oldReactions = parseJson(message.emojiReactions)

    for pair in oldReactions.pairs:
      if (pair[1]["emojiId"].getInt == emojiId and pair[1]["from"].getStr == self.pubKey):
        return pair[0]
    return ""

  proc toggleEmojiReaction*(self: ChatsView, messageId: string, emojiId: int) {.slot.} =
    let emojiReactionId = self.messageEmojiReactionId(self.activeChannel.id, messageId, emojiId)
    if (emojiReactionId == ""):
      self.status.chat.addEmojiReaction(self.activeChannel.id, messageId, emojiId)
    else:
      self.status.chat.removeEmojiReaction(emojiReactionId)

  proc pushReactions*(self:ChatsView, reactions: var seq[Reaction]) =
    let t = reactions.len
    for reaction in reactions.mitems:
      let messageList = self.messageList[reaction.chatId]
      var message = messageList.getMessageById(reaction.messageId)
      var oldReactions: JsonNode
      if (message.emojiReactions == "") :
        oldReactions = %*{}
      else: 
        oldReactions = parseJson(message.emojiReactions)

      if (oldReactions.hasKey(reaction.id)):
        if (reaction.retracted):
          # Remove the reaction
          oldReactions.delete(reaction.id)
          messageList.setMessageReactions(reaction.messageId, $oldReactions)
        continue

      oldReactions[reaction.id] = %* {
        "from": reaction.fromAccount,
        "emojiId": reaction.emojiId
      }
      messageList.setMessageReactions(reaction.messageId, $oldReactions)


  proc updateUsernames*(self:ChatsView, contacts: seq[Profile]) =
    if contacts.len > 0:
      # Updating usernames for all the messages list
      for k in self.messageList.keys:
        self.messageList[k].updateUsernames(contacts)

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
    self.messagePushed()

  proc addRecentStickerToList*(self: ChatsView, sticker: Sticker) =
    self.recentStickers.addStickerToList(sticker)
  
  proc copyToClipboard*(self: ChatsView, content: string) {.slot.} =
    setClipBoardText(content)

  proc sendSticker*(self: ChatsView, hash: string, pack: int) {.slot.} =
    let sticker = Sticker(hash: hash, packId: pack)
    self.addRecentStickerToList(sticker)
    self.status.chat.sendSticker(self.activeChannel.id, sticker)

  proc joinChat*(self: ChatsView, channel: string, chatTypeInt: int): int {.slot.} =
    self.status.chat.join(channel, ChatType(chatTypeInt))
    self.setActiveChannel(channel)

  proc joinGroup*(self: ChatsView) {.slot.} =
    self.status.chat.confirmJoiningGroup(self.activeChannel.id)

  proc messagesLoaded*(self: ChatsView) {.signal.}

  proc loadMoreMessages*(self: ChatsView) {.slot.} =
    trace "Loading more messages", chaId = self.activeChannel.id
    self.status.chat.chatMessages(self.activeChannel.id, false)
    self.status.chat.chatReactions(self.activeChannel.id, false)
    self.messagesLoaded();

  proc loadMoreMessagesWithIndex*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return
    trace "Loading more messages", chaId = selectedChannel.id
    self.status.chat.chatMessages(selectedChannel.id, false)
    self.status.chat.chatReactions(selectedChannel.id, false)
    self.messagesLoaded();

  proc leaveChatByIndex*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return
    self.status.chat.leave(selectedChannel.id)

  proc leaveActiveChat*(self: ChatsView) {.slot.} =
    self.status.chat.leave(self.activeChannel.id)

  proc removeChat*(self: ChatsView, chatId: string) =
    discard self.chats.removeChatItemFromList(chatId)
    self.messageList[chatId].delete
    self.messageList.del(chatId)

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

  proc updateChats*(self: ChatsView, chats: seq[Chat], triggerChange:bool = true) =
    for chat in chats:
      self.upsertChannel(chat.id)
      self.chats.updateChat(chat, triggerChange)
      if(self.activeChannel.id == chat.id):
        self.activeChannel.setChatItem(chat)
        self.currentSuggestions.setNewData(self.status.contacts.getContacts())
    self.calculateUnreadMessages()

  proc renameGroup*(self: ChatsView, newName: string) {.slot.} =
    self.status.chat.renameGroup(self.activeChannel.id, newName)

  proc blockContact*(self: ChatsView, id: string): string {.slot.} =
    return self.status.contacts.blockContact(id)

  proc addContact*(self: ChatsView, id: string): string {.slot.} =
    return self.status.contacts.addContact(id)

  proc removeContact*(self: ChatsView, id: string) {.slot.} =
    self.status.contacts.removeContact(id)

  proc createGroup*(self: ChatsView, groupName: string, pubKeys: string) {.slot.} =
    let pubKeysSeq = map(parseJson(pubKeys).getElems(), proc(x:JsonNode):string = x.getStr)
    self.status.chat.createGroup(groupName, pubKeysSeq)

  proc addGroupMembers*(self: ChatsView, chatId: string, pubKeys: string) {.slot.} =
    let pubKeysSeq = map(parseJson(pubKeys).getElems(), proc(x:JsonNode):string = x.getStr)
    self.status.chat.addGroupMembers(chatId, pubKeysSeq)

  proc kickGroupMember*(self: ChatsView, chatId: string, pubKey: string) {.slot.} =
    self.status.chat.kickGroupMember(chatId, pubKey)

  proc makeAdmin*(self: ChatsView, chatId: string, pubKey: string) {.slot.} =
    self.status.chat.makeAdmin(chatId, pubKey)

  proc isEnsVerified*(self: ChatsView, id: string): bool {.slot.} =
    if id == "": return false
    let contact = self.status.contacts.getContactByID(id)
    if contact == nil:
      return false
    result = contact.ensVerified

  proc formatENSUsername*(self: ChatsView, username: string): string {.slot.} =
    result = status_ens.addDomain(username)

  proc generateIdenticon*(self: ChatsView, pk: string): string {.slot.} =
    result = status_accounts.generateIdenticon(pk)

  # Resolving a ENS name
  proc resolveENS*(self: ChatsView, ens: string) {.slot.} =
    spawnAndSend(self, "ensResolved") do: # Call self.ensResolved(string) when ens is resolved
      status_ens.pubkey(ens)

  proc ensWasResolved*(self: ChatsView, resolvedPubKey: string) {.signal.}

  proc ensResolved(self: ChatsView, pubKey: string) {.slot.} =
    self.ensWasResolved(pubKey)

  proc isConnected*(self: ChatsView): bool {.slot.} =
    result = self.connected

  proc onlineStatusChanged(self: ChatsView, connected: bool) {.signal.}

  proc setConnected*(self: ChatsView, connected: bool) =
    self.connected = connected
    self.onlineStatusChanged(connected)

  QtProperty[bool] isOnline:
    read = isConnected
    notify = onlineStatusChanged

  proc muteChannel*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return
    self.status.chat.muteChat(selectedChannel.id)
    selectedChannel.muted = true
    self.chats.updateChat(selectedChannel, false)

  proc unmuteChannel*(self: ChatsView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return
    self.status.chat.unmuteChat(selectedChannel.id)
    selectedChannel.muted = false
    self.chats.updateChat(selectedChannel, false)

  proc channelIsMuted*(self: ChatsView, channelIndex: int): bool {.slot.} =
    if (self.chats.chats.len == 0): return false
    let selectedChannel = self.chats.getChannel(channelIndex)
    if (selectedChannel == nil): return false
    result = selectedChannel.muted
    

  proc startRecording*(self: ChatsView) {.slot.}=
    self.audioRecorder = newQAudioRecorder(TMPDIR)
    self.audioRecorder.start()

  proc stopRecording*(self: ChatsView) {.slot.} =
    echo self.audioRecorder.stop()

    defer:
      echo "TODO: delete audio file"

    if aacEncOpen(phAacEncoder.unsafeAddr, 0.cuint, 0.cuint) != AACENC_ERROR.AACENC_OK:
      error "Could not convert open encoder AAC"
      return

    echo aacEncoder_SetParam(phAacEncoder.unsafeAddr, AACENC_PARAM.AACENC_AOT, 2.cuint)
    echo aacEncoder_SetParam(phAacEncoder.unsafeAddr, AACENC_PARAM.AACENC_SBR_MODE, 0.cuint) 
    echo aacEncoder_SetParam(phAacEncoder.unsafeAddr, AACENC_PARAM.AACENC_CHANNELMODE, 2.cuint)
    echo aacEncoder_SetParam(phAacEncoder.unsafeAddr, AACENC_PARAM.AACENC_SAMPLERATE, 22050.cuint)
    echo aacEncoder_SetParam(phAacEncoder.unsafeAddr, AACENC_PARAM.AACENC_BITRATEMODE, 1.cuint)
    

#[
    if aacEncoder_SetParam(phAacEncoder.addr, AACENC_PARAM.AACENC_CHANNELMODE, 2.cint) != AACENC_ERROR.AACENC_OK:
      error "Could not set the Channel mode"
      return

    if aacEncoder_SetParam(phAacEncoder.addr, AACENC_PARAM.AACENC_SBR_MODE, 0.cint) != AACENC_ERROR.AACENC_OK:
      error "Could not set the SBR"
      return

    if aacEncoder_SetParam(phAacEncoder.addr, AACENC_PARAM.AACENC_TRANSMUX, 2.cint) != AACENC_ERROR.AACENC_OK:
      error "Could not set the transmux rate"
      return

    if aacEncoder_SetParam(phAacEncoder.addr, AACENC_PARAM.AACENC_SAMPLERATE, 22050.cint) != AACENC_ERROR.AACENC_OK:
      error "Could not set the sample rate"
      return

    if aacEncoder_SetParam(phAacEncoder.addr, AACENC_PARAM.AACENC_BITRATEMODE, 1.cint) != AACENC_ERROR.AACENC_OK:
      error "Could not set the VBR bitrate"
      return

    if aacEncoder_SetParam(phAacEncoder.addr, AACENC_PARAM.AACENC_CHANNELORDER, 1.cint) != AACENC_ERROR.AACENC_OK:
      error "Could not set the channel order"
      return
   
    if aacEncoder_SetParam(phAacEncoder.addr, AACENC_PARAM.AACENC_AFTERBURNER, 1.cint) != AACENC_ERROR.AACENC_OK:
      error "Could not enable afterburner"
      return

    var identifier: int = 0
    var bufElSizes: int = 2

    var inArgs: AACENC_InArgs = AACENC_InArgs(
      numInSamples: 0,
      numAncBytes: 0
    )

    var outArgs: AACENC_InArgs;

    #in_args.numInSamples = read <= 0 ? -1 : read/2;


    #var inBuf: AACENC_BufDesc = AACENC_BufDesc(
    #  numBufs: 1,
    #  bufs: ptr pointer
    #  bufferIdentifiers: identifier.addr
    #  bufSizes: .....
    #  bufElSizes: bufElSizes.addr
    #)


    #echo aacEncEncode(phAacEncoder.addr, &inBufDesc, &outBufDesc, &inargs, &outargs);
    
]#
    if aacEncClose(phAacEncoder.addr) != AACENC_ERROR.AACENC_OK:
      error "Could not close encoder AAC"
      return


