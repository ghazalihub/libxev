## Intrusive FIFO Queue Data Structure in Nim.

type
  IntrusiveQueue*[T] = object
    head*: ptr T
    tail*: ptr T

proc initIntrusiveQueue*[T](): IntrusiveQueue[T] {.inline.} =
  IntrusiveQueue[T](head: nil, tail: nil)

proc push*[T](self: var IntrusiveQueue[T], v: ptr T) {.inline.} =
  assert(v.next == nil)
  if self.tail != nil:
    self.tail.next = v
    self.tail = v
  else:
    self.head = v
    self.tail = v

proc pop*[T](self: var IntrusiveQueue[T]): ptr T {.inline.} =
  let nextNode = self.head
  if nextNode == nil: return nil
  if self.head == self.tail:
    self.tail = nil
  self.head = nextNode.next
  nextNode.next = nil
  return nextNode

proc empty*[T](self: IntrusiveQueue[T]): bool {.inline.} =
  self.head == nil
