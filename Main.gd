extends Node2D
## Игровой цикл, локальная физика и сетевой прогресс соперника.

const PLATFORM_Y := 300.0
const TARGET_Y := PLATFORM_Y - 450.0
const SWIPE_FRACTION := 0.014
const NO_POINTER := -2
const MOUSE_POINTER := -1
const PROGRESS_SEND_INTERVAL := 0.25

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


func _ready() -> void:
	Input.use_accumulated_input = false

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
		network.opponent_progress_received.connect(_on_opponent_progress)
		network.match_result_received.connect(_on_match_result)
		network.opponent_left.connect(_on_opponent_left)

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


func _input(event: InputEvent) -> void:
	if match_finished:
		return

	if won:
		if not multiplayer_active:
			if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
				get_tree().call_deferred("reload_current_scene")
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

	var button := sheet.hit(pos)
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
	if feedback_time > 0.0:
		feedback_time -= delta
		if feedback_time <= 0.0:
			sheet.set_selected(-1)

	if match_finished:
		_update_visual()
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
			sheet.set_finished(true)
			events.stop_events()

			if multiplayer_active and network != null:
				network.send_goal_reached()
			else:
				visual.set_match_result("ПОБЕДА")

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
	_update_network_progress(top)
	_update_visual()


func _update_network_progress(top: float) -> void:
	if not multiplayer_active or network == null or won:
		return

	progress_send_timer -= get_physics_process_delta_time()
	if progress_send_timer > 0.0:
		return

	progress_send_timer = PROGRESS_SEND_INTERVAL

	var total_height := PLATFORM_Y - TARGET_Y
	var progress := clampf((PLATFORM_Y - top) / total_height, 0.0, 1.0)
	network.send_progress(progress)


func _on_opponent_progress(value: float) -> void:
	if is_instance_valid(visual):
		visual.set_opponent_progress(value)


func _on_match_result(result: String, message: String) -> void:
	match_finished = true
	blocks.set_spawning_enabled(false)
	events.stop_events()

	if result == "win":
		won = true
		sheet.set_finished(true)
	elif result == "loss":
		won = false

	visual.set_match_result(message)


func _on_opponent_left() -> void:
	if is_instance_valid(visual):
		visual.set_match_result("СОПЕРНИК ОТКЛЮЧИЛСЯ")
