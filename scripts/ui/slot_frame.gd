class_name SlotFrame
extends Control

## Glowing neon battlefield slot with a radiant crosshair reticle.
## Blue for the opponent's battlefield, amber-gold for the player's.

@export var accent: Color = Color(0.25, 0.75, 1.0)
var _t: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	var pulse = 0.5 + 0.5 * sin(_t * 2.2)
	# Inner tinted glass
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(accent.r * 0.15, accent.g * 0.12, accent.b * 0.18, 0.55)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.75 + 0.25 * pulse)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35 + 0.25 * pulse)
	sb.shadow_size = 10
	draw_style_box(sb, r)
	# Inner thin line
	var sb2 = StyleBoxFlat.new()
	sb2.draw_center = false
	sb2.set_corner_radius_all(6)
	sb2.set_border_width_all(1)
	sb2.border_color = Color(1, 1, 1, 0.25)
	draw_style_box(sb2, r.grow(-6))
	# Crosshair reticle
	var c = size * 0.5
	var rad = minf(size.x, size.y) * 0.13
	var col = Color(accent.r, accent.g, accent.b, 0.9)
	draw_arc(c, rad, 0, TAU, 32, col, 2.0, true)
	draw_arc(c, rad * 0.35, 0, TAU, 16, col, 1.5, true)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(c + d * rad * 0.6, c + d * rad * 1.9, col, 1.5, true)
	draw_circle(c, 2.5, Color(1, 1, 1, 0.9))
