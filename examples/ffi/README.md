# FFI examples

Programs that call into C libraries through Spinel's FFI.

| path | what it shows |
|---|---|
| [`libm.rb`](libm.rb) | `ffi_func` against libm and libc — cos, sqrt, pow, strlen. Smallest possible proof that FFI works; no external dependencies beyond what's always linked. |
| [`sdl/`](sdl/) | A full SDL2 playground: raw FFI vs. the `SdlApp` DSL wrapper, interactive drawing, and synthesized audio with oscilloscope visualization. Requires `libsdl2-dev`. See [`sdl/README.md`](sdl/README.md). |

## Build and run

```sh
./spinel examples/ffi/libm.rb && ./libm
```

See [`../../docs/FFI.md`](../../docs/FFI.md) for the full FFI DSL
reference (`ffi_lib`, `ffi_func`, `ffi_const`, `ffi_buffer`,
`ffi_read_*`, `ffi_write_*`, the `ptr` type, pointer ownership
rules, and WSL2/WSLg notes).
