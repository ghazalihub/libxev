## macOS/BSD Kqueue Backend Implementation in Nim.

import ../[types, errors, loop, heap, queue, threadpool]
import std/posix

type
  KqueueLoop* = object
    kqFd*: Fd
    active*: int
    threadPool*: ptr ThreadPool

proc available*(): bool {.inline.} =
  when defined(macosx) or defined(bsd) or defined(freebsd): true else: false

proc initKqueueLoop*(options: Options): XevResult[KqueueLoop] =
  let res = KqueueLoop(
    kqFd: Fd(-1),
    threadPool: cast[ptr ThreadPool](options.threadPool)
  )
  return ok(res)

proc deinit*(self: var KqueueLoop) =
  discard

proc run*(self: var KqueueLoop, mode: RunMode): XevResult[void] =
  return ok()
