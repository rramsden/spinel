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
  ffi_func :SDL_malloc,             [:size_t],                                :ptr
  ffi_func :SDL_free,               [:ptr],                                   :void
  ffi_func :SDL_SetRenderDrawColor, [:ptr, :int, :int, :int, :int],           :int
  ffi_func :SDL_RenderClear,        [:ptr],                                   :int
  ffi_func :SDL_RenderPresent,      [:ptr],                                   :void
  ffi_func :SDL_RenderDrawPoint,    [:ptr, :int, :int],                       :int
  ffi_func :SDL_RenderDrawLine,     [:ptr, :int, :int, :int, :int],           :int
  ffi_func :SDL_RenderFillRect,     [:ptr, :ptr],                             :int
  ffi_func :SDL_RenderDrawRect,     [:ptr, :ptr],                             :int

  # Surface/texture helpers
  ffi_func :SDL_CreateTextureFromSurface, [:ptr, :ptr],                     :ptr
  ffi_func :SDL_FreeSurface,              [:ptr],                            :void
  ffi_func :SDL_DestroyTexture,           [:ptr],                            :void
  ffi_func :SDL_SetTextureColorMod,       [:ptr, :uint8, :uint8, :uint8],   :int
  ffi_func :SDL_SetTextureAlphaMod,       [:ptr, :uint8],                   :int
  ffi_func :SDL_RenderCopy,               [:ptr, :ptr, :ptr, :ptr],          :int

  # --- Events ---
  ffi_func :SDL_PollEvent,                [:ptr],                            :int
  ffi_buffer :event_buf, 64
  ffi_read_u32 :event_type_raw, 0
  ffi_read_u32 :event_key_sym_raw, 20
  # SDL_WindowEvent layout:
  #   Uint32 type       (offset 0)
  #   Uint32 timestamp  (offset 4)
  #   Uint32 windowID   (offset 8)
  #   Uint8  event      (offset 12)  <-- subtype (SHOWN, CLOSE, ...)
  ffi_read_u8  :event_window_event, 12
  ffi_const :WINDOWEVENT_CLOSE, 14
end

# =============================================================================
# SDL_ttf bindings
# =============================================================================

module SDL_TTF
  ffi_lib "SDL2_ttf"

  ffi_func :TTF_Init,           [],                              :int
  ffi_func :TTF_Quit,           [],                              :void
  ffi_func :TTF_OpenFont,       [:str, :int],                    :ptr
  ffi_func :TTF_CloseFont,      [:ptr],                          :void
  ffi_func :TTF_OpenFontIndex,  [:str, :int, :int],              :ptr
  ffi_func :TTF_OpenFontRW,     [:ptr, :int, :int],              :ptr
  ffi_func :TTF_GetFontStyle,   [:ptr],                          :int
  ffi_func :TTF_SetFontStyle,   [:ptr, :int],                    :int
  ffi_func :TTF_GetFontOutline, [:ptr],                          :int
  ffi_func :TTF_SetFontOutline, [:ptr, :int],                    :int
  ffi_func :TTF_GetFontHinting, [:ptr],                          :int
  ffi_func :TTF_SetFontHinting, [:ptr, :int],                    :int
  ffi_func :TTF_GetFontHeight,  [:ptr],                          :int
  ffi_func :TTF_GetFontLineSkip, [:ptr],                       :int
  ffi_func :TTF_GetFontKerning, [:ptr],                        :int
  ffi_func :TTF_SetFontKerning, [:ptr, :int],                  :int
  ffi_func :TTF_GetFontFaces, [:ptr],                          :int
  ffi_func :TTF_GetFontInfo, [:ptr, :ptr],                      :int
  ffi_func :TTF_SizeText, [:ptr, :str, :ptr, :ptr],            :int
  ffi_func :TTF_SizeUTF8, [:ptr, :str, :ptr, :ptr],            :int
  ffi_func :TTF_SizePangoText, [:ptr, :ptr, :ptr, :ptr, :ptr], :int
  ffi_func :TTF_SizePangoUTF8, [:ptr, :ptr, :ptr, :ptr, :ptr], :int
  ffi_func :TTF_SizeGlyph, [:ptr, :uint16, :ptr, :ptr],       :int
  ffi_func :TTF_RenderText_Shaded, [:ptr, :str, :ptr, :ptr],   :ptr
  ffi_func :TTF_RenderUTF8_Shaded, [:ptr, :str, :ptr, :ptr],   :ptr
  ffi_func :TTF_RenderGlyph_Shaded, [:ptr, :uint16, :ptr, :ptr], :ptr
  # NOTE on SDL_Color ABI:
  # SDL_Color is a 4-byte struct {Uint8 r,g,b,a}. The C API takes it
  # BY VALUE, not by pointer. On SysV x86-64, structs <= 8 bytes of
  # integer members are passed in a single integer register, so the
  # color is delivered to the callee packed into the low 32 bits of
  # that register as 0xAABBGGRR (little-endian byte order: r @ byte 0,
  # g @ byte 1, b @ byte 2, a @ byte 3).
  #
  # Spinel's FFI DSL has no struct-by-value primitive, and passing
  # `:ptr` would put the *address* of our color buffer into the
  # register — SDL_ttf would then read the low 4 bytes of the BSS
  # address as RGBA, producing a different color on every launch
  # (thanks to ASLR). We therefore declare the color argument as
  # `:uint32` and pack it ourselves via `sdl_pack_color`.
  ffi_func :TTF_RenderText_Blended, [:ptr, :str, :uint32],     :ptr
  ffi_func :TTF_RenderUTF8_Blended, [:ptr, :str, :uint32],     :ptr
  ffi_func :TTF_RenderGlyph_Blended, [:ptr, :uint16, :uint32], :ptr
  ffi_func :TTF_RenderText_Blended_Wrapped, [:ptr, :str, :uint32, :uint32], :ptr
  ffi_func :TTF_RenderUTF8_Blended_Wrapped, [:ptr, :str, :uint32, :uint32], :ptr
  ffi_func :TTF_RenderText_Shaded_Wrapped, [:ptr, :str, :uint32, :uint32], :ptr
  ffi_func :TTF_RenderUTF8_Shaded_Wrapped, [:ptr, :str, :uint32, :uint32], :ptr
  ffi_func :TTF_SetFontDirection, [:ptr, :int],                :int
  ffi_func :TTF_SetFontLetterSpacing, [:ptr, :uint16],         :int

  # (No SDL_Color buffer: colors are packed into a uint32 and passed
  # by value via sdl_pack_color, matching SDL_Color's C ABI on
  # SysV x86-64. See the NOTE on the Blended bindings above.)

  # SDL_Rect buffer (x, y, w, h — each int = 4 bytes)
  ffi_buffer :dst_rect, 16
  ffi_write_i32 :dst_rect_set_x, 0
  ffi_write_i32 :dst_rect_set_y, 4
  ffi_write_i32 :dst_rect_set_w, 8
  ffi_write_i32 :dst_rect_set_h, 12
  ffi_read_i32  :dst_rect_get_x, 0
  ffi_read_i32  :dst_rect_get_y, 4
  ffi_read_i32  :dst_rect_get_w, 8
  ffi_read_i32  :dst_rect_get_h, 12

  # Surface dimension accessors.
  # SDL_Surface layout on a 64-bit LP64 system:
  #   Uint32           flags;   offset 0   (4 bytes + 4 pad)
  #   SDL_PixelFormat *format;  offset 8   (8 bytes, 8-aligned)
  #   int              w;       offset 16
  #   int              h;       offset 20
  ffi_read_i32  :surface_get_w, 16
  ffi_read_i32  :surface_get_h, 20
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

