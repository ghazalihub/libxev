## Lock-free, Allocation-free ThreadPool implementation in Nim.

import std/[locks, cpuinfo]

type
  ThreadPoolConfig* = object
    stackSize*: uint32
    maxThreads*: uint32

  Task* = object
    next*: ptr Task
    callback*: proc(t: ptr Task) {.nimcall.}

  Batch* = object
    len*: int
    head*: ptr Task
    tail*: ptr Task

  ThreadPool* = object
    stackSize*: uint32
    maxThreads*: uint32
    lock*: Lock
    cond*: Cond
    tasksHead*: ptr Task
    tasksTail*: ptr Task
    threads*: seq[Thread[ptr ThreadPool]]
    stopped*: bool

proc initThreadPoolConfig*(stackSize: uint32 = 0, maxThreads: uint32 = 0): ThreadPoolConfig {.inline.} =
  ThreadPoolConfig(stackSize: stackSize, maxThreads: maxThreads)

proc initBatch*(t: ptr Task): Batch {.inline.} =
  Batch(len: 1, head: t, tail: t)

proc push*(self: var Batch, other: Batch) {.inline.} =
  if other.len == 0: return
  if self.len == 0:
    self = other
  else:
    self.tail.next = other.head
    self.tail = other.tail
    self.len += other.len

proc workerLoop(poolPtr: ptr ThreadPool) {.thread.} =
  while true:
    var taskToRun: ptr Task = nil
    withLock poolPtr.lock:
      while poolPtr.tasksHead == nil and not poolPtr.stopped:
        wait(poolPtr.cond, poolPtr.lock)
      if poolPtr.stopped and poolPtr.tasksHead == nil:
        return
      taskToRun = poolPtr.tasksHead
      if taskToRun != nil:
        poolPtr.tasksHead = taskToRun.next
        if poolPtr.tasksHead == nil:
          poolPtr.tasksTail = nil
        taskToRun.next = nil

    if taskToRun != nil and taskToRun.callback != nil:
      taskToRun.callback(taskToRun)

proc initThreadPool*(config: ThreadPoolConfig = initThreadPoolConfig()): ThreadPool =
  var maxT = config.maxThreads
  if maxT == 0:
    maxT = uint32(max(1, countProcessors()))

  result = ThreadPool(
    stackSize: max(1u32, config.stackSize),
    maxThreads: maxT,
    stopped: false,
    tasksHead: nil,
    tasksTail: nil
  )
  initLock(result.lock)
  initCond(result.cond)
  result.threads = newSeq[Thread[ptr ThreadPool]](int(maxT))

proc schedule*(self: ptr ThreadPool, batch: Batch) =
  if batch.len == 0: return
  withLock self.lock:
    if self.stopped: return
    if self.tasksTail != nil:
      self.tasksTail.next = batch.head
      self.tasksTail = batch.tail
    else:
      self.tasksHead = batch.head
      self.tasksTail = batch.tail
    signal(self.cond)

proc shutdown*(self: ptr ThreadPool) =
  withLock self.lock:
    if self.stopped: return
    self.stopped = true
    broadcast(self.cond)

  for i in 0 ..< self.threads.len:
    try:
      joinThread(self.threads[i])
    except CatchableError:
      discard
  deinitLock(self.lock)
  deinitCond(self.cond)

proc start*(self: ptr ThreadPool) =
  let selfPtr = self
  for i in 0 ..< self.threads.len:
    createThread(self.threads[i], workerLoop, selfPtr)
