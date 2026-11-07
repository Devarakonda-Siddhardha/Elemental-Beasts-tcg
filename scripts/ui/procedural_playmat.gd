class_name ProceduralPlaymat
extends Control

## Procedural Playmat for Elemental Beasts TCG
## Synthesizes a fantasy rubber/cloth battlemat entirely at runtime in code.
## Zero external image textures required.
##
## Features:
## - FastNoiseLite procedural slate/woven-cloth grain overlay
## - Radial vignette and depth shading
## - High-end stitched playmat perimeter with runic corner filigree
## - Central Omni-Elemental Summoning Circle with 6 animated elemental nodes
## - 4 Opponent & 4 Player etched summoning lanes with corner brackets
## - Left-side Deck and Discard etched pedestals
## - Subtle dynamic breathing pulse for elemental runes

@export var animate_pulse: bool = true
@export var show_summoning_circle: bool = true
@export var show_slot_brackets: bool = true

var _noise_texture: ImageTexture = null
var _anim_time: float = 0.0

# 6 Principal Element colors matching the game's authentic palette
const ELEMENT_COLORS = {
	"fire": Color(0.95, 0.40, 0.20, 0.85),
	"lightning": Color(0.98, 0.85, 0.25, 0.85),
	"shadow": Color(0.65, 0.25, 0.85, 0.85),
	"wind": Color(0.20, 0.85, 0.65, 0.85),
	"ice": Color(0.30, 0.75, 0.98, 0.85),
	"mechanical": Color(0.85, 0.45, 0.60, 0.85)
}

const ELEMENT_ANGLES = [
	0.0,            # Fire (East)
	PI / 3.0,       # Lightning (SE)
	2.0 * PI / 3.0, # Shadow (SW)
	PI,             # Wind (West)
	4.0 * PI / 3.0, # Ice (NW)
	5.0 * PI / 3.0  # Mechanical (NE)
]

const ELEMENT_NAMES = ["fire", "lightning", "shadow", "wind", "ice", "mechanical"]

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

func _draw() -> void:
	var w = size.x
	var h = size.y
	if w <= 0 or h <= 0:
		return

	# 1. Base Dark Slate / Obsidian Surface
	_draw_mat_surface(w, h)

	# 2. Stitched Playmat Perimeter & Corner Filigree
	_draw_stitched_borders(w, h)

	# 3. Left Piles Pedestals (Deck & Discard zones)
	_draw_left_piles_pedestals(w, h)

	# 4. Central Grand Summoning Circle & Elemental Nodes
	var play_left = 116.0
	var play_right = w - 300.0
	var center_x = play_left + (play_right - play_left) * 0.5
	var center_y = h * 0.5 - 20.0
	var center = Vector2(center_x, center_y)

	if show_summoning_circle:
		_draw_summoning_circle(center)

	# 5. Battlefield Dividing Meridian
	_draw_dividing_meridian(play_left, play_right, center_y)

	# 6. Card Summoning Lanes (4 Opponent slots, 4 Player slots)
	if show_slot_brackets:
		_draw_summoning_lanes(center_x, h)

## 1. Deep textured battlemat surface
func _draw_mat_surface(w: float, h: float) -> void:
	# Deep background fill
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.06, 0.09, 1.0))

	# Procedural noise grain overlay (tiled smoothly)
	if _noise_texture:
		var grain_mod = Color(0.4, 0.5, 0.7, 0.08)
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

	# Radial Vignette (darkens edges and focuses light on central arena)
	var center = Vector2(w * 0.5, h * 0.45)
	var max_r = maxf(w, h) * 0.65
	var ring_count = 8
	for i in range(ring_count):
		var r_frac = float(i) / float(ring_count)
		var r = max_r * (0.45 + r_frac * 0.55)
		var alpha = r_frac * r_frac * 0.65
		draw_arc(center, r, 0, TAU, 36, Color(0.01, 0.01, 0.02, alpha), max_r * 0.15)

