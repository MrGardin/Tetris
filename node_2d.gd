extends Node2D

# Godot 4.x — attach to the root Node2D of an empty scene.
# Monochrome portrait physics tower game. No grid, row clearing, or text UI.

const CELL: float = 18.0
const PLATFORM_Y: float = 300.0
const PLATFORM_WIDTH_RATIO: float = 0.33
const PLATFORM_THICKNESS: float = 4.5
const TARGET_HEIGHT: float = 450.0

const PIECE_GRAVITY_SCALE: float = 0.32
const PIECE_LINEAR_DAMP: float = 1.4
const PIECE_ANGULAR_DAMP: float = 2.2

const BG_TOP := Color(0.025, 0.035, 0.105)
const BG_BOTTOM := Color(0.004, 0.006, 0.025)
const WHITE := Color(0.96, 0.97, 1.0)
const BLACK := Color(0.018, 0.021, 0.027)

# RigidBody rotation must be applied in the physics integration callback;
# changing a rigid body's rotation directly from _process can be overwritten.
class PieceBody extends RigidBody2D:
	var queued_turn: float = 0.0

	func request_quarter_turn() -> void:
		queued_turn += PI * 0.5

	func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
		if not is_zero_approx(queued_turn):
			var new_angle: float = state.transform.get_rotation() + queued_turn
			state.transform = Transform2D(new_angle, state.transform.origin)
			state.angular_velocity = 0.0
			queued_turn = 0.0


