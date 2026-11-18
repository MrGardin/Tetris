extends Node2D
## Экран обучения для Tetris:Windbound.
## Центрируется между безопасными отступами; при нехватке места прокручивается.

@export_file("*.tscn")
var start_scene_path: String = "res://scenes/Start/Start.tscn"

@export_file("*.tscn")
var multiplayer_menu_scene_path: String = "res://scenes/MultiplayerMenu/MultiplayerMenu.tscn"

const SPACE := Color("#030509")
const WHITE := Color("#f0f3f8")
const MUTED := Color("#a6b0c0")
const RED := Color("#ff4055")

var viewport_size := Vector2(540.0, 960.0)
var elapsed := 0.0

# x, y — начальная позиция; z — размер; w — фаза мерцания.
var stars: Array[Vector4] = []
var star_speeds: Array[Vector2] = []

var scroll: ScrollContainer
var content: VBoxContainer


func _ready() -> void:
	randomize()
	viewport_size = get_viewport_rect().size

	for i in 150:
		stars.append(Vector4(
			randf(),
			randf(),
			randf_range(0.7, 1.7),
			randf_range(0.0, TAU)
		))
		star_speeds.append(Vector2(
			randf_range(-3.0, 3.0),
			randf_range(2.0, 9.0)
		))

	_build_interface()
	_update_safe_area()

	get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_draw_background()
	_draw_planet()
	_draw_stars()
	_draw_shooting_stars()
	_draw_floating_blocks()
	_draw_logo()


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), SPACE)

	draw_circle(
		Vector2(viewport_size.x * 0.04, viewport_size.y * 0.48),
		viewport_size.x * 0.28,
		Color(0.035, 0.055, 0.095, 0.32)
	)

	draw_circle(
		Vector2(viewport_size.x * 0.97, viewport_size.y * 0.76),
		viewport_size.x * 0.31,
		Color(0.075, 0.025, 0.045, 0.17)
	)


func _draw_planet() -> void:
	var center := Vector2(viewport_size.x * 0.90, viewport_size.y * 0.18)
	var radius := minf(viewport_size.x * 0.095, 52.0)

	_draw_ellipse(
		center,
		Vector2(radius * 1.8, radius * 0.45),
		Color(0.72, 0.78, 0.88, 0.13),
		1.0
	)
	draw_circle(center, radius, Color("#0b1018"))
	draw_arc(
		center,
		radius,
		-2.3,
		0.8,
		48,
		Color(0.81, 0.86, 0.94, 0.18),
		1.0,
		true
	)


func _draw_stars() -> void:
	for i in stars.size():
		var star := stars[i]
		var speed := star_speeds[i]

		var x := fposmod(
			star.x * viewport_size.x + speed.x * elapsed,
			viewport_size.x
		)
		var y := fposmod(
			star.y * viewport_size.y + speed.y * elapsed,
			viewport_size.y
		)
		var twinkle := 0.5 + 0.5 * sin(elapsed * 2.0 + star.w)
		var alpha := 0.22 + 0.70 * twinkle
		var point := Vector2(x, y)

		if star.z > 1.35 and twinkle > 0.78:
			draw_circle(
				point,
				star.z * 3.5,
				Color(0.56, 0.70, 1.0, 0.045 + twinkle * 0.055)
			)

		draw_circle(point, star.z, Color(0.88, 0.92, 1.0, alpha))

		if star.z > 1.45:
			draw_line(
				point - Vector2(2.5, 0.0),
				point + Vector2(2.5, 0.0),
				Color(0.88, 0.92, 1.0, alpha * 0.35),
				0.7,
				true
			)


func _draw_shooting_stars() -> void:
	# Редкие небольшие метеоры пролетают по диагонали.
	for i in 3:
		var cycle := fposmod(elapsed + float(i) * 2.7, 8.0)
		if cycle > 1.0:
			continue

		var progress := cycle
		var x := fposmod(
			float(i) * 0.37 + 0.18 + progress * 0.70,
			1.0
		)
		var y := fposmod(
			float(i) * 0.23 + progress * 0.52,
			1.0
		)
		var head := Vector2(x * viewport_size.x, y * viewport_size.y)
		var tail := head + Vector2(-22.0, -14.0)

		draw_line(tail, head, Color(0.74, 0.84, 1.0, 0.08), 3.0, true)
		draw_line(tail, head, Color(0.90, 0.94, 1.0, 0.48), 1.0, true)
		draw_circle(head, 1.2, Color(1.0, 1.0, 1.0, 0.75))


func _draw_floating_blocks() -> void:
	var cell_size := clampf(viewport_size.x * 0.04, 16.0, 23.0)
	var drift := sin(elapsed * 0.7) * 6.0

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.09, viewport_size.y * 0.48 + drift),
		cell_size,
		[
			Vector2i(-1, 0),
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(1, -1)
		],
		Color(0.78, 0.84, 0.94, 0.08)
	)

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.91, viewport_size.y * 0.70 - drift),
		cell_size,
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(0, 1),
			Vector2i(1, 1)
		],
		Color(0.92, 0.34, 0.42, 0.07)
	)


func _draw_ghost_piece(
	center: Vector2,
	cell_size: float,
	cells: Array[Vector2i],
	color: Color
) -> void:
	for cell in cells:
		var rect := Rect2(
			center + Vector2(cell) * cell_size
				- Vector2.ONE * cell_size * 0.5,
			Vector2.ONE * cell_size
		)
		draw_rect(rect, color, false, 1.0, true)


