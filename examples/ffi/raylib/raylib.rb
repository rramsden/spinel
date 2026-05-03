# Friendly Raylib wrapper on top of Spinel's FFI.
#
# `require_relative "raylib"` from your program, then work with the
# high-level RaylibApp + RaylibFont classes below. The raw FFI layer
# (module RAY) is still available for anything not yet wrapped.
#
# --- The companion C shim ---
#
# Raylib's public API takes Color, Vector2, Rectangle, Font, and
# Texture2D BY VALUE. Spinel's FFI only handles scalars and opaque
# pointers, so the larger structs (Font is 48 bytes, returned via a
# hidden ABI pointer) cannot be expressed directly. raylib_helper.c
# provides `rl_*` wrappers that take packed scalars and box Fonts on
# the heap. Build it once and install alongside libraylib:
#
#   cc -O2 -fPIC -shared -I<raylib-include> raylib_helper.c \
#      -L<raylib-lib> -lraylib -o libraylibhelper.so
#
# --- Color ABI ---
#
# raylib's Color = {Uint8 r, g, b, a} fits in a single integer register
# on SysV x86-64. We pack RGBA into a uint32 (byte 0=R,1=G,2=B,3=A) and
# pass it by value. ClearBackground/DrawText would accept that directly,
# but we route everything through the shim so the public API is uniform.

# =============================================================================
# Raw FFI layer
# =============================================================================

