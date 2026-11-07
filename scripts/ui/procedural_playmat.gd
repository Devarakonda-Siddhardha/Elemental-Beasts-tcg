class_name ProceduralPlaymat
extends Control

## Procedural Playmat for Elemental Beasts TCG
## Synthesizes a fantasy TCG battlemat at runtime directly in GDScript.
## Inspired by authentic AAA dragon-themed TCG arenas:
## - FastNoiseLite procedural slate & woven-cloth grain overlay
## - 4 Corner Elemental Dragon Auras (Fire top-left, Ice top-right, Shadow bottom-left, Lightning bottom-right)
## - Ornate Top & Bottom Plaque Pods (Life Crest, 5-Gem Mana Battery, 6-Element Stone Pile sockets)
## - Glowing Neon Card Slots with 8-Point Radiant Crosshair Reticles
##   * Opponent: Electric Cyan-Blue Neon + Cyan Reticles
##   * Player: Fiery Amber-Gold Neon + Golden Reticles
## - Ornate Battlefield Banners: "OPPONENT'S BATTLEFIELD" & "YOUR BATTLEFIELD"
## - Central "ELEMENTAL BEAST TCG" Golden Draconic Altar Crest
## - Left & Right Columns: Deck (40), Discard, Stone Pile & Banish Zones

@export var animate_pulse: bool = true
@export var show_summoning_circle: bool = true
@export var show_slot_brackets: bool = true

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

	# Fantasy sky arena backdrop (all HUD panels / slots are real UI nodes)
	_draw_sky_arena(w, h)
	_draw_corner_dragon_auras(w, h)

# ==============================================================================
# 0. Fantasy Sky Arena (purple twilight sky, floating peaks, glowing altar ring)
# ==============================================================================
func _draw_sky_arena(w: float, h: float) -> void:
	# Vertical twilight gradient
	var bands = 48
	var top_col = Color(0.10, 0.05, 0.22)
	var mid_col = Color(0.36, 0.16, 0.48)
	var low_col = Color(0.12, 0.06, 0.20)
	for i in range(bands):
		var t = float(i) / float(bands - 1)
		var c: Color
		if t < 0.5:
			c = top_col.lerp(mid_col, t / 0.5)
		else:
			c = mid_col.lerp(low_col, (t - 0.5) / 0.5)
		draw_rect(Rect2(0, h * float(i) / bands, w, h / bands + 1.0), c)

	# Noise clouds
	if _noise_texture:
		var step = 512.0
		var x = 0.0
		while x < w:
			var y = 0.0
			while y < h:
				draw_texture_rect(_noise_texture, Rect2(x, y, step, step), false, Color(0.85, 0.55, 1.0, 0.10))
				y += step
			x += step

	# Horizon glow
	var hy = h * 0.5
	for i in range(10):
		var a = 0.05 * (1.0 - float(i) / 10.0)
		draw_rect(Rect2(0, hy - i * 9.0, w, i * 18.0), Color(1.0, 0.55, 0.85, a))

	# Distant mountain silhouettes (procedural, deterministic)
	_draw_mountain_range(w, hy + 10.0, 60.0, Color(0.22, 0.12, 0.34, 0.95), 1.3)
	_draw_mountain_range(w, h * 0.80, 90.0, Color(0.14, 0.08, 0.24, 0.95), 2.1)
	_draw_mountain_range(w, h * 0.98, 70.0, Color(0.08, 0.04, 0.14, 1.0), 3.7)

	# Central summoning ring between the two battlefields
	var c = Vector2(w * 0.52, hy)
	var pulse = 0.5 + 0.5 * sin(_anim_time * 1.6)
	for k in range(3):
		var rx = 300.0 + k * 22.0
		var pts = PackedVector2Array()
		for s in range(65):
			var ang = TAU * float(s) / 64.0
			pts.append(c + Vector2(cos(ang) * rx, sin(ang) * rx * 0.16))
		draw_polyline(pts, Color(1.0, 0.75, 0.35, 0.18 + 0.12 * pulse - k * 0.05), 2.0, true)

	# Vignette
	for i in range(6):
		var r_frac = float(i) / 6.0
		var max_r = maxf(w, h) * 0.7
		draw_arc(Vector2(w * 0.5, h * 0.5), max_r * (0.6 + r_frac * 0.5), 0, TAU, 48, Color(0.02, 0.0, 0.05, r_frac * 0.35), max_r * 0.14)

