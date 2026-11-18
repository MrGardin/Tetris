extends Node2D
## Godot 4.5.x. Game-level input, camera, platform physics and victory countdown.
## Block spawning, physics, commands and block rendering are handled by child "Blocks".
## Scene decoration and countdown text are handled by child "Visual".

const PLATFORM_Y := 300.0
const TARGET_Y := PLATFORM_Y - 450.0
const SWIPE_FRACTION := 0.014
const WIN_COUNTDOWN := 3.0

const NO_POINTER := -2
const MOUSE_POINTER := -1

var camera := Camera2D.new()
var stand_shape := RectangleShape2D.new()
var screen_size := Vector2(540.0, 960.0)
var blocks: Node
var visual: Node
var sheet := preload("res://Sheet.gd").new()

var countdown := -1.0 # -1 means inactive; otherwise seconds remaining.
var won := false
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
	blocks.connect("block_result", _on_block_result)

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
	blocks.call("start_game", screen_size, camera.position.y)

func _resize() -> void:
	screen_size = get_viewport_rect().size
	stand_shape.size = Vector2(maxf(1.0, screen_size.x * 0.33), 4.5)
	if is_instance_valid(blocks):
		blocks.call("set_viewport_size", screen_size)
	_update_visual()
	sheet.queue_redraw()

func _update_visual() -> void:
	if is_instance_valid(visual):
		visual.call("set_scene_state", screen_size, camera.position, stand_shape.size.x, PLATFORM_Y, TARGET_Y)
		visual.call("set_countdown", countdown if countdown >= 0.0 and not won else -1.0)

func _input(e: InputEvent) -> void:
	if won:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.is_pressed():
			get_tree().call_deferred("reload_current_scene")
		return
	if e.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if e is InputEventScreenTouch:
		if e.canceled:
			if pointer == e.index:
				pointer = NO_POINTER
		elif e.pressed:
			_begin(e.index, e.position)
		else:
			_end(e.index, e.position)
	elif e is InputEventScreenDrag and pointer == e.index:
		drag_px += e.screen_relative
		_sample(drag_px)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_begin(MOUSE_POINTER, e.position)
		else:
			_end(MOUSE_POINTER, e.position)
	elif e is InputEventMouseMotion and pointer == MOUSE_POINTER:
		drag_px += e.screen_relative
		_sample(drag_px)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_A, KEY_LEFT: _send(-1)
			KEY_D, KEY_RIGHT: _send(1)
			KEY_W, KEY_UP: _send(0)

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
	owner_id = int(blocks.call("active_instance_id"))
	swipe_px = maxf(4.0, minf(get_window().size.x, get_window().size.y) * SWIPE_FRACTION)
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
	if owner_id != 0 and int(blocks.call("active_instance_id")) != owner_id:
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

func _send(cmd: int) -> void:
	if countdown < 0.0:
		blocks.call("command", cmd)

func _on_block_result(cmd: int, moved: bool) -> void:
	if moved:
		sheet.set_selected(cmd + 1)
		feedback_time = 0.22

func _physics_process(dt: float) -> void:
	if feedback_time > 0.0:
		feedback_time -= dt
		if feedback_time <= 0.0:
			sheet.set_selected(-1)

	var top: float = float(blocks.call("top_y", PLATFORM_Y))
	if won:
		blocks.call("set_spawning_enabled", false)
	elif top <= TARGET_Y:
		if countdown < 0.0:
			countdown = WIN_COUNTDOWN
		countdown = maxf(0.0, countdown - dt)
		blocks.call("set_spawning_enabled", false)
		if countdown <= 0.0:
			won = true
			sheet.set_finished(true)
	else:
		# If the tower drops back below the target, cancel the attempt and resume play.
		countdown = -1.0
		blocks.call("set_spawning_enabled", true)

	var target_camera_y := minf(camera.position.y, top + screen_size.y * 0.18)
	camera.position.y = lerpf(camera.position.y, target_camera_y, minf(1.0, dt * 3.0))
	blocks.call("set_camera_y", camera.position.y)
	_update_visual()
