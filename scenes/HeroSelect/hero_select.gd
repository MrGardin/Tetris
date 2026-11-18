extends Node2D
## Выбор одного локального героя перед поиском соперника.
## Весь интерфейс создаётся автоматически.

const SPACE := Color("#030509")
const WHITE := Color("#f0f3f8")
const MUTED := Color("#a6b0c0")
const RED := Color("#ff4055")
const BINDER := Color("#69e0c0")
const LEVITATOR := Color("#9bbcff")

const MENU_PATH := "res://scenes/MultiplayerMenu/MultiplayerMenu.tscn"
const START_PATH := "res://scenes/Start/Start.tscn"

const BINDER_DESCRIPTION := (
	"Сцепляет фигуру с блоками при касании. "
	+ "Соединение и зелёное сплетение сохраняются, "
	+ "но новые блоки уже не приклеиваются."
)

const LEVITATOR_DESCRIPTION := (
	"После обычной установки фигура навсегда замирает. "
	+ "Гравитация, ветер и удаление событиями "
	+ "на неё больше не действуют."
)


class HeroPortrait extends Control:
	var hero := "binder"
	var highlighted := false
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return

		var center := size * 0.5
		var unit := minf(size.x / 6.0, size.y / 4.0)

		var accent := (
			Color("#69e0c0")
			if hero == "binder"
			else Color("#9bbcff")
		)

		var glow := 0.13 if highlighted else 0.045

		draw_circle(
			center,
			unit * 1.85,
			Color(accent, glow)
		)

		var cells: Array[Vector2] = [
			Vector2(-1, 0),
			Vector2.ZERO,
			Vector2(1, 0),
			Vector2(0, -1)
		]

		for cell in cells:
			var rect := Rect2(
				center + cell * unit - Vector2.ONE * unit * 0.5,
				Vector2.ONE * unit
			)

			draw_rect(rect, Color("#05070b"))
			draw_rect(rect.grow(-1.8), Color("#e9edf3"))

		if hero == "binder":
			for strand in 2:
				var points := PackedVector2Array()

				for i in 49:
					var x := (
						(float(i) / 48.0 - 0.5)
						* unit
						* 3.5
					)

					var y := sin(
						x / unit * 2.7
						+ time * 1.5
						+ strand * PI
					) * unit * 0.52

					points.append(center + Vector2(x, y))

				draw_polyline(points, accent, 2.0, true)

		else:
			for ring in 2:
				var points := PackedVector2Array()

				for i in 65:
					var angle := TAU * float(i) / 64.0

					points.append(
						center + Vector2(
							cos(angle) * unit * (1.9 + ring * 0.2),
							sin(angle) * unit * 0.36
								+ unit * (0.8 + ring * 0.3)
						)
					)

				draw_polyline(
					points,
					Color(accent, 0.75 - ring * 0.25),
					1.3,
					true
				)

			for i in 3:
				var x := center.x + (i - 1) * unit * 0.6

				var y := (
					center.y
					- unit * 1.7
					- sin(time * 2.0 + i) * 3.0
				)

				draw_line(
					Vector2(x - 4.0, y + 5.0),
					Vector2(x, y),
					accent,
					1.5,
					true
				)

				draw_line(
					Vector2(x, y),
					Vector2(x + 4.0, y + 5.0),
					accent,
					1.5,
					true
				)


var viewport_size := Vector2(540.0, 960.0)
var elapsed := 0.0

var stars: Array[Vector4] = []
var star_speeds: Array[Vector2] = []

var logo_center := Vector2.ZERO
var logo_cell_size := 32.0

var network: LanClient

var root_control: Control
var layout_root: Control

var title: Label
var subtitle: Label

var hero_buttons: Array[Button] = []
var portraits: Array[HeroPortrait] = []
var hero_names: Array[Label] = []

var description_panel: Panel
var description_title: Label
var hero_description_label: Label
var cooldown_label: Label

