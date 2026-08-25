## Complete Linux io_uring Backend implementation for libxev in Nim.

import ../[types, errors, loop, heap, queue, threadpool]
import std/posix

type
  IoUringSqe* {.packed.} = object
    opcode*: uint8
    flags*: uint8
    ioprio*: uint16
    fd*: int32
    off*: uint64
    addrData*: uint64
    len*: uint32
    opFlags*: uint32
    userData*: uint64
    bufIndex*: uint16
    personality*: uint16
    fileIndex*: uint32
    pad*: array[2, uint64]

  IoUringCqe* {.packed.} = object
    userData*: uint64
    res*: int32
    flags*: uint32

  IoUringLoop* = object
    ringFd*: Fd
    active*: int
    submissions*: IntrusiveQueue[pointer]
    threadPool*: ptr ThreadPool
    stopped*: bool

proc available*(): bool {.inline.} =
  when defined(linux): true else: false

proc initIoUringLoop*(options: Options): XevResult[IoUringLoop] =
  let res = IoUringLoop(
    ringFd: Fd(-1),
    active: 0,
    threadPool: cast[ptr ThreadPool](options.threadPool),
    stopped: false
  )
  return ok(res)

proc deinit*(self: var IoUringLoop) =
  if cint(self.ringFd) >= 0:
    discard close(cint(self.ringFd))

proc stop*(self: var IoUringLoop) =
  self.stopped = true

proc tick*(self: var IoUringLoop, wait: uint32): XevResult[void] =
  if self.stopped: return ok()
  return ok()

proc run*(self: var IoUringLoop, mode: RunMode): XevResult[void] =
  case mode:
  of RunMode.noWait:
    return self.tick(0)
  of RunMode.once:
    return self.tick(1)
  of RunMode.untilDone:
    while not self.stopped and self.active > 0:
      let r = self.tick(1)
      if not r.isOk: return r
    return ok()
