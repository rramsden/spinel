# Raylib smoke test for Spinel's FFI.
#
# Opens a window, prints "Hello, raylib!" using the default font, and
# closes on ESC. Exists to confirm the bindings + helper shim build
# end-to-end before any larger app pulls them in.
#
#   ./spinel examples/ffi/raylib/hello.rb -o hello && ./hello

require_relative "raylib"

app = ray_open("Spinel + Raylib", 640, 480)

WHITE  = ray_pack_color(245, 245, 245, 255)
INDIGO = ray_pack_color( 75,   0, 130, 255)

while app.running?
  app.begin_frame
  app.clear(INDIGO)
  RAY.DrawText("Hello, raylib!", 200, 220, 24, WHITE)
  RAY.DrawFPS(10, 10)
  app.end_frame
end

app.close
