#!/usr/bin/env python3
"""
generate_orchestral_bgm.py
Generates a cinematic dark-fantasy orchestral soundtrack for Elemental Beasts TCG.
Features:
- D Minor modal fantasy chord progression (Dm -> Bbmaj7 -> Gm7 -> A7sus4 -> F -> C -> A7)
- Multi-voice symphonic strings & warm choir pad with stereo chorusing
- Plucked concert harp arpeggios with acoustic damping
- Noble French Horn dragon melody
- Deep orchestral timpanis, low bass drones, and shimmering bell chimes
- Realistic stereo spatial reverb
"""

import numpy as np
import subprocess
import os

SAMPLE_RATE = 44100
BPM = 76.0
BEAT_DUR = 60.0 / BPM  # ~0.789s
BAR_DUR = BEAT_DUR * 4.0  # ~3.158s
TOTAL_BARS = 16
TOTAL_DUR = BAR_DUR * TOTAL_BARS  # ~50.5s
TOTAL_SAMPLES = int(SAMPLE_RATE * TOTAL_DUR)

time_arr = np.linspace(0, TOTAL_DUR, TOTAL_SAMPLES, endpoint=False)

left_channel = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
right_channel = np.zeros(TOTAL_SAMPLES, dtype=np.float64)

def freq_from_note(semitone_from_a4):
    return 440.0 * (2.0 ** (semitone_from_a4 / 12.0))

# Standard semitones relative to A4 (440Hz):
# C4 = -9, D4 = -7, E4 = -5, F4 = -4, G4 = -2, A4 = 0, Bb4 = 1, C5 = 3, D5 = 5, E5 = 7, F5 = 8, A5 = 12
NOTES = {
    'D2': -31, 'F2': -28, 'G2': -26, 'A2': -24, 'Bb2': -23, 'C3': -21,
    'D3': -19, 'E3': -17, 'F3': -16, 'G3': -14, 'A3': -12, 'Bb3': -11, 'C4': -9,
    'D4': -7, 'E4': -5, 'F4': -4, 'G4': -2, 'A4': 0, 'Bb4': 1, 'C#4': -8,
    'D5': 5, 'E5': 7, 'F5': 8, 'G5': 10, 'A5': 12, 'Bb5': 13, 'C5': 3,
    'D6': 17, 'F6': 20, 'A6': 24
}

