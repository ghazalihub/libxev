## TCP Socket Watcher Implementation for nimxev in Nim.

import ../[types, errors, loop]
import ../backend/epoll
import ./stream
import std/posix

type
  TcpWatcher* = object
    fd*: SockFd

proc initTcpWatcher*(fd: SockFd = SockFd(-1)): XevResult[TcpWatcher] =
  if cint(fd) >= 0:
    return ok(TcpWatcher(fd: fd))
  let s = socket(AF_INET, SOCK_STREAM or SOCK_CLOEXEC or SOCK_NONBLOCK, 0)
  if s < 0: return err[TcpWatcher](errSystemResources)
  return ok(TcpWatcher(fd: SockFd(s)))

proc deinit*(self: var TcpWatcher) =
  if cint(self.fd) >= 0:
    discard close(cint(self.fd))

proc bindAddr*(self: TcpWatcher, address: string, port: uint16): XevResult[void] =
  var sa: Sockaddr_in
  sa.sin_family = uint16(AF_INET)
  sa.sin_port = htons(port)
  sa.sin_addr.s_addr = inet_addr(cstring(address))

  var opt: cint = 1
  discard setsockopt(cint(self.fd), SOL_SOCKET, SO_REUSEADDR, addr opt, sizeof(opt).SockLen)

  if bindSocket(cint(self.fd), cast[ptr SockAddr](addr sa), sizeof(sa).SockLen) < 0:
    return err[void](errUnexpected)
  return ok()

proc listen*(self: TcpWatcher, backlog: cint = 128): XevResult[void] =
  if posix.listen(cint(self.fd), backlog) < 0:
    return err[void](errUnexpected)
  return ok()

proc accept*(self: TcpWatcher, loop: pointer, c: ptr Completion, userdata: pointer, cb: CallbackProc) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  c.op = Operation(kind: OperationKind.accept)
  c.op.acceptOp = AcceptOp(socket: self.fd)
  c.userdata = userdata
  c.callback = cb
  epollLoopPtr[].add(c)

proc connect*(self: TcpWatcher, loop: pointer, c: ptr Completion, address: string, port: uint16, userdata: pointer, cb: CallbackProc) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  c.op = Operation(kind: OperationKind.connect)
  c.op.connectOp = ConnectOp(socket: self.fd)
  c.userdata = userdata
  c.callback = cb
  epollLoopPtr[].add(c)

proc read*(self: TcpWatcher, loop: pointer, c: ptr Completion, buf: ReadBuffer, userdata: pointer, cb: CallbackProc) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  c.op = Operation(kind: OperationKind.read)
  c.op.readOp = ReadOp(fd: Fd(cint(self.fd)), buffer: buf)
  c.userdata = userdata
  c.callback = cb
  epollLoopPtr[].add(c)

proc write*(self: TcpWatcher, loop: pointer, c: ptr Completion, buf: WriteBuffer, userdata: pointer, cb: CallbackProc) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  c.op = Operation(kind: OperationKind.write)
  c.op.writeOp = WriteOp(fd: Fd(cint(self.fd)), buffer: buf)
  c.userdata = userdata
  c.callback = cb
  epollLoopPtr[].add(c)

proc queueWrite*(self: TcpWatcher, loop: pointer, queue: var WriteQueue, req: ptr WriteRequest, buf: WriteBuffer, userdata: pointer, cb: CallbackProc) =
  req.buffer = buf
  req.cb = cast[pointer](cb)
  req.userdata = userdata
  queue.push(req)

proc shutdown*(self: TcpWatcher, loop: pointer, c: ptr Completion, userdata: pointer, cb: CallbackProc) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  c.op = Operation(kind: OperationKind.shutdown)
  c.op.shutdownOp = ShutdownOp(socket: self.fd, how: ShutdownHow.both)
  c.userdata = userdata
  c.callback = cb
  epollLoopPtr[].add(c)

proc close*(self: TcpWatcher, loop: pointer, c: ptr Completion, userdata: pointer, cb: CallbackProc) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  c.op = Operation(kind: OperationKind.close)
  c.op.closeOp = CloseOp(fd: Fd(cint(self.fd)))
  c.userdata = userdata
  c.callback = cb
  epollLoopPtr[].add(c)
