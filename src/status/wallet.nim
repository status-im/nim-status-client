import json, strformat, strutils, chronicles, sequtils, httpclient, tables, net
import json_serialization, stint
from web3/ethtypes import Address, EthSend, Quantity
from web3/conversions import `$`
from libstatus/core import getBlockByNumber
import libstatus/accounts as status_accounts
import libstatus/tokens as status_tokens
import libstatus/settings as status_settings
import libstatus/wallet as status_wallet
import libstatus/accounts/constants as constants
import libstatus/eth/[eth, contracts]
from libstatus/core import getBlockByNumber
from libstatus/types import PendingTransactionType, GeneratedAccount, DerivedAccount, Transaction, Setting, GasPricePrediction, `%`, StatusGoException, Network, RpcResponse, RpcException
from libstatus/utils as libstatus_utils import eth2Wei, gwei2Wei, first, toUInt64, parseAddress
import wallet/[balance_manager, account, collectibles]
import transactions
import ../eventemitter
import options
export account, collectibles
export Transaction

logScope:
  topics = "wallet-model"

proc confirmed*(self:PendingTransactionType):string =
  result = "transaction:" & $self

type TransactionMinedArgs* = ref object of Args
  data*: string
  transactionHash*: string
  success*: bool
  revertReason*: string # TODO: possible to get revert reason in here?
    
type WalletModel* = ref object
  events*: EventEmitter
  accounts*: seq[WalletAccount]
  defaultCurrency*: string
  tokens*: seq[Erc20Contract]
  totalBalance*: float

proc getDefaultCurrency*(self: WalletModel): string
proc calculateTotalFiatBalance*(self: WalletModel)

proc newWalletModel*(events: EventEmitter): WalletModel =
  result = WalletModel()
  result.accounts = @[]
  result.tokens = @[]
  result.events = events
  result.defaultCurrency = ""
  result.totalBalance = 0.0

proc initEvents*(self: WalletModel) =
  self.events.on("currencyChanged") do(e: Args):
    self.defaultCurrency = self.getDefaultCurrency()
    for account in self.accounts:
      updateBalance(account, self.getDefaultCurrency())
    self.calculateTotalFiatBalance()
    self.events.emit("accountsUpdated", Args())

  self.events.on("newAccountAdded") do(e: Args):
   self.calculateTotalFiatBalance()

proc delete*(self: WalletModel) =
  discard

proc buildTokenTransaction(self: WalletModel, source, to, assetAddress: Address, value: float, transfer: var Transfer, contract: var Erc20Contract, gas = "", gasPrice = ""): EthSend =
  contract = getErc20Contract(assetAddress)
  if contract == nil:
    raise newException(ValueError, fmt"Could not find ERC-20 contract with address '{assetAddress}' for the current network")
  transfer = Transfer(to: to, value: eth2Wei(value, contract.decimals))
  transactions.buildTokenTransaction(source, assetAddress, gas, gasPrice)

proc getKnownTokenContract*(self: WalletModel, address: Address): Erc20Contract =
  getErc20Contracts().concat(getCustomTokens()).getErc20ContractByAddress(address)

proc estimateGas*(self: WalletModel, source, to, value, data: string, success: var bool): string =
  var tx = transactions.buildTransaction(
    parseAddress(source),
    eth2Wei(parseFloat(value), 18),
    data = data
  )
  tx.to = parseAddress(to).some
  result = eth.estimateGas(tx, success)

proc getTransactionReceipt*(self: WalletModel, transactionHash: string): JsonNode =
  result = status_wallet.getTransactionReceipt(transactionHash).parseJSON()["result"]

proc confirmTransactionStatus(self: WalletModel, pendingTransactions: JsonNode, blockNumber: int) =
  for trx in pendingTransactions.getElems():
    let transactionReceipt = self.getTransactionReceipt(trx["transactionHash"].getStr)
    if transactionReceipt.kind != JNull:
      status_wallet.deletePendingTransaction(trx["transactionHash"].getStr)
      let ev = TransactionMinedArgs(
                data: trx["data"].getStr,
                transactionHash: trx["transactionHash"].getStr,
                success: transactionReceipt{"status"}.getStr == "0x1",
                revertReason: ""
               )
      self.events.emit(parseEnum[PendingTransactionType](trx["type"].getStr).confirmed, ev)

