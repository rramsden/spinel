# SDL2 interactive shapes demo using the friendly wrapper.
#
# Shows off the friendly API: drawing primitives, keyboard input,
# and per-frame animation — all without touching raw SDL_* calls.
#
# Controls:
#   Space       cycle background color
#   Arrows      move the white square
#   R / G / B   set square color
#   ESC         quit
#
# Build and run:
#   ./spinel examples/sdl_shapes.rb && ./sdl_shapes

require_relative "sdl2"

app = sdl_open("Spinel + SDL2 (shapes demo)", 640, 480)
if app == nil
  puts "failed to start SDL: " + SDL.SDL_GetError
  exit 1
end

puts "Arrow keys to move, Space for background, R/G/B for square color."
puts "ESC or close to quit."

# Game state
bg_idx = 0
bg_r = 20; bg_g = 20; bg_b = 60
sq_x = 320 - 20
sq_y = 240 - 20
sq_w = 40
sq_h = 40
sq_r = 255; sq_g = 255; sq_b = 255

step = 6

while app.running
  # Drain events and react to key presses. We use the poll loop
  # so we can inspect individual keys (not just ESC).
  code = app.poll
  while code != 0
    if code == SDL::EVT_KEYDOWN
      k = app.last_key
      if k == SDL::K_SPACE
        bg_idx = (bg_idx + 1) % 4
        if bg_idx == 0
          bg_r = 20;  bg_g = 20;  bg_b = 60
        elsif bg_idx == 1
          bg_r = 60;  bg_g = 20;  bg_b = 20
        elsif bg_idx == 2
          bg_r = 20;  bg_g = 60;  bg_b = 20
        else
          bg_r = 40;  bg_g = 40;  bg_b = 40
        end
      elsif k == SDL::K_LEFT  then sq_x = sq_x - step
      elsif k == SDL::K_RIGHT then sq_x = sq_x + step
      elsif k == SDL::K_UP    then sq_y = sq_y - step
      elsif k == SDL::K_DOWN  then sq_y = sq_y + step
      elsif k == SDL::K_R     then sq_r = 255; sq_g = 64;  sq_b = 64
      elsif k == SDL::K_G     then sq_r = 64;  sq_g = 255; sq_b = 64
      elsif k == SDL::K_B     then sq_r = 64;  sq_g = 64;  sq_b = 255
      end
    end
    code = app.poll
  end

  # Clamp square to window bounds
  if sq_x < 0 then sq_x = 0 end
  if sq_y < 0 then sq_y = 0 end
  if sq_x + sq_w > 640 then sq_x = 640 - sq_w end
  if sq_y + sq_h > 480 then sq_y = 480 - sq_h end

  # Draw
  app.clear_with(sdl_rgb(bg_r, bg_g, bg_b))

  # Crosshair through center
  app.set_color(sdl_rgb(80, 80, 80))
  app.draw_line(0, 240, 640, 240)
  app.draw_line(320, 0, 320, 480)

  # The square
  app.set_color(sdl_rgb(sq_r, sq_g, sq_b))
  app.fill_rect(sq_x, sq_y, sq_w, sq_h)

  # Border
  app.set_color(sdl_rgb(255, 255, 255))
  app.draw_rect(sq_x, sq_y, sq_w, sq_h)

  app.present
  app.frame_sync
end

app.close
puts "Bye."
