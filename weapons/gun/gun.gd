extends Area2D

@export var rotation_speed: float = 10.0
@export var fire_rate: float = 1.0

@export var shooting_point_path: NodePath
@export var bullet_scene: PackedScene = preload("res://projectiles/bullet/bullet.tscn")

# recoil and firing settings
@export var recoil_strength: float = 18.0
@export var recoil_rotation: float = 0.12
@export var recoil_return_speed: float = 8.0
@export var fire_cooldown_enabled: bool = true

var _fire_cooldown: float = 0.0
@onready var shooting_point: Node2D = get_node_or_null(shooting_point_path)
var _default_rotation: float = 0.0
var _shot_accumulator: float = 0.0
var _recoil_offset: Vector2 = Vector2.ZERO
var _recoil_rotation: float = 0.0
var _base_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	monitoring = true
	# fallback: if no path was set but a child named "ShootingPoint" exists, use it
	if shooting_point == null:
		# try direct child first, then search recursively for a node named "ShootingPoint"
		shooting_point = get_node_or_null("ShootingPoint")
		if shooting_point == null:
			# try a shallow child search first
			for c in get_children():
				if c is Node2D and c.name == "ShootingPoint":
					shooting_point = c
					break
			# recursive fallback
			if shooting_point == null:
				var found = null
				var stack := [self]
				while stack.size() > 0 and found == null:
					var node: Node = stack.pop_back()
					for ch in node.get_children():
						if ch is Node2D and ch.name == "ShootingPoint":
							found = ch
							break
						stack.append(ch)
				if found:
					shooting_point = found

	# store base local position so recoil can be applied as an offset
	_base_position = position
	# store the default/local rotation so the gun can return to it when no enemies
	_default_rotation = rotation
	# enable receiving input events so _input can catch action presses
	set_process_input(true)


func _physics_process(delta: float) -> void:
	var bodies: Array = get_overlapping_bodies()

	var target: Node2D = null
	if not bodies.is_empty():
		target = _find_closest_enemy(bodies)

	if target != null:
		var target_pos: Vector2 = target.global_position
		var desired_angle: float = (target_pos - global_position).angle()
		rotation = lerp_angle(rotation, desired_angle, clamp(rotation_speed * delta, 0.0, 1.0))
	else:
		# no enemies nearby: face the player's movement direction if available,
		# otherwise return gun to its default/local rotation
		var parent = get_parent()
		var movement_dir_angle_set := false
		var movement_dir_angle: float = 0.0
		if parent:
			if "velocity" in parent and parent.velocity is Vector2 and parent.velocity.length() > 0.01:
				movement_dir_angle = parent.velocity.angle()
				movement_dir_angle_set = true
			elif parent.has_method("get_velocity"):
				var vel = parent.get_velocity()
				if typeof(vel) == TYPE_VECTOR2 and vel.length() > 0.01:
					movement_dir_angle = vel.angle()
					movement_dir_angle_set = true

		if movement_dir_angle_set:
			rotation = lerp_angle(rotation, movement_dir_angle, clamp(rotation_speed * delta, 0.0, 1.0))
		else:
			rotation = lerp_angle(rotation, _default_rotation, clamp(rotation_speed * delta, 0.0, 1.0))

	# accumulate shots when holding the shoot action so very high fire rates are possible
	if bullet_scene and fire_rate > 0.0 and Input.is_action_pressed("shoot"):
		_shot_accumulator += fire_rate * delta

	# consume accumulated shots (may fire multiple times per physics step)
	var shots_this_step := 0
	# decrease the cooldown timer
	if _fire_cooldown > 0.0:
		_fire_cooldown = max(_fire_cooldown - delta, 0.0)

	while _shot_accumulator >= 1.0:
		# if cooldown enabled and still cooling, stop consuming shots this frame
		if fire_cooldown_enabled and _fire_cooldown > 0.0:
			break
		shots_this_step += 1
		if target != null:
			_shoot(target.global_position)
		else:
			_shoot()
		_shot_accumulator -= 1.0
	if shots_this_step > 0:
		pass

	# decay recoil over time and apply offset to local position and rotation
	_recoil_offset = _recoil_offset.lerp(Vector2.ZERO, clamp(recoil_return_speed * delta, 0.0, 1.0))
	_recoil_rotation = lerp(_recoil_rotation, 0.0, clamp(recoil_return_speed * delta, 0.0, 1.0))
	position = _base_position + _recoil_offset
	# apply rotation recoil additively so aiming lerp stays intact
	rotation += _recoil_rotation


func _input(event) -> void:
	# react to press events immediately (non-echo): add a shot to the accumulator
	if event.is_action_pressed("shoot") and not event.is_echo():
		_shot_accumulator += 1.0
		pass


# Note: firing is now driven by `_shot_accumulator` in `_physics_process`.


func _find_closest_enemy(bodies: Array) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for b in bodies:
		if not b is Node2D:
			continue
		var d := global_position.distance_to(b.global_position)
		if d < best_dist:
			best_dist = d
			best = b
	return best


func _shoot(target_pos = null) -> void:
	if not bullet_scene:
		return

	# debug: confirm the PackedScene resource is present

	var instance = bullet_scene.instantiate()
	if not instance:
		return

	# common reference to shooter (parent)
	var shooter = get_parent()

	# debug: instance created

	if instance is Node2D:
		var fire_pos: Vector2 = shooting_point.global_position if shooting_point else global_position
		instance.global_position = fire_pos
		if target_pos != null:
			instance.rotation = (target_pos - fire_pos).angle()
		else:
			# use the gun's global rotation as firing direction
			instance.rotation = global_rotation

		# debug: firing details

		# avoid immediately colliding with the shooter (player/gun)
		if instance is Area2D:
			# add collision exceptions with the gun node and its parent (usually the player)
			# add exception with the gun itself and shooter if the bullet supports collision exceptions
			if instance.has_method("add_collision_exception_with"):
				instance.add_collision_exception_with(self)
				if shooter:
					instance.add_collision_exception_with(shooter)
			else:
				pass

	# add instance to the scene
	get_parent().add_child(instance)

	# apply cooldown
	if fire_rate > 0.0 and fire_cooldown_enabled:
		_fire_cooldown = 1.0 / fire_rate

	# apply recoil: push the gun back along firing direction and add a short rotation
	var fire_direction = Vector2(cos(instance.rotation), sin(instance.rotation))
	_recoil_offset += -fire_direction * recoil_strength
	_recoil_rotation += -sign(fire_direction.x) * recoil_rotation

	# optional: notify parent to shake camera or apply a physics impulse if it supports it
	if shooter and shooter.has_method("shake_camera"):
		shooter.shake_camera(recoil_strength * 0.02)
	if shooter and shooter.has_method("apply_recoil_force"):
		# attempt to pass a recoil vector in local/player space
		if shooter.has_method("apply_recoil_force"):
			shooter.apply_recoil_force(-fire_direction * recoil_strength)

	# debug: confirm added to scene tree
