import strformat, httpclient, json, chronicles, sequtils, strutils, tables, sugar, net
import ../libstatus/core as status
import ../libstatus/eth/contracts as contracts
import ../libstatus/stickers as status_stickers
import ../libstatus/types
import web3/[conversions, ethtypes], stint
import ../libstatus/utils
import account

const CRYPTOKITTY* = "cryptokitty"
const KUDO* = "kudo"
const ETHERMON* = "ethermon"
const STICKER* = "stickers"

const COLLECTIBLE_TYPES* = [CRYPTOKITTY, KUDO, ETHERMON, STICKER]

const MAX_TOKENS = 200

proc getTokenUri(contract: Erc721Contract, tokenId: Stuint[256]): string =
  try:
    let
      tokenUri = TokenUri(tokenId: tokenId)
      payload = %* [{
        "to": $contract.address,
        "data": contract.methods["tokenURI"].encodeAbi(tokenUri)
      }, "latest"]
      response = callPrivateRPC("eth_call", payload)
    var postfixedResult: string = parseJson($response)["result"].str
    postfixedResult.removeSuffix('0')
    postfixedResult.removePrefix("0x")
    postfixedResult = parseHexStr(postfixedResult)
    let index = postfixedResult.find("http")
    if (index < -1):
      return ""
    result = postfixedResult[index ..  postfixedResult.high]
  except Exception as e:
    error "Error getting the token URI", mes = e.msg
    result = ""

proc tokenOfOwnerByIndex(contract: Erc721Contract, address: Address, index: Stuint[256]): int =
  let
    tokenOfOwnerByIndex = TokenOfOwnerByIndex(address: address, index: index)
    payload = %* [{
      "to": $contract.address,
      "data": contract.methods["tokenOfOwnerByIndex"].encodeAbi(tokenOfOwnerByIndex)
    }, "latest"]
    response = callPrivateRPC("eth_call", payload)
    jsonResponse = parseJson($response)
  if (not jsonResponse.hasKey("result")):
    return -1
  let res = jsonResponse["result"].getStr
  if (res == "0x"):
    return -1
  result = fromHex[int](res)

proc tokensOfOwnerByIndex(contract: Erc721Contract, address: Address): seq[int] =
  var index = 0
  var token: int
  result = @[]
  while (true):
    token = tokenOfOwnerByIndex(contract, address, index.u256)
    if (token == -1 or token == 0 or result.len > MAX_TOKENS):
      return result
    result.add(token)
    index = index + 1

proc getCryptoKittiesBatch*(address: Address, offset: int = 0): seq[Collectible] =
  var cryptokitties: seq[Collectible]
  cryptokitties = @[]
  # TODO handle testnet -- does this API exist in testnet??
  let url: string = fmt"https://api.cryptokitties.co/kitties?limit=20&offset={$offset}&owner_wallet_address={$address}&parents=false"
  let secureSSLContext = newContext()
  let client = newHttpClient(sslContext = secureSSLContext)
  client.headers = newHttpHeaders({ "Content-Type": "application/json" })

  let response = client.request(url)
  let responseBody = parseJson(response.body)
  let kitties = responseBody["kitties"]
  for kitty in kitties:
    try:
      var id = kitty["id"]
      var name = kitty["name"]
      var finalId = ""
      var finalName = ""
      if id.kind != JNull:
        finalId = $id
      if name.kind != JNull:
        finalName = $name
      cryptokitties.add(Collectible(id: finalId,
        name: finalName,
        image: kitty["image_url_png"].str,
        collectibleType: CRYPTOKITTY,
        description: "",
        externalUrl: ""))
    except Exception as e2:
      error "Error with this individual cat", msg = e2.msg, cat = kitty

  let limit = responseBody["limit"].getInt
  let total = responseBody["total"].getInt
  let currentCount = limit * (offset + 1)
  if (currentCount < total and currentCount < MAX_TOKENS):
    # Call the API again with offset + 1
    let nextBatch = getCryptoKittiesBatch(address, offset + 1)
    return concat(cryptokitties, nextBatch)
  return cryptokitties

