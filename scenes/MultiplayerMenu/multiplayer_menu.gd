extends Node2D
## Сетевое меню Tetris:Windbound в стиле стартового экрана.
## Уведомления и код комнаты показываются в панели над карточками.

const SPACE := Color("#030509")
const WHITE := Color("#f0f3f8")
const MUTED := Color("#a6b0c0")
const RED := Color("#ff4055")
const ICON_LIGHT := Color("#e4ebf6")
const ICON_DARK := Color("#182130")

const STATUS_MESSAGE_DURATION := 3.0

@export_file("*.tscn")
var game_scene_path: String = "res://Main.tscn"

@export_file("*.tscn")
var start_scene_path: String = "res://scenes/Start/Start.tscn"


class TetrominoIcon extends Control:
	var piece_index: int = 0

	func _draw() -> void:
		var shapes: Array = [
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
		]
		var shape: Array = shapes[clampi(piece_index, 0, shapes.size() - 1)]
		var cell_size: float = minf(size.x / 3.4, size.y / 2.4)
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
var elapsed: float = 0.0
var stars: Array[Vector4] = []
var star_speeds: Array[Vector2] = []

var network: LanClient

var canvas_root: Control
var title_label: Label
var subtitle_label: Label
var status_panel: Panel
var status_label: Label
var cancel_button: Button
var back_button: Button
var cards: Array[Button] = []

var join_overlay: Control
var join_panel: Panel
var room_code_input: LineEdit
var join_title: Label
var cancel_join_button: Button
var submit_join_button: Button

var persistent_room_code: String = ""
var temporary_status: String = ""
var temporary_status_time: float = 0.0
var searching: bool = false


func _ready() -> void:
	var local_net := get_node_or_null("/root/Net") as LanClient
	if local_net == null or not local_net.hero_locked:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/HeroSelect/HeroSelect.tscn")
		return
	randomize()
	viewport_size = get_viewport_rect().size

	for i in 190:
		stars.append(Vector4(
			randf(),
			randf(),
			randf_range(0.7, 1.9),
			randf_range(0.0, TAU)
		))
		star_speeds.append(Vector2(
			randf_range(-5.0, 5.0),
			randf_range(3.0, 15.0)
		))

	network = get_node_or_null("/root/Net") as LanClient
	if network == null:
		push_error(
			"Не найден Autoload Net. Добавь LanClient.gd "
			+ "в Project Settings → Globals → Autoload с именем Net."
		)

	_build_interface()
	_layout_interface()
	_refresh_status_panel()

	if network != null:
		network.status_changed.connect(_on_network_status)
		network.room_created.connect(_on_room_created)
		network.match_started.connect(_on_match_started)

	get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta

	if temporary_status_time > 0.0:
		temporary_status_time = maxf(0.0, temporary_status_time - delta)
		if temporary_status_time <= 0.0:
			temporary_status = ""
			_refresh_status_panel()

	queue_redraw()


func _draw() -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_draw_space_background()
	_draw_planets()
	_draw_stars()
	_draw_shooting_stars()
	_draw_floating_tetrominoes()
	_draw_logo()


