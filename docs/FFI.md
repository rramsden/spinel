# Spinel FFI

Call C functions from Spinel Ruby programs. No extension compiler,
no `require "ffi"`: declarations go straight into the source and the
AOT compiler generates direct C call sites with the right externs and
linker flags.

## Example

```ruby
module LibC
  ffi_func :strlen, [:str], :size_t
  ffi_func :getpid, [],     :int
end

puts LibC.strlen("hello, world")   # 12
puts LibC.getpid
```

Compile and run:

```sh
./spinel prog.rb && ./prog
```

libc and libm are always linked; anything else needs `ffi_lib`.

## DSL reference

All FFI declarations go inside a `module` body. The module name becomes
the namespace for the functions (`SDL.SDL_Init`, `LibC.strlen`, …).

### `ffi_lib "name"`

Declares that this module needs `-lname` on the link command line. May
appear multiple times per module.

```ruby
module SDL
  ffi_lib "SDL2"
  ffi_lib "SDL2_image"   # if you need both
end
```

### `ffi_cflags "..."`

Declares cflags (include dirs, defines) needed for this module's
externs. Rarely needed — externs use standard C types only, so headers
don't have to be included in the generated code — but useful when a
library's headers define macros the C compiler expects.

```ruby
ffi_cflags "-I/usr/include/SDL2"
ffi_cflags "-D_REENTRANT"
```

### `ffi_func :name, [arg_types], ret_type`

Declares a C function callable as `Module.name(...)`.

```ruby
ffi_func :SDL_Init,         [:uint32],                                  :int
ffi_func :SDL_CreateWindow, [:str, :int, :int, :int, :int, :uint32],    :ptr
ffi_func :SDL_Quit,         [],                                         :void
```

Recognized type specs:

| spec | C type | Spinel type |
|---|---|---|
| `:int` | `int` | `int` |
| `:uint32` | `uint32_t` | `int` |
| `:int32` | `int32_t` | `int` |
| `:uint16` | `uint16_t` | `int` |
| `:int16` | `int16_t` | `int` |
| `:uint8` | `uint8_t` | `int` |
| `:int8` | `int8_t` | `int` |
| `:size_t` | `size_t` | `int` |
| `:long` | `long` | `int` |
| `:float` | `float` | `float` |
| `:double` | `double` | `float` |
| `:bool` | `int` | `bool` |
| `:str` | `const char *` | `string` |
| `:ptr` | `void *` | `ptr` |
| `:void` | `void` | `void` (return only) |

All integer types collapse to `mrb_int` (int64) inside Spinel and cast
to the declared C type at the call boundary. Floats collapse to `double`
the same way.

### `ffi_const :NAME, <int>`

Declares an integer constant accessible as `Module::NAME`. Pure
convenience — the value is inlined at use sites like any other Ruby
integer constant.

```ruby
ffi_const :INIT_VIDEO,          0x20
ffi_const :WINDOWPOS_CENTERED,  0x2fff0000
```

### `ffi_buffer :name, <size>`

Declares a static `size`-byte buffer, accessible as `Module.name`
returning a `:ptr`. Useful as scratch space or as an out-parameter for
functions like `SDL_PollEvent` that write into a caller-supplied struct.

```ruby
ffi_buffer :event_buf, 64
buf = SDL.event_buf           # void *
SDL.SDL_PollEvent(buf)
```

Lifetime: static. The buffer lives for the whole program.

### `ffi_read_u32 :name, <offset>` / `ffi_read_i32` / `ffi_read_ptr`

Declares a field reader: `Module.name(buf)` returns the value at
`offset` bytes into `buf`. Handy for poking into C structs when you
only need a few fields.

```ruby
# SDL_Event union: first 4 bytes are the type.
ffi_read_u32 :event_type, 0
# SDL_KeyboardEvent.keysym.sym is at offset 20.
ffi_read_u32 :event_key_sym, 20
```

No `ffi_write_*` yet — the MVP only reads struct fields, on the
assumption that C code is the one writing them.

## Pointer semantics

`:ptr` maps to C `void *`. Values of this type are **not GC-tracked**:
the Spinel garbage collector never follows them and never frees them.
Foreign memory is the user's responsibility.

Two consequences worth knowing:

1. **Call destroy functions explicitly.** Nothing calls `SDL_Quit` or
   `free()` for you.
2. **Strings passed into C are only valid for the duration of the
   call.** Spinel strings are GC-managed; if a C function stashes the
   pointer somewhere and the string becomes unreachable afterward, a
   later GC cycle will free it out from under the C code. If you need
   a string to outlive the call, copy it into an `ffi_buffer` first.

`ptr` values compare equal to `nil` when the pointer is NULL:

```ruby
win = SDL.SDL_CreateWindow(...)
if win == nil
  puts SDL.SDL_GetError
end
```

## Link-flag plumbing

The codegen emits marker comments into the generated C:

```c
/* SPINEL_LINK: -lSDL2 */
/* SPINEL_CFLAGS: -I/usr/include/SDL2 */
```

The `spinel` wrapper script scrapes these with `sed` and appends them
to the `cc` invocation. If you want to override (e.g. static linking,
custom lib path), use `-c` to stop at C and drive the linker yourself.

## Limitations

The MVP covers scalars, strings, opaque pointers, integer constants,
raw byte buffers, and simple struct-field reads. Not supported yet:

- **No struct declarations.** Use `ffi_buffer` + `ffi_read_*` for
  the handful of fields you need.
- **No callbacks / Ruby-to-C function pointers.**
- **No variadic C functions** (`printf(...)`). Use Spinel's built-in
  `printf` if you want formatted output.
- **No `ffi_write_*`** — can't write struct fields from Ruby. Pass a
  buffer to a C function that writes it for you.
- **Pointers can't enter polymorphic values.** Don't put a `:ptr` into
  a `poly_array` or a generic `Hash`; keep them as plain locals or
  wrap them in a class with a `ptr`-typed ivar.

## WSL2 / WSLg note

SDL2 programs built this way render to the Windows desktop via WSLg
automatically — no `DISPLAY` / `WAYLAND_DISPLAY` setup needed. If the
SDL Wayland backend misbehaves, force X11:

```sh
SDL_VIDEODRIVER=x11 ./hello
```

For runnable examples see `examples/sdl/`:

  - `hello_raw.rb`  — hello window via raw SDL FFI calls
  - `hello.rb`      — hello window via the SdlApp DSL wrapper
  - `shapes.rb`     — interactive drawing (arrow keys, R/G/B)
  - `music.rb`      — synthetic audio + oscilloscope visualization

All use the shared `examples/sdl2.rb` library.
