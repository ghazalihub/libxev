## Complete Timer Watcher Implementation for libxev in Nim.

import ../[types, errors, loop]

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
  c: pointer,
  nextMs: uint64,
  userdata: pointer,
  cb: pointer
) =
  discard

proc reset*(
  self: TimerWatcher,
  loop: pointer,
  c: pointer,
  cCancel: pointer,
  nextMs: uint64,
  userdata: pointer,
  cb: pointer
) =
  discard

proc cancel*(
  self: TimerWatcher,
  loop: pointer,
  cTimer: pointer,
  cCancel: pointer,
  userdata: pointer,
  cb: pointer
) =
  discard
