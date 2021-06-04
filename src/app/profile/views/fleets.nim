import NimQml
import chronicles, strutils
import ../../../status/libstatus/types as status_types
import ../../../status/libstatus/settings as status_settings
import ../../../status/libstatus/accounts as status_accounts
import ../../../status/status

QtObject:
  type Fleets * = ref object of QObject
    status: Status

  proc setup(self: Fleets) =
    self.QObject.setup

  proc delete*(self: Fleets) =
    self.QObject.delete

  proc newFleets*(status: Status): Fleets =
    new(result, delete)
    result = Fleets()
    result.status = status
    result.setup

  proc fleetChanged*(self: Fleets, newFleet: string) {.signal.}

  proc triggerFleetChange*(self: Fleets) {.slot.} =
    self.fleetChanged($status_settings.getFleet())

  proc setFleet*(self: Fleets, newFleet: string) {.slot.} =
    discard status_settings.saveSetting(Setting.Fleet, newFleet)
    let fleet = parseEnum[Fleet](newFleet)
    let installationId = status_settings.getSetting[string](Setting.InstallationId)
    let updatedNodeConfig = status_accounts.getNodeConfig(self.status.fleet.config, installationId, $status_settings.getCurrentNetwork(), fleet)
    discard status_settings.saveSetting(Setting.NodeConfig, updatedNodeConfig)
    let isWakuV2 = if fleet == WakuV2Prod or fleet == WakuV2Test: true else: false
    # Updating waku version because it makes no sense for some fleets to run under wakuv1 or v2 config
    if isWakuV2:
      status_settings.setWakuVersion(2)
    else:
      status_settings.setWakuVersion(1)
    
    self.fleetChanged(newFleet)
    quit(QuitSuccess) # quits the app TODO: change this to logout instead when supported

  proc getFleet*(self: Fleets): string {.slot.} = $status_settings.getFleet()

  QtProperty[string] fleet:
    read = getFleet
    notify = fleetChanged
