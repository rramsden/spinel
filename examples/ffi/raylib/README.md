# Raylib bindings for Spinel

A friendly Spinel FFI wrapper around [raylib](https://www.raylib.com/).
Mirrors the layout of `examples/ffi/sdl/` — raw `RAY` module on the
bottom, `RaylibApp` / `RaylibFont` classes on top.

## Files

- `raylib.rb` — Spinel FFI declarations + `RaylibApp` / `RaylibFont`.
- `raylib_helper.c` — Tiny C shim for the parts of raylib's API that
  pass structs by value (Vector2, Font, Color tints). Spinel's FFI
  only handles scalars and opaque pointers; the shim turns those into
  packed-uint32 / heap-boxed-pointer ABIs Spinel can call directly.
- `hello.rb` — Smoke test: opens a window, prints "Hello, raylib!".

## Building the shim

The shim has to exist before any Spinel program that uses these
bindings will link. Build it once and install alongside libraylib:

```sh
cc -O2 -fPIC -shared -I<raylib-include> raylib_helper.c \
   -L<raylib-lib> -Wl,-rpath,<raylib-lib> \
   -lraylib -o <raylib-lib>/libraylibhelper.so
```

If raylib lives in `~/.local`:

```sh
cc -O2 -fPIC -shared -I$HOME/.local/include raylib_helper.c \
   -L$HOME/.local/lib -Wl,-rpath,$HOME/.local/lib \
   -lraylib -o $HOME/.local/lib/libraylibhelper.so
```

## Building hello.rb

```sh
LIBRARY_PATH=$HOME/.local/lib CPATH=$HOME/.local/include \
  ./spinel examples/ffi/raylib/hello.rb -o hello
LD_LIBRARY_PATH=$HOME/.local/lib ./hello
```

(Or bake an rpath via `module RAY; ffi_cflags "-Wl,-rpath,..."; end`
in a sibling file you `require_relative` first — the Living Grimoire
project's Makefile does exactly that.)

## ABI notes

- **Color** (`{u8 r, g, b, a}`) is integer class and ≤ 8 bytes, so it
  rides a single integer register on SysV x86-64. We pack RGBA into a
  uint32 (byte 0=R, 1=G, 2=B, 3=A) and pass it by value. `DrawText`
  and `ClearBackground` could take this directly; we route through the
  shim anyway so the public API is uniform.
- **Vector2** (`{float x, y}`) is SSE class — passed in xmm registers,
  not integer — so the same packing trick doesn't work. Anything that
  takes/returns Vector2 (`DrawTextEx`, `MeasureTextEx`) goes through
  the shim.
- **Font** is 48 bytes, returned via a hidden pointer arg in the SysV
  ABI. The shim heap-boxes it and hands back an opaque pointer.
- **`_Bool` returns** (`IsKeyPressed` etc.) are tricky: the callee
  only writes the low byte of `eax` and the upper bits are
  implementation-defined. Spinel's `:bool` extern declares an `int`
  return, which can read garbage in the upper bytes. The shim wraps
  these with `... ? 1 : 0` so the Spinel side always sees 0 or 1.
