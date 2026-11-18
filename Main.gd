extends Node2D
## Локальная физика, сетевые события и обмен снимками после матча.

const PLATFORM_Y := 300.0
const TARGET_Y := PLATFORM_Y - 450.0
const SWIPE_FRACTION := 0.014
const NO_POINTER := -2
const MOUSE_POINTER := -1
const PROGRESS_SEND_INTERVAL := 0.25
const PROOF_MAX_DIMENSION := 360
const HERO_SELECT_SCENE_PATH := "res://scenes/HeroSelect/HeroSelect.tscn"
const ABILITY_COOLDOWN := 30.0
const MAIN_MENU_SCENE_PATH := "res://scenes/Start/Start.tscn"

var camera := Camera2D.new()
var stand_shape := RectangleShape2D.new()
var screen_size := Vector2(540.0, 960.0)

var blocks: Node
var visual: Node
var events: Node
var network: LanClient
var sheet := preload("res://Sheet.gd").new()

var countdown := -1.0
var won := false
var match_finished := false
var multiplayer_active := false
var progress_send_timer := 0.0

var pointer := NO_POINTER
var start := Vector2.ZERO
var consumed := false
var owner_id := 0
var last_up := -10000
var drag_px := Vector2.ZERO
var swipe_px := 10.0
var feedback_time := 0.0

var hero_id := ""
var ability_remaining := 0.0

var result_layer: CanvasLayer
var result_root: Control
var result_panel: Panel
var result_label: Label
var proof_label: Label
var proof_texture: TextureRect
var menu_button: Button


func _ready() -> void:
	Input.use_accumulated_input = false
	var local_net := get_node_or_null("/root/Net") as LanClient
	if local_net == null or not local_net.hero_locked:
		set_physics_process(false)
		set_process_input(false)
		get_tree().call_deferred("change_scene_to_file", HERO_SELECT_SCENE_PATH)
		return
	hero_id = local_net.selected_hero

	blocks = get_node("Blocks")
	visual = get_node("Visual")
	events = get_node("Events")

	blocks.block_result.connect(_on_block_result)
	events.meteor_event_started.connect(_on_meteor_event_started)
	events.meteor_event_ended.connect(_on_meteor_event_ended)
	events.purge_event_started.connect(_on_purge_event_started)
	events.purge_event_execute.connect(_on_purge_event_execute)
	events.purge_event_ended.connect(_on_purge_event_ended)

	network = get_node_or_null("/root/Net") as LanClient
	multiplayer_active = network != null and network.match_ready

	if multiplayer_active:
		events.set_network_mode(true)
		network.opponent_progress_received.connect(_on_opponent_progress)
		network.match_result_received.connect(_on_match_result)
		network.opponent_left.connect(_on_opponent_left)
		network.network_event_started.connect(_on_network_event_started)
		network.network_event_execute.connect(_on_network_event_execute)
		network.network_event_ended.connect(_on_network_event_ended)
		network.opponent_proof_received.connect(_on_opponent_proof_received)

	_build_result_ui()

	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(sheet)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	add_child(camera)
	camera.make_current()

	var stand := StaticBody2D.new()
	stand.position.y = PLATFORM_Y + 2.25

	var collision := CollisionShape2D.new()
	collision.shape = stand_shape
	stand.add_child(collision)
	add_child(stand)

	_resize()
	get_viewport().size_changed.connect(_resize)
	blocks.start_game(screen_size, camera.position.y)


func _resize() -> void:
	screen_size = get_viewport_rect().size
	stand_shape.size = Vector2(maxf(1.0, screen_size.x * 0.33), 4.5)

	if is_instance_valid(blocks):
		blocks.set_viewport_size(screen_size)

	_layout_result_ui()
	_update_visual()
	sheet.queue_redraw()


func _update_visual() -> void:
	if not is_instance_valid(visual):
		return

	visual.set_scene_state(
		screen_size,
		camera.position,
		stand_shape.size.x,
		PLATFORM_Y,
		TARGET_Y
	)
	visual.set_countdown(countdown if countdown >= 0.0 and not won else -1.0)


func _on_meteor_event_started(direction: int) -> void:
	blocks.set_wind_direction(direction)
	visual.set_meteor_event(true, direction)


func _on_meteor_event_ended() -> void:
	blocks.set_wind_direction(0)
	visual.set_meteor_event(false, 0)


