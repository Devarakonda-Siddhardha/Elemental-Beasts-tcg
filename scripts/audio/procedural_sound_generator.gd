class_name ProceduralSoundGenerator
extends RefCounted

const SAMPLE_RATE: int = 22050

# Helper to create an AudioStreamWAV from a float array [-1.0, 1.0]
static func create_wav_from_samples(samples: Array[float], sample_rate: int = SAMPLE_RATE) -> AudioStreamWAV:
	var num_samples: int = samples.size()
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	for i in range(num_samples):
		var s: float = clampf(samples[i], -1.0, 1.0)
		var int_val: int = int(round(s * 32767.0))
		bytes.encode_s16(i * 2, int_val)
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav

# 1. Subtle, high-frequency card hover chirp (35ms)
static func generate_card_hover() -> AudioStreamWAV:
	var duration: float = 0.035
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 90.0)
		var freq: float = lerp(1200.0, 1800.0, t / duration)
		var wave: float = sin(t * freq * TAU)
		samples[i] = wave * env * 0.25
		
	return create_wav_from_samples(samples)

# 2. Tactile Card Click / Select (50ms)
static func generate_card_click() -> AudioStreamWAV:
	var duration: float = 0.05
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 80.0)
		var noise: float = randf_range(-0.5, 0.5)
		var pop: float = sin(t * 350.0 * TAU) * 0.7
		samples[i] = (pop + noise * 0.5) * env * 0.4
		
	return create_wav_from_samples(samples)

# 3. Card Play / Slam on Battlefield (180ms)
static func generate_card_play() -> AudioStreamWAV:
	var duration: float = 0.18
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 24.0)
		# Rapid downward frequency pitch for heavy body thump
		var freq: float = 180.0 * exp(-t * 18.0) + 45.0
		var thump: float = sin(t * freq * TAU)
		# Add a snappy initial transient slap
		var slap: float = randf_range(-0.6, 0.6) * exp(-t * 70.0)
		samples[i] = (thump * 0.8 + slap * 0.4) * env * 0.7
		
	return create_wav_from_samples(samples)

# 4. Mana Crystal Spend Chime (300ms)
static func generate_mana_spend() -> AudioStreamWAV:
	var duration: float = 0.3
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 14.0)
		# Dual crystal chime (C6: 1046 Hz and G6: 1568 Hz)
		var chime1: float = sin(t * 1046.5 * TAU)
		var chime2: float = sin(t * 1567.98 * TAU) * 0.6
		var shimmer: float = sin(t * 3135.96 * TAU) * 0.25 * exp(-t * 30.0)
		samples[i] = (chime1 + chime2 + shimmer) * env * 0.4
		
	return create_wav_from_samples(samples)

# 5. Mana Refresh 5 Crystals Fanfare (450ms)
static func generate_mana_refresh() -> AudioStreamWAV:
	var duration: float = 0.45
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	# Ascending 3-note crystal shimmer (523Hz C5 -> 659Hz E5 -> 784Hz G5)
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total: float = 0.0
		
		# Note 1: 0.0 - 0.3s
		if t >= 0.0:
			var dt: float = t
			total += sin(dt * 523.25 * TAU) * exp(-dt * 12.0) * 0.35
		# Note 2: 0.08 - 0.4s
		if t >= 0.08:
			var dt: float = t - 0.08
			total += sin(dt * 659.25 * TAU) * exp(-dt * 12.0) * 0.35
		# Note 3: 0.16 - 0.45s
		if t >= 0.16:
			var dt: float = t - 0.16
			total += sin(dt * 783.99 * TAU) * exp(-dt * 10.0) * 0.45
			# octave shimmer
			total += sin(dt * 1567.98 * TAU) * exp(-dt * 20.0) * 0.2
			
		samples[i] = total * 0.6
		
	return create_wav_from_samples(samples)

# 6. Element Stone Placement Clack (220ms)
static func generate_stone_place() -> AudioStreamWAV:
	var duration: float = 0.22
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 22.0)
		# Hard mineral impact: sharp initial click + resonant stone ringing
		var click: float = randf_range(-1.0, 1.0) * exp(-t * 90.0)
		var ring1: float = sin(t * 460.0 * TAU) * 0.6
		var ring2: float = sin(t * 1180.0 * TAU) * 0.35
		samples[i] = (click * 0.6 + ring1 + ring2) * env * 0.6
		
	return create_wav_from_samples(samples)

# 7. Element Stone Spend / Dissolve (220ms)
static func generate_stone_spend() -> AudioStreamWAV:
	var duration: float = 0.22
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 16.0)
		var noise: float = randf_range(-0.7, 0.7)
		var whoosh: float = sin(t * (600.0 - t * 1200.0) * TAU) * 0.5
		samples[i] = (noise * 0.5 + whoosh) * env * 0.5
		
	return create_wav_from_samples(samples)

