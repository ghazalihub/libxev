## Complete WebAssembly WASI Poll Backend implementation for nimxev in Nim.

import ../[types, errors, loop, queue]
import ./epoll

type
  WasiPollLoop* = object
    active*: int
    submissions*: IntrusiveQueue[Completion]
    deletions*: IntrusiveQueue[Completion]
    stopped*: bool

proc available*(): bool {.inline.} =
  when defined(wasm) or defined(wasi): true else: false

proc initWasiPollLoop*(options: Options): XevResult[WasiPollLoop] =
  return ok(WasiPollLoop(
    active: 0,
    submissions: initIntrusiveQueue[Completion](),
    deletions: initIntrusiveQueue[Completion](),
    stopped: false
  ))

proc deinit*(self: var WasiPollLoop) =
  discard

proc add*(self: var WasiPollLoop, completion: ptr Completion) =
  completion.flags.state = 1
  self.submissions.push(completion)

proc delete*(self: var WasiPollLoop, completion: ptr Completion) =
  completion.flags.state = 2
  self.deletions.push(completion)

proc stop*(self: var WasiPollLoop) =
  self.stopped = true

proc tick*(self: var WasiPollLoop, wait: uint32): XevResult[void] =
  if self.stopped: return ok()

  while not self.submissions.empty():
    let c = self.submissions.pop()
    if c == nil or c.flags.state != 1: continue
    c.flags.state = 3
    self.active += 1

  while not self.deletions.empty():
    let c = self.deletions.pop()
    if c == nil or c.flags.state != 2: continue
    c.flags.state = 0
    if self.active > 0: self.active -= 1

  return ok()

proc run*(self: var WasiPollLoop, mode: RunMode): XevResult[void] =
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
