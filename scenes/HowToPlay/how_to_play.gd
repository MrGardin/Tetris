extends Node2D
## Экран обучения для Tetris:Windbound.
## Интерфейс перестраивается под размер экрана и прокручивается на телефонах.

@export_file("*.tscn")
var start_scene_path: String = "res://scenes/Start/Start.tscn"

@export_file("*.tscn")
var main_scene_path: String = "res://Main.tscn"

const SPACE := Color("#030509")
const WHITE := Color("#f0f3f8")
const MUTED := Color("#a6b0c0")
const RED := Color("#ff4055")

var viewport_size := Vector2(540.0, 960.0)
var elapsed := 0.0
var stars: Array[Vector4] = []

var scroll: ScrollContainer
var content: VBoxContainer
var title_label: Label
var subtitle_label: Label
var back_button: Button
var play_button: Button


func _ready() -> void:
	randomize()
	viewport_size = get_viewport_rect().size

	for i in 180:
		stars.append(Vector4(
			randf(),
			randf(),
			randf_range(0.7, 1.8),
			randf_range(0.0, TAU)
		))

	_build_interface()

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
	_draw_floating_blocks()
	_draw_logo()


func _draw_background() -> void:
	draw_rect(
		Rect2(Vector2.ZERO, viewport_size),
		SPACE
	)

	draw_circle(
		Vector2(viewport_size.x * 0.05, viewport_size.y * 0.48),
		viewport_size.x * 0.28,
		Color(0.035, 0.055, 0.095, 0.32)
	)

	draw_circle(
		Vector2(viewport_size.x * 0.97, viewport_size.y * 0.76),
		viewport_size.x * 0.31,
		Color(0.075, 0.025, 0.045, 0.17)
	)


func _draw_planet() -> void:
	# Планета находится у края и не залезает на основной текст.
	var center := Vector2(viewport_size.x * 0.88, viewport_size.y * 0.18)
	var radius := minf(viewport_size.x * 0.105, 56.0)

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
		var drift := elapsed * (2.0 + star.z)
		var x := fposmod(star.x * viewport_size.x + drift, viewport_size.x)
		var y := star.y * viewport_size.y
		var shimmer := 0.35 + 0.50 * (
			0.5 + 0.5 * sin(elapsed * 1.2 + star.w)
		)
		var point := Vector2(x, y)

		draw_circle(
			point,
			star.z,
			Color(0.88, 0.92, 1.0, shimmer)
		)

		if star.z > 1.5:
			draw_line(
				point - Vector2(2.5, 0.0),
				point + Vector2(2.5, 0.0),
				Color(0.88, 0.92, 1.0, shimmer * 0.35),
				0.7,
				true
			)


func _draw_floating_blocks() -> void:
	var cell_size := clampf(viewport_size.x * 0.04, 16.0, 23.0)
	var drift := sin(elapsed * 0.7) * 6.0

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.11, viewport_size.y * 0.48 + drift),
		cell_size,
		[
			Vector2i(-1, 0),
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(1, -1)
		],
		Color(0.78, 0.84, 0.94, 0.09)
	)

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.89, viewport_size.y * 0.69 - drift),
		cell_size,
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(0, 1),
			Vector2i(1, 1)
		],
		Color(0.92, 0.34, 0.42, 0.08)
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
	# Маленький декоративный знак сверху справа — не перекрывает инструкции.
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

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_layer.add_child(root)

	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18.0
	scroll.offset_top = 20.0
	scroll.offset_right = -18.0
	scroll.offset_bottom = -20.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	root.add_child(scroll)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	_build_header()
	_build_control_cards()
	_build_objective_card()
	_build_keyboard_hint()
	_build_buttons()


func _build_header() -> void:
	title_label = Label.new()
	title_label.text = "КАК ИГРАТЬ"
	title_label.custom_minimum_size = Vector2(0.0, 42.0)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", WHITE)
	content.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "УПРАВЛЕНИЕ И ЦЕЛЬ ИГРЫ"
	subtitle_label.custom_minimum_size = Vector2(0.0, 24.0)
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", MUTED)
	content.add_child(subtitle_label)


func _build_control_cards() -> void:
	content.add_child(_create_control_card(
		"←",
		"ВЛЕВО",
		"Нажми кнопку со стрелкой влево, чтобы сдвинуть фигуру на одну клетку."
	))

	content.add_child(_create_control_card(
		"↻",
		"ПОВОРОТ",
		"Нажми среднюю кнопку, чтобы повернуть фигуру на 90°."
	))

	content.add_child(_create_control_card(
		"→",
		"ВПРАВО",
		"Нажми кнопку со стрелкой вправо, чтобы сдвинуть фигуру на одну клетку."
	))


func _create_control_card(
	icon_text: String,
	heading: String,
	description: String
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 84.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(false))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var icon := Label.new()
	icon.text = icon_text
	icon.custom_minimum_size = Vector2(48.0, 0.0)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 27)
	icon.add_theme_color_override(
		"font_color",
		RED if heading == "ПОВОРОТ" else WHITE
	)
	row.add_child(icon)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 3)
	row.add_child(text_column)

	var title := Label.new()
	title.text = heading
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", WHITE)
	text_column.add_child(title)

	var detail := Label.new()
	detail.text = description
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", MUTED)
	text_column.add_child(detail)

	return panel


func _build_objective_card() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 178.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(true))
	content.add_child(panel)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 8)
	panel.add_child(text_column)

	var heading := Label.new()
	heading.text = "ЦЕЛЬ"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", WHITE)
	text_column.add_child(heading)

	var description := Label.new()
	description.text = (
		"Дострой башню до верхней пунктирной линии и удерживай её там "
		+ "5 секунд. В будущем соревновательном режиме победит тот, "
		+ "кто выполнит это раньше соперника."
	)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", MUTED)
	text_column.add_child(description)

	var note := Label.new()
	note.text = "Сейчас соперников в игре ещё нет — можно тренироваться в одиночку."
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color("#ff8995"))
	text_column.add_child(note)


func _build_keyboard_hint() -> void:
	var hint := Label.new()
	hint.text = "Дополнительно: ← / A — влево, ↑ / W — поворот, → / D — вправо."
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.custom_minimum_size = Vector2(0.0, 42.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED)
	content.add_child(hint)


func _build_buttons() -> void:
	back_button = _create_button("НАЗАД В МЕНЮ", false)
	back_button.pressed.connect(_on_back_pressed)
	content.add_child(back_button)

	play_button = _create_button("ИГРАТЬ", true)
	play_button.pressed.connect(_on_play_pressed)
	content.add_child(play_button)


func _make_panel_style(is_objective: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.065, 0.94)

	if is_objective:
		style.border_color = Color(0.92, 0.25, 0.34, 0.72)
	else:
		style.border_color = Color(0.58, 0.66, 0.79, 0.48)

	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0

	return style


func _create_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 15)

	var normal := StyleBoxFlat.new()
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0

	var hover := StyleBoxFlat.new()
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(5)
	hover.content_margin_top = 10.0
	hover.content_margin_bottom = 10.0

	var pressed := StyleBoxFlat.new()
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(5)
	pressed.content_margin_top = 10.0
	pressed.content_margin_bottom = 10.0

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


func _on_viewport_resized() -> void:
	viewport_size = get_viewport_rect().size
	queue_redraw()


func _on_back_pressed() -> void:
	_change_scene(start_scene_path)


func _on_play_pressed() -> void:
	_change_scene(main_scene_path)


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("Сцена не найдена: %s" % path)
		return

	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error(
			"Не удалось открыть сцену %s. Код ошибки: %s"
			% [path, error]
		)
