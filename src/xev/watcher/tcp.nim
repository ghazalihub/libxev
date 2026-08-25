## TCP Socket Watcher Implementation for libxev in Nim.

import ../[types, errors, loop]

type
  TcpWatcher* = object
    fd*: SockFd

proc initTcpWatcher*(fd: SockFd = SockFd(-1)): XevResult[TcpWatcher] =
  return ok(TcpWatcher(fd: fd))

proc deinit*(self: var TcpWatcher) =
  discard
