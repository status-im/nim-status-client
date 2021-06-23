import json, os, nimcrypto, uuids, json_serialization, chronicles, strutils

from status_go import multiAccountGenerateAndDeriveAddresses, generateAlias, identicon, saveAccountAndLogin, login, openAccounts, getNodeConfig
import core
import utils as utils
import types as types
import accounts/constants
import ../signals/types as signal_types
import ../wallet/account
from settings as status_settings import nil

proc getNetworkConfig(currentNetwork: string): JsonNode =
  result = constants.DEFAULT_NETWORKS.first("id", currentNetwork)


proc getNodeConfig*(fleetConfig: FleetConfig, installationId: string, networkConfig: JsonNode, fleet: Fleet = Fleet.PROD, useDefaultConfig: bool = false): JsonNode =
  let upstreamUrl = networkConfig["config"]["UpstreamConfig"]["URL"]
  var newDataDir = networkConfig["config"]["DataDir"].getStr
  newDataDir.removeSuffix("_rpc")

  if useDefaultConfig:
    result = constants.NODE_CONFIG.copy()
  else:
    result = getNodeConfig().parseJSON()
  result["ClusterConfig"]["Fleet"] = newJString($fleet)
  result["ClusterConfig"]["BootNodes"] = %* fleetConfig.getNodes(fleet, FleetNodes.Bootnodes)
  result["ClusterConfig"]["TrustedMailServers"] = %* fleetConfig.getNodes(fleet, FleetNodes.Mailservers)
  result["ClusterConfig"]["StaticNodes"] = %* fleetConfig.getNodes(fleet, FleetNodes.Whisper)
  result["ClusterConfig"]["RendezvousNodes"] = %* fleetConfig.getNodes(fleet, FleetNodes.Rendezvous)
  result["ClusterConfig"]["WakuNodes"] =  %* fleetConfig.getNodes(fleet, FleetNodes.Waku)
  result["ClusterConfig"]["WakuStoreNodes"] =  %* fleetConfig.getNodes(fleet, FleetNodes.Waku)

  result["NetworkId"] = networkConfig["config"]["NetworkId"]
  result["DataDir"] = newDataDir.newJString()
  result["UpstreamConfig"]["Enabled"] = networkConfig["config"]["UpstreamConfig"]["Enabled"]
  result["UpstreamConfig"]["URL"] = upstreamUrl
  result["ShhextConfig"]["InstallationID"] = newJString(installationId)

  # TODO: commented since it's not necessary (we do the connections thru C bindings). Enable it thru an option once status-nodes are able to be configured in desktop
  # result["ListenAddr"] = if existsEnv("STATUS_PORT"): newJString("0.0.0.0:" & $getEnv("STATUS_PORT")) else: newJString("0.0.0.0:30305")

proc getNodeConfig*(fleetConfig: FleetConfig, installationId: string, currentNetwork: string = constants.DEFAULT_NETWORK_NAME, fleet: Fleet = Fleet.PROD, useDefaultConfig: bool = false): JsonNode =
  let networkConfig = getNetworkConfig(currentNetwork)
  result = getNodeConfig(fleetConfig, installationId, networkConfig, fleet, useDefaultConfig)

proc hashPassword*(password: string): string =
  result = "0x" & $keccak_256.digest(password)

proc getDefaultAccount*(): string =
  var response = callPrivateRPC("eth_accounts")
  result = parseJson(response)["result"][0].getStr()

proc generateAddresses*(n = 5): seq[GeneratedAccount] =
  let multiAccountConfig = %* {
    "n": n,
    "mnemonicPhraseLength": 12,
    "bip39Passphrase": "",
    "paths": [PATH_WALLET_ROOT, PATH_EIP_1581, PATH_WHISPER, PATH_DEFAULT_WALLET]
  }
  let generatedAccounts = $status_go.multiAccountGenerateAndDeriveAddresses($multiAccountConfig)
  result = Json.decode(generatedAccounts, seq[GeneratedAccount])

proc generateAlias*(publicKey: string): string =
  result = $status_go.generateAlias(publicKey)

proc generateIdenticon*(publicKey: string): string =
  result = $status_go.identicon(publicKey)

