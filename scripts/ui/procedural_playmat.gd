class_name ProceduralPlaymat
extends Control

## Procedural Playmat for Elemental Beasts TCG
## Synthesizes the celestial fantasy TCG battlemat at runtime directly in GDScript.
## Faithfully reproduces the aesthetic of the reference arena:
## - Cosmic violet/indigo nebula sky with glittering starfield & cross-flares
## - Floating crystal crags on left & right with glowing purple crystal spires & cyan waterfalls
## - Bottom-center golden celestial citadel silhouette with radiating sunbeams & spires
## - Central elliptical golden arcane ritual rings with rune notches & starburst flare
## - Outer double-line golden filigree border with baroque flourishes & faceted purple diamond gems

@export var animate_pulse: bool = true
@export var show_summoning_circle: bool = true

var _noise_texture: ImageTexture = null
var _anim_time: float = 0.0

# 6 Principal Element palette matching authentic card frames
const ELEMENT_COLORS = {
	"fire": Color(1.0, 0.32, 0.18, 0.95),        # Radiant Crimson-Flame
	"lightning": Color(1.0, 0.84, 0.12, 0.95),   # Electric Golden Bolt
	"wind": Color(0.15, 0.88, 0.55, 0.95),        # Emerald Gale Swirl
	"ice": Color(0.20, 0.80, 1.0, 0.95),         # Glacial Frost Blue
	"shadow": Color(0.72, 0.28, 0.95, 0.95),      # Abyssal Void Purple
	"mechanical": Color(0.88, 0.55, 0.68, 0.95)   # Cybernetic Bronze Gear
}

const ELEMENT_NAMES = ["fire", "lightning", "wind", "ice", "shadow", "mechanical"]

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_generate_noise_overlay()
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if animate_pulse:
		_anim_time += delta
		queue_redraw()

func _generate_noise_overlay() -> void:
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	var img = noise.get_image(512, 512)
	if img:
		_noise_texture = ImageTexture.create_from_image(img)

func _get_game_state() -> GameState:
	var p = get_parent()
	if p and "game_state" in p and p.game_state is GameState:
		return p.game_state
	return null

func _draw() -> void:
	var w = size.x
	var h = size.y
	if w <= 0 or h <= 0:
		return

	# 1. Cosmic Deep Sky & Nebulae
	_draw_cosmic_space(w, h)

	# 2. Left & Right Floating Crystal Islands with Waterfalls
	_draw_floating_crystal_islands(w, h)

	# 3. Bottom Celestial Golden Citadel Spire Silhouette & Halo
	_draw_golden_citadel(w, h)

	# 4. Central Golden Arcane Concentric Magic Rings
	if show_summoning_circle:
		_draw_arcane_summoning_rings(w, h)

	# 5. Outer Golden Filigree Border & Purple Diamond Corner Gems
	_draw_ornate_filigree_frame(w, h)

