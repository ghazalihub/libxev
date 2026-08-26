## Cross-platform Async Watcher Implementation for nimxev in Nim.

import ../[types, errors, loop]
import ../backend/epoll
import std/posix

proc eventfd(initval: cuint, flags: cint): cint {.importc: "eventfd", header: "<sys/eventfd.h>".}

type
  AsyncWatcher* = object
    fd*: Fd
    rFd*: Fd
    wFd*: Fd

proc initAsyncWatcher*(): XevResult[AsyncWatcher] =
  when defined(linux):
    let efd = eventfd(0, 0x80000 or 0x800) # EFD_CLOEXEC | EFD_NONBLOCK
    if efd < 0: return err[AsyncWatcher](errSystemResources)
    return ok(AsyncWatcher(fd: Fd(efd), rFd: Fd(-1), wFd: Fd(-1)))
  else:
    var fds: array[2, cint]
    if pipe(fds) < 0: return err[AsyncWatcher](errSystemResources)
    return ok(AsyncWatcher(fd: Fd(fds[0]), rFd: Fd(fds[0]), wFd: Fd(fds[1])))

proc deinit*(self: var AsyncWatcher) =
  if cint(self.fd) >= 0:
    discard close(cint(self.fd))
  if cint(self.wFd) >= 0 and cint(self.wFd) != cint(self.fd):
    discard close(cint(self.wFd))

proc notify*(self: AsyncWatcher): XevResult[void] =
  var val: uint64 = 1
  let target = if cint(self.wFd) >= 0: cint(self.wFd) else: cint(self.fd)
  if write(target, addr val, sizeof(val)) < 0:
    return err[void](errUnexpected)
  return ok()

proc wait*(
  self: AsyncWatcher,
  loop: pointer,
  c: ptr Completion,
  userdata: pointer,
  cb: CallbackProc
) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  c.op = Operation(kind: OperationKind.read)
  c.op.readOp = ReadOp(fd: self.fd, buffer: initReadBufferArray())
  c.userdata = userdata
  c.callback = cb
  epollLoopPtr[].add(c)
