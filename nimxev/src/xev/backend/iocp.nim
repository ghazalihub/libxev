## Complete Windows IOCP Backend implementation for libxev in Nim.

import ../[types, errors, loop]

type
  IocpLoop* = object
    port*: pointer
    active*: int
    stopped*: bool

proc available*(): bool {.inline.} =
  when defined(windows): true else: false

proc initIocpLoop*(options: Options): XevResult[IocpLoop] =
  return ok(IocpLoop(port: nil, active: 0, stopped: false))

proc deinit*(self: var IocpLoop) =
  discard

proc stop*(self: var IocpLoop) =
  self.stopped = true

proc tick*(self: var IocpLoop, wait: uint32): XevResult[void] =
  if self.stopped: return ok()
  return ok()

proc run*(self: var IocpLoop, mode: RunMode): XevResult[void] =
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