# ==============================================================================
# 1. Cosmic Deep Space, Nebulae, and Sparkling Starfield
# ==============================================================================
func _draw_cosmic_space(w: float, h: float) -> void:
	# Vertical twilight gradient bands (deep abyss -> celestial magenta nebula -> deep abyss)
	var bands = 64
	var c_top = Color(0.04, 0.01, 0.10)       # Dark cosmic void
	var c_upper = Color(0.12, 0.04, 0.25)     # Deep indigo
	var c_mid = Color(0.25, 0.08, 0.44)       # Radiant celestial purple
	var c_lower = Color(0.13, 0.04, 0.24)     # Deep twilight
	var c_bot = Color(0.05, 0.01, 0.11)       # Bottom void

	for i in range(bands):
		var t = float(i) / float(bands - 1)
		var c: Color
		if t < 0.25:
			c = c_top.lerp(c_upper, t / 0.25)
		elif t < 0.50:
			c = c_upper.lerp(c_mid, (t - 0.25) / 0.25)
		elif t < 0.75:
			c = c_mid.lerp(c_lower, (t - 0.50) / 0.25)
		else:
			c = c_lower.lerp(c_bot, (t - 0.75) / 0.25)
		draw_rect(Rect2(0, h * float(i) / bands, w, h / bands + 1.0), c)

	# Cosmic nebula clouds using noise texture
	if _noise_texture:
		var step = 512.0
		var x = 0.0
		while x < w:
			var y = 0.0
			while y < h:
				# Violet dust layer
				draw_texture_rect(_noise_texture, Rect2(x, y, step, step), false, Color(0.85, 0.45, 1.0, 0.09))
				# Cyan energetic dust layer offset
				draw_texture_rect(_noise_texture, Rect2(x + 40, y + 40, step, step), false, Color(0.20, 0.75, 1.0, 0.05))
				y += step
			x += step

	# Sparkling Starfield (deterministic pseudo-random math)
	var star_count = 140
	var pulse = 0.5 + 0.5 * sin(_anim_time * 2.4)
	for i in range(star_count):
		var sx = float((i * 179 + 43) % int(w))
		var sy = float((i * 283 + 97) % int(h))
		# Star twinkling
		var star_pulse = 0.5 + 0.5 * sin(_anim_time * 3.0 + float(i * 13))
		var star_alpha = 0.35 + 0.55 * star_pulse
		var is_bright = (i % 9 == 0)

		if is_bright:
			# 4-point cross diffraction flare on bright stars
			var flare_len = 5.0 + 3.0 * star_pulse
			var flare_col = Color(1.0, 0.95, 0.85, star_alpha * 0.8)
			draw_line(Vector2(sx - flare_len, sy), Vector2(sx + flare_len, sy), flare_col, 1.0, true)
			draw_line(Vector2(sx, sy - flare_len), Vector2(sx, sy + flare_len), flare_col, 1.0, true)
			draw_circle(Vector2(sx, sy), 1.8, Color(1.0, 1.0, 1.0, star_alpha))
		else:
			var s_rad = 0.8 + 0.7 * float((i * 7) % 3)
			draw_circle(Vector2(sx, sy), s_rad, Color(0.90, 0.88, 1.0, star_alpha * 0.75))

# ==============================================================================
# 2. Floating Crystal Islands with Glowing Spires & Waterfalls
# ==============================================================================
func _draw_floating_crystal_islands(w: float, h: float) -> void:
	# --- LEFT FLOATING ISLANDS ---
	# Upper Left Crag
	_draw_crag_island(Vector2(0, h * 0.22), Vector2(w * 0.18, h * 0.42), true)
	# Upper Left Crystal Spires
	_draw_crystal_cluster(Vector2(w * 0.06, h * 0.22), 48.0, Color(0.78, 0.35, 1.0))
	_draw_crystal_cluster(Vector2(w * 0.12, h * 0.26), 36.0, Color(0.65, 0.25, 0.95))
	# Upper Left Cascading Waterfall
	_draw_waterfall(Vector2(w * 0.09, h * 0.35), 70.0, 14.0)

	# Lower Left Crag
	_draw_crag_island(Vector2(0, h * 0.54), Vector2(w * 0.16, h * 0.76), true)
	# Lower Left Crystal Spires
	_draw_crystal_cluster(Vector2(w * 0.05, h * 0.54), 42.0, Color(0.82, 0.40, 1.0))
	# Lower Left Waterfall
	_draw_waterfall(Vector2(w * 0.08, h * 0.67), 65.0, 12.0)

	# --- RIGHT FLOATING ISLANDS ---
	# Upper Right Crag
	_draw_crag_island(Vector2(w * 0.82, h * 0.22), Vector2(w, h * 0.42), false)
	# Upper Right Crystal Spires
	_draw_crystal_cluster(Vector2(w * 0.94, h * 0.22), 48.0, Color(0.78, 0.35, 1.0))
	_draw_crystal_cluster(Vector2(w * 0.88, h * 0.26), 36.0, Color(0.65, 0.25, 0.95))
	# Upper Right Cascading Waterfall
	_draw_waterfall(Vector2(w * 0.91, h * 0.35), 70.0, 14.0)

	# Lower Right Crag
	_draw_crag_island(Vector2(w * 0.84, h * 0.54), Vector2(w, h * 0.76), false)
	# Lower Right Crystal Spires
	_draw_crystal_cluster(Vector2(w * 0.95, h * 0.54), 42.0, Color(0.82, 0.40, 1.0))
	# Lower Right Waterfall
	_draw_waterfall(Vector2(w * 0.92, h * 0.67), 65.0, 12.0)

