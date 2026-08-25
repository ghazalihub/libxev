## Lock-free Intrusive MPSC (Multi-Producer, Single-Consumer) Queue in Nim.

import std/atomics

type
  IntrusiveMpscQueue*[T] = object
    head*: ptr T
    tail*: ptr T
    stub*: T

proc initIntrusiveMpscQueue*[T](self: var IntrusiveMpscQueue[T]) =
  self.head = addr self.stub
  self.tail = addr self.stub
  self.stub.next = nil

proc push*[T](self: var IntrusiveMpscQueue[T], v: ptr T) =
  var nextPtr = addr v.next
  atomicStore(cast[ptr (ptr T)](nextPtr), nil, MemoryOrder.Unordered)
  let prev = atomicExchange(addr self.head, v, MemoryOrder.AcqRel)
  var prevNextPtr = addr prev.next
  atomicStore(cast[ptr (ptr T)](prevNextPtr), v, MemoryOrder.Release)

proc pop*[T](self: var IntrusiveMpscQueue[T]): ptr T =
  var tail = atomicLoad(addr self.tail, MemoryOrder.Unordered)
  var tailNextPtr = addr tail.next
  var nextNode = atomicLoad(cast[ptr (ptr T)](tailNextPtr), MemoryOrder.Acquire)

  if tail == addr self.stub:
    if nextNode == nil: return nil
    atomicStore(addr self.tail, nextNode, MemoryOrder.Unordered)
    tail = nextNode
    tailNextPtr = addr tail.next
    nextNode = atomicLoad(cast[ptr (ptr T)](tailNextPtr), MemoryOrder.Acquire)

  if nextNode != nil:
    atomicStore(addr self.tail, nextNode, MemoryOrder.Release)
    tail.next = nil
    return tail

  let head = atomicLoad(addr self.head, MemoryOrder.Unordered)
  if tail != head: return nil

  self.push(addr self.stub)

  tailNextPtr = addr tail.next
  nextNode = atomicLoad(cast[ptr (ptr T)](tailNextPtr), MemoryOrder.Acquire)
  if nextNode != nil:
    atomicStore(addr self.tail, nextNode, MemoryOrder.Unordered)
    tail.next = nil
    return tail

  return nil
