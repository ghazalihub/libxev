## WebAssembly WASI Poll Backend Implementation in Nim.

import ../[types, errors, loop]

type
  WasiPollLoop* = object
    active*: int

proc available*(): bool {.inline.} =
  when defined(wasm) or defined(wasi): true else: false

proc initWasiPollLoop*(options: Options): XevResult[WasiPollLoop] =
  return ok(WasiPollLoop(active: 0))

proc deinit*(self: var WasiPollLoop) =
  discard

proc run*(self: var WasiPollLoop, mode: RunMode): XevResult[void] =
  return ok()
