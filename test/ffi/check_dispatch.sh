#!/bin/sh
# FFI dispatch smoke check (commit #3)
#
# Compiles a tiny FFI program that calls into libm + libc via the
# declared FFI interface, and verifies the output matches expectations.
# If this fails, either codegen or the wrapper's SPINEL_LINK scraper
# is broken.
#
# Usage: sh test/ffi/check_dispatch.sh
# Exit 0 on pass, non-zero on failure.

set -e
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

./spinel examples/ffi_libm.rb -o "$TMP/libm" >/dev/null 2>&1
out=$("$TMP/libm")
expected="1
4
1024
12"
if [ "$out" != "$expected" ]; then
  echo "FFI libm dispatch FAILED:"
  echo "  expected: $expected"
  echo "  got:      $out"
  exit 1
fi
echo "ffi dispatch OK (libm example)"