proc getCryptoKitties*(address: Address): string =
  try:
    let cryptokitties = getCryptoKittiesBatch(address, 0)
  
    return $(%*cryptokitties)
  except Exception as e:
    error "Error getting Cryptokitties", msg = e.msg
    return e.msg

proc getCryptoKitties*(address: string): string =
  let eth_address = parseAddress(address)
  result = getCryptoKitties(eth_address)

proc getEthermons*(address: Address): string =
  try:
    var ethermons: seq[Collectible]
    ethermons = @[]
    let contract = getErc721Contract("ethermon")
    if contract == nil: return $(%*ethermons)

    let tokens = tokensOfOwnerByIndex(contract, address)

    if (tokens.len == 0):
      return $(%*ethermons)

    let tokensJoined = strutils.join(tokens, ",")
    let url = fmt"https://www.ethermon.io/api/monster/get_data?monster_ids={tokensJoined}"
    let secureSSLContext = newContext()
    let client = newHttpClient(sslContext = secureSSLContext)
    client.headers = newHttpHeaders({ "Content-Type": "application/json" })

    let response = client.request(url)
    let monsters = parseJson(response.body)["data"]
    var i = 0
    for monsterKey in json.keys(monsters):
      let monster = monsters[monsterKey]
      ethermons.add(Collectible(id: $tokens[i],
      name: monster["class_name"].str,
      image: monster["image"].str,
      collectibleType: ETHERMON,
      description: "",
      externalUrl: ""))
      i = i + 1
        
    return $(%*ethermons)
  except Exception as e:
    error "Error getting Ethermons", msg = e.msg
    result = e.msg

proc getEthermons*(address: string): string =
  let eth_address = parseAddress(address)
  result = getEthermons(eth_address)

proc getKudos*(address: Address): string =
  try:
    var kudos: seq[Collectible]
    kudos = @[]
    let contract = getErc721Contract("kudos")
    if contract == nil: return  $(%*kudos)
    
    let tokens = tokensOfOwnerByIndex(contract, address)

    if (tokens.len == 0):
      return $(%*kudos)

    for token in tokens:
      let url =  getTokenUri(contract, token.u256)

      if (url == ""):
        return  $(%*kudos)

      let secureSSLContext = newContext()
      let client = newHttpClient(sslContext = secureSSLContext)
      client.headers = newHttpHeaders({ "Content-Type": "application/json" })

      let response = client.request(url)
      let kudo = parseJson(response.body)

      kudos.add(Collectible(id: $token,
      name: kudo["name"].str,
      image: kudo["image"].str,
      collectibleType: KUDO,
      description: kudo["description"].str,
      externalUrl: kudo["external_url"].str))

    return $(%*kudos)
  except Exception as e:
    error "Error getting Kudos", msg = e.msg
    result = e.msg

proc getKudos*(address: string): string =
  let eth_address = parseAddress(address)
  result = getKudos(eth_address)

proc getStickers*(address: Address): string =
  try:
    var stickers: seq[Collectible]
    stickers = @[]
    let contract = getErc721Contract("sticker-pack")
    if contract == nil: return
    
    let tokensIds = tokensOfOwnerByIndex(contract, address)

    if (tokensIds.len == 0):
      return $(%*stickers)

    let purchasedStickerPacks = tokensIds.map(tokenId => status_stickers.getPackIdFromTokenId(tokenId.u256))

    if (purchasedStickerPacks.len == 0):
      return $(%*stickers)
    # TODO find a way to keep those in memory so as not to reload it each time
    let availableStickerPacks = getAvailableStickerPacks()

    var index = 0
    for stickerId in purchasedStickerPacks:
      let sticker = availableStickerPacks[stickerId]
      stickers.add(Collectible(id: $tokensIds[index],
        name: sticker.name,
        image: fmt"https://ipfs.infura.io/ipfs/{status_stickers.decodeContentHash(sticker.preview)}",
        collectibleType: STICKER,
        description: sticker.author,
        externalUrl: "")
      )
      index = index + 1

    return $(%*stickers)
  except Exception as e:
    error "Error getting Stickers", msg = e.msg
    result = e.msg

proc getStickers*(address: string): string =
  let eth_address = parseAddress(address)
  result = getStickers(eth_address)
