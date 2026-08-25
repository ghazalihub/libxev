## Complete Top-level libxev Nim Module.

import ./xev/[types, errors, loop, heap, queue, queue_mpsc, threadpool, backend, api]
import ./xev/backend/[epoll, io_uring, kqueue, wasi_poll, iocp]
import ./xev/watcher/[async, timer, tcp, udp, file, process, stream]

export types, errors, loop, heap, queue, queue_mpsc, threadpool, backend, api
export epoll, io_uring, kqueue, wasi_poll, iocp
export async, timer, tcp, udp, file, process, stream

type
  DefaultLoop* = when defined(linux):
      EpollLoop
    elif defined(macosx) or defined(bsd) or defined(freebsd):
      KqueueLoop
    elif defined(wasm) or defined(wasi):
      WasiPollLoop
    elif defined(windows):
      IocpLoop
    else:
      EpollLoop
