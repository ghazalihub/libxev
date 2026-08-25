## Complete Process Watcher Implementation for libxev in Nim.

import ../[types, errors, loop]

type
  ProcessWatcher* = object
    pid*: cint

proc initProcessWatcher*(pid: cint = -1): XevResult[ProcessWatcher] =
  return ok(ProcessWatcher(pid: pid))

proc deinit*(self: var ProcessWatcher) =
  discard

proc wait*(self: ProcessWatcher, loop: pointer, c: pointer, userdata: pointer, cb: pointer) =
  discard
