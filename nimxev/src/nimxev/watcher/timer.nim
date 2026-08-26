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
  loop: pointer,
  c: ptr Completion,
  nextMs: uint64,
  userdata: pointer,
  cb: CallbackProc
) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  epollLoopPtr[].updateNow()
  var curTs = epollLoopPtr[].cachedNow

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
  epollLoopPtr[].add(c)

proc reset*(
  self: TimerWatcher,
  loop: pointer,
  c: ptr Completion,
  cCancel: ptr Completion,
  nextMs: uint64,
  userdata: pointer,
  cb: CallbackProc
) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  if cCancel != nil:
    cCancel.op = Operation(kind: OperationKind.cancel)
    cCancel.op.cancelOp = CancelOp(c: c)
    epollLoopPtr[].add(cCancel)

  self.run(loop, c, nextMs, userdata, cb)

proc cancel*(
  self: TimerWatcher,
  loop: pointer,
  cTimer: ptr Completion,
  cCancel: ptr Completion,
  userdata: pointer,
  cb: CallbackProc
) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  cCancel.op = Operation(kind: OperationKind.cancel)
  cCancel.op.cancelOp = CancelOp(c: cTimer)
  cCancel.userdata = userdata
  cCancel.callback = cb
  epollLoopPtr[].add(cCancel)
