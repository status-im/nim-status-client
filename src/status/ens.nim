import strutils
import profile/profile
import nimcrypto
import json
import json_serialization
import tables
import strformat
import libstatus/core
import libstatus/types
import libstatus/utils
import libstatus/wallet
import stew/byteutils
import unicode
import transactions
import algorithm
import web3/[ethtypes, conversions], stew/byteutils, stint
import libstatus/eth/contracts
import chronicles, libp2p/[multihash, multicodec, cid]

const domain* = ".stateofus.eth"

proc userName*(ensName: string, removeSuffix: bool = false): string =
  if ensName != "" and ensName.endsWith(domain):
    if removeSuffix:
      result = ensName.split(".")[0]
    else:
      result = ensName
  else:
    if ensName.endsWith(".eth") and removeSuffix:
      return ensName.split(".")[0]
    result = ensName

proc addDomain*(username: string): string =
  if username.endsWith(".eth"):
    return username
  else:
    return username & domain

proc hasNickname*(contact: Profile): bool = contact.localNickname != ""

proc userNameOrAlias*(contact: Profile, removeSuffix: bool = false): string =
  if(contact.ensName != "" and contact.ensVerified):
    result = "@" & userName(contact.ensName, removeSuffix)
  elif(contact.localNickname != ""):
    result = contact.localNickname
  else:
    result = contact.alias

proc label*(username:string): string =
  let name = username.toLower()
  var node:array[32, byte] = keccak_256.digest(username).data
  result = "0x" & node.toHex()

proc namehash*(ensName:string): string =
  let name = ensName.toLower()
  var node:array[32, byte]

  node.fill(0)
  var parts = name.split(".")
  for i in countdown(parts.len - 1,0):
    let elem = keccak_256.digest(parts[i]).data
    var concatArrays: array[64, byte]
    concatArrays[0..31] = node
    concatArrays[32..63] = elem
    node = keccak_256.digest(concatArrays).data

  result = "0x" & node.toHex()

const registry* = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"
const resolver_signature = "0x0178b8bf"
proc resolver*(usernameHash: string): string =
  let payload = %* [{
    "to": registry,
    "from": "0x0000000000000000000000000000000000000000",
    "data": fmt"{resolver_signature}{userNameHash}"
  }, "latest"]
  let response = callPrivateRPC("eth_call", payload)
  # TODO: error handling
  var resolverAddr = response.parseJson["result"].getStr
  resolverAddr.removePrefix("0x000000000000000000000000")
  result = "0x" & resolverAddr

const owner_signature = "0x02571be3" # owner(bytes32 node)
proc owner*(username: string): string =
  var userNameHash = namehash(addDomain(username))
  userNameHash.removePrefix("0x")
  let payload = %* [{
    "to": registry,
    "from": "0x0000000000000000000000000000000000000000",
    "data": fmt"{owner_signature}{userNameHash}"
  }, "latest"]
  let response = callPrivateRPC("eth_call", payload)
  # TODO: error handling
  let ownerAddr = response.parseJson["result"].getStr;
  if ownerAddr == "0x0000000000000000000000000000000000000000000000000000000000000000":
    return ""
  result = "0x" & ownerAddr.substr(26)

const pubkey_signature = "0xc8690233" # pubkey(bytes32 node)
proc pubkey*(username: string): string =
  var userNameHash = namehash(addDomain(username))
  userNameHash.removePrefix("0x")
  let ensResolver = resolver(userNameHash)
  let payload = %* [{
    "to": ensResolver,
    "from": "0x0000000000000000000000000000000000000000",
    "data": fmt"{pubkey_signature}{userNameHash}"
  }, "latest"]
  let response = callPrivateRPC("eth_call", payload)
  # TODO: error handling
  var pubkey = response.parseJson["result"].getStr
  if pubkey == "0x" or pubkey == "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000":
    result = ""
  else:
    pubkey.removePrefix("0x")
    result = "0x04" & pubkey

const address_signature = "0x3b3b57de" # addr(bytes32 node)
proc address*(username: string): string =
  var userNameHash = namehash(addDomain(username))
  userNameHash.removePrefix("0x")
  let ensResolver = resolver(userNameHash)
  let payload = %* [{
    "to": ensResolver,
    "from": "0x0000000000000000000000000000000000000000",
    "data": fmt"{address_signature}{userNameHash}"
  }, "latest"]
  let response = callPrivateRPC("eth_call", payload)
  # TODO: error handling
  let address = response.parseJson["result"].getStr;
  if address == "0x0000000000000000000000000000000000000000000000000000000000000000":
    return ""
  result = "0x" & address.substr(26)

const contenthash_signature = "0xbc1c58d1" # contenthash(bytes32)
proc contenthash*(ensAddr: string): string =
  var ensHash = namehash(ensAddr)
  ensHash.removePrefix("0x")
  let ensResolver = resolver(ensHash)
  let payload = %* [{
    "to": ensResolver,
    "from": "0x0000000000000000000000000000000000000000",
    "data": fmt"{contenthash_signature}{ensHash}"
  }, "latest"]

  let response = callPrivateRPC("eth_call", payload)
  let bytesResponse = response.parseJson["result"].getStr;
  if bytesResponse == "0x":
    return ""

  let size = fromHex(Stuint[256], bytesResponse[66..129]).truncate(int)
  result = bytesResponse[130..129+size*2]