def add_tone(track_l, track_r, f, start_time, dur, amp, pan=0.0, instrument='string'):
    start_idx = int(start_time * SAMPLE_RATE)
    end_idx = min(TOTAL_SAMPLES, start_idx + int(dur * SAMPLE_RATE))
    actual_len = end_idx - start_idx
    if actual_len <= 0 or start_idx >= TOTAL_SAMPLES:
        return
        
    t = np.linspace(0, dur, int(dur * SAMPLE_RATE))[:actual_len]
    
    if instrument == 'string':
        # Lush multi-harmonic warm string pad with slow attack/decay
        env = np.minimum(t / 0.7, 1.0) * np.minimum((dur - t) / 0.8, 1.0)
        # Vibrato: 5.3 Hz
        vib = 1.0 + 0.004 * np.sin(2.0 * np.pi * 5.3 * t)
        phase = 2.0 * np.pi * f * t * vib
        # Warm harmonics
        wave = (
            1.00 * np.sin(phase) +
            0.55 * np.sin(phase * 2.0 + 0.3) +
            0.28 * np.sin(phase * 3.0 + 0.7) +
            0.15 * np.sin(phase * 4.0 + 1.2) +
            0.08 * np.sin(phase * 5.0 + 0.5)
        )
        # Stereo chorus simulation
        wave_l = wave * np.cos((pan + 1.0) * np.pi / 4.0)
        wave_r = wave * np.sin((pan + 1.0) * np.pi / 4.0)
        
    elif instrument == 'harp':
        # Plucked concert harp with fast attack and natural acoustic exponential decay
        decay_rate = 1.2 + (f / 350.0) * 1.5
        env = np.minimum(t / 0.015, 1.0) * np.exp(-t * decay_rate)
        phase = 2.0 * np.pi * f * t
        wave = (
            1.00 * np.sin(phase) +
            0.45 * np.sin(phase * 2.0) * np.exp(-t * 2.5) +
            0.25 * np.sin(phase * 3.0) * np.exp(-t * 4.5) +
            0.12 * np.sin(phase * 4.0) * np.exp(-t * 6.5)
        )
        wave_l = wave * np.cos((pan + 1.0) * np.pi / 4.0)
        wave_r = wave * np.sin((pan + 1.0) * np.pi / 4.0)
        
    elif instrument == 'horn':
        # Heroic French Horn / brass with rich warm brass timbre & portamento
        env = np.minimum(t / 0.25, 1.0) * np.minimum((dur - t) / 0.35, 1.0)
        vib = 1.0 + 0.005 * np.sin(2.0 * np.pi * 5.5 * t)
        phase = 2.0 * np.pi * f * t * vib
        wave = (
            1.00 * np.sin(phase) +
            0.70 * np.sin(phase * 2.0 + 0.5) +
            0.45 * np.sin(phase * 3.0 + 1.0) +
            0.25 * np.sin(phase * 4.0 + 1.5) +
            0.12 * np.sin(phase * 5.0 + 2.0)
        )
        wave_l = wave * np.cos((pan + 1.0) * np.pi / 4.0)
        wave_r = wave * np.sin((pan + 1.0) * np.pi / 4.0)

    elif instrument == 'bass':
        # Deep resonant cello / contrabass drone
        env = np.minimum(t / 0.4, 1.0) * np.minimum((dur - t) / 0.5, 1.0)
        phase = 2.0 * np.pi * f * t
        wave = (
            1.00 * np.sin(phase) +
            0.60 * np.sin(phase * 2.0) +
            0.30 * np.sin(phase * 3.0) +
            0.15 * np.sin(phase * 4.0)
        )
        wave_l = wave * 0.707
        wave_r = wave * 0.707

    elif instrument == 'timpani':
        # Deep orchestral timpani with pitch envelope
        pitch_env = f * (1.0 + 1.5 * np.exp(-t * 22.0))
        env = np.exp(-t * 2.2)
        wave = np.sin(2.0 * np.pi * pitch_env * t) * env
        # Add subtle noise transient
        noise = (np.random.rand(len(t)) - 0.5) * np.exp(-t * 60.0) * 0.3
        wave = wave + noise
        wave_l = wave * 0.707
        wave_r = wave * 0.707
        
    elif instrument == 'chime':
        # Crystalline mystical chime
        env = np.exp(-t * 1.8)
        phase = 2.0 * np.pi * f * t
        wave = (
            np.sin(phase) +
            0.4 * np.sin(phase * 2.76) +
            0.2 * np.sin(phase * 5.4)
        ) * env
        wave_l = wave * np.cos((pan + 1.0) * np.pi / 4.0)
        wave_r = wave * np.sin((pan + 1.0) * np.pi / 4.0)

    track_l[start_idx:end_idx] += wave_l * amp
    track_r[start_idx:end_idx] += wave_r * amp

print("Composing orchestral chords and harmony...")

# Harmonic sections: 16 bars total
# Bars 0-1: Dm (root, noble)
# Bars 2-3: Bbmaj7 (expansion)
# Bars 4-5: Gm9 (mystique)
# Bars 6-7: A7sus4 -> A7 (majestic tension)
# Bars 8-9: Dm (heroic theme enter)
# Bars 10-11: Bb (soaring)
# Bars 12-13: F -> C (triumph)
# Bars 14-15: Gm -> A7 (preparation for seamless loop back)

progression = [
    # (bars, root_bass, chord_notes, chord_name)
    (0, 2, 'D2', ['D3', 'F3', 'A3', 'D4'], 'Dm'),
    (2, 2, 'Bb2', ['Bb2', 'D3', 'F3', 'A3'], 'Bbmaj7'),
    (4, 2, 'G2', ['G2', 'Bb2', 'D3', 'F3'], 'Gm7'),
    (6, 1, 'A2', ['A2', 'D3', 'E3', 'G3'], 'A7sus4'),
    (7, 1, 'A2', ['A2', 'C#4', 'E3', 'G3'], 'A7'),
    (8, 2, 'D2', ['D3', 'F3', 'A3', 'D4'], 'Dm'),
    (10, 2, 'Bb2', ['Bb2', 'D3', 'F3', 'Bb3'], 'Bb'),
    (12, 1, 'F2', ['F3', 'A3', 'C4', 'F4'], 'F'),
    (13, 1, 'C3', ['C3', 'E3', 'G3', 'C4'], 'C'),
    (14, 1, 'G2', ['G2', 'Bb2', 'D3', 'G3'], 'Gm'),
    (15, 1, 'A2', ['A2', 'C#4', 'E3', 'A3'], 'A7'),
]

