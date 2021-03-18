import # nim libs
  tables

import # vendor libs
  chronos, NimQml, json, json_serialization, task_runner

import # status-desktop libs
  ./common, ../libstatus/types, ../stickers

type
  StickerPackPurchaseGasEstimate* = ref object of BaseTask
    packId*: int
    address*: string
    price*: string
    uuid*: string
  ObtainAvailableStickerPacks* = ref object of BaseTask
  StickersTasks* = ref object of BaseTasks

proc newStickersTasks*(chanSendToPool: AsyncChannel[ThreadSafeString]): StickersTasks =
  new(result)
  result.chanSendToPool = chanSendToPool

proc run*(task: StickerPackPurchaseGasEstimate) =
  var success: bool
  var estimate = estimateGas(
    task.packId,
    task.address,
    task.price,
    success
  )
  if not success:
    estimate = 325000
  let result: tuple[estimate: int, uuid: string] = (estimate, task.uuid)
  task.finish(result)

proc run*(task: ObtainAvailableStickerPacks) =
  var success: bool
  let availableStickerPacks = getAvailableStickerPacks()
  var packs: seq[StickerPack] = @[]
  for packId, stickerPack in availableStickerPacks.pairs:
    packs.add(stickerPack)
  task.finish(%*(packs))

proc stickerPackPurchaseGasEstimate*(self: StickersTasks, vptr: pointer, slot: string, packId: int, address: string, price: string, uuid: string) =
  let task = StickerPackPurchaseGasEstimate(vptr: cast[ByteAddress](vptr), slot: slot, packId: packId, address: address, price: price, uuid: uuid)
  self.start(task)

proc obtainAvailableStickerPacks*(self: StickersTasks, vptr: pointer, slot: string) =
  let task = ObtainAvailableStickerPacks(vptr: cast[ByteAddress](vptr), slot: slot)
  self.start(task)