# Full-screen animated deep-space backdrop. Stars drift; occasional meteors cross the sky.
class MonochromeBackdrop extends Control:
	var rng := RandomNumberGenerator.new()
	var stars: Array = []
	var meteors: Array = []
	var elapsed: float = 0.0
	var next_meteor_in: float = 3.0

	func _ready() -> void:
		rng.randomize()
		for i in range(105):
			_add_star(rng.randf_range(0.0, size.y))
		next_meteor_in = rng.randf_range(2.0, 5.0)
		set_process(true)

	func _add_star(y_pos: float) -> void:
		stars.append({
			"pos": Vector2(rng.randf_range(0.0, maxf(1.0, size.x)), y_pos),
			"speed": rng.randf_range(5.0, 24.0),
			"radius": rng.randf_range(0.45, 1.45),
			"phase": rng.randf_range(0.0, TAU),
			"twinkle": rng.randf_range(1.2, 4.5),
			"tone": rng.randf_range(0.65, 1.0)
		})

	func _process(delta: float) -> void:
		elapsed += delta
		for i in range(stars.size()):
			var star: Dictionary = stars[i]
			var pos: Vector2 = star["pos"]
			pos.y += float(star["speed"]) * delta
			pos.x -= float(star["speed"]) * 0.12 * delta
			if pos.y > size.y + 2.0:
				pos.y = -2.0
				pos.x = rng.randf_range(0.0, maxf(1.0, size.x))
			if pos.x < -2.0:
				pos.x = size.x + 2.0
			star["pos"] = pos
			stars[i] = star

		for i in range(meteors.size() - 1, -1, -1):
			var meteor: Dictionary = meteors[i]
			var meteor_pos: Vector2 = meteor["pos"]
			var meteor_velocity: Vector2 = meteor["vel"]
			meteor["pos"] = meteor_pos + meteor_velocity * delta
			meteor["life"] = float(meteor["life"]) - delta
			meteors[i] = meteor
			if float(meteor["life"]) <= 0.0:
				meteors.remove_at(i)

		next_meteor_in -= delta
		if next_meteor_in <= 0.0:
			_spawn_meteor()
			next_meteor_in = rng.randf_range(3.0, 7.5)
		queue_redraw()

	func _spawn_meteor() -> void:
		var from_left: bool = rng.randf() < 0.5
		var start_x: float = rng.randf_range(0.0, size.x)
		var start_y: float = rng.randf_range(0.04, 0.42) * size.y
		var direction: Vector2 = Vector2(1.0, 0.72) if from_left else Vector2(-1.0, 0.72)
		var speed: float = rng.randf_range(430.0, 760.0)
		meteors.append({
			"pos": Vector2(start_x, start_y),
			"vel": direction.normalized() * speed,
			"life": rng.randf_range(0.65, 1.05),
			"max_life": 1.05,
			"length": rng.randf_range(48.0, 100.0)
		})

	func _draw() -> void:
		# Layered midnight-blue gradient.
		var bands: int = 56
		for i in range(bands):
			var t: float = float(i) / float(bands - 1)
			var y0: float = size.y * float(i) / float(bands)
			var y1: float = size.y * float(i + 1) / float(bands) + 1.0
			draw_rect(Rect2(0.0, y0, size.x, y1 - y0), BG_TOP.lerp(BG_BOTTOM, t))

		# Soft nebulae made from overlapping translucent light clouds.
		var nebula_a := Vector2(size.x * 0.18, size.y * 0.30 + sin(elapsed * 0.12) * 18.0)
		var nebula_b := Vector2(size.x * 0.82, size.y * 0.62 + cos(elapsed * 0.10) * 22.0)
		for i in range(9, 0, -1):
			var k: float = float(i) / 9.0
			draw_circle(nebula_a, size.x * (0.04 + k * 0.21), Color(0.18, 0.24, 0.78, 0.012 + (1.0 - k) * 0.009))
			draw_circle(nebula_b, size.x * (0.035 + k * 0.19), Color(0.38, 0.12, 0.62, 0.010 + (1.0 - k) * 0.008))
		var haze := Color(0.10, 0.28, 0.58, 0.035)
		draw_circle(Vector2(size.x * 0.52, size.y * 0.48), size.x * 0.12, haze)

		# Distant stars with slow drift and individual twinkle.
		for star in stars:
			var pos: Vector2 = star["pos"]
			var pulse: float = 0.60 + 0.40 * sin(elapsed * float(star["twinkle"]) + float(star["phase"]))
			var alpha: float = (0.18 + 0.70 * pulse) * float(star["tone"])
			var radius: float = float(star["radius"])
			draw_circle(pos, radius * 2.5, Color(0.45, 0.62, 1.0, alpha * 0.11))
			draw_circle(pos, radius, Color(0.80, 0.88, 1.0, alpha))
			if radius > 1.12:
				draw_line(pos - Vector2(3.2, 0), pos + Vector2(3.2, 0), Color(0.88, 0.93, 1.0, alpha * 0.42), 0.55, true)
				draw_line(pos - Vector2(0, 3.2), pos + Vector2(0, 3.2), Color(0.88, 0.93, 1.0, alpha * 0.42), 0.55, true)

		# Occasional shooting stars: luminous head with a fading, tapered tail.
		for meteor in meteors:
			var pos: Vector2 = meteor["pos"]
			var velocity: Vector2 = meteor["vel"]
			var life_ratio: float = clampf(float(meteor["life"]) / float(meteor["max_life"]), 0.0, 1.0)
			var tail: Vector2 = -velocity.normalized() * float(meteor["length"])
			var alpha: float = sin(life_ratio * PI) * 0.92
			draw_line(pos + tail, pos, Color(0.28, 0.48, 1.0, alpha * 0.16), 5.0, true)
			draw_line(pos + tail, pos, Color(0.72, 0.84, 1.0, alpha * 0.62), 1.35, true)
			draw_circle(pos, 2.0, Color(0.94, 0.98, 1.0, alpha))
			draw_circle(pos, 5.0, Color(0.48, 0.67, 1.0, alpha * 0.20))

		# Subtle astronomical guide arcs and edge framing; no labels or UI.
		var arc_center := Vector2(size.x * 0.50, size.y * 0.50)
		for i in range(3):
			var radius: float = size.x * (0.46 + float(i) * 0.055)
			draw_arc(arc_center, radius, -PI * 0.28, PI * 0.28, 36, Color(0.50, 0.64, 1.0, 0.025 - float(i) * 0.005), 0.7, true)
		var side_margin: float = size.x * 0.06
		draw_line(Vector2(side_margin, 0), Vector2(side_margin, size.y), Color(0.62, 0.72, 1.0, 0.055), 1.0, true)
		draw_line(Vector2(size.x - side_margin, 0), Vector2(size.x - side_margin, size.y), Color(0.62, 0.72, 1.0, 0.055), 1.0, true)


