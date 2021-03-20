import libstatus/accounts as libstatus_accounts
import libstatus/core as libstatus_core
import libstatus/settings as libstatus_settings
import libstatus/types as libstatus_types
import chat, accounts, wallet, node, network, mailservers, messages, contacts, profile, stickers, permissions, fleet
import ../eventemitter
import ./tasks/task_runner_impl

export chat, accounts, node, mailservers, messages, contacts, profile, network, permissions, fleet, task_runner_impl

type Status* = ref object
  events*: EventEmitter
  fleet*: FleetModel
  chat*: ChatModel
  messages*: MessagesModel
  mailservers*: MailserverModel
  accounts*: AccountModel
  wallet*: WalletModel
  node*: NodeModel
  profile*: ProfileModel
  contacts*: ContactModel
  network*: NetworkModel
  stickers*: StickersModel
  permissions*: PermissionsModel
  tasks*: TaskRunner

proc newStatusInstance*(fleetConfig: string): Status =
  result = Status()
  result.tasks = newTaskRunner()
  result.events = createEventEmitter()
  result.fleet = fleet.newFleetModel(result.events, fleetConfig)
  result.chat = chat.newChatModel(result.events)
  result.accounts = accounts.newAccountModel(result.events)
  result.wallet = wallet.newWalletModel(result.events)
  result.wallet.initEvents()
  result.node = node.newNodeModel()
  result.mailservers = mailservers.newMailserverModel(result.fleet, result.events)
  result.messages = messages.newMessagesModel(result.events)
  result.profile = profile.newProfileModel()
  result.contacts = contacts.newContactModel(result.events)
  result.network = network.newNetworkModel(result.events)
  result.stickers = stickers.newStickersModel(result.events)
  result.permissions = permissions.newPermissionsModel(result.events)

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

proc saveSetting*(self: Status, setting: Setting, value: string) =
  discard libstatus_settings.saveSetting(setting, value)
