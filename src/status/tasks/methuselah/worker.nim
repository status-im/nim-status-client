import # std libs
  json, tables

import # vendor libs
  chronicles, chronos, json_serialization, task_runner

import # status-desktop libs
  ../common

export
  chronos, common, json_serialization

logScope:
  topics = "task-methuselah-worker"

type
  WorkerThreadArg* = object # of RootObj
    chanSendToMain*: AsyncChannel[ThreadSafeString]
    chanRecvFromMain*: AsyncChannel[ThreadSafeString]
  MethuselahWorker* = ref object of RootObj
    chanSendToMain*: AsyncChannel[ThreadSafeString]
    chanRecvFromMain*: AsyncChannel[ThreadSafeString]
    thread*: Thread[WorkerThreadArg]

# forward declarations
method workerThread(arg: WorkerThreadArg) {.thread, base.}

proc newMethuselahWorker*(): MethuselahWorker =
  new(result)
  result.chanRecvFromMain = newAsyncChannel[ThreadSafeString](-1)
  result.chanSendToMain = newAsyncChannel[ThreadSafeString](-1)


method init*(self: MethuselahWorker) {.base.} =
  # self.chanRecvFromMeth.open()
  # self.chanSendToMeth.open()
  # let arg = WorkerThreadArg(
  #   chanSendToMain: self.chanRecvFromMeth,
  #   chanRecvFromMain: self.chanSendToMeth
  # )
  # createThread(self.thread, mailserverThread, arg)
  # # block until we receive "ready"
  # discard $(self.chanRecvFromMeth.recvSync())

  # override this base method
  raise newException(CatchableError, "Method without implementation override")

method teardown*(self: MethuselahWorker) {.base.} =
  # self.chanSendToMeth.sendSync("shutdown".safe)
  # self.chanRecvFromMeth.close()
  # self.chanSendToMeth.close()
  # debug "[threadpool] waiting for the control thread to stop"
  # joinThread(self.thread)

  # override this base method
  raise newException(CatchableError, "Method without implementation override")

method worker(arg: WorkerThreadArg) {.async, base.} =
  # let
  #   chanSendToMain = arg.chanSendToMain
  #   chanRecvFromMainOrTask = arg.chanRecvFromMain
  # chanSendToMain.open()
  # chanRecvFromMainOrTask.open()

  # debug "[threadpool] sending 'ready' to main thread"
  # await chanSendToMain.send("ready".safe)

  # override this base method
  raise newException(CatchableError, "Method without implementation override")

method workerThread(arg: WorkerThreadArg) {.thread, base.} =
  # waitFor worker(arg)

  # override this base method
  raise newException(CatchableError, "Method without implementation override")