func _draw_space_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), SPACE)

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
	var center := Vector2(viewport_size.x * 0.83, viewport_size.y * 0.19)
	var radius := minf(viewport_size.x * 0.115, 62.0)

	_draw_ellipse(
		center,
		Vector2(radius * 1.9, radius * 0.48),
		Color(0.72, 0.78, 0.88, 0.16),
		1.0
	)
	_draw_ellipse(
		center,
		Vector2(radius * 1.55, radius * 0.36),
		Color(0.72, 0.78, 0.88, 0.10),
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
		var point := Vector2(x, y)
		var alpha := 0.22 + 0.72 * twinkle

		if star.z > 1.45 and twinkle > 0.74:
			draw_circle(
				point,
				star.z * 3.6,
				Color(0.56, 0.70, 1.0, 0.04 + twinkle * 0.06)
			)

		draw_circle(point, star.z, Color(0.88, 0.92, 1.0, alpha))

		if star.z > 1.65:
			draw_line(
				point - Vector2(3.0, 0.0),
				point + Vector2(3.0, 0.0),
				Color(0.88, 0.92, 1.0, alpha * 0.4),
				0.7,
				true
			)


func _draw_shooting_stars() -> void:
	for i in 4:
		var cycle := fposmod(elapsed + float(i) * 2.1, 9.0)
		if cycle > 0.85:
			continue

		var progress := cycle / 0.85
		var start_x := 0.12 + float(i) * 0.21
		var start_y := 0.06 + float(i % 2) * 0.26
		var head := Vector2(
			fposmod(start_x + progress * 0.65, 1.0) * viewport_size.x,
			fposmod(start_y + progress * 0.44, 1.0) * viewport_size.y
		)
		var tail := head + Vector2(-34.0, -20.0)

		draw_line(tail, head, Color(0.70, 0.81, 1.0, 0.09), 4.0, true)
		draw_line(tail, head, Color(0.90, 0.95, 1.0, 0.56), 1.2, true)
		draw_circle(head, 1.5, Color(1.0, 1.0, 1.0, 0.86))


func _draw_floating_tetrominoes() -> void:
	var cell_size := clampf(viewport_size.x * 0.045, 18.0, 25.0)
	var drift := sin(elapsed * 0.7) * 7.0

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.13, viewport_size.y * 0.48 + drift),
		cell_size,
		[
			Vector2i(-1, 0),
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(1, -1)
		],
		Color(0.78, 0.84, 0.94, 0.10)
	)

	_draw_ghost_piece(
		Vector2(viewport_size.x * 0.87, viewport_size.y * 0.68 - drift),
		cell_size,
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(0, 1),
			Vector2i(1, 1)
		],
		Color(0.92, 0.34, 0.42, 0.09)
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
	var center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.205)
	var cell_size := clampf(viewport_size.x * 0.075, 27.0, 38.0)

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
		var fill := Color("#e9edf3") if i != 3 else RED
		draw_rect(rect.grow(1.5), Color("#05070b"))
		draw_rect(rect.grow(-2.0), fill)

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
	var layer := CanvasLayer.new()
	add_child(layer)

	canvas_root = Control.new()
	canvas_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(canvas_root)

	title_label = Label.new()
	title_label.text = "СЕТЕВАЯ ИГРА"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", WHITE)
	canvas_root.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "ВЫБЕРИ, КАК НАЧАТЬ МАТЧ"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", MUTED)
	canvas_root.add_child(subtitle_label)

	_build_status()
	_build_cards()
	_build_back_button()
	_build_join_dialog()


func _build_status() -> void:
	status_panel = Panel.new()
	status_panel.add_theme_stylebox_override("panel", _make_status_style())
	canvas_root.add_child(status_panel)

	status_label = Label.new()
	status_label.text = "Подключись к серверу, чтобы начать."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", MUTED)
	status_panel.add_child(status_label)

	cancel_button = Button.new()
	cancel_button.text = "ОТМЕНА"
	cancel_button.visible = false
	cancel_button.add_theme_font_size_override("font_size", 10)
	cancel_button.add_theme_color_override("font_color", WHITE)
	cancel_button.add_theme_stylebox_override("normal", _make_small_style(false))
	cancel_button.add_theme_stylebox_override("hover", _make_small_style(true))
	cancel_button.add_theme_stylebox_override("pressed", _make_small_style(true))
	cancel_button.pressed.connect(_on_cancel_search)
	status_panel.add_child(cancel_button)


func _build_cards() -> void:
	var random_card := _create_card(
		0,
		"НАЙТИ СЛУЧАЙНОГО ИГРОКА",
		"Найти соперника через интернет."
	)
	random_card.pressed.connect(_on_find_random)
	cards.append(random_card)
	canvas_root.add_child(random_card)

	var create_card := _create_card(
		1,
		"СОЗДАТЬ КОМНАТУ",
		"Создать комнату и получить код."
	)
	create_card.pressed.connect(_on_create_room)
	cards.append(create_card)
	canvas_root.add_child(create_card)

	var join_card := _create_card(
		2,
		"ПРИСОЕДИНИТЬСЯ К КОМНАТЕ",
		"Ввести код комнаты друга."
	)
	join_card.pressed.connect(_on_open_join)
	cards.append(join_card)
	canvas_root.add_child(join_card)


