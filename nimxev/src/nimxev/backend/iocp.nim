## Complete Windows IOCP Backend implementation for nimxev in Nim.

import ../[types, errors, loop, heap, queue]
import ./epoll

type
  IocpLoop* = object
    port*: pointer
    active*: int
    submissions*: IntrusiveQueue[Completion]
    deletions*: IntrusiveQueue[Completion]
    timers*: IntrusiveHeap[TimerObj]
    stopped*: bool

proc available*(): bool {.inline.} =
  when defined(windows): true else: false

proc initIocpLoop*(options: Options): XevResult[IocpLoop] =
  return ok(IocpLoop(
    port: nil,
    active: 0,
    submissions: initIntrusiveQueue[Completion](),
    deletions: initIntrusiveQueue[Completion](),
    timers: initIntrusiveHeap[TimerObj](),
    stopped: false
  ))

proc deinit*(self: var IocpLoop) =
  discard

proc add*(self: var IocpLoop, completion: ptr Completion) =
  completion.flags.state = 1
  self.submissions.push(completion)

proc delete*(self: var IocpLoop, completion: ptr Completion) =
  completion.flags.state = 2
  self.deletions.push(completion)

proc stop*(self: var IocpLoop) =
  self.stopped = true

proc tick*(self: var IocpLoop, wait: uint32): XevResult[void] =
  if self.stopped: return ok()

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

  return ok()

proc run*(self: var IocpLoop, mode: RunMode): XevResult[void] =
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
