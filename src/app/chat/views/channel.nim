import NimQml, Tables, json, sequtils, chronicles, times, re, sugar, strutils, os, strformat, algorithm

import ../../../status/[status, contacts, types]
import ../../../status/signals/types as signal_types
import ../../../status/ens as status_ens
import ../../../status/chat as status_chat
import ../../../status/chat/[chat, message]
import ../../../status/tasks/[qt, task_runner_impl]

import communities, chat_item, channels_list, communities, community_list

logScope:
  topics = "channel-view"

QtObject:
  type ChannelView* = ref object of QObject
    status: Status
    communities*: CommunitiesView
    chats*: ChannelsList
    activeChannel*: ChatItemView
    previousActiveChannelIndex*: int
    contextChannel*: ChatItemView

  proc setup(self: ChannelView) = self.QObject.setup
  proc delete*(self: ChannelView) =
    self.chats.delete
    self.activeChannel.delete
    self.contextChannel.delete
    self.QObject.delete

  proc newChannelView*(status: Status, communities: CommunitiesView): ChannelView =
    new(result, delete)
    result.status = status
    result.chats = newChannelsList(status)
    result.activeChannel = newChatItemView(status)
    result.contextChannel = newChatItemView(status)
    result.communities = communities
    result.previousActiveChannelIndex = -1
    result.setup

  proc getChannel*(self: ChannelView, index: int): Chat =
    if (self.communities.activeCommunity.active):
      return self.communities.activeCommunity.chats.getChannel(index)
    else:
      return self.chats.getChannel(index)
  
  proc getCommunityChannelById(self: ChannelView, channel: string): Chat =
    let index = self.communities.activeCommunity.chats.chats.findIndexById(channel)
    if (index > -1):
      return self.communities.activeCommunity.chats.getChannel(index)
    let chan = self.communities.activeCommunity.chats.getChannelByName(channel)
    if not chan.isNil:
      return chan

  proc getChannelById*(self: ChannelView, channel: string): Chat =
    if self.communities.activeCommunity.active:
      result = self.getCommunityChannelById(channel)
      if not result.isNil:
        return result
    # even if communities are active, if we don't find a chat, it's possibly
    # because we are looking for a normal chat, so continue below
    let index = self.chats.chats.findIndexById(channel)
    if index > -1:
      return self.chats.getChannel(index)

  proc updateChannelInRightList*(self: ChannelView, channel: Chat) =
    if (self.communities.activeCommunity.active):
      self.communities.activeCommunity.chats.updateChat(channel)
    else:
      self.chats.updateChat(channel)

  proc getChatsList(self: ChannelView): QVariant {.slot.} =
    newQVariant(self.chats)

  QtProperty[QVariant] chats:
    read = getChatsList

  proc getChannelColor*(self: ChannelView, channel: string): string {.slot.} =
    if (channel == ""): return
    let selectedChannel = self.getChannelById(channel)
    if (selectedChannel.isNil or selectedChannel.id == "") : return
    return selectedChannel.color

  proc activeChannelChanged*(self: ChannelView) {.signal.}

  proc contextChannelChanged*(self: ChannelView) {.signal.}

  proc markAllChannelMessagesReadByIndex*(self: ChannelView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return
    discard self.status.chat.markAllChannelMessagesRead(selectedChannel.id)

  proc clearUnreadIfNeeded*(self: ChannelView, channel: var Chat) =
    if (not channel.isNil and (channel.unviewedMessagesCount > 0 or channel.hasMentions)):
      var response = self.status.chat.markAllChannelMessagesRead(channel.id)
      if not response.hasKey("error"):
        self.chats.clearUnreadMessagesCount(channel)

  proc userNameOrAlias(self: ChannelView, pubKey: string): string =
    if self.status.chat.contacts.hasKey(pubKey):
      return status_ens.userNameOrAlias(self.status.chat.contacts[pubKey])
    generateAlias(pubKey)

  proc setActiveChannelByIndexWithForce*(self: ChannelView, index: int, forceUpdate: bool) {.slot.} =
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

  proc setActiveChannelByIndex*(self: ChannelView, index: int) {.slot.} =
    self.setActiveChannelByIndexWithForce(index, false)

  proc emitActiveChannelChangeEvent*(self: ChannelView, chatId: string) =
    self.status.chat.setActiveChannel(chatId)

  proc getActiveChannelIdx(self: ChannelView): int {.slot.} =
    if (self.communities.activeCommunity.active):
      return self.communities.activeCommunity.chats.chats.findIndexById(self.activeChannel.id)
    else:
      return self.chats.chats.findIndexById(self.activeChannel.id)

  QtProperty[int] activeChannelIndex:
    read = getActiveChannelIdx
    write = setActiveChannelByIndex
    notify = activeChannelChanged

  proc setActiveChannel*(self: ChannelView, channel: string) {.slot.} =
    if (self.activeChannel.id == "" and channel == backToFirstChat):
      self.setActiveChannelByIndex(0)
      return

    if(channel == "" or channel == backToFirstChat): return
    let selectedChannel = self.getChannelById(channel)

    self.activeChannel.setChatItem(selectedChannel)
    
    discard self.status.chat.markAllChannelMessagesRead(self.activeChannel.id)
    self.activeChannelChanged()

  proc getActiveChannel*(self: ChannelView): QVariant {.slot.} =
    newQVariant(self.activeChannel)

  QtProperty[QVariant] activeChannel:
    read = getActiveChannel
    write = setActiveChannel
    notify = activeChannelChanged

  proc setContextChannel*(self: ChannelView, channel: string) {.slot.} =
    let contextChannel = self.getChannelById(channel)
    self.contextChannel.setChatItem(contextChannel)
    self.contextChannelChanged()

  proc getContextChannel*(self: ChannelView): QVariant {.slot.} =
    newQVariant(self.contextChannel)
  
  QtProperty[QVariant] contextChannel:
    read = getContextChannel
    write = setContextChannel
    notify = contextChannelChanged

  proc restorePreviousActiveChannel*(self: ChannelView) {.slot.} =
    if self.previousActiveChannelIndex != -1:
      self.setActiveChannelByIndexWithForce(self.previousActiveChannelIndex, true)

  proc joinPublicChat*(self: ChannelView, channel: string): int {.slot.} =
    self.status.chat.createPublicChat(channel)
    self.setActiveChannel(channel)
    ChatType.Public.int

  proc joinPrivateChat*(self: ChannelView, pubKey: string, ensName: string): int {.slot.} =
    self.status.chat.createOneToOneChat(pubKey, if ensName != "": status_ens.addDomain(ensName) else: "")
    self.setActiveChannel(pubKey)
    ChatType.OneToOne.int

  proc leaveChatByIndex*(self: ChannelView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return
    if (self.activeChannel.id == selectedChannel.id):
      self.activeChannel.chatItem = nil
    self.status.chat.leave(selectedChannel.id)

  proc leaveActiveChat*(self: ChannelView) {.slot.} =
    self.status.chat.leave(self.activeChannel.id)

  proc clearChatHistory*(self: ChannelView, id: string) {.slot.} =
    self.status.chat.clearHistory(id)

  proc clearChatHistoryByIndex*(self: ChannelView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return
    self.status.chat.clearHistory(selectedChannel.id)

  proc muteCurrentChannel*(self: ChannelView) {.slot.} =
    self.activeChannel.mute()
    let channel = self.getChannelById(self.activeChannel.id())
    channel.muted = true
    self.updateChannelInRightList(channel)

  proc unmuteCurrentChannel*(self: ChannelView) {.slot.} =
    self.activeChannel.unmute()
    let channel = self.getChannelById(self.activeChannel.id())
    channel.muted = false
    self.updateChannelInRightList(channel)

  proc muteChannel*(self: ChannelView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return
    if (selectedChannel.id == self.activeChannel.id):
      self.muteCurrentChannel()
      return
    selectedChannel.muted = true
    self.status.chat.muteChat(selectedChannel)
    self.updateChannelInRightList(selectedChannel)

  proc unmuteChannel*(self: ChannelView, channelIndex: int) {.slot.} =
    if (self.chats.chats.len == 0): return
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return
    if (selectedChannel.id == self.activeChannel.id):
      self.unmuteCurrentChannel()
      return
    selectedChannel.muted = false
    self.status.chat.unmuteChat(selectedChannel)
    self.updateChannelInRightList(selectedChannel)

  proc channelIsMuted*(self: ChannelView, channelIndex: int): bool {.slot.} =
    if (self.chats.chats.len == 0): return false
    let selectedChannel = self.getChannel(channelIndex)
    if (selectedChannel == nil): return false
    result = selectedChannel.muted  
