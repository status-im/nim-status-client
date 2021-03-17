import
  json, chronicles, strformat, stint, strutils, sequtils, tables, atomics

import
  web3/[ethtypes, conversions], json_serialization

import 
  ./settings, ./core, ./wallet, ./eth/contracts
from types import Setting, Network, RpcResponse, RpcException
from utils import parseAddress

logScope:
  topics = "wallet"

var
  customTokens {.threadvar.}: seq[Erc20Contract]
  customTokensInited {.threadvar.}: bool
  dirty: Atomic[bool]

dirty.store(true)

proc getCustomTokens*(useCached: bool = true): seq[Erc20Contract] =
  let cacheIsDirty = not customTokensInited or dirty.load
  if useCached and not cacheIsDirty:
    result = customTokens
  else: 
    let payload = %* []
    let responseStr = callPrivateRPC("wallet_getCustomTokens", payload)
    # TODO: this should be handled in the deserialisation of RpcResponse,
    # question has been posed: https://discordapp.com/channels/613988663034118151/616299964242460682/762828178624217109
    let response = RpcResponse(result: $(responseStr.parseJSON()["result"]))
    if not response.error.isNil:
      raise newException(RpcException, "Error getting custom tokens: " & response.error.message)
    result = if response.result == "null": @[] else: Json.decode(response.result, seq[Erc20Contract])
    dirty.store(false)
    customTokens = result
    customTokensInited = true

proc visibleTokensSNTDefault(): JsonNode =
  let currentNetwork = getCurrentNetwork()
  let SNT = if currentNetwork == Network.Mainnet: "SNT" else: "STT"
  let response = getSetting[string](Setting.VisibleTokens, "{}").parseJSON

  if not response.hasKey($currentNetwork):
    # Set STT/SNT visible by default
    response[$currentNetwork] = %* [SNT]

  return response

proc toggleAsset*(symbol: string) =
  let currentNetwork = getCurrentNetwork()
  let visibleTokens = visibleTokensSNTDefault()
  var visibleTokenList = visibleTokens[$currentNetwork].to(seq[string])
  let symbolIdx = visibleTokenList.find(symbol)
  if symbolIdx > -1:
    visibleTokenList.del(symbolIdx)
  else:
    visibleTokenList.add symbol
  visibleTokens[$currentNetwork] = newJArray()
  visibleTokens[$currentNetwork] = %* visibleTokenList
  discard saveSetting(Setting.VisibleTokens, $visibleTokens)

proc hideAsset*(symbol: string) =
  let currentNetwork = getCurrentNetwork()
  let visibleTokens = visibleTokensSNTDefault()
  var visibleTokenList = visibleTokens[$currentNetwork].to(seq[string])
  var symbolIdx = visibleTokenList.find(symbol)
  if symbolIdx > -1:
    visibleTokenList.del(symbolIdx)
  visibleTokens[$currentNetwork] = newJArray()
  visibleTokens[$currentNetwork] = %* visibleTokenList
  discard saveSetting(Setting.VisibleTokens, $visibleTokens)

proc getVisibleTokens*(): seq[Erc20Contract] =
  let currentNetwork = getCurrentNetwork()
  let visibleTokens = visibleTokensSNTDefault()
  var visibleTokenList = visibleTokens[$currentNetwork].to(seq[string])
  let customTokens = getCustomTokens()

  result = @[]
  for v in visibleTokenList:
    let t = getErc20Contract(v)
    if t != nil: result.add t
    let ct = customTokens.getErc20ContractBySymbol(v)
    if ct != nil: result.add ct
  
proc addCustomToken*(address: string, name: string, symbol: string, decimals: int, color: string) =
  let payload = %* [{"address": address, "name": name, "symbol": symbol, "decimals": decimals, "color": color}]
  discard callPrivateRPC("wallet_addCustomToken", payload)
  dirty.store(true)

proc removeCustomToken*(address: string) =
  let payload = %* [address]
  echo callPrivateRPC("wallet_deleteCustomToken", payload)
  dirty.store(true)

proc getTokensBalances*(accounts: openArray[string], tokens: openArray[string]): JsonNode =
  let payload = %* [accounts, tokens]
  let response = callPrivateRPC("wallet_getTokensBalances", payload).parseJson
  if response["result"].kind == JNull:
    return %* {}
  response["result"]

proc getToken*(tokenAddress: string): Erc20Contract =
  getErc20Contracts().concat(getCustomTokens()).getErc20ContractByAddress(tokenAddress.parseAddress)

proc getTokenBalance*(tokenAddress: string, account: string): string = 
  var postfixedAccount: string = account
  postfixedAccount.removePrefix("0x")
  let payload = %* [{
    "to": tokenAddress, "from": account, "data": fmt"0x70a08231000000000000000000000000{postfixedAccount}"
  }, "latest"]
  let response = callPrivateRPC("eth_call", payload)
  let balance = response.parseJson["result"].getStr

  var decimals = 18
  let address = parseAddress(tokenAddress)
  let t = getErc20Contract(address)
  let ct = getCustomTokens().getErc20ContractByAddress(address)
  if t != nil: 
    decimals = t.decimals
  elif ct != nil: 
    decimals = ct.decimals

  result = $hex2Token(balance, decimals)

proc getSNTAddress*(): string =
  let snt = contracts.getSntContract()
  result = $snt.address

proc getSNTBalance*(account: string): string =
  let snt = contracts.getSntContract()
  result = getTokenBalance($snt.address, account)

proc getTokenString*(contract: Contract, methodName: string): string =
  let payload = %* [{
      "to": $contract.address,
      "data": contract.methods[methodName].encodeAbi()
    }, "latest"]
  
  let responseStr = callPrivateRPC("eth_call", payload)
  let response = Json.decode(responseStr, RpcResponse)
  if not response.error.isNil:
    raise newException(RpcException, "Error getting token string - " & methodName & ": " & response.error.message)
  if response.result == "0x":
    return ""

  let size = fromHex(Stuint[256], response.result[66..129]).truncate(int)
  result = response.result[130..129+size*2].parseHexStr

proc tokenName*(contract: Contract): string = getTokenString(contract, "name")

proc tokenSymbol*(contract: Contract): string = getTokenString(contract, "symbol")

proc tokenDecimals*(contract: Contract): int =
  let payload = %* [{
      "to": $contract.address,
      "data": contract.methods["decimals"].encodeAbi()
    }, "latest"]
  
  let responseStr = callPrivateRPC("eth_call", payload)
  let response = Json.decode(responseStr, RpcResponse)
  if not response.error.isNil:
    raise newException(RpcException, "Error getting token decimals: " & response.error.message)
  if response.result == "0x":
    return 0
  result = parseHexInt(response.result)
