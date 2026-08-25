## Async File I/O Watcher Implementation for libxev in Nim.

import ../[types, errors, loop]

type
  FileWatcher* = object
    fd*: Fd

proc initFileWatcher*(fd: Fd = Fd(-1)): XevResult[FileWatcher] =
  return ok(FileWatcher(fd: fd))

proc deinit*(self: var FileWatcher) =
  discard