# 8. Dragon Evolution Fanfare Surge (700ms)
static func generate_evolution() -> AudioStreamWAV:
	var duration: float = 0.7
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	# Sweeping mystical arpeggio with rich harmonics (A major: 440 -> 554 -> 659 -> 880)
	var notes = [440.0, 554.37, 659.25, 880.0]
	var note_times = [0.0, 0.12, 0.24, 0.36]
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var val: float = 0.0
		
		# Base power surge swell
		var swell: float = sin(t * 110.0 * TAU) * minf(t * 5.0, 1.0) * exp(-maxf(0.0, t - 0.4) * 6.0) * 0.3
		val += swell
		
		for n in range(notes.size()):
			if t >= note_times[n]:
				var dt: float = t - note_times[n]
				var f: float = notes[n]
				var decay: float = exp(-dt * 6.0)
				# Sine + octave harmonic + third harmonic
				var harm: float = sin(dt * f * TAU) + 0.4 * sin(dt * f * 2.0 * TAU) + 0.2 * sin(dt * f * 3.0 * TAU)
				val += harm * decay * 0.25
				
		samples[i] = clampf(val * 0.8, -1.0, 1.0)
		
	return create_wav_from_samples(samples)

# 9. Elemental Fusion Vortex & Cataclysmic Blast (900ms)
static func generate_fusion() -> AudioStreamWAV:
	var duration: float = 0.9
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var val: float = 0.0
		
		if t < 0.35:
			# Vortex charge-up: rising FM wobble
			var phase: float = t / 0.35
			var mod_freq: float = 12.0 + phase * 30.0
			var carrier_freq: float = 70.0 + phase * 260.0
			val = sin(t * carrier_freq * TAU + sin(t * mod_freq * TAU) * 3.0) * (phase * 0.7)
		else:
			# Cataclysmic elemental blast and sustained harmonic ring
			var dt: float = t - 0.35
			var env_blast: float = exp(-dt * 5.0)
			var blast_noise: float = randf_range(-0.8, 0.8) * exp(-dt * 14.0)
			var sub_boom: float = sin(dt * 55.0 * TAU) * exp(-dt * 4.0) * 0.8
			var chord: float = (sin(dt * 440.0 * TAU) + sin(dt * 659.25 * TAU) + sin(dt * 880.0 * TAU)) * 0.25 * env_blast
			val = (sub_boom + blast_noise * 0.6 + chord)
			
		samples[i] = clampf(val * 0.75, -1.0, 1.0)
		
	return create_wav_from_samples(samples)

# 10. Attack Slash / Strike (240ms)
static func generate_attack_slash() -> AudioStreamWAV:
	var duration: float = 0.24
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 18.0)
		# Swift pitch drop blade sweep (2800 Hz down to 250 Hz)
		var freq: float = 2800.0 * exp(-t * 22.0) + 250.0
		var sweep: float = sin(t * freq * TAU)
		var hiss: float = randf_range(-0.7, 0.7) * exp(-t * 25.0)
		samples[i] = (sweep * 0.6 + hiss * 0.6) * env * 0.7
		
	return create_wav_from_samples(samples)

# 11. Damage Impact / Hit (280ms)
static func generate_damage_hit() -> AudioStreamWAV:
	var duration: float = 0.28
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 15.0)
		var sub_drop: float = sin(t * (85.0 * exp(-t * 14.0) + 35.0) * TAU)
		var punch: float = randf_range(-0.9, 0.9) * exp(-t * 40.0)
		samples[i] = (sub_drop * 0.7 + punch * 0.5) * env * 0.75
		
	return create_wav_from_samples(samples)

# 12. Beast Defeat / Collapse (500ms)
static func generate_beast_defeat() -> AudioStreamWAV:
	var duration: float = 0.5
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 6.0)
		var freq: float = 160.0 * exp(-t * 7.0) + 30.0
		var rumble: float = sin(t * freq * TAU)
		var dust: float = randf_range(-0.5, 0.5) * exp(-t * 5.0)
		samples[i] = (rumble * 0.6 + dust * 0.4) * env * 0.65
		
	return create_wav_from_samples(samples)

# 13. Spell Cast / Arcane Shimmer (450ms)
static func generate_spell_cast() -> AudioStreamWAV:
	var duration: float = 0.45
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 7.0)
		# Rapid FM sparkle: carrier 1200 -> 2400 Hz
		var carrier: float = 1200.0 + t * 2400.0
		var mod: float = sin(t * 35.0 * TAU) * 400.0
		var sparkle: float = sin(t * (carrier + mod) * TAU)
		var wind: float = randf_range(-0.3, 0.3) * (1.0 - t / duration)
		samples[i] = (sparkle * 0.5 + wind * 0.3) * env * 0.6
		
	return create_wav_from_samples(samples)

