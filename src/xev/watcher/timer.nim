## Timer Watcher Implementation for libxev in Nim.

import ../[types, errors, loop]

type
  TimerWatcher* = object
    active*: bool

proc initTimerWatcher*(): XevResult[TimerWatcher] =
  return ok(TimerWatcher(active: false))

proc deinit*(self: var TimerWatcher) =
  discard
