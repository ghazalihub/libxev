## Core Type Mapping & OS Handle Representations for libxev in Nim.
## Designed for zero-allocation and high performance (`--mm:arc`).

type
  Fd* = distinct cint
  SockFd* = distinct cint
  Signal* = distinct cint

proc `==`*(a, b: Fd): bool {.borrow.}
proc `==`*(a, b: SockFd): bool {.borrow.}
proc `==`*(a, b: Signal): bool {.borrow.}

type
  ByteSlice* = object
    `ptr`*: ptr byte
    len*: int

  ConstByteSlice* = object
    `ptr`*: ptr byte
    len*: int

  ReadBufferKind* = enum
    rbSlice
    rbArray

  ReadBuffer* = object
    case kind*: ReadBufferKind
    of rbSlice:
      slice*: ByteSlice
    of rbArray:
      arr*: array[32, byte]

  WriteBufferKind* = enum
    wbSlice
    wbArray

  WriteBuffer* = object
    case kind*: WriteBufferKind
    of wbSlice:
      slice*: ConstByteSlice
    of wbArray:
      arr*: array[32, byte]
      len*: int

proc initReadBuffer*(bytes: ptr byte, len: int): ReadBuffer {.inline.} =
  ReadBuffer(kind: rbSlice, slice: ByteSlice(`ptr`: bytes, len: len))

proc initReadBufferArray*(): ReadBuffer {.inline.} =
  ReadBuffer(kind: rbArray)

proc initWriteBuffer*(bytes: ptr byte, len: int): WriteBuffer {.inline.} =
  WriteBuffer(kind: wbSlice, slice: ConstByteSlice(`ptr`: bytes, len: len))

proc initWriteBufferArray*(data: openArray[byte]): WriteBuffer {.inline.} =
  var res = WriteBuffer(kind: wbArray, len: data.len)
  if data.len > 0:
    copyMem(addr res.arr[0], unsafeAddr data[0], min(data.len, 32))
  return res