## 2. Stitched rubber/cloth perimeter
func _draw_stitched_borders(w: float, h: float) -> void:
	var inset = 10.0
	var rect_outer = Rect2(inset, inset, w - inset * 2.0, h - inset * 2.0)
	var border_color = Color(0.22, 0.26, 0.36, 0.75)
	var border_gold = Color(0.65, 0.55, 0.30, 0.35)

	# Main rounded border
	_draw_rounded_rect(rect_outer, 12.0, border_color, 2.5)

	# Inner hairline gold foil line
	var rect_inner = Rect2(inset + 5.0, inset + 5.0, w - (inset + 5.0) * 2.0, h - (inset + 5.0) * 2.0)
	_draw_rounded_rect(rect_inner, 9.0, border_gold, 1.0)

	# Dashed stitch effect along perimeter
	_draw_dashed_stitch(rect_inner.grow(-3.0))

	# 4 Corner Filigree Diamonds
	var corners = [
		Vector2(inset + 14.0, inset + 14.0),
		Vector2(w - inset - 14.0, inset + 14.0),
		Vector2(w - inset - 14.0, h - inset - 14.0),
		Vector2(inset + 14.0, h - inset - 14.0)
	]
	for c in corners:
		_draw_diamond_filigree(c, 7.0, Color(0.85, 0.72, 0.35, 0.6))

## 3. Left-side Deck and Discard zones
func _draw_left_piles_pedestals(w: float, h: float) -> void:
	var left_x = 14.0
	var pile_w = 76.0
	var pile_h = 100.0

	var enemy_deck_y = 48.0
	var enemy_discard_y = 168.0
	var player_discard_y = h - 240.0
	var player_deck_y = h - 122.0

	var slots = [
		{"rect": Rect2(left_x, enemy_deck_y, pile_w, pile_h), "col": Color(0.4, 0.55, 0.75, 0.3), "type": "deck"},
		{"rect": Rect2(left_x, enemy_discard_y, pile_w, pile_h), "col": Color(0.7, 0.35, 0.35, 0.3), "type": "discard"},
		{"rect": Rect2(left_x, player_discard_y, pile_w, pile_h), "col": Color(0.7, 0.35, 0.35, 0.3), "type": "discard"},
		{"rect": Rect2(left_x, player_deck_y, pile_w, pile_h), "col": Color(0.75, 0.65, 0.35, 0.3), "type": "deck"}
	]

	for s in slots:
		var r: Rect2 = s["rect"]
		var c: Color = s["col"]
		draw_rect(r, Color(0.04, 0.05, 0.08, 0.5), true)
		_draw_rounded_rect(r, 6.0, c, 1.5)
		_draw_corner_brackets(r, 10.0, c * 1.3, 1.8)

