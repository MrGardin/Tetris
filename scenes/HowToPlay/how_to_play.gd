extends Node2D
## Экран обучения для Tetris:Windbound.

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

var overlay: Control
var title_label: Label
var subtitle_label: Label
var cards_box: VBoxContainer
var objective_panel: PanelContainer
var keyboard_label: Label
var back_button: Button
var play_button: Button


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

	_draw_background()
	_draw_distant_planet()
	_draw_stars()
	_draw_floating_blocks()
	_draw_logo()


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), SPACE)

	draw_circle(
		Vector2(viewport_size.x * 0.08, viewport_size.y * 0.48),
		viewport_size.x * 0.30,
		Color(0.035, 0.055, 0.095, 0.38)
	)

	draw_circle(
		Vector2(viewport_size.x * 0.94, viewport_size.y * 0.75),
		viewport_size.x * 0.34,
		Color(0.075, 0.025, 0.045, 0.20)
	)


func _draw_distant_planet() -> void:
	var center := Vector2(viewport_size.x * 0.84, viewport_size.y * 0.18)
	var radius := viewport_size.x * 0.105

	_draw_ellipse(
		center,
		Vector2(radius * 1.9, radius * 0.48),
		Color(0.72, 0.78, 0.88, 0.16),
		1.0
	)

	draw_circle(center, radius, Color("#0b1018"))
	draw_arc(
		center,
		radius,
		-2.3,
		0.8,
		48,
		Color(0.81, 0.86, 0.94, 0.22),
		1.0,
		true
	)


func _draw_stars() -> void:
	for i in stars.size():
		var star := stars[i]
		var drift := elapsed * (3.0 + star.z * 1.6)
		var x := fposmod(star.x * viewport_size.x + drift, viewport_size.x)
		var y := star.y * viewport_size.y
		var shimmer := 0.36 + 0.54 * (
			0.5 + 0.5 * sin(elapsed * 1.3 + star.w)
		)
		var position := Vector2(x, y)

		draw_circle(position, star.z, Color(0.88, 0.92, 1.0, shimmer))

		if star.z > 1.65:
			draw_line(
				position - Vector2(3.0, 0.0),
				position + Vector2(3.0, 0.0),
				Color(0.88, 0.92, 1.0, shimmer * 0.4),
				0.7,
				true
			)


func _draw_floating_blocks() -> void:
	var cell_size := clampf(viewport_size.x * 0.045, 18.0, 25.0)
	var drift := sin(elapsed * 0.7) * 7.0

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.13, viewport_size.y * 0.47 + drift),
		cell_size,
		[
			Vector2i(-1, 0),
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(1, -1)
		],
		Color(0.78, 0.84, 0.94, 0.12)
	)

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.87, viewport_size.y * 0.66 - drift),
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
	var center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.205)
	var cell_size := clampf(viewport_size.x * 0.045, 20.0, 26.0)

	_draw_ellipse(
		center,
		Vector2(cell_size * 2.7, cell_size * 0.82),
		Color(0.72, 0.79, 0.91, 0.23),
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
		draw_rect(rect.grow(1.5), Color("#05070b"))
		draw_rect(rect.grow(-2.0), fill)

	for i in 3:
		var angle := elapsed * 0.65 + TAU * float(i) / 3.0
		var point := center + Vector2(
			cos(angle) * cell_size * 2.3,
			sin(angle) * cell_size * 0.66
		)
		draw_circle(point, 1.6, Color(0.90, 0.94, 1.0, 0.75))


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
	title_label.text = "КАК ИГРАТЬ"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", WHITE)
	overlay.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "УПРАВЛЕНИЕ И ЦЕЛЬ ПОЛЁТА"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", MUTED)
	overlay.add_child(subtitle_label)

	cards_box = VBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 9)
	overlay.add_child(cards_box)

	cards_box.add_child(_create_control_card(
		"←",
		"ВЛЕВО",
		"Перемещает активную фигуру на одну клетку влево."
	))

	cards_box.add_child(_create_control_card(
		"↻",
		"ПОВОРОТ",
		"Поворачивает активную фигуру на 90°."
	))

	cards_box.add_child(_create_control_card(
		"→",
		"ВПРАВО",
		"Перемещает активную фигуру на одну клетку вправо."
	))

	objective_panel = _create_objective_panel()
	overlay.add_child(objective_panel)

	keyboard_label = Label.new()
	keyboard_label.text = "Клавиатура: ← / A — влево, ↑ / W — поворот, → / D — вправо."
	keyboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyboard_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keyboard_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keyboard_label.add_theme_font_size_override("font_size", 11)
	keyboard_label.add_theme_color_override("font_color", MUTED)
	overlay.add_child(keyboard_label)

	back_button = _create_button("НАЗАД В МЕНЮ", false)
	back_button.pressed.connect(_on_back_pressed)
	overlay.add_child(back_button)

	play_button = _create_button("ИГРАТЬ", true)
	play_button.pressed.connect(_on_play_pressed)
	overlay.add_child(play_button)


