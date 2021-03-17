import ./core as status, ./types, ./eth/contracts, ./settings, ./edn_helpers
import
  json, json_serialization, tables, chronicles, sequtils, httpclient, net,
  stint, libp2p/[multihash, multicodec, cid], web3/[ethtypes, conversions]
from strutils import parseHexInt, parseInt
from nimcrypto import fromHex

proc decodeContentHash*(value: string): string =
  if value == "":
    return ""

  # eg encoded sticker multihash cid:
  #  e30101701220eab9a8ef4eac6c3e5836a3768d8e04935c10c67d9a700436a0e53199e9b64d29
  #  e3017012205c531b83da9dd91529a4cf8ecd01cb62c399139e6f767e397d2f038b820c139f (testnet)
  #  e3011220c04c617170b1f5725070428c01280b4c19ae9083b7e6d71b7a0d2a1b5ae3ce30 (testnet)
  #
  # The first 4 bytes (in hex) represent:
  # e3 = codec identifier "ipfs-ns" for content-hash
  # 01 = unused - sometimes this is NOT included (ie ropsten)
  # 01 = CID version (effectively unused, as we will decode with CIDv0 regardless)
  # 70 = codec identifier "dag-pb"

  # ipfs-ns
  if value[0..1] != "e3":
    warn "Could not decode sticker. It may still be valid, but requires a different codec to be used", hash=value
    return ""

  try:
    # dag-pb
    let defaultCodec = parseHexInt("70") #dag-pb
    var codec = defaultCodec # no codec specified
    var codecStartIdx = 2 # idx of where codec would start if it was specified
    # handle the case when starts with 0xe30170 instead of 0xe3010170
    if value[2..5] == "0101":
      codecStartIdx = 6
      codec = parseHexInt(value[6..7])
    elif value[2..3] == "01" and value[4..5] != "12":
      codecStartIdx = 4
      codec = parseHexInt(value[4..5])

    # strip the info we no longer need
    var multiHashStr = value[codecStartIdx + 2..<value.len]

    # The rest of the hash identifies the multihash algo, length, and digest
    # More info: https://multiformats.io/multihash/
    # 12 = identifies sha2-256 hash
    # 20 = multihash length = 32
    # ...rest = multihash digest
    let multiHash = MultiHash.init(nimcrypto.fromHex(multiHashStr)).get()
    let resultTyped = Cid.init(CIDv0, MultiCodec.codec(codec), multiHash).get()
    result = $resultTyped
    trace "Decoded sticker hash", cid=result
  except Exception as e:
    error "Error decoding sticker", hash=value, exception=e.msg
    raise

# Retrieves number of sticker packs owned by user
# See https://notes.status.im/Q-sQmQbpTOOWCQcYiXtf5g#Read-Sticker-Packs-owned-by-a-user
# for more details
proc getBalance*(address: Address): int =
  let contract = contracts.getContract("sticker-pack")
  if contract == nil: return 0

  let
    balanceOf = BalanceOf(address: address)
    payload = %* [{
      "to": $contract.address,
      "data": contract.methods["balanceOf"].encodeAbi(balanceOf)
    }, "latest"]

  let responseStr = status.callPrivateRPC("eth_call", payload)
  let response = Json.decode(responseStr, RpcResponse)
  if not response.error.isNil:
    raise newException(RpcException, "Error getting stickers balance: " & response.error.message)
  if response.result == "0x":
    return 0
  result = parseHexInt(response.result)

# Gets number of sticker packs
proc getPackCount*(): int =
  let contract = contracts.getContract("stickers")
  if contract == nil: return 0

  let payload = %* [{
      "to": $contract.address,
      "data": contract.methods["packCount"].encodeAbi()
    }, "latest"]

  let responseStr = status.callPrivateRPC("eth_call", payload)
  let response = Json.decode(responseStr, RpcResponse)
  if not response.error.isNil:
    raise newException(RpcException, "Error getting stickers balance: " & response.error.message)
  if response.result == "0x":
    return 0
  result = parseHexInt(response.result)