proc initNode*() =
  createDir(STATUSGODIR)
  createDir(KEYSTOREDIR)
  discard $status_go.initKeystore(KEYSTOREDIR)

proc parseIdentityImage*(images: JsonNode): IdentityImage =
  result = IdentityImage()
  if (images.kind != JNull):
    for image in images:
      if (image["type"].getStr == "thumbnail"):
        # TODO check if this can be url or if it's always uri
        result.thumbnail = image["uri"].getStr
      elif (image["type"].getStr == "large"):
        result.large = image["uri"].getStr

proc openAccounts*(): seq[NodeAccount] =
  let strNodeAccounts = status_go.openAccounts(STATUSGODIR).parseJson
  # FIXME fix serialization
  result = @[]
  if (strNodeAccounts.kind != JNull):
    for account in strNodeAccounts:
      let nodeAccount = NodeAccount(
        name: account["name"].getStr,
        timestamp: account["timestamp"].getInt,
        keyUid: account["key-uid"].getStr,
        identicon: account["identicon"].getStr,
        keycardPairing: account["keycard-pairing"].getStr
      )
      if (account{"images"}.kind != JNull):
        nodeAccount.identityImage = parseIdentityImage(account["images"])

      result.add(nodeAccount)


proc saveAccountAndLogin*(
  account: GeneratedAccount,
  accountData: string,
  password: string,
  configJSON: string,
  settingsJSON: string): types.Account =
  let hashedPassword = hashPassword(password)
  let subaccountData = %* [
    {
      "public-key": account.derived.defaultWallet.publicKey,
      "address": account.derived.defaultWallet.address,
      "color": "#4360df",
      "wallet": true,
      "path": constants.PATH_DEFAULT_WALLET,
      "name": "Status account"
    },
    {
      "public-key": account.derived.whisper.publicKey,
      "address": account.derived.whisper.address,
      "name": account.name,
      "identicon": account.identicon,
      "path": constants.PATH_WHISPER,
      "chat": true
    }
  ]

  var savedResult = $status_go.saveAccountAndLogin(accountData, hashedPassword, settingsJSON, configJSON, $subaccountData)
  let parsedSavedResult = savedResult.parseJson
  let error = parsedSavedResult["error"].getStr

  if error == "":
    debug "Account saved succesfully"
    result = account.toAccount
    return

  raise newException(StatusGoException, "Error saving account and logging in: " & error)

proc storeDerivedAccounts*(account: GeneratedAccount, password: string, paths: seq[string] = @[PATH_WALLET_ROOT, PATH_EIP_1581, PATH_WHISPER, PATH_DEFAULT_WALLET]): MultiAccounts =
  let hashedPassword = hashPassword(password)
  let multiAccount = %* {
    "accountID": account.id,
    "paths": paths,
    "password": hashedPassword
  }
  let response = $status_go.multiAccountStoreDerivedAccounts($multiAccount);

  try:
    result = Json.decode($response, MultiAccounts)
  except:
    let err = Json.decode($response, StatusGoError)
    raise newException(StatusGoException, "Error storing multiaccount derived accounts: " & err.error)

proc getAccountData*(account: GeneratedAccount): JsonNode =
  result = %* {
    "name": account.name,
    "address": account.address,
    "identicon": account.identicon,
    "key-uid": account.keyUid,
    "keycard-pairing": nil
  }

proc getAccountSettings*(account: GeneratedAccount, defaultNetworks: JsonNode, installationId: string): JsonNode =
  result = %* {
    "key-uid": account.keyUid,
    "mnemonic": account.mnemonic,
    "public-key": account.derived.whisper.publicKey,
    "name": account.name,
    "address": account.address,
    "eip1581-address": account.derived.eip1581.address,
    "dapps-address": account.derived.defaultWallet.address,
    "wallet-root-address": account.derived.walletRoot.address,
    "preview-privacy?": true,
    "signing-phrase": generateSigningPhrase(3),
    "log-level": "INFO",
    "latest-derived-path": 0,
    "networks/networks": defaultNetworks,
    "currency": "usd",
    "identicon": account.identicon,
    "waku-enabled": true,
    "wallet/visible-tokens": {
      "mainnet": ["SNT"]
    },
    "appearance": 0,
    "networks/current-network": constants.DEFAULT_NETWORK_NAME,
    "installation-id": installationId
  }

