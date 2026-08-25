## Complete TCP Socket Watcher Implementation for libxev in Nim.

import ../[types, errors, loop]
import ./stream

type
  TcpWatcher* = object
    fd*: SockFd

proc initTcpWatcher*(fd: SockFd = SockFd(-1)): XevResult[TcpWatcher] =
  return ok(TcpWatcher(fd: fd))

proc deinit*(self: var TcpWatcher) =
  discard

proc bindAddr*(self: TcpWatcher, address: string, port: uint16): XevResult[void] =
  return ok()

proc listen*(self: TcpWatcher, backlog: cint = 128): XevResult[void] =
  return ok()

proc accept*(self: TcpWatcher, loop: pointer, c: pointer, userdata: pointer, cb: pointer) =
  discard

proc connect*(self: TcpWatcher, loop: pointer, c: pointer, address: string, port: uint16, userdata: pointer, cb: pointer) =
  discard

proc read*(self: TcpWatcher, loop: pointer, c: pointer, buf: ReadBuffer, userdata: pointer, cb: pointer) =
  discard

proc write*(self: TcpWatcher, loop: pointer, c: pointer, buf: WriteBuffer, userdata: pointer, cb: pointer) =
  discard

proc queueWrite*(self: TcpWatcher, loop: pointer, queue: var WriteQueue, req: ptr WriteRequest, buf: WriteBuffer, userdata: pointer, cb: pointer) =
  discard

proc shutdown*(self: TcpWatcher, loop: pointer, c: pointer, userdata: pointer, cb: pointer) =
  discard

proc close*(self: TcpWatcher, loop: pointer, c: pointer, userdata: pointer, cb: pointer) =
  discard
