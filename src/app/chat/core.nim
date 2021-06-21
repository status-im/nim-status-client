import NimQml, chronicles, tables
import ../../status/chat as chat_model
import ../../status/messages as messages_model
import ../../status/signals/types
import ../../status/types as status_types
import ../../status/[chat, contacts, status, wallet, stickers, settings]
import view, views/channels_list, views/message_list, views/reactions, views/stickers as stickers_view
import ../../eventemitter

logScope:
  topics = "chat-controller"

type ChatController* = ref object
  view*: ChatsView
  status*: Status
  variant*: QVariant

proc newController*(status: Status): ChatController =
  result = ChatController()
  result.status = status
  result.view = newChatsView(status)
  result.variant = newQVariant(result.view)

proc delete*(self: ChatController) =
  delete self.variant
  delete self.view

include event_handling
include signal_handling

proc init*(self: ChatController) =
  self.handleMailserverEvents()
  self.handleChatEvents()
  self.handleSignals()

  let pubKey = self.status.settings.getSetting[:string](Setting.PublicKey, "0x0")
  let messagesFromContactsOnly = self.status.settings.getSetting[:bool](Setting.MessagesFromContactsOnly, false, true)

  # self.view.pubKey = pubKey
  self.view.setPubKey(pubKey)
  self.status.chat.init(pubKey, messagesFromContactsOnly)
  self.status.stickers.init()
  self.view.reactions.init()
  
  self.view.asyncActivityNotificationLoad()

  let recentStickers = self.status.stickers.getRecentStickers()
  for sticker in recentStickers:
    self.view.stickers.addRecentStickerToList(sticker)
    self.status.stickers.addStickerToRecent(sticker)
  
  if self.status.network.isConnected:
    self.view.stickers.obtainAvailableStickerPacks()
  else:
    self.view.stickers.populateOfflineStickerPacks()

  self.status.events.on("network:disconnected") do(e: Args):
    self.view.stickers.clearStickerPacks()
    self.view.stickers.populateOfflineStickerPacks()

  self.status.events.on("network:connected") do(e: Args):
    self.view.stickers.clearStickerPacks()
    self.view.stickers.obtainAvailableStickerPacks()