var next_button: Button
var back_button: Button

var selected_hero := ""


func _ready() -> void:
	network = get_node_or_null("/root/Net") as LanClient

	if network != null:
		network.close_connection()
		network.begin_hero_selection()

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

	_build_interface()
	_layout_interface()

	get_viewport().size_changed.connect(_layout_interface)


func _process(delta: float) -> void:
	elapsed += delta
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
	draw_rect(
		Rect2(Vector2.ZERO, viewport_size),
		SPACE
	)

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
	var distant_center := Vector2(
		viewport_size.x * 0.83,
		viewport_size.y * 0.19
	)

	var distant_radius := minf(
		viewport_size.x * 0.115,
		62.0
	)

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

	draw_circle(
		distant_center,
		distant_radius,
		Color("#0b1018")
	)

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

	var red_center := Vector2(
		viewport_size.x * 0.12,
		viewport_size.y * 0.73
	)

	var pulse := 0.85 + 0.15 * sin(elapsed * 1.4)
	var red_radius := viewport_size.x * 0.043 * pulse

	_draw_ellipse(
		red_center,
		Vector2(red_radius * 2.2, red_radius * 0.65),
		Color(0.85, 0.12, 0.23, 0.24),
		1.0
	)

	draw_circle(
		red_center,
		red_radius,
		Color(0.15, 0.035, 0.055, 0.9)
	)

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
		var alpha := 0.22 + 0.72 * twinkle
		var point := Vector2(x, y)

		if star.z > 1.45 and twinkle > 0.74:
			draw_circle(
				point,
				star.z * 3.6,
				Color(0.56, 0.70, 1.0, 0.04 + twinkle * 0.06)
			)

		draw_circle(
			point,
			star.z,
			Color(0.88, 0.92, 1.0, alpha)
		)

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
		var cycle := fposmod(
			elapsed + float(i) * 2.1,
			9.0
		)

		if cycle > 0.85:
			continue

		var progress := cycle / 0.85
		var start_x := 0.12 + float(i) * 0.21
		var start_y := 0.06 + float(i % 2) * 0.26

		var head := Vector2(
			fposmod(start_x + progress * 0.65, 1.0)
				* viewport_size.x,
			fposmod(start_y + progress * 0.44, 1.0)
				* viewport_size.y
		)

		var tail := head + Vector2(-34.0, -20.0)

		draw_line(
			tail,
			head,
			Color(0.70, 0.81, 1.0, 0.09),
			4.0,
			true
		)

		draw_line(
			tail,
			head,
			Color(0.90, 0.95, 1.0, 0.56),
			1.2,
			true
		)

		draw_circle(
			head,
			1.5,
			Color(1.0, 1.0, 1.0, 0.86)
		)


func _draw_floating_tetrominoes() -> void:
	var cell_size := clampf(
		viewport_size.x * 0.045,
		18.0,
		25.0
	)

	var drift := sin(elapsed * 0.7) * 7.0

	_draw_ghost_piece(
		Vector2(
			viewport_size.x * 0.16,
			viewport_size.y * 0.43 + drift
		),
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
		Vector2(
			viewport_size.x * 0.84,
			viewport_size.y * 0.65 - drift
		),
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
			center + Vector2(cell) * cell_size
				- Vector2.ONE * cell_size * 0.5,
			Vector2.ONE * cell_size
		)

		draw_rect(rect, color, false, 1.0, true)


