## Generic API Wrapper Dispatcher for nimxev in Nim.

import ./[types, errors, loop, backend]
import ./backend/[epoll, io_uring, kqueue, wasi_poll, iocp]
import ./watcher/[async, timer, tcp, udp, file, process, stream]

type
  XevApi*[B: static BackendKind] = object

proc available*[B: static BackendKind](): bool {.inline.} =
  when B == BackendKind.epoll:
    epoll.available()
  elif B == BackendKind.ioUring:
    io_uring.available()
  elif B == BackendKind.kqueue:
    kqueue.available()
  elif B == BackendKind.wasiPoll:
    wasi_poll.available()
  elif B == BackendKind.iocp:
    iocp.available()
