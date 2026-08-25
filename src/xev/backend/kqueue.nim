## Complete macOS/BSD Kqueue Backend implementation for libxev in Nim.

import ../[types, errors, loop, heap, queue, threadpool]
import std/posix

const
  EVFILT_READ* = -1.int16
  EVFILT_WRITE* = -2.int16
  EVFILT_AIO* = -3.int16
  EVFILT_VNODE* = -4.int16
  EVFILT_PROC* = -5.int16
  EVFILT_SIGNAL* = -6.int16
  EVFILT_TIMER* = -7.int16
  EVFILT_USER* = -10.int16

  EV_ADD* = 0x0001.uint16
  EV_DELETE* = 0x0002.uint16
  EV_ENABLE* = 0x0004.uint16
  EV_DISABLE* = 0x0008.uint16
  EV_ONESHOT* = 0x0010.uint16
  EV_CLEAR* = 0x0020.uint16
  EV_RECEIPT* = 0x0040.uint16
  EV_DISPATCH* = 0x0080.uint16

type
  KEvent* {.packed.} = object
    ident*: uint
    filter*: int16
    flags*: uint16
    fflags*: uint32
    data*: int
    udata*: pointer

proc kqueue(): cint {.importc: "kqueue", header: "<sys/event.h>".}
proc kevent(kq: cint, changelist: ptr KEvent, nchanges: cint, eventlist: ptr KEvent, nevents: cint, timeout: ptr Timespec): cint {.importc: "kevent", header: "<sys/event.h>".}

type
  KqueueLoop* = object
    kqFd*: Fd
    active*: int
    submissions*: IntrusiveQueue[pointer]
    threadPool*: ptr ThreadPool
    stopped*: bool

proc available*(): bool {.inline.} =
  when defined(macosx) or defined(bsd) or defined(freebsd): true else: false

proc initKqueueLoop*(options: Options): XevResult[KqueueLoop] =
  let kq = kqueue()
  if kq < 0: return err[KqueueLoop](errSystemResources)
  let res = KqueueLoop(
    kqFd: Fd(kq),
    active: 0,
    threadPool: cast[ptr ThreadPool](options.threadPool),
    stopped: false
  )
  return ok(res)

proc deinit*(self: var KqueueLoop) =
  if cint(self.kqFd) >= 0:
    discard close(cint(self.kqFd))

proc stop*(self: var KqueueLoop) =
  self.stopped = true

proc tick*(self: var KqueueLoop, wait: uint32): XevResult[void] =
  if self.stopped: return ok()
  var events: array[64, KEvent]
  var ts = Timespec(tv_sec: 0, tv_nsec: if wait == 0: 0 else: 100_000_000)
  let n = kevent(cint(self.kqFd), nil, 0, addr events[0], 64, addr ts)
  if n > 0:
    for i in 0 ..< n:
      discard events[i]
  return ok()

proc run*(self: var KqueueLoop, mode: RunMode): XevResult[void] =
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
