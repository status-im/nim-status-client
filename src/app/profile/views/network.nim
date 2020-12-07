import NimQml, chronicles
import ../../../status/status

logScope:
  topics = "network-view"

QtObject:
  type NetworkView* = ref object of QObject
    status: Status
    network: string

  proc setup(self: NetworkView) =
    self.QObject.setup

  proc delete*(self: NetworkView) =
    self.QObject.delete

  proc newNetworkView*(status: Status): NetworkView =
    new(result, delete)
    result.status = status
    result.setup

  proc networkChanged*(self: NetworkView) {.signal.}

  proc triggerNetworkChange*(self: NetworkView) {.slot.} =
    self.networkChanged()

  proc getNetwork*(self: NetworkView): QVariant {.slot.} =
    return newQVariant(self.network)

  proc setNetwork*(self: NetworkView, network: string) =
    self.network = network
    self.networkChanged()
  
  proc setNetworkAndPersist*(self: NetworkView, network: string) {.slot.} =
    self.network = network
    self.networkChanged()
    self.status.accounts.changeNetwork(self.status.fleet.config, network)
    quit(QuitSuccess) # quits the app TODO: change this to logout instead when supported

  QtProperty[QVariant] current:
    read = getNetwork
    write = setNetworkAndPersist
    notify = networkChanged