proc getPrice*(): Stuint[256] =
  let
    contract = contracts.getContract("ens-usernames")
    payload = %* [{
      "to": $contract.address,
      "data": contract.methods["getPrice"].encodeAbi()
    }, "latest"]

  let responseStr = callPrivateRPC("eth_call", payload)
  let response = Json.decode(responseStr, RpcResponse)
  if not response.error.isNil:
    raise newException(RpcException, "Error getting ens username price: " & response.error.message)
  if response.result == "0x":
    raise newException(RpcException, "Error getting ens username price: 0x")
  result = fromHex(Stuint[256], response.result)

proc extractCoordinates*(pubkey: string):tuple[x: string, y:string] =
  result = ("0x" & pubkey[4..67], "0x" & pubkey[68..131])

proc registerUsernameEstimateGas*(username: string, address: string, pubKey: string, success: var bool): int =
  let
    label = fromHex(FixedBytes[32], label(username))
    coordinates = extractCoordinates(pubkey)
    x = fromHex(FixedBytes[32], coordinates.x)
    y =  fromHex(FixedBytes[32], coordinates.y)
    ensUsernamesContract = contracts.getContract("ens-usernames")
    sntContract = contracts.getSntContract()
    price = getPrice()

  let
    register = Register(label: label, account: parseAddress(address), x: x, y: y)
    registerAbiEncoded = ensUsernamesContract.methods["register"].encodeAbi(register)
    approveAndCallObj = ApproveAndCall[132](to: ensUsernamesContract.address, value: price, data: DynamicBytes[132].fromHex(registerAbiEncoded))
    approveAndCallAbiEncoded = sntContract.methods["approveAndCall"].encodeAbi(approveAndCallObj)

  var tx = transactions.buildTokenTransaction(parseAddress(address), sntContract.address, "", "")

  let response = sntContract.methods["approveAndCall"].estimateGas(tx, approveAndCallObj, success)
  if success:
    result = fromHex[int](response)

proc registerUsername*(username, pubKey, address, gas, gasPrice,  password: string, success: var bool): string =
  let
    label = fromHex(FixedBytes[32], label(username))
    coordinates = extractCoordinates(pubkey)
    x = fromHex(FixedBytes[32], coordinates.x)
    y =  fromHex(FixedBytes[32], coordinates.y)
    ensUsernamesContract = contracts.getContract("ens-usernames")
    sntContract = contracts.getSntContract()
    price = getPrice()

  let
    register = Register(label: label, account: parseAddress(address), x: x, y: y)
    registerAbiEncoded = ensUsernamesContract.methods["register"].encodeAbi(register)
    approveAndCallObj = ApproveAndCall[132](to: ensUsernamesContract.address, value: price, data: DynamicBytes[132].fromHex(registerAbiEncoded))

  var tx = transactions.buildTokenTransaction(parseAddress(address), sntContract.address, gas, gasPrice)

  result = sntContract.methods["approveAndCall"].send(tx, approveAndCallObj, password, success)
  if success:
    trackPendingTransaction(result, address, $sntContract.address, PendingTransactionType.RegisterENS, username & domain)

proc setPubKeyEstimateGas*(username: string, address: string, pubKey: string, success: var bool): int =
  var hash = namehash(username)
  hash.removePrefix("0x")

  let
    label = fromHex(FixedBytes[32], "0x" & hash)
    x = fromHex(FixedBytes[32], "0x" & pubkey[4..67])
    y =  fromHex(FixedBytes[32], "0x" & pubkey[68..131])
    resolverContract = contracts.getContract("ens-resolver")
    setPubkey = SetPubkey(label: label, x: x, y: y)
    resolverAddress = resolver(hash)

  var tx = transactions.buildTokenTransaction(parseAddress(address), parseAddress(resolverAddress), "", "")

  try:
    let response = resolverContract.methods["setPubkey"].estimateGas(tx, setPubkey, success)
    if success:
      result = fromHex[int](response)
  except RpcException as e:
    raise

proc setPubKey*(username, pubKey, address, gas, gasPrice, password: string, success: var bool): string =
  var hash = namehash(username)
  hash.removePrefix("0x")

  let
    label = fromHex(FixedBytes[32], "0x" & hash)
    x = fromHex(FixedBytes[32], "0x" & pubkey[4..67])
    y =  fromHex(FixedBytes[32], "0x" & pubkey[68..131])
    resolverContract = contracts.getContract("ens-resolver")
    setPubkey = SetPubkey(label: label, x: x, y: y)
    resolverAddress = resolver(hash)

  var tx = transactions.buildTokenTransaction(parseAddress(address), parseAddress(resolverAddress), gas, gasPrice)

  try:
    result = resolverContract.methods["setPubkey"].send(tx, setPubkey, password, success)
    if success:
      trackPendingTransaction(result, $address, resolverAddress, PendingTransactionType.SetPubKey, username)
  except RpcException as e:
    raise

proc statusRegistrarAddress*():string =
  result = $contracts.getContract("ens-usernames").address


type
  ENSType* {.pure.} = enum
    IPFS,
    SWARM,
    IPNS,
    UNKNOWN

proc decodeENSContentHash*(value: string): tuple[ensType: ENSType, output: string] =
  if value == "":
    return (ENSType.UNKNOWN, "")

  if value[0..5] == "e40101":
    return (ENSType.SWARM, value.split("1b20")[1])

  if value[0..7] == "e3010170":
    try:
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
      let
        multiHash = MultiHash.init(nimcrypto.fromHex(multiHashStr)).get()
        decoded = Cid.init(CIDv0, MultiCodec.codec(codec), multiHash).get()
      return (ENSType.IPFS, $decoded)
    except Exception as e:
      error "Error decoding ENS contenthash", hash=value, exception=e.msg
      raise

  if value[0..8] == "e50101700":
    return (ENSType.IPNS, parseHexStr(value[12..value.len-1]))

  return (ENSType.UNKNOWN, "")
