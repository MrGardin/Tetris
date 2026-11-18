extends Node2D
## Экран выбора сетевого режима Tetris:Windbound.

const SPACE := Color("#030509")
const WHITE := Color("#f0f3f8")
const MUTED := Color("#a6b0c0")
const ICON_LIGHT := Color("#e4ebf6")
const ICON_DARK := Color("#182130")

const PIECE_SHAPES: Array = [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
]


class TetrominoIcon extends Control:
	var piece_index := 0

	func _draw() -> void:
		var shape: Array = PIECE_SHAPES[clampi(piece_index, 0, PIECE_SHAPES.size() - 1)]
		var cell_size := 13.0
		var min_cell := Vector2i(999, 999)
		var max_cell := Vector2i(-999, -999)

		for cell: Vector2i in shape:
			min_cell.x = mini(min_cell.x, cell.x)
			min_cell.y = mini(min_cell.y, cell.y)
			max_cell.x = maxi(max_cell.x, cell.x)
			max_cell.y = maxi(max_cell.y, cell.y)

		var shape_size := Vector2(
			float(max_cell.x - min_cell.x + 1) * cell_size,
			float(max_cell.y - min_cell.y + 1) * cell_size
		)
		var origin := (size - shape_size) * 0.5

		for cell: Vector2i in shape:
			var local_cell := Vector2(
				float(cell.x - min_cell.x),
				float(cell.y - min_cell.y)
			)
			var rect := Rect2(
				origin + local_cell * cell_size,
				Vector2.ONE * (cell_size - 1.0)
			)
			draw_rect(rect, ICON_DARK)
			draw_rect(rect.grow(-1.4), ICON_LIGHT)


var viewport_size := Vector2(540.0, 960.0)
var elapsed := 0.0
var stars: Array[Vector4] = []
var star_speeds: Array[Vector2] = []

var network: LanClient

var root_control: Control
var scroll: ScrollContainer
var center: CenterContainer
var content: VBoxContainer
var cards: Array[Button] = []

var status_label: Label
var cancel_button: Button

var modal_layer: Control
var room_panel: PanelContainer
var room_code_input: LineEdit


func _ready() -> void:
	randomize()
	viewport_size = get_viewport_rect().size

	for i in 150:
		stars.append(Vector4(
			randf(),
			randf(),
			randf_range(0.7, 1.8),
			randf_range(0.0, TAU)
		))
		star_speeds.append(Vector2(
			randf_range(-4.0, 4.0),
			randf_range(2.0, 11.0)
		))

	network = LanClient.new()
	add_child(network)
	network.status_changed.connect(_on_network_status)
	network.room_created.connect(_on_room_created)
	network.match_found.connect(_on_match_found)
	network.opponent_left.connect(_on_opponent_left)

	_build_interface()
	_update_safe_area()

	get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(network):
		network.close_connection()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

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

	_draw_planet()
	_draw_stars()
	_draw_meteors()
	_draw_floating_blocks()
	_draw_logo()


func _draw_planet() -> void:
	var planet_center := Vector2(viewport_size.x * 0.89, viewport_size.y * 0.18)
	var radius := minf(viewport_size.x * 0.095, 52.0)

	_draw_ellipse(
		planet_center,
		Vector2(radius * 1.8, radius * 0.45),
		Color(0.72, 0.78, 0.88, 0.13),
		1.0
	)

	draw_circle(planet_center, radius, Color("#0b1018"))
	draw_arc(
		planet_center,
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


func _draw_meteors() -> void:
	for i in 3:
		var cycle := fposmod(elapsed + float(i) * 2.7, 8.0)
		if cycle > 1.0:
			continue

		var x := fposmod(float(i) * 0.37 + 0.18 + cycle * 0.70, 1.0)
		var y := fposmod(float(i) * 0.23 + cycle * 0.52, 1.0)
		var head := Vector2(x * viewport_size.x, y * viewport_size.y)
		var tail := head + Vector2(-23.0, -15.0)

		draw_line(tail, head, Color(0.74, 0.84, 1.0, 0.08), 3.0, true)
		draw_line(tail, head, Color(0.90, 0.94, 1.0, 0.48), 1.0, true)
		draw_circle(head, 1.2, Color(1.0, 1.0, 1.0, 0.75))


func _draw_floating_blocks() -> void:
	var cell_size := clampf(viewport_size.x * 0.04, 16.0, 23.0)
	var drift := sin(elapsed * 0.7) * 6.0

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.08, viewport_size.y * 0.48 + drift),
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
		Vector2(viewport_size.x * 0.92, viewport_size.y * 0.70 - drift),
		cell_size,
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(0, 1),
			Vector2i(1, 1)
		],
		Color(0.78, 0.84, 0.94, 0.07)
	)


func _draw_ghost_piece(
	center_point: Vector2,
	cell_size: float,
	cells: Array[Vector2i],
	color: Color
) -> void:
	for cell in cells:
		var rect := Rect2(
			center_point + Vector2(cell) * cell_size
				- Vector2.ONE * cell_size * 0.5,
			Vector2.ONE * cell_size
		)
		draw_rect(rect, color, false, 1.0, true)


