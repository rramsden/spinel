#!/bin/sh
# SDL2 raw-FFI smoke check.
#
# Compiles examples/sdl/hello_raw.rb (demonstrates the raw SDL module
# without the SdlApp DSL wrapper) and verifies:
#   1. Codegen succeeds.
#   2. cc succeeds with -lSDL2 on the command line.
#   3. The binary dynamically links libSDL2.
#   4. Launching the binary prints the "Window open" line before
#      being killed by the timeout (proves main loop entered).
#
# Skipped gracefully if SDL2 isn't installed.
#
# Usage: sh test/ffi/check_sdl_raw.sh
# Exit 0 on pass (or skip), non-zero on failure.

set -e
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR"

if ! pkg-config --exists sdl2 2>/dev/null; then
  echo "ffi sdl raw check SKIPPED (SDL2 not installed)"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

./spinel examples/sdl/hello_raw.rb -o "$TMP/hello_raw" >/dev/null 2>&1

if ! ldd "$TMP/hello_raw" | grep -q libSDL2; then
  echo "FAIL: libSDL2 not dynamically linked"
  exit 1
fi

# Run headless-ish: the program prints "Window open." and then enters
# an event loop until quit. If it starts cleanly, we kill it after
# 2 seconds and check for the expected startup line.
out=$(timeout 2 "$TMP/hello_raw" 2>&1 || true)
if ! echo "$out" | grep -q "Window open"; then
  echo "FAIL: hello_raw did not reach main loop"
  echo "Output was:"
  echo "$out"
  exit 1
fi

echo "ffi sdl raw check OK (hello_raw links -lSDL2 and enters main loop)"
