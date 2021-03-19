import # vendor libs
  chronicles, task_runner

import # status-desktop libs
  ./threadpool

export task_runner, threadpool

logScope:
  topics = "task-manager"

type
  TaskManager* = ref object
    threadpool*: ThreadPool

proc newTaskManager*(): TaskManager =
  new(result)
  result.threadpool = newThreadPool()

proc init*(self: TaskManager) =
  self.threadpool.init()

proc teardown*(self: TaskManager) =
  self.threadpool.teardown()