proc checkPendingTransactions*(self: WalletModel) =
  let response = getBlockByNumber("latest").parseJson()
  if response.hasKey("result"):
    let latestBlock = parseInt($fromHex(Stuint[256], response["result"]["number"].getStr))
    let pendingTransactions = status_wallet.getPendingTransactions()
    if (pendingTransactions != ""):
      self.confirmTransactionStatus(pendingTransactions.parseJson["result"], latestBlock)
    

proc checkPendingTransactions*(self: WalletModel, address: string, blockNumber: int) =
  self.confirmTransactionStatus(status_wallet.getPendingOutboundTransactionsByAddress(address).parseJson["result"], blockNumber)
  
proc estimateTokenGas*(self: WalletModel, source, to, assetAddress, value: string, success: var bool): string =
  var
    transfer: Transfer
    contract: Erc20Contract
    tx = self.buildTokenTransaction(
      parseAddress(source),
      parseAddress(to),
      parseAddress(assetAddress),
      parseFloat(value),
      transfer,
      contract
    )

  result = contract.methods["transfer"].estimateGas(tx, transfer, success)

proc sendTransaction*(self: WalletModel, source, to, value, gas, gasPrice, password: string, success: var bool, data = ""): string =
  var tx = transactions.buildTransaction(
    parseAddress(source),
    eth2Wei(parseFloat(value), 18), gas, gasPrice, data
  )

  if to != "":
    tx.to = parseAddress(to).some

  result = eth.sendTransaction(tx, password, success)
  if success:
    trackPendingTransaction(result, $source, $to, PendingTransactionType.WalletTransfer, "")

proc sendTokenTransaction*(self: WalletModel, source, to, assetAddress, value, gas, gasPrice, password: string, success: var bool): string =
  var
    transfer: Transfer
    contract: Erc20Contract
    tx = self.buildTokenTransaction(
      parseAddress(source),
      parseAddress(to),
      parseAddress(assetAddress),
      parseFloat(value),
      transfer,
      contract,
      gas,
      gasPrice
    )

  result = contract.methods["transfer"].send(tx, transfer, password, success)
  if success:
    trackPendingTransaction(result, $source, $to, PendingTransactionType.WalletTransfer, "")

proc getDefaultCurrency*(self: WalletModel): string =
  # TODO: this should come from a model? It is going to be used too in the
  # profile section and ideally we should not call the settings more than once
  status_settings.getSetting[string](Setting.Currency, "usd")

# TODO: This needs to be removed or refactored so that test tokens are shown
# when on testnet https://github.com/status-im/nim-status-client/issues/613.
proc getStatusToken*(self: WalletModel): string =
  var
    token = Asset()
    erc20Contract = getSntContract()
  token.name = erc20Contract.name
  token.symbol = erc20Contract.symbol
  token.address = $erc20Contract.address
  result = $(%token)

proc setDefaultCurrency*(self: WalletModel, currency: string) =
  discard status_settings.saveSetting(Setting.Currency, currency)
  self.events.emit("currencyChanged", CurrencyArgs(currency: currency))

proc generateAccountConfiguredAssets*(self: WalletModel, accountAddress: string): seq[Asset] =
  var assets: seq[Asset] = @[]
  var asset = Asset(name:"Ethereum", symbol: "ETH", value: "0.0", fiatBalanceDisplay: "0.0", accountAddress: accountAddress)
  assets.add(asset)
  for token in self.tokens:
    var symbol = token.symbol
    var existingToken = Asset(name: token.name, symbol: symbol, value: fmt"0.0", fiatBalanceDisplay: "$0.0", accountAddress: accountAddress, address: $token.address)
    assets.add(existingToken)
  assets

proc populateAccount*(self: WalletModel, walletAccount: var WalletAccount, balance: string,  refreshCache: bool = false) =
  var assets: seq[Asset] = self.generateAccountConfiguredAssets(walletAccount.address)
  walletAccount.balance = none[string]()
  walletAccount.assetList = assets
  walletAccount.realFiatBalance = none[float]()

proc update*(self: WalletModel, address: string, ethBalance: string, tokens: JsonNode) =
  for account in self.accounts:
    if account.address != address: continue
    storeBalances(account, ethBalance, tokens)
    updateBalance(account, self.getDefaultCurrency(), false)

