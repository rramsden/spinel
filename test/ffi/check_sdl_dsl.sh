#!/bin/sh
# SDL2 DSL smoke check.
#
# Compiles examples/ffi/sdl/hello.rb and examples/ffi/sdl/shapes.rb (both use
# the friendly SdlApp wrapper in examples/ffi/sdl/sdl2.rb) and verifies each
# links libSDL2 and reaches its main loop. Skipped if SDL2 isn't
# installed.
#
# Usage: sh test/ffi/check_sdl_dsl.sh
# Exit 0 on pass (or skip), non-zero on failure.

set -e
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR"

if ! pkg-config --exists sdl2 2>/dev/null; then
  echo "ffi sdl dsl check SKIPPED (SDL2 not installed)"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

check_one() {
  src=$1
  expected_startup=$2
  bin="$TMP/$(basename "$src" .rb)"
  ./spinel "$src" -o "$bin" >/dev/null 2>&1
  if ! ldd "$bin" | grep -q libSDL2; then
    echo "FAIL: $src did not link libSDL2"
    exit 1
  fi
  out=$(timeout 2 "$bin" 2>&1 || true)
  if ! echo "$out" | grep -q "$expected_startup"; then
    echo "FAIL: $src did not print expected startup line"
    echo "  expected: $expected_startup"
    echo "  output:   $out"
    exit 1
  fi
}

check_one examples/ffi/sdl/hello.rb  "Window open"
check_one examples/ffi/sdl/shapes.rb "Arrow keys"

echo "ffi sdl dsl check OK (hello + shapes)"
