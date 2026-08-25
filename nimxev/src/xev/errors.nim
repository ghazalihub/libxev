## Universal Error & Result Architecture for libxev in Nim.

type
  XevErrorKind* = enum
    errNone = 0
    errUnexpected
    errThreadPoolRequired
    errThreadPoolUnsupported
    errNotFound
    errDupFailed
    errUnknown
    errEOF
    errProcessFdQuotaExceeded
    errSystemFdQuotaExceeded
    errSystemResources
    errUserResourceLimitReached
    errFileDescriptorAlreadyPresentInSet
    errOperationCausesCircularLoop
    errFileDescriptorNotRegistered
    errFileDescriptorIncompatibleWithEpoll
    errSocketNotConnected
    errConnectionAborted
    errConnectionResetByPeer
    errBlockingOperationInProgress
    errNetworkSubsystemFailed
    errWouldBlock
    errCanceled

  AcceptError* = XevErrorKind
  CancelError* = XevErrorKind
  CloseError* = XevErrorKind
  ConnectError* = XevErrorKind
  ShutdownError* = XevErrorKind
  WriteError* = XevErrorKind
  ReadError* = XevErrorKind
  PollError* = XevErrorKind
  TimerError* = XevErrorKind

  XevResult*[T] = object
    when T is void:
      case isOk*: bool
      of true:
        discard
      of false:
        error*: XevErrorKind
    else:
      case isOk*: bool
      of true:
        value*: T
      of false:
        error*: XevErrorKind

proc ok*[T](val: T): XevResult[T] {.inline.} =
  XevResult[T](isOk: true, value: val)

proc ok*(): XevResult[void] {.inline.} =
  XevResult[void](isOk: true)

proc err*[T](e: XevErrorKind): XevResult[T] {.inline.} =
  when T is void:
    XevResult[void](isOk: false, error: e)
  else:
    XevResult[T](isOk: false, error: e)
