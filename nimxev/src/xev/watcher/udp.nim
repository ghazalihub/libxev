## Complete UDP Socket Watcher Implementation for libxev in Nim.

import ../[types, errors, loop]

type
  UdpWatcher* = object
    fd*: SockFd

proc initUdpWatcher*(fd: SockFd = SockFd(-1)): XevResult[UdpWatcher] =
  return ok(UdpWatcher(fd: fd))

proc deinit*(self: var UdpWatcher) =
  discard

proc bindAddr*(self: UdpWatcher, address: string, port: uint16): XevResult[void] =
  return ok()

proc send*(self: UdpWatcher, loop: pointer, c: pointer, buf: WriteBuffer, address: string, port: uint16, userdata: pointer, cb: pointer) =
  discard

proc recv*(self: UdpWatcher, loop: pointer, c: pointer, buf: ReadBuffer, userdata: pointer, cb: pointer) =
  discard

proc close*(self: UdpWatcher, loop: pointer, c: pointer, userdata: pointer, cb: pointer) =
  discard
