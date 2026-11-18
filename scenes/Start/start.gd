extends Node2D
## Космический стартовый экран Tetris:Windbound.

@export_file("*.tscn")
var main_scene_path: String = "res://Main.tscn"

const SPACE := Color("#030509")
const WHITE := Color("#f0f3f8")
const MUTED := Color("#a6b0c0")
const RED := Color("#ff4055")

var viewport_size := Vector2(540.0, 960.0)
var elapsed := 0.0

# x, y — нормализованные координаты; z — размер; w — фаза мерцания.
var stars: Array[Vector4] = []

var overlay: Control
var title_label: Label
var subtitle_label: Label
var play_button: Button
var how_to_button: Button
var placeholder_dialog: AcceptDialog


func _ready() -> void:
	randomize()
	viewport_size = get_viewport_rect().size

	for i in 180:
		stars.append(Vector4(
			randf(),
			randf(),
			randf_range(0.7, 2.0),
			randf_range(0.0, TAU)
		))

	_build_interface()
	_layout_interface()

	get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_draw_space_background()
	_draw_planets()
	_draw_stars()
	_draw_floating_tetrominoes()
	_draw_logo()


func _draw_space_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), SPACE)

	# Едва заметные цветные области для глубины фона.
	draw_circle(
		Vector2(viewport_size.x * 0.08, viewport_size.y * 0.45),
		viewport_size.x * 0.30,
		Color(0.035, 0.055, 0.095, 0.38)
	)
	draw_circle(
		Vector2(viewport_size.x * 0.94, viewport_size.y * 0.74),
		viewport_size.x * 0.34,
		Color(0.075, 0.025, 0.045, 0.20)
	)


func _draw_planets() -> void:
	var distant_center := Vector2(viewport_size.x * 0.83, viewport_size.y * 0.19)
	var distant_radius := viewport_size.x * 0.115

	_draw_ellipse(
		distant_center,
		Vector2(distant_radius * 1.9, distant_radius * 0.48),
		Color(0.72, 0.78, 0.88, 0.16),
		1.0
	)
	_draw_ellipse(
		distant_center,
		Vector2(distant_radius * 1.55, distant_radius * 0.36),
		Color(0.72, 0.78, 0.88, 0.10),
		1.0
	)
	draw_circle(distant_center, distant_radius, Color("#0b1018"))
	draw_arc(
		distant_center,
		distant_radius,
		-2.3,
		0.8,
		48,
		Color(0.81, 0.86, 0.94, 0.22),
		1.0,
		true
	)

	# Маленький красный объект — отсылка к эффектам событий в игре.
	var red_center := Vector2(viewport_size.x * 0.12, viewport_size.y * 0.73)
	var pulse := 0.85 + 0.15 * sin(elapsed * 1.4)
	var red_radius := viewport_size.x * 0.043 * pulse

	_draw_ellipse(
		red_center,
		Vector2(red_radius * 2.2, red_radius * 0.65),
		Color(0.85, 0.12, 0.23, 0.24),
		1.0
	)
	draw_circle(red_center, red_radius, Color(0.15, 0.035, 0.055, 0.9))
	draw_arc(
		red_center,
		red_radius,
		-2.5,
		0.75,
		32,
		Color(1.0, 0.20, 0.30, 0.55),
		1.0,
		true
	)


func _draw_stars() -> void:
	for i in stars.size():
		var star := stars[i]
		var position := Vector2(
			star.x * viewport_size.x,
			star.y * viewport_size.y
		)
		var shimmer := 0.38 + 0.52 * (
			0.5 + 0.5 * sin(elapsed * 1.3 + star.w)
		)
		var color := Color(0.88, 0.92, 1.0, shimmer)

		draw_circle(position, star.z, color)

		# Изредка звезда превращается в небольшой блик.
		if star.z > 1.65:
			draw_line(
				position - Vector2(3.0, 0.0),
				position + Vector2(3.0, 0.0),
				Color(0.88, 0.92, 1.0, shimmer * 0.4),
				0.7,
				true
			)


func _draw_floating_tetrominoes() -> void:
	# Полупрозрачные формы по краям экрана — не конкурируют с меню.
	var cell_size := clampf(viewport_size.x * 0.045, 18.0, 25.0)
	var drift := sin(elapsed * 0.7) * 7.0

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.16, viewport_size.y * 0.43 + drift),
		cell_size,
		[
			Vector2i(-1, 0),
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(1, -1)
		],
		Color(0.78, 0.84, 0.94, 0.13)
	)

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.84, viewport_size.y * 0.65 - drift),
		cell_size,
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(0, 1),
			Vector2i(1, 1)
		],
		Color(0.92, 0.34, 0.42, 0.11)
	)


func _draw_ghost_piece(
	center: Vector2,
	cell_size: float,
	cells: Array[Vector2i],
	color: Color
) -> void:
	for cell in cells:
		var rect := Rect2(
			center + Vector2(cell) * cell_size - Vector2.ONE * cell_size * 0.5,
			Vector2.ONE * cell_size
		)
		draw_rect(rect, color, false, 1.0, true)


