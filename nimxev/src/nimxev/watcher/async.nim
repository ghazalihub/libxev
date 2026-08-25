## Async Watcher Implementation for nimxev in Nim.

import ../[types, errors, loop]
import ../backend/epoll
import std/posix

proc eventfd(initval: cuint, flags: cint): cint {.importc: "eventfd", header: "<sys/eventfd.h>".}

type
  AsyncWatcher* = object
    fd*: Fd

proc initAsyncWatcher*(): XevResult[AsyncWatcher] =
  let efd = eventfd(0, 0x80000 or 0x800) # EFD_CLOEXEC | EFD_NONBLOCK
  if efd < 0: return err[AsyncWatcher](errSystemResources)
  return ok(AsyncWatcher(fd: Fd(efd)))

proc deinit*(self: var AsyncWatcher) =
  if cint(self.fd) >= 0:
    discard close(cint(self.fd))

proc notify*(self: AsyncWatcher): XevResult[void] =
  var val: uint64 = 1
  if write(cint(self.fd), addr val, sizeof(val)) < 0:
    return err[void](errUnexpected)
  return ok()

proc wait*(
  self: AsyncWatcher,
  loop: ptr EpollLoop,
  c: ptr Completion,
  userdata: pointer,
  cb: CallbackProc
) =
  c.op = Operation(kind: OperationKind.read)
  c.op.readOp = ReadOp(fd: self.fd, buffer: initReadBufferArray())
  c.userdata = userdata
  c.callback = cb
  loop[].add(c)