func _draw_mountain_range(w: float, base_y: float, amp: float, col: Color, seed_f: float) -> void:
	var pts = PackedVector2Array()
	pts.append(Vector2(0, base_y + amp))
	var steps = 40
	for i in range(steps + 1):
		var x = w * float(i) / steps
		var n = sin(x * 0.011 * seed_f) * 0.5 + sin(x * 0.027 + seed_f * 2.0) * 0.35 + sin(x * 0.063 + seed_f) * 0.15
		pts.append(Vector2(x, base_y - absf(n) * amp))
	pts.append(Vector2(w, base_y + amp))
	pts.append(Vector2(w, base_y + amp * 3.0))
	pts.append(Vector2(0, base_y + amp * 3.0))
	draw_colored_polygon(pts, col)

# ==============================================================================
# 1. Base Mat Surface & Vignette
# ==============================================================================
func _draw_mat_surface(w: float, h: float) -> void:
	# Deep obsidian base
	draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.05, 0.08, 1.0))

	# Procedural noise grain overlay (tiled)
	if _noise_texture:
		var grain_mod = Color(0.35, 0.45, 0.65, 0.07)
		var step = 512.0
		var x = 0.0
		while x < w:
			var y = 0.0
			while y < h:
				var draw_w = minf(step, w - x)
				var draw_h = minf(step, h - y)
				draw_texture_rect_region(
					_noise_texture,
					Rect2(x, y, draw_w, draw_h),
					Rect2(0, 0, draw_w, draw_h),
					grain_mod
				)
				y += step
			x += step

	# Radial Vignette
	var center = Vector2(w * 0.5, h * 0.5)
	var max_r = maxf(w, h) * 0.65
	for i in range(6):
		var r_frac = float(i) / 6.0
		var r = max_r * (0.50 + r_frac * 0.50)
		var alpha = r_frac * r_frac * 0.60
		draw_arc(center, r, 0, TAU, 32, Color(0.01, 0.01, 0.02, alpha), max_r * 0.15)

# ==============================================================================
# 2. 4 Corner Elemental Dragon Auras (Fire, Ice, Shadow, Lightning)
# ==============================================================================
func _draw_corner_dragon_auras(w: float, h: float) -> void:
	var pulse = 0.5 + 0.5 * sin(_anim_time * 2.0)
	var corner_r = 140.0 + pulse * 12.0

	# Top-Left: Fire Dragon Aura (Radiant Crimson / Ember Flame)
	_draw_corner_tendrils(Vector2.ZERO, corner_r, Color(1.0, 0.25, 0.08, 0.22), Color(1.0, 0.65, 0.10, 0.35), 0.0, PI * 0.5)

	# Top-Right: Ice Dragon Aura (Glacial Frost Azure / Cyan Shards)
	_draw_corner_tendrils(Vector2(w, 0), corner_r, Color(0.10, 0.75, 1.0, 0.22), Color(0.60, 0.95, 1.0, 0.35), PI * 0.5, PI)

	# Bottom-Left: Shadow Dragon Aura (Abyssal Void Violet / Indigo Vortex)
	_draw_corner_tendrils(Vector2(0, h), corner_r, Color(0.55, 0.15, 0.85, 0.22), Color(0.85, 0.40, 1.0, 0.35), 1.5 * PI, TAU)

	# Bottom-Right: Lightning Dragon Aura (Electric Gold / Lightning Arcs)
	_draw_corner_tendrils(Vector2(w, h), corner_r, Color(1.0, 0.80, 0.10, 0.22), Color(1.0, 0.95, 0.45, 0.35), PI, 1.5 * PI)

