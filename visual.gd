extends Node2D
## Космос, игровое поле, таймер, эффекты и индикатор соперника.

const SPACE := Color("#030509")
const LINE := Color("#f0f3f8")
const CELL := 27.0

var viewport_size := Vector2(540.0, 960.0)
var camera_position := Vector2.ZERO
var platform_width := 180.0
var platform_y := 300.0
var target_y := -150.0
var countdown := -1.0

var stars: Array[Vector4] = []
var star_phase := 0.0
var meteor_event_active := false
var meteor_direction := 1
var meteor_elapsed := 0.0
var meteors: Array[Vector4] = []

var purge_alpha := 0.0
var purge_requested := false
var purge_clock := 0.0

var opponent_progress := 0.0
var match_result_text := ""


func _ready() -> void:
	for i in 190:
		stars.append(Vector4(
			randf(),
			randf(),
			randf_range(2.0, 13.0),
			randf_range(0.35, 1.15)
		))

	for i in 26:
		meteors.append(Vector4(
			randf(),
			randf(),
			randf_range(110.0, 230.0),
			randf_range(10.0, 24.0)
		))

	queue_redraw()


func set_scene_state(
	view_size: Vector2,
	cam_position: Vector2,
	stand_width: float,
	ground_y: float,
	finish_y: float
) -> void:
	viewport_size = view_size
	camera_position = cam_position
	platform_width = stand_width
	platform_y = ground_y
	target_y = finish_y
	queue_redraw()


func set_countdown(seconds_left: float) -> void:
	countdown = seconds_left
	queue_redraw()


func set_opponent_progress(value: float) -> void:
	opponent_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func set_match_result(text: String) -> void:
	match_result_text = text
	queue_redraw()


func set_meteor_event(enabled: bool, direction: int) -> void:
	if enabled and not meteor_event_active:
		meteor_elapsed = 0.0

	meteor_event_active = enabled
	meteor_direction = -1 if direction < 0 else 1
	queue_redraw()


func set_purge_event(enabled: bool) -> void:
	purge_requested = enabled

	if enabled:
		purge_clock = 0.0

	queue_redraw()


func _process(delta: float) -> void:
	star_phase += delta

	if meteor_event_active:
		meteor_elapsed += delta

	if purge_requested:
		purge_clock += delta
		purge_alpha = minf(1.0, purge_alpha + delta * 2.0)
	else:
		purge_alpha = maxf(0.0, purge_alpha - delta * 1.7)

	queue_redraw()


func _draw() -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var origin := camera_position - viewport_size * 0.5

	draw_rect(Rect2(origin, viewport_size), SPACE)
	draw_circle(
		origin + Vector2(viewport_size.x * 0.86, viewport_size.y * 0.22),
		viewport_size.x * 0.33,
		Color("#080c13")
	)
	draw_circle(
		origin + Vector2(viewport_size.x * 0.10, viewport_size.y * 0.73),
		viewport_size.x * 0.27,
		Color("#070a10")
	)

	_draw_distant_world(origin)
	_draw_stars(origin)

	if meteor_event_active:
		_draw_meteor_shower(origin)

	if purge_alpha > 0.0:
		_draw_purge_planet(origin)

	_draw_target_line()
	_draw_platform()
	_draw_countdown()
	_draw_opponent_indicator(origin)
	_draw_match_result(origin)


func _draw_stars(origin: Vector2) -> void:
	for i in stars.size():
		var star := stars[i]
		var x := fposmod(
			star.x * viewport_size.x + star_phase * star.z * 0.08,
			viewport_size.x
		)
		var y := fposmod(
			star.y * viewport_size.y - star_phase * star.z * 0.62,
			viewport_size.y
		)
		var shimmer := 0.30 + 0.55 * (
			0.5 + 0.5 * sin(
				star_phase * (0.6 + star.z * 0.06) + float(i) * 1.31
			)
		)
		var point := origin + Vector2(x, y)

		draw_circle(point, star.w, Color(0.87, 0.91, 0.98, shimmer))

		if star.w > 1.02:
			draw_line(
				point - Vector2(2.4, 0.0),
				point + Vector2(2.4, 0.0),
				Color(0.87, 0.91, 0.98, shimmer * 0.35),
				0.65,
				true
			)