func _draw_logo() -> void:
	var logo_center := Vector2(viewport_size.x * 0.86, viewport_size.y * 0.105)
	var cell_size := clampf(viewport_size.x * 0.025, 11.0, 15.0)

	_draw_ellipse(
		logo_center,
		Vector2(cell_size * 2.5, cell_size * 0.75),
		Color(0.72, 0.79, 0.91, 0.17),
		1.0
	)

	for cell in [
		Vector2i(-1, 0),
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, -1)
	]:
		var rect := Rect2(
			logo_center + Vector2(cell) * cell_size
				- Vector2.ONE * cell_size * 0.5,
			Vector2.ONE * cell_size
		)
		draw_rect(rect.grow(1.0), Color("#05070b"))
		draw_rect(rect.grow(-1.5), Color("#e9edf3"))


func _draw_ellipse(
	center_point: Vector2,
	radii: Vector2,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()

	for i in 65:
		var angle := TAU * float(i) / 64.0
		points.append(
			center_point + Vector2(
				cos(angle) * radii.x,
				sin(angle) * radii.y
			)
		)

	draw_polyline(points, color, width, true)


func _build_interface() -> void:
	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)

	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(root_control)

	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root_control.add_child(scroll)

	center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("separation", 12)
	center.add_child(content)

	_add_header()
	_add_status()
	_add_cards()
	_build_join_dialog()


func _add_header() -> void:
	var title := Label.new()
	title.text = "СЕТЕВАЯ ИГРА"
	title.custom_minimum_size = Vector2(0.0, 40.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", WHITE)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ВЫБЕРИ, КАК НАЧАТЬ МАТЧ"
	subtitle.custom_minimum_size = Vector2(0.0, 22.0)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", MUTED)
	content.add_child(subtitle)


func _add_status() -> void:
	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(0.0, 58.0)
	status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.88)
	style.border_color = Color(0.46, 0.55, 0.68, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	status_panel.add_theme_stylebox_override("panel", style)
	content.add_child(status_panel)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	status_panel.add_child(column)

	status_label = Label.new()
	status_label.text = "Подключись к серверу, чтобы начать."
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", MUTED)
	column.add_child(status_label)

	cancel_button = Button.new()
	cancel_button.text = "ОТМЕНИТЬ ПОИСК"
	cancel_button.custom_minimum_size = Vector2(0.0, 38.0)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.visible = false
	cancel_button.add_theme_font_size_override("font_size", 12)
	cancel_button.add_theme_color_override("font_color", WHITE)
	cancel_button.add_theme_stylebox_override("normal", _make_small_button_style(false))
	cancel_button.add_theme_stylebox_override("hover", _make_small_button_style(true))
	cancel_button.add_theme_stylebox_override("pressed", _make_small_button_style(true))
	cancel_button.pressed.connect(_on_cancel_search_pressed)
	column.add_child(cancel_button)


func _add_cards() -> void:
	var random_card := _create_card(
		0,
		"НАЙТИ СЛУЧАЙНОГО ИГРОКА",
		"Найти соперника через интернет."
	)
	random_card.pressed.connect(_on_find_random_pressed)
	cards.append(random_card)
	content.add_child(random_card)

	var create_card := _create_card(
		1,
		"СОЗДАТЬ КОМНАТУ",
		"Создать комнату и получить код для друга."
	)
	create_card.pressed.connect(_on_create_room_pressed)
	cards.append(create_card)
	content.add_child(create_card)

	var join_card := _create_card(
		2,
		"ПРИСОЕДИНИТЬСЯ К КОМНАТЕ",
		"Ввести код комнаты и подключиться к другу."
	)
	join_card.pressed.connect(_on_join_room_pressed)
	cards.append(join_card)
	content.add_child(join_card)


func _create_card(
	piece_index: int,
	heading: String,
	description: String
) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0.0, 108.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _make_card_style(0))
	button.add_theme_stylebox_override("hover", _make_card_style(1))
	button.add_theme_stylebox_override("pressed", _make_card_style(2))
	button.add_theme_stylebox_override("focus", _make_card_style(1))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_top = 10.0
	row.offset_right = -14.0
	row.offset_bottom = -10.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var icon := TetrominoIcon.new()
	icon.piece_index = piece_index
	icon.custom_minimum_size = Vector2(48.0, 48.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 5)
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)

	var title := Label.new()
	title.text = heading
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", WHITE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(title)

	var detail := Label.new()
	detail.text = description
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", MUTED)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(detail)

	return button


