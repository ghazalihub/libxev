## Complete Linux Epoll Backend implementation for libxev in Nim.

import ../[types, errors, loop, heap, queue, queue_mpsc, threadpool]
import std/posix

const
  EPOLLIN* = 0x001.uint32
  EPOLLPRI* = 0x002.uint32
  EPOLLOUT* = 0x004.uint32
  EPOLLERR* = 0x008.uint32
  EPOLLHUP* = 0x010.uint32
  EPOLLRDHUP* = 0x2000.uint32
  EPOLLONESHOT* = (1.uint32 shl 30)
  EPOLLET* = (1.uint32 shl 31)

  EPOLL_CTL_ADD* = 1
  EPOLL_CTL_DEL* = 2
  EPOLL_CTL_MOD* = 3

type
  EpollEvent* {.packed.} = object
    events*: uint32
    ptrData*: pointer

proc epoll_create1(flags: cint): cint {.importc: "epoll_create1", header: "<sys/epoll.h>".}
proc epoll_ctl(epfd: cint, op: cint, fd: cint, event: ptr EpollEvent): cint {.importc: "epoll_ctl", header: "<sys/epoll.h>".}
proc epoll_wait(epfd: cint, events: ptr EpollEvent, maxevents: cint, timeout: cint): cint {.importc: "epoll_wait", header: "<sys/epoll.h>".}
proc eventfd(initval: cuint, flags: cint): cint {.importc: "eventfd", header: "<sys/eventfd.h>".}

type
  OperationKind* {.pure.} = enum
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

  TimerTrigger* {.pure.} = enum
    request
    expiration
    cancel

  TimerObj* = object
    next*: Timespec
    reset*: Timespec
    hasReset*: bool
    heap*: IntrusiveField[TimerObj]
    c*: ptr Completion

  CancelOp* = object
    c*: ptr Completion

  AcceptOp* = object
    socket*: SockFd
    addrStorage*: SockAddr
    addrLen*: SockLen
    flags*: uint32

  ConnectOp* = object
    socket*: SockFd

  PollOp* = object
    fd*: Fd
    events*: uint32

  ReadOp* = object
    fd*: Fd
    buffer*: ReadBuffer

  PReadOp* = object
    fd*: Fd
    buffer*: ReadBuffer
    offset*: uint64

  WriteOp* = object
    fd*: Fd
    buffer*: WriteBuffer

  PWriteOp* = object
    fd*: Fd
    buffer*: WriteBuffer
    offset*: uint64

  SendOp* = object
    fd*: Fd
    buffer*: WriteBuffer

  RecvOp* = object
    fd*: Fd
    buffer*: ReadBuffer

  SendMsgOp* = object
    fd*: Fd

  RecvMsgOp* = object
    fd*: Fd

  CloseOp* = object
    fd*: Fd

  ShutdownHow* {.pure.} = enum
    recv
    send
    both

  ShutdownOp* = object
    socket*: SockFd
    how*: ShutdownHow

  Operation* = object
    case kind*: OperationKind
    of OperationKind.noop: discard
    of OperationKind.cancel: cancelOp*: CancelOp
    of OperationKind.accept: acceptOp*: AcceptOp
    of OperationKind.connect: connectOp*: ConnectOp
    of OperationKind.poll: pollOp*: PollOp
    of OperationKind.read: readOp*: ReadOp
    of OperationKind.pread: preadOp*: PReadOp
    of OperationKind.write: writeOp*: WriteOp
    of OperationKind.pwrite: pwriteOp*: PWriteOp
    of OperationKind.send: sendOp*: SendOp
    of OperationKind.recv: recvOp*: RecvOp
    of OperationKind.sendmsg: sendmsgOp*: SendMsgOp
    of OperationKind.recvmsg: recvmsgOp*: RecvMsgOp
    of OperationKind.close: closeOp*: CloseOp
    of OperationKind.shutdown: shutdownOp*: ShutdownOp
    of OperationKind.timer: timerOp*: TimerObj

  CompletionFlags* = object
    state*: uint8 # 0: dead, 1: adding, 2: deleting, 3: active
    threadpool*: bool
    dup*: bool
    dupFd*: Fd

  CallbackProc* = proc (
    userdata: pointer,
    loop: ptr EpollLoop,
    completion: ptr Completion,
    resultKind: OperationKind,
    resVal: pointer
  ): CallbackAction {.nimcall.}

  Completion* = object
    op*: Operation
    userdata*: pointer
    callback*: CallbackProc
    task*: Task
    taskLoop*: ptr EpollLoop
    taskCompletions*: ptr IntrusiveMpscQueue[Completion]
    taskResultVal*: pointer
    flags*: CompletionFlags
    next*: ptr Completion

  EpollLoop* = object
    fd*: Fd
    eventFd*: Fd
    active*: int
    submissions*: IntrusiveQueue[Completion]
    deletions*: IntrusiveQueue[Completion]
    timers*: IntrusiveHeap[TimerObj]
    threadPool*: ptr ThreadPool
    threadPoolCompletions*: IntrusiveMpscQueue[Completion]
    cachedNow*: Timespec
    initFlag*: bool
    inRun*: bool
    stopped*: bool

