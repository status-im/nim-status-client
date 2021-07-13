import NimQml, std/wrapnils, chronicles
import ../../../status/status
import ../../../status/chat/message
import ../../../status/chat/stickers
import message_format

QtObject:
  type MessageItem* = ref object of QObject
    messageItem*: Message
    status*: Status

  proc setup(self: MessageItem) =
    self.QObject.setup

  proc delete*(self: MessageItem) =
    self.QObject.delete

  proc newMessageItem*(status: Status): MessageItem =
    new(result, delete)
    result.status = status
    result.setup

  proc newMessageItem*(status: Status, message: Message): MessageItem =
    new(result, delete)
    result.messageItem = message
    result.status = status
    result.setup

  proc setMessageItem*(self: MessageItem, messageItem: Message) =
    self.messageItem = messageItem

  proc alias*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.alias
  QtProperty[string] alias:
    read = alias

  proc userName*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.userName
  QtProperty[string] userName:
    read = userName

  proc message*(self: MessageItem): string {.slot.} = result = renderBlock(self.messageItem, self.status.chat.contacts)
  QtProperty[string] message:
    read = message

  proc localName*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.localName
  QtProperty[string] localName:
    read = localName

  proc chatId*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.chatId
  QtProperty[string] chatId:
    read = chatId

  proc clock*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.clock
  QtProperty[int] clock:
    read = clock

  proc gapFrom*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.gapFrom
  QtProperty[int] gapFrom:
    read = gapFrom

  proc gapTo*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.gapTo
  QtProperty[int] gapTo:
    read = gapTo

  proc contentType*(self: MessageItem): int {.slot.} = result = self.messageItem.contentType.int
  QtProperty[int] contentType:
    read = contentType

  proc ensName*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.ensName
  QtProperty[string] ensName:
    read = ensName

  proc fromAuthor*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.fromAuthor
  QtProperty[string] fromAuthor:
    read = fromAuthor

  proc messageId*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.id
  QtProperty[string] messageId:
    read = messageId

  proc identicon*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.identicon
  QtProperty[string] identicon:
    read = identicon

  proc lineCount*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.lineCount
  QtProperty[int] lineCount:
    read = lineCount

  proc localChatId*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.localChatId
  QtProperty[string] localChatId:
    read = localChatId

  proc messageType*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.messageType
  QtProperty[string] messageType:
    read = messageType

  proc replace*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.replace
  QtProperty[string] replace:
    read = replace

  proc responseTo*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.responseTo
  QtProperty[string] responseTo:
    read = responseTo

  proc rtl*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.rtl
  QtProperty[bool] rtl:
    read = rtl

  proc seen*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.seen
  QtProperty[bool] seen:
    read = seen

  proc sticker*(self: MessageItem): string {.slot.} = result = self.messageItem.stickerHash.decodeContentHash()
  QtProperty[string] sticker:
    read = sticker

  proc sectionIdentifier*(self: MessageItem): string {.slot.} = result = sectionIdentifier(self.messageItem)
  QtProperty[string] sectionIdentifier:
    read = sectionIdentifier

  proc stickerPackId*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.stickerPackId
  QtProperty[int] stickerPackId:
    read = stickerPackId

  proc plainText*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.text
  QtProperty[string] plainText:
    read = plainText

  proc timestamp*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.timestamp
  QtProperty[string] timestamp:
    read = timestamp

  proc whisperTimestamp*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.whisperTimestamp
  QtProperty[string] whisperTimestamp:
    read = whisperTimestamp

  proc isCurrentUser*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.isCurrentUser
  QtProperty[bool] isCurrentUser:
    read = isCurrentUser

  proc stickerHash*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.stickerHash
  QtProperty[string] stickerHash:
    read = stickerHash

  proc outgoingStatus*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.outgoingStatus
  QtProperty[string] outgoingStatus:
    read = outgoingStatus

  proc linkUrls*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.linkUrls
  QtProperty[string] linkUrls:
    read = linkUrls

  proc image*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.image
  QtProperty[string] image:
    read = image


  proc audio*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.audio
  QtProperty[string] audio:
    read = audio

  proc communityId*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.communityId
  QtProperty[string] communityId:
    read = communityId

  proc audioDurationMs*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.audioDurationMs
  QtProperty[int] audioDurationMs:
    read = audioDurationMs

  proc hasMention*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.hasMention
  QtProperty[bool] hasMention:
    read = hasMention

  proc isPinned*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.isPinned
  QtProperty[bool] isPinned:
    read = isPinned

  proc pinnedBy*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.pinnedBy
  QtProperty[string] pinnedBy:
    read = pinnedBy