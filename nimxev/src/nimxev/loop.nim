## Common Event Loop Abstractions for libxev in Nim.

import ./errors

type
  RunMode* {.pure.} = enum
    noWait = 0
    once = 1
    untilDone = 2

  CallbackAction* {.pure.} = enum
    disarm = 0
    rearm = 1

  CompletionState* {.pure.} = enum
    dead = 0
    active = 1

  Options* = object
    entries*: uint32
    threadPool*: pointer

proc initOptions*(entries: uint32 = 256, threadPool: pointer = nil): Options {.inline.} =
  Options(entries: entries, threadPool: threadPool)