func _draw_logo() -> void:
	var center := Vector2(viewport_size.x * 0.86, viewport_size.y * 0.105)
	var cell_size := clampf(viewport_size.x * 0.025, 11.0, 15.0)

	_draw_ellipse(
		center,
		Vector2(cell_size * 2.5, cell_size * 0.75),
		Color(0.72, 0.79, 0.91, 0.17),
		1.0
	)

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
		var fill := RED if i == 3 else Color("#e9edf3")
		draw_rect(rect.grow(1.0), Color("#05070b"))
		draw_rect(rect.grow(-1.5), fill)


func _draw_ellipse(
	center: Vector2,
	radii: Vector2,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()

	for i in 65:
		var angle := TAU * float(i) / 64.0
		points.append(center + Vector2(
			cos(angle) * radii.x,
			sin(angle) * radii.y
		))

	draw_polyline(points, color, width, true)


func _build_interface() -> void:
	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_layer.add_child(root)

	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	root.add_child(scroll)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	_add_header()
	_add_control_cards()
	_add_objective_card()
	_add_buttons()


func _add_header() -> void:
	var title := Label.new()
	title.text = "КАК ИГРАТЬ"
	title.custom_minimum_size = Vector2(0.0, 38.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", WHITE)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "УПРАВЛЕНИЕ И ЦЕЛЬ ИГРЫ"
	subtitle.custom_minimum_size = Vector2(0.0, 22.0)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", MUTED)
	content.add_child(subtitle)


func _add_control_cards() -> void:
	content.add_child(_create_control_card(
		"←",
		"ВЛЕВО",
		"Сдвинь активную фигуру на одну клетку влево."
	))

	content.add_child(_create_control_card(
		"↻",
		"ПОВОРОТ",
		"Поверни активную фигуру на 90°."
	))

	content.add_child(_create_control_card(
		"→",
		"ВПРАВО",
		"Сдвинь активную фигуру на одну клетку вправо."
	))


func _create_control_card(
	icon_text: String,
	heading: String,
	description: String
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 76.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(false))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var icon := Label.new()
	icon.text = icon_text
	icon.custom_minimum_size = Vector2(42.0, 0.0)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 25)
	icon.add_theme_color_override("font_color", WHITE)
	row.add_child(icon)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 2)
	row.add_child(text_column)

	var title := Label.new()
	title.text = heading
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", WHITE)
	text_column.add_child(title)

	var detail := Label.new()
	detail.text = description
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", MUTED)
	text_column.add_child(detail)

	return panel


func _add_objective_card() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 150.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(true))
	content.add_child(panel)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "ЦЕЛЬ"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", WHITE)
	column.add_child(heading)

	var description := Label.new()
	description.text = (
		"Дострой башню до верхней пунктирной линии и удерживай её там "
		+ "5 секунд. Побеждает тот, кто первым выполнит это условие."
	)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("font_color", MUTED)
	column.add_child(description)


func _add_buttons() -> void:
	# Порядок поменян: сначала кнопка игры, затем возврат в меню.
	var play_button := _create_button("ИГРАТЬ", true)
	play_button.pressed.connect(_on_play_pressed)
	content.add_child(play_button)

	var back_button := _create_button("НАЗАД В МЕНЮ", false)
	back_button.pressed.connect(_on_back_pressed)
	content.add_child(back_button)


func _make_panel_style(is_objective: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.065, 0.94)
	style.border_color = (
		Color(0.92, 0.25, 0.34, 0.72)
		if is_objective
		else Color(0.58, 0.66, 0.79, 0.48)
	)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _create_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)

	var normal := StyleBoxFlat.new()
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0

	var hover := StyleBoxFlat.new()
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(5)
	hover.content_margin_top = 8.0
	hover.content_margin_bottom = 8.0

	var pressed := StyleBoxFlat.new()
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(5)
	pressed.content_margin_top = 8.0
	pressed.content_margin_bottom = 8.0

	if primary:
		normal.bg_color = Color("#e0e6f0")
		normal.border_color = Color("#f0f3f8")
		hover.bg_color = Color("#ffffff")
		hover.border_color = Color("#ffffff")
		pressed.bg_color = Color("#cbd4e2")
		pressed.border_color = Color("#cbd4e2")

		button.add_theme_color_override("font_color", Color("#080b11"))
		button.add_theme_color_override("font_hover_color", Color("#080b11"))
		button.add_theme_color_override("font_pressed_color", Color("#080b11"))
	else:
		normal.bg_color = Color(0.03, 0.04, 0.06, 0.86)
		normal.border_color = Color(0.77, 0.83, 0.92, 0.62)
		hover.bg_color = Color(0.12, 0.15, 0.21, 0.96)
		hover.border_color = Color("#f0f3f8")
		pressed.bg_color = Color(0.16, 0.07, 0.10, 0.96)
		pressed.border_color = RED

		button.add_theme_color_override("font_color", WHITE)
		button.add_theme_color_override("font_hover_color", WHITE)
		button.add_theme_color_override("font_pressed_color", WHITE)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	return button


func _update_safe_area() -> void:
	viewport_size = get_viewport_rect().size

	# Оставляем место под статус-бар и системную навигацию телефона.
	var safe_top := maxf(52.0, viewport_size.y * 0.055)
	var safe_bottom := maxf(30.0, viewport_size.y * 0.035)
	var side_margin := minf(18.0, viewport_size.x * 0.045)

	scroll.offset_left = side_margin
	scroll.offset_top = safe_top
	scroll.offset_right = -side_margin
	scroll.offset_bottom = -safe_bottom


func _on_viewport_resized() -> void:
	_update_safe_area()
	queue_redraw()


func _on_back_pressed() -> void:
	_change_scene(start_scene_path)


func _on_play_pressed() -> void:
	_change_scene(multiplayer_menu_scene_path)


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("Сцена не найдена: %s" % path)
		return

	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error(
			"Не удалось открыть сцену %s. Код ошибки: %s"
			% [path, error]
		)