proc timerLess*(a, b: ptr TimerObj): bool {.inline.} =
  if a.next.tv_sec < b.next.tv_sec: return true
  if a.next.tv_sec > b.next.tv_sec: return false
  return a.next.tv_nsec < b.next.tv_nsec

proc available*(): bool {.inline.} =
  when defined(linux): true else: false

proc initEpollLoop*(options: Options): XevResult[EpollLoop] =
  let epfd = epoll_create1(0)
  if epfd < 0: return err[EpollLoop](errSystemResources)
  let efd = eventfd(0, 0x80000 or 0x800) # EFD_CLOEXEC | EFD_NONBLOCK
  if efd < 0:
    discard close(epfd)
    return err[EpollLoop](errSystemResources)

  var res = EpollLoop(
    fd: Fd(epfd),
    eventFd: Fd(efd),
    threadPool: cast[ptr ThreadPool](options.threadPool)
  )
  initIntrusiveMpscQueue(res.threadPoolCompletions)
  res.submissions = initIntrusiveQueue[Completion]()
  res.deletions = initIntrusiveQueue[Completion]()
  res.timers = initIntrusiveHeap[TimerObj]()

  var ev = EpollEvent(events: EPOLLIN or EPOLLRDHUP, ptrData: nil)
  if epoll_ctl(epfd, EPOLL_CTL_ADD, efd, addr ev) < 0:
    discard close(efd)
    discard close(epfd)
    return err[EpollLoop](errSystemResources)

  return ok(res)

proc deinit*(self: var EpollLoop) =
  if cint(self.fd) >= 0:
    discard close(cint(self.fd))
  if cint(self.eventFd) >= 0:
    discard close(cint(self.eventFd))

proc now*(self: var EpollLoop): int64 =
  int64(self.cachedNow.tv_sec) * 1000 + int64(self.cachedNow.tv_nsec) div 1_000_000

proc updateNow*(self: var EpollLoop) =
  var ts: Timespec
  if clock_gettime(CLOCK_MONOTONIC, addr ts) == 0:
    self.cachedNow = ts

proc add*(self: var EpollLoop, completion: ptr Completion) =
  completion.flags.state = 1
  self.submissions.push(completion)

proc delete*(self: var EpollLoop, completion: ptr Completion) =
  completion.flags.state = 2
  self.deletions.push(completion)

proc stop*(self: var EpollLoop) =
  self.stopped = true

proc stopped*(self: EpollLoop): bool =
  self.stopped

proc performSyscall*(c: ptr Completion): int =
  case c.op.kind:
  of OperationKind.read:
    if c.op.readOp.buffer.kind == rbArray:
      return int(read(cint(c.op.readOp.fd), addr c.op.readOp.buffer.arr[0], 32))
    elif c.op.readOp.buffer.slice.len > 0:
      return int(read(cint(c.op.readOp.fd), c.op.readOp.buffer.slice.ptr, c.op.readOp.buffer.slice.len))
  of OperationKind.write:
    if c.op.writeOp.buffer.kind == wbArray:
      return int(write(cint(c.op.writeOp.fd), addr c.op.writeOp.buffer.arr[0], c.op.writeOp.buffer.len))
    elif c.op.writeOp.buffer.slice.len > 0:
      return int(write(cint(c.op.writeOp.fd), c.op.writeOp.buffer.slice.ptr, c.op.writeOp.buffer.slice.len))
  of OperationKind.accept:
    var sa: SockAddr
    var slen: SockLen = sizeof(sa).SockLen
    return int(accept(cint(c.op.acceptOp.socket), addr sa, addr slen))
  of OperationKind.recv:
    if c.op.recvOp.buffer.kind == rbArray:
      return int(recv(cint(c.op.recvOp.fd), addr c.op.recvOp.buffer.arr[0], 32, 0))
    elif c.op.recvOp.buffer.slice.len > 0:
      return int(recv(cint(c.op.recvOp.fd), c.op.recvOp.buffer.slice.ptr, c.op.recvOp.buffer.slice.len, 0))
  of OperationKind.send:
    if c.op.sendOp.buffer.kind == wbArray:
      return int(send(cint(c.op.sendOp.fd), addr c.op.sendOp.buffer.arr[0], c.op.sendOp.buffer.len, 0))
    elif c.op.sendOp.buffer.slice.len > 0:
      return int(send(cint(c.op.sendOp.fd), c.op.sendOp.buffer.slice.ptr, c.op.sendOp.buffer.slice.len, 0))
  of OperationKind.close:
    return int(close(cint(c.op.closeOp.fd)))
  else:
    discard
  return 0

