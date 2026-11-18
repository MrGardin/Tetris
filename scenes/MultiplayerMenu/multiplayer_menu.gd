extends Node2D
## Сетевое меню без прокрутки.

const SPACE := Color("#030509")
const WHITE := Color("#f0f3f8")
const MUTED := Color("#a6b0c0")
const ICON_LIGHT := Color("#e4ebf6")
const ICON_DARK := Color("#182130")

@export_file("*.tscn")
var game_scene_path: String = "res://Main.tscn"

@export_file("*.tscn")
var start_scene_path: String = "res://scenes/Start/Start.tscn"

const PIECE_SHAPES: Array = [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
]


class TetrominoIcon extends Control:
	var piece_index := 0

	func _draw() -> void:
		var shape: Array = PIECE_SHAPES[
			clampi(piece_index, 0, PIECE_SHAPES.size() - 1)
		]
		var cell_size := 12.0
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
			draw_rect(rect.grow(-1.3), ICON_LIGHT)


var viewport_size := Vector2(540.0, 960.0)
var elapsed := 0.0
var stars: Array[Vector4] = []
var star_speeds: Array[Vector2] = []

var network: LanClient
var root_control: Control
var safe_area: Control
var content: VBoxContainer
var cards: Array[Button] = []

var status_label: Label
var cancel_button: Button
var join_overlay: Control
var join_panel: PanelContainer
var room_code_input: LineEdit


func _ready() -> void:
	randomize()
	viewport_size = get_viewport_rect().size

	for i in 130:
		stars.append(Vector4(
			randf(),
			randf(),
			randf_range(0.7, 1.7),
			randf_range(0.0, TAU)
		))
		star_speeds.append(Vector2(
			randf_range(-4.0, 4.0),
			randf_range(2.0, 10.0)
		))

	network = get_node_or_null("/root/Net") as LanClient
	if network == null:
		push_error(
			"Не найден Autoload Net. Добавь LanClient.gd "
			+ "в Project Settings → Globals → Autoload с именем Net."
		)

	_build_interface()
	_layout_interface()

	if network != null:
		network.status_changed.connect(_on_network_status)
		network.room_created.connect(_on_room_created)
		network.match_started.connect(_on_match_started)

	get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()


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
	_draw_logo()


func _draw_planet() -> void:
	var center := Vector2(viewport_size.x * 0.89, viewport_size.y * 0.18)
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
		var x := fposmod(star.x * viewport_size.x + speed.x * elapsed, viewport_size.x)
		var y := fposmod(star.y * viewport_size.y + speed.y * elapsed, viewport_size.y)
		var twinkle := 0.5 + 0.5 * sin(elapsed * 2.0 + star.w)
		var point := Vector2(x, y)

		if star.z > 1.3 and twinkle > 0.78:
			draw_circle(point, star.z * 3.2, Color(0.56, 0.70, 1.0, 0.07))

		draw_circle(point, star.z, Color(0.88, 0.92, 1.0, 0.25 + twinkle * 0.65))


func _draw_meteors() -> void:
	for i in 3:
		var cycle := fposmod(elapsed + float(i) * 2.7, 8.0)
		if cycle > 1.0:
			continue

		var head := Vector2(
			fposmod(float(i) * 0.37 + 0.18 + cycle * 0.70, 1.0) * viewport_size.x,
			fposmod(float(i) * 0.23 + cycle * 0.52, 1.0) * viewport_size.y
		)
		var tail := head + Vector2(-23.0, -15.0)
		draw_line(tail, head, Color(0.74, 0.84, 1.0, 0.08), 3.0, true)
		draw_line(tail, head, Color(0.90, 0.94, 1.0, 0.48), 1.0, true)
		draw_circle(head, 1.2, Color(1.0, 1.0, 1.0, 0.75))


func _draw_logo() -> void:
	var center := Vector2(viewport_size.x * 0.86, viewport_size.y * 0.105)
	var cell_size := clampf(viewport_size.x * 0.025, 11.0, 15.0)

	for cell in [
		Vector2i(-1, 0),
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, -1)
	]:
		var rect := Rect2(
			center + Vector2(cell) * cell_size
				- Vector2.ONE * cell_size * 0.5,
			Vector2.ONE * cell_size
		)
		draw_rect(rect.grow(1.0), Color("#05070b"))
		draw_rect(rect.grow(-1.5), Color("#e9edf3"))


