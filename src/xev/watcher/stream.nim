## Generic Stream Watcher Abstractions for libxev in Nim.

import ../[types, errors, loop, queue]

type
  WriteRequest* = object
    buffer*: WriteBuffer
    cb*: pointer
    userdata*: pointer
    next*: ptr WriteRequest

  WriteQueue* = object
    queue*: IntrusiveQueue[WriteRequest]

proc initWriteQueue*(): WriteQueue {.inline.} =
  WriteQueue(queue: initIntrusiveQueue[WriteRequest]())

proc push*(self: var WriteQueue, req: ptr WriteRequest) {.inline.} =
  self.queue.push(req)

proc pop*(self: var WriteQueue): ptr WriteRequest {.inline.} =
  self.queue.pop()

proc empty*(self: WriteQueue): bool {.inline.} =
  self.queue.empty()