# Gets sticker pack data
proc getPackData*(id: Stuint[256]): StickerPack =
  let
    contract = contracts.getContract("stickers")
    contractMethod = contract.methods["getPackData"]
    getPackData = GetPackData(packId: id)
    payload = %* [{
      "to": $contract.address,
      "data": contractMethod.encodeAbi(getPackData)
      }, "latest"]
  let responseStr = status.callPrivateRPC("eth_call", payload)
  let response = Json.decode(responseStr, RpcResponse)
  if not response.error.isNil:
    raise newException(RpcException, "Error getting sticker pack data: " & response.error.message)

  let packData = contracts.decodeContractResponse[PackData](response.result)

  # contract response includes a contenthash, which needs to be decoded to reveal
  # an IPFS identifier. Once decoded, download the content from IPFS. This content
  # is in EDN format, ie https://ipfs.infura.io/ipfs/QmWVVLwVKCwkVNjYJrRzQWREVvEk917PhbHYAUhA1gECTM
  # and it also needs to be decoded in to a nim type
  let secureSSLContext = newContext()
  let client = newHttpClient(sslContext = secureSSLContext)
  let contentHash = contracts.toHex(packData.contentHash)
  let url = "https://ipfs.infura.io/ipfs/" & decodeContentHash(contentHash)
  var ednMeta = client.getContent(url)

  # decode the EDN content in to a StickerPack
  result = edn_helpers.decode[StickerPack](ednMeta)
  # EDN doesn't include a packId for each sticker, so add it here
  result.stickers.apply(proc(sticker: var Sticker) =
    sticker.packId = truncate(id, int))
  result.id = truncate(id, int)
  result.price = packData.price

proc tokenOfOwnerByIndex*(address: Address, idx: Stuint[256]): int =
  let
    contract = contracts.getContract("sticker-pack")
    tokenOfOwnerByIndex = TokenOfOwnerByIndex(address: address, index: idx)
    payload = %* [{
      "to": $contract.address,
      "data": contract.methods["tokenOfOwnerByIndex"].encodeAbi(tokenOfOwnerByIndex)
    }, "latest"]

  let responseStr = status.callPrivateRPC("eth_call", payload)
  let response = Json.decode(responseStr, RpcResponse)
  if not response.error.isNil:
    raise newException(RpcException, "Error getting owned tokens: " & response.error.message)
  if response.result == "0x":
    return 0
  result = parseHexInt(response.result)

proc getPackIdFromTokenId*(tokenId: Stuint[256]): int =
  let
    contract = contracts.getContract("sticker-pack")
    tokenPackId = TokenPackId(tokenId: tokenId)
    payload = %* [{
      "to": $contract.address,
      "data": contract.methods["tokenPackId"].encodeAbi(tokenPackId)
    }, "latest"]

  let responseStr = status.callPrivateRPC("eth_call", payload)
  let response = Json.decode(responseStr, RpcResponse)
  if not response.error.isNil:
    raise newException(RpcException, "Error getting pack id from token id: " & response.error.message)
  if response.result == "0x":
    return 0
  result = parseHexInt(response.result)

proc saveInstalledStickerPacks*(installedStickerPacks: Table[int, StickerPack]) =
  let json = %* {}
  for packId, pack in installedStickerPacks.pairs:
    json[$packId] = %(pack)
  discard settings.saveSetting(Setting.Stickers_PacksInstalled, $json)

proc saveRecentStickers*(stickers: seq[Sticker]) =
  discard settings.saveSetting(Setting.Stickers_Recent, %(stickers.mapIt($it.hash)))

proc getInstalledStickerPacks*(): Table[int, StickerPack] =
  let setting = settings.getSetting[string](Setting.Stickers_PacksInstalled, "{}").parseJson
  result = initTable[int, StickerPack]()
  for i in setting.keys:
    let packId = parseInt(i)
    result[packId] = Json.decode($(setting[i]), StickerPack)
    result[packId].stickers.apply(proc(sticker: var Sticker) =
      sticker.packId = packId)

proc getPackIdForSticker*(packs: Table[int, StickerPack], hash: string): int =
  for packId, pack in packs.pairs:
    if pack.stickers.any(proc(sticker: Sticker): bool = return sticker.hash == hash):
      return packId
  return 0

proc getRecentStickers*(): seq[Sticker] =
  # TODO: this should be a custom `readValue` implementation of nim-json-serialization
  let settings = settings.getSetting[seq[string]](Setting.Stickers_Recent, @[])
  let installedStickers = getInstalledStickerPacks()
  result = newSeq[Sticker]()
  for hash in settings:
    # pack id is not returned from status-go settings, populate here
    let packId = getPackIdForSticker(installedStickers, $hash)
    # .insert instead of .add to effectively reverse the order stickers because
    # stickers are re-reversed when added to the view due to the nature of
    # inserting recent stickers at the front of the list
    result.insert(Sticker(hash: $hash, packId: packId), 0)

proc getAvailableStickerPacks*(): Table[int, StickerPack] =
  var availableStickerPacks = initTable[int, StickerPack]()
  try:
    let numPacks = getPackCount()
    for i in 0..<numPacks:
      try:
        let stickerPack = getPackData(i.u256)
        availableStickerPacks[stickerPack.id] = stickerPack
      except:
        continue
    result = availableStickerPacks
  except RpcException:
    error "Error in getAvailableStickerPacks", message = getCurrentExceptionMsg()
    result = initTable[int, StickerPack]()