func _draw_corner_tendrils(origin: Vector2, max_radius: float, base_col: Color, bright_col: Color, a_start: float, a_end: float) -> void:
	# Concentric glowing aura arcs
	for i in range(4):
		var frac = float(i + 1) / 4.0
		var r = max_radius * frac
		var c = Color(base_col.r, base_col.g, base_col.b, base_col.a * (1.0 - frac * 0.5))
		draw_arc(origin, r, a_start, a_end, 20, c, 3.0 + frac * 4.0, true)

	# Dragon fang / flame rays radiating from corner
	var ray_count = 5
	for j in range(ray_count):
		var a = a_start + float(j) * (a_end - a_start) / float(ray_count - 1)
		var dir = Vector2(cos(a), sin(a))
		var len = max_radius * (0.65 + 0.35 * sin(_anim_time * 3.0 + float(j)))
		draw_line(origin + dir * 15.0, origin + dir * len, bright_col, 1.5, true)

# ==============================================================================
# 3. Stitched Perimeter & Golden Filigree
# ==============================================================================
func _draw_stitched_borders(w: float, h: float) -> void:
	var inset = 8.0
	var r_outer = Rect2(inset, inset, w - inset * 2.0, h - inset * 2.0)
	var col_trim = Color(0.35, 0.28, 0.15, 0.85) # Antique Bronze
	var col_gold = Color(0.88, 0.72, 0.30, 0.65) # Radiant Gold

	# Heavy outer border
	_draw_rounded_rect(r_outer, 12.0, col_trim, 2.5)
	# Inner gold hairline
	_draw_rounded_rect(r_outer.grow(-4.0), 9.0, col_gold, 1.2)
	# Stitched dashed lines
	_draw_dashed_stitch(r_outer.grow(-7.0))

# ==============================================================================
# 4. Top & Bottom Status Pods (Mana Battery, Stone Pile, Life Crest)
# ==============================================================================
func _draw_top_bar_pods(w: float, h: float, gs: GameState) -> void:
	var bar_y = 10.0
	var bar_h = 32.0

	# Opponent Life Crest (Heraldic Shield on Top-Left)
	var opp_hp = gs.player_hp[1] if gs else 30
	_draw_life_crest(Vector2(65.0, bar_y + bar_h * 0.5), opp_hp, "OPPONENT LIFE", Color(0.85, 0.25, 0.25))

	# Opponent Mana Pod (5 Glowing Blue Crystals)
	var opp_mana = gs.player_mana[1].current_mana if gs else 5
	var mana_pod_x = 220.0
	_draw_mana_pod(Vector2(mana_pod_x, bar_y), 190.0, bar_h, opp_mana, "OPPONENT MANA (5/5)")

	# Center Infinity Crest
	_draw_infinity_crest(Vector2(450.0, bar_y + bar_h * 0.5))

	# Opponent Stone Pile Pod (6 Elemental Sockets)
	var stone_pod_x = 490.0
	_draw_stone_pile_pod(Vector2(stone_pod_x, bar_y), 270.0, bar_h, 1, gs, "OPPONENT STONE PILE")

func _draw_bottom_bar_pods(w: float, h: float, gs: GameState) -> void:
	var bar_y = h - 42.0
	var bar_h = 32.0

	# Player Life Crest (Heraldic Shield on Bottom-Left)
	var ply_hp = gs.player_hp[0] if gs else 30
	_draw_life_crest(Vector2(65.0, bar_y + bar_h * 0.5), ply_hp, "YOUR LIFE", Color(0.95, 0.70, 0.20))

	# Player Mana Pod (5 Glowing Blue Crystals)
	var ply_mana = gs.player_mana[0].current_mana if gs else 5
	var mana_pod_x = 220.0
	_draw_mana_pod(Vector2(mana_pod_x, bar_y), 190.0, bar_h, ply_mana, "YOUR MANA (5/5)")

	# Center Infinity Crest
	_draw_infinity_crest(Vector2(450.0, bar_y + bar_h * 0.5))

	# Player Stone Pile Pod (6 Elemental Sockets)
	var stone_pod_x = 490.0
	_draw_stone_pile_pod(Vector2(stone_pod_x, bar_y), 270.0, bar_h, 0, gs, "YOUR STONE PILE")