func _draw_meteor_shower(origin: Vector2) -> void:
	for meteor in meteors:
		var x := fposmod(
			meteor.x * viewport_size.x
				+ meteor_direction * meteor_elapsed * meteor.z * 0.38,
			viewport_size.x
		)
		var y := fposmod(
			meteor.y * viewport_size.y + meteor_elapsed * meteor.z,
			viewport_size.y
		)
		var head := origin + Vector2(x, y)
		var tail := head + Vector2(
			-meteor_direction * meteor.w * 0.55,
			-meteor.w
		)

		draw_line(tail, head, Color(0.83, 0.89, 0.98, 0.22), 3.0, true)
		draw_line(tail, head, Color(0.95, 0.97, 1.0, 0.72), 1.0, true)
		draw_circle(head, 1.4, Color(0.98, 0.99, 1.0, 0.9))


func _draw_purge_planet(origin: Vector2) -> void:
	var t := purge_alpha
	var center := origin + Vector2(
		viewport_size.x * 0.22,
		viewport_size.y * 0.30
	)
	var appear := minf(1.0, t * 2.4)
	var pulse := 0.82 + 0.18 * sin(purge_clock * 7.0)
	var radius := viewport_size.x * 0.052 * appear
	var red := Color(0.92, 0.10, 0.20, 0.72 * t * pulse)
	var dim_red := Color(0.82, 0.08, 0.18, 0.30 * t)

	_draw_ellipse(center, Vector2(radius * 2.35, radius * 0.63), dim_red, 1.2)
	_draw_ellipse(center, Vector2(radius * 1.78, radius * 0.46), red, 0.85)
	draw_circle(center, radius, Color(0.11, 0.025, 0.045, 0.95 * t))
	draw_arc(center, radius, -2.6, 0.75, 40, red, 1.4, true)

	for i in 3:
		var angle := purge_clock * 1.2 + TAU * float(i) / 3.0
		var point := center + Vector2(
			cos(angle) * radius * 1.58,
			sin(angle) * radius * 0.56
		)
		draw_circle(point, 1.8 * appear, Color(1.0, 0.28, 0.35, 0.88 * t))

	for i in 8:
		var angle := TAU * float(i) / 8.0 + purge_clock * 0.18
		var direction := Vector2(cos(angle), sin(angle))
		var ray_end := radius * (
			2.3 + 0.15 * sin(purge_clock * 3.0 + float(i))
		)
		draw_line(
			center + direction * radius * 1.9,
			center + direction * ray_end,
			Color(0.9, 0.14, 0.23, 0.24 * t),
			0.8,
			true
		)


func _draw_distant_world(origin: Vector2) -> void:
	var center := origin + Vector2(
		viewport_size.x * 0.82,
		viewport_size.y * 0.34
	)
	var radius := viewport_size.x * 0.13

	_draw_ellipse(
		center,
		Vector2(radius * 1.8, radius * 0.43),
		Color(0.72, 0.78, 0.88, 0.17),
		1.0
	)
	_draw_ellipse(
		center,
		Vector2(radius * 1.45, radius * 0.32),
		Color(0.72, 0.78, 0.88, 0.09),
		1.0
	)
	draw_circle(center, radius, Color("#0b1018"))
	draw_arc(
		center,
		radius,
		-2.2,
		0.85,
		48,
		Color(0.81, 0.86, 0.94, 0.18),
		1.0,
		true
	)