proc setupAccount*(fleetConfig: FleetConfig, account: GeneratedAccount, password: string): types.Account =
  try:
    let storeDerivedResult = storeDerivedAccounts(account, password)
    let accountData = getAccountData(account)
    let installationId = $genUUID()
    var settingsJSON = getAccountSettings(account, constants.DEFAULT_NETWORKS, installationId)
    var nodeConfig = getNodeConfig(fleetConfig, installationId, constants.DEFAULT_NETWORK_NAME, Fleet.PROD, true)

    result = saveAccountAndLogin(account, $accountData, password, $nodeConfig, $settingsJSON)

  except StatusGoException as e:
    raise newException(StatusGoException, "Error setting up account: " & e.msg)

  finally:
    # TODO this is needed for now for the retrieving of past messages. We'll either move or remove it later
    let peer = "enode://44160e22e8b42bd32a06c1532165fa9e096eebedd7fa6d6e5f8bbef0440bc4a4591fe3651be68193a7ec029021cdb496cfe1d7f9f1dc69eb99226e6f39a7a5d4@35.225.221.245:443"
    discard status_go.addPeer(peer)

proc login*(nodeAccount: NodeAccount, password: string): NodeAccount =
  let hashedPassword = hashPassword(password)
  let account = nodeAccount.toAccount
  let loginResult = $status_go.login($toJson(account), hashedPassword)
  let error = parseJson(loginResult)["error"].getStr

  if error == "":
    debug "Login requested", user=nodeAccount.name
    result = nodeAccount
    return

  raise newException(StatusGoException, "Error logging in: " & error)

proc loadAccount*(address: string, password: string): GeneratedAccount =
  let hashedPassword = hashPassword(password)
  let inputJson = %* {
    "address": address,
    "password": hashedPassword
  }
  let loadResult = $status_go.multiAccountLoadAccount($inputJson)
  let parsedLoadResult = loadResult.parseJson
  let error = parsedLoadResult{"error"}.getStr

  if error == "":
    debug "Account loaded succesfully"
    result = Json.decode(loadResult, GeneratedAccount)
    return

  raise newException(StatusGoException, "Error loading wallet account: " & error)

proc verifyAccountPassword*(address: string, password: string): bool =
  let hashedPassword = hashPassword(password)
  let verifyResult = $status_go.verifyAccountPassword(KEYSTOREDIR, address, hashedPassword)
  let error = parseJson(verifyResult)["error"].getStr

  if error == "":
    return true

  return false

proc multiAccountImportMnemonic*(mnemonic: string): GeneratedAccount =
  let mnemonicJson = %* {
    "mnemonicPhrase": mnemonic,
    "Bip39Passphrase": ""
  }
  # status_go.multiAccountImportMnemonic never results in an error given ANY input
  let importResult = $status_go.multiAccountImportMnemonic($mnemonicJson)
  result = Json.decode(importResult, GeneratedAccount)

proc MultiAccountImportPrivateKey*(privateKey: string): GeneratedAccount =
  let privateKeyJson = %* {
    "privateKey": privateKey
  }
  # status_go.MultiAccountImportPrivateKey never results in an error given ANY input
  try:
    let importResult = $status_go.multiAccountImportPrivateKey($privateKeyJson)
    result = Json.decode(importResult, GeneratedAccount)
  except Exception as e:
    error "Error getting account from private key", msg=e.msg


proc storeDerivedWallet*(account: GeneratedAccount, password: string, walletIndex: int, accountType: string): string =
  let hashedPassword = hashPassword(password)
  let derivationPath = (if accountType == constants.GENERATED: "m/" else: "m/44'/60'/0'/0/") & $walletIndex
  let multiAccount = %* {
    "accountID": account.id,
    "paths": [derivationPath],
    "password": hashedPassword
  }
  let response = parseJson($status_go.multiAccountStoreDerivedAccounts($multiAccount));
  let error = response{"error"}.getStr
  if error == "":
    debug "Wallet stored succesfully"
    return "m/44'/60'/0'/0/" & $walletIndex
  raise newException(StatusGoException, error)