func _draw_life_crest(center: Vector2, hp: int, title: String, accent_col: Color) -> void:
	var r = 18.0
	# Outer shield outline
	draw_circle(center, r + 3.0, Color(0.75, 0.60, 0.25, 0.9))
	draw_circle(center, r, Color(0.12, 0.04, 0.05, 0.95))
	draw_arc(center, r - 1.0, 0, TAU, 24, accent_col, 1.8, true)

	# Numeric value
	var font = ThemeDB.fallback_font
	var font_size = 13
	var hp_str = str(hp)
	var text_sz = font.get_string_size(hp_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center - Vector2(text_sz.x * 0.5, -4.0), hp_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func _draw_mana_pod(pos: Vector2, w: float, h: float, mana_count: int, title: String) -> void:
	var r_box = Rect2(pos.x, pos.y, w, h)
	# Ornate filigree backdrop
	draw_rect(r_box, Color(0.06, 0.08, 0.12, 0.9), true)
	_draw_rounded_rect(r_box, 6.0, Color(0.80, 0.65, 0.25, 0.8), 1.5)

	# 5 Glowing Blue Mana Crystals
	var gem_spacing = 28.0
	var start_x = pos.x + (w - 4.0 * gem_spacing) * 0.5
	var gem_y = pos.y + h * 0.5
	for i in range(5):
		var gem_pos = Vector2(start_x + float(i) * gem_spacing, gem_y)
		var is_active = (i < mana_count)
		_draw_mana_crystal(gem_pos, 8.0, is_active)

func _draw_mana_crystal(center: Vector2, radius: float, active: bool) -> void:
	var pulse = 0.5 + 0.5 * sin(_anim_time * 3.0 + center.x)
	var pts = PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.65, -radius * 0.3),
		center + Vector2(radius * 0.50, radius * 0.8),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.50, radius * 0.8),
		center + Vector2(-radius * 0.65, -radius * 0.3),
		center + Vector2(0, -radius)
	])

	if active:
		# Outer blue aura
		draw_circle(center, radius + 3.0 + pulse * 2.0, Color(0.0, 0.65, 1.0, 0.25 + pulse * 0.15))
		# Crystal body
		draw_colored_polygon(pts, Color(0.15, 0.65, 1.0, 0.95))
		draw_polyline(pts, Color(0.70, 0.92, 1.0, 0.95), 1.2, true)
		# Specular core
		draw_circle(center - Vector2(1.5, 2.0), 2.2, Color(1, 1, 1, 0.9))
	else:
		# Inactive / spent mana
		draw_colored_polygon(pts, Color(0.08, 0.12, 0.18, 0.6))
		draw_polyline(pts, Color(0.25, 0.35, 0.45, 0.4), 1.0, true)

func _draw_infinity_crest(center: Vector2) -> void:
	var r = 9.0
	var col_gold = Color(0.90, 0.75, 0.30, 0.85)
	draw_circle(center, 13.0, Color(0.08, 0.09, 0.12, 0.95))
	draw_arc(center - Vector2(r * 0.55, 0), r * 0.55, 0, TAU, 16, col_gold, 1.5, true)
	draw_arc(center + Vector2(r * 0.55, 0), r * 0.55, 0, TAU, 16, col_gold, 1.5, true)

