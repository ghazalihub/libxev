## Timer Watcher Implementation for nimxev in Nim.

import ../[types, errors, loop]
import ../backend/epoll
import std/posix

type
  TimerWatcher* = object
    active*: bool

proc initTimerWatcher*(): XevResult[TimerWatcher] =
  return ok(TimerWatcher(active: false))

proc deinit*(self: var TimerWatcher) =
  discard

proc run*(
  self: TimerWatcher,
  loop: ptr EpollLoop,
  c: ptr Completion,
  nextMs: uint64,
  userdata: pointer,
  cb: CallbackProc
) =
  loop[].updateNow()
  var curTs = loop[].cachedNow

  let addSec = Time(nextMs div 1000)
  let addNsec = int((nextMs mod 1000) * 1_000_000)

  var targetSec = curTs.tv_sec + addSec
  var targetNsec = curTs.tv_nsec + addNsec
  if targetNsec >= 1_000_000_000:
    targetSec += 1
    targetNsec -= 1_000_000_000

  var ts: Timespec
  ts.tv_sec = targetSec
  ts.tv_nsec = targetNsec

  c.op = Operation(kind: OperationKind.timer)
  c.op.timerOp = TimerObj(next: ts, c: c)
  c.userdata = userdata
  c.callback = cb
  loop[].add(c)

proc reset*(
  self: TimerWatcher,
  loop: ptr EpollLoop,
  c: ptr Completion,
  cCancel: ptr Completion,
  nextMs: uint64,
  userdata: pointer,
  cb: CallbackProc
) =
  if cCancel != nil:
    cCancel.op = Operation(kind: OperationKind.cancel)
    cCancel.op.cancelOp = CancelOp(c: c)
    loop[].add(cCancel)

  self.run(loop, c, nextMs, userdata, cb)

proc cancel*(
  self: TimerWatcher,
  loop: ptr EpollLoop,
  cTimer: ptr Completion,
  cCancel: ptr Completion,
  userdata: pointer,
  cb: CallbackProc
) =
  cCancel.op = Operation(kind: OperationKind.cancel)
  cCancel.op.cancelOp = CancelOp(c: cTimer)
  cCancel.userdata = userdata
  cCancel.callback = cb
  loop[].add(cCancel)
