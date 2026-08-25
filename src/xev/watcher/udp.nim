## UDP Socket Watcher Implementation for libxev in Nim.

import ../[types, errors, loop]

type
  UdpWatcher* = object
    fd*: SockFd

proc initUdpWatcher*(fd: SockFd = SockFd(-1)): XevResult[UdpWatcher] =
  return ok(UdpWatcher(fd: fd))

proc deinit*(self: var UdpWatcher) =
  discard
