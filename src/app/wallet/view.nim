import atomics, strformat, strutils, sequtils, json, std/wrapnils, parseUtils, tables
import NimQml, chronicles, stint

import
  ../../status/[status, wallet],
  views/[accounts, collectibles, transactions, tokens, gas, ens, dapp_browser, history, balance, utils, asset_list, account_list]

QtObject:
  type
    WalletView* = ref object of QAbstractListModel
      status: Status
      accountsView: AccountsView
      collectiblesView: CollectiblesView
      transactionsView*: TransactionsView
      tokensView*: TokensView
      dappBrowserView*: DappBrowserView
      gasView*: GasView
      ensView*: EnsView
      historyView*: HistoryView
      balanceView*: BalanceView
      utilsView*: UtilsView
      isNonArchivalNode: bool

  proc delete(self: WalletView) =
    self.accountsView.delete
    self.gasView.delete
    self.ensView.delete
    self.utilsView.delete
    self.QAbstractListModel.delete

  proc setup(self: WalletView) =
    self.QAbstractListModel.setup

  proc newWalletView*(status: Status): WalletView =
    new(result, delete)
    result.status = status

    result.accountsView = newAccountsView(status)
    result.collectiblesView = newCollectiblesView(status, result.accountsView)
    result.transactionsView = newTransactionsView(status, result.accountsView)
    result.tokensView = newTokensView(status, result.accountsView)
    result.gasView = newGasView(status)
    result.ensView = newEnsView(status)
    result.dappBrowserView = newDappBrowserView(status, result.accountsView)
    result.historyView = newHistoryView(status, result.accountsView, result.transactionsView)
    result.balanceView = newBalanceView(status, result.accountsView, result.transactionsView, result.historyView)
    result.utilsView = newUtilsView()
    result.isNonArchivalNode = false

    result.setup

  proc getAccounts(self: WalletView): QVariant {.slot.} = newQVariant(self.accountsView)
  QtProperty[QVariant] accountsView:
    read = getAccounts

  proc getCollectibles(self: WalletView): QVariant {.slot.} = newQVariant(self.collectiblesView)
  QtProperty[QVariant] collectiblesView:
    read = getCollectibles

  proc getTransactions(self: WalletView): QVariant {.slot.} = newQVariant(self.transactionsView)
  QtProperty[QVariant] transactionsView:
    read = getTransactions

  proc getGas(self: WalletView): QVariant {.slot.} = newQVariant(self.gasView)
  QtProperty[QVariant] gasView:
    read = getGas

  proc getTokens(self: WalletView): QVariant {.slot.} = newQVariant(self.tokensView)
  QtProperty[QVariant] tokensView:
    read = getTokens

  proc getEns(self: WalletView): QVariant {.slot.} = newQVariant(self.ensView)
  QtProperty[QVariant] ensView:
    read = getEns

  proc getHistory(self: WalletView): QVariant {.slot.} = newQVariant(self.historyView)
  QtProperty[QVariant] historyView:
    read = getHistory

  proc getBalance(self: WalletView): QVariant {.slot.} = newQVariant(self.balanceView)
  QtProperty[QVariant] balanceView:
    read = getBalance

  proc getUtils(self: WalletView): QVariant {.slot.} = newQVariant(self.utilsView)
  QtProperty[QVariant] utilsView:
    read = getUtils

  proc getDappBrowserView(self: WalletView): QVariant {.slot.} = newQVariant(self.dappBrowserView)
  QtProperty[QVariant] dappBrowserView:
    read = getDappBrowserView

  proc updateView*(self: WalletView) =
    self.transactionsView.triggerEIP1559Check()

    self.balanceView.setTotalFiatBalance(self.status.wallet.getTotalFiatBalance())
    self.balanceView.totalFiatBalanceChanged()

    self.accountsView.currentAccount.assetList.setNewData(self.accountsView.currentAccount.account.assetList)
    self.accountsView.triggerUpdateAccounts()

    self.tokensView.setCurrentAssetList(self.accountsView.currentAccount.account.assetList)

  proc getAccountBalanceSuccess*(self: WalletView, jsonResponse: string) {.slot.} =
    self.balanceView.getAccountBalanceSuccess(jsonResponse)
    self.updateView()

  proc getDefaultAddress*(self: WalletView): string {.slot.} =
    result = $self.status.wallet.getWalletAccounts()[0].address

  proc setInitialRange*(self: WalletView) {.slot.} = 
    discard self.status.wallet.setInitialBlocksRange()

  proc setCurrentAccountByIndex*(self: WalletView, index: int) {.slot.} =
    if self.accountsView.setCurrentAccountByIndex(index):
      let selectedAccount = self.accountsView.accounts.getAccount(index)

      self.tokensView.setCurrentAssetList(selectedAccount.assetList)

      self.collectiblesView.setCurrentCollectiblesLists(selectedAccount.collectiblesLists)
      self.collectiblesView.loadCollectiblesForAccount(selectedAccount.address, selectedAccount.collectiblesLists)

      self.transactionsView.setCurrentTransactions(selectedAccount.transactions.data)

  proc addAccountToList*(self: WalletView, account: WalletAccount) =
    self.accountsView.addAccountToList(account)
    # If it's the first account we ever get, use its list as our first lists
    if (self.accountsView.accounts.rowCount == 1):
      self.tokensView.setCurrentAssetList(account.assetList)
      discard self.accountsView.setCurrentAccountByIndex(0)

  proc transactionCompleted*(self: WalletView, success: bool, txHash: string, revertReason: string = "") {.signal.}

  proc setDappBrowserAddress*(self: WalletView) {.slot.} =
    self.dappBrowserView.setDappBrowserAddress()

  proc setHistoryFetchState*(self: WalletView, accounts: seq[string], isFetching: bool) =
    self.historyView.setHistoryFetchState(accounts, isFetching)

  proc initBalances*(self: WalletView, loadTransactions: bool = true) =
    self.balanceView.initBalances(loadTransactions)

  proc setSigningPhrase*(self: WalletView, signingPhrase: string) =
    self.utilsView.setSigningPhrase(signingPhrase)

  proc setEtherscanLink*(self: WalletView, link: string) =
    self.utilsView.setEtherscanLink(link)

  proc checkRecentHistory*(self: WalletView) =
    self.transactionsView.checkRecentHistory()

  proc initBalances*(self: WalletView, accounts: seq[string], loadTransactions: bool = true) =
    for acc in accounts:
      self.balanceView.initBalance(acc, loadTransactions)

  proc isNonArchivalNodeChanged*(self: WalletView) {.signal.}

  proc setNonArchivalNode*(self: WalletView, isNonArchivalNode: bool = true) {.slot.} =
    self.isNonArchivalNode = isNonArchivalNode
    self.isNonArchivalNodeChanged()

  proc isNonArchivalNode*(self: WalletView): bool {.slot.} = result = ?.self.isNonArchivalNode
  QtProperty[bool] isNonArchivalNode:
    read = isNonArchivalNode
    write = setNonArchivalNode
    notify = isNonArchivalNodeChanged
