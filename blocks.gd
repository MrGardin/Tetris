extends Node2D
## Block spawning, physics, commands, visuals, wind and meteor-event purge.

const CELL := 27.0
const TILE_BORDER := 1.35
const TILE_SIZE := CELL
const WIND_ACCELERATION := 50.0
const PURGE_FADE_TIME := 0.42
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
	var tile_angles: Array[float] = []
	var binding := false
	# Permanent visual marker only; never enables additional welding.
	var bound_visual := false
	var binding_resolving := false
	var levitation_pending := false
	var anchored := false
	var anchor_transform := Transform2D.IDENTITY
	var effect_clock := 0.0
	var cells: Array
	signal result(cmd: int, moved: bool)
	var controlled := true
	var x_limit := 270.0
	var commands: Array[int] = []
	var box := RectangleShape2D.new()
	var purge_marked := false
	var purge_committed := false
	var purge_clock := 0.0
	var purge_warning_duration := 2.2

	func command(action: int) -> void:
		if controlled and not purge_committed and not anchored:
			commands.append(action)
			sleeping = false

	func release_control() -> void:
		controlled = false
		commands.clear()

	func mark_for_purge(warning_duration: float) -> void:
		if anchored:
			return
		purge_marked = true
		purge_clock = 0.0
		purge_warning_duration = warning_duration
		queue_redraw()

	func fits_width(t: Transform2D) -> bool:
		var radius := TILE_SIZE * 0.5 * (absf(t.x.x) + absf(t.y.x))
		for cell: Vector2 in cells:
			if absf((t * (cell * CELL)).x) + radius > x_limit:
				return false
		return true

	func _process(delta: float) -> void:
		if purge_marked and not purge_committed:
			purge_clock += delta
		if binding or bound_visual or levitation_pending or anchored:
			effect_clock += delta
		if purge_marked or binding or bound_visual or levitation_pending or anchored:
			queue_redraw()

	func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
		if not controlled or purge_committed or commands.is_empty():
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
		var flash := purge_marked and not purge_committed and fposmod(purge_clock, 0.32) < 0.16
		for i in cells.size():
			var center: Vector2 = cells[i] * CELL
			var angle: float = tile_angles[i] if i < tile_angles.size() else 0.0
			draw_set_transform(center, angle)
			var outer := Rect2(-Vector2.ONE * half, Vector2.ONE * TILE_SIZE)
			draw_rect(outer, Color("#05070b"))
			draw_rect(outer.grow(-TILE_BORDER), Color("#ff273d") if flash else Color("#e9edf3"))
			if binding or bound_visual:
				# Two animated tendrils wrap each tile.
				for strand in 2:
					var line := PackedVector2Array()
					for point in 13:
						var x := -half + float(point) / 12.0 * CELL
						line.append(Vector2(x, sin(x * 0.24 + effect_clock * 2.2 + strand * PI) * 7.0))
					draw_polyline(line, Color("#69e0c0"), 1.6, true)
			if levitation_pending or anchored:
				var glow := Color(0.55, 0.72, 1.0, 0.65 + 0.25 * sin(effect_clock * 3.0))
				draw_rect(outer.grow(-3.0), glow, false, 1.4, true)
				draw_line(Vector2(-6, 5), Vector2(0, -4), glow, 1.5, true)
				draw_line(Vector2(0, -4), Vector2(6, 5), glow, 1.5, true)
			if purge_marked and not purge_committed:
				draw_arc(Vector2.ZERO, CELL * 0.37, 0.0, TAU, 24, Color(1.0, 0.16, 0.25, 0.9 if flash else 0.36), 1.2, true)
		draw_set_transform(Vector2.ZERO)

var active: Piece
var pieces: Array[Piece] = []
var purge_targets: Array[Piece] = []
var viewport_size := Vector2(540.0, 960.0)
var camera_y := 0.0
var contact_time := 0.0
var spawn_wait := 0.0
var spawning_enabled := true
var buffered := 99
var buffered_at := -1000
var platform_y := 300.0
var wind_direction := 0
# One accepted activation can wait for the next spawned figure.
var queued_hero_ability := ""

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
		if not is_instance_valid(body) or body.controlled or body.purge_committed:
			continue
		for i in body.cells.size():
			var angle: float = body.global_rotation + body.tile_angles[i]
			var extent := TILE_SIZE * 0.5 * (absf(cos(angle)) + absf(sin(angle)))
			var cell: Vector2 = body.cells[i]
			top = minf(top, body.to_global(cell * CELL).y - extent)
	return top

