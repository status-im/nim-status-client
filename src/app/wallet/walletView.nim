import NimQml
import Tables
import ../../models/wallet

type
  AssetRoles {.pure.} = enum
    Name = UserRole + 1,
    Symbol = UserRole + 2,
    Value = UserRole + 3,
    FiatValue = UserRole + 4,
    Image = UserRole + 5

QtObject:
  type
    WalletView* = ref object of QAbstractListModel
      assets*: seq[Asset]
      defaultAccount: string
      model: WalletModel

  proc delete(self: WalletView) =
    self.QAbstractListModel.delete
    self.assets = @[]

  proc setup(self: WalletView) =
    self.QAbstractListModel.setup

  proc newWalletView*(model: WalletModel): WalletView =
    new(result, delete)
    result.model = model
    result.assets = @[]
    result.setup

  proc addAssetToList*(self: WalletView, asset: Asset) =
    self.beginInsertRows(newQModelIndex(), self.assets.len, self.assets.len)
    self.assets.add(asset)
    self.endInsertRows()

  proc setDefaultAccount*(self: WalletView, account: string) =
    self.defaultAccount = account

  proc getDefaultAccount*(self: WalletView): string {.slot.} =
    return self.defaultAccount

  method rowCount(self: WalletView, index: QModelIndex = nil): int =
    return self.assets.len

  method data(self: WalletView, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.assets.len:
      return

    let asset = self.assets[index.row]
    let assetRole = role.AssetRoles
    case assetRole:
    of AssetRoles.Name: result = newQVariant(asset.name)
    of AssetRoles.Symbol: result = newQVariant(asset.symbol)
    of AssetRoles.Value: result = newQVariant(asset.value)
    of AssetRoles.FiatValue: result = newQVariant(asset.fiatValue)
    of AssetRoles.Image: result = newQVariant(asset.image)

  proc onSendTransaction*(self: WalletView, from_value: string, to: string, value: string, password: string): string {.slot.} =
    result = self.model.sendTransaction(from_value, to, value, password)

  method roleNames(self: WalletView): Table[int, string] =
    { AssetRoles.Name.int:"name",
    AssetRoles.Symbol.int:"symbol",
    AssetRoles.Value.int:"value",
    AssetRoles.FiatValue.int:"fiatValue",
    AssetRoles.Image.int:"image" }.toTable
