## Intrusive Pairing Heap Data Structure in Nim.

type
  IntrusiveField*[T] = object
    child*: ptr T
    prev*: ptr T
    next*: ptr T

  IntrusiveHeap*[T] = object
    root*: ptr T

proc initIntrusiveHeap*[T](): IntrusiveHeap[T] {.inline.} =
  IntrusiveHeap[T](root: nil)

proc meld[T](self: var IntrusiveHeap[T], a, b: ptr T, less: proc(x, y: ptr T): bool {.closure.}): ptr T =
  assert(a.heap.next == nil)
  if less(a, b):
    b.heap.prev = a
    if b.heap.next != nil:
      a.heap.next = b.heap.next
      b.heap.next.heap.prev = a
      b.heap.next = nil
    if a.heap.child != nil:
      b.heap.next = a.heap.child
      a.heap.child.heap.prev = b
    a.heap.child = b
    return a

  b.heap.prev = a.heap.prev
  a.heap.prev = b
  if b.heap.child != nil:
    a.heap.next = b.heap.child
    b.heap.child.heap.prev = a
  b.heap.child = a
  return b

proc combineSiblings[T](self: var IntrusiveHeap[T], left: ptr T, less: proc(x, y: ptr T): bool {.closure.}): ptr T =
  left.heap.prev = nil
  var root: ptr T = nil
  var a = left
  while true:
    var b = a.heap.next
    if b == nil:
      root = a
      break
    a.heap.next = nil
    b = self.meld(a, b, less)
    a = b.heap.next
    if a == nil:
      root = b
      break

  while true:
    var b = root.heap.prev
    if b == nil: return root
    b.heap.next = nil
    root = self.meld(b, root, less)

proc insert*[T](self: var IntrusiveHeap[T], v: ptr T, less: proc(x, y: ptr T): bool {.closure.}) =
  if self.root == nil:
    self.root = v
  else:
    self.root = self.meld(v, self.root, less)

proc peek*[T](self: IntrusiveHeap[T]): ptr T {.inline.} =
  self.root

proc deleteMin*[T](self: var IntrusiveHeap[T], less: proc(x, y: ptr T): bool {.closure.}): ptr T =
  let root = self.root
  if root == nil: return nil
  if root.heap.child != nil:
    self.root = self.combineSiblings(root.heap.child, less)
  else:
    self.root = nil
  root.heap = IntrusiveField[T]()
  return root

proc remove*[T](self: var IntrusiveHeap[T], v: ptr T, less: proc(x, y: ptr T): bool {.closure.}) =
  let prev = v.heap.prev
  if prev == nil:
    assert(self.root == v)
    discard self.deleteMin(less)
    return

  if v.heap.next != nil:
    v.heap.next.heap.prev = prev
  if prev.heap.child == v:
    prev.heap.child = v.heap.next
  else:
    prev.heap.next = v.heap.next
  v.heap.prev = nil
  v.heap.next = nil

  let child = v.heap.child
  if child == nil: return
  v.heap.child = nil
  let x = self.combineSiblings(child, less)
  if self.root != nil:
    self.root = self.meld(x, self.root, less)
  else:
    self.root = x
