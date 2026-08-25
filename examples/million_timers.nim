## Million timers benchmark ported to Nim using nimxev.

import nimxev
import std/times

const NumTimers = 1_000_000

var timerCbCalled = 0

proc timerCallback(userdata: pointer, loop: ptr DefaultLoop, completion: ptr Completion, resultKind: OperationKind, resVal: pointer): CallbackAction =
  timerCbCalled += 1
  return CallbackAction.disarm

proc main() =
  var loopRes = initEpollLoop(initOptions())
  if not loopRes.isOk:
    echo "Loop init failure"
    return

  var loop = loopRes.value
  defer loop.deinit()

  var timers = newSeq[TimerWatcher](NumTimers)
  var completions = newSeq[Completion](NumTimers)

  let beforeAll = cpuTime()
  var timeout: uint64 = 1

  for i in 0 ..< NumTimers:
    if i mod 1000 == 0: timeout += 1
    timers[i] = initTimerWatcher().value
    timers[i].run(addr loop, addr completions[i], timeout, nil, cast[pointer](timerCallback))

  let beforeRun = cpuTime()
  discard loop.run(RunMode.untilDone)
  let afterRun = cpuTime()
  let afterAll = cpuTime()

  echo "Total time: ", (afterAll - beforeAll), "s"
  echo "Init time: ", (beforeRun - beforeAll), "s"
  echo "Dispatch time: ", (afterRun - beforeRun), "s"
  echo "Cleanup time: ", (afterAll - afterRun), "s"

main()
