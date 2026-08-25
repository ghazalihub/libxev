## UDP Socket Watcher Implementation for nimxev in Nim.

import ../[types, errors, loop]
import ../backend/epoll
import std/posix

type
  UdpWatcher* = object
    fd*: SockFd

proc initUdpWatcher*(fd: SockFd = SockFd(-1)): XevResult[UdpWatcher] =
  if cint(fd) >= 0:
    return ok(UdpWatcher(fd: fd))
  let s = socket(AF_INET, SOCK_DGRAM or SOCK_CLOEXEC or SOCK_NONBLOCK, 0)
  if s < 0: return err[UdpWatcher](errSystemResources)
  return ok(UdpWatcher(fd: SockFd(s)))

proc deinit*(self: var UdpWatcher) =
  if cint(self.fd) >= 0:
    discard close(cint(self.fd))

proc bindAddr*(self: UdpWatcher, address: string, port: uint16): XevResult[void] =
  var sa: Sockaddr_in
  sa.sin_family = uint16(AF_INET)
  sa.sin_port = htons(port)
  sa.sin_addr.s_addr = inet_addr(cstring(address))

  if bindSocket(cint(self.fd), cast[ptr SockAddr](addr sa), sizeof(sa).SockLen) < 0:
    return err[void](errUnexpected)
  return ok()

proc send*(self: UdpWatcher, loop: ptr EpollLoop, c: ptr Completion, buf: WriteBuffer, address: string, port: uint16, userdata: pointer, cb: CallbackProc) =
  c.op = Operation(kind: OperationKind.send)
  c.op.sendOp = SendOp(fd: Fd(cint(self.fd)), buffer: buf)
  c.userdata = userdata
  c.callback = cb
  loop[].add(c)

proc recv*(self: UdpWatcher, loop: ptr EpollLoop, c: ptr Completion, buf: ReadBuffer, userdata: pointer, cb: CallbackProc) =
  c.op = Operation(kind: OperationKind.recv)
  c.op.recvOp = RecvOp(fd: Fd(cint(self.fd)), buffer: buf)
  c.userdata = userdata
  c.callback = cb
  loop[].add(c)

proc close*(self: UdpWatcher, loop: ptr EpollLoop, c: ptr Completion, userdata: pointer, cb: CallbackProc) =
  c.op = Operation(kind: OperationKind.close)
  c.op.closeOp = CloseOp(fd: Fd(cint(self.fd)))
  c.userdata = userdata
  c.callback = cb
  loop[].add(c)
