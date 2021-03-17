import # vendor libs
  chronicles, task_runner

import # status-desktop libs
  ./threadpool

export threadpool

logScope:
  topics = "task-manager"

type
  TaskManager* = ref object
    threadPool*: ThreadPool

proc newTaskManager*(): TaskManager =
  new(result)
  result.threadPool = newThreadPool()

proc init*(self: TaskManager) =
  self.threadPool.init()

proc teardown*(self: TaskManager) =
  self.threadPool.teardown()



