import
  chronicles, chronos, NimQml, task_runner

logScope:
  topics = "tasks-signals"

QtObject:
  type TasksSignalsController* = ref object of QObject
    variant*: QVariant
    chanSend: AsyncChannel[ThreadSafeString]

  proc newController*(chanSend: AsyncChannel[ThreadSafeString]): TasksSignalsController =
    new(result)
    result.setup()
    result.variant = newQVariant(result)
    result.chanSend = chanSend

  proc setup(self: TasksSignalsController) =
    self.QObject.setup()

  proc delete*(self: TasksSignalsController) =
    self.variant.delete()
    self.QObject.delete()

  proc processSignal(self: TasksSignalsController, statusSignal: string) =
    debugEcho ">>> [status/signals/tasks.processSignal] statusSignal: ", statusSignal
    

    # self.status.events.emit(signalType.event, signal)

  proc signalReceived*(self: TasksSignalsController, signal: string) {.signal.}

  proc receiveSignal(self: TasksSignalsController, signal: string) {.slot.} =
    self.processSignal(signal)
    self.signalReceived(signal)

  proc createTask(self: TasksSignalsController) {.slot.} =
    debugEcho ">>> [signals/tasks.createTask] sending task to channel"
    self.chanSend.sendSync("do task".safe)