func _draw_logo() -> void:
	var center := logo_center
	var cell_size := logo_cell_size

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

		var fill := (
			Color("#e9edf3")
			if i != 3
			else RED
		)

		draw_rect(rect.grow(1.5), Color("#05070b"))
		draw_rect(rect.grow(-2.0), fill)

	for i in 3:
		var angle := elapsed * 0.65 + TAU * float(i) / 3.0

		var point := center + Vector2(
			cos(angle) * cell_size * 2.35,
			sin(angle) * cell_size * 0.66
		)

		draw_circle(
			point,
			1.8,
			Color(0.90, 0.94, 1.0, 0.75)
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


func _label(
	text: String,
	font_size: int,
	color: Color = WHITE
) -> Label:
	var label := Label.new()

	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label.add_theme_font_size_override(
		"font_size",
		font_size
	)

	label.add_theme_color_override(
		"font_color",
		color
	)

	return label


func _style(
	color: Color,
	selected: bool = false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = (
		Color(0.045, 0.065, 0.09, 0.96)
		if selected
		else Color(0.03, 0.04, 0.06, 0.88)
	)

	style.border_color = (
		color
		if selected
		else Color(0.77, 0.83, 0.92, 0.45)
	)

	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(5)

	return style


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()

	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 15)

	var normal := _style(WHITE)
	var hover := _style(WHITE, true)
	var pressed := _style(RED, true)

	if primary:
		normal.bg_color = Color("#e0e6f0")
		normal.border_color = WHITE

		hover.bg_color = Color.WHITE
		pressed.bg_color = Color("#cbd4e2")

	for state in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color"
	]:
		button.add_theme_color_override(
			state,
			Color("#080b11") if primary else WHITE
		)

	button.add_theme_color_override(
		"font_disabled_color",
		MUTED
	)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", _style(MUTED))

	return button


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	root_control = Control.new()
	layer.add_child(root_control)

	root_control.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	layout_root = Control.new()
	root_control.add_child(layout_root)

	title = _label("ВЫБОР ГЕРОЯ", 26)
	layout_root.add_child(title)

	subtitle = _label(
		"ОДИН ГЕРОЙ НА ВЕСЬ МАТЧ",
		11,
		MUTED
	)
	layout_root.add_child(subtitle)

	for i in 2:
		var hero := "binder" if i == 0 else "levitator"
		var button := _button("", false)

		layout_root.add_child(button)
		hero_buttons.append(button)

		var portrait := HeroPortrait.new()
		portrait.hero = hero
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

		button.add_child(portrait)
		portraits.append(portrait)

		var name_label := _label(
			"СЦЕПЩИК" if i == 0 else "ЛЕВИТАТОР",
			15
		)

		button.add_child(name_label)
		hero_names.append(name_label)

		button.pressed.connect(_select_hero.bind(hero))

	_build_description_card()

	next_button = _button("ДАЛЕЕ", true)
	next_button.disabled = true
	next_button.pressed.connect(_on_next_pressed)
	layout_root.add_child(next_button)

	back_button = _button("НАЗАД В МЕНЮ", false)
	back_button.pressed.connect(
		func() -> void:
			_change_scene(START_PATH)
	)
	layout_root.add_child(back_button)


func _build_description_card() -> void:
	description_panel = Panel.new()
	description_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	description_panel.add_theme_stylebox_override(
		"panel",
		_style(MUTED)
	)

	layout_root.add_child(description_panel)

	# Внутренняя область карточки с постоянными отступами.
	# Размеры и позиции текста дальше распределяет VBoxContainer.
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	description_panel.add_child(margin)

	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)

	margin.add_child(column)

	# Верхняя строка: название героя и способности.
	description_title = _label("ВЫБЕРИ ГЕРОЯ", 14)
	description_title.custom_minimum_size = Vector2(0.0, 28.0)
	description_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_title.size_flags_vertical = Control.SIZE_FILL
	description_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	column.add_child(description_title)

	# Центральная область: описание.
	hero_description_label = _label(
		"Нажми на героя, чтобы узнать его способность.",
		14,
		WHITE
	)

	hero_description_label.name = "HeroDescription"
	hero_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_description_label.add_theme_constant_override("line_spacing", 3)

	column.add_child(hero_description_label)

	# Нижняя строка: время восстановления.
	cooldown_label = _label(
		"СПОСОБНОСТЬ • ОТКАТ 30 СЕКУНД",
		10,
		MUTED
	)

	cooldown_label.custom_minimum_size = Vector2(0.0, 20.0)
	cooldown_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cooldown_label.size_flags_vertical = Control.SIZE_FILL

	column.add_child(cooldown_label)