proc storePrivateKeyAccount*(account: GeneratedAccount, password: string) =
  let hashedPassword = hashPassword(password)
  let response = parseJson($status_go.multiAccountStoreAccount($(%*{"accountID": account.id, "password": hashedPassword})));
  let error = response{"error"}.getStr
  if error == "":
    debug "Wallet stored succesfully"
    return

  raise newException(StatusGoException, error)

proc saveAccount*(account: GeneratedAccount, password: string, color: string, accountType: string, isADerivedAccount = true, walletIndex: int = 0 ): DerivedAccount =
  try:
    var derivationPath = "m/44'/60'/0'/0/0"
    if (isADerivedAccount):
      # Only store derived accounts. Private key accounts are not multiaccounts
      derivationPath = storeDerivedWallet(account, password, walletIndex, accountType)
    elif accountType == constants.KEY:
      storePrivateKeyAccount(account, password)

    var address = account.derived.defaultWallet.address
    var publicKey = account.derived.defaultWallet.publicKey

    if (address == ""):
      address = account.address
      publicKey = account.publicKey

    echo callPrivateRPC("accounts_saveAccounts", %* [
      [{
        "color": color,
        "name": account.name,
        "address": address,
        "public-key": publicKey,
        "type": accountType,
        "path": derivationPath
      }]
    ])

    result = DerivedAccount(address: address, publicKey: publicKey, derivationPath: derivationPath)
  except:
    error "Error storing the new account. Bad password?"
    raise

proc changeAccount*(account: WalletAccount): string =
  try:
    let response = callPrivateRPC("accounts_saveAccounts", %* [
      [{
        "color": account.iconColor,
        "name": account.name,
        "address": account.address,
        "public-key": account.publicKey,
        "type": account.walletType,
        "path": "m/44'/60'/0'/0/1" # <--- TODO: fix this. Derivation path is not supposed to change
      }]
    ])

    utils.handleRPCErrors(response)
    return ""
  except Exception as e:
    error "Error saving the account", msg=e.msg
    result = e.msg

proc deleteAccount*(address: string): string =
  try:
    let response = callPrivateRPC("accounts_deleteAccount", %* [address])

    utils.handleRPCErrors(response)
    return ""
  except Exception as e:
    error "Error removing the account", msg=e.msg
    result = e.msg

proc deriveWallet*(accountId: string, walletIndex: int): DerivedAccount =
  let path = "m/" & $walletIndex
  let deriveJson = %* {
    "accountID": accountId,
    "paths": [path]
  }
  let deriveResult = parseJson($status_go.multiAccountDeriveAddresses($deriveJson))
  result = DerivedAccount(
    address: deriveResult[path]["address"].getStr,
    publicKey: deriveResult[path]["publicKey"].getStr)

proc deriveAccounts*(accountId: string): MultiAccounts =
  let deriveJson = %* {
    "accountID": accountId,
    "paths": [PATH_WALLET_ROOT, PATH_EIP_1581, PATH_WHISPER, PATH_DEFAULT_WALLET]
  }
  let deriveResult = $status_go.multiAccountDeriveAddresses($deriveJson)
  result = Json.decode(deriveResult, MultiAccounts)

proc logout*(): StatusGoError =
  result = Json.decode($status_go.logout(), StatusGoError)

proc storeIdentityImage*(keyUID: string, imagePath: string, aX, aY, bX, bY: int): IdentityImage =
  let response = callPrivateRPC("multiaccounts_storeIdentityImage", %* [keyUID, imagePath, aX, aY, bX, bY]).parseJson
  result = parseIdentityImage(response{"result"})

proc getIdentityImage*(keyUID: string): IdentityImage =
  try:
    let response = callPrivateRPC("multiaccounts_getIdentityImages", %* [keyUID]).parseJson
    result = parseIdentityImage(response{"result"})
  except Exception as e:
    error "Error getting identity image", msg=e.msg

proc deleteIdentityImage*(keyUID: string): string =
  try:
    let response = callPrivateRPC("multiaccounts_deleteIdentityImage", %* [keyUID]).parseJson
    result = ""
  except Exception as e:
    error "Error getting identity image", msg=e.msg
    result = e.msg