func _draw_crag_island(top_left: Vector2, bot_right: Vector2, is_left: bool) -> void:
	var pts = PackedVector2Array()
	var mid_y = top_left.y + (bot_right.y - top_left.y) * 0.4
	var col_crag = Color(0.11, 0.05, 0.18, 0.96)
	var col_edge = Color(0.24, 0.12, 0.36, 0.85)

	if is_left:
		pts.append(Vector2(top_left.x, mid_y))
		pts.append(Vector2(top_left.x + (bot_right.x - top_left.x) * 0.7, top_left.y))
		pts.append(Vector2(bot_right.x, mid_y))
		pts.append(Vector2(top_left.x + (bot_right.x - top_left.x) * 0.5, bot_right.y))
		pts.append(Vector2(top_left.x, bot_right.y * 0.9))
	else:
		pts.append(Vector2(bot_right.x, mid_y))
		pts.append(Vector2(bot_right.x - (bot_right.x - top_left.x) * 0.7, top_left.y))
		pts.append(Vector2(top_left.x, mid_y))
		pts.append(Vector2(bot_right.x - (bot_right.x - top_left.x) * 0.5, bot_right.y))
		pts.append(Vector2(bot_right.x, bot_right.y * 0.9))

	draw_colored_polygon(pts, col_crag)
	draw_polyline(pts, col_edge, 2.0)

func _draw_crystal_cluster(base_pos: Vector2, height: float, color: Color) -> void:
	# 3 crystalline shard spires rising up
	for off_x in [-8.0, 0.0, 10.0]:
		var h_spire = height * (1.0 if off_x == 0.0 else 0.72)
		var w_spire = 7.0 if off_x == 0.0 else 5.0
		var pts = PackedVector2Array()
		pts.append(Vector2(base_pos.x + off_x, base_pos.y - h_spire))
		pts.append(Vector2(base_pos.x + off_x + w_spire, base_pos.y))
		pts.append(Vector2(base_pos.x + off_x - w_spire, base_pos.y))
		draw_colored_polygon(pts, color)
		# Specular facet line
		draw_line(
			Vector2(base_pos.x + off_x, base_pos.y - h_spire),
			Vector2(base_pos.x + off_x, base_pos.y),
			Color(1.0, 0.90, 1.0, 0.90),
			1.5,
			true
		)

func _draw_waterfall(start_pos: Vector2, length: float, width: float) -> void:
	# Cascading cyan luminescent water stream
	var pts_l = PackedVector2Array()
	var pts_r = PackedVector2Array()
	var wave = sin(_anim_time * 4.0) * 1.5
	for step in range(7):
		var frac = float(step) / 6.0
		var cur_y = start_pos.y + frac * length
		var cur_w = width * (1.0 - frac * 0.3)
		pts_l.append(Vector2(start_pos.x - cur_w * 0.5 + wave * frac, cur_y))
		pts_r.append(Vector2(start_pos.x + cur_w * 0.5 + wave * frac, cur_y))

	var poly = PackedVector2Array()
	poly.append_array(pts_l)
	pts_r.reverse()
	poly.append_array(pts_r)
	draw_colored_polygon(poly, Color(0.28, 0.82, 1.0, 0.65))

	# Froth & mist at bottom of falls
	var froth_pos = Vector2(start_pos.x, start_pos.y + length)
	draw_circle(froth_pos, 7.0, Color(0.85, 0.95, 1.0, 0.40))
	draw_circle(froth_pos, 4.0, Color(1.0, 1.0, 1.0, 0.70))

# ==============================================================================
# 3. Bottom Celestial Golden Citadel Spire Silhouette & Radiant Sunbeams
# ==============================================================================
func _draw_golden_citadel(w: float, h: float) -> void:
	var c_x = w * 0.5
	var base_y = h

	# 1. Radiant Golden Horizon Halo
	var halo_center = Vector2(c_x, h * 0.88)
	for k in range(5):
		var r_halo = 120.0 + float(k) * 28.0
		var a_halo = 0.14 * (1.0 - float(k) / 5.0)
		draw_circle(halo_center, r_halo, Color(1.0, 0.80, 0.25, a_halo))

	# 2. Rising Golden Sunbeams radiating upwards
	var beam_count = 9
	for b in range(beam_count):
		var angle = -PI * 0.5 + (float(b) - 4.0) * 0.16
		var b_dir = Vector2(cos(angle), sin(angle))
		var b_len = 240.0 + 30.0 * sin(_anim_time * 2.0 + float(b))
		var b_col = Color(1.0, 0.85, 0.35, 0.12)
		draw_line(halo_center, halo_center + b_dir * b_len, b_col, 8.0, false)

	# 3. Multi-tier Gothic / Draconic Citadel Spires
	var spires = [
		[-180.0, 55.0, 14.0],
		[-140.0, 75.0, 16.0],
		[-105.0, 105.0, 18.0],
		[-70.0, 135.0, 20.0],
		[-35.0, 165.0, 22.0],
		[0.0, 200.0, 26.0],     # Central Great Spire
		[35.0, 165.0, 22.0],
		[70.0, 135.0, 20.0],
		[105.0, 105.0, 18.0],
		[140.0, 75.0, 16.0],
		[180.0, 55.0, 14.0]
	]

	var col_citadel = Color(0.10, 0.04, 0.16, 0.98)
	var col_gold_tip = Color(1.0, 0.88, 0.40, 0.95)

	for sp in spires:
		var sx = c_x + sp[0]
		var s_height = sp[1]
		var s_width = sp[2]

		var s_pts = PackedVector2Array()
		s_pts.append(Vector2(sx, base_y - s_height))
		s_pts.append(Vector2(sx + s_width * 0.5, base_y))
		s_pts.append(Vector2(sx - s_width * 0.5, base_y))
		draw_colored_polygon(s_pts, col_citadel)

		# Glowing golden spire pinnacle tip
		draw_circle(Vector2(sx, base_y - s_height), 2.8, col_gold_tip)
		# Spire crest light line
		draw_line(
			Vector2(sx, base_y - s_height),
			Vector2(sx, base_y - s_height + 22.0),
			Color(1.0, 0.85, 0.35, 0.85),
			1.5,
			true
		)