class PieceVisual extends Node2D:
	var cells: Array = []
	var cell_size: float = 18.0

	func _cut_corners(rect: Rect2, cut: float) -> PackedVector2Array:
		var p: Vector2 = rect.position
		var s: Vector2 = rect.size
		var c: float = minf(cut, minf(s.x, s.y) * 0.28)
		return PackedVector2Array([
			p + Vector2(c, 0), p + Vector2(s.x - c, 0),
			p + Vector2(s.x, c), p + Vector2(s.x, s.y - c),
			p + Vector2(s.x - c, s.y), p + Vector2(c, s.y),
			p + Vector2(0, s.y - c), p + Vector2(0, c)
		])

	func _closed(points: PackedVector2Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(point)
		if not points.is_empty():
			result.append(points[0])
		return result

	func _draw() -> void:
		for cell in cells:
			var center: Vector2 = Vector2(cell.x, cell.y) * cell_size
			var side: float = cell_size * 0.92
			var origin: Vector2 = center - Vector2.ONE * side * 0.5
			var outer := Rect2(origin, Vector2.ONE * side)
			var shadow := Rect2(origin + Vector2(1.0, 1.5), Vector2.ONE * side)

			# Deep-space alloy casing and layered cyan energy rim.
			draw_colored_polygon(_cut_corners(shadow, 3.0), Color(0.0, 0.0, 0.015, 0.8))
			draw_colored_polygon(_cut_corners(outer, 3.0), Color(0.035, 0.055, 0.105))
			draw_polyline(_closed(_cut_corners(outer, 3.0)), Color(0.18, 0.78, 1.0, 0.95), 0.95, true)

			var inner := Rect2(origin + Vector2(1.5, 1.5), Vector2.ONE * (side - 3.0))
			draw_colored_polygon(_cut_corners(inner, 2.2), Color(0.11, 0.17, 0.26))
			var face := Rect2(origin + Vector2(2.6, 2.6), Vector2.ONE * (side - 5.2))
			draw_colored_polygon(_cut_corners(face, 1.7), Color(0.72, 0.84, 0.96))
			var core := Rect2(origin + Vector2(3.8, 3.8), Vector2.ONE * (side - 7.6))
			draw_colored_polygon(_cut_corners(core, 1.2), Color(0.88, 0.94, 1.0))

			# Angular spacecraft panel engraving and luminous reactor diamond.
			draw_line(origin + Vector2(3.0, 3.4), origin + Vector2(side * 0.48, 3.4), Color(0.10, 0.88, 1.0, 0.90), 0.7, true)
			draw_line(origin + Vector2(side * 0.53, side - 3.0), origin + Vector2(side - 3.0, side - 3.0), Color(0.20, 0.48, 0.85, 0.75), 0.65, true)
			var d: float = side * 0.19
			var diamond := PackedVector2Array([
				center + Vector2(0, -d), center + Vector2(d, 0),
				center + Vector2(0, d), center + Vector2(-d, 0)
			])
			draw_colored_polygon(diamond, Color(0.07, 0.28, 0.43, 0.55))
			draw_polyline(_closed(diamond), Color(0.14, 0.94, 1.0, 0.95), 0.7, true)
			draw_circle(center, 1.15, Color(0.96, 1.0, 1.0, 0.98))

			# Tiny corner bolts and lower bevel create a 3D machined read.
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var bolt: Vector2 = center + Vector2(sx * side * 0.31, sy * side * 0.31)
					draw_circle(bolt, 0.62, Color(0.04, 0.20, 0.32, 0.9))
					draw_circle(bolt, 0.30, Color(0.60, 0.94, 1.0, 0.95))
			draw_line(origin + Vector2(3.0, side - 1.8), origin + Vector2(side - 3.0, side - 1.8), Color(0.01, 0.07, 0.16, 0.8), 0.75, true)


var view_size: Vector2 = Vector2(540.0, 960.0)
var platform_width: float = 356.0
var target_y: float = PLATFORM_Y - TARGET_HEIGHT

var camera: Camera2D
var active_piece: PieceBody
var pieces: Array = []

var spawn_delay: float = 0.0
var contact_time: float = 0.0
var line_time: float = 0.0
var game_won: bool = false

var last_up_swipe_time: float = -10.0
var touch_start: Vector2 = Vector2.ZERO
var mouse_start: Vector2 = Vector2.ZERO

var was_left_down: bool = false
var was_right_down: bool = false
var was_rotate_down: bool = false

var piece_shapes: Array = [
	[Vector2(-1.5, 0), Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(1.5, 0)], # I
	[Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)], # O
	[Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, -1)], # T
	[Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(1, -1)], # L
	[Vector2(-1, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0)], # J
	[Vector2(-1, 0), Vector2(0, 0), Vector2(0, -1), Vector2(1, -1)], # S
	[Vector2(-1, -1), Vector2(0, -1), Vector2(0, 0), Vector2(1, 0)] # Z
]

