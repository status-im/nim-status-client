import NimQml, tables, json, chronicles, strutils, json_serialization
import ../libstatus/types as status_types
import types, messages, discovery, whisperFilter, envelopes, expired, wallet, mailserver
import ../status
import ../../eventemitter

logScope:
  topics = "tasks-signals"

QtObject:
  type TasksSignalsController* = ref object of QObject
    variant*: QVariant

  proc newController*(): TasksSignalsController =
    new(result)
    result.setup()
    result.variant = newQVariant(result)

  proc setup(self: TasksSignalsController) =
    self.QObject.setup()

  proc delete*(self: TasksSignalsController) =
    self.variant.delete()
    self.QObject.delete()

  proc processSignal(self: TasksSignalsController, statusSignal: string) =
    debugEcho ">>> [status/signals/tasks.processSignal] statusSignal: ", statusSignal
    

    # self.status.events.emit(signalType.event, signal)

  # proc signalReceived*(self: TasksSignalsController, signal: string) {.signal.}

  proc receiveSignal(self: TasksSignalsController, signal: string) {.slot.} =
    self.processSignal(signal)
    # self.signalReceived(signal)
