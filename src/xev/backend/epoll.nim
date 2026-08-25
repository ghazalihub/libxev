## Epoll Backend implementation for Linux in Nim.

import ../[types, errors, loop, heap, queue, queue_mpsc, threadpool]
import std/posix

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
  var res = EpollLoop(
    fd: Fd(-1),
    eventFd: Fd(-1),
    threadPool: cast[ptr ThreadPool](options.threadPool)
  )
  initIntrusiveMpscQueue(res.threadPoolCompletions)
  res.submissions = initIntrusiveQueue[Completion]()
  res.deletions = initIntrusiveQueue[Completion]()
  res.timers = initIntrusiveHeap[TimerObj]()
  return ok(res)

proc deinit*(self: var EpollLoop) =
  discard

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

proc run*(self: var EpollLoop, mode: RunMode): XevResult[void] =
  self.updateNow()
  return ok()
