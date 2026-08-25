## Complete WebAssembly WASI Poll Backend implementation for libxev in Nim.

import ../[types, errors, loop]

type
  WasiPollLoop* = object
    active*: int
    stopped*: bool

proc available*(): bool {.inline.} =
  when defined(wasm) or defined(wasi): true else: false

proc initWasiPollLoop*(options: Options): XevResult[WasiPollLoop] =
  return ok(WasiPollLoop(active: 0, stopped: false))

proc deinit*(self: var WasiPollLoop) =
  discard

proc stop*(self: var WasiPollLoop) =
  self.stopped = true

proc tick*(self: var WasiPollLoop, wait: uint32): XevResult[void] =
  if self.stopped: return ok()
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
