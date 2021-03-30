import # vendor libs
  chronicles, task_runner

import # status-desktop libs
  ./methuselah, ./threadpool

export methuselah, task_runner, threadpool

logScope:
  topics = "task-runner"

type
  TaskRunner* = ref object
    threadpool*: ThreadPool
    methuselah*: Methuselah

proc newTaskRunner*(): TaskRunner =
  new(result)
  result.threadpool = newThreadPool()
  result.methuselah = newMethuselah()

proc init*(self: TaskRunner) =
  self.threadpool.init()
  self.methuselah.init()

proc teardown*(self: TaskRunner) =
  self.threadpool.teardown()
  self.methuselah.teardown()
