import NimQml
import Tables
import ../../../status/status

type
  DappsRoles {.pure.} = enum
    Name = UserRole + 1,

QtObject:
  type DappList* = ref object of QAbstractListModel
    status: Status
    dapps: seq[string]

  proc setup(self: DappList) = self.QAbstractListModel.setup

  proc delete(self: DappList) =
    self.dapps = @[]
    self.QAbstractListModel.delete

  proc newDappList*(status: Status): DappList =
    new(result, delete)
    result.status = status
    result.dapps = @[]
    result.setup

  proc init*(self: DappList) {.slot.} =
    self.beginResetModel()
    self.dapps = self.status.permissions.getDapps()
    self.endResetModel()

  method rowCount(self: DappList, index: QModelIndex = nil): int =
    return self.dapps.len

  method data(self: DappList, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.dapps.len:
      return
    result = newQVariant(self.dapps[index.row])

  method roleNames(self: DappList): Table[int, string] =
    {
      DappsRoles.Name.int:"name",
    }.toTable

  proc clearData(self: DappList) {.slot.} =
    self.beginResetModel()
    self.dapps = @[]
    self.endResetModel()

  proc revokeAllPermissions(self: DappList) {.slot.} =
    self.status.permissions.clearPermissions()
    self.clearData()
