import NimQml, Tables, json, nimcrypto, strformat, json_serialization, strutils
import ../../status/types as status_types
import ../../status/signals/types
import ../../status/accounts as AccountModel
import ../../status/[status, wallet]
import views/account_info

type
  AccountRoles {.pure.} = enum
    Username = UserRole + 1,
    Identicon = UserRole + 2,
    Address = UserRole + 3

QtObject:
  type OnboardingView* = ref object of QAbstractListModel
    accounts*: seq[GeneratedAccount]
    currentAccount*: AccountInfoView
    status*: Status
    isCurrentFlow*: bool
    isFirstTimeLogin*: bool

  proc setup(self: OnboardingView) =
    self.QAbstractListModel.setup

  proc delete*(self: OnboardingView) =
    self.currentAccount.delete
    self.accounts = @[]
    self.QAbstractListModel.delete

  proc newOnboardingView*(status: Status): OnboardingView =
    new(result, delete)
    result.accounts = @[]
    result.currentAccount = newAccountInfoView()
    result.status = status
    result.isCurrentFlow = false
    result.setup

  proc addAccountToList*(self: OnboardingView, account: GeneratedAccount) =
    self.beginInsertRows(newQModelIndex(), self.accounts.len, self.accounts.len)
    self.accounts.add(account)
    self.endInsertRows()
  
  proc removeAccounts*(self: OnboardingView) =
    self.beginResetModel()
    self.accounts = @[]
    self.endResetModel()

  method rowCount(self: OnboardingView, index: QModelIndex = nil): int =
    return self.accounts.len

  method data(self: OnboardingView, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.accounts.len:
      return

    let asset = self.accounts[index.row]
    let assetRole = role.AccountRoles
    case assetRole:
    of AccountRoles.Username: result = newQVariant(asset.name)
    of AccountRoles.Identicon: result = newQVariant(asset.identicon)
    of AccountRoles.Address: result = newQVariant(asset.keyUid)

  method roleNames(self: OnboardingView): Table[int, string] =
    { AccountRoles.Username.int:"username",
    AccountRoles.Identicon.int:"identicon",
    AccountRoles.Address.int:"address" }.toTable

  proc storeAccountAndLogin(self: OnboardingView, selectedAccountIndex: int, password: string): string {.slot.} =
    try:
      result = self.status.accounts.storeAccountAndLogin(self.status.fleet.config, selectedAccountIndex, password).toJson
    except:
      let
        e = getCurrentException()
        msg = getCurrentExceptionMsg()
      result = StatusGoError(error: msg).toJson

  proc getCurrentAccount*(self: OnboardingView): QVariant {.slot.} =
    result = newQVariant(self.currentAccount)

  proc setCurrentAccount*(self: OnboardingView, selectedAccountIdx: int) {.slot.} =
    self.currentAccount.setAccount(self.accounts[selectedAccountIdx])

  QtProperty[QVariant] currentAccount:
    read = getCurrentAccount
    write = setCurrentAccount

  proc importMnemonic(self: OnboardingView, mnemonic: string): string {.slot.} =
    try:
      let importResult = self.status.accounts.importMnemonic(mnemonic.strip())
      result = importResult.toJson
      self.currentAccount.setAccount(importResult)
    except StatusGoException as e:
      result = StatusGoError(error: e.msg).toJson

  proc validateMnemonic*(self: OnboardingView, mnemonic: string): string {.slot.} =
    result = self.status.wallet.validateMnemonic(mnemonic.strip())

  proc loginResponseChanged*(self: OnboardingView, error: string) {.signal.}

  proc setLastLoginResponse*(self: OnboardingView, loginResponse: StatusGoError) =
    self.loginResponseChanged(loginResponse.error)

  proc isCurrentFlow*(self: OnboardingView): bool {.slot.} =
    result = self.isCurrentFlow

  proc currentFlowChanged*(self: OnboardingView, v: bool) {.signal.}

  proc setCurrentFlow*(self: OnboardingView, v: bool) {.slot.} =
    if self.isCurrentFlow == v: return
    self.isCurrentFlow = v
    self.currentFlowChanged(v)

  proc `isCurrentFlow=`*(self: OnboardingView, v: bool) = self.setCurrentFlow(v)

  QtProperty[bool] isCurrentFlow:
    read = isCurrentFlow
    write = setCurrentFlow
    notify = currentFlowChanged

  proc firstTimeLoginChanged*(self: OnboardingView, v: bool) {.signal.}

  proc setFirstTimeLogin*(self: OnboardingView, v: bool) {.slot.} =
    if self.isFirstTimeLogin == v: return
    self.isFirstTimeLogin = v
    self.firstTimeLoginChanged(v)

  proc `isFirstTimeLogin=`*(self: OnboardingView, v: bool) = self.setFirstTimeLogin(v)

  QtProperty[bool] isFirstTimeLogin:
    read = isFirstTimeLogin
    write = setFirstTimeLogin
    notify = firstTimeLoginChanged

  proc storeDerivedAndLogin(self: OnboardingView, password: string): string {.slot.} =
    try:
      result = self.status.accounts.storeDerivedAndLogin(self.status.fleet.config, self.currentAccount.account, password).toJson
      self.setFirstTimeLogin(true)
    except StatusGoException as e:
      var msg = e.msg
      if e.msg.contains("account already exists"):
        msg = "Account already exists. Please try importing another account."
      result = StatusGoError(error: msg).toJson