proc getEthBalance*(address: string): string =
  var balance = getBalance(address)
  result = hex2token(balance, 18)

proc newAccount*(self: WalletModel, walletType: string, derivationPath: string, name: string, address: string, iconColor: string, balance: string, publicKey: string): WalletAccount =
  var assets: seq[Asset] = self.generateAccountConfiguredAssets(address)
  var account = WalletAccount(name: name, path: derivationPath, walletType: walletType, address: address, iconColor: iconColor, balance: none[string](), assetList: assets, realFiatBalance: none[float](), publicKey: publicKey)
  updateBalance(account, self.getDefaultCurrency())
  account

proc initAccounts*(self: WalletModel) =
  self.tokens = status_tokens.getVisibleTokens()
  let accounts = status_wallet.getWalletAccounts()
  for account in accounts:
    var acc = WalletAccount(account)
    self.populateAccount(acc, "") 
    updateBalance(acc, self.getDefaultCurrency(), true)
    self.accounts.add(acc)

proc updateAccount*(self: WalletModel, address: string) =
  for acc in self.accounts.mitems:
    if acc.address == address:
      self.populateAccount(acc, "", true)
      updateBalance(acc, self.getDefaultCurrency(), true)
  self.events.emit("accountsUpdated", Args())

proc getTotalFiatBalance*(self: WalletModel): string =
  self.calculateTotalFiatBalance()
  fmt"{self.totalBalance:.2f}"

proc convertValue*(self: WalletModel, balance: string, fromCurrency: string, toCurrency: string): float =
  result = convertValue(balance, fromCurrency, toCurrency)

proc calculateTotalFiatBalance*(self: WalletModel) =
  self.totalBalance = 0.0
  for account in self.accounts:
    if account.realFiatBalance.isSome:
      self.totalBalance += account.realFiatBalance.get()

proc addNewGeneratedAccount(self: WalletModel, generatedAccount: GeneratedAccount, password: string, accountName: string, color: string, accountType: string, isADerivedAccount = true, walletIndex: int = 0): string =
  try:
    generatedAccount.name = accountName
    var derivedAccount: DerivedAccount = status_accounts.saveAccount(generatedAccount, password, color, accountType, isADerivedAccount, walletIndex)
    var account = self.newAccount(accountType, derivedAccount.derivationPath, accountName, derivedAccount.address, color, fmt"0.00 {self.defaultCurrency}", derivedAccount.publicKey)
    self.accounts.add(account)
    self.events.emit("newAccountAdded", AccountArgs(account: account))
  except Exception as e:
    return fmt"Error adding new account: {e.msg}"

  return ""

proc addNewGeneratedAccountWithPassword(self: WalletModel, generatedAccount: GeneratedAccount, password: string, accountName: string, color: string, accountType: string, isADerivedAccount = true, walletIndex: int = 0): string =
  let defaultAccount = status_accounts.getDefaultAccount()
  let isPasswordOk = status_accounts.verifyAccountPassword(defaultAccount, password)

  if (not isPasswordOk):
    return "Wrong password"
  result = self.addNewGeneratedAccount(generatedAccount, password, accountName, color, accountType, isADerivedAccount, walletIndex)

proc generateNewAccount*(self: WalletModel, password: string, accountName: string, color: string): string =
  let walletRootAddress = status_settings.getSetting[string](Setting.WalletRootAddress, "")
  let walletIndex = status_settings.getSetting[int](Setting.LatestDerivedPath) + 1
  let loadedAccount = status_accounts.loadAccount(walletRootAddress, password)
  let derivedAccount = status_accounts.deriveWallet(loadedAccount.id, walletIndex)

  let generatedAccount = GeneratedAccount(
    id: loadedAccount.id,
    publicKey: derivedAccount.publicKey,
    address: derivedAccount.address
  )

  result = self.addNewGeneratedAccountWithPassword(generatedAccount, password, accountName, color, constants.GENERATED, true, walletIndex)
  
  let statusGoResult = status_settings.saveSetting(Setting.LatestDerivedPath, $walletIndex)
  if statusGoResult.error != "":
    error "Error storing the latest wallet index", msg=statusGoResult.error

