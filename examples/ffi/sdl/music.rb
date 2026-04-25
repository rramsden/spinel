# SDL2 synthetic music + waveform visualizer.
#
# Generates a short melody as 16-bit signed mono PCM entirely from
# Ruby (no audio file, no WAV loader), queues it for playback via
# SDL's audio queue API, and animates the waveform on screen
# synchronized with playback.
#
# Controls:
#   Space   restart playback (re-queue)
#   ESC     quit
#
# Build and run:
#   ./spinel examples/ffi/sdl/music.rb && ./music

require_relative "sdl2"

# ----------------------------------------------------------------------------
# Audio constants
# ----------------------------------------------------------------------------
SAMPLE_RATE   = 44100
BYTES_PER_SAMPLE = 2   # signed 16-bit mono
NOTE_SECS     = 0.25   # length of each note
NUM_NOTES     = 4
TOTAL_SAMPLES = (SAMPLE_RATE * NOTE_SECS * NUM_NOTES).to_i   # = 44100 samples
TOTAL_BYTES   = TOTAL_SAMPLES * BYTES_PER_SAMPLE             # = 88200 bytes (fits audio_pcm)

# Window
W = 800
H = 400

# Melody: a C-major arpeggio (C4, E4, G4, C5) frequencies in Hz
NOTE0 = 262   # C4
NOTE1 = 330   # E4
NOTE2 = 392   # G4
NOTE3 = 523   # C5

# ----------------------------------------------------------------------------
# Synthesize melody into SDL.audio_pcm
# ----------------------------------------------------------------------------

# Pick the note frequency for sample index i (based on which quarter
# of the total sample range we're in).
def note_for_sample(i, note_samples)
  n = i / note_samples
  if n == 0 then return NOTE0 end
  if n == 1 then return NOTE1 end
  if n == 2 then return NOTE2 end
  NOTE3
end

# Simple ADSR-ish envelope so notes don't click. Returns 0.0..1.0.
def envelope(sample_in_note, note_samples)
  # 10% attack, 20% release, 70% sustain at full volume
  attack_len  = note_samples / 10
  release_len = note_samples / 5
  if sample_in_note < attack_len
    return sample_in_note.to_f / attack_len.to_f
  end
  if sample_in_note > note_samples - release_len
    remaining = note_samples - sample_in_note
    return remaining.to_f / release_len.to_f
  end
  1.0
end

puts "Synthesizing " + TOTAL_SAMPLES.to_s + " samples (" + TOTAL_BYTES.to_s + " bytes)..."

buf = SDL.audio_pcm
note_samples = SAMPLE_RATE / 4   # samples per note (quarter second each)
two_pi = 3.141592653589793 * 2.0
amp_max = 12000.0                # leaves headroom so quieter notes don't clip

i = 0
while i < TOTAL_SAMPLES
  freq = note_for_sample(i, note_samples)
  sample_in_note = i - (i / note_samples) * note_samples
  env = envelope(sample_in_note, note_samples)
  t = i.to_f / SAMPLE_RATE.to_f
  # Additive synth: fundamental + soft second harmonic for a bell tone
  fundamental = Math.sin(two_pi * freq.to_f * t)
  second      = Math.sin(two_pi * freq.to_f * 2.0 * t) * 0.3
  value = (fundamental + second) * env * amp_max
  SDL.pcm_set_s16(buf, i, value.to_i)
  i = i + 1
end
puts "Synthesis done."

# ----------------------------------------------------------------------------
# Open window + audio, queue samples, start playback
# ----------------------------------------------------------------------------

app = sdl_open("Spinel + SDL2 music demo", W, H)
if app == nil
  puts "failed to start SDL: " + SDL.SDL_GetError
  exit 1
end

if app.open_audio(SAMPLE_RATE, SDL::AUDIO_S16LSB, 1, 2048) != 0
  puts "failed to open audio: " + SDL.SDL_GetError
  app.close
  exit 1
end

# Kick off playback. Queue the whole buffer and unpause.
app.queue_audio(SDL.audio_pcm, TOTAL_BYTES)
app.play_audio

puts "Playing. Space to restart, ESC to quit."

# ----------------------------------------------------------------------------
# Main loop: render the waveform, highlight the playback position
# ----------------------------------------------------------------------------

half_h = H / 2

while app.running
  code = app.poll
  while code != 0
    if code == SDL::EVT_KEYDOWN && app.last_key == SDL::K_SPACE
      SDL.SDL_ClearQueuedAudio(1)
      app.queue_audio(SDL.audio_pcm, TOTAL_BYTES)
    end
    code = app.poll
  end

  # Figure out where we are in playback. Queued-bytes counts DOWN from
  # TOTAL_BYTES as samples get consumed; so played_bytes = TOTAL - queued.
  queued = app.queued_audio_bytes
  played_bytes = TOTAL_BYTES - queued
  if played_bytes < 0     then played_bytes = 0 end
  if played_bytes > TOTAL_BYTES then played_bytes = TOTAL_BYTES end
  played_samples = played_bytes / BYTES_PER_SAMPLE

  # --- Draw ---
  app.clear_with(sdl_rgb(12, 12, 24))

  # Center line
  app.set_color(sdl_rgb(40, 40, 70))
  app.draw_line(0, half_h, W, half_h)

  # Waveform: one column per pixel. We plot an oscilloscope-style view
  # of a ~20 ms window around the current playback cursor so the
  # waveform appears to scroll in sync with the music.
  window_samples = SAMPLE_RATE / 50   # 20 ms
  center_sample = played_samples
  start_sample = center_sample - window_samples / 2
  if start_sample < 0 then start_sample = 0 end
  if start_sample + window_samples > TOTAL_SAMPLES
    start_sample = TOTAL_SAMPLES - window_samples
  end

  app.set_color(sdl_rgb(80, 180, 255))
  prev_y = half_h
  x = 0
  while x < W
    sample_idx = start_sample + (x * window_samples) / W
    if sample_idx >= TOTAL_SAMPLES then sample_idx = TOTAL_SAMPLES - 1 end
    s = SDL.pcm_get_s16(SDL.audio_pcm, sample_idx)
    # 16-bit range -> pixels. Amplitude is ~12000 max, so scale to ~150 pixels.
    y = half_h - (s * (half_h - 60)) / 16000
    if y < 0 then y = 0 end
    if y >= H then y = H - 1 end
    if x > 0
      app.draw_line(x - 1, prev_y, x, y)
    end
    prev_y = y
    x = x + 1
  end

  # Progress cursor
  cursor_x = (played_samples * W) / TOTAL_SAMPLES
  if cursor_x >= W then cursor_x = W - 1 end
  app.set_color(sdl_rgb(255, 80, 80))
  app.draw_line(cursor_x, 0, cursor_x, H)

  # Bottom status band: progress bar
  app.set_color(sdl_rgb(40, 40, 60))
  app.fill_rect(0, H - 40, W, 40)
  bar_w = (played_bytes * (W - 20)) / TOTAL_BYTES
  if bar_w > 0
    app.set_color(sdl_rgb(80, 180, 255))
    app.fill_rect(10, H - 30, bar_w, 20)
  end
  app.set_color(sdl_rgb(200, 200, 220))
  app.draw_rect(10, H - 30, W - 20, 20)

  app.present
  app.frame_sync
end

app.close_audio
app.close
puts "Bye."