func begin_purge_warning(count: int, warning_duration: float) -> void:
	purge_targets.clear()
	var eligible: Array[Piece] = []
	for body in pieces:
		if is_instance_valid(body) and not body.purge_committed and not body.anchored:
			eligible.append(body)
	eligible.shuffle()
	var amount := mini(count, eligible.size())
	for i in amount:
		var body := eligible[i]
		body.mark_for_purge(warning_duration)
		purge_targets.append(body)

func execute_purge() -> void:
	for body in purge_targets:
		if not is_instance_valid(body) or body.anchored or body.purge_committed:
			continue
		body.purge_committed = true
		body.commands.clear()
		body.freeze = true
		body.set_collision_layer_value(1, false)
		body.set_collision_mask_value(1, false)
		for child in body.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
		if body == active:
			active = null
			spawn_wait = 0.0
		pieces.erase(body)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(body, "scale", body.scale * 0.18, PURGE_FADE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(body, "modulate", Color(1.0, 0.12, 0.22, 0.0), PURGE_FADE_TIME)
		tween.chain().tween_callback(body.queue_free)
	purge_targets.clear()

func _spawn() -> void:
	var shape_index := randi_range(0, SHAPES.size() - 1)
	var body := Piece.new()
	body.cells = SHAPES[shape_index].duplicate()
	for _cell in body.cells:
		body.tile_angles.append(0.0)
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
	if not queued_hero_ability.is_empty():
		_apply_hero_ability(body, queued_hero_ability)
		queued_hero_ability = ""
	if buffered != 99 and Time.get_ticks_msec() - buffered_at <= 380:
		body.command(buffered)
	buffered = 99
	contact_time = 0.0

func _on_piece_result(cmd: int, moved: bool) -> void:
	block_result.emit(cmd, moved)

# True means the activation was accepted, either now or for the next piece.
# Main starts its existing 30-second cooldown immediately on true.
func activate_hero_ability(hero: String) -> bool:
	if hero not in ["binder", "levitator"] or not can_activate_hero_ability():
		return false
	if is_instance_valid(active) and active.controlled and not active.purge_committed and not active.is_queued_for_deletion():
		_apply_hero_ability(active, hero)
	else:
		queued_hero_ability = hero
	return true

func _apply_hero_ability(body: Piece, hero: String) -> void:
	if hero == "binder":
		body.binding = true
	elif hero == "levitator":
		body.levitation_pending = true
	body.queue_redraw()

func can_activate_hero_ability() -> bool:
	if not queued_hero_ability.is_empty():
		return false
	if not is_instance_valid(active) or active.is_queued_for_deletion() or active.purge_committed or not active.controlled:
		return true
	return not active.binding and not active.levitation_pending and not active.anchored

func _anchor(body: Piece) -> void:
	body.anchor_transform = body.global_transform
	body.levitation_pending = false
	body.anchored = true
	body.release_control()
	body.gravity_scale = 0.0
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.constant_force = Vector2.ZERO
	body.constant_torque = 0.0
	body.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	body.freeze = true
	body.purge_marked = false
	purge_targets.erase(body)
	body.queue_redraw()

func _settle_active() -> void:
	var body := active
	body.release_control()
	if body.levitation_pending:
		_anchor(body)
	active = null
	contact_time = 0.0
	spawn_wait = 0.30

# Snapshot only the figures touching this coated piece at this instant.
# New contacts after this batch do not inherit the welding ability.
func _schedule_binding(body: Piece) -> void:
	if not body.binding or body.binding_resolving or body.controlled or body.purge_committed:
		return
	var contacts: Array[Piece] = []
	for other in body.get_colliding_bodies():
		if other is Piece and other != body and not other.controlled and not other.purge_committed and not other.is_queued_for_deletion():
			if not (body.anchored and other.anchored) and not contacts.has(other):
				contacts.append(other)
	if contacts.is_empty():
		return
	body.binding_resolving = true
	_resolve_binding.call_deferred(body, contacts)

func _resolve_binding(body: Piece, contacts: Array[Piece]) -> void:
	if not is_instance_valid(body) or body.is_queued_for_deletion() or body.purge_committed:
		return
	body.binding_resolving = false
	if not body.binding:
		return
	var keep: Piece = body
	var merged := false
	for other in contacts:
		if not is_instance_valid(other) or other.is_queued_for_deletion() or other == keep:
			continue
		var combined := _merge_binding_pair(keep, other)
		if is_instance_valid(combined):
			keep = combined
			merged = true
	if merged:
		keep.binding = false
		keep.binding_resolving = false
		keep.queue_redraw()

func _merge_binding_pair(first: Piece, second: Piece) -> Piece:
	if not is_instance_valid(first) or not is_instance_valid(second):
		return null
	if first == second or first.is_queued_for_deletion() or second.is_queued_for_deletion():
		return null
	if first.purge_committed or second.purge_committed or first.controlled or second.controlled:
		return null
	# Separate permanent levitation anchors are never moved or consumed.
	# One anchor can absorb an ordinary body while keeping its exact transform.
	if first.anchored and second.anchored:
		return null
	var keep := second if second.anchored else first
	var remove := first if keep == second else second
	var old_mass := keep.mass
	var sum_mass := old_mass + remove.mass
	var velocity := (keep.linear_velocity * old_mass + remove.linear_velocity * remove.mass) / sum_mass
	for i in remove.cells.size():
		var cell: Vector2 = remove.cells[i]
		var local_center := keep.to_local(remove.to_global(cell * CELL))
		var local_angle: float = remove.global_rotation + remove.tile_angles[i] - keep.global_rotation
		keep.cells.append(local_center / CELL)
		keep.tile_angles.append(local_angle)
		var collider := CollisionShape2D.new()
		collider.shape = keep.box
		collider.position = local_center
		collider.rotation = local_angle
		keep.add_child(collider)
	keep.mass = sum_mass
	# Welding does not transfer an unspent ability to the whole compound.
	keep.bound_visual = true
	keep.binding = false
	remove.binding = false
	if not keep.anchored:
		keep.linear_velocity = velocity
		keep.sleeping = false
		if remove.purge_marked:
			keep.purge_marked = true
			keep.purge_clock = maxf(keep.purge_clock, remove.purge_clock)
		if keep.purge_marked and not purge_targets.has(keep):
			purge_targets.append(keep)
	purge_targets.erase(remove)
	remove.purge_committed = true
	remove.collision_layer = 0
	remove.collision_mask = 0
	remove.freeze = true
	remove.hide()
	pieces.erase(remove)
	remove.queue_free()
	keep.queue_redraw()
	return keep

func _physics_process(dt: float) -> void:
	for i in range(pieces.size() - 1, -1, -1):
		var body := pieces[i]
		if not is_instance_valid(body):
			pieces.remove_at(i)
			continue
		if body.anchored:
			body.global_transform = body.anchor_transform
		if not body.anchored and body.position.y > platform_y + viewport_size.y * 0.35:
			if body == active:
				active = null
				spawn_wait = 0.35
			pieces.remove_at(i)
			purge_targets.erase(body)
			body.queue_free()
			continue
		if wind_direction != 0 and not body.anchored and not body.purge_committed:
			body.apply_central_force(Vector2(wind_direction * WIND_ACCELERATION * body.mass, 0.0))
	if is_instance_valid(active):
		contact_time = contact_time + dt if active.get_contact_count() > 0 else 0.0
		# Binding takes effect on contact with another settled piece.
		var binding_contact := false
		if active.binding:
			for other in active.get_colliding_bodies():
				if other is Piece and not other.controlled and not other.purge_committed:
					binding_contact = true
					break
		if contact_time >= 0.24 or binding_contact:
			_settle_active()
	elif spawning_enabled:
		spawn_wait -= dt
		if spawn_wait <= 0.0:
			_spawn()
	# Only an unspent coated figure can schedule one contact batch.
	for body in pieces:
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			_schedule_binding(body)
