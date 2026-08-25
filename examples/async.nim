## Ported async watcher example in Nim using nimxev.

import nimxev

proc timerCallback(userdata: pointer, loop: ptr DefaultLoop, completion: ptr Completion, resultKind: OperationKind, resVal: pointer): CallbackAction =
  let asyncPtr = cast[ptr AsyncWatcher](userdata)
  discard asyncPtr[].notify()
  return CallbackAction.disarm

proc asyncCallback(userdata: pointer, loop: ptr DefaultLoop, completion: ptr Completion, resultKind: OperationKind, resVal: pointer): CallbackAction =
  let notified = cast[ptr bool](userdata)
  notified[] = true
  return CallbackAction.disarm

proc main() =
  var loopRes = initEpollLoop(initOptions())
  if not loopRes.isOk:
    echo "xev_loop_init failure"
    return

  var loop = loopRes.value
  defer loop.deinit()

  var asyncWatcher = initAsyncWatcher().value
  defer asyncWatcher.deinit()

  var notified = false
  var asyncC: Completion
  asyncWatcher.wait(addr loop, addr asyncC, addr notified, cast[pointer](asyncCallback))

  var timerWatcher = initTimerWatcher().value
  defer timerWatcher.deinit()

  var timerC: Completion
  timerWatcher.run(addr loop, addr timerC, 1, addr asyncWatcher, cast[pointer](timerCallback))

  discard loop.run(RunMode.untilDone)

  if not notified:
    echo "FAIL! async should have been notified!"
  else:
    echo "Async notification received successfully!"

main()
