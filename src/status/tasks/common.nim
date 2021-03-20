import # vendor libs
  json_serialization, NimQml, task_runner

type
  BaseTasks* = ref object of RootObj
    chanSendToPool*: AsyncChannel[ThreadSafeString]
  BaseTask* = ref object of RootObj
    vptr*: ByteAddress
    slot*: string
  TaskArg* = ref object of RootObj
    tptr*: ByteAddress
  Task* = proc(arg: string): void {.gcsafe, nimcall.}

proc start*[T: BaseTask](self: BaseTasks, task: T) =
  let payload = task.toJson(typeAnnotations = true)
  self.chanSendToPool.sendSync(payload.safe)

proc finish*[T](task: BaseTask, payload: T) =
  let resultPayload = Json.encode(payload)
  signal_handler(cast[pointer](task.vptr), resultPayload, task.slot)

proc taskArgDecoder*[T](arg: string): T =
  Json.decode(arg, T, allowUnknownFields = true)

proc taskArgEncoder*[T](arg: T): string =
  arg.toJson(typeAnnotations = true)