proc addAccountsFromSeed*(self: WalletModel, seed: string, password: string, accountName: string, color: string): string =
  let mnemonic = replace(seed, ',', ' ')
  var generatedAccount = status_accounts.multiAccountImportMnemonic(mnemonic)
  generatedAccount.derived = status_accounts.deriveAccounts(generatedAccount.id)
  return self.addNewGeneratedAccountWithPassword(generatedAccount, password, accountName, color, constants.SEED)

proc addAccountsFromPrivateKey*(self: WalletModel, privateKey: string, password: string, accountName: string, color: string): string =
  let generatedAccount = status_accounts.MultiAccountImportPrivateKey(privateKey)
  return self.addNewGeneratedAccountWithPassword(generatedAccount, password, accountName, color, constants.KEY, false)

proc addWatchOnlyAccount*(self: WalletModel, address: string, accountName: string, color: string): string =
  let account = GeneratedAccount(address: address)
  return self.addNewGeneratedAccount(account, "", accountName, color, constants.WATCH, false)

proc hasAsset*(self: WalletModel, account: string, symbol: string): bool =
  self.tokens = status_tokens.getVisibleTokens()
  self.tokens.anyIt(it.symbol == symbol)

proc changeAccountSettings*(self: WalletModel, address: string, accountName: string, color: string): string =
  var selectedAccount: WalletAccount
  for account in self.accounts:
    if (account.address == address):
      selectedAccount = account
      break
  if (isNil(selectedAccount)):
    result = "No account found with that address"
    error "No account found with that address", address
  selectedAccount.name = accountName
  selectedAccount.iconColor = color
  result = status_accounts.changeAccount(selectedAccount)

proc deleteAccount*(self: WalletModel, address: string): string =
  result = status_accounts.deleteAccount(address)

proc toggleAsset*(self: WalletModel, symbol: string) =
  status_tokens.toggleAsset(symbol)
  self.tokens = status_tokens.getVisibleTokens()
  for account in self.accounts:
    account.assetList = self.generateAccountConfiguredAssets(account.address)
    updateBalance(account, self.getDefaultCurrency())
  self.events.emit("assetChanged", Args())

proc hideAsset*(self: WalletModel, symbol: string) =
  status_tokens.hideAsset(symbol)
  self.tokens = status_tokens.getVisibleTokens()
  for account in self.accounts:
    account.assetList = self.generateAccountConfiguredAssets(account.address)
    updateBalance(account, self.getDefaultCurrency())
  self.events.emit("assetChanged", Args())

proc addCustomToken*(self: WalletModel, symbol: string, enable: bool, address: string, name: string, decimals: int, color: string) =
  addCustomToken(address, name, symbol, decimals, color)

proc getTransfersByAddress*(self: WalletModel, address: string): seq[Transaction] =
 result = status_wallet.getTransfersByAddress(address)

proc validateMnemonic*(self: WalletModel, mnemonic: string): string =
  result = status_wallet.validateMnemonic(mnemonic).parseJSON()["error"].getStr

proc getGasPricePredictions*(self: WalletModel): GasPricePrediction =
  if status_settings.getCurrentNetwork() != Network.Mainnet:
    # TODO: what about other chains like xdai?
    return GasPricePrediction(safeLow: 1.0, standard: 2.0, fast: 3.0, fastest: 4.0)
  try:
    let url: string = fmt"https://etherchain.org/api/gasPriceOracle"
    let secureSSLContext = newContext()
    let client = newHttpClient(sslContext = secureSSLContext)
    client.headers = newHttpHeaders({ "Content-Type": "application/json" })
    let response = client.request(url)
    result = Json.decode(response.body, GasPricePrediction)
  except Exception as e:
    echo "error getting gas price predictions"
    echo e.msg

proc getGasPricePredictions2*(): GasPricePrediction =
  if status_settings.getCurrentNetwork() != Network.Mainnet:
    # TODO: what about other chains like xdai?
    return GasPricePrediction(safeLow: 1.0, standard: 2.0, fast: 3.0, fastest: 4.0)
  try:
    let url: string = fmt"https://etherchain.org/api/gasPriceOracle"
    let secureSSLContext = newContext()
    let client = newHttpClient(sslContext = secureSSLContext)
    client.headers = newHttpHeaders({ "Content-Type": "application/json" })
    let response = client.request(url)
    result = Json.decode(response.body, GasPricePrediction)
  except Exception as e:
    echo "error getting gas price predictions"
    echo e.msg