## 4. Central Grand Summoning Circle & 6 Elemental Nodes
func _draw_summoning_circle(center: Vector2) -> void:
	var pulse = 0.5 + 0.5 * sin(_anim_time * 1.8)
	var glow_alpha = 0.20 + pulse * 0.12

	var base_gold = Color(0.85, 0.75, 0.40, glow_alpha)
	var outer_r = 135.0
	var mid_r = 100.0
	var inner_r = 65.0
	var core_r = 24.0

	# Outer glowing ring
	draw_arc(center, outer_r, 0, TAU, 64, base_gold, 1.5, true)
	draw_arc(center, outer_r + 2.0, 0, TAU, 64, Color(base_gold.r, base_gold.g, base_gold.b, glow_alpha * 0.4), 1.0, true)

	# 36 Compass tick marks
	for i in range(36):
		var ang = float(i) * TAU / 36.0
		var dir = Vector2(cos(ang), sin(ang))
		var is_major = (i % 6 == 0)
		var tick_len = 10.0 if is_major else 5.0
		var col = Color(0.9, 0.8, 0.45, 0.45 if is_major else 0.20)
		draw_line(center + dir * (outer_r - tick_len), center + dir * outer_r, col, 1.5 if is_major else 1.0, true)

	# Middle ring
	draw_arc(center, mid_r, 0, TAU, 48, Color(0.35, 0.65, 0.85, glow_alpha * 0.8), 1.2, true)

	# Inscribed 6-pointed elemental star (two interlocking triangles)
	var tri1 = PackedVector2Array()
	var tri2 = PackedVector2Array()
	for i in range(3):
		var a1 = float(i) * TAU / 3.0 - PI * 0.5
		var a2 = a1 + PI
		tri1.append(center + Vector2(cos(a1), sin(a1)) * mid_r)
		tri2.append(center + Vector2(cos(a2), sin(a2)) * mid_r)
	tri1.append(tri1[0])
	tri2.append(tri2[0])
	draw_polyline(tri1, Color(0.75, 0.65, 0.35, glow_alpha * 0.5), 1.2, true)
	draw_polyline(tri2, Color(0.75, 0.65, 0.35, glow_alpha * 0.5), 1.2, true)

	# Inner ring
	draw_arc(center, inner_r, 0, TAU, 36, base_gold, 1.2, true)

	# Core Nexus (pulsing central aura)
	draw_circle(center, core_r + pulse * 4.0, Color(0.2, 0.5, 0.8, 0.08 + pulse * 0.06))
	draw_circle(center, core_r * 0.6, Color(0.9, 0.8, 0.5, 0.15 + pulse * 0.15))
	draw_arc(center, core_r, 0, TAU, 24, Color(0.95, 0.85, 0.45, 0.6), 1.5, true)

	# 6 Elemental Nodes around the outer circumference
	for i in range(6):
		var el_name = ELEMENT_NAMES[i]
		var ang = ELEMENT_ANGLES[i] + _anim_time * 0.05
		var node_pos = center + Vector2(cos(ang), sin(ang)) * outer_r
		var col: Color = ELEMENT_COLORS.get(el_name, Color.WHITE)

		# Conduit ray to center
		var conduit_col = Color(col.r, col.g, col.b, 0.15 + pulse * 0.10)
		draw_line(center + Vector2(cos(ang), sin(ang)) * inner_r, node_pos, conduit_col, 1.0, true)

		# Outer node aura
		draw_circle(node_pos, 8.0 + pulse * 2.0, Color(col.r, col.g, col.b, 0.20 + pulse * 0.15))
		# Main node jewel
		draw_circle(node_pos, 5.0, col)
		# Specular highlight
		draw_circle(node_pos - Vector2(1.5, 1.5), 1.8, Color(1, 1, 1, 0.85))

## 5. Battlefield dividing meridian
func _draw_dividing_meridian(left_x: float, right_x: float, y: float) -> void:
	var pulse = 0.5 + 0.5 * sin(_anim_time * 1.5)
	var glow_col = Color(0.35, 0.65, 0.85, 0.15 + pulse * 0.10)
	var core_col = Color(0.85, 0.75, 0.45, 0.35)

	# Glow line
	draw_line(Vector2(left_x, y), Vector2(right_x, y), glow_col, 4.0, true)
	# Fine central hairline
	draw_line(Vector2(left_x, y), Vector2(right_x, y), core_col, 1.2, true)

	# End terminal diamonds
	_draw_diamond_filigree(Vector2(left_x, y), 5.0, core_col)
	_draw_diamond_filigree(Vector2(right_x, y), 5.0, core_col)

## 6. Card Summoning Lanes (4 Opponent slots, 4 Player slots)
func _draw_summoning_lanes(center_x: float, h: float) -> void:
	var slot_w = 126.0
	var slot_h = 168.0
	var sep = 16.0
	var total_w = 4.0 * slot_w + 3.0 * sep
	var start_x = center_x - total_w * 0.5

	var opp_y = 52.0
	var ply_y = h * 0.5 - 116.0

	var opp_color = Color(0.30, 0.50, 0.85, 0.35)
	var ply_color = Color(0.85, 0.70, 0.30, 0.35)

	for i in range(4):
		var x = start_x + float(i) * (slot_w + sep)

		# Opponent slot
		var r_opp = Rect2(x, opp_y, slot_w, slot_h)
		draw_rect(r_opp, Color(0.04, 0.07, 0.12, 0.35), true)
		_draw_rounded_rect(r_opp, 8.0, opp_color, 1.2)
		_draw_corner_brackets(r_opp, 14.0, opp_color * 1.4, 1.8)

		# Player slot
		var r_ply = Rect2(x, ply_y, slot_w, slot_h)
		draw_rect(r_ply, Color(0.08, 0.07, 0.04, 0.35), true)
		_draw_rounded_rect(r_ply, 8.0, ply_color, 1.2)
		_draw_corner_brackets(r_ply, 14.0, ply_color * 1.4, 1.8)

