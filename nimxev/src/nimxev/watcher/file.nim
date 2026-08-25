## Async File I/O Watcher Implementation for nimxev in Nim.

import ../[types, errors, loop]
import ../backend/epoll
import std/posix

type
  FileWatcher* = object
    fd*: Fd

proc initFileWatcher*(fd: Fd = Fd(-1)): XevResult[FileWatcher] =
  return ok(FileWatcher(fd: fd))

proc deinit*(self: var FileWatcher) =
  if cint(self.fd) >= 0:
    discard close(cint(self.fd))

proc read*(self: FileWatcher, loop: ptr EpollLoop, c: ptr Completion, buf: ReadBuffer, offset: uint64, userdata: pointer, cb: CallbackProc) =
  c.op = Operation(kind: OperationKind.pread)
  c.op.preadOp = PReadOp(fd: self.fd, buffer: buf, offset: offset)
  c.userdata = userdata
  c.callback = cb
  loop[].add(c)

proc write*(self: FileWatcher, loop: ptr EpollLoop, c: ptr Completion, buf: WriteBuffer, offset: uint64, userdata: pointer, cb: CallbackProc) =
  c.op = Operation(kind: OperationKind.pwrite)
  c.op.pwriteOp = PWriteOp(fd: self.fd, buffer: buf, offset: offset)
  c.userdata = userdata
  c.callback = cb
  loop[].add(c)

proc close*(self: FileWatcher, loop: ptr EpollLoop, c: ptr Completion, userdata: pointer, cb: CallbackProc) =
  c.op = Operation(kind: OperationKind.close)
  c.op.closeOp = CloseOp(fd: self.fd)
  c.userdata = userdata
  c.callback = cb
  loop[].add(c)