func _on_purge_event_started(warning_duration: float) -> void:
	blocks.begin_purge_warning(1, warning_duration)
	visual.set_purge_event(true)


func _on_purge_event_execute() -> void:
	blocks.execute_purge()


func _on_purge_event_ended() -> void:
	visual.set_purge_event(false)


func _on_network_event_started(
	event_name: String,
	direction: int,
	warning_duration: float
) -> void:
	events.begin_network_event(event_name, direction, warning_duration)


func _on_network_event_execute() -> void:
	events.execute_network_event()


func _on_network_event_ended() -> void:
	events.end_network_event()


func _input(event: InputEvent) -> void:
	if match_finished:
		return

	if won:
		# В одиночном режиме после победы не перезапускаем игру
		# касанием экрана. Для возврата используется кнопка карточки.
		return

	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	if event is InputEventScreenTouch:
		if event.canceled:
			if pointer == event.index:
				pointer = NO_POINTER
		elif event.pressed:
			_begin(event.index, event.position)
		else:
			_end(event.index, event.position)

	elif event is InputEventScreenDrag and pointer == event.index:
		drag_px += event.screen_relative
		_sample(drag_px)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(MOUSE_POINTER, event.position)
		else:
			_end(MOUSE_POINTER, event.position)

	elif event is InputEventMouseMotion and pointer == MOUSE_POINTER:
		drag_px += event.screen_relative
		_sample(drag_px)

	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT:
				_send(-1)
			KEY_D, KEY_RIGHT:
				_send(1)
			KEY_W, KEY_UP:
				_send(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pointer = NO_POINTER
		last_up = -10000


func _begin(id: int, pos: Vector2) -> void:
	if pointer != NO_POINTER:
		return

	pointer = id
	start = pos
	drag_px = Vector2.ZERO
	owner_id = int(blocks.active_instance_id())
	swipe_px = maxf(
		4.0,
		minf(get_window().size.x, get_window().size.y) * SWIPE_FRACTION
	)

	if sheet.ability_hit(pos):
		consumed = true
		last_up = -10000
		_activate_ability()
		return

	var button: int = sheet.hit(pos)
	consumed = button >= 0

	if consumed:
		last_up = -10000
		_send(button - 1)


func _end(id: int, pos: Vector2) -> void:
	if pointer != id:
		return

	var transform := get_viewport().get_screen_transform()
	_sample((transform * pos) - (transform * start))
	pointer = NO_POINTER


func _sample(delta: Vector2) -> void:
	if consumed:
		return

	if owner_id != 0 and int(blocks.active_instance_id()) != owner_id:
		return

	if absf(delta.x) >= swipe_px and absf(delta.x) >= absf(delta.y) * 0.76:
		consumed = true
		last_up = -10000
		_send(1 if delta.x > 0.0 else -1)

	elif -delta.y >= swipe_px * 1.5 and -delta.y > absf(delta.x) * 1.55:
		consumed = true
		var now := Time.get_ticks_msec()

		if now - last_up <= 480:
			_send(0)
			last_up = -10000
		else:
			last_up = now


func _send(command: int) -> void:
	if countdown < 0.0 and not match_finished:
		blocks.command(command)


func _on_block_result(command: int, moved: bool) -> void:
	if moved:
		sheet.set_selected(command + 1)
		feedback_time = 0.22


func _physics_process(delta: float) -> void:
	if not match_finished and not won:
		ability_remaining = maxf(0.0, ability_remaining - delta)
	_update_ability_ui()
	if feedback_time > 0.0:
		feedback_time -= delta
		if feedback_time <= 0.0:
			sheet.set_selected(-1)

	if match_finished:
		return

	var top: float = float(blocks.top_y(PLATFORM_Y))

	if won:
		blocks.set_spawning_enabled(false)

	elif top <= TARGET_Y:
		if countdown < 0.0:
			countdown = 5.0

		countdown = maxf(0.0, countdown - delta)
		blocks.set_spawning_enabled(false)

		if countdown <= 0.0:
			won = true
			blocks.set_spawning_enabled(false)
			events.stop_events()

			if multiplayer_active and network != null:
				network.send_goal_reached()
			else:
				match_finished = true
				proof_label.text = "Одиночная игра"
				_show_result_panel("ПОБЕДА")

	else:
		countdown = -1.0
		blocks.set_spawning_enabled(true)

	var target_camera_y := minf(
		camera.position.y,
		top + screen_size.y * 0.18
	)
	camera.position.y = lerpf(
		camera.position.y,
		target_camera_y,
		minf(1.0, delta * 3.0)
	)

	blocks.set_camera_y(camera.position.y)
	_update_network_progress(top, delta)
	_update_visual()


func _update_network_progress(top: float, delta: float) -> void:
	if not multiplayer_active or network == null or won:
		return

	progress_send_timer -= delta
	if progress_send_timer > 0.0:
		return

	progress_send_timer = PROGRESS_SEND_INTERVAL

	var total_height: float = PLATFORM_Y - TARGET_Y
	var progress: float = clampf(
		(PLATFORM_Y - top) / total_height,
		0.0,
		1.0
	)
	network.send_progress(progress)


func _on_opponent_progress(value: float) -> void:
	if is_instance_valid(visual):
		visual.set_opponent_progress(value)


func _on_match_result(result: String, message: String) -> void:
	if match_finished:
		return

	match_finished = true
	blocks.set_spawning_enabled(false)
	events.stop_events()

	if result == "win":
		won = true

	# Результат показываем в карточке, не в центре игрового поля.
	if result == "loss":
		won = false

	# Дожидаемся отрисовки финального игрового кадра перед снимком.
	visual.set_countdown(-1.0)
	await RenderingServer.frame_post_draw
	_send_local_proof()
	_show_result_panel(message)


func _on_opponent_left() -> void:
	if match_finished:
		return

	match_finished = true
	blocks.set_spawning_enabled(false)
	events.stop_events()
	proof_label.text = "Матч прерван"
	_show_result_panel("СОПЕРНИК ОТКЛЮЧИЛСЯ")


func _send_local_proof() -> void:
	if network == null or not multiplayer_active:
		return

	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		proof_label.text = "Не удалось снять экран."
		return

	var largest_side: int = maxi(image.get_width(), image.get_height())

	if largest_side > PROOF_MAX_DIMENSION:
		var scale_factor: float = (
			float(PROOF_MAX_DIMENSION) / float(largest_side)
		)
		var new_width: int = maxi(
			1,
			int(round(float(image.get_width()) * scale_factor))
		)
		var new_height: int = maxi(
			1,
			int(round(float(image.get_height()) * scale_factor))
		)
		image.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)

	image.convert(Image.FORMAT_RGB8)
	var jpg_data: PackedByteArray = image.save_jpg_to_buffer(0.48)

	if jpg_data.is_empty():
		proof_label.text = "Не удалось сжать снимок."
		return

	network.send_tower_proof(Marshalls.raw_to_base64(jpg_data))