func _ready() -> void:
	view_size = get_viewport_rect().size
	platform_width = view_size.x * PLATFORM_WIDTH_RATIO
	target_y = PLATFORM_Y - TARGET_HEIGHT
	_create_backdrop()
	_create_camera()
	_create_platform()
	queue_redraw()
	_spawn_piece()

func _create_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var backdrop := MonochromeBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(backdrop)

func _create_camera() -> void:
	camera = Camera2D.new()
	camera.position = Vector2.ZERO
	camera.enabled = true
	add_child(camera)
	camera.make_current()

func _create_platform() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.name = "NarrowStand"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 1
	floor_body.position = Vector2(0.0, PLATFORM_Y + PLATFORM_THICKNESS * 0.5)

	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(platform_width, PLATFORM_THICKNESS)
	collision.shape = rect
	floor_body.add_child(collision)
	add_child(floor_body)

func _spawn_piece() -> void:
	if game_won:
		return

	var cells: Array = piece_shapes[randi() % piece_shapes.size()]
	var body := PieceBody.new()
	body.name = "FallingTetromino"
	body.gravity_scale = PIECE_GRAVITY_SCALE
	body.linear_damp = PIECE_LINEAR_DAMP
	body.angular_damp = PIECE_ANGULAR_DAMP
	body.contact_monitor = true
	body.max_contacts_reported = 12
	body.can_sleep = true
	body.set_meta("cells", cells)
	body.set_meta("settled", false)

	var material := PhysicsMaterial.new()
	material.friction = 0.85
	material.bounce = 0.0
	body.physics_material_override = material

	for cell in cells:
		var collision := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(CELL * 0.94, CELL * 0.94)
		collision.shape = box
		collision.position = Vector2(cell.x, cell.y) * CELL
		body.add_child(collision)

	var visual := PieceVisual.new()
	visual.cells = cells
	visual.cell_size = CELL
	body.add_child(visual)

	var spawn_y: float = camera.position.y - view_size.y * 0.34
	body.position = Vector2(0.0, spawn_y)
	add_child(body)
	pieces.append(body)
	active_piece = body
	contact_time = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
		else:
			_handle_swipe(event.position - touch_start)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_start = event.position
		else:
			_handle_swipe(event.position - mouse_start)

