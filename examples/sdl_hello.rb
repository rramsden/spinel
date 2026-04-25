# SDL2 hello-window demo via Spinel's FFI.
#
# Opens a 640x480 window, animates a solid color that pulses through
# red/green/blue channels, and closes when you press ESC or click the
# close button.
#
# Build and run:
#   ./spinel examples/sdl_hello.rb && ./sdl_hello
#
# On WSL2 with WSLg, the window appears on your Windows desktop.
# Environment: no DISPLAY/WAYLAND_DISPLAY setup needed; WSLg exports
# them automatically. If you hit rendering glitches, try
#   SDL_VIDEODRIVER=x11 ./sdl_hello
# to force the X11 backend through XWayland.

module SDL
  ffi_lib "SDL2"
  ffi_cflags "-I/usr/include/SDL2"
  ffi_cflags "-D_REENTRANT"

  # Subsystem flags
  ffi_const :INIT_VIDEO, 0x20

  # Window position / flags
  ffi_const :WINDOWPOS_CENTERED, 0x2fff0000
  ffi_const :WINDOW_SHOWN,       4

  # Renderer flags
  ffi_const :RENDERER_ACCELERATED, 2
  ffi_const :RENDERER_PRESENTVSYNC, 4

  # Event types
  ffi_const :QUIT,     256
  ffi_const :KEYDOWN,  768

  # Keycodes
  ffi_const :K_ESCAPE, 27

  # Core lifecycle
  ffi_func :SDL_Init,           [:uint32],                                :int
  ffi_func :SDL_Quit,           [],                                       :void
  ffi_func :SDL_GetError,       [],                                       :str

  # Window + renderer
  ffi_func :SDL_CreateWindow,   [:str, :int, :int, :int, :int, :uint32],  :ptr
  ffi_func :SDL_DestroyWindow,  [:ptr],                                   :void
  ffi_func :SDL_CreateRenderer, [:ptr, :int, :uint32],                    :ptr
  ffi_func :SDL_DestroyRenderer,[:ptr],                                   :void
  ffi_func :SDL_SetRenderDrawColor, [:ptr, :int, :int, :int, :int],       :int
  ffi_func :SDL_RenderClear,    [:ptr],                                   :int
  ffi_func :SDL_RenderPresent,  [:ptr],                                   :void

  # Event polling. SDL_Event is a 56-byte union; we reserve 64 for safety.
  # type field is at offset 0 (Uint32). For SDL_KEYDOWN, keysym.sym sits
  # at offset 20 (SDL_KeyboardEvent: type=0, timestamp=4, windowID=8,
  # state=12, repeat=13, padding=14-15, keysym.scancode=16,
  # keysym.sym=20).
  ffi_func :SDL_PollEvent,      [:ptr],                                   :int
  ffi_buffer :event_buf, 64
  ffi_read_u32 :event_type, 0
  ffi_read_u32 :event_key_sym, 20

  # Timing
  ffi_func :SDL_Delay,          [:uint32],                                :void
  ffi_func :SDL_GetTicks,       [],                                       :uint32
end

if SDL.SDL_Init(SDL::INIT_VIDEO) != 0
  puts "SDL_Init failed: " + SDL.SDL_GetError
  exit 1
end

win = SDL.SDL_CreateWindow(
  "Spinel + SDL2",
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
  # Drain the event queue.
  while SDL.SDL_PollEvent(buf) != 0
    et = SDL.event_type(buf)
    if et == SDL::QUIT
      running = false
    elsif et == SDL::KEYDOWN
      if SDL.event_key_sym(buf) == SDL::K_ESCAPE
        running = false
      end
    end
  end

  # Pulse through RGB channels every ~3 seconds.
  t = frame
  r = (t)        % 256
  g = (t * 2)    % 256
  b = (t * 3)    % 256
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