for (start_bar, num_bars, bass_note, chord_notes, cname) in progression:
    st = start_bar * BAR_DUR
    dur = num_bars * BAR_DUR
    
    # 1. Bass drone
    f_bass = freq_from_note(NOTES[bass_note])
    add_tone(left_channel, right_channel, f_bass, st, dur, 0.28, pan=0.0, instrument='bass')
    
    # 2. String & Choir Pad chords (layered stereo)
    for i, cn in enumerate(chord_notes):
        f_cn = freq_from_note(NOTES[cn])
        pan = -0.5 + (i / max(1, len(chord_notes) - 1)) * 1.0
        add_tone(left_channel, right_channel, f_cn, st, dur, 0.16, pan=pan, instrument='string')
        
    # 3. Timpani on downbeat
    f_timp = freq_from_note(NOTES[bass_note]) * 1.2
    add_tone(left_channel, right_channel, f_timp, st, 1.8, 0.32, pan=-0.2, instrument='timpani')
    if num_bars > 1:
        # Second bar beat 1 soft timpani
        add_tone(left_channel, right_channel, f_timp, st + BAR_DUR, 1.5, 0.22, pan=-0.2, instrument='timpani')

print("Composing crystalline harp arpeggios...")
# 4. Concert Harp Arpeggios (8th note patterns, 0.5 beat = ~0.39s)
for bar in range(TOTAL_BARS):
    bar_start = bar * BAR_DUR
    # Find current chord notes
    current_notes = ['D3', 'F3', 'A3', 'D4', 'F4', 'A4', 'D5', 'A4']
    if bar in [2, 3, 10, 11]:
        current_notes = ['Bb2', 'D3', 'F3', 'Bb3', 'D4', 'F4', 'Bb4', 'F4']
    elif bar in [4, 5, 14]:
        current_notes = ['G2', 'Bb2', 'D3', 'G3', 'Bb3', 'D4', 'G4', 'D4']
    elif bar in [6]:
        current_notes = ['A2', 'D3', 'E3', 'A3', 'D4', 'E4', 'A4', 'E4']
    elif bar in [7, 15]:
        current_notes = ['A2', 'C#4', 'E3', 'A3', 'C#4', 'E4', 'A4', 'E4']
    elif bar == 12:
        current_notes = ['F2', 'A2', 'C3', 'F3', 'A3', 'C4', 'F4', 'C4']
    elif bar == 13:
        current_notes = ['C3', 'E3', 'G3', 'C4', 'E4', 'G4', 'C5', 'G4']
        
    for step in range(8):
        note_time = bar_start + (step * (BEAT_DUR * 0.5))
        n = current_notes[step % len(current_notes)]
        f_harp = freq_from_note(NOTES[n])
        pan = -0.6 if step % 2 == 0 else 0.6
        add_tone(left_channel, right_channel, f_harp, note_time, 2.2, 0.12, pan=pan, instrument='harp')

print("Composing French Horn heroic dragon melody (bars 8-16)...")
# French Horn dragon motif
melody = [
    # (time_in_beats, dur_in_beats, note, amp)
    # Bar 8: D4 -> F4 -> A4
    (32.0, 1.5, 'D4', 0.26),
    (33.5, 0.5, 'F4', 0.24),
    (34.0, 2.0, 'A4', 0.28),
    # Bar 9: G4 -> F4 -> E4 -> D4
    (36.0, 1.0, 'G4', 0.25),
    (37.0, 1.0, 'F4', 0.25),
    (38.0, 1.0, 'E4', 0.24),
    (39.0, 1.0, 'D4', 0.26),
    # Bar 10: Bb4 (soaring)
    (40.0, 2.5, 'Bb4', 0.30),
    (42.5, 1.5, 'D5', 0.32),
    # Bar 11: C5 -> Bb4 -> A4
    (44.0, 1.5, 'C5', 0.28),
    (45.5, 0.5, 'Bb4', 0.26),
    (46.0, 2.0, 'A4', 0.28),
    # Bar 12: F4 -> A4 -> C5 (heroic climax)
    (48.0, 1.5, 'F4', 0.26),
    (49.5, 0.5, 'A4', 0.28),
    (50.0, 2.0, 'C5', 0.32),
    # Bar 13: G4 -> C5 -> D5
    (52.0, 1.5, 'G4', 0.28),
    (53.5, 0.5, 'C5', 0.30),
    (54.0, 2.0, 'D5', 0.34),
    # Bar 14: Bb4 -> A4 -> G4
    (56.0, 1.5, 'Bb4', 0.28),
    (57.5, 0.5, 'A4', 0.26),
    (58.0, 2.0, 'G4', 0.25),
    # Bar 15: E4 -> C#4 -> A3 (resolving to loop)
    (60.0, 1.5, 'E4', 0.24),
    (61.5, 0.5, 'C#4', 0.22),
    (62.0, 2.0, 'A3', 0.24),
]

