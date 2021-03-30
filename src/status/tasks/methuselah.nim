import # std libs
  tables

import # vendor libs
  chronicles

import # status-desktop libs
  ./methuselah/[worker, mailserver]

logScope:
  topics = "task-methuselah"

type
  Methuselah* = ref object
    workers: Table[string, MethuselahWorker]

proc newMethuselah*(): Methuselah =
  new(result)
  result.workers = [
    ("mailserver", cast[MethuselahWorker](newMailserverWorker()))
    # ("ipc", newIpcWorker())
  ].toTable

proc init*(self: Methuselah) =
  for worker in self.workers.values:
    cast[MailserverWorker](worker).init()

proc teardown*(self: Methuselah) =
  for worker in self.workers.values:
    worker.teardown()