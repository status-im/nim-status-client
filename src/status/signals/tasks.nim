import
  chronicles, chronos, json, json_serialization, NimQml, ../stickers, task_runner

logScope:
  topics = "tasks-signals"

type
  TaskManager* = ref object
    chanSend: AsyncChannel[ThreadSafeString]
    thread: Thread[ThreadArg]
  ThreadArg* = object
    chanRecv*: AsyncChannel[ThreadSafeString]
  Task = object of RootObj
    vptr: ByteAddress
    slot: string
  StickerPackPurchaseGasEstimate = object of Task
    packId: int
    address: string
    price: string
    uuid: string

proc newTaskManager*(chanSend: AsyncChannel[ThreadSafeString], thread: var Thread[ThreadArg]): TaskManager =
  new(result)
  result.chanSend = chanSend
  result.thread = thread

proc setup(self: TaskManager) =
  self.chanSend.open()

proc delete*(self: TaskManager) =
  self.chanSend.close()
  joinThread(self.thread)

proc worker(arg: ThreadArg) {.async.} =
  let chanRecv = arg.chanRecv
  var count = 0
  chanRecv.open()

  proc runTask(stickerPackPurchaseGasEstimate: StickerPackPurchaseGasEstimate) =
    var success: bool
    var estimate = estimateGas2(
      stickerPackPurchaseGasEstimate.packId,
      stickerPackPurchaseGasEstimate.address,
      stickerPackPurchaseGasEstimate.price,
      success
    )
    if not success:
      estimate = 325000
    debugEcho ">>> [TaskManager.runTask] estimate: ", $estimate
    let result: tuple[estimate: int, uuid: string] = (estimate, stickerPackPurchaseGasEstimate.uuid)
    let resultPayload = Json.encode(result)
    debugEcho ">>> [TaskManager.runTask] result payload: ", resultPayload
    debugEcho ">>> [TaskManager.runTask] stickerPackPurchaseGasEstimate.vptr: ", repr cast[pointer](stickerPackPurchaseGasEstimate.vptr)

    signal_handler(cast[pointer](stickerPackPurchaseGasEstimate.vptr), resultPayload, stickerPackPurchaseGasEstimate.slot)

  while true:
    let received = $(await chanRecv.recv())
    debugEcho ">>> [TaskManager.worker] received message: ", received
    try:
      let
        jsonNode = parseJson(received)
        messageType = jsonNode{"$type"}.getStr

      debugEcho ">>> [TaskManager.worker] message type: ", messageType
      case messageType
        of "StickerPackPurchaseGasEstimate":
          debugEcho ">>> [TaskManager.worker] we have a StickerPackPurchaseGasEstimate"
          let decoded = Json.decode(received, StickerPackPurchaseGasEstimate, allowUnknownFields = true)
          debugEcho ">>> [TaskManager.worker] decoded: ", decoded, ", running task..."
          decoded.runTask()
          debugEcho ">>> [TaskManager.worker] after run task"
    except Exception as e:
      error "Error parsing message", message=received, error=e.msg

    count = count + 1

proc workerThread*(arg: ThreadArg) {.thread.} =
  waitFor worker(arg)

proc stickerPackPurchaseGasEstimate*(self: TaskManager, vptr: pointer, slot: string, packId: int, address: string, price: string, uuid: string) =
  debugEcho ">>> [signals/tasks.stickerPackPurchaseGasEstimate] unsafeAddr(vptr): ", repr unsafeAddr(vptr)
  debugEcho ">>> [signals/tasks.stickerPackPurchaseGasEstimate] cast[ByteAddress](vptr): ", repr cast[ByteAddress](vptr)
  let task = StickerPackPurchaseGasEstimate(vptr: cast[ByteAddress](vptr), slot: slot, packId: packId, address: address, price: price, uuid: uuid)
  let payload = task.toJson(typeAnnotations = true)
  debugEcho ">>> [signals/tasks.stickerPackPurchaseGasEstimate] encoded payload: ", payload
  self.chanSend.sendSync(payload.safe)
