## Timer Watcher Implementation for nimxev in Nim.

import ../[types, errors, loop]
import ../backend/epoll

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
  var ts: Timespec
  ts.tv_sec = Time(nextMs div 1000)
  ts.tv_nsec = int(nextMs mod 1000) * 1_000_000

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