func _draw_stone_pile_pod(pos: Vector2, w: float, h: float, player_id: int, gs: GameState, title: String) -> void:
	var r_box = Rect2(pos.x, pos.y, w, h)
	draw_rect(r_box, Color(0.06, 0.08, 0.12, 0.9), true)
	_draw_rounded_rect(r_box, 6.0, Color(0.80, 0.65, 0.25, 0.8), 1.5)

	# 6 Elemental Badges
	var badge_spacing = 38.0
	var start_x = pos.x + 22.0
	var badge_y = pos.y + h * 0.5

	for i in range(6):
		var el = ELEMENT_NAMES[i]
		var badge_pos = Vector2(start_x + float(i) * badge_spacing, badge_y)
		var count = 0
		if gs and player_id < gs.player_stones.size():
			count = gs.player_stones[player_id].get_stone_count(el)
		var col: Color = ELEMENT_COLORS[el]
		_draw_element_badge(badge_pos, 10.0, col, count)

func _draw_element_badge(center: Vector2, radius: float, col: Color, count: int) -> void:
	# Outer rim
	draw_circle(center, radius + 1.5, Color(0.08, 0.10, 0.14, 0.95))
	draw_circle(center, radius, col * 0.4)
	draw_arc(center, radius, 0, TAU, 16, col, 1.5, true)

	if count > 0:
		draw_circle(center, radius * 0.55, col)
		var font = ThemeDB.fallback_font
		draw_string(font, center + Vector2(radius + 2.0, 4.0), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

# ==============================================================================
# 5. Left & Right Columns (Deck, Discard, Stone, Banish)
# ==============================================================================
func _draw_side_columns(w: float, h: float, gs: GameState) -> void:
	# Left: Opponent Deck, Opponent Discard, Player Discard, Player Deck
	var left_x = 14.0
	var col_w = 78.0
	var box_h = 96.0

	var opp_deck_y = 52.0
	var opp_discard_y = 160.0
	var ply_discard_y = h - 230.0
	var ply_deck_y = h - 122.0

	var left_zones = [
		{"rect": Rect2(left_x, opp_deck_y, col_w, box_h), "label": "OPPONENT DECK", "count": (gs.player_decks[1].size() if gs else 40), "col": Color(0.85, 0.70, 0.25, 0.7)},
		{"rect": Rect2(left_x, opp_discard_y, col_w, box_h), "label": "DISCARD PILE", "count": (gs.player_discards[1].size() if gs else 0), "col": Color(0.85, 0.35, 0.35, 0.7)},
		{"rect": Rect2(left_x, ply_discard_y, col_w, box_h), "label": "YOUR DISCARD", "count": (gs.player_discards[0].size() if gs else 0), "col": Color(0.85, 0.35, 0.35, 0.7)},
		{"rect": Rect2(left_x, ply_deck_y, col_w, box_h), "label": "YOUR DECK", "count": (gs.player_decks[0].size() if gs else 40), "col": Color(0.85, 0.70, 0.25, 0.7)}
	]

	for z in left_zones:
		var r: Rect2 = z["rect"]
		var c: Color = z["col"]
		draw_rect(r, Color(0.04, 0.05, 0.08, 0.6), true)
		_draw_rounded_rect(r, 6.0, c, 1.5)
		_draw_corner_brackets(r, 12.0, c * 1.3, 1.8)

# ==============================================================================
# 6. Central Dragon Altar & Crest
# ==============================================================================
func _draw_center_altar(center_x: float, center_y: float) -> void:
	var center = Vector2(center_x, center_y)
	var pulse = 0.5 + 0.5 * sin(_anim_time * 1.8)
	var gold_aura = Color(0.92, 0.78, 0.32, 0.25 + pulse * 0.15)

	# Celestial Sunburst Halo
	var halo_r = 95.0
	draw_arc(center, halo_r, 0, TAU, 48, gold_aura, 1.5, true)
	for i in range(24):
		var a = float(i) * TAU / 24.0
		var dir = Vector2(cos(a), sin(a))
		draw_line(center + dir * (halo_r - 6.0), center + dir * halo_r, gold_aura, 1.2, true)

	# Center Draconic Ribbon Banner: "ELEMENTAL BEAST TCG"
	var banner_w = 210.0
	var banner_h = 24.0
	var banner_r = Rect2(center_x - banner_w * 0.5, center_y - banner_h * 0.5, banner_w, banner_h)
	draw_rect(banner_r, Color(0.06, 0.07, 0.10, 0.88), true)
	_draw_rounded_rect(banner_r, 4.0, Color(0.92, 0.78, 0.32, 0.85), 1.5)

	var font = ThemeDB.fallback_font
	var text_title = "ELEMENTAL BEAST TCG"
	var text_sz = font.get_string_size(text_title, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	draw_string(font, center - Vector2(text_sz.x * 0.5, -4.0), text_title, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1.0, 0.90, 0.55))

# ==============================================================================
# 7. Battlefield Summoning Slots with 8-Point Crosshair Reticles
# ==============================================================================
func _draw_battlefield_slots(center_x: float, h: float) -> void:
	var slot_w = 126.0
	var slot_h = 168.0
	var sep = 16.0
	var total_w = 4.0 * slot_w + 3.0 * sep
	var start_x = center_x - total_w * 0.5

	var opp_y = 50.0
	var ply_y = h * 0.5 - 118.0

	var pulse = 0.5 + 0.5 * sin(_anim_time * 2.2)

	# Opponent Colors: Electric Cyan Neon
	var opp_border = Color(0.18, 0.75, 1.0, 0.75)
	var opp_glow = Color(0.05, 0.50, 0.95, 0.20 + pulse * 0.10)
	var opp_reticle = Color(0.35, 0.85, 1.0, 0.65)

	# Player Colors: Fiery Amber-Gold Neon
	var ply_border = Color(1.0, 0.70, 0.18, 0.75)
	var ply_glow = Color(1.0, 0.45, 0.05, 0.20 + pulse * 0.10)
	var ply_reticle = Color(1.0, 0.85, 0.35, 0.65)

	# Header Banners
	_draw_battlefield_banner(center_x, opp_y - 12.0, "OPPONENT'S BATTLEFIELD (Max 4)", opp_border)
	_draw_battlefield_banner(center_x, ply_y + slot_h + 12.0, "YOUR BATTLEFIELD (Max 4)", ply_border)

	for i in range(4):
		var x = start_x + float(i) * (slot_w + sep)

		# --- Opponent Slot ---
		var r_opp = Rect2(x, opp_y, slot_w, slot_h)
		# Outer Glow
		_draw_rounded_rect(r_opp.grow(3.0), 9.0, opp_glow, 3.0)
		# Inner Backdrop
		draw_rect(r_opp, Color(0.04, 0.07, 0.12, 0.45), true)
		# Neon Border
		_draw_rounded_rect(r_opp, 8.0, opp_border, 1.8)
		# 8-Point Crosshair Reticle in Slot Center
		_draw_8point_crosshair(r_opp.get_center(), 22.0, opp_reticle)

		# --- Player Slot ---
		var r_ply = Rect2(x, ply_y, slot_w, slot_h)
		# Outer Glow
		_draw_rounded_rect(r_ply.grow(3.0), 9.0, ply_glow, 3.0)
		# Inner Backdrop
		draw_rect(r_ply, Color(0.08, 0.06, 0.03, 0.45), true)
		# Neon Border
		_draw_rounded_rect(r_ply, 8.0, ply_border, 1.8)
		# 8-Point Crosshair Reticle in Slot Center
		_draw_8point_crosshair(r_ply.get_center(), 22.0, ply_reticle)

## 8-Point Radiant Compass Crosshair (From reference image center-of-slot reticle)
func _draw_8point_crosshair(center: Vector2, radius: float, col: Color) -> void:
	# Center circle ring
	draw_arc(center, radius * 0.45, 0, TAU, 20, col * 0.7, 1.0, true)
	draw_circle(center, 1.8, col)

	# 4 Cardinal Spikes (Long)
	var len_card = radius
	draw_line(center + Vector2(0, -len_card), center + Vector2(0, len_card), col, 1.2, true)
	draw_line(center + Vector2(-len_card, 0), center + Vector2(len_card, 0), col, 1.2, true)

	# 4 Diagonal Spikes (Short)
	var len_diag = radius * 0.58
	var d = Vector2(len_diag, len_diag) * 0.7071
	draw_line(center - d, center + d, col * 0.75, 1.0, true)
	var d2 = Vector2(-len_diag, len_diag) * 0.7071
	draw_line(center - d2, center + d2, col * 0.75, 1.0, true)

func _draw_battlefield_banner(center_x: float, y: float, text: String, accent_col: Color) -> void:
	var font = ThemeDB.fallback_font
	var text_sz = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	var bw = text_sz.x + 40.0
	var bh = 16.0
	var r = Rect2(center_x - bw * 0.5, y - bh * 0.5, bw, bh)

	# Dark plaque with golden fangs
	draw_rect(r, Color(0.06, 0.07, 0.10, 0.85), true)
	_draw_rounded_rect(r, 3.0, accent_col * 0.8, 1.0)
	# Lateral wing arrows
	draw_line(Vector2(r.position.x - 12.0, y), Vector2(r.position.x, y), accent_col, 1.5, true)
	draw_line(Vector2(r.end.x, y), Vector2(r.end.x + 12.0, y), accent_col, 1.5, true)

	draw_string(font, Vector2(center_x - text_sz.x * 0.5, y + 3.5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.95, 0.90, 0.75))

# ==============================================================================
# Helper Vector Drawing Primitives
# ==============================================================================
func _draw_rounded_rect(r: Rect2, rad: float, col: Color, width: float = 1.0) -> void:
	var pts = PackedVector2Array()
	var segs = 6
	for i in range(segs + 1):
		var a = PI + float(i) * (PI * 0.5) / float(segs)
		pts.append(r.position + Vector2(rad, rad) + Vector2(cos(a), sin(a)) * rad)
	for i in range(segs + 1):
		var a = 1.5 * PI + float(i) * (PI * 0.5) / float(segs)
		pts.append(Vector2(r.end.x - rad, r.position.y + rad) + Vector2(cos(a), sin(a)) * rad)
	for i in range(segs + 1):
		var a = 0.0 + float(i) * (PI * 0.5) / float(segs)
		pts.append(Vector2(r.end.x - rad, r.end.y - rad) + Vector2(cos(a), sin(a)) * rad)
	for i in range(segs + 1):
		var a = 0.5 * PI + float(i) * (PI * 0.5) / float(segs)
		pts.append(Vector2(r.position.x + rad, r.end.y - rad) + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	draw_polyline(pts, col, width, true)

func _draw_corner_brackets(r: Rect2, arm: float, col: Color, width: float = 1.5) -> void:
	draw_line(r.position, r.position + Vector2(arm, 0), col, width, true)
	draw_line(r.position, r.position + Vector2(0, arm), col, width, true)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x - arm, r.position.y), col, width, true)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + arm), col, width, true)
	draw_line(r.end, r.end - Vector2(arm, 0), col, width, true)
	draw_line(r.end, r.end - Vector2(0, arm), col, width, true)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x + arm, r.end.y), col, width, true)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y - arm), col, width, true)

func _draw_dashed_stitch(r: Rect2) -> void:
	var stitch_len = 6.0
	var gap = 4.0
	var col = Color(0.40, 0.45, 0.55, 0.35)

	var x = r.position.x
	while x < r.end.x - stitch_len:
		draw_line(Vector2(x, r.position.y), Vector2(x + stitch_len, r.position.y), col, 1.0)
		draw_line(Vector2(x, r.end.y), Vector2(x + stitch_len, r.end.y), col, 1.0)
		x += stitch_len + gap

	var y = r.position.y
	while y < r.end.y - stitch_len:
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x, y + stitch_len), col, 1.0)
		draw_line(Vector2(r.end.x, y), Vector2(r.end.x, y + stitch_len), col, 1.0)
		y += stitch_len + gap
