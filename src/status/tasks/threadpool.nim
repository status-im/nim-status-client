import
  chronicles, chronos, json, json_serialization, NimQml, sequtils, tables,
  task_runner

import
  ./common, ./stickers
export
  stickers

logScope:
  topics = "task-threadpool"

type
  ThreadPool* = ref object
    chanRecvFromPool*: AsyncChannel[ThreadSafeString]
    chanSendToPool*: AsyncChannel[ThreadSafeString]
    thread: Thread[PoolThreadArg]
    size: int
    stickers*: StickersTasks
  PoolThreadArg* = object
    chanSendToMain*: AsyncChannel[ThreadSafeString]
    chanRecvFromMain*: AsyncChannel[ThreadSafeString]
    size*: int
  TaskThreadArg = object
    id: int
    chanRecvFromPool: AsyncChannel[ThreadSafeString]
    chanSendToPool: AsyncChannel[ThreadSafeString]
  ThreadNotification = object
    id: int
    notice: string
  

# forward declarations
proc poolThread(arg: PoolThreadArg) {.thread.}

const MaxThreadPoolSize = 16

proc newThreadPool*(size: int = MaxThreadPoolSize): ThreadPool =
  new(result)
  result.chanRecvFromPool = newAsyncChannel[ThreadSafeString](-1)
  result.chanSendToPool = newAsyncChannel[ThreadSafeString](-1)
  result.thread = Thread[PoolThreadArg]()
  result.size = size
  result.stickers = newStickersTasks(result.chanSendToPool)

proc init*(self: ThreadPool) =
  self.chanRecvFromPool.open()
  self.chanSendToPool.open()
  let arg = PoolThreadArg(
    chanSendToMain: self.chanRecvFromPool,
    chanRecvFromMain: self.chanSendToPool,
    size: self.size
  )
  createThread(self.thread, poolThread, arg)

  # block until we receive "ready"
  let received = $(self.chanRecvFromPool.recvSync())

proc teardown*(self: ThreadPool) =
  self.chanSendToPool.sendSync("shutdown".safe)
  self.chanRecvFromPool.close()
  self.chanSendToPool.close()
  joinThread(self.thread)

proc task(arg: TaskThreadArg) {.async.} =
  arg.chanRecvFromPool.open()
  arg.chanSendToPool.open()

  let noticeToPool = ThreadNotification(id: arg.id, notice: "ready")
  info "[threadpool task thread] sending 'ready'", threadid=arg.id
  await arg.chanSendToPool.send(noticeToPool.toJson(typeAnnotations = true).safe)

  while true:
    info "[threadpool task thread] waiting for message"
    let received = $(await arg.chanRecvFromPool.recv())

    if received == "shutdown":
      info "[threadpool task thread] received 'shutdown'"
      info "[threadpool task thread] breaking while loop"
      break

    let
      jsonNode = parseJson(received)
      messageType = jsonNode{"$type"}.getStr

    info "[threadpool task thread] received task", messageType=messageType
    info "[threadpool task thread] initiating task", messageType=messageType,
      threadid=arg.id

    try:
      case messageType
        of "StickerPackPurchaseGasEstimate:ObjectType":
          let decoded = Json.decode(received, StickerPackPurchaseGasEstimate, allowUnknownFields = true)
          decoded.run()
        of "ObtainAvailableStickerPacks:ObjectType":
          let decoded = Json.decode(received, ObtainAvailableStickerPacks, allowUnknownFields = true)
          decoded.run()
        else:
          error "[threadpool task thread] unknown message", message=received
    except Exception as e:
      error "[threadpool task thread] exception", error=e.msg

    let noticeToPool = ThreadNotification(id: arg.id, notice: "done")
    info "[threadpool task thread] sending 'done' notice to pool",
      threadid=arg.id
    await arg.chanSendToPool.send(noticeToPool.toJson(typeAnnotations = true).safe)

  arg.chanRecvFromPool.close()
  arg.chanSendToPool.close()

proc taskThread(arg: TaskThreadArg) {.thread.} =
  waitFor task(arg)

