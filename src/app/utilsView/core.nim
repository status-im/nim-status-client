import NimQml, chronicles
import ../../status/signals/types
import ../../status/[status, node, network]
import ../../status/types as status_types
import view
import ../../eventemitter

logScope:
  topics = "utils"

type UtilsController* = ref object
  status*: Status
  view*: UtilsView
  variant*: QVariant

proc newController*(status: Status): UtilsController =
  result = UtilsController()
  result.status = status
  result.view = newUtilsView(status)
  result.variant = newQVariant(result.view)

proc delete*(self: UtilsController) =
  delete self.variant
  delete self.view

proc init*(self: UtilsController) =
  self.view.asyncCheckForUpdates()
