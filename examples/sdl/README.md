# SDL2 examples

Four demos on top of the shared library in [`../sdl2.rb`](../sdl2.rb).
They're ordered from simplest to most involved — start at the top
if you're learning the layer.

| file | what it shows | raw FFI? | DSL? | audio? |
|---|---|---|---|---|
| [`hello_raw.rb`](hello_raw.rb) | window + RGB pulse, **raw FFI only**                | yes | no  | no  |
| [`hello.rb`](hello.rb)         | same thing via the `SdlApp` DSL — same behavior, ~1/3 the code | no  | yes | no  |
| [`shapes.rb`](shapes.rb)       | interactive drawing: arrow keys move a square, R/G/B re-color, Space cycles background | no  | yes | no  |
| [`music.rb`](music.rb)         | synthesizes a 4-note arpeggio as PCM, plays it via SDL audio, renders the waveform in sync | no  | yes | yes |

## Build and run

All examples compile the same way:

```sh
./spinel examples/sdl/hello.rb     # compiles to ./hello
./hello
```

No extra flags needed — the `ffi_lib "SDL2"` + `ffi_cflags` directives
in `sdl2.rb` flow through the Spinel codegen into the cc invocation.

## Prerequisites

SDL2 development headers:

```sh
sudo apt install -y libsdl2-dev
```

On WSL2 with WSLg (default on recent Windows 11/10), windows render
to your Windows desktop with no environment setup. See
[`../../docs/FFI.md`](../../docs/FFI.md) for the full FFI reference
and WSL2/WSLg notes.

## Where the plumbing lives

- [`../sdl2.rb`](../sdl2.rb)  — raw FFI declarations (`module SDL`),
  the `SdlApp` class, color helpers, keycode mapping. All examples
  here just `require_relative "../sdl2"`.
- [`../../docs/FFI.md`](../../docs/FFI.md) — full FFI DSL reference,
  type-spec table, ownership rules, WSL2 notes.
