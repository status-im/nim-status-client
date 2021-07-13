import NimQml, chronicles, std/wrapnils
import ../../status/types as status_types
import ../../status/accounts as AccountModel
import ../../status/status
import ../../status/signals/types
import ../../eventemitter
import view

type OnboardingController* = ref object
  view*: OnboardingView
  variant*: QVariant
  status: Status

proc newController*(status: Status): OnboardingController =
  result = OnboardingController()
  result.status = status
  result.view = newOnboardingView(status)
  result.variant = newQVariant(result.view)

proc delete*(self: OnboardingController) =
  delete self.variant
  delete self.view

proc reset*(self: OnboardingController) =
  self.view.removeAccounts()

proc handleNodeLogin(self: OnboardingController, response: NodeSignal) =
  if not self.view.isCurrentFlow: return
  if self.view.currentAccount.account != nil:
    self.view.setLastLoginResponse(response.event)
    if ?.response.event.error == "":
      self.status.events.emit("login", AccountArgs(account: self.view.currentAccount.account.toAccount))

proc init*(self: OnboardingController) =
  let accounts = self.status.accounts.generateAddresses()
  for account in accounts:
    self.view.addAccountToList(account)

  self.status.events.on(SignalType.NodeLogin.event) do(e:Args):
    self.handleNodeLogin(NodeSignal(e))
  
proc onFirstTimeLogin*(self: OnboardingController) =
  info "First time login"
  debug "Setting default sync period to 7 days"
  self.status.saveSetting(Setting.DefaultSyncPeriod, 604800) # 1 week in seconds
  self.view.setFirstTimeLogin(false)
