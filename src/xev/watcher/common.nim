## Common Watcher Helpers for libxev in Nim.

proc userdataValue*[T](v: pointer): ptr T {.inline.} =
  when T is void:
    return nil
  else:
    return cast[ptr T](v)
