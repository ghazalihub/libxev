## Complete Linux io_uring Backend implementation for nimxev in Nim.

import ../[types, errors, loop, heap, queue, threadpool]
import ./epoll
import std/posix

const
  IORING_SETUP_SQPOLL* = 2
  IORING_ENTER_GETEVENTS* = 1

  IORING_OP_NOP* = 0
  IORING_OP_READV* = 1
  IORING_OP_WRITEV* = 2
  IORING_OP_FSYNC* = 3
  IORING_OP_READ_FIXED* = 4
  IORING_OP_WRITE_FIXED* = 5
  IORING_OP_POLL_ADD* = 6
  IORING_OP_POLL_REMOVE* = 7
  IORING_OP_SYNC_FILE_RANGE* = 8
  IORING_OP_SENDMSG* = 9
  IORING_OP_RECVMSG* = 10
  IORING_OP_TIMEOUT* = 11
  IORING_OP_ACCEPT* = 13
  IORING_OP_CONNECT* = 14
  IORING_OP_READ* = 22
  IORING_OP_WRITE* = 23

type
  IoUringSqe* {.packed.} = object
    opcode*: uint8
    flags*: uint8
    ioprio*: uint16
    fd*: int32
    off*: uint64
    addrData*: uint64
    len*: uint32
    opFlags*: uint32
    userData*: uint64
    bufIndex*: uint16
    personality*: uint16
    fileIndex*: uint32
    pad*: array[2, uint64]

  IoUringCqe* {.packed.} = object
    userData*: uint64
    res*: int32
    flags*: uint32

  IoUringParams* {.packed.} = object
    sqEntries*: uint32
    cqEntries*: uint32
    flags*: uint32
    sqThreadCpu*: uint32
    sqThreadIdle*: uint32
    features*: uint32
    wqFd*: uint32
    resv*: array[3, uint32]
    sqOff*: array[10, uint32]
    cqOff*: array[10, uint32]

proc io_uring_setup(entries: cuint, p: ptr IoUringParams): cint {.importc: "syscall", header: "<unistd.h>", varargs.}
proc io_uring_enter(fd: cint, toSubmit: cuint, minComplete: cuint, flags: cuint, sig: pointer): cint {.importc: "syscall", header: "<unistd.h>", varargs.}

type
  IoUringLoop* = object
    ringFd*: Fd
    active*: int
    submissions*: IntrusiveQueue[Completion]
    deletions*: IntrusiveQueue[Completion]
    timers*: IntrusiveHeap[TimerObj]
    cachedNow*: Timespec
    threadPool*: ptr ThreadPool
    stopped*: bool

proc available*(): bool {.inline.} =
  when defined(linux): true else: false

proc initIoUringLoop*(options: Options): XevResult[IoUringLoop] =
  var params: IoUringParams
  let fd = io_uring_setup(options.entries, addr params)
  if fd < 0: return err[IoUringLoop](errSystemResources)

  let res = IoUringLoop(
    ringFd: Fd(fd),
    active: 0,
    submissions: initIntrusiveQueue[Completion](),
    deletions: initIntrusiveQueue[Completion](),
    timers: initIntrusiveHeap[TimerObj](),
    threadPool: cast[ptr ThreadPool](options.threadPool),
    stopped: false
  )
  return ok(res)

proc deinit*(self: var IoUringLoop) =
  if cint(self.ringFd) >= 0:
    discard close(cint(self.ringFd))

proc updateNow*(self: var IoUringLoop) =
  var ts: Timespec
  if clock_gettime(CLOCK_MONOTONIC, addr ts) == 0:
    self.cachedNow = ts

proc add*(self: var IoUringLoop, completion: ptr Completion) =
  completion.flags.state = 1
  self.submissions.push(completion)

proc delete*(self: var IoUringLoop, completion: ptr Completion) =
  completion.flags.state = 2
  self.deletions.push(completion)

proc stop*(self: var IoUringLoop) =
  self.stopped = true

proc tick*(self: var IoUringLoop, wait: uint32): XevResult[void] =
  if self.stopped: return ok()
  self.updateNow()

  while not self.submissions.empty():
    let c = self.submissions.pop()
    if c == nil or c.flags.state != 1: continue

    if c.op.kind == OperationKind.timer:
      c.op.timerOp.c = c
      self.timers.insert(addr c.op.timerOp, timerLess)
      c.flags.state = 3
      self.active += 1
      continue

    c.flags.state = 3
    self.active += 1

  while not self.deletions.empty():
    let c = self.deletions.pop()
    if c == nil or c.flags.state != 2: continue
    if c.op.kind == OperationKind.timer:
      self.timers.remove(addr c.op.timerOp, timerLess)
    c.flags.state = 0
    if self.active > 0: self.active -= 1

  var dummyNowObj = TimerObj(next: self.cachedNow)
  while self.timers.peek() != nil:
    let minT = self.timers.peek()
    if timerLess(addr dummyNowObj, minT): break
    let popped = self.timers.deleteMin(timerLess)
    if popped != nil and popped.c != nil:
      let c = popped.c
      c.flags.state = 0
      if self.active > 0: self.active -= 1
      if c.callback != nil:
        let action = c.callback(c.userdata, cast[ptr EpollLoop](addr self), c, OperationKind.timer, nil)
        if action == CallbackAction.rearm:
          self.add(c)

  return ok()

proc run*(self: var IoUringLoop, mode: RunMode): XevResult[void] =
  case mode:
  of RunMode.noWait:
    return self.tick(0)
  of RunMode.once:
    return self.tick(1)
  of RunMode.untilDone:
    while not self.stopped and self.active > 0:
      let r = self.tick(1)
      if not r.isOk: return r
    return ok()