func _create_control_card(
	icon_text: String,
	heading: String,
	description: String
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 78.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style(false))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var icon := Label.new()
	icon.text = icon_text
	icon.custom_minimum_size = Vector2(54.0, 0.0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 30)
	icon.add_theme_color_override("font_color", RED if heading == "ПОВОРОТ" else WHITE)
	row.add_child(icon)

	var text_column := VBoxContainer.new()
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 2)
	row.add_child(text_column)

	var title := Label.new()
	title.text = heading
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", WHITE)
	text_column.add_child(title)

	var detail := Label.new()
	detail.text = description
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", MUTED)
	text_column.add_child(detail)

	return panel


func _create_objective_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(true))

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)

	var heading := Label.new()
	heading.text = "ЦЕЛЬ"
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", WHITE)
	content.add_child(heading)

	var description := Label.new()
	description.text = (
		"Собирай башню до верхней пунктирной линии и удерживай её там "
		+ "до конца отсчёта. В соревновательном режиме побеждает тот, "
		+ "кто сделает это раньше соперника."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", MUTED)
	content.add_child(description)

	var note := Label.new()
	note.text = "Сейчас соперник ещё не добавлен — пока можно тренироваться в одиночку."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color("#ff8995"))
	content.add_child(note)

	return panel


func _make_panel_style(is_objective: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.065, 0.92)
	style.border_color = (
		Color(0.92, 0.25, 0.34, 0.72)
		if is_objective
		else Color(0.58, 0.66, 0.79, 0.42)
	)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


func _create_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 15)

	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(4)
	normal.set_border_width_all(1)
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0
	normal.content_margin_top = 9.0
	normal.content_margin_bottom = 9.0

	var hover := StyleBoxFlat.new()
	hover.set_corner_radius_all(4)
	hover.set_border_width_all(1)
	hover.content_margin_left = 16.0
	hover.content_margin_right = 16.0
	hover.content_margin_top = 9.0
	hover.content_margin_bottom = 9.0

	var pressed := StyleBoxFlat.new()
	pressed.set_corner_radius_all(4)
	pressed.set_border_width_all(1)
	pressed.content_margin_left = 16.0
	pressed.content_margin_right = 16.0
	pressed.content_margin_top = 9.0
	pressed.content_margin_bottom = 9.0

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
		normal.bg_color = Color(0.03, 0.04, 0.06, 0.70)
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

	var width := viewport_size.x
	var height := viewport_size.y
	var content_width := minf(460.0, width - 36.0)
	var center_x := width * 0.5

	title_label.position = Vector2(center_x - content_width * 0.5, height * 0.075)
	title_label.size = Vector2(content_width, 42.0)

	subtitle_label.position = Vector2(center_x - content_width * 0.5, height * 0.125)
	subtitle_label.size = Vector2(content_width, 24.0)

	var cards_y := height * 0.255
	var card_height := clampf(height * 0.082, 70.0, 86.0)
	cards_box.position = Vector2(center_x - content_width * 0.5, cards_y)
	cards_box.size = Vector2(content_width, card_height * 3.0 + 18.0)

	for card in cards_box.get_children():
		card.custom_minimum_size.y = card_height

	objective_panel.position = Vector2(
		center_x - content_width * 0.5,
		height * 0.555
	)
	objective_panel.size = Vector2(content_width, height * 0.175)

	keyboard_label.position = Vector2(
		center_x - content_width * 0.5,
		height * 0.745
	)
	keyboard_label.size = Vector2(content_width, 40.0)

	var button_width := minf(340.0, width - 64.0)
	var button_height := 48.0
	var buttons_y := height * 0.835

	back_button.position = Vector2(
		center_x - button_width * 0.5,
		buttons_y
	)
	back_button.size = Vector2(button_width, button_height)

	play_button.position = Vector2(
		center_x - button_width * 0.5,
		buttons_y + button_height + 10.0
	)
	play_button.size = Vector2(button_width, button_height)


func _on_viewport_resized() -> void:
	_layout_interface()
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
		push_error("Не удалось открыть сцену %s. Код ошибки: %s" % [path, error])
