## Threadpool example ported to Nim using nimxev.

import nimxev

type
  Job = object
    task: Task
    done: bool

proc taskCallback(t: ptr Task) =
  let jobPtr = cast[ptr Job](t)
  jobPtr.done = true

proc main() =
  var pool = initThreadPool(initThreadPoolConfig())
  pool.start()

  const TaskCount = 128
  var jobs: array[TaskCount, Job]
  var batch: Batch

  for i in 0 ..< TaskCount:
    jobs[i].done = false
    jobs[i].task.callback = taskCallback
    let singleBatch = initBatch(addr jobs[i].task)
    batch.push(singleBatch)

  schedule(addr pool, batch)

  while true:
    var allDone = true
    for i in 0 ..< TaskCount:
      if not jobs[i].done:
        allDone = false
        break
    if allDone: break

  shutdown(addr pool)
  echo TaskCount, " tasks completed successfully!"

main()
