## Async Watcher Implementation for libxev in Nim.

import ../[types, errors, loop]

type
  AsyncWatcher* = object
    fd*: Fd

proc initAsyncWatcher*(): XevResult[AsyncWatcher] =
  return ok(AsyncWatcher(fd: Fd(-1)))

proc deinit*(self: var AsyncWatcher) =
  discard

proc notify*(self: AsyncWatcher): XevResult[void] =
  return ok()