# ==============================================================================
# Helper Vector Drawing Primitives
# ==============================================================================

func _draw_rounded_rect(r: Rect2, rad: float, col: Color, width: float = 1.0) -> void:
	var pts = PackedVector2Array()
	var segs = 6
	# Top-left corner
	for i in range(segs + 1):
		var a = PI + float(i) * (PI * 0.5) / float(segs)
		pts.append(r.position + Vector2(rad, rad) + Vector2(cos(a), sin(a)) * rad)
	# Top-right corner
	for i in range(segs + 1):
		var a = 1.5 * PI + float(i) * (PI * 0.5) / float(segs)
		pts.append(Vector2(r.end.x - rad, r.position.y + rad) + Vector2(cos(a), sin(a)) * rad)
	# Bottom-right corner
	for i in range(segs + 1):
		var a = 0.0 + float(i) * (PI * 0.5) / float(segs)
		pts.append(Vector2(r.end.x - rad, r.end.y - rad) + Vector2(cos(a), sin(a)) * rad)
	# Bottom-left corner
	for i in range(segs + 1):
		var a = 0.5 * PI + float(i) * (PI * 0.5) / float(segs)
		pts.append(Vector2(r.position.x + rad, r.end.y - rad) + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	draw_polyline(pts, col, width, true)

func _draw_corner_brackets(r: Rect2, arm: float, col: Color, width: float = 1.5) -> void:
	# Top-Left
	draw_line(r.position, r.position + Vector2(arm, 0), col, width, true)
	draw_line(r.position, r.position + Vector2(0, arm), col, width, true)
	# Top-Right
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x - arm, r.position.y), col, width, true)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + arm), col, width, true)
	# Bottom-Right
	draw_line(r.end, r.end - Vector2(arm, 0), col, width, true)
	draw_line(r.end, r.end - Vector2(0, arm), col, width, true)
	# Bottom-Left
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x + arm, r.end.y), col, width, true)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y - arm), col, width, true)

func _draw_diamond_filigree(center: Vector2, half_size: float, col: Color) -> void:
	var pts = PackedVector2Array([
		center + Vector2(0, -half_size),
		center + Vector2(half_size, 0),
		center + Vector2(0, half_size),
		center + Vector2(-half_size, 0),
		center + Vector2(0, -half_size)
	])
	draw_polyline(pts, col, 1.5, true)
	draw_circle(center, half_size * 0.35, col)

func _draw_dashed_stitch(r: Rect2) -> void:
	var stitch_len = 6.0
	var gap = 4.0
	var col = Color(0.35, 0.40, 0.52, 0.35)

	# Top edge
	var x = r.position.x
	while x < r.end.x - stitch_len:
		draw_line(Vector2(x, r.position.y), Vector2(x + stitch_len, r.position.y), col, 1.0)
		x += stitch_len + gap

	# Bottom edge
	x = r.position.x
	while x < r.end.x - stitch_len:
		draw_line(Vector2(x, r.end.y), Vector2(x + stitch_len, r.end.y), col, 1.0)
		x += stitch_len + gap

	# Left edge
	var y = r.position.y
	while y < r.end.y - stitch_len:
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x, y + stitch_len), col, 1.0)
		y += stitch_len + gap

	# Right edge
	y = r.position.y
	while y < r.end.y - stitch_len:
		draw_line(Vector2(r.end.x, y), Vector2(r.end.x, y + stitch_len), col, 1.0)
		y += stitch_len + gap