func _draw_logo() -> void:
	var center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.255)
	var cell_size := clampf(viewport_size.x * 0.075, 27.0, 38.0)

	# Кольца-орбиты за знаком.
	_draw_ellipse(
		center,
		Vector2(cell_size * 2.75, cell_size * 0.85),
		Color(0.72, 0.79, 0.91, 0.28),
		1.0
	)
	_draw_ellipse(
		center,
		Vector2(cell_size * 2.38, cell_size * 0.67),
		Color(0.72, 0.79, 0.91, 0.14),
		1.0
	)

	# Значок из четырёх клеток, напоминающий тетромино.
	var cells: Array[Vector2i] = [
		Vector2i(-1, 0),
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, -1)
	]

	for i in cells.size():
		var cell := cells[i]
		var rect := Rect2(
			center + Vector2(cell) * cell_size
				- Vector2.ONE * cell_size * 0.5,
			Vector2.ONE * cell_size
		)
		var fill := Color("#e9edf3")
		if i == 3:
			fill = RED

		draw_rect(rect.grow(1.5), Color("#05070b"))
		draw_rect(rect.grow(-2.0), fill)

	# Маленькие вращающиеся точки на орбите.
	for i in 3:
		var angle := elapsed * 0.65 + TAU * float(i) / 3.0
		var point := center + Vector2(
			cos(angle) * cell_size * 2.35,
			sin(angle) * cell_size * 0.66
		)
		draw_circle(point, 1.8, Color(0.90, 0.94, 1.0, 0.75))


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


func _build_interface() -> void:
	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(overlay)

	title_label = Label.new()
	title_label.text = "Tetris:Windbound"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", WHITE)
	title_label.add_theme_color_override("font_shadow_color", Color(0.75, 0.83, 1.0, 0.16))
	title_label.add_theme_constant_override("shadow_offset_x", 0)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "СОБЕРИ ВЫСОТУ. УДЕРЖИ КУРС."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", MUTED)
	overlay.add_child(subtitle_label)

	play_button = _create_button("ИГРАТЬ", true)
	play_button.pressed.connect(_on_play_pressed)
	overlay.add_child(play_button)

	how_to_button = _create_button("КАК ИГРАТЬ", false)
	how_to_button.pressed.connect(_on_how_to_pressed)
	overlay.add_child(how_to_button)

	placeholder_dialog = AcceptDialog.new()
	placeholder_dialog.title = "Как играть"
	placeholder_dialog.dialog_text = "Раздел «Как играть» появится позже."
	overlay.add_child(placeholder_dialog)


func _create_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)

	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(4)
	normal.set_border_width_all(1)
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0

	var hover := StyleBoxFlat.new()
	hover.set_corner_radius_all(4)
	hover.set_border_width_all(1)
	hover.content_margin_left = 18.0
	hover.content_margin_right = 18.0
	hover.content_margin_top = 10.0
	hover.content_margin_bottom = 10.0

	var pressed := StyleBoxFlat.new()
	pressed.set_corner_radius_all(4)
	pressed.set_border_width_all(1)
	pressed.content_margin_left = 18.0
	pressed.content_margin_right = 18.0
	pressed.content_margin_top = 10.0
	pressed.content_margin_bottom = 10.0

	if primary:
		normal.bg_color = Color(0.88, 0.91, 0.96, 0.96)
		normal.border_color = Color("#f0f3f8")
		hover.bg_color = Color("#ffffff")
		hover.border_color = Color("#ffffff")
		pressed.bg_color = Color("#d8deea")
		pressed.border_color = Color("#d8deea")

		button.add_theme_color_override("font_color", Color("#080b11"))
		button.add_theme_color_override("font_hover_color", Color("#080b11"))
		button.add_theme_color_override("font_pressed_color", Color("#080b11"))
	else:
		normal.bg_color = Color(0.03, 0.04, 0.06, 0.55)
		normal.border_color = Color(0.77, 0.83, 0.92, 0.55)
		hover.bg_color = Color(0.12, 0.15, 0.21, 0.92)
		hover.border_color = Color("#f0f3f8")
		pressed.bg_color = Color(0.16, 0.07, 0.10, 0.95)
		pressed.border_color = RED

		button.add_theme_color_override("font_color", WHITE)
		button.add_theme_color_override("font_hover_color", Color("#ffffff"))
		button.add_theme_color_override("font_pressed_color", Color("#ffffff"))

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)

	return button


func _layout_interface() -> void:
	viewport_size = get_viewport_rect().size

	var title_width := minf(500.0, viewport_size.x - 28.0)
	var button_width := minf(310.0, viewport_size.x - 64.0)
	var center_x := viewport_size.x * 0.5

	title_label.position = Vector2(
		center_x - title_width * 0.5,
		viewport_size.y * 0.375
	)
	title_label.size = Vector2(title_width, 54.0)

	subtitle_label.position = Vector2(
		center_x - title_width * 0.5,
		viewport_size.y * 0.445
	)
	subtitle_label.size = Vector2(title_width, 24.0)

	play_button.position = Vector2(
		center_x - button_width * 0.5,
		viewport_size.y * 0.535
	)
	play_button.size = Vector2(button_width, 58.0)

	how_to_button.position = Vector2(
		center_x - button_width * 0.5,
		viewport_size.y * 0.535 + 72.0
	)
	how_to_button.size = Vector2(button_width, 54.0)


func _on_viewport_resized() -> void:
	_layout_interface()
	queue_redraw()


func _on_play_pressed() -> void:
	if not ResourceLoader.exists(main_scene_path):
		push_error(
			"Не найдена сцена Main: %s. "
			% main_scene_path
			+ "Проверьте main_scene_path в Start.gd."
		)
		return

	var error := get_tree().change_scene_to_file(main_scene_path)
	if error != OK:
		push_error("Не удалось открыть сцену Main. Код ошибки: %s" % error)


func _on_how_to_pressed() -> void:
	var path := "res://scenes/HowToPlay/HowToPlay.tscn"

	if not ResourceLoader.exists(path):
		push_error("Не найдена сцена обучения: %s" % path)
		return

	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Не удалось открыть сцену обучения. Код ошибки: %s" % error)