# 14. Status Effect Applied (Stun / Freeze) (300ms)
static func generate_status_applied() -> AudioStreamWAV:
	var duration: float = 0.3
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 12.0)
		# Rapid pulses (crystalline ice crack / electrical sizzle)
		var pulse: float = sin(t * 1800.0 * TAU) * (1.0 if int(t * 80.0) % 2 == 0 else -1.0)
		var buzz: float = randf_range(-0.5, 0.5) * exp(-t * 20.0)
		samples[i] = (pulse * 0.5 + buzz * 0.5) * env * 0.55
		
	return create_wav_from_samples(samples)

# 15. Resonant Turn Change Gong (550ms)
static func generate_turn_change() -> AudioStreamWAV:
	var duration: float = 0.55
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 6.0)
		# Warm resonant bell chime (523 Hz + 784 Hz + 1318 Hz)
		var b1: float = sin(t * 523.25 * TAU) * 0.5
		var b2: float = sin(t * 783.99 * TAU) * 0.35
		var b3: float = sin(t * 1318.51 * TAU) * 0.2
		samples[i] = (b1 + b2 + b3) * env * 0.6
		
	return create_wav_from_samples(samples)

# 16. Royal Victory Fanfare (1.3s)
static func generate_victory() -> AudioStreamWAV:
	var duration: float = 1.3
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	# Fanfare notes: C5 (523), E5 (659), G5 (784), C6 (1046)
	var freqs = [523.25, 659.25, 783.99, 1046.5]
	var times = [0.0, 0.16, 0.32, 0.48]
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var val: float = 0.0
		
		for n in range(freqs.size()):
			if t >= times[n]:
				var dt: float = t - times[n]
				var f: float = freqs[n]
				var decay: float = exp(-dt * 3.5)
				# Brassy wave: fundamental + 2nd harmonic + 3rd harmonic
				var brass: float = sin(dt * f * TAU) + 0.3 * sin(dt * f * 2.0 * TAU) + 0.15 * sin(dt * f * 3.0 * TAU)
				val += brass * decay * (0.22 if n < 3 else 0.4)
				
		samples[i] = clampf(val * 0.8, -1.0, 1.0)
		
	return create_wav_from_samples(samples)

# 17. Somber Defeat Chord (1.3s)
static func generate_defeat() -> AudioStreamWAV:
	var duration: float = 1.3
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	# Minor descending progression: A3 (220), F3 (174.6), D3 (146.8)
	var freqs = [220.0, 174.61, 146.83]
	var times = [0.0, 0.25, 0.5]
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var val: float = 0.0
		
		for n in range(freqs.size()):
			if t >= times[n]:
				var dt: float = t - times[n]
				var f: float = freqs[n]
				var decay: float = exp(-dt * 2.8)
				var tone: float = sin(dt * f * TAU) + 0.2 * sin(dt * f * 2.0 * TAU)
				val += tone * decay * 0.3
				
		samples[i] = clampf(val * 0.7, -1.0, 1.0)
		
	return create_wav_from_samples(samples)

# 18. Modern UI Click (25ms)
static func generate_ui_click() -> AudioStreamWAV:
	var duration: float = 0.025
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 140.0)
		var wave: float = sin(t * 1200.0 * TAU)
		var click: float = randf_range(-0.5, 0.5)
		samples[i] = (wave * 0.7 + click * 0.3) * env * 0.5
		
	return create_wav_from_samples(samples)

# 19. Looping Thematic Main Menu BGM Fallback (8.0s D-minor draconic harp & orchestral pad loop)
static func generate_main_menu_bgm() -> AudioStreamWAV:
	var duration: float = 8.0
	var num_samples: int = int(SAMPLE_RATE * duration)
	var samples: Array[float] = []
	samples.resize(num_samples)
	var chord_d: Array[float] = [146.83, 220.0, 293.66, 349.23, 440.0]
	var chord_bb: Array[float] = [116.54, 174.61, 233.08, 293.66, 349.23]
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		# 4 seconds D minor, 4 seconds Bb Major
		var chord: Array[float] = chord_d if t < 4.0 else chord_bb
		var pad: float = 0.0
		for f in chord:
			pad += (sin(t * f * TAU) + 0.4 * sin(t * f * 2.0 * TAU) + 0.15 * sin(t * f * 3.0 * TAU)) * 0.06
		# Cello root drone
		var root_f: float = 73.42 if t < 4.0 else 58.27
		var bass: float = (sin(t * root_f * TAU) + 0.5 * sin(t * root_f * 2.0 * TAU)) * 0.16
		# Soft harp note every 1.0s
		var harp_t: float = fmod(t, 1.0)
		var harp_f: float = chord[int(t * 2.0) % chord.size()] * 2.0
		var harp: float = sin(harp_t * harp_f * TAU) * exp(-harp_t * 3.5) * 0.12
		samples[i] = clampf(pad + bass + harp, -1.0, 1.0)
	var wav := create_wav_from_samples(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	return wav

