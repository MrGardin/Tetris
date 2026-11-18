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
var hero_id := ""
var ability_remaining := 0.0
var ability_duration := 30.0
var ability_enabled := false

func set_ability_state(hero: String, remaining: float, duration: float, enabled: bool) -> void:
	hero_id = hero
	ability_remaining = maxf(0.0, remaining)
	ability_duration = maxf(0.001, duration)
	ability_enabled = enabled
	queue_redraw()

func ability_rect() -> Rect2:
	var diameter := minf(54.0, maxf(24.0, size.x - 24.0))
	var right := button_rect(2)
	var x := minf(size.x - diameter - 14.0, right.end.x + 26.0)
	var y := right.position.y - diameter * 0.65
	var rect := Rect2(Vector2(maxf(12.0, x), maxf(12.0, y)), Vector2.ONE * diameter)
	for i in 3:
		if rect.grow(8.0).intersects(button_rect(i).grow(12.0)):
			var highest := minf(button_rect(0).position.y, minf(button_rect(1).position.y, button_rect(2).position.y))
			rect.position.y = maxf(12.0, highest - diameter - 22.0)
			break
	return rect

func ability_hit(point: Vector2) -> bool:
	return not hero_id.is_empty() and ability_rect().grow(8.0).has_point(point)

func _draw_ability() -> void:
	if hero_id.is_empty():
		return
	var rect := ability_rect()
	var center := rect.get_center()
	var radius := rect.size.x * 0.5
	var accent := Color("#69e0c0") if hero_id == "binder" else Color("#9bbcff")
	var progress := clampf(1.0 - ability_remaining / ability_duration, 0.0, 1.0)
	draw_circle(center, radius, Color(VOID, 0.94))
	# Disc and outer ring fill clockwise during cooldown.
	if progress > 0.001:
		var sector := PackedVector2Array([center])
		var steps := maxi(2, int(ceil(progress * 64.0)))
		for i in range(steps + 1):
			var angle := -PI * 0.5 + TAU * progress * float(i) / float(steps)
			sector.append(center + Vector2(cos(angle), sin(angle)) * (radius - 2.0))
		draw_colored_polygon(sector, Color(accent, 0.15 if ability_enabled else 0.075))
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 72, Color(accent, 1.0 if ability_enabled else 0.6), 2.0, true)
	draw_arc(center, radius, 0.0, TAU, 72, Color(LIGHT, 0.23), 1.0, true)
	var ink := accent if ability_enabled else Color(accent, 0.45)
	if hero_id == "binder":
		for j in 2:
			var line := PackedVector2Array()
			for i in 25:
				var x := -12.0 + i
				line.append(center + Vector2(x, sin(x * 0.25 + j * PI) * 6.0))
			draw_polyline(line, ink, 1.7, true)
	else:
		draw_rect(Rect2(center - Vector2(6, 4), Vector2(12, 12)), ink, false, 1.5, true)
		draw_line(center + Vector2(-7, -7), center + Vector2(0, -13), ink, 1.5, true)
		draw_line(center + Vector2(0, -13), center + Vector2(7, -7), ink, 1.5, true)
		draw_line(center + Vector2(-10, 13), center + Vector2(10, 13), ink, 1.0, true)
	if ability_remaining > 0.0:
		var font := ThemeDB.fallback_font
		var text := str(int(ceil(ability_remaining)))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, center + Vector2(-width * 0.5, radius + 16.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, LIGHT)

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

	_draw_ability()

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
