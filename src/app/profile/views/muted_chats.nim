import NimQml, sequtils, strutils, sugar, os, json, chronicles
import chronicles
import ../../chat/views/channels_list
import ../../../status/profile/profile
import ../../../status/profile as status_profile
import ../../../status/contacts as status_contacts
import ../../../status/status
import ../../../status/ens as status_ens
import ../../../status/chat/chat
import ../../../status/types
import ../../../status/constants as accountConstants
import ../../utils/image_utils

logScope:
  topics = "muted-chats-view"

QtObject:
  type MutedChatsView* = ref object of QObject
    status*: Status
    mutedChats*: ChannelsList
    mutedContacts*: ChannelsList

  proc setup(self: MutedChatsView) =
    self.QObject.setup

  proc delete*(self: MutedChatsView) =
    if not self.mutedChats.isNil: self.mutedChats.delete
    if not self.mutedContacts.isNil: self.mutedContacts.delete
    self.QObject.delete

  proc newMutedChatsView*(status: Status): MutedChatsView =
    new(result, delete)
    result.status = status
    result.mutedChats = newChannelsList(status)
    result.mutedContacts = newChannelsList(status)
    result.setup
  
  proc getMutedChatsList(self: MutedChatsView): QVariant {.slot.} =
    newQVariant(self.mutedChats)

  proc getMutedContactsList(self: MutedChatsView): QVariant {.slot.} =
    newQVariant(self.mutedContacts)

  proc mutedChatsListChanged*(self: MutedChatsView) {.signal.}

  proc mutedContactsListChanged*(self: MutedChatsView) {.signal.}

  QtProperty[QVariant] chats:
    read = getMutedChatsList
    notify = mutedChatsListChanged

  QtProperty[QVariant] contacts:
    read = getMutedContactsList
    notify = mutedContactsListChanged

  proc updateChats*(self: MutedChatsView, chats: seq[Chat]) =
    for chat in chats:
      if not chat.muted:
        if chat.chatType.isOneToOne:
          discard self.mutedContacts.removeChatItemFromList(chat.id)
        else:
          discard self.mutedChats.removeChatItemFromList(chat.id)
      else:
        if chat.chatType.isOneToOne:
          discard self.mutedContacts.addChatItemToList(chat)
        else:
          discard self.mutedChats.addChatItemToList(chat)
    self.mutedChatsListChanged()
    self.mutedContactsListChanged()
