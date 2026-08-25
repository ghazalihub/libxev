## Ported basic timer example in Nim using nimxev.

import nimxev

proc timerCallback(userdata: pointer, loop: ptr EpollLoop, completion: ptr Completion, resultKind: OperationKind, resVal: pointer): CallbackAction =
  echo "Timer triggered!"
  return CallbackAction.disarm

proc main() =
  var loopRes = initEpollLoop(initOptions())
  if not loopRes.isOk:
    echo "xev_loop_init failure"
    return

  var loop = loopRes.value
  defer loop.deinit()

  var c: Completion
  var w = initTimerWatcher().value
  defer w.deinit()

  w.run(addr loop, addr c, 1, nil, timerCallback)
  discard loop.run(RunMode.untilDone)

main()
