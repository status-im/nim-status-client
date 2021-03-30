import # std libs
  json, tables

import # vendor libs
  chronicles, chronos, json_serialization, task_runner

import # status-desktop libs
  ../common, ./worker

export
  chronos, common, json_serialization

logScope:
  topics = "mailserver worker"

type
  MailserverWorker* = ref object of MethuselahWorker
  # MailserverWorkerThreadArg = ref object of WorkerThreadArg
  ThreadNotification = object
    id: int
    notice: string

# forward declarations
proc mailserverThread(arg: WorkerThreadArg) {.thread.}

proc newMailserverWorker*(): MailserverWorker =
  new(result)
  # if we need to do things in the base class' constructor,
  # uncomment the following line:
  # result = cast[MailserverWorker](newMethuselahWorker())
  result.chanRecvFromMain = newAsyncChannel[ThreadSafeString](-1)
  result.chanSendToMain = newAsyncChannel[ThreadSafeString](-1)

proc init*(self: MailserverWorker) =
  self.chanRecvFromMain.open()
  self.chanSendToMain.open()
  let arg = WorkerThreadArg(
    chanSendToMain: self.chanRecvFromMain,
    chanRecvFromMain: self.chanSendToMain
  )
  createThread(self.thread, mailserverThread, arg)
  # block until we receive "ready"
  discard $(self.chanRecvFromMain.recvSync())

proc teardown*(self: MailserverWorker) =
  self.chanSendToMain.sendSync("shutdown".safe)
  self.chanRecvFromMain.close()
  self.chanSendToMain.close()
  debug "waiting for the control thread to stop"
  joinThread(self.thread)

proc mailserver(arg: WorkerThreadArg) {.async.} =
  let
    chanSendToMain = arg.chanSendToMain
    chanRecvFromMain = arg.chanRecvFromMain
  chanSendToMain.open()
  chanRecvFromMain.open()

  debug "sending 'ready' to main thread"
  await chanSendToMain.send("ready".safe)

  while true:
    await sleepAsync 1000.milliseconds
    debug "MAILSERVER DOING ITS THING"

proc mailserverThread(arg: WorkerThreadArg) {.thread.} =
  waitFor mailserver(arg)