func _make_card_style(state: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(7)
	style.set_border_width_all(1)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	match state:
		0:
			style.bg_color = Color(0.035, 0.045, 0.065, 0.92)
			style.border_color = Color(0.58, 0.66, 0.79, 0.55)
		1:
			style.bg_color = Color(0.08, 0.11, 0.16, 0.97)
			style.border_color = Color(0.82, 0.88, 0.98, 0.88)
		2:
			style.bg_color = Color(0.10, 0.14, 0.20, 0.98)
			style.border_color = Color(0.74, 0.84, 1.0, 0.95)

	return style


func _make_small_button_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(5)
	style.set_border_width_all(1)
	style.bg_color = Color(0.08, 0.11, 0.16, 0.94) if highlighted else Color(0.035, 0.045, 0.065, 0.90)
	style.border_color = Color(0.82, 0.88, 0.98, 0.72)
	return style


func _build_join_dialog() -> void:
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.visible = false
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(modal_layer)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(shade)

	room_panel = PanelContainer.new()
	room_panel.custom_minimum_size = Vector2(300.0, 190.0)
	room_panel.add_theme_stylebox_override("panel", _make_dialog_style())
	modal_layer.add_child(room_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	room_panel.add_child(column)

	var heading := Label.new()
	heading.text = "КОД КОМНАТЫ"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", WHITE)
	column.add_child(heading)

	room_code_input = LineEdit.new()
	room_code_input.placeholder_text = "Например: H57QAY"
	room_code_input.max_length = 12
	room_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_code_input.add_theme_font_size_override("font_size", 18)
	column.add_child(room_code_input)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)

	var cancel := Button.new()
	cancel.text = "ОТМЕНА"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size.y = 44.0
	cancel.add_theme_color_override("font_color", WHITE)
	cancel.add_theme_stylebox_override("normal", _make_small_button_style(false))
	cancel.add_theme_stylebox_override("hover", _make_small_button_style(true))
	cancel.pressed.connect(_close_join_dialog)
	buttons.add_child(cancel)

	var join := Button.new()
	join.text = "ВОЙТИ"
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.custom_minimum_size.y = 44.0
	join.add_theme_color_override("font_color", WHITE)
	join.add_theme_stylebox_override("normal", _make_small_button_style(false))
	join.add_theme_stylebox_override("hover", _make_small_button_style(true))
	join.pressed.connect(_submit_room_code)
	buttons.add_child(join)


func _make_dialog_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#080d15")
	style.border_color = Color(0.72, 0.80, 0.92, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


func _update_safe_area() -> void:
	viewport_size = get_viewport_rect().size

	var side_margin := minf(20.0, viewport_size.x * 0.05)
	var safe_top := maxf(52.0, viewport_size.y * 0.055)
	var safe_bottom := maxf(32.0, viewport_size.y * 0.04)
	var available_width := maxf(240.0, viewport_size.x - side_margin * 2.0)
	var available_height := maxf(1.0, viewport_size.y - safe_top - safe_bottom)

	scroll.offset_left = side_margin
	scroll.offset_top = safe_top
	scroll.offset_right = -side_margin
	scroll.offset_bottom = -safe_bottom

	content.custom_minimum_size.x = available_width
	for card in cards:
		card.custom_minimum_size.x = available_width

	var content_height := content.get_combined_minimum_size().y
	center.custom_minimum_size = Vector2(
		available_width,
		maxf(available_height, content_height)
	)

	var dialog_width := minf(340.0, viewport_size.x - 36.0)
	room_panel.custom_minimum_size.x = dialog_width
	room_panel.position = Vector2(
		(viewport_size.x - dialog_width) * 0.5,
		(viewport_size.y - room_panel.custom_minimum_size.y) * 0.5
	)

	scroll.queue_sort()
	center.queue_sort()
	content.queue_sort()


func _on_find_random_pressed() -> void:
	cancel_button.visible = true
	_set_status("Подключаемся и ищем соперника...")
	network.find_random_player()


func _on_cancel_search_pressed() -> void:
	network.cancel_search()
	cancel_button.visible = false


func _on_create_room_pressed() -> void:
	cancel_button.visible = false
	_set_status("Создаём комнату...")
	network.create_room()


func _on_join_room_pressed() -> void:
	room_code_input.text = ""
	modal_layer.visible = true
	_update_safe_area()
	room_code_input.grab_focus()


func _submit_room_code() -> void:
	var code := room_code_input.text.strip_edges().to_upper()

	if code.is_empty():
		_set_status("Введи код комнаты.")
		return

	modal_layer.visible = false
	cancel_button.visible = false
	_set_status("Подключаемся к комнате %s..." % code)
	network.join_room(code)


func _close_join_dialog() -> void:
	modal_layer.visible = false


func _on_network_status(text: String) -> void:
	_set_status(text)

	if text != "Ищем случайного соперника...":
		if not text.begins_with("Подключаемся") and not text.begins_with("Подключено"):
			cancel_button.visible = false


func _on_room_created(room_code: String) -> void:
	_set_status("Комната создана. Передай другу код: %s" % room_code)
	cancel_button.visible = false


func _on_match_found(room_code: String, role: String) -> void:
	cancel_button.visible = false
	_set_status("Соперник найден! Комната %s · роль %s" % [room_code, role])


func _on_opponent_left() -> void:
	cancel_button.visible = false


func _set_status(text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = text


func _on_viewport_resized() -> void:
	_update_safe_area()
	queue_redraw()