func _keyboard_key_down(physical_key: Key, logical_key: Key) -> bool:
	return Input.is_physical_key_pressed(physical_key) or Input.is_key_pressed(logical_key)

func _poll_keyboard() -> void:
	var left_down: bool = _keyboard_key_down(KEY_A, KEY_A) or _keyboard_key_down(KEY_LEFT, KEY_LEFT)
	var right_down: bool = _keyboard_key_down(KEY_D, KEY_D) or _keyboard_key_down(KEY_RIGHT, KEY_RIGHT)
	var rotate_down: bool = _keyboard_key_down(KEY_W, KEY_W) or _keyboard_key_down(KEY_UP, KEY_UP)

	if left_down and not was_left_down:
		_move_active(-1)
	if right_down and not was_right_down:
		_move_active(1)
	if rotate_down and not was_rotate_down:
		_rotate_active()

	was_left_down = left_down
	was_right_down = right_down
	was_rotate_down = rotate_down

func _handle_swipe(delta: Vector2) -> void:
	if game_won:
		return
	if absf(delta.x) > 35.0 and absf(delta.x) > absf(delta.y) * 1.15:
		_move_active(1 if delta.x > 0.0 else -1)
	elif delta.y < -35.0 and absf(delta.y) > absf(delta.x) * 1.15:
		var now: float = float(Time.get_ticks_msec()) / 1000.0
		if now - last_up_swipe_time <= 0.48:
			_rotate_active()
			last_up_swipe_time = -10.0
		else:
			last_up_swipe_time = now

func _move_active(direction: int) -> void:
	if game_won or not is_instance_valid(active_piece):
		return
	var step := Vector2(direction * CELL, 0.0)
	var limit: float = view_size.x * 0.5 - CELL * 2.5
	if absf(active_piece.position.x + step.x) > limit:
		return
	if not active_piece.test_move(active_piece.global_transform, step):
		active_piece.position.x += step.x
		active_piece.linear_velocity.x = 0.0

func _rotate_active() -> void:
	if game_won or not is_instance_valid(active_piece):
		return
	active_piece.request_quarter_turn()

func _process(delta: float) -> void:
	_poll_keyboard()

	if spawn_delay > 0.0:
		spawn_delay = maxf(0.0, spawn_delay - delta)
		if spawn_delay == 0.0 and not is_instance_valid(active_piece) and not game_won:
			_spawn_piece()

	for i in range(pieces.size() - 1, -1, -1):
		var body: PieceBody = pieces[i]
		if not is_instance_valid(body):
			pieces.remove_at(i)
			continue
		if body.global_position.y > PLATFORM_Y + view_size.y * 2.0:
			if body == active_piece:
				active_piece = null
				spawn_delay = 0.35
			body.queue_free()
			pieces.remove_at(i)

	if is_instance_valid(active_piece):
		if active_piece.get_contact_count() > 0:
			contact_time += delta
		else:
			contact_time = 0.0
		if contact_time >= 0.12:
			active_piece.set_meta("settled", true)
			active_piece = null
			spawn_delay = 0.30
			contact_time = 0.0

	_update_camera(delta)
	_update_win_state(delta)
	queue_redraw()

func _tower_top_y(settled_only: bool = true) -> float:
	var top: float = PLATFORM_Y
	for body in pieces:
		if not is_instance_valid(body):
			continue
		if settled_only and not bool(body.get_meta("settled", false)):
			continue
		var cells: Array = body.get_meta("cells", [])
		var angle: float = body.global_rotation
		var half_extent: float = CELL * 0.47 * (absf(cos(angle)) + absf(sin(angle)))
		for cell in cells:
			var local_center := Vector2(cell.x, cell.y) * CELL
			var center: Vector2 = body.global_transform * local_center
			top = minf(top, center.y - half_extent)
	return top