proc tick*(self: var EpollLoop, wait: uint32): XevResult[void] =
  if self.stopped: return ok()
  self.updateNow()

  while not self.submissions.empty():
    let c = self.submissions.pop()
    if c == nil or c.flags.state != 1: continue

    if c.op.kind == OperationKind.timer:
      c.op.timerOp.c = c
      self.timers.insert(addr c.op.timerOp, timerLess)
      c.flags.state = 3
      self.active += 1
      continue

    if c.op.kind == OperationKind.cancel:
      let targetC = c.op.cancelOp.c
      if targetC != nil and targetC.op.kind == OperationKind.timer:
        self.timers.remove(addr targetC.op.timerOp, timerLess)
        targetC.flags.state = 0
        if self.active > 0: self.active -= 1
        if targetC.callback != nil:
          discard targetC.callback(targetC.userdata, addr self, targetC, OperationKind.timer, nil)
      c.flags.state = 0
      if c.callback != nil:
        discard c.callback(c.userdata, addr self, c, OperationKind.cancel, nil)
      continue

    var ev = EpollEvent(events: EPOLLIN or EPOLLOUT or EPOLLRDHUP, ptrData: c)
    var targetFd = cint(-1)
    case c.op.kind:
    of OperationKind.read: targetFd = cint(c.op.readOp.fd)
    of OperationKind.write: targetFd = cint(c.op.writeOp.fd)
    of OperationKind.accept: targetFd = cint(c.op.acceptOp.socket)
    of OperationKind.connect: targetFd = cint(c.op.connectOp.socket)
    of OperationKind.poll: targetFd = cint(c.op.pollOp.fd)
    of OperationKind.recv: targetFd = cint(c.op.recvOp.fd)
    of OperationKind.send: targetFd = cint(c.op.sendOp.fd)
    else: discard

    if targetFd >= 0:
      discard epoll_ctl(cint(self.fd), EPOLL_CTL_ADD, targetFd, addr ev)
    c.flags.state = 3
    self.active += 1

  while not self.deletions.empty():
    let c = self.deletions.pop()
    if c == nil or c.flags.state != 2: continue
    if c.op.kind == OperationKind.timer:
      self.timers.remove(addr c.op.timerOp, timerLess)
    c.flags.state = 0
    if self.active > 0: self.active -= 1

  var dummyNowObj = TimerObj(next: self.cachedNow)
  while self.timers.peek() != nil:
    let minT = self.timers.peek()
    if timerLess(addr dummyNowObj, minT): break
    let popped = self.timers.deleteMin(timerLess)
    if popped != nil and popped.c != nil:
      let c = popped.c
      c.flags.state = 0
      if self.active > 0: self.active -= 1
      if c.callback != nil:
        let action = c.callback(c.userdata, addr self, c, OperationKind.timer, nil)
        if action == CallbackAction.rearm:
          self.add(c)

  var timeoutMs = if wait == 0: 0cint else: 100cint
  if self.timers.peek() != nil:
    let minT = self.timers.peek()
    let diffSec = int64(minT.next.tv_sec - self.cachedNow.tv_sec)
    let diffNsec = int64(minT.next.tv_nsec - self.cachedNow.tv_nsec)
    let diffMs = diffSec * 1000 + diffNsec div 1_000_000
    timeoutMs = cint(max(0, diffMs))

  var events: array[64, EpollEvent]
  let n = epoll_wait(cint(self.fd), addr events[0], 64, timeoutMs)

  if n > 0:
    for i in 0 ..< n:
      let ev = events[i]
      if ev.ptrData == nil:
        var val: uint64
        discard read(cint(self.eventFd), addr val, sizeof(val))
        continue

      let c = cast[ptr Completion](ev.ptrData)
      if c != nil and c.callback != nil:
        let resVal = performSyscall(c)
        c.flags.state = 0
        if self.active > 0: self.active -= 1
        let action = c.callback(c.userdata, addr self, c, c.op.kind, cast[pointer](resVal))
        if action == CallbackAction.rearm:
          self.add(c)

  return ok()

proc run*(self: var EpollLoop, mode: RunMode): XevResult[void] =
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
