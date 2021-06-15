import # std libs
  atomics, strformat, strutils, sequtils, json, std/wrapnils, parseUtils, tables

import NimQml, json, sequtils, chronicles, strutils, strformat, json
import ../../../status/[status, settings, wallet]
import ../../../status/wallet/collectibles as status_collectibles
import ../../../status/signals/types as signal_types
import ../../../status/types

import # status-desktop libs
  ../../../status/wallet as status_wallet,
  ../../../status/tasks/[qt, task_runner_impl]

import account_list, account_item, transaction_list, accounts

const ZERO_ADDRESS* = "0x0000000000000000000000000000000000000000"

logScope:
  topics = "transactions-view"

type
  SendTransactionTaskArg = ref object of QObjectTaskArg
    from_addr: string
    to: string
    assetAddress: string
    value: string
    gas: string
    gasPrice: string
    password: string
    uuid: string
  LoadTransactionsTaskArg = ref object of QObjectTaskArg
    address: string
    blockNumber: string
  WatchTransactionTaskArg = ref object of QObjectTaskArg
    transactionHash: string

const sendTransactionTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[SendTransactionTaskArg](argEncoded)
  var
    success: bool
    response: string
  if arg.assetAddress != ZERO_ADDRESS and not arg.assetAddress.isEmptyOrWhitespace:
    response = wallet.sendTokenTransaction(arg.from_addr, arg.to, arg.assetAddress, arg.value, arg.gas, arg.gasPrice, arg.password, success)
  else:
    response = wallet.sendTransaction(arg.from_addr, arg.to, arg.value, arg.gas, arg.gasPrice, arg.password, success)
  let output = %* { "result": %response, "success": %success, "uuid": %arg.uuid }
  arg.finish(output)

proc sendTransaction[T](self: T, slot: string, from_addr: string, to: string, assetAddress: string, value: string, gas: string, gasPrice: string, password: string, uuid: string) =
  let arg = SendTransactionTaskArg(
    tptr: cast[ByteAddress](sendTransactionTask),
    vptr: cast[ByteAddress](self.vptr),
    slot: slot,
    from_addr: from_addr,
    to: to,
    assetAddress: assetAddress,
    value: value,
    gas: gas,
    gasPrice: gasPrice,
    password: password,
    uuid: uuid
  )
  self.status.tasks.threadpool.start(arg)

const loadTransactionsTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let
    arg = decode[LoadTransactionsTaskArg](argEncoded)
    output = %*{
      "address": arg.address,
      "history": status_wallet.getTransfersByAddress(arg.address)
    }
  arg.finish(output)

proc loadTransactions*[T](self: T, slot: string, address: string) =
  let arg = LoadTransactionsTaskArg(
    tptr: cast[ByteAddress](loadTransactionsTask),
    vptr: cast[ByteAddress](self.vptr),
    slot: slot,
    address: address
  )
  self.status.tasks.threadpool.start(arg)

const watchTransactionTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let
    arg = decode[WatchTransactionTaskArg](argEncoded)
    response = status_wallet.watchTransaction(arg.transactionHash)
    output = %* { "result": response }
  arg.finish(output)

proc watchTransaction[T](self: T, slot: string, transactionHash: string) =
  let arg = WatchTransactionTaskArg(
    tptr: cast[ByteAddress](watchTransactionTask),
    vptr: cast[ByteAddress](self.vptr),
    slot: slot,
    transactionHash: transactionHash
  )
  self.status.tasks.threadpool.start(arg)

QtObject:
  type TransactionsView* = ref object of QObject
      status: Status
      accountsView*: AccountsView
      transactionsView*: TransactionsView
      currentTransactions*: TransactionList

  proc setup(self: TransactionsView) =
    self.QObject.setup

  proc delete(self: TransactionsView) =
    self.currentTransactions.delete
    # self.currentCollectiblesLists.delete

  proc newTransactionsView*(status: Status, accountsView: AccountsView): TransactionsView =
    new(result, delete)
    result.status = status
    # result.currentCollectiblesLists = newCollectiblesList()
    result.accountsView = accountsView # TODO: not ideal but a solution for now
    result.currentTransactions = newTransactionList()
    result.setup

  proc currentTransactionsChanged*(self: TransactionsView) {.signal.}

  proc getCurrentTransactions*(self: TransactionsView): QVariant {.slot.} =
    return newQVariant(self.currentTransactions)

  proc setCurrentTransactions*(self: TransactionsView, transactionList: seq[Transaction]) =
    self.currentTransactions.setNewData(transactionList)
    self.currentTransactionsChanged()

  QtProperty[QVariant] transactions:
    read = getCurrentTransactions
    write = setCurrentTransactions
    notify = currentTransactionsChanged

  proc transactionWasSent*(self: TransactionsView, txResult: string) {.signal.}

  proc transactionSent(self: TransactionsView, txResult: string) {.slot.} =
    self.transactionWasSent(txResult)
    let jTxRes = txResult.parseJSON()
    let txHash = jTxRes{"result"}.getStr()
    if txHash != "":
      self.watchTransaction("transactionWatchResultReceived", txHash)

  proc sendTransaction*(self: TransactionsView, from_addr: string, to: string, assetAddress: string, value: string, gas: string, gasPrice: string, password: string, uuid: string) {.slot.} =
    self.sendTransaction("transactionSent", from_addr, to, assetAddress, value, gas, gasPrice, password, uuid)

  proc checkRecentHistory*(self: TransactionsView) {.slot.} =
    var addresses:seq[string] = @[]
    for acc in self.status.wallet.accounts:
      addresses.add(acc.address)
    discard self.status.wallet.checkRecentHistory(addresses)

  proc transactionWatchResultReceived(self: TransactionsView, watchResult: string) {.slot.} =
    let wTxRes = watchResult.parseJSON()["result"].getStr().parseJson(){"result"}
    if wTxRes.kind == JNull:
      self.checkRecentHistory()
    else:
      discard #TODO: Ask Simon if should we show an error popup indicating the trx wasn't mined in 10m or something

  proc transactionCompleted*(self: TransactionsView, success: bool, txHash: string, revertReason: string = "") {.signal.}
