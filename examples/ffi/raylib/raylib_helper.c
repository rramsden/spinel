/*
 * raylib_helper.c — C shim that bridges raylib's struct-by-value API
 * to Spinel's FFI (which only handles scalars and opaque pointers).
 *
 * raylib passes Color/Vector2/Rectangle/Font/Texture2D BY VALUE. Some of
 * those (Color = 4 ints) ride in a single integer register and can be
 * packed into a uint32 — Spinel can call those directly. Others
 * (Vector2 = SSE register, Font = 48 bytes by reference) cannot be
 * faked from a uint64; they need real C call sites.
 *
 * The shim is the smallest set of wrappers that lets the Living
 * Grimoire game (and similar 2D apps) avoid those ABI corners. Every
 * helper takes/returns scalars or void*, so the Spinel side can stay
 * declarative.
 */

#include "raylib.h"
#include <stdlib.h>

/* Convert the packed RGBA word the Spinel side hands us (byte 0 = R,
 * 1 = G, 2 = B, 3 = A — same memory layout as raylib's Color struct
 * on little-endian targets) into an actual Color. */
static Color rgba_unpack(unsigned int packed) {
    Color c;
    c.r = (unsigned char)(packed       & 0xFF);
    c.g = (unsigned char)((packed >> 8) & 0xFF);
    c.b = (unsigned char)((packed >> 16) & 0xFF);
    c.a = (unsigned char)((packed >> 24) & 0xFF);
    return c;
}

/* === Font lifecycle ===
 *
 * raylib's Font is 48 bytes (>16) so the SysV ABI returns it via a
 * hidden pointer arg the caller allocates. Spinel can't synthesize
 * that, so we heap-box the Font and hand back an opaque pointer. */

void *rl_load_font(const char *path, int size) {
    Font *f = (Font *)malloc(sizeof(Font));
    if (!f) return NULL;
    *f = LoadFontEx(path, size, NULL, 0);
    return (void *)f;
}

void rl_unload_font(void *font) {
    if (!font) return;
    UnloadFont(*(Font *)font);
    free(font);
}

int rl_font_is_valid(void *font) {
    if (!font) return 0;
    return IsFontValid(*(Font *)font) ? 1 : 0;
}

int rl_font_base_size(void *font) {
    if (!font) return 0;
    return ((Font *)font)->baseSize;
}

/* === Boolean-returning wrappers ===
 *
 * raylib returns C99 _Bool from IsKeyPressed/Down/Released and friends.
 * Spinel declares those externs with `int` return; on SysV x86-64 the
 * callee only writes the low byte (al) and the upper bits of eax are
 * implementation-defined. gcc usually zero-extends, but not always —
 * we have observed `IsKeyPressed(KEY_SPACE)` returning a nonzero "int"
 * for an unpressed key. Routing through these wrappers forces a real
 * int return, so the Spinel side sees 0 or 1. */

int rl_window_should_close(void) { return WindowShouldClose() ? 1 : 0; }
int rl_is_key_pressed(int key)   { return IsKeyPressed(key)   ? 1 : 0; }
int rl_is_key_down(int key)      { return IsKeyDown(key)      ? 1 : 0; }
int rl_is_key_released(int key)  { return IsKeyReleased(key)  ? 1 : 0; }

/* === Drawing ===
 *
 * ClearBackground takes Color (4 bytes, integer class) which Spinel
 * could pass directly as :uint32. Wrapping it anyway keeps the public
 * surface uniform: every helper takes a packed color the same way. */

void rl_clear_background(unsigned int packed_color) {
    ClearBackground(rgba_unpack(packed_color));
}

/* DrawTextEx needs Font (by value) and Vector2 (in xmm register).
 * Neither survives the round trip through Spinel's scalar-only DSL,
 * so we shoulder the struct construction here. */
void rl_draw_text_ex(void *font, const char *text,
                     float x, float y,
                     float font_size, float spacing,
                     unsigned int packed_color) {
    Vector2 pos;
    pos.x = x;
    pos.y = y;
    DrawTextEx(*(Font *)font, text, pos, font_size, spacing,
               rgba_unpack(packed_color));
}

/* === Measuring ===
 *
 * MeasureTextEx returns Vector2 (8 bytes float, SSE register). Splitting
 * it into two scalar calls is cheaper than building a Spinel-owned
 * Vector2 buffer and read accessors. */

float rl_measure_text_w(void *font, const char *text,
                        float font_size, float spacing) {
    Vector2 sz = MeasureTextEx(*(Font *)font, text, font_size, spacing);
    return sz.x;
}

float rl_measure_text_h(void *font, const char *text,
                        float font_size, float spacing) {
    Vector2 sz = MeasureTextEx(*(Font *)font, text, font_size, spacing);
    return sz.y;
}
