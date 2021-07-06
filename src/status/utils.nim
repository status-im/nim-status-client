import json, random, strutils, strformat, tables, chronicles, unicode, times
from sugar import `=>`, `->`
import stint
from times import getTime, toUnix, nanosecond
import libstatus/accounts/signing_phrases
from web3 import Address, fromHex
import web3/ethhexstrings

proc getTimelineChatId*(pubKey: string = ""): string =
  if pubKey == "":
    return "@timeline70bd746ddcc12beb96b2c9d572d0784ab137ffc774f5383e50585a932080b57cca0484b259e61cecbaa33a4c98a300a"
  else:
    return "@" & pubKey

proc isWakuEnabled(): bool =
  true # TODO:

proc prefix*(methodName: string, isExt:bool = true): string =
  result = if isWakuEnabled(): "waku" else: "shh" 
  result = result & (if isExt: "ext_" else: "_")
  result = result & methodName

proc isOneToOneChat*(chatId: string): bool =
  result = chatId.startsWith("0x") # There is probably a better way to do this

proc keys*(obj: JsonNode): seq[string] =
  result = newSeq[string]()
  for k, _ in obj:
    result.add k

proc generateSigningPhrase*(count: int): string =
  let now = getTime()
  var rng = initRand(now.toUnix * 1000000000 + now.nanosecond)
  var phrases: seq[string] = @[]
  
  for i in 1..count:
    phrases.add(rng.sample(signing_phrases.phrases))

  result = phrases.join(" ")

proc handleRPCErrors*(response: string) =
  let parsedReponse = parseJson(response)
  if (parsedReponse.hasKey("error")):
    raise newException(ValueError, parsedReponse["error"]["message"].str)

proc toStUInt*[bits: static[int]](flt: float, T: typedesc[StUint[bits]]): T =
  var stringValue =  fmt"{flt:<.0f}"
  stringValue.removeSuffix('.')
  if (flt >= 0):
    result = parse($stringValue, StUint[bits])
  else:
    result = parse("0", StUint[bits])

proc toUInt256*(flt: float): UInt256 =
  toStUInt(flt, StUInt[256])

proc toUInt64*(flt: float): StUInt[64] =
  toStUInt(flt, StUInt[64])

proc eth2Wei*(eth: float, decimals: int = 18): UInt256 =
  let weiValue = eth * parseFloat(alignLeft("1", decimals + 1, '0'))
  weiValue.toUInt256

proc gwei2Wei*(gwei: float): UInt256 =
  eth2Wei(gwei, 9)

proc wei2Eth*(input: Stuint[256], decimals: int = 18): string =
  var one_eth = u256(10).pow(decimals) # fromHex(Stuint[256], "DE0B6B3A7640000")

  var (eth, remainder) = divmod(input, one_eth)
  let leading_zeros = "0".repeat(($one_eth).len - ($remainder).len - 1)

  fmt"{eth}.{leading_zeros}{remainder}"

proc wei2Eth*(input: string, decimals: int): string =
  try:
    var input256: Stuint[256]
    if input.contains("e+"): # we have a js string BN, ie 1e+21
      let
        inputSplit = input.split("e+")
        whole = inputSplit[0].u256
        remainder = u256(10).pow(inputSplit[1].parseInt)
      input256 = whole * remainder
    else:
      input256 = input.u256
    result = wei2Eth(input256, decimals)
  except Exception as e:
    error "Error parsing this wei value", input, msg=e.msg
    result = "0"
  
proc wei2Gwei*(input: string): string =
  result = wei2Eth(input, 9)

proc first*(jArray: JsonNode, fieldName, id: string): JsonNode =
  if jArray == nil:
    return nil
  if jArray.kind != JArray:
    raise newException(ValueError, "Parameter 'jArray' is a " & $jArray.kind & ", but must be a JArray")
  for child in jArray.getElems:
    if child{fieldName}.getStr.toLower == id.toLower:
      return child

proc any*(jArray: JsonNode, fieldName, id: string): bool =
  if jArray == nil:
    return false
  result = false
  for child in jArray.getElems:
    if child{fieldName}.getStr.toLower == id.toLower:
      return true

proc isEmpty*(a: JsonNode): bool =
  case a.kind:
  of JObject: return a.fields.len == 0
  of JArray: return a.elems.len == 0
  of JString: return a.str == ""
  of JNull: return true
  else:
    return false

proc find*[T](s: seq[T], pred: proc(x: T): bool {.closure.}): T {.inline.} =
  let results = s.filter(pred)
  if results.len == 0:
    return default(type(T))
  result = results[0]

proc find*[T](s: seq[T], pred: proc(x: T): bool {.closure.}, found: var bool): T {.inline.} =
  let results = s.filter(pred)
  if results.len == 0:
    found = false
    return default(type(T))
  result = results[0]
  found = true

proc parseAddress*(strAddress: string): Address =
  fromHex(Address, strAddress)

proc isAddress*(strAddress: string): bool =
  try:
    discard parseAddress(strAddress)
  except:
    return false
  return true

proc validateTransactionInput*(from_addr, to_addr, assetAddress, value, gas, gasPrice, data: string, isEIP1599Enabled: bool, maxPriorityFeePerGas, maxFeePerGas, uuid: string) =
  if not isAddress(from_addr): raise newException(ValueError, "from_addr is not a valid ETH address")
  if not isAddress(to_addr): raise newException(ValueError, "to_addr is not a valid ETH address")
  if parseFloat(value) < 0: raise newException(ValueError, "value should be a number >= 0")
  if parseInt(gas) <= 0: raise newException(ValueError, "gas should be a number > 0")
  if isEIP1599Enabled:
    if parseFloat(maxPriorityFeePerGas) <= 0: raise newException(ValueError, "maxPriorityFeePerGas should be a number > 0")
    if parseFloat(maxFeePerGas) <= 0: raise newException(ValueError, "maxFeePerGas should be a number > 0")
  else:
    if parseFloat(gasPrice) <= 0: raise newException(ValueError, "gasPrice should be a number > 0")
  if uuid.isEmptyOrWhitespace(): raise newException(ValueError, "uuid is required")

  if assetAddress != "": # If a token is being used
    if not isAddress(assetAddress): raise newException(ValueError, "assetAddress is not a valid ETH address")
    if assetAddress == "0x0000000000000000000000000000000000000000":  raise newException(ValueError, "assetAddress requires a valid token address")

  if data != "": # If data is being used
    if not validate(HexDataStr(data)): raise newException(ValueError, "data should contain a valid hex string")

proc hex2Time*(hex: string): Time =
  # represents the time since 1970-01-01T00:00:00Z
  fromUnix(fromHex[int64](hex))

proc hex2LocalDateTime*(hex: string): DateTime =
  # Convert hex time (since 1970-01-01T00:00:00Z) into a DateTime using the
  # local timezone. 
  hex.hex2Time.local

proc isUnique*[T](key: T, existingKeys: var seq[T]): bool =
  # If the key doesn't exist in the existingKeys seq, add it and return true.
  # Otherwise, the key already existed, so return false.
  # Can be used to deduplicate sequences with `deduplicate[T]`.
  if not existingKeys.contains(key):
    existingKeys.add key
    return true
  return false

proc deduplicate*[T](txs: var seq[T], key: (T) -> string) =
  var existingKeys: seq[string] = @[]
  txs.keepIf(tx => tx.key().isUnique(existingKeys))
