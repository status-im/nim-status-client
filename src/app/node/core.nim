import NimQml, chronicles
import ../../status/signals/types
import ../../status/[status, node, network]
import ../../status/libstatus/types as status_types
import ../../eventemitter
import view

logScope:
  topics = "node"

type NodeController* = ref object
  status*: Status
  view*: NodeView
  variant*: QVariant

proc newController*(status: Status): NodeController =
  result = NodeController()
  result.status = status
  result.view = newNodeView(status)
  result.variant = newQVariant(result.view)

proc delete*(self: NodeController) =
  delete self.variant
  delete self.view

proc init*(self: NodeController) =
  self.status.events.on(SignalType.Wallet.event) do(e:Args):
    self.view.setLastMessage($WalletSignal(e).blockNumber)

  self.status.events.on(SignalType.DiscoverySummary.event) do(e:Args):
    self.status.network.peerSummaryChange(DiscoverySummarySignal(e).enodes)