# ==============================================================================
# 4. Central Golden Arcane Concentric Magic Rings
# ==============================================================================
func _draw_arcane_summoning_rings(w: float, h: float) -> void:
	var c = Vector2(w * 0.5, h * 0.505)
	var pulse = 0.5 + 0.5 * sin(_anim_time * 1.8)

	# 1. Outer Elliptical Ring
	var r_outer_x = 360.0
	var r_outer_y = 52.0
	var pts_out = PackedVector2Array()
	for s in range(65):
		var ang = TAU * float(s) / 64.0
		pts_out.append(c + Vector2(cos(ang) * r_outer_x, sin(ang) * r_outer_y))
	draw_polyline(pts_out, Color(1.0, 0.80, 0.30, 0.38 + 0.12 * pulse), 2.2, true)

	# Radial Compass Ticks on outer ring
	var tick_count = 16
	for t in range(tick_count):
		var t_ang = TAU * float(t) / float(tick_count)
		var p1 = c + Vector2(cos(t_ang) * (r_outer_x - 6.0), sin(t_ang) * (r_outer_y - 3.0))
		var p2 = c + Vector2(cos(t_ang) * (r_outer_x + 6.0), sin(t_ang) * (r_outer_y + 3.0))
		draw_line(p1, p2, Color(1.0, 0.88, 0.40, 0.55), 1.8, true)

	# 2. Middle Orbital Ring
	var r_mid_x = 270.0
	var r_mid_y = 38.0
	var pts_mid = PackedVector2Array()
	for s in range(65):
		var ang = TAU * float(s) / 64.0
		pts_mid.append(c + Vector2(cos(ang) * r_mid_x, sin(ang) * r_mid_y))
	draw_polyline(pts_mid, Color(1.0, 0.75, 0.25, 0.28 + 0.10 * pulse), 1.5, true)

	# Orbital Golden Rune Nodes
	for n in range(8):
		var n_ang = TAU * float(n) / 8.0 + _anim_time * 0.2
		var n_pos = c + Vector2(cos(n_ang) * r_mid_x, sin(n_ang) * r_mid_y)
		draw_circle(n_pos, 3.2, Color(1.0, 0.90, 0.45, 0.85))

	# 3. Inner Focal Ring
	var r_in_x = 180.0
	var r_in_y = 25.0
	var pts_in = PackedVector2Array()
	for s in range(65):
		var ang = TAU * float(s) / 64.0
		pts_in.append(c + Vector2(cos(ang) * r_in_x, sin(ang) * r_in_y))
	draw_polyline(pts_in, Color(1.0, 0.85, 0.40, 0.50 + 0.20 * pulse), 2.0, true)

	# Central Golden Light Flare & Starburst
	var flare_len_x = 65.0 + 15.0 * pulse
	var flare_len_y = 10.0 + 4.0 * pulse
	draw_line(c - Vector2(flare_len_x, 0), c + Vector2(flare_len_x, 0), Color(1.0, 0.90, 0.50, 0.80), 2.5, true)
	draw_line(c - Vector2(0, flare_len_y), c + Vector2(0, flare_len_y), Color(1.0, 0.90, 0.50, 0.80), 2.5, true)
	draw_circle(c, 5.0, Color(1.0, 1.0, 0.95, 0.95))