func _layout_interface() -> void:
	viewport_size = get_viewport_rect().size

	if not is_instance_valid(layout_root):
		return

	var available := Vector2(
		maxf(1.0, viewport_size.x - 32.0),
		maxf(1.0, viewport_size.y - 48.0)
	)

	var group_size := Vector2(440.0, 730.0)

	var ui_scale := minf(
		1.0,
		minf(
			available.x / group_size.x,
			available.y / group_size.y
		)
	)

	layout_root.size = group_size
	layout_root.scale = Vector2.ONE * ui_scale

	layout_root.position = (
		viewport_size - group_size * ui_scale
	) * 0.5

	logo_center = (
		layout_root.position
		+ Vector2(220.0, 86.0) * ui_scale
	)

	logo_cell_size = 34.0 * ui_scale

	title.size = Vector2(440.0, 40.0)
	title.position = Vector2(0.0, 160.0)

	subtitle.size = Vector2(440.0, 24.0)
	subtitle.position = Vector2(0.0, 202.0)

	for i in 2:
		hero_buttons[i].size = Vector2(212.0, 162.0)
		hero_buttons[i].position = Vector2(
			float(i) * 228.0,
			246.0
		)

		portraits[i].size = Vector2(188.0, 112.0)
		portraits[i].position = Vector2(12.0, 8.0)

		hero_names[i].size = Vector2(196.0, 28.0)
		hero_names[i].position = Vector2(8.0, 124.0)

	description_panel.size = Vector2(440.0, 166.0)
	description_panel.position = Vector2(0.0, 424.0)

	# Внутренние подписи здесь не позиционируем.
	# Их размещает контейнер внутри description_panel.

	next_button.size = Vector2(440.0, 50.0)
	next_button.position = Vector2(0.0, 608.0)

	back_button.size = Vector2(440.0, 44.0)
	back_button.position = Vector2(0.0, 670.0)

	queue_redraw()


func _select_hero(hero: String) -> void:
	if hero not in ["binder", "levitator"]:
		return

	if network == null:
		hero_description_label.text = (
			"Не найден Autoload Net. "
			+ "Добавь scripts/LanClient.gd с именем Net."
		)
		return

	if not network.select_hero(hero):
		return

	selected_hero = hero

	var accent := (
		BINDER
		if hero == "binder"
		else LEVITATOR
	)

	for i in 2:
		var chosen := (
			(i == 0 and hero == "binder")
			or (i == 1 and hero == "levitator")
		)

		var hero_accent := BINDER if i == 0 else LEVITATOR

		hero_buttons[i].add_theme_stylebox_override(
			"normal",
			_style(hero_accent, chosen)
		)

		portraits[i].highlighted = chosen

	description_panel.add_theme_stylebox_override(
		"panel",
		_style(accent, true)
	)

	if hero == "binder":
		description_title.text = "СЦЕПЩИК • ЖИВОЕ СПЛЕТЕНИЕ"
		hero_description_label.text = BINDER_DESCRIPTION
	else:
		description_title.text = "ЛЕВИТАТОР • НЕПОДВИЖНАЯ ОПОРА"
		hero_description_label.text = LEVITATOR_DESCRIPTION

	description_title.add_theme_color_override(
		"font_color",
		accent
	)

	next_button.disabled = false


func _on_next_pressed() -> void:
	if network != null and network.confirm_hero():
		_change_scene(MENU_PATH)


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("Сцена не найдена: %s" % path)
		return

	var error: Error = get_tree().change_scene_to_file(path)

	if error != OK:
		push_error(
			"Не удалось открыть сцену %s. Код: %s"
			% [path, error]
		)
