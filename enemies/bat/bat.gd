extends CharacterBody2D

@onready var player: Node = get_node("/root/Game/Player")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var hover_speed: float = 50.0
@export var hover_amplitude: float = 20.0
@export var swoop_speed: float = 200.0
@export var time_before_attack: float = 2.0

@export var detection_radius: float = 200.0
@export var swoop_duration: float = 1.0

@export var hit_radius: float = 16.0
@export var swoop_acceleration: float = 600.0
@export var retreat_speed_multiplier: float = 0.45
@export var retreat_duration: float = 1.2
@export var attack_collision_mask: int = 0xFFFFFFFF

@export var death_fall_speed: float = 200.0
@export var death_fade_delay: float = 0.5
@export var death_fade_duration: float = 1.0

@export var max_health: int = 3

enum State { HOVER, SWOOP, RETREAT, DEAD }

var state: int = State.HOVER
var timer: float = 0.0
var base_position: Vector2

# Runtime state
var target_position: Vector2 = Vector2.ZERO
var health: int = 0
var current_swoop_speed: float = 0.0
var retreat_timer: float = 0.0

# Death/fade tracking
var death_timer: float = 0.0
var last_animation: String = ""

func _ready() -> void:
	base_position = global_position
	health = max_health
	_play_if_exists("flying")

func _physics_process(delta: float) -> void:
	timer += delta

	match state:
		State.HOVER:
			_ensure_flying()
			_hover_motion(delta)

			if _player_in_range(detection_radius):
				_start_swoop(_get_player_position())
				return

			if timer >= time_before_attack:
				timer = 0.0
				var targ = _get_player_position() if is_instance_valid(player) else base_position
				_start_swoop(targ)

		State.SWOOP:
			_ensure_flying()
			_swoop_motion(delta)
			if timer >= swoop_duration:
				_start_retreat()

		State.RETREAT:
			_ensure_flying()
			retreat_timer += delta
			velocity = velocity.move_toward(Vector2.ZERO, swoop_acceleration * delta * 0.12)
			move_and_slide()
			if retreat_timer >= retreat_duration:
				_to_hover()

		State.DEAD:
			death_timer += delta
			velocity.y = max(velocity.y, death_fall_speed)
			move_and_slide()
			if death_timer >= death_fade_delay:
				var t: float = (death_timer - death_fade_delay) / death_fade_duration
				var a: float = clamp(1.0 - t, 0.0, 1.0)
				if animated_sprite:
					var c := animated_sprite.modulate
					c.a = a
					animated_sprite.modulate = c
				if t >= 1.0:
					queue_free()

func _play_if_exists(anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func _ensure_flying() -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("flying") and animated_sprite.animation != "flying":
		animated_sprite.play("flying")

func _player_in_range(radius: float) -> bool:
	return is_instance_valid(player) and player.global_position.distance_to(global_position) <= radius

func _get_player_position() -> Vector2:
	return player.global_position if is_instance_valid(player) else base_position

func _start_swoop(targ: Vector2) -> void:
	timer = 0.0
	target_position = targ
	current_swoop_speed = swoop_speed * 0.45
	state = State.SWOOP

func _start_retreat() -> void:
	state = State.RETREAT
	timer = 0.0
	retreat_timer = 0.0
	var away := (global_position - target_position).normalized() if target_position != Vector2.ZERO else Vector2.UP
	velocity = (away + Vector2(0, -0.4)).normalized() * swoop_speed * retreat_speed_multiplier

func _to_hover() -> void:
	state = State.HOVER
	retreat_timer = 0.0
	base_position = global_position
	target_position = Vector2.ZERO
	current_swoop_speed = 0.0
	_play_if_exists("flying")

func _hover_motion(_delta: float) -> void:
	var x_offset := sin(timer * 3.0) * hover_amplitude
	global_position = base_position + Vector2(x_offset, 0)
	if animated_sprite:
		animated_sprite.flip_h = x_offset > 0

func _swoop_motion(delta: float) -> void:
	if target_position == Vector2.ZERO:
		if is_instance_valid(player):
			target_position = player.global_position
		else:
			return

	var to_target := target_position - global_position
	var dist := to_target.length()
	var dir := to_target.normalized() if dist > 0 else Vector2.ZERO

	current_swoop_speed = move_toward(current_swoop_speed, swoop_speed, swoop_acceleration * delta)

	var sway := Vector2(-dir.y, dir.x) * sin(timer * 10.0) * 0.35
	velocity = (dir + sway).normalized() * current_swoop_speed
	if animated_sprite:
		animated_sprite.flip_h = velocity.x > 0

	var projected_pos := global_position + velocity * delta

	var space := get_world_2d().direct_space_state
	var exclude := [self]

	var params := PhysicsRayQueryParameters2D.new()
	params.from = global_position
	params.to = projected_pos
	params.exclude = exclude
	params.collision_mask = attack_collision_mask
	params.collide_with_bodies = true
	params.collide_with_areas = false

	var result := space.intersect_ray(params)
	if result:
		var collider: Object = result.collider
		if collider == player or (collider and collider.has_method("take_damage")):
			global_position = result.position
			if collider and collider.has_method("take_damage"):
				collider.take_damage(1, global_position)
			_start_retreat()
			return

	move_and_slide()

	if dist <= hit_radius:
		if is_instance_valid(player) and player.has_method("take_damage"):
			player.take_damage(1, global_position)
		_start_retreat()

func take_damage(amount: int = 1, from_pos: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	_play_if_exists("hit")

	var kb_dir := Vector2(0, -1)
	if from_pos != Vector2.ZERO:
		kb_dir = (global_position - from_pos).normalized()
	velocity = kb_dir * max(swoop_speed, 150)

	state = State.RETREAT
	timer = 0.0
	retreat_timer = 0.0

	if health <= 0:
		if animated_sprite:
			last_animation = str(animated_sprite.animation) if animated_sprite.animation else ""
			animated_sprite.stop()
		state = State.DEAD
		death_timer = 0.0
		velocity = Vector2(0, death_fall_speed)
		return
