# SDL2 demo using the friendly wrapper in examples/ffi/sdl/sdl2.rb.
#
# ~20 lines of real program code vs ~60 for the raw version.
#
# Build and run:
#   ./spinel examples/ffi/sdl/hello.rb && ./hello

require_relative "sdl2"

app = sdl_open("Spinel + SDL2 (friendly)", 640, 480)
if app == nil
  puts "failed to start SDL: " + SDL.SDL_GetError
  exit 1
end

puts "Window open. Press ESC or close the window to quit."

frame = 0
while app.running
  # Drain events (built-in handlers close on :quit / ESC).
  app.drain_events

  # Per-frame draw: pulse RGB channels.
  r = frame % 256
  g = (frame * 2) % 256
  b = (frame * 3) % 256
  app.clear_with(sdl_rgb(r, g, b))
  app.present

  app.frame_sync   # ~60 fps
  frame = frame + 1
end

app.close
puts "Bye."
