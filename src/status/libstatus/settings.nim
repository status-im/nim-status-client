import
  json, tables, sugar, sequtils, strutils, atomics

import
  json_serialization, chronicles, uuids

import
  ./core, ./types, ../signals/types as statusgo_types, ./accounts/constants,
  ./utils

var
  settings {.threadvar.}: JsonNode
  settingsInited {.threadvar.}: bool
  dirty: Atomic[bool]

dirty.store(true)
settings = %* {}

proc saveSetting*(key: Setting, value: string | JsonNode): StatusGoError =
  try:
    let response = callPrivateRPC("settings_saveSetting", %* [key, value])
    let responseResult = $(response.parseJSON(){"result"})
    if responseResult == "null":
      result.error = ""
    else: result = Json.decode(response, StatusGoError)
  except Exception as e:
    error "Error saving setting", key=key, value=value, msg=e.msg
    dirty.store(true)

proc getWeb3ClientVersion*(): string =
  parseJson(callPrivateRPC("web3_clientVersion"))["result"].getStr

proc getSettings*(useCached: bool = true, keepSensitiveData: bool = false): JsonNode =
  let cacheIsDirty = (not settingsInited) or dirty.load
  if useCached and (not cacheIsDirty) and (not keepSensitiveData):
    result = settings
  else: 
    result = callPrivateRPC("settings_getSettings").parseJSON()["result"]
    if not keepSensitiveData:
      dirty.store(false)
      delete(result, "mnemonic")
      settings = result
      settingsInited = true

proc getSetting*[T](name: Setting, defaultValue: T, useCached: bool = true): T =
  let settings: JsonNode = getSettings(useCached, $name == "mnemonic")
  if not settings.contains($name) or settings{$name}.isEmpty():
    return defaultValue
  result = Json.decode($settings{$name}, T)

proc getSetting*[T](name: Setting, useCached: bool = true): T =
  result = getSetting(name, default(type(T)), useCached)

proc getCurrentNetwork*(): Network =
  case getSetting[string](Setting.Networks_CurrentNetwork, constants.DEFAULT_NETWORK_NAME):
  of "mainnet_rpc":
    result = Network.Mainnet
  of "testnet_rpc":
    result = Network.Testnet
  of "rinkeby_rpc":
    result = Network.Rinkeby
  of "goerli_rpc":
    result = Network.Goerli
  of "xdai_rpc":
    result = Network.XDai
  of "poa_rpc":
    result = Network.Poa
  else:
    result = Network.Other
    
proc getCurrentNetworkDetails*(): NetworkDetails =
  let currNetwork = getSetting[string](Setting.Networks_CurrentNetwork, constants.DEFAULT_NETWORK_NAME)
  let networks = getSetting[seq[NetworkDetails]](Setting.Networks_Networks)
  networks.find((network: NetworkDetails) => network.id == currNetwork)
    
proc getLinkPreviewWhitelist*(): JsonNode =
  result = callPrivateRPC("getLinkPreviewWhitelist".prefix, %* []).parseJSON()["result"]

proc getFleet*(): Fleet =
  let fleet = getSetting[string](Setting.Fleet, $Fleet.PROD)
  result = parseEnum[Fleet](fleet)

proc getPinnedMailserver*(): string =
  let pinnedMailservers = getSetting[JsonNode](Setting.PinnedMailservers, %*{})
  let fleet = getSetting[string](Setting.Fleet, $Fleet.PROD)
  return pinnedMailservers{fleet}.getStr()

proc pinMailserver*(enode: string = "") =
  let pinnedMailservers = getSetting[JsonNode](Setting.PinnedMailservers, %*{})
  let fleet = getSetting[string](Setting.Fleet, $Fleet.PROD)

  pinnedMailservers[fleet] = newJString(enode)
  discard saveSetting(Setting.PinnedMailservers, pinnedMailservers)

proc saveMailserver*(name, enode: string) =
  let fleet = getSetting[string](Setting.Fleet, $Fleet.PROD)
  let result = callPrivateRPC("mailservers_addMailserver", %* [
    %*{
      "id": $genUUID(),
      "name": name,
      "address": enode,
      "fleet": $fleet
    }
  ]).parseJSON()["result"]

proc getMailservers*():JsonNode =
  let fleet = getSetting[string](Setting.Fleet, $Fleet.PROD)
  result = callPrivateRPC("mailservers_getMailservers").parseJSON()["result"]

