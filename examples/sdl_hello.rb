# SDL2 hello-window demo using the *raw* FFI layer directly.
#
# This shows what Spinel's FFI looks like without the friendly
# SdlApp wrapper — every SDL call is visible. For a more compact
# version using the wrapper, see examples/sdl_hello2.rb. For the
# richer interactive shapes demo, see examples/sdl_shapes.rb.
#
# The FFI declarations (externs, constants, buffers) live in
# examples/sdl2.rb — we `require_relative` it and then just ignore
# the friendly classes on top.
#
# Build and run:
#   ./spinel examples/sdl_hello.rb && ./sdl_hello
#
# On WSL2 with WSLg, the window appears on your Windows desktop.
# Environment: no DISPLAY/WAYLAND_DISPLAY setup needed; WSLg exports
# them automatically. If you hit rendering glitches, try
#   SDL_VIDEODRIVER=x11 ./sdl_hello
# to force the X11 backend through XWayland.

require_relative "sdl2"

# ----------------------------------------------------------------------------
# Manually drive SDL via the raw FFI layer. No SdlApp, no SdlColor —
# just the module SDL provided by examples/sdl2.rb.
# ----------------------------------------------------------------------------

if SDL.SDL_Init(SDL::INIT_VIDEO) != 0
  puts "SDL_Init failed: " + SDL.SDL_GetError
  exit 1
end

win = SDL.SDL_CreateWindow(
  "Spinel + SDL2 (raw FFI)",
  SDL::WINDOWPOS_CENTERED, SDL::WINDOWPOS_CENTERED,
  640, 480,
  SDL::WINDOW_SHOWN)
if win == nil
  puts "SDL_CreateWindow failed: " + SDL.SDL_GetError
  SDL.SDL_Quit
  exit 1
end

ren = SDL.SDL_CreateRenderer(win, -1, SDL::RENDERER_ACCELERATED)
if ren == nil
  puts "SDL_CreateRenderer failed: " + SDL.SDL_GetError
  SDL.SDL_DestroyWindow(win)
  SDL.SDL_Quit
  exit 1
end

puts "Window open. Press ESC or close the window to quit."

buf = SDL.event_buf
running = true
frame = 0
while running
  # Drain the event queue via raw SDL_PollEvent.
  while SDL.SDL_PollEvent(buf) != 0
    et = SDL.event_type_raw(buf)
    if et == SDL::EVT_QUIT
      running = false
    elsif et == SDL::EVT_KEYDOWN
      if SDL.event_key_sym_raw(buf) == SDL::K_ESCAPE
        running = false
      end
    end
  end

  # Pulse through RGB channels.
  r = frame % 256
  g = (frame * 2) % 256
  b = (frame * 3) % 256
  SDL.SDL_SetRenderDrawColor(ren, r, g, b, 255)
  SDL.SDL_RenderClear(ren)
  SDL.SDL_RenderPresent(ren)

  SDL.SDL_Delay(16)   # ~60 fps
  frame = frame + 1
end

SDL.SDL_DestroyRenderer(ren)
SDL.SDL_DestroyWindow(win)
SDL.SDL_Quit
puts "Bye."