module RAY
  ffi_lib "raylib"
  ffi_lib "raylibhelper"

  # --- Window / lifecycle ---
  ffi_func :InitWindow,         [:int, :int, :str], :void
  ffi_func :CloseWindow,        [],                 :void
  ffi_func :IsWindowReady,      [],                 :bool
  ffi_func :SetWindowTitle,     [:str],             :void
  ffi_func :GetScreenWidth,     [],                 :int
  ffi_func :GetScreenHeight,    [],                 :int
  ffi_func :SetConfigFlags,     [:uint32],          :void
  ffi_func :SetTraceLogLevel,   [:int],             :void

  # --- Frame loop ---
  ffi_func :BeginDrawing,       [],                 :void
  ffi_func :EndDrawing,         [],                 :void
  ffi_func :SetTargetFPS,       [:int],             :void
  ffi_func :GetFPS,             [],                 :int
  ffi_func :GetFrameTime,       [],                 :float
  ffi_func :GetTime,            [],                 :double

  # --- Built-in drawing (Color is 4 bytes integer-class, can ride a
  #     uint32 register on SysV x86-64; see header note). ---
  ffi_func :DrawText,           [:str, :int, :int, :int, :uint32], :void
  ffi_func :DrawFPS,            [:int, :int],       :void
  ffi_func :MeasureText,        [:str, :int],       :int

  # --- Input ---
  # raylib's IsKey* return _Bool; we go through the shim's int wrappers
  # to dodge a SysV-ABI gotcha (see raylib_helper.c for the full story).
  ffi_func :GetKeyPressed,      [],                 :int
  ffi_func :GetCharPressed,     [],                 :int

  # --- C shim entry points (struct-by-value + clean int bool returns) ---
  ffi_func :rl_window_should_close, [],             :int
  ffi_func :rl_is_key_pressed,   [:int],            :int
  ffi_func :rl_is_key_down,      [:int],            :int
  ffi_func :rl_is_key_released,  [:int],            :int
  ffi_func :rl_clear_background, [:uint32],         :void
  ffi_func :rl_load_font,        [:str, :int],      :ptr
  ffi_func :rl_unload_font,      [:ptr],            :void
  ffi_func :rl_font_is_valid,    [:ptr],            :int
  ffi_func :rl_font_base_size,   [:ptr],            :int
  ffi_func :rl_draw_text_ex,     [:ptr, :str, :float, :float, :float, :float, :uint32], :void
  ffi_func :rl_measure_text_w,   [:ptr, :str, :float, :float], :float
  ffi_func :rl_measure_text_h,   [:ptr, :str, :float, :float], :float

  # --- Config flags (subset; see raylib.h for the rest) ---
  ffi_const :FLAG_VSYNC_HINT,        0x00000040
  ffi_const :FLAG_FULLSCREEN_MODE,   0x00000002
  ffi_const :FLAG_WINDOW_RESIZABLE,  0x00000004
  ffi_const :FLAG_WINDOW_UNDECORATED, 0x00000008
  ffi_const :FLAG_WINDOW_HIDDEN,     0x00000080
  ffi_const :FLAG_MSAA_4X_HINT,      0x00000020
  ffi_const :FLAG_WINDOW_HIGHDPI,    0x00002000

  # --- Trace log levels ---
  ffi_const :LOG_ALL,      0
  ffi_const :LOG_TRACE,    1
  ffi_const :LOG_DEBUG,    2
  ffi_const :LOG_INFO,     3
  ffi_const :LOG_WARNING,  4
  ffi_const :LOG_ERROR,    5
  ffi_const :LOG_FATAL,    6
  ffi_const :LOG_NONE,     7

  # --- Common keys (raylib uses GLFW codes — KEY_A == 'A' == 65). ---
  ffi_const :KEY_NULL,      0
  ffi_const :KEY_APOSTROPHE, 39
  ffi_const :KEY_COMMA,     44
  ffi_const :KEY_MINUS,     45
  ffi_const :KEY_PERIOD,    46
  ffi_const :KEY_SLASH,     47
  ffi_const :KEY_ZERO,      48
  ffi_const :KEY_ONE,       49
  ffi_const :KEY_TWO,       50
  ffi_const :KEY_THREE,     51
  ffi_const :KEY_FOUR,      52
  ffi_const :KEY_FIVE,      53
  ffi_const :KEY_SIX,       54
  ffi_const :KEY_SEVEN,     55
  ffi_const :KEY_EIGHT,     56
  ffi_const :KEY_NINE,      57
  ffi_const :KEY_SEMICOLON, 59
  ffi_const :KEY_EQUAL,     61
  ffi_const :KEY_A, 65
  ffi_const :KEY_B, 66
  ffi_const :KEY_C, 67
  ffi_const :KEY_D, 68
  ffi_const :KEY_E, 69
  ffi_const :KEY_F, 70
  ffi_const :KEY_G, 71
  ffi_const :KEY_H, 72
  ffi_const :KEY_I, 73
  ffi_const :KEY_J, 74
  ffi_const :KEY_K, 75
  ffi_const :KEY_L, 76
  ffi_const :KEY_M, 77
  ffi_const :KEY_N, 78
  ffi_const :KEY_O, 79
  ffi_const :KEY_P, 80
  ffi_const :KEY_Q, 81
  ffi_const :KEY_R, 82
  ffi_const :KEY_S, 83
  ffi_const :KEY_T, 84
  ffi_const :KEY_U, 85
  ffi_const :KEY_V, 86
  ffi_const :KEY_W, 87
  ffi_const :KEY_X, 88
  ffi_const :KEY_Y, 89
  ffi_const :KEY_Z, 90
  ffi_const :KEY_SPACE,     32
  ffi_const :KEY_ESCAPE,    256
  ffi_const :KEY_ENTER,     257
  ffi_const :KEY_TAB,       258
  ffi_const :KEY_BACKSPACE, 259
  ffi_const :KEY_INSERT,    260
  ffi_const :KEY_DELETE,    261
  ffi_const :KEY_RIGHT,     262
  ffi_const :KEY_LEFT,      263
  ffi_const :KEY_DOWN,      264
  ffi_const :KEY_UP,        265
  ffi_const :KEY_PAGE_UP,   266
  ffi_const :KEY_PAGE_DOWN, 267
  ffi_const :KEY_HOME,      268
  ffi_const :KEY_END,       269
  ffi_const :KEY_F1,  290
  ffi_const :KEY_F2,  291
  ffi_const :KEY_F3,  292
  ffi_const :KEY_F4,  293
  ffi_const :KEY_F5,  294
  ffi_const :KEY_F6,  295
  ffi_const :KEY_F7,  296
  ffi_const :KEY_F8,  297
  ffi_const :KEY_F9,  298
  ffi_const :KEY_F10, 299
  ffi_const :KEY_F11, 300
  ffi_const :KEY_F12, 301
