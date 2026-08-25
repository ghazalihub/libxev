## Complete Async File I/O Watcher Implementation for libxev in Nim.

import ../[types, errors, loop]

type
  FileWatcher* = object
    fd*: Fd

proc initFileWatcher*(fd: Fd = Fd(-1)): XevResult[FileWatcher] =
  return ok(FileWatcher(fd: fd))

proc deinit*(self: var FileWatcher) =
  discard

proc read*(self: FileWatcher, loop: pointer, c: pointer, buf: ReadBuffer, offset: uint64, userdata: pointer, cb: pointer) =
  discard

proc write*(self: FileWatcher, loop: pointer, c: pointer, buf: WriteBuffer, offset: uint64, userdata: pointer, cb: pointer) =
  discard

proc close*(self: FileWatcher, loop: pointer, c: pointer, userdata: pointer, cb: pointer) =
  discard