func _create_card(
	piece_index: int,
	heading: String,
	detail_text: String
) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _make_card_style(0))
	button.add_theme_stylebox_override("hover", _make_card_style(1))
	button.add_theme_stylebox_override("pressed", _make_card_style(2))
	button.add_theme_stylebox_override("focus", _make_card_style(1))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_top = 8.0
	row.offset_right = -14.0
	row.offset_bottom = -8.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var icon := TetrominoIcon.new()
	icon.piece_index = piece_index
	icon.custom_minimum_size = Vector2(48.0, 48.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	var title := Label.new()
	title.text = heading
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 13)
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


func _build_back_button() -> void:
	back_button = Button.new()
	back_button.text = "НАЗАД К ГЕРОЯМ"
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.add_theme_font_size_override("font_size", 12)
	back_button.add_theme_color_override("font_color", WHITE)
	back_button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	back_button.add_theme_color_override("font_pressed_color", Color("#dce5f5"))
	back_button.add_theme_stylebox_override("normal", _make_small_style(false))
	back_button.add_theme_stylebox_override("hover", _make_small_style(true))
	back_button.add_theme_stylebox_override("pressed", _make_small_style(true))
	back_button.add_theme_stylebox_override("focus", _make_small_style(true))
	back_button.pressed.connect(func() -> void:
		_change_scene("res://scenes/HeroSelect/HeroSelect.tscn")
	)
	canvas_root.add_child(back_button)