func _draw_ellipse(
	center: Vector2,
	radii: Vector2,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()

	for i in 81:
		var angle := TAU * float(i) / 80.0
		points.append(
			center + Vector2(
				cos(angle) * radii.x,
				sin(angle) * radii.y
			)
		)

	draw_polyline(points, color, width, true)


func _draw_target_line() -> void:
	var half_view := viewport_size.x * 0.5
	var x0 := camera_position.x - half_view + 18.0
	var x1 := camera_position.x + half_view - 18.0
	var y := target_y

	draw_line(
		Vector2(x0, y),
		Vector2(x1, y),
		Color(0.91, 0.94, 1.0, 0.15),
		5.0,
		true
	)
	draw_dashed_line(
		Vector2(x0, y),
		Vector2(x1, y),
		Color(0.91, 0.94, 1.0, 0.88),
		1.6,
		10.0,
		true,
		true
	)

	for x in [x0, x1]:
		draw_line(
			Vector2(x, y - 7.0),
			Vector2(x, y + 7.0),
			Color(0.91, 0.94, 1.0, 0.92),
			1.2,
			true
		)


func _draw_countdown() -> void:
	if countdown < 0.0:
		return

	var label := "%.2f" % maxf(0.0, countdown)
	var font := ThemeDB.fallback_font
	var font_size := 30
	var text_size := font.get_string_size(
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	)
	var center := Vector2(camera_position.x, target_y - CELL * 2.5)
	var panel_size := Vector2(text_size.x + 38.0, 48.0)
	var panel := Rect2(center - panel_size * 0.5, panel_size)

	draw_rect(panel, Color("#05070b"))
	draw_rect(panel, Color(0.78, 0.84, 0.94, 0.76), false, 1.0, true)

	var text_position := Vector2(
		center.x - text_size.x * 0.5,
		center.y + text_size.y * 0.35
	)
	draw_string(
		font,
		text_position,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color("#f0f3f8")
	)


func _draw_platform() -> void:
	var half_width := platform_width * 0.5

	draw_rect(
		Rect2(-half_width, platform_y + 1.0, platform_width, 5.5),
		Color("#111722")
	)
	draw_line(
		Vector2(-half_width, platform_y),
		Vector2(half_width, platform_y),
		LINE,
		2.0,
		true
	)
	draw_line(
		Vector2(-half_width + 10.0, platform_y + 8.0),
		Vector2(half_width - 10.0, platform_y + 8.0),
		Color(0.78, 0.83, 0.92, 0.22),
		1.0,
		true
	)
	draw_circle(Vector2(-half_width, platform_y), 2.0, LINE)
	draw_circle(Vector2(half_width, platform_y), 2.0, LINE)


func _draw_opponent_indicator(origin: Vector2) -> void:
	var left := origin.x + viewport_size.x - 27.0
	var top := origin.y + maxf(125.0, viewport_size.y * 0.17)
	var bottom := origin.y + minf(viewport_size.y * 0.58, top - origin.y + 230.0)
	var track_height := maxf(90.0, bottom - top)
	var marker_y := bottom - opponent_progress * track_height

	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(left - 58.0, top - 13.0),
		"СОПЕРНИК",
		HORIZONTAL_ALIGNMENT_CENTER,
		58.0,
		9,
		Color(0.75, 0.82, 0.93, 0.75)
	)

	draw_line(
		Vector2(left, top),
		Vector2(left, bottom),
		Color(0.72, 0.80, 0.92, 0.20),
		3.0,
		true
	)

	var progress_end := lerpf(bottom, top, opponent_progress)
	draw_line(
		Vector2(left, bottom),
		Vector2(left, progress_end),
		Color(0.82, 0.88, 0.98, 0.62),
		2.0,
		true
	)

	var triangle := PackedVector2Array([
		Vector2(left - 10.0, marker_y),
		Vector2(left + 6.0, marker_y - 8.0),
		Vector2(left + 6.0, marker_y + 8.0)
	])
	draw_colored_polygon(triangle, Color("#e4ebf6"))
	triangle.append(triangle[0])
	draw_polyline(triangle, Color("#ffffff"), 1.0, true)


func _draw_match_result(origin: Vector2) -> void:
	if match_result_text.is_empty():
		return

	var font := ThemeDB.fallback_font
	var font_size := 18
	var text_size := font.get_string_size(
		match_result_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		font_size
	)
	var center := origin + viewport_size * 0.5
	var panel_size := Vector2(
		minf(viewport_size.x - 32.0, text_size.x + 36.0),
		54.0
	)
	var panel := Rect2(center - panel_size * 0.5, panel_size)

	draw_rect(panel, Color(0.02, 0.03, 0.05, 0.92))
	draw_rect(panel, Color(0.72, 0.80, 0.92, 0.82), false, 1.0, true)
	draw_string(
		font,
		Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35),
		match_result_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color("#f0f3f8")
	)