end

# =============================================================================
# Color value type — packs into the uint32 our shim and DrawText expect.
# =============================================================================

# Pack RGBA bytes into the uint32 layout that matches raylib's
# {Uint8 r, g, b, a} struct on little-endian targets: byte 0 = R,
# byte 1 = G, byte 2 = B, byte 3 = A.
def ray_pack_color(r, g, b, a)
  (a << 24) | (b << 16) | (g << 8) | r
end

# Replace just the alpha byte of an already-packed color. Used to
# fade text in and out without touching the RGB channels.
def ray_pack_color_alpha(packed, a)
  (packed & 0x00FFFFFF) | (a << 24)
end

# =============================================================================
# RaylibFont — opaque heap-boxed Font handle from the shim.
# =============================================================================

class RaylibFont
  attr_reader :ptr, :path, :size

  def initialize(path, size)
    @path = path
    @size = size
    @ptr  = RAY.rl_load_font(path, size)
  end

  def valid?
    @ptr != nil && RAY.rl_font_is_valid(@ptr) != 0
  end

  def measure_w(text, spacing)
    RAY.rl_measure_text_w(@ptr, text, @size.to_f, spacing.to_f)
  end

  def measure_h(text, spacing)
    RAY.rl_measure_text_h(@ptr, text, @size.to_f, spacing.to_f)
  end

  def draw(text, x, y, packed_color, spacing)
    RAY.rl_draw_text_ex(@ptr, text, x.to_f, y.to_f,
                        @size.to_f, spacing.to_f, packed_color)
  end

  def close
    if @ptr != nil
      RAY.rl_unload_font(@ptr)
      @ptr = nil
    end
  end
end

# =============================================================================
# RaylibApp — window + frame loop, all flattened.
# =============================================================================

# Construct via ray_open(title, width, height). Run a main loop like:
#
#   while app.running?
#     app.begin_frame
#     app.clear(ray_pack_color(0, 0, 32, 255))
#     # ... draw calls ...
#     app.end_frame
#   end
#   app.close
class RaylibApp
  attr_accessor :screen_width, :screen_height, :quit_on_escape

  def initialize(width, height, title, vsync, target_fps)
    @screen_width   = width
    @screen_height  = height
    @quit_on_escape = true
    @user_quit      = false

    flags = 0
    if vsync
      flags = flags | RAY::FLAG_VSYNC_HINT
    end
    if flags != 0
      RAY.SetConfigFlags(flags)
    end

    RAY.SetTraceLogLevel(RAY::LOG_WARNING)
    RAY.InitWindow(width, height, title)
    if target_fps > 0
      RAY.SetTargetFPS(target_fps)
    end
  end

  # --- Frame loop ---

  def running?
    if @user_quit
      return false
    end
    if @quit_on_escape && RAY.rl_is_key_pressed(RAY::KEY_ESCAPE) != 0
      return false
    end
    RAY.rl_window_should_close == 0
  end

  def quit
    @user_quit = true
  end

  def begin_frame
    RAY.BeginDrawing
  end

  def end_frame
    RAY.EndDrawing
  end

  def clear(packed_color)
    RAY.rl_clear_background(packed_color)
  end

  def fps
    RAY.GetFPS
  end

  def frame_time
    RAY.GetFrameTime
  end

  # --- Input ---

  def key_pressed?(key)
    RAY.rl_is_key_pressed(key) != 0
  end

  def key_down?(key)
    RAY.rl_is_key_down(key) != 0
  end

  def key_released?(key)
    RAY.rl_is_key_released(key) != 0
  end

  # --- Lifecycle ---

  def close
    RAY.CloseWindow
  end
end

# =============================================================================
# Top-level factory
# =============================================================================

# Open a window with vsync enabled and a 60 FPS cap. Returns a RaylibApp.
# Pass vsync: false to disable vsync; pass target_fps: 0 to uncap.
def ray_open(title, width, height, vsync: true, target_fps: 60)
  RaylibApp.new(width, height, title, vsync, target_fps)
end