func _draw_ellipse(
	center: Vector2,
	radii: Vector2,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()
	for i in 65:
		var angle := TAU * float(i) / 64.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, width, true)


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_control)

	safe_area = Control.new()
	root_control.add_child(safe_area)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	safe_area.add_child(content)

	_add_header()
	_add_status()
	_add_cards()
	_add_back_button()
	_build_join_dialog()


func _add_header() -> void:
	var title := Label.new()
	title.text = "СЕТЕВАЯ ИГРА"
	title.custom_minimum_size.y = 34.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", WHITE)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ВЫБЕРИ, КАК НАЧАТЬ МАТЧ"
	subtitle.custom_minimum_size.y = 20.0
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", MUTED)
	content.add_child(subtitle)


func _add_status() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 48.0
	panel.add_theme_stylebox_override("panel", _make_status_style())
	content.add_child(panel)

	status_label = Label.new()
	status_label.text = "Подключись к серверу, чтобы начать."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", MUTED)
	panel.add_child(status_label)

	cancel_button = Button.new()
	cancel_button.text = "ОТМЕНИТЬ ПОИСК"
	cancel_button.custom_minimum_size.y = 34.0
	cancel_button.visible = false
	cancel_button.add_theme_font_size_override("font_size", 11)
	cancel_button.add_theme_color_override("font_color", WHITE)
	cancel_button.add_theme_stylebox_override("normal", _make_small_style(false))
	cancel_button.add_theme_stylebox_override("hover", _make_small_style(true))
	cancel_button.pressed.connect(_on_cancel_search)
	content.add_child(cancel_button)


func _add_cards() -> void:
	var random_card := _create_card(
		0,
		"НАЙТИ СЛУЧАЙНОГО ИГРОКА",
		"Найти соперника через интернет."
	)
	random_card.pressed.connect(_on_find_random)
	cards.append(random_card)
	content.add_child(random_card)

	var create_card := _create_card(
		1,
		"СОЗДАТЬ КОМНАТУ",
		"Создать комнату и получить код."
	)
	create_card.pressed.connect(_on_create_room)
	cards.append(create_card)
	content.add_child(create_card)

	var join_card := _create_card(
		2,
		"ПРИСОЕДИНИТЬСЯ К КОМНАТЕ",
		"Ввести код комнаты друга."
	)
	join_card.pressed.connect(_on_open_join)
	cards.append(join_card)
	content.add_child(join_card)


