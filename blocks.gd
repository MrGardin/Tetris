extends Node2D
## Owns block spawning, physics, commands, and block appearance.
## Tile centers use integer CELL coordinates; physics placement remains continuous.

const CELL := 27.0
const TILE_INSET := 1.35
const TILE_BORDER := TILE_INSET
const TILE_SIZE := CELL
# Tune this value to change how strongly the meteor-shower gust pushes blocks.
const WIND_ACCELERATION := 50.0 # world pixels/s^2

const SHAPES := [
	[Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)],
	[Vector2(-1, 0), Vector2.ZERO, Vector2.RIGHT, Vector2.UP],
	[Vector2(-1, 0), Vector2.ZERO, Vector2.RIGHT, Vector2(1, -1)],
	[Vector2(-1, -1), Vector2.LEFT, Vector2.ZERO, Vector2.RIGHT],
	[Vector2.LEFT, Vector2.ZERO, Vector2.UP, Vector2(1, -1)],
	[Vector2(-1, -1), Vector2.UP, Vector2.ZERO, Vector2.RIGHT]
]

class Piece extends RigidBody2D:
	var cells: Array
	signal result(cmd: int, moved: bool)
	var controlled := true
	var x_limit := 270.0
	var commands: Array[int] = []
	var box := RectangleShape2D.new()

	func command(action: int) -> void:
		if controlled:
			commands.append(action)
			sleeping = false

	func release_control() -> void:
		controlled = false
		commands.clear()

	func fits_width(t: Transform2D) -> bool:
		var radius := TILE_SIZE * 0.5 * (absf(t.x.x) + absf(t.y.x))
		for cell: Vector2 in cells:
			if absf((t * (cell * CELL)).x) + radius > x_limit:
				return false
		return true

	func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
		if not controlled or commands.is_empty():
			return
		var cmd: int = commands.pop_front()
		var t := state.transform
		if cmd != 0:
			var step := Vector2(cmd * CELL, 0.0)
			var next := t
			next.origin += step
			if not fits_width(next) or test_move(t, step):
				result.emit(cmd, false)
				return
			state.transform = next
			state.linear_velocity = Vector2(0.0, state.linear_velocity.y)
			result.emit(cmd, true)
		else:
			var next := Transform2D(t.get_rotation() + PI / 2.0, t.origin)
			if not fits_width(next):
				result.emit(cmd, false)
				return
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = box
			query.exclude = [get_rid()]
			query.collision_mask = collision_mask
			for cell: Vector2 in cells:
				query.transform = next.translated_local(cell * CELL)
				if not state.get_space_state().intersect_shape(query, 1).is_empty():
					result.emit(cmd, false)
					return
			state.transform = next
			state.angular_velocity = 0.0
			result.emit(cmd, true)

	func _draw() -> void:
		var half := CELL * 0.5
		for cell: Vector2 in cells:
			var center := cell * CELL
			var outer := Rect2(center - Vector2.ONE * half, Vector2.ONE * TILE_SIZE)
			var inner := outer.grow(-TILE_BORDER)
			draw_rect(outer, Color("#05070b"))
			draw_rect(inner, Color("#e9edf3"))

var active: Piece
var pieces: Array[Piece] = []
var viewport_size := Vector2(540.0, 960.0)
var camera_y := 0.0
var contact_time := 0.0
var spawn_wait := 0.0
var spawning_enabled := true
var buffered := 99
var buffered_at := -1000
var platform_y := 300.0
var wind_direction := 0

signal block_result(cmd: int, moved: bool)

func start_game(view_size: Vector2, initial_camera_y: float) -> void:
	viewport_size = view_size
	camera_y = initial_camera_y
	_spawn()

func set_viewport_size(value: Vector2) -> void:
	viewport_size = value
	if is_instance_valid(active):
		active.x_limit = viewport_size.x * 0.5

func set_camera_y(value: float) -> void:
	camera_y = value

func set_spawning_enabled(value: bool) -> void:
	spawning_enabled = value

func set_wind_direction(direction: int) -> void:
	wind_direction = clampi(direction, -1, 1)

func active_instance_id() -> int:
	return active.get_instance_id() if is_instance_valid(active) else 0

func command(action: int) -> void:
	if is_instance_valid(active):
		active.command(action)
	else:
		buffered = action
		buffered_at = Time.get_ticks_msec()

func top_y(fallback_y: float) -> float:
	var top := fallback_y
	for body in pieces:
		if body.controlled:
			continue
		var extent := TILE_SIZE * 0.5 * (absf(cos(body.rotation)) + absf(sin(body.rotation)))
		for cell: Vector2 in body.cells:
			top = minf(top, (body.transform * (cell * CELL)).y - extent)
	return top

func _spawn() -> void:
	var shape_index := randi_range(0, SHAPES.size() - 1)
	var body := Piece.new()
	body.cells = SHAPES[shape_index]
	body.result.connect(_on_piece_result)
	body.gravity_scale = 0.50
	body.linear_damp = 1.4
	body.angular_damp = 2.2
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.85
	body.physics_material_override.bounce = 0.0
	body.box.size = Vector2.ONE * TILE_SIZE
	for cell: Vector2 in body.cells:
		var collider := CollisionShape2D.new()
		collider.shape = body.box
		collider.position = cell * CELL
		body.add_child(collider)
	body.position = Vector2(0.0, camera_y - viewport_size.y * 0.34)
	body.x_limit = viewport_size.x * 0.5
	add_child(body)
	pieces.append(body)
	active = body
	if buffered != 99 and Time.get_ticks_msec() - buffered_at <= 380:
		body.command(buffered)
	buffered = 99
	contact_time = 0.0

func _on_piece_result(cmd: int, moved: bool) -> void:
	block_result.emit(cmd, moved)

func _physics_process(dt: float) -> void:
	for i in range(pieces.size() - 1, -1, -1):
		var body := pieces[i]
		if body.position.y > platform_y + viewport_size.y * 0.35:
			if body == active:
				active = null
				spawn_wait = 0.35
			pieces.remove_at(i)
			body.queue_free()

		# Constant low acceleration affects every existing block, active or settled.
		# Change WIND_ACCELERATION above to tune the strength of the gust.
		if wind_direction != 0 and is_instance_valid(body):
			body.apply_central_force(Vector2(wind_direction * WIND_ACCELERATION * body.mass, 0.0))

	if is_instance_valid(active):
		contact_time = contact_time + dt if active.get_contact_count() > 0 else 0.0
		if contact_time >= 0.24:
			active.release_control()
			active = null
			spawn_wait = 0.30
	elif spawning_enabled:
		spawn_wait -= dt
		if spawn_wait <= 0.0:
			_spawn()
