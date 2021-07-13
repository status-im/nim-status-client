import libstatus/accounts as libstatus_accounts
import libstatus/core as libstatus_core
import libstatus/settings as libstatus_settings
import types as libstatus_types
import chat, accounts, wallet, node, network, messages, contacts, profile, stickers, permissions, fleet, settings, mailservers, browser, tokens, provider
import ../eventemitter
import ./tasks/task_runner_impl

export chat, accounts, node, messages, contacts, profile, network, permissions, fleet, task_runner_impl, eventemitter

type Status* = ref object
  events*: EventEmitter
  fleet*: FleetModel
  chat*: ChatModel
  messages*: MessagesModel
  accounts*: AccountModel
  wallet*: WalletModel
  node*: NodeModel
  profile*: ProfileModel
  contacts*: ContactModel
  network*: NetworkModel
  stickers*: StickersModel
  permissions*: PermissionsModel
  tasks*: TaskRunner
  settings*: SettingsModel
  mailservers*: MailserversModel
  browser*: BrowserModel
  tokens*: TokensModel
  provider*: ProviderModel

proc newStatusInstance*(fleetConfig: string): Status =
  result = Status()
  result.tasks = newTaskRunner()
  result.events = createEventEmitter()
  result.fleet = fleet.newFleetModel(fleetConfig)
  result.chat = chat.newChatModel(result.events)
  result.accounts = accounts.newAccountModel(result.events)
  result.wallet = wallet.newWalletModel(result.events)
  result.wallet.initEvents()
  result.node = node.newNodeModel()
  result.messages = messages.newMessagesModel(result.events)
  result.profile = profile.newProfileModel()
  result.contacts = contacts.newContactModel(result.events)
  result.network = network.newNetworkModel(result.events)
  result.stickers = stickers.newStickersModel(result.events)
  result.permissions = permissions.newPermissionsModel(result.events)
  result.settings = settings.newSettingsModel(result.events)
  result.mailservers = mailservers.newMailserversModel(result.events)
  result.browser = browser.newBrowserModel(result.events)
  result.tokens = tokens.newTokensModel(result.events)
  result.provider = provider.newProviderModel(result.events, result.permissions)

proc initNode*(self: Status) =
  self.tasks.init()
  libstatus_accounts.initNode()

proc startMessenger*(self: Status) =
  libstatus_core.startMessenger()

proc reset*(self: Status) =
  # TODO: remove this once accounts are not tracked in the AccountsModel
  self.accounts.reset()

  # NOT NEEDED self.chat.reset()
  # NOT NEEDED self.wallet.reset()
  # NOT NEEDED self.node.reset()
  # NOT NEEDED self.mailservers.reset()
  # NOT NEEDED self.profile.reset()

  # TODO: add all resets here

proc getNodeVersion*(self: Status): string =
  libstatus_settings.getWeb3ClientVersion()

proc saveSetting*(self: Status, setting: Setting, value: string | bool | int) =
  discard libstatus_settings.saveSetting(setting, value)