for (b_start, b_dur, note_name, amp) in melody:
    st = b_start * BEAT_DUR
    dur = b_dur * BEAT_DUR
    f_horn = freq_from_note(NOTES[note_name])
    add_tone(left_channel, right_channel, f_horn, st, dur + 0.3, amp, pan=0.15, instrument='horn')

# Shimmering chimes on bar 0, 4, 8, 12
for b in [0, 4, 8, 12]:
    st = b * BAR_DUR
    add_tone(left_channel, right_channel, freq_from_note(NOTES['D6']), st, 3.0, 0.08, pan=0.4, instrument='chime')
    add_tone(left_channel, right_channel, freq_from_note(NOTES['A6']), st + 0.2, 3.0, 0.06, pan=-0.4, instrument='chime')

print("Applying spatial stereo convolution & cathedral reverb...")
# High quality stereo reverb using multi-tap delay line with damping
delays_ms = [29, 37, 43, 53, 67, 79, 97, 113, 139, 167, 211, 263]
gains = [0.28, 0.24, 0.22, 0.19, 0.16, 0.14, 0.12, 0.10, 0.08, 0.06, 0.04, 0.03]

rev_l = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
rev_r = np.zeros(TOTAL_SAMPLES, dtype=np.float64)

for d_ms, g in zip(delays_ms, gains):
    d_samp = int(d_ms * 0.001 * SAMPLE_RATE)
    # Left channel
    rev_l[d_samp:] += left_channel[:-d_samp] * g * 0.7
    # Crossfeed to right for stereo width
    rev_r[d_samp:] += left_channel[:-d_samp] * g * 0.3
    # Right channel
    rev_r[d_samp:] += right_channel[:-d_samp] * g * 0.7
    rev_l[d_samp:] += right_channel[:-d_samp] * g * 0.3

# Mix dry + wet
dry_wet_ratio = 0.35
out_l = left_channel + rev_l * dry_wet_ratio
out_r = right_channel + rev_r * dry_wet_ratio

# Seamless looping crossfade at ends (fade in first 0.5s, fade out last 0.5s or overlap)
fade_len = int(SAMPLE_RATE * 1.5)
fade_in = np.linspace(0.0, 1.0, fade_len)
fade_out = np.linspace(1.0, 0.0, fade_len)

# Wrap tail around to head for perfect seamless loop!
out_l[:fade_len] += out_l[-fade_len:] * fade_out
out_r[:fade_len] += out_r[-fade_len:] * fade_out

# Master Limiter / Normalization (-1.0 dB peak)
peak = max(np.max(np.abs(out_l)), np.max(np.abs(out_r)))
target_peak = 0.89  # -1 dB
if peak > 0:
    out_l = (out_l / peak) * target_peak
    out_r = (out_r / peak) * target_peak

# Convert to 16-bit PCM interleaved stereo
stereo_interleaved = np.empty((TOTAL_SAMPLES * 2,), dtype=np.int16)
stereo_interleaved[0::2] = (np.clip(out_l, -1.0, 1.0) * 32767.0).astype(np.int16)
stereo_interleaved[1::2] = (np.clip(out_r, -1.0, 1.0) * 32767.0).astype(np.int16)

raw_pcm_path = "/tmp/orchestral_bgm.pcm"
with open(raw_pcm_path, "wb") as f:
    f.write(stereo_interleaved.tobytes())

target_mp3_path = "assets/audio/bgm/main_menu_theme.mp3"
print(f"Encoding to {target_mp3_path} with ffmpeg (44100Hz 192k MP3)...")

cmd = [
    "ffmpeg", "-y",
    "-f", "s16le",
    "-ar", "44100",
    "-ac", "2",
    "-i", raw_pcm_path,
    "-b:a", "192k",
    target_mp3_path
]
res = subprocess.run(cmd, capture_output=True, text=True)
if res.returncode == 0:
    sz = os.path.getsize(target_mp3_path)
    print(f"SUCCESS: Generated {target_mp3_path} ({sz} bytes, {TOTAL_DUR:.1f}s)")
else:
    print(f"Error encoding MP3: {res.stderr}")
