xev-nim(7) "github.com/mitchellh/libxev" "Miscellaneous Information Manual"

# NAME

nimxev Nim API

# DESCRIPTION

See nimxev(7) for a general libxev/nimxev overview. This man page gives a
specific overview of the Nim API for nimxev.

nimxev is a high-performance Nim port of libxev. The Nim API takes advantage
of Nim idioms, ARC/ORC memory management (`--mm:arc`), distinct OS handles,
and zero-allocation event loop paths.

# INSTALLATION

Add `nimxev` to your `.nimble` file:

```nim
requires "nimxev >= 0.1.0"
```

Then import `nimxev` in your code:

```nim
import nimxev
```

# QUICK START

## INITIALIZING A LOOP

```nim
var loop = initEpollLoop(initOptions()).value
defer loop.deinit()
```

## ADDING A TIMER COMPLETION

```nim
var c: Completion
var w = initTimerWatcher().value
defer w.deinit()

w.run(addr loop, addr c, 5000, nil, cast[pointer](timerCallback))
discard loop.run(RunMode.untilDone)
```

# MEMORY MANAGEMENT

nimxev does not perform dynamic memory allocation inside the hot event loop
paths. Memory for completions and loops must remain at a stable address while active.

# SEE ALSO

nimxev(7)