func _build_join_dialog() -> void:
	join_overlay = Control.new()
	join_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	join_overlay.visible = false
	join_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_root.add_child(join_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	join_overlay.add_child(shade)

	join_panel = Panel.new()
	join_panel.add_theme_stylebox_override("panel", _make_dialog_style())
	join_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	join_overlay.add_child(join_panel)

	join_title = Label.new()
	join_title.text = "КОД КОМНАТЫ"
	join_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	join_title.add_theme_font_size_override("font_size", 17)
	join_title.add_theme_color_override("font_color", WHITE)
	join_panel.add_child(join_title)

	room_code_input = LineEdit.new()
	room_code_input.placeholder_text = "Например: H57QAY"
	room_code_input.max_length = 12
	room_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_code_input.add_theme_font_size_override("font_size", 18)
	join_panel.add_child(room_code_input)

	cancel_join_button = Button.new()
	cancel_join_button.text = "ОТМЕНА"
	cancel_join_button.add_theme_font_size_override("font_size", 12)
	cancel_join_button.add_theme_color_override("font_color", WHITE)
	cancel_join_button.add_theme_stylebox_override("normal", _make_small_style(false))
	cancel_join_button.add_theme_stylebox_override("hover", _make_small_style(true))
	cancel_join_button.pressed.connect(func() -> void:
		join_overlay.visible = false
	)
	join_panel.add_child(cancel_join_button)

	submit_join_button = Button.new()
	submit_join_button.text = "ВОЙТИ"
	submit_join_button.add_theme_font_size_override("font_size", 12)
	submit_join_button.add_theme_color_override("font_color", WHITE)
	submit_join_button.add_theme_stylebox_override("normal", _make_small_style(false))
	submit_join_button.add_theme_stylebox_override("hover", _make_small_style(true))
	submit_join_button.pressed.connect(_on_join_room)
	join_panel.add_child(submit_join_button)


func _layout_interface() -> void:
	viewport_size = get_viewport_rect().size

	var width: float = viewport_size.x
	var height: float = viewport_size.y
	var side_margin: float = minf(22.0, width * 0.05)
	var content_width: float = maxf(220.0, width - side_margin * 2.0)

	var safe_top: float = maxf(42.0, height * 0.045)
	var safe_bottom: float = maxf(28.0, height * 0.035)
	var logo_bottom: float = height * 0.33
	var content_top: float = maxf(safe_top, logo_bottom)
	var available_height: float = maxf(1.0, height - content_top - safe_bottom)

	var title_height: float = 34.0
	var subtitle_height: float = 20.0
	var status_height: float = 48.0
	var back_height: float = 42.0
	var gap: float = 9.0

	var fixed_height: float = (
		title_height
		+ subtitle_height
		+ status_height
		+ back_height
		+ gap * 5.0
	)

	var card_height: float = clampf(
		(available_height - fixed_height) / 3.0,
		58.0,
		104.0
	)

	var group_height: float = fixed_height + card_height * 3.0
	var group_top: float = content_top + maxf(
		0.0,
		(available_height - group_height) * 0.5
	)

	var y: float = group_top

	title_label.position = Vector2(side_margin, y)
	title_label.size = Vector2(content_width, title_height)
	y += title_height + 2.0

	subtitle_label.position = Vector2(side_margin, y)
	subtitle_label.size = Vector2(content_width, subtitle_height)
	y += subtitle_height + gap

	status_panel.position = Vector2(side_margin, y)
	status_panel.size = Vector2(content_width, status_height)
	y += status_height + gap

	for card in cards:
		card.position = Vector2(side_margin, y)
		card.size = Vector2(content_width, card_height)
		y += card_height + gap

	back_button.position = Vector2(side_margin, y)
	back_button.size = Vector2(content_width, back_height)

	_layout_status_contents(content_width, status_height)
	_layout_join_dialog()


func _layout_status_contents(panel_width: float, panel_height: float) -> void:
	if searching:
		var cancel_width: float = minf(96.0, panel_width * 0.30)
		var inner_left: float = 8.0
		var inner_right: float = 8.0
		var gap: float = 6.0

		status_label.position = Vector2(inner_left, 3.0)
		status_label.size = Vector2(
			panel_width - inner_left - inner_right - cancel_width - gap,
			panel_height - 6.0
		)

		cancel_button.position = Vector2(
			panel_width - inner_right - cancel_width,
			7.0
		)
		cancel_button.size = Vector2(cancel_width, panel_height - 14.0)
	else:
		status_label.position = Vector2(8.0, 3.0)
		status_label.size = Vector2(panel_width - 16.0, panel_height - 6.0)
		cancel_button.position = Vector2.ZERO
		cancel_button.size = Vector2.ZERO

	cancel_button.visible = searching


func _layout_join_dialog() -> void:
	if not is_instance_valid(join_panel):
		return

	var panel_width: float = minf(340.0, viewport_size.x - 36.0)
	var panel_height: float = 188.0
	var padding: float = 16.0
	var inside_width: float = panel_width - padding * 2.0

	join_panel.position = Vector2(
		(viewport_size.x - panel_width) * 0.5,
		(viewport_size.y - panel_height) * 0.5
	)
	join_panel.size = Vector2(panel_width, panel_height)

	join_title.position = Vector2(padding, 12.0)
	join_title.size = Vector2(inside_width, 28.0)

	room_code_input.position = Vector2(padding, 48.0)
	room_code_input.size = Vector2(inside_width, 42.0)

	var buttons_y: float = 106.0
	var button_gap: float = 8.0
	var button_width: float = (inside_width - button_gap) * 0.5

	cancel_join_button.position = Vector2(padding, buttons_y)
	cancel_join_button.size = Vector2(button_width, 42.0)

	submit_join_button.position = Vector2(
		padding + button_width + button_gap,
		buttons_y
	)
	submit_join_button.size = Vector2(button_width, 42.0)


func _make_status_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.90)
	style.border_color = Color(0.46, 0.55, 0.68, 0.52)
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
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0

	match state:
		0:
			style.bg_color = Color(0.035, 0.045, 0.065, 0.92)
			style.border_color = Color(0.58, 0.66, 0.79, 0.58)
		1:
			style.bg_color = Color(0.08, 0.11, 0.16, 0.97)
			style.border_color = Color(0.82, 0.88, 0.98, 0.90)
		2:
			style.bg_color = Color(0.10, 0.14, 0.20, 0.98)
			style.border_color = Color(0.74, 0.84, 1.0, 0.96)

	return style