func _create_card(piece_index: int, heading: String, detail_text: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _make_card_style(0))
	button.add_theme_stylebox_override("hover", _make_card_style(1))
	button.add_theme_stylebox_override("pressed", _make_card_style(2))
	button.add_theme_stylebox_override("focus", _make_card_style(1))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_top = 7.0
	row.offset_right = -12.0
	row.offset_bottom = -7.0
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var icon := TetrominoIcon.new()
	icon.piece_index = piece_index
	icon.custom_minimum_size = Vector2(40.0, 40.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	var title := Label.new()
	title.text = heading
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", WHITE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var detail := Label.new()
	detail.text = detail_text
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", MUTED)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(detail)

	return button


func _add_back_button() -> void:
	var back := Button.new()
	back.text = "НАЗАД В МЕНЮ"
	back.custom_minimum_size.y = 38.0
	back.add_theme_font_size_override("font_size", 11)
	back.add_theme_color_override("font_color", MUTED)
	back.add_theme_stylebox_override("normal", _make_small_style(false))
	back.add_theme_stylebox_override("hover", _make_small_style(true))
	back.pressed.connect(func() -> void:
		_change_scene(start_scene_path)
	)
	content.add_child(back)


func _build_join_dialog() -> void:
	join_overlay = Control.new()
	join_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	join_overlay.visible = false
	root_control.add_child(join_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.75)
	join_overlay.add_child(shade)

	join_panel = PanelContainer.new()
	join_panel.add_theme_stylebox_override("panel", _make_dialog_style())
	join_overlay.add_child(join_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	join_panel.add_child(column)

	var label := Label.new()
	label.text = "КОД КОМНАТЫ"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", WHITE)
	column.add_child(label)

	room_code_input = LineEdit.new()
	room_code_input.placeholder_text = "Например: H57QAY"
	room_code_input.max_length = 12
	room_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(room_code_input)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	var cancel := Button.new()
	cancel.text = "ОТМЕНА"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size.y = 40.0
	cancel.add_theme_stylebox_override("normal", _make_small_style(false))
	cancel.add_theme_stylebox_override("hover", _make_small_style(true))
	cancel.pressed.connect(func() -> void:
		join_overlay.visible = false
	)
	row.add_child(cancel)

	var join := Button.new()
	join.text = "ВОЙТИ"
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.custom_minimum_size.y = 40.0
	join.add_theme_stylebox_override("normal", _make_small_style(false))
	join.add_theme_stylebox_override("hover", _make_small_style(true))
	join.pressed.connect(_on_join_room)
	row.add_child(join)


func _layout_interface() -> void:
	viewport_size = get_viewport_rect().size

	var side := minf(16.0, viewport_size.x * 0.04)
	var top := maxf(48.0, viewport_size.y * 0.05)
	var bottom := maxf(28.0, viewport_size.y * 0.035)
	var usable_width := maxf(220.0, viewport_size.x - side * 2.0)
	var usable_height := maxf(1.0, viewport_size.y - top - bottom)

	safe_area.position = Vector2(side, top)
	safe_area.size = Vector2(usable_width, usable_height)

	var card_height := clampf((usable_height - 205.0) / 3.0, 70.0, 102.0)

	for card in cards:
		card.custom_minimum_size = Vector2(usable_width, card_height)

	content.position = Vector2.ZERO
	content.size = Vector2(usable_width, usable_height)

	# Масштабируем только вертикальные интервалы, а не экран:
	# прокрутки нет, карточки остаются в доступной области.
	var total_minimum := content.get_combined_minimum_size().y
	if total_minimum > usable_height:
		var compression := usable_height / total_minimum
		for child in content.get_children():
			if child is Control:
				child.scale = Vector2.ONE * minf(1.0, compression)
	else:
		for child in content.get_children():
			if child is Control:
				child.scale = Vector2.ONE

	var dialog_width := minf(320.0, viewport_size.x - 32.0)
	join_panel.custom_minimum_size = Vector2(dialog_width, 0.0)
	join_panel.position = Vector2(
		(viewport_size.x - dialog_width) * 0.5,
		(viewport_size.y - 170.0) * 0.5
	)


func _make_status_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.90)
	style.border_color = Color(0.46, 0.55, 0.68, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _make_card_style(state: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(7)
	style.set_border_width_all(1)

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


func _make_small_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(5)
	style.set_border_width_all(1)
	style.bg_color = Color(0.08, 0.11, 0.16, 0.94) if highlighted else Color(0.035, 0.045, 0.065, 0.90)
	style.border_color = Color(0.72, 0.80, 0.92, 0.65)
	return style


func _make_dialog_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#080d15")
	style.border_color = Color(0.72, 0.80, 0.92, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _on_find_random() -> void:
	if network == null:
		_set_status("Не настроен Autoload Net.")
		return

	cancel_button.visible = true
	_set_status("Подключаемся и ищем соперника...")
	network.find_random_player()


func _on_cancel_search() -> void:
	if network != null:
		network.cancel_search()
	cancel_button.visible = false


func _on_create_room() -> void:
	if network == null:
		return

	cancel_button.visible = false
	_set_status("Создаём комнату...")
	network.create_room()


func _on_open_join() -> void:
	join_overlay.visible = true
	room_code_input.text = ""
	_layout_interface()
	room_code_input.grab_focus()


func _on_join_room() -> void:
	var code := room_code_input.text.strip_edges().to_upper()
	if code.is_empty():
		_set_status("Введи код комнаты.")
		return

	join_overlay.visible = false
	_set_status("Подключаемся к комнате %s..." % code)

	if network != null:
		network.join_room(code)


func _on_room_created(code: String) -> void:
	cancel_button.visible = false
	_set_status("Комната создана. Передай другу код: %s" % code)


func _on_network_status(text: String) -> void:
	_set_status(text)

	if text != "Ищем случайного соперника...":
		if text.begins_with("Соперник найден"):
			cancel_button.visible = false
		elif text.begins_with("Ошибка") or text.begins_with("Комната"):
			cancel_button.visible = false


func _on_match_started() -> void:
	_change_scene(game_scene_path)


func _set_status(text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = text


func _on_viewport_resized() -> void:
	_layout_interface()
	queue_redraw()


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("Сцена не найдена: %s" % path)
		return

	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Не удалось открыть сцену %s. Код: %s" % [path, error])
