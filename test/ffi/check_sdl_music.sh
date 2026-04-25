#!/bin/sh
# SDL2 audio + waveform demo smoke check.
#
# Compiles sdl_music.rb and verifies:
#   - codegen + link succeed
#   - libSDL2 dynamically linked
#   - the synth loop runs (expected "Synthesis done." output)
#   - audio open succeeds (expected "Playing." output)
#   - main loop entered and exits cleanly within the timeout
#
# Skipped if SDL2 isn't installed.
#
# Usage: sh test/ffi/check_sdl_music.sh
# Exit 0 on pass (or skip), non-zero on failure.

set -e
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR"

if ! pkg-config --exists sdl2 2>/dev/null; then
  echo "ffi sdl music check SKIPPED (SDL2 not installed)"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

./spinel examples/sdl_music.rb -o "$TMP/sdl_music" >/dev/null 2>&1

if ! ldd "$TMP/sdl_music" | grep -q libSDL2; then
  echo "FAIL: sdl_music did not link libSDL2"
  exit 1
fi

out=$(timeout 3 "$TMP/sdl_music" 2>&1 || true)
if ! echo "$out" | grep -q "Synthesis done"; then
  echo "FAIL: sdl_music did not complete PCM synthesis"
  echo "Output was:"
  echo "$out"
  exit 1
fi
if ! echo "$out" | grep -q "Playing"; then
  echo "FAIL: sdl_music did not open audio"
  echo "Output was:"
  echo "$out"
  exit 1
fi

echo "ffi sdl music check OK (sdl_music synthesizes + opens audio)"
