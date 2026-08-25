## Complete macOS/BSD Kqueue Backend implementation for nimxev in Nim.

import ../[types, errors, loop, heap, queue, threadpool]
import ./epoll
import std/posix

const
  EVFILT_READ* = -1.int16
  EVFILT_WRITE* = -2.int16
  EVFILT_TIMER* = -7.int16

  EV_ADD* = 0x0001.uint16
  EV_DELETE* = 0x0002.uint16
  EV_ENABLE* = 0x0004.uint16
  EV_DISABLE* = 0x0008.uint16
  EV_ONESHOT* = 0x0010.uint16
  EV_CLEAR* = 0x0020.uint16

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
    submissions*: IntrusiveQueue[Completion]
    deletions*: IntrusiveQueue[Completion]
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
    submissions: initIntrusiveQueue[Completion](),
    deletions: initIntrusiveQueue[Completion](),
    threadPool: cast[ptr ThreadPool](options.threadPool),
    stopped: false
  )
  return ok(res)

proc deinit*(self: var KqueueLoop) =
  if cint(self.kqFd) >= 0:
    discard close(cint(self.kqFd))

proc add*(self: var KqueueLoop, completion: ptr Completion) =
  completion.flags.state = 1
  self.submissions.push(completion)

proc delete*(self: var KqueueLoop, completion: ptr Completion) =
  completion.flags.state = 2
  self.deletions.push(completion)

proc stop*(self: var KqueueLoop) =
  self.stopped = true

proc tick*(self: var KqueueLoop, wait: uint32): XevResult[void] =
  if self.stopped: return ok()

  while not self.submissions.empty():
    let c = self.submissions.pop()
    if c == nil or c.flags.state != 1: continue

    var kev: KEvent
    kev.udata = c
    kev.flags = EV_ADD or EV_ENABLE or EV_ONESHOT

    case c.op.kind:
    of OperationKind.read, OperationKind.accept, OperationKind.recv:
      kev.ident = uint(c.op.readOp.fd)
      kev.filter = EVFILT_READ
    of OperationKind.write, OperationKind.connect, OperationKind.send:
      kev.ident = uint(c.op.writeOp.fd)
      kev.filter = EVFILT_WRITE
    else: discard

    discard kevent(cint(self.kqFd), addr kev, 1, nil, 0, nil)
    c.flags.state = 3
    self.active += 1

  while not self.deletions.empty():
    let c = self.deletions.pop()
    if c == nil or c.flags.state != 2: continue
    c.flags.state = 0
    if self.active > 0: self.active -= 1

  var events: array[64, KEvent]
  var ts = Timespec(tv_sec: 0, tv_nsec: if wait == 0: 0 else: 100_000_000)
  let n = kevent(cint(self.kqFd), nil, 0, addr events[0], 64, addr ts)

  if n > 0:
    for i in 0 ..< n:
      let c = cast[ptr Completion](events[i].udata)
      if c != nil and c.callback != nil:
        c.flags.state = 0
        if self.active > 0: self.active -= 1
        let action = c.callback(c.userdata, nil, c, c.op.kind, nil)
        if action == CallbackAction.rearm:
          self.add(c)

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
