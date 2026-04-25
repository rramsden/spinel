# Friendly SDL2 wrapper on top of Spinel's FFI.
#
# `require_relative "sdl2"` from your program, then work with the
# high-level classes and helpers below. The raw FFI layer (module
# SDL) is still available for anything the friendly layer doesn't
# wrap.
#
# --- Design constraints from Spinel's Ruby subset ---
#
#   * Classes cannot be nested inside modules, so types are top-level
#     and named `SdlXxx` (e.g. `SdlApp`, not `SDL::App`).
#   * Module class methods (`def self.foo`) cannot take blocks.
#   * Class methods (`def self.foo`) lose `:ptr` param type info at
#     their internal call sites — that's why the main factory is a
#     top-level function (`sdl_open`), not `SdlApp.open`.
#   * `yield a, b` compiles to invalid C today; yield one value or
#     none and let the block read other state via closure.
#   * Yielding object values (`yield some_obj`) also miscompiles,
#     so we don't yield events. Users `poll` in a plain `while` loop.
#   * Symbol-typed ivars (`@state = :none`) are mistyped by inference
#     as pointers to the enclosing class. Event codes are therefore
#     stored as ints, not symbols. Users compare against
#     `SDL::EVT_QUIT` etc. (which matches SDL's C API anyway).
#
# Once these quirks are fixed upstream, we can swap to more idiomatic
# symbol-based event types without changing the method names below.

# =============================================================================
# Raw FFI layer
# =============================================================================

module SDL
  ffi_lib "SDL2"
  ffi_cflags "-I/usr/include/SDL2"
  ffi_cflags "-D_REENTRANT"

  # --- Subsystem flags ---
  ffi_const :INIT_TIMER,       0x00000001
  ffi_const :INIT_AUDIO,       0x00000010
  ffi_const :INIT_VIDEO,       0x00000020
  ffi_const :INIT_JOYSTICK,    0x00000200
  ffi_const :INIT_EVENTS,      0x00004000
  ffi_const :INIT_EVERYTHING,  0x00007231

  # --- Window flags ---
  ffi_const :WINDOWPOS_UNDEFINED, 0x1fff0000
  ffi_const :WINDOWPOS_CENTERED,  0x2fff0000
  ffi_const :WINDOW_FULLSCREEN,   0x00000001
  ffi_const :WINDOW_OPENGL,       0x00000002
  ffi_const :WINDOW_SHOWN,        0x00000004
  ffi_const :WINDOW_HIDDEN,       0x00000008
  ffi_const :WINDOW_BORDERLESS,   0x00000010
  ffi_const :WINDOW_RESIZABLE,    0x00000020
  ffi_const :WINDOW_MINIMIZED,    0x00000040
  ffi_const :WINDOW_MAXIMIZED,    0x00000080

  # --- Renderer flags ---
  ffi_const :RENDERER_SOFTWARE,      1
  ffi_const :RENDERER_ACCELERATED,   2
  ffi_const :RENDERER_PRESENTVSYNC,  4

  # --- Event types (raw SDL Uint32 codes) ---
  ffi_const :EVT_NONE,            0    # sentinel used by the friendly layer
  ffi_const :EVT_QUIT,            256
  ffi_const :EVT_WINDOWEVENT,     512
  ffi_const :EVT_KEYDOWN,         768
  ffi_const :EVT_KEYUP,           769
  ffi_const :EVT_MOUSEMOTION,     1024
  ffi_const :EVT_MOUSEBUTTONDOWN, 1025
  ffi_const :EVT_MOUSEBUTTONUP,   1026

  # --- Common keycodes ---
  ffi_const :K_UNKNOWN,   0
  ffi_const :K_RETURN,    13
  ffi_const :K_ESCAPE,    27
  ffi_const :K_SPACE,     32
  ffi_const :K_LEFT,      1073741904
  ffi_const :K_RIGHT,     1073741903
  ffi_const :K_UP,        1073741906
  ffi_const :K_DOWN,      1073741905
  ffi_const :K_A,         97
  ffi_const :K_B,         98
  ffi_const :K_C,         99
  ffi_const :K_D,         100
  ffi_const :K_E,         101
  ffi_const :K_F,         102
  ffi_const :K_G,         103
  ffi_const :K_H,         104
  ffi_const :K_I,         105
  ffi_const :K_J,         106
  ffi_const :K_K,         107
  ffi_const :K_L,         108
  ffi_const :K_M,         109
  ffi_const :K_N,         110
  ffi_const :K_O,         111
  ffi_const :K_P,         112
  ffi_const :K_Q,         113
  ffi_const :K_R,         114
  ffi_const :K_S,         115
  ffi_const :K_T,         116
  ffi_const :K_U,         117
  ffi_const :K_V,         118
  ffi_const :K_W,         119
  ffi_const :K_X,         120
  ffi_const :K_Y,         121
  ffi_const :K_Z,         122
  ffi_const :K_0,         48
  ffi_const :K_1,         49
  ffi_const :K_2,         50
  ffi_const :K_3,         51
  ffi_const :K_4,         52
  ffi_const :K_5,         53
  ffi_const :K_6,         54
  ffi_const :K_7,         55
  ffi_const :K_8,         56
  ffi_const :K_9,         57

  # --- Core lifecycle ---
  ffi_func :SDL_Init,               [:uint32],                                :int
  ffi_func :SDL_Quit,               [],                                       :void
  ffi_func :SDL_GetError,           [],                                       :str
  ffi_func :SDL_GetTicks,           [],                                       :uint32
  ffi_func :SDL_Delay,              [:uint32],                                :void

  # --- Window + renderer ---
  ffi_func :SDL_CreateWindow,       [:str, :int, :int, :int, :int, :uint32],  :ptr
  ffi_func :SDL_DestroyWindow,      [:ptr],                                   :void
  ffi_func :SDL_SetWindowTitle,     [:ptr, :str],                             :void
  ffi_func :SDL_CreateRenderer,     [:ptr, :int, :uint32],                    :ptr
  ffi_func :SDL_DestroyRenderer,    [:ptr],                                   :void
  ffi_func :SDL_SetRenderDrawColor, [:ptr, :int, :int, :int, :int],           :int
  ffi_func :SDL_RenderClear,        [:ptr],                                   :int
  ffi_func :SDL_RenderPresent,      [:ptr],                                   :void
  ffi_func :SDL_RenderDrawPoint,    [:ptr, :int, :int],                       :int
  ffi_func :SDL_RenderDrawLine,     [:ptr, :int, :int, :int, :int],           :int
  ffi_func :SDL_RenderFillRect,     [:ptr, :ptr],                             :int
  ffi_func :SDL_RenderDrawRect,     [:ptr, :ptr],                             :int

  # --- Events ---
  # SDL_Event is a 56-byte union; we reserve 64 for safety.
  ffi_func :SDL_PollEvent,          [:ptr],                                   :int
  ffi_buffer :event_buf, 64
  # `type` is at offset 0; SDL_KeyboardEvent.keysym.sym at offset 20.
  ffi_read_u32 :event_type_raw, 0
  ffi_read_u32 :event_key_sym_raw, 20
