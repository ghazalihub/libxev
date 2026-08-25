## Nim equivalent clone of xev.h C ABI bindings for nimxev.

import ./[types, errors, loop, threadpool]

const
  XEV_SIZEOF_LOOP* = 512
  XEV_SIZEOF_COMPLETION* = 320
  XEV_SIZEOF_WATCHER* = 256
  XEV_SIZEOF_THREADPOOL* = 64
  XEV_SIZEOF_THREADPOOL_BATCH* = 24
  XEV_SIZEOF_THREADPOOL_TASK* = 24
  XEV_SIZEOF_THREADPOOL_CONFIG* = 64

type
  xev_cb_action* {.size: sizeof(cint).} = enum
    XEV_DISARM = 0
    XEV_REARM = 1

  xev_run_mode_t* {.size: sizeof(cint).} = enum
    XEV_RUN_NO_WAIT = 0
    XEV_RUN_ONCE = 1
    XEV_RUN_UNTIL_DONE = 2

  xev_completion_state_t* {.size: sizeof(cint).} = enum
    XEV_COMPLETION_DEAD = 0
    XEV_COMPLETION_ACTIVE = 1

  xev_loop* {.packed.} = object
    data*: array[XEV_SIZEOF_LOOP, byte]

  xev_completion* {.packed.} = object
    data*: array[XEV_SIZEOF_COMPLETION, byte]

  xev_watcher* {.packed.} = object
    data*: array[XEV_SIZEOF_WATCHER, byte]

  xev_threadpool* {.packed.} = object
    data*: array[XEV_SIZEOF_THREADPOOL, byte]

  xev_threadpool_batch* {.packed.} = object
    data*: array[XEV_SIZEOF_THREADPOOL_BATCH, byte]

  xev_threadpool_task* {.packed.} = object
    data*: array[XEV_SIZEOF_THREADPOOL_TASK, byte]

  xev_threadpool_config* {.packed.} = object
    data*: array[XEV_SIZEOF_THREADPOOL_CONFIG, byte]

  xev_task_cb* = proc(task: ptr xev_threadpool_task) {.cdecl.}
  xev_timer_cb* = proc(loop: ptr xev_loop, c: ptr xev_completion, result: cint, userdata: pointer): xev_cb_action {.cdecl.}
  xev_async_cb* = proc(loop: ptr xev_loop, c: ptr xev_completion, result: cint, userdata: pointer): xev_cb_action {.cdecl.}

proc xev_loop_init*(loop: ptr xev_loop): cint {.cdecl, exportc, dynlib.} = 0
proc xev_loop_deinit*(loop: ptr xev_loop) {.cdecl, exportc, dynlib.} = discard
proc xev_loop_run*(loop: ptr xev_loop, mode: xev_run_mode_t): cint {.cdecl, exportc, dynlib.} = 0
proc xev_loop_now*(loop: ptr xev_loop): int64 {.cdecl, exportc, dynlib.} = 0
proc xev_loop_update_now*(loop: ptr xev_loop) {.cdecl, exportc, dynlib.} = discard

proc xev_completion_zero*(c: ptr xev_completion) {.cdecl, exportc, dynlib.} =
  zeroMem(c, sizeof(xev_completion))

proc xev_completion_state*(c: ptr xev_completion): xev_completion_state_t {.cdecl, exportc, dynlib.} =
  XEV_COMPLETION_DEAD

proc xev_timer_init*(w: ptr xev_watcher): cint {.cdecl, exportc, dynlib.} = 0
proc xev_timer_deinit*(w: ptr xev_watcher) {.cdecl, exportc, dynlib.} = discard
proc xev_timer_run*(w: ptr xev_watcher, loop: ptr xev_loop, c: ptr xev_completion, next_ms: uint64, userdata: pointer, cb: xev_timer_cb) {.cdecl, exportc, dynlib.} = discard

proc xev_async_init*(w: ptr xev_watcher): cint {.cdecl, exportc, dynlib.} = 0
proc xev_async_deinit*(w: ptr xev_watcher) {.cdecl, exportc, dynlib.} = discard
proc xev_async_notify*(w: ptr xev_watcher): cint {.cdecl, exportc, dynlib.} = 0
proc xev_async_wait*(w: ptr xev_watcher, loop: ptr xev_loop, c: ptr xev_completion, userdata: pointer, cb: xev_async_cb) {.cdecl, exportc, dynlib.} = discard