func _make_small_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(5)
	style.set_border_width_all(1)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0

	if highlighted:
		style.bg_color = Color(0.10, 0.14, 0.20, 0.98)
		style.border_color = Color(0.82, 0.88, 0.98, 0.90)
	else:
		style.bg_color = Color(0.035, 0.045, 0.065, 0.92)
		style.border_color = Color(0.62, 0.70, 0.82, 0.68)

	return style


func _make_dialog_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#080d15")
	style.border_color = Color(0.72, 0.80, 0.92, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _refresh_status_panel() -> void:
	if not is_instance_valid(status_label):
		return

	if not temporary_status.is_empty() and temporary_status_time > 0.0:
		status_label.text = temporary_status
	elif not persistent_room_code.is_empty():
		status_label.text = "КОД КОМНАТЫ: %s" % persistent_room_code
	else:
		status_label.text = "Подключись к серверу, чтобы начать."

	_layout_status_contents(status_panel.size.x, status_panel.size.y)


func _show_temporary_status(text: String, duration: float = STATUS_MESSAGE_DURATION) -> void:
	temporary_status = text
	temporary_status_time = duration
	_refresh_status_panel()


func _on_find_random() -> void:
	if network == null:
		_show_temporary_status("Не настроен Autoload Net.")
		return

	searching = true
	_show_temporary_status("Подключаемся и ищем соперника...")
	_layout_interface()
	network.find_random_player()


func _on_cancel_search() -> void:
	if network != null:
		network.cancel_search()

	searching = false
	_show_temporary_status("Поиск отменён.")
	_layout_interface()


func _on_create_room() -> void:
	if network == null:
		_show_temporary_status("Не настроен Autoload Net.")
		return

	searching = false
	_show_temporary_status("Создаём комнату...")
	_layout_interface()
	network.create_room()


func _on_open_join() -> void:
	join_overlay.visible = true
	room_code_input.text = ""
	_layout_join_dialog()
	room_code_input.grab_focus()


func _on_join_room() -> void:
	var code: String = room_code_input.text.strip_edges().to_upper()

	if code.is_empty():
		_show_temporary_status("Введи код комнаты.")
		return

	join_overlay.visible = false
	searching = false
	_show_temporary_status("Подключаемся к комнате %s..." % code)
	_layout_interface()

	if network != null:
		network.join_room(code)


func _on_room_created(code: String) -> void:
	persistent_room_code = code
	searching = false
	temporary_status = ""
	temporary_status_time = 0.0
	_refresh_status_panel()
	_layout_interface()


func _on_network_status(text: String) -> void:
	if text.begins_with("Ищем случайного соперника"):
		searching = true
		_show_temporary_status(text)
		_layout_interface()
		return

	if text.begins_with("Комната создана") and not persistent_room_code.is_empty():
		# Код комнаты уже закреплён в панели.
		_refresh_status_panel()
		return

	if text.begins_with("Соперник найден"):
		searching = false
		_show_temporary_status(text)
		_layout_interface()
		return

	if text.begins_with("Поиск отменён"):
		searching = false
		_show_temporary_status(text)
		_layout_interface()
		return

	if text.begins_with("Подключено к серверу"):
		if persistent_room_code.is_empty():
			_show_temporary_status(text)
		return

	if text.begins_with("Подключаемся к серверу"):
		_show_temporary_status(text)
		return

	if text.begins_with("Ошибка") or text.begins_with("Не удалось"):
		searching = false
		_show_temporary_status(text)
		_layout_interface()
		return

	if text.begins_with("Соперник отключился"):
		searching = false
		_show_temporary_status(text)
		_layout_interface()
		return

	_show_temporary_status(text)


func _on_match_started() -> void:
	_change_scene(game_scene_path)


func _on_viewport_resized() -> void:
	_layout_interface()
	queue_redraw()


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