end

# =============================================================================
# Color value type
# =============================================================================

class SdlColor
  attr_accessor :r, :g, :b, :a
  def initialize(r, g, b, a)
    @r = r; @g = g; @b = b; @a = a
  end
end

# Convenience constructors
def sdl_rgb(r, g, b);      SdlColor.new(r, g, b, 255); end
def sdl_rgba(r, g, b, a);  SdlColor.new(r, g, b, a); end

# =============================================================================
# SdlApp — window + renderer + events + drawing, all flattened
# =============================================================================

# Construct via sdl_open(title, width, height). Run a main loop like:
#
#   while app.running
#     app.drain_events           # built-in quit/ESC handling
#     # (or in a loop: while (code = app.poll) != SDL::EVT_NONE ... end)
#     app.clear_with(sdl_rgb(0, 0, 32))
#     app.draw_line(10, 10, 100, 100)
#     app.present
#     app.frame_sync
#   end
#   app.close
class SdlApp
  attr_accessor :window_ptr, :renderer_ptr,
                :last_event_type, :last_key,
                :running, :quit_on_escape, :frame_delay_ms

  def initialize(wp, rp)
    @window_ptr = wp
    @renderer_ptr = rp
    @last_event_type = 0    # SDL::EVT_NONE
    @last_key = 0           # SDL::K_UNKNOWN
    @running = true
    @quit_on_escape = true
    @frame_delay_ms = 16
  end

  # --- Lifecycle ---

  def quit
    @running = false
    0
  end

  def close
    if @renderer_ptr != nil
      SDL.SDL_DestroyRenderer(@renderer_ptr)
      @renderer_ptr = nil
    end
    if @window_ptr != nil
      SDL.SDL_DestroyWindow(@window_ptr)
      @window_ptr = nil
    end
    SDL.SDL_Quit
    0
  end

  # --- Events ---

  # Poll a single pending event. Returns the raw SDL event type
  # (SDL::EVT_QUIT, SDL::EVT_KEYDOWN, ...) or SDL::EVT_NONE when the
  # queue is empty. Updates @last_event_type and (for key events)
  # @last_key. Applies built-in handlers:
  #   - Sets @running = false on SDL::EVT_QUIT.
  #   - Sets @running = false on SDL::EVT_KEYDOWN with ESC when
  #     @quit_on_escape is true.
  def poll
    if SDL.SDL_PollEvent(SDL.event_buf) == 0
      @last_event_type = 0
      return 0
    end
    et = SDL.event_type_raw(SDL.event_buf)
    @last_event_type = et
    @last_key = 0
    if et == SDL::EVT_QUIT
      @running = false
    elsif et == SDL::EVT_KEYDOWN
      @last_key = SDL.event_key_sym_raw(SDL.event_buf)
      if @quit_on_escape == true && @last_key == SDL::K_ESCAPE
        @running = false
      end
    elsif et == SDL::EVT_KEYUP
      @last_key = SDL.event_key_sym_raw(SDL.event_buf)
    end
    et
  end

  # Drain every pending event this frame, applying built-in handlers.
  def drain_events
    while poll != 0
      # poll has already done the work
    end
    0
  end

  # --- Timing ---

  def frame_sync
    if @frame_delay_ms > 0
      SDL.SDL_Delay(@frame_delay_ms)
    end
    0
  end

  # --- Drawing ---

  # Set the current draw color. Call as `app.set_color(sdl_rgb(...))`.
  # (Can't use `color=` — Spinel compiles that as a struct field write
  # rather than a method call.)
  def set_color(c)
    SDL.SDL_SetRenderDrawColor(@renderer_ptr, c.r, c.g, c.b, c.a)
    0
  end

  def clear
    SDL.SDL_RenderClear(@renderer_ptr)
    0
  end

  def clear_with(c)
    SDL.SDL_SetRenderDrawColor(@renderer_ptr, c.r, c.g, c.b, c.a)
    SDL.SDL_RenderClear(@renderer_ptr)
    0
  end

  def present
    SDL.SDL_RenderPresent(@renderer_ptr)
    0
  end

  def draw_point(x, y)
    SDL.SDL_RenderDrawPoint(@renderer_ptr, x, y)
    0
  end

  def draw_line(x1, y1, x2, y2)
    SDL.SDL_RenderDrawLine(@renderer_ptr, x1, y1, x2, y2)
    0
  end

  # Solid rectangle via repeated horizontal lines. Works without
  # needing SDL_Rect packing (Spinel FFI lacks a writer primitive yet).
  def fill_rect(x, y, w, h)
    yi = 0
    while yi < h
      SDL.SDL_RenderDrawLine(@renderer_ptr, x, y + yi, x + w - 1, y + yi)
      yi = yi + 1
    end
    0
  end

  # Rectangle outline via 4 lines.
  def draw_rect(x, y, w, h)
    SDL.SDL_RenderDrawLine(@renderer_ptr, x,         y,         x + w - 1, y)
    SDL.SDL_RenderDrawLine(@renderer_ptr, x,         y + h - 1, x + w - 1, y + h - 1)
    SDL.SDL_RenderDrawLine(@renderer_ptr, x,         y,         x,         y + h - 1)
    SDL.SDL_RenderDrawLine(@renderer_ptr, x + w - 1, y,         x + w - 1, y + h - 1)
    0
  end
end

# =============================================================================
# Top-level factory
# =============================================================================

# Initialize SDL video, create a window + renderer, return an SdlApp.
# Returns nil on failure; caller should check and print SDL.SDL_GetError.
def sdl_open(title, width, height)
  if SDL.SDL_Init(SDL::INIT_VIDEO) != 0
    return nil
  end
  win = SDL.SDL_CreateWindow(title,
    SDL::WINDOWPOS_CENTERED, SDL::WINDOWPOS_CENTERED,
    width, height, SDL::WINDOW_SHOWN)
  if win == nil
    SDL.SDL_Quit
    return nil
  end
  ren = SDL.SDL_CreateRenderer(win, -1, SDL::RENDERER_ACCELERATED)
  if ren == nil
    SDL.SDL_DestroyWindow(win)
    SDL.SDL_Quit
    return nil
  end
  SdlApp.new(win, ren)
end
