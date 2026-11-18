extends Control
## Wordless monochrome touch interface.

const LIGHT := Color("#f4f6fa")
const VOID := Color("#05070b")
const SOFT := Color("#aab3c0")
const BUTTON_SIZE := 90.0 
const BUTTON_GAP := 25.0
const EDGE_MARGIN := 27.0

var selected := -1
var finish := false

func _is_horizontal() -> bool:
	return size.x >= BUTTON_SIZE * 3.0 + BUTTON_GAP * 2.0 + 32.0

func button_rect(i: int) -> Rect2:
	var diameter := minf(BUTTON_SIZE, size.x - 32.0)
	if _is_horizontal():
		var total := diameter * 3.0 + BUTTON_GAP * 2.0
		var x := (size.x - total) * 0.5 + i * (diameter + BUTTON_GAP)
		return Rect2(Vector2(x, size.y - diameter - EDGE_MARGIN), Vector2.ONE * diameter)
	else:
		# Stack the full-size controls vertically on narrow/portrait screens.
		var gap := minf(BUTTON_GAP, maxf(8.0, (size.y - diameter * 3.0 - 2.0 * EDGE_MARGIN) / 2.0))
		var total_height := diameter * 3.0 + gap * 2.0
		var y := size.y - total_height - EDGE_MARGIN + i * (diameter + gap)
		return Rect2(Vector2((size.x - diameter) * 0.5, y), Vector2.ONE * diameter)

func hit(p: Vector2) -> int:
	for i in 3:
		if button_rect(i).grow(12.0).has_point(p):
			return i
	return -1

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for i in 3:
		var r := button_rect(i)
		var c := r.get_center()
		var radius := r.size.x * 0.5
		var scale := r.size.x / 64.0
		if selected == i:
			draw_circle(c, radius + 11.0 * scale, Color(LIGHT, 0.055))
			draw_arc(c, radius + 7.0 * scale, 0.0, TAU, 64, Color(LIGHT, 0.62), 1.0 * scale, true)
		draw_circle(c, radius, Color(VOID, 0.76))
		draw_arc(c, radius, 0.0, TAU, 96, Color(LIGHT, 0.60), 1.1 * scale, true)
		if i == 0:
			_arrow(c, -1.0, scale)
		elif i == 1:
			_rotate_icon(c, scale)
		else:
			_arrow(c, 1.0, scale)

	if finish:
		var c := size * 0.5
		draw_circle(c, 55.0, Color(VOID, 0.94))
		draw_arc(c, 55.0, 0.0, TAU, 72, Color(LIGHT, 0.88), 1.2, true)
		draw_circle(c, 8.0, LIGHT)
		draw_circle(c + Vector2(5.0, -5.0), 8.0, VOID)
		draw_arc(c, 20.0, -0.3, PI * 1.55, 36, SOFT, 1.0, true)

func _arrow(c: Vector2, direction: float, scale: float) -> void:
	var tip := c + Vector2(direction * 13.0, 0.0) * scale
	var tail := c - Vector2(direction * 11.0, 0.0) * scale
	draw_line(tail, tip, LIGHT, 1.8 * scale, true)
	draw_line(tip, tip - Vector2(direction * 7.0, -7.0) * scale, LIGHT, 1.8 * scale, true)
	draw_line(tip, tip - Vector2(direction * 7.0, 7.0) * scale, LIGHT, 1.8 * scale, true)

func _rotate_icon(c: Vector2, scale: float) -> void:
	draw_arc(c, 11.0 * scale, -2.5, 2.15, 48, LIGHT, 1.7 * scale, true)
	var tip := c + Vector2(8.0, -7.6) * scale
	draw_line(tip, tip + Vector2(-1.0, 7.0) * scale, LIGHT, 1.7 * scale, true)
	draw_line(tip, tip + Vector2(-7.0, 1.0) * scale, LIGHT, 1.7 * scale, true)

func set_selected(value: int) -> void:
	selected = value
	queue_redraw()

func set_finished(value: bool) -> void:
	finish = value
	queue_redraw()