func _update_camera(delta: float) -> void:
	var top: float = _tower_top_y(true)
	var desired_y: float = top + view_size.y * 0.18
	if desired_y < camera.position.y:
		camera.position.y = lerpf(camera.position.y, desired_y, minf(1.0, delta * 3.0))

func _update_win_state(delta: float) -> void:
	if game_won:
		return
	if _tower_top_y(true) <= target_y:
		line_time += delta
	else:
		line_time = 0.0
	if line_time >= 3.0:
		game_won = true
func _draw() -> void:
	# Compact orbital platform: luminous cyan edge, dark body, blue underglow.
	var left: float = -platform_width * 0.5
	var slab := Rect2(Vector2(left, PLATFORM_Y), Vector2(platform_width, PLATFORM_THICKNESS))
	draw_rect(Rect2(Vector2(left - 5.0, PLATFORM_Y + 2.0), Vector2(platform_width + 10.0, PLATFORM_THICKNESS + 9.0)), Color(0.03, 0.35, 0.95, 0.12))
	draw_rect(Rect2(Vector2(left - 2.0, PLATFORM_Y + 3.0), Vector2(platform_width + 4.0, PLATFORM_THICKNESS + 5.0)), Color(0.0, 0.0, 0.02, 0.55))
	draw_rect(slab, Color(0.035, 0.075, 0.14))
	draw_rect(Rect2(Vector2(left + 1.0, PLATFORM_Y), Vector2(platform_width - 2.0, 1.2)), Color(0.22, 0.91, 1.0))
	draw_rect(Rect2(Vector2(left + 2.0, PLATFORM_Y + 2.0), Vector2(platform_width - 4.0, 0.8)), Color(0.22, 0.46, 0.76, 0.9))
	for i in range(5):
		var x: float = left + platform_width * (float(i) + 0.5) / 5.0
		draw_rect(Rect2(Vector2(x - 5.0, PLATFORM_Y + 3.2), Vector2(10.0, 1.2)), Color(0.12, 0.68, 1.0, 0.55))
	draw_line(Vector2(left + 5.0, PLATFORM_Y + PLATFORM_THICKNESS - 0.5), Vector2(-5.0, PLATFORM_Y + PLATFORM_THICKNESS - 0.5), Color(0.15, 0.86, 1.0, 0.52), 0.7, true)
	draw_line(Vector2(5.0, PLATFORM_Y + PLATFORM_THICKNESS - 0.5), Vector2(-left - 5.0, PLATFORM_Y + PLATFORM_THICKNESS - 0.5), Color(0.15, 0.86, 1.0, 0.52), 0.7, true)
	draw_circle(Vector2(left, PLATFORM_Y + PLATFORM_THICKNESS * 0.5), 2.0, Color(0.34, 0.96, 1.0))
	draw_circle(Vector2(-left, PLATFORM_Y + PLATFORM_THICKNESS * 0.5), 2.0, Color(0.34, 0.96, 1.0))

	# Final height marker is moved closer to the platform (half target height).
	var half_w: float = view_size.x * 0.5
	draw_line(Vector2(-half_w, target_y), Vector2(half_w, target_y), Color(0.22, 0.67, 1.0, 0.13), 7.0, true)
	draw_line(Vector2(-half_w, target_y), Vector2(half_w, target_y), Color(0.52, 0.91, 1.0, 0.88), 1.3, true)
	draw_line(Vector2(-half_w, target_y - 5.0), Vector2(half_w, target_y - 5.0), Color(0.37, 0.64, 1.0, 0.30), 0.8, true)
	for side in [-1.0, 1.0]:
		var x: float = side * (half_w - 13.0)
		draw_circle(Vector2(x, target_y), 3.0, Color(0.65, 0.95, 1.0, 0.92))
		draw_circle(Vector2(x, target_y), 6.0, Color(0.14, 0.62, 1.0, 0.22))
