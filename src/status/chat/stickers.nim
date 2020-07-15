import chronicles
import ../libstatus/stickers as libstatus_stickers

logScope:
  topics = "sticker-decoding"

# TODO: this is for testing purposes, the correct function should decode the hash
proc decodeContentHash*(value: string): string =
  libstatus_stickers.decodeContentHash(value)