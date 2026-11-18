extends Node2D
## Scene-only drawing: space backdrop, drifting stars, planet, platform, target line and countdown.

const SPACE := Color("#030509")
const LINE := Color("#f0f3f8")
const CELL := 27.0

var viewport_size := Vector2(540.0, 960.0)
var camera_position := Vector2.ZERO
var platform_width := 180.0
var platform_y := 300.0
var target_y := -150.0
var countdown := -1.0
var stars: Array[Vector4] = [] # normalized x/y, speed, radius
var star_phase := 0.0

func _ready() -> void:
	for i in 190:
		stars.append(Vector4(randf(), randf(), randf_range(2.0, 13.0), randf_range(0.35, 1.15)))
	queue_redraw()

func set_scene_state(view_size: Vector2, cam_position: Vector2, stand_width: float, ground_y: float, finish_y: float) -> void:
	viewport_size = view_size
	camera_position = cam_position
	platform_width = stand_width
	platform_y = ground_y
	target_y = finish_y
	queue_redraw()

func set_countdown(seconds_left: float) -> void:
	countdown = seconds_left
	queue_redraw()

func _process(dt: float) -> void:
	star_phase += dt
	queue_redraw()

func _draw() -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var origin := camera_position - viewport_size * 0.5
	# Near-black space with two very soft monochrome nebula forms.
	draw_rect(Rect2(origin, viewport_size), SPACE)
	draw_circle(origin + Vector2(viewport_size.x * 0.86, viewport_size.y * 0.22), viewport_size.x * 0.33, Color("#080c13"))
	draw_circle(origin + Vector2(viewport_size.x * 0.10, viewport_size.y * 0.73), viewport_size.x * 0.27, Color("#070a10"))
	_draw_distant_world(origin)
	_draw_stars(origin)
	_draw_target_line()
	_draw_platform()
	_draw_countdown()

func _draw_stars(origin: Vector2) -> void:
	for i in stars.size():
		var star := stars[i]
		var x := fposmod(star.x * viewport_size.x + star_phase * star.z * 0.08, viewport_size.x)
		var y := fposmod(star.y * viewport_size.y - star_phase * star.z * 0.62, viewport_size.y)
		var shimmer := 0.30 + 0.55 * (0.5 + 0.5 * sin(star_phase * (0.6 + star.z * 0.06) + float(i) * 1.31))
		var p := origin + Vector2(x, y)
		draw_circle(p, star.w, Color(0.87, 0.91, 0.98, shimmer))
		if star.w > 1.02:
			draw_line(p - Vector2(2.4, 0.0), p + Vector2(2.4, 0.0), Color(0.87, 0.91, 0.98, shimmer * 0.35), 0.65, true)

func _draw_distant_world(origin: Vector2) -> void:
	var center := origin + Vector2(viewport_size.x * 0.82, viewport_size.y * 0.34)
	var radius := viewport_size.x * 0.13
	_draw_ellipse(center, Vector2(radius * 1.8, radius * 0.43), Color(0.72, 0.78, 0.88, 0.17), 1.0)
	_draw_ellipse(center, Vector2(radius * 1.45, radius * 0.32), Color(0.72, 0.78, 0.88, 0.09), 1.0)
	draw_circle(center, radius, Color("#0b1018"))
	draw_arc(center, radius, -2.2, 0.85, 48, Color(0.81, 0.86, 0.94, 0.18), 1.0, true)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 81:
		var angle := TAU * float(i) / 80.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, width, true)

func _draw_target_line() -> void:
	var half_view := viewport_size.x * 0.5
	var x0 := camera_position.x - half_view + 18.0
	var x1 := camera_position.x + half_view - 18.0
	var y := target_y
	# The broad faint under-stroke makes the goal visible against both stars and nebula.
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.91, 0.94, 1.0, 0.15), 5.0, true)
	# Broken luminous line, with bright end caps; this is the final-height guide.
	draw_dashed_line(Vector2(x0, y), Vector2(x1, y), Color(0.91, 0.94, 1.0, 0.88), 1.6, 10.0, true, true)
	for x in [x0, x1]:
		draw_line(Vector2(x, y - 7.0), Vector2(x, y + 7.0), Color(0.91, 0.94, 1.0, 0.92), 1.2, true)

func _draw_countdown() -> void:
	if countdown < 0.0:
		return
	var label := "%.2f" % maxf(0.0, countdown)
	var font := ThemeDB.fallback_font
	var font_size := 30
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	# Place the readout 2.5 block-heights above the target line.
	var center := Vector2(camera_position.x, target_y - CELL * 2.5)
	var panel_size := Vector2(text_size.x + 38.0, 48.0)
	var panel := Rect2(center - panel_size * 0.5, panel_size)
	var text_position := Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)

	# Compact instrument-style readout: dark capsule, fine outline and clipped corner accents.
	draw_rect(panel, Color("#05070b"))
	draw_rect(panel, Color(0.78, 0.84, 0.94, 0.76), false, 1.0, true)
	var corner := 7.0
	var accent := Color("#f0f3f8")
	# Four short corner marks give the timer a distinct, precise visual treatment.
	draw_line(panel.position, panel.position + Vector2(corner, 0.0), accent, 1.4, true)
	draw_line(panel.position, panel.position + Vector2(0.0, corner), accent, 1.4, true)
	draw_line(Vector2(panel.end.x, panel.position.y), Vector2(panel.end.x - corner, panel.position.y), accent, 1.4, true)
	draw_line(Vector2(panel.end.x, panel.position.y), Vector2(panel.end.x, panel.position.y + corner), accent, 1.4, true)
	draw_line(Vector2(panel.position.x, panel.end.y), Vector2(panel.position.x + corner, panel.end.y), accent, 1.4, true)
	draw_line(Vector2(panel.position.x, panel.end.y), Vector2(panel.position.x, panel.end.y - corner), accent, 1.4, true)
	draw_line(panel.end, panel.end - Vector2(corner, 0.0), accent, 1.4, true)
	draw_line(panel.end, panel.end - Vector2(0.0, corner), accent, 1.4, true)

	# Subtle glow behind crisp white numerals.
	var glow := Color(0.86, 0.91, 1.0, 0.16)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, text_position + offset, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, glow)
	draw_string(font, text_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, accent)

func _draw_platform() -> void:
	var half_width := platform_width * 0.5
	draw_rect(Rect2(-half_width, platform_y + 1.0, platform_width, 5.5), Color("#111722"))
	draw_line(Vector2(-half_width, platform_y), Vector2(half_width, platform_y), LINE, 2.0, true)
	draw_line(Vector2(-half_width + 10.0, platform_y + 8.0), Vector2(half_width - 10.0, platform_y + 8.0), Color(0.78, 0.83, 0.92, 0.22), 1.0, true)
	draw_circle(Vector2(-half_width, platform_y), 2.0, LINE)
	draw_circle(Vector2(half_width, platform_y), 2.0, LINE)
