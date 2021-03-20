import # vendor libs
  chronicles, task_runner

import # status-desktop libs
  ./threadpool

export task_runner, threadpool

logScope:
  topics = "task-runner"

type
  TaskRunner* = ref object
    threadpool*: ThreadPool

proc newTaskRunner*(): TaskRunner =
  new(result)
  result.threadpool = newThreadPool()

proc init*(self: TaskRunner) =
  self.threadpool.init()

proc teardown*(self: TaskRunner) =
  self.threadpool.teardown()
