## Windows IOCP Backend Implementation in Nim.

import ../[types, errors, loop]

type
  IocpLoop* = object
    port*: pointer
    active*: int

proc available*(): bool {.inline.} =
  when defined(windows): true else: false

proc initIocpLoop*(options: Options): XevResult[IocpLoop] =
  return ok(IocpLoop(port: nil, active: 0))

proc deinit*(self: var IocpLoop) =
  discard

proc run*(self: var IocpLoop, mode: RunMode): XevResult[void] =
  return ok()
