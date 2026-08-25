## Linux io_uring Backend Implementation in Nim.

import ../[types, errors, loop, heap, queue, threadpool]
import std/posix

type
  IoUringOpKind* {.pure.} = enum
    noop
    cancel
    accept
    connect
    poll
    read
    pread
    write
    pwrite
    send
    recv
    sendmsg
    recvmsg
    close
    shutdown
    timer

  IoUringLoop* = object
    ringFd*: Fd
    active*: int
    submissions*: IntrusiveQueue[pointer]
    threadPool*: ptr ThreadPool

proc available*(): bool {.inline.} =
  when defined(linux): true else: false

proc initIoUringLoop*(options: Options): XevResult[IoUringLoop] =
  let res = IoUringLoop(
    ringFd: Fd(-1),
    threadPool: cast[ptr ThreadPool](options.threadPool)
  )
  return ok(res)

proc deinit*(self: var IoUringLoop) =
  discard

proc run*(self: var IoUringLoop, mode: RunMode): XevResult[void] =
  return ok()
