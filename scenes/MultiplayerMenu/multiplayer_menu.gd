extends Node2D
## Экран выбора сетевого режима Tetris:Windbound.
## Карточки пока только отображаются — логика нажатий не подключена.

const SPACE := Color("#030509")
const WHITE := Color("#f0f3f8")
const MUTED := Color("#a6b0c0")
const CARD_TEXT := Color("#dce5f5")
const CARD_ICON := Color("#e4ebf6")
const CARD_ICON_DARK := Color("#182130")

# Иконки тетромино: клетки заданы в координатах сетки.
const PIECE_SHAPES: Array = [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
]


class TetrominoIcon extends Control:
	var piece_index := 0

	func _draw() -> void:
		var shapes: Array = [
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
		]

		var shape: Array = shapes[clampi(piece_index, 0, shapes.size() - 1)]
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
		var shape_origin := (size - shape_size) * 0.5

		for cell: Vector2i in shape:
			var local_cell := Vector2(
				float(cell.x - min_cell.x),
				float(cell.y - min_cell.y)
			)
			var rect := Rect2(
				shape_origin + local_cell * cell_size,
				Vector2.ONE * (cell_size - 1.0)
			)

			draw_rect(rect, CARD_ICON_DARK)
			draw_rect(rect.grow(-1.4), CARD_ICON)


var viewport_size := Vector2(540.0, 960.0)
var elapsed := 0.0

# x, y — начальная позиция; z — размер; w — фаза мерцания.
var stars: Array[Vector4] = []
var star_speeds: Array[Vector2] = []

var scroll: ScrollContainer
var centering: CenterContainer
var content: VBoxContainer
var cards: Array[Button] = []


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
		star_speeds.append(Vector2(
			randf_range(-4.0, 4.0),
			randf_range(2.0, 11.0)
		))

	_build_interface()

	get_viewport().size_changed.connect(_on_viewport_resized)
	call_deferred("_update_safe_area")
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
	_draw_meteors()
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

		if star.z > 1.5:
			draw_line(
				point - Vector2(2.5, 0.0),
				point + Vector2(2.5, 0.0),
				Color(0.88, 0.92, 1.0, alpha * 0.35),
				0.7,
				true
			)


func _draw_meteors() -> void:
	for i in 3:
		var cycle := fposmod(elapsed + float(i) * 2.7, 8.0)
		if cycle > 1.0:
			continue

		var progress := cycle
		var x := fposmod(float(i) * 0.37 + 0.18 + progress * 0.70, 1.0)
		var y := fposmod(float(i) * 0.23 + progress * 0.52, 1.0)

		var head := Vector2(x * viewport_size.x, y * viewport_size.y)
		var tail := head + Vector2(-23.0, -15.0)

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
		Color(0.78, 0.84, 0.94, 0.07)
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

	for cell in cells:
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
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	root.add_child(scroll)

	centering = CenterContainer.new()
	centering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centering)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("separation", 12)
	centering.add_child(content)

	_add_header()

	cards.append(_create_card(
		0,
		"НАЙТИ СЛУЧАЙНОГО ИГРОКА",
		"Быстрый поиск соперника для сетевого матча."
	))

	cards.append(_create_card(
		1,
		"СОЗДАТЬ КОМНАТУ",
		"Создай комнату и пригласи в неё других игроков."
	))

	cards.append(_create_card(
		2,
		"ПРИСОЕДИНИТЬСЯ К КОМНАТЕ",
		"Подключись к комнате, используя её код."
	))

	for card in cards:
		content.add_child(card)


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

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	content.add_child(spacer)


func _create_card(
	piece_index: int,
	heading: String,
	description: String
) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0.0, 116.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP

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
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
			# Тёмный космический фон карточки оставлен.
			style.bg_color = Color(0.035, 0.045, 0.065, 0.92)
			style.border_color = Color(0.58, 0.66, 0.79, 0.55)
		1:
			style.bg_color = Color(0.08, 0.11, 0.16, 0.97)
			style.border_color = Color(0.82, 0.88, 0.98, 0.88)
		2:
			# Нажатие тоже без красных акцентов.
			style.bg_color = Color(0.10, 0.14, 0.20, 0.98)
			style.border_color = Color(0.74, 0.84, 1.0, 0.95)

	return style


func _update_safe_area() -> void:
	viewport_size = get_viewport_rect().size

	var safe_top := maxf(52.0, viewport_size.y * 0.055)
	var safe_bottom := maxf(32.0, viewport_size.y * 0.04)
	var side_margin := minf(20.0, viewport_size.x * 0.05)
	var available_width := maxf(240.0, viewport_size.x - side_margin * 2.0)
	var available_height := maxf(1.0, viewport_size.y - safe_top - safe_bottom)

	scroll.offset_left = side_margin
	scroll.offset_top = safe_top
	scroll.offset_right = -side_margin
	scroll.offset_bottom = -safe_bottom

	# Явно задаём ширину контента и карточек по ширине телефона.
	# Это не даёт контейнеру схлопнуть текст в узкую колонку.
	content.custom_minimum_size.x = available_width

	for card in cards:
		card.custom_minimum_size.x = available_width
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Центрируем содержимое в безопасной области.
	# Если оно выше экрана, ScrollContainer позволит прокрутить его.
	var content_height := content.get_combined_minimum_size().y
	centering.custom_minimum_size = Vector2(
		available_width,
		maxf(available_height, content_height)
	)

	scroll.queue_sort()
	centering.queue_sort()
	content.queue_sort()


func _on_viewport_resized() -> void:
	_update_safe_area()
	queue_redraw()
