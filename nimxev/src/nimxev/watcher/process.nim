## Process Watcher Implementation for nimxev in Nim.

import ../[types, errors, loop]
import ../backend/epoll

type
  ProcessWatcher* = object
    pid*: cint

proc initProcessWatcher*(pid: cint = -1): XevResult[ProcessWatcher] =
  return ok(ProcessWatcher(pid: pid))

proc deinit*(self: var ProcessWatcher) =
  discard

proc wait*(self: ProcessWatcher, loop: pointer, c: ptr Completion, userdata: pointer, cb: CallbackProc) =
  let epollLoopPtr = cast[ptr EpollLoop](loop)
  c.op = Operation(kind: OperationKind.poll)
  c.op.pollOp = PollOp(fd: Fd(self.pid), events: 0)
  c.userdata = userdata
  c.callback = cb
  epollLoopPtr[].add(c)