proc pool(arg: PoolThreadArg) {.async.} =
  let
    chanSendToMain = arg.chanSendToMain
    chanRecvFromMainOrTask = arg.chanRecvFromMain
  var threadsBusy = newTable[int, tuple[thr: Thread[TaskThreadArg],
    chanSendToTask: AsyncChannel[ThreadSafeString]]]()
  var threadsIdle = newSeq[tuple[id: int, thr: Thread[TaskThreadArg],
    chanSendToTask: AsyncChannel[ThreadSafeString]]](arg.size)
  var taskQueue: seq[string] = @[] # FIFO queue
  var allReady = 0
  chanSendToMain.open()
  chanRecvFromMainOrTask.open()

  info "[threadpool] sending 'ready' to main thread"
  await chanSendToMain.send("ready".safe)

  for i in 0..<arg.size:
    let id = i + 1
    let chanSendToTask = newAsyncChannel[ThreadSafeString](-1)
    chanSendToTask.open()
    info "[threadpool] adding to threadsIdle", threadid=id
    threadsIdle[i].id = id
    createThread(
      threadsIdle[i].thr,
      taskThread,
      TaskThreadArg(id: id, chanRecvFromPool: chanSendToTask,
        chanSendToPool: chanRecvFromMainOrTask
      )
    )
    threadsIdle[i].chanSendToTask = chanSendToTask

  # when task received and number of busy threads == MaxThreadPoolSize,
  # then put the task in a queue

  # when task received and number of busy threads < MaxThreadPoolSize, pop
  # a thread from threadsIdle, track that thread in threadsBusy, and run
  # task in that thread

  # if "done" received from a thread, remove thread from threadsBusy, and
  # push thread into threadsIdle

  while true:
    info "[threadpool] waiting for message"
    var task = $(await chanRecvFromMainOrTask.recv())
    info "[threadpool] received message", msg=task

    if task == "shutdown":
      info "[threadpool] sending 'shutdown' to all task threads"
      for tpl in threadsIdle:
        await tpl.chanSendToTask.send("shutdown".safe)
      for tpl in threadsBusy.values:
        await tpl.chanSendToTask.send("shutdown".safe)
      info "[threadpool] breaking while loop"
      break

    let
      jsonNode = parseJson(task)
      messageType = jsonNode{"$type"}.getStr
    info "[threadpool] determined message type", messageType=messageType

    case messageType
      of "ThreadNotification":
        try:
          let notification = Json.decode(task, ThreadNotification, allowUnknownFields = true)
          info "[threadpool] received notification",
            notice=notification.notice, threadid=notification.id

          if notification.notice == "ready":
            info "[threadpool] received 'ready' from a task thread"
            allReady = allReady + 1

          elif notification.notice == "done":
            let tpl = threadsBusy[notification.id]
            info "[threadpool] adding to threadsIdle",
                newlength=(threadsIdle.len + 1)
            threadsIdle.add (notification.id, tpl.thr, tpl.chanSendToTask)
            info "[threadpool] removing from threadsBusy",
              newlength=(threadsBusy.len - 1), threadid=notification.id
            threadsBusy.del notification.id

            if taskQueue.len > 0:
              info "[threadpool] removing from taskQueue",
                newlength=(taskQueue.len - 1)
              task = taskQueue[0]
              taskQueue.delete 0, 0

              info "[threadpool] removing from threadsIdle",
                newlength=(threadsIdle.len - 1)
              let tpl = threadsIdle[0]
              threadsIdle.delete 0, 0
              info "[threadpool] adding to threadsBusy",
                newlength=(threadsBusy.len + 1), threadid=tpl.id
              threadsBusy.add tpl.id, (tpl.thr, tpl.chanSendToTask)
              await tpl.chanSendToTask.send(task.safe)

          else:
            error "[threadpool] unknown notification", notice=notification.notice
        except Exception as e:
          warn "[threadpool] unknown error in thread notification", message=task, error=e.msg

      else: # must be a request to do task work
        if allReady < arg.size or threadsBusy.len == arg.size:
          # add to queue
          info "[threadpool] adding to taskQueue",
            newlength=(taskQueue.len + 1)
          taskQueue.add task

        # do we have available threads in the threadpool?
        elif threadsBusy.len < arg.size:
          # check if we have tasks waiting on queue
          if taskQueue.len > 0:
            # remove first element from the task queue
            info "[threadpool] adding to taskQueue",
              newlength=(taskQueue.len + 1)
            taskQueue.add task
            info "[threadpool] removing from taskQueue",
              newlength=(taskQueue.len - 1)
            task = taskQueue[0]
            taskQueue.delete 0, 0

          info "[threadpool] removing from threadsIdle",
            newlength=(threadsIdle.len - 1)
          let tpl = threadsIdle[0]
          threadsIdle.delete 0, 0
          info "[threadpool] adding to threadsBusy",
            newlength=(threadsBusy.len + 1), threadid=tpl.id
          threadsBusy.add tpl.id, (tpl.thr, tpl.chanSendToTask)
          await tpl.chanSendToTask.send(task.safe)


  var allTaskThreads: seq[Thread[TaskThreadArg]] = @[]

  for tpl in threadsIdle:
    tpl.chanSendToTask.close()
    allTaskThreads.add tpl.thr
  for tpl in threadsBusy.values:
    tpl.chanSendToTask.close()
    allTaskThreads.add tpl.thr

  chanSendToMain.close()
  chanRecvFromMainOrTask.close()

  joinThreads(allTaskThreads)

proc poolThread(arg: PoolThreadArg) {.thread.} =
  waitFor pool(arg)