# ==============================================================================
# 5. Outer Golden Filigree Border & Faceted Purple Diamond Corner Gems
# ==============================================================================
func _draw_ornate_filigree_frame(w: float, h: float) -> void:
	var inset_outer = 6.0
	var inset_inner = 12.0
	var col_outer = Color(0.85, 0.68, 0.25, 0.95)     # Antique bright gold
	var col_inner = Color(1.0, 0.88, 0.45, 0.65)      # Radiant hairline gold

	var r_out = Rect2(inset_outer, inset_outer, w - inset_outer * 2.0, h - inset_outer * 2.0)
	var r_in = Rect2(inset_inner, inset_inner, w - inset_inner * 2.0, h - inset_inner * 2.0)

	# Outer border with corner rounding
	_draw_rounded_rect(r_out, 12.0, col_outer, 3.0)
	# Inner gold hairline
	_draw_rounded_rect(r_in, 8.0, col_inner, 1.5)

	# Faceted Purple Diamond Gems at 4 corners
	var gem_inset = 22.0
	var corners = [
		Vector2(gem_inset, gem_inset),
		Vector2(w - gem_inset, gem_inset),
		Vector2(gem_inset, h - gem_inset),
		Vector2(w - gem_inset, h - gem_inset)
	]

	for cp in corners:
		_draw_faceted_purple_diamond(cp, 15.0)

	# Midpoint Diamond Gems at edges
	_draw_faceted_purple_diamond(Vector2(w * 0.5, inset_outer + 3.0), 9.0)
	_draw_faceted_purple_diamond(Vector2(w * 0.5, h - inset_outer - 3.0), 9.0)

func _draw_faceted_purple_diamond(center: Vector2, radius: float) -> void:
	# Gold setting bezel
	var pts_bezel = PackedVector2Array([
		center + Vector2(0, -radius - 2.5),
		center + Vector2(radius + 2.5, 0),
		center + Vector2(0, radius + 2.5),
		center + Vector2(-radius - 2.5, 0)
	])
	draw_colored_polygon(pts_bezel, Color(0.92, 0.74, 0.28, 0.98))

	# Violet / Magenta gemstone
	var pts_gem = PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0)
	])
	draw_colored_polygon(pts_gem, Color(0.68, 0.18, 0.92, 0.98))

	# Gem facets & specular highlight
	draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), Color(0.85, 0.40, 1.0, 0.8), 1.2, true)
	draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), Color(0.85, 0.40, 1.0, 0.8), 1.2, true)
	draw_circle(center - Vector2(radius * 0.25, radius * 0.25), radius * 0.25, Color(1.0, 0.85, 1.0, 0.9))

func _draw_rounded_rect(r: Rect2, corner_rad: float, color: Color, line_width: float) -> void:
	var cr = minf(corner_rad, minf(r.size.x, r.size.y) * 0.5)
	var pts = PackedVector2Array()

	# Top edge
	pts.append(Vector2(r.position.x + cr, r.position.y))
	pts.append(Vector2(r.end.x - cr, r.position.y))
	# Top-right corner
	for s in range(5):
		var a = -PI * 0.5 + float(s) * (PI * 0.5) / 4.0
		pts.append(Vector2(r.end.x - cr + cos(a) * cr, r.position.y + cr + sin(a) * cr))
	# Right edge
	pts.append(Vector2(r.end.x, r.end.y - cr))
	# Bottom-right corner
	for s in range(5):
		var a = 0.0 + float(s) * (PI * 0.5) / 4.0
		pts.append(Vector2(r.end.x - cr + cos(a) * cr, r.end.y - cr + sin(a) * cr))
	# Bottom edge
	pts.append(Vector2(r.position.x + cr, r.end.y))
	# Bottom-left corner
	for s in range(5):
		var a = PI * 0.5 + float(s) * (PI * 0.5) / 4.0
		pts.append(Vector2(r.position.x + cr + cos(a) * cr, r.end.y - cr + sin(a) * cr))
	# Left edge
	pts.append(Vector2(r.position.x, r.position.y + cr))
	# Top-left corner
	for s in range(5):
		var a = PI + float(s) * (PI * 0.5) / 4.0
		pts.append(Vector2(r.position.x + cr + cos(a) * cr, r.position.y + cr + sin(a) * cr))

	draw_polyline(pts, color, line_width, true)
