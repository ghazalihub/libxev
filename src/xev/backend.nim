## Backend Selection for libxev in Nim.

type
  BackendKind* {.pure.} = enum
    ioUring
    epoll
    kqueue
    wasiPoll
    iocp

proc defaultBackend*(): BackendKind {.inline.} =
  when defined(linux):
    return BackendKind.ioUring
  elif defined(macosx) or defined(bsd) or defined(freebsd):
    return BackendKind.kqueue
  elif defined(wasm) or defined(wasi):
    return BackendKind.wasiPoll
  elif defined(windows):
    return BackendKind.iocp
  else:
    return BackendKind.epoll
