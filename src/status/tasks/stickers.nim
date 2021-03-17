import
  chronos, NimQml, json_serialization, task_runner

import
  ../stickers

type
  StickerPackPurchaseGasEstimate* = object
    vptr*: ByteAddress
    slot*: string
    packId*: int
    address*: string
    price*: string
    uuid*: string
  StickersTasks* = ref object
    chanSendToPool: AsyncChannel[ThreadSafeString]

proc newStickersTasks*(chanSendToPool: AsyncChannel[ThreadSafeString]): StickersTasks =
  new(result)
  result.chanSendToPool = chanSendToPool

proc runTask*(stickerPackPurchaseGasEstimate: StickerPackPurchaseGasEstimate) =
  var success: bool
  var estimate = estimateGas2(
    stickerPackPurchaseGasEstimate.packId,
    stickerPackPurchaseGasEstimate.address,
    stickerPackPurchaseGasEstimate.price,
    success
  )
  if not success:
    estimate = 325000
  let result: tuple[estimate: int, uuid: string] = (estimate, stickerPackPurchaseGasEstimate.uuid)
  let resultPayload = Json.encode(result)

  signal_handler(cast[pointer](stickerPackPurchaseGasEstimate.vptr), resultPayload, stickerPackPurchaseGasEstimate.slot)

proc stickerPackPurchaseGasEstimate*(self: StickersTasks, vptr: pointer, slot: string, packId: int, address: string, price: string, uuid: string) =
  let task = StickerPackPurchaseGasEstimate(vptr: cast[ByteAddress](vptr), slot: slot, packId: packId, address: address, price: price, uuid: uuid)
  let payload = task.toJson(typeAnnotations = true)
  self.chanSendToPool.sendSync(payload.safe)