func _on_opponent_proof_received(image_base64: String) -> void:
	if image_base64.is_empty():
		proof_label.text = "Соперник не прислал снимок."
		return

	var jpg_data: PackedByteArray = Marshalls.base64_to_raw(image_base64)
	var image := Image.new()
	var error: Error = image.load_jpg_from_buffer(jpg_data)

	if error != OK:
		proof_label.text = "Снимок соперника повреждён."
		return

	proof_texture.texture = ImageTexture.create_from_image(image)
	proof_label.text = "Снимок башни соперника"


func _build_result_ui() -> void:
	result_layer = CanvasLayer.new()
	result_layer.layer = 20
	add_child(result_layer)

	result_root = Control.new()
	result_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_root.visible = false
	result_layer.add_child(result_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	result_root.add_child(shade)

	# Обычный Panel: его размер задаём вручную,
	# поэтому он заканчивается сразу после кнопки.
	result_panel = Panel.new()
	result_panel.add_theme_stylebox_override(
		"panel",
		_make_result_panel_style()
	)
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	result_root.add_child(result_panel)

	result_label = Label.new()
	result_label.text = "МАТЧ ЗАВЕРШЁН"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.add_theme_color_override("font_color", Color("#f0f3f8"))
	result_panel.add_child(result_label)

	proof_label = Label.new()
	proof_label.text = "Ожидаем снимок соперника..."
	proof_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proof_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	proof_label.add_theme_font_size_override("font_size", 11)
	proof_label.add_theme_color_override("font_color", Color("#a6b0c0"))
	result_panel.add_child(proof_label)

	proof_texture = TextureRect.new()
	proof_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	proof_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	proof_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.add_child(proof_texture)

	menu_button = Button.new()
	menu_button.text = "ГЛАВНОЕ МЕНЮ"
	menu_button.focus_mode = Control.FOCUS_ALL
	menu_button.add_theme_font_size_override("font_size", 13)
	menu_button.add_theme_color_override("font_color", Color("#f0f3f8"))
	menu_button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	menu_button.add_theme_color_override("font_pressed_color", Color("#dce5f5"))
	menu_button.add_theme_stylebox_override(
		"normal",
		_make_menu_button_style(0)
	)
	menu_button.add_theme_stylebox_override(
		"hover",
		_make_menu_button_style(1)
	)
	menu_button.add_theme_stylebox_override(
		"pressed",
		_make_menu_button_style(2)
	)
	menu_button.add_theme_stylebox_override(
		"focus",
		_make_menu_button_style(1)
	)
	menu_button.pressed.connect(_on_main_menu_pressed)
	result_panel.add_child(menu_button)

	_layout_result_ui()


func _make_result_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#080d15")
	style.border_color = Color(0.72, 0.80, 0.92, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _make_menu_button_style(state: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	match state:
		0:
			style.bg_color = Color(0.035, 0.045, 0.065, 0.96)
			style.border_color = Color(0.58, 0.66, 0.79, 0.72)
		1:
			style.bg_color = Color(0.08, 0.11, 0.16, 0.99)
			style.border_color = Color(0.82, 0.88, 0.98, 0.95)
		2:
			style.bg_color = Color(0.10, 0.14, 0.20, 1.0)
			style.border_color = Color(0.74, 0.84, 1.0, 1.0)

	return style


func _layout_result_ui() -> void:
	if not is_instance_valid(result_panel):
		return

	var panel_width: float = minf(350.0, screen_size.x - 32.0)
	var side_padding := 16.0
	var top_padding := 16.0
	var title_height := 32.0
	var proof_label_height := 20.0
	var button_height := 44.0
	var gap := 8.0

	var fixed_height: float = (
		top_padding * 2.0
		+ title_height
		+ proof_label_height
		+ button_height
		+ gap * 3.0
	)
	var max_image_height: float = maxf(
		60.0,
		screen_size.y - fixed_height - 24.0
	)
	var image_height: float = clampf(
		screen_size.y * 0.38,
		minf(90.0, max_image_height),
		minf(360.0, max_image_height)
	)

	var panel_height: float = fixed_height + image_height
	var content_width: float = panel_width - side_padding * 2.0

	result_panel.position = Vector2(
		(screen_size.x - panel_width) * 0.5,
		(screen_size.y - panel_height) * 0.5
	)
	result_panel.size = Vector2(panel_width, panel_height)

	var y := top_padding

	result_label.position = Vector2(side_padding, y)
	result_label.size = Vector2(content_width, title_height)
	y += title_height + gap

	proof_label.position = Vector2(side_padding, y)
	proof_label.size = Vector2(content_width, proof_label_height)
	y += proof_label_height + gap

	proof_texture.position = Vector2(side_padding, y)
	proof_texture.size = Vector2(content_width, image_height)
	y += image_height + gap

	menu_button.position = Vector2(side_padding, y)
	menu_button.size = Vector2(content_width, button_height)


func _show_result_panel(message: String) -> void:
	pointer = NO_POINTER
	_update_ability_ui()
	result_label.text = message
	result_root.visible = true
	_layout_result_ui()


func _on_main_menu_pressed() -> void:
	if network != null:
		network.close_connection()

	if not ResourceLoader.exists(MAIN_MENU_SCENE_PATH):
		push_error(
			"Не найдена сцена главного меню: %s. Исправь MAIN_MENU_SCENE_PATH в Main.gd."
			% MAIN_MENU_SCENE_PATH
		)
		return

	var error: Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if error != OK:
		push_error(
			"Не удалось открыть главное меню. Код ошибки: %s" % error
		)


func _activate_ability() -> void:
	if match_finished or won or countdown >= 0.0 or ability_remaining > 0.0:
		return
	if bool(blocks.activate_hero_ability(hero_id)):
		ability_remaining = ABILITY_COOLDOWN
		_update_ability_ui()


func _update_ability_ui() -> void:
	if not is_instance_valid(blocks):
		return
	var available: bool = (
		not match_finished and not won and countdown < 0.0
		and ability_remaining <= 0.0
		and bool(blocks.can_activate_hero_ability())
	)
	sheet.set_ability_state(hero_id, ability_remaining, ABILITY_COOLDOWN, available)