# Pack RGBA bytes into the single uint32 that SDL_Color occupies when
# passed by value on SysV x86-64: byte 0 = R, byte 1 = G, byte 2 = B,
# byte 3 = A. Use this to feed TTF_Render*_Blended and friends.
def sdl_pack_color(r, g, b, a)
  (a << 24) | (b << 16) | (g << 8) | r
end

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
    @frame_delay_ms = 0
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
    elsif et == SDL::EVT_WINDOWEVENT
      # SDL_WINDOWEVENT subtype is a uint8 at offset 12 in the
      # SDL_Event union (SDL_WindowEvent.event). Only bail on CLOSE;
      # other subtypes (SHOWN, EXPOSED, FOCUS_GAINED, ...) fire during
      # normal window life and must not quit the app.
      if SDL.event_window_event(SDL.event_buf) == SDL::WINDOWEVENT_CLOSE
        @running = false
      end
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

  # --- Audio (queue-based, callback-free) ---

  # Open the default audio device with the given format. Returns 0 on
  # success, -1 on failure. After this call, `play_audio` begins
  # playback and `queue_audio(buf, bytes)` feeds samples.
  #
  # freq      : sample rate (e.g. 44100)
  # format    : one of SDL::AUDIO_S16LSB, SDL::AUDIO_S16SYS
  # channels  : 1 (mono) or 2 (stereo)
  # samples   : audio buffer size in frames (e.g. 1024 or 4096)
  def open_audio(freq, format, channels, samples)
    if SDL.SDL_Init(SDL::INIT_AUDIO) != 0
      return -1
    end
    spec = SDL.audio_spec_desired
    SDL.aspec_set_freq(spec,     freq)
    SDL.aspec_set_format(spec,   format)
    SDL.aspec_set_channels(spec, channels)
    SDL.aspec_set_samples(spec,  samples)
    SDL.aspec_set_callback(spec, nil)   # NULL -> use queue API
    SDL.aspec_set_userdata(spec, nil)
    SDL.SDL_OpenAudio(spec, SDL.audio_spec_obtained)
  end

  def close_audio
    SDL.SDL_CloseAudio
    0
  end

  # Begin audio playback (unpause).
  def play_audio
    SDL.SDL_PauseAudio(0)
    0
  end

  def pause_audio
    SDL.SDL_PauseAudio(1)
    0
  end

  # Queue `bytes` bytes of PCM data from `buf` onto device 1 (the
  # default device opened by SDL_OpenAudio). Returns 0 on success.
  def queue_audio(buf, bytes)
    SDL.SDL_QueueAudio(1, buf, bytes)
    0
  end

  # How many bytes are still queued (undrained) for playback.
  def queued_audio_bytes
    SDL.SDL_GetQueuedAudioSize(1)
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

  def render_texture(texture, alpha, dst_rect)
    SDL.SDL_SetTextureAlphaMod(texture, alpha)
    SDL.SDL_RenderCopy(@renderer_ptr, texture, nil, dst_rect)
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
def sdl_open(title, width, height, vsync: true)
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
  flags = SDL::RENDERER_ACCELERATED
  if vsync
    flags |= SDL::RENDERER_PRESENTVSYNC
  end
  ren = SDL.SDL_CreateRenderer(win, -1, flags)
  if ren == nil
    SDL.SDL_DestroyWindow(win)
    SDL.SDL_Quit
    return nil
  end
  SdlApp.new(win, ren)
end
