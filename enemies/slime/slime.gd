extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var walk_speed: float = 60.0
@export var patrol_distance: float = 80.0
@export var idle_duration: float = 0.45

@export var gravity: float = 400.0

@export var max_health: int = 3

@export var death_fall_speed: float = 200.0
@export var death_fade_delay: float = 0.5
@export var death_fade_duration: float = 1.0

enum State { IDLE, WALK, DEAD }

var state: int = State.WALK
var base_position: Vector2 = Vector2.ZERO
var direction: int = 1
var health: int = 0

var idle_timer: float = 0.0
var death_timer: float = 0.0

func _ready() -> void:
	base_position = global_position
	health = max_health
	_play_if_exists("idle")

func _physics_process(delta: float) -> void:
	match state:
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
			return

	# gravity
	velocity.y += gravity * delta

	if state == State.IDLE:
		idle_timer -= delta
		velocity.x = 0
		if idle_timer <= 0.0:
			state = State.WALK
	elif state == State.WALK:
		velocity.x = direction * walk_speed

		# patrol bounds
		if direction > 0 and global_position.x >= base_position.x + patrol_distance:
			_start_idle_and_turn()
		elif direction < 0 and global_position.x <= base_position.x - patrol_distance:
			_start_idle_and_turn()

	move_and_slide()

	# animations and flipping
	if animated_sprite:
		if abs(velocity.x) > 1.0 and state != State.IDLE:
			_play_if_exists("running")
		else:
			_play_if_exists("idle")
		animated_sprite.flip_h = velocity.x > 0

func _start_idle_and_turn() -> void:
	state = State.IDLE
	idle_timer = idle_duration
	direction *= -1

func _play_if_exists(anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)

func take_damage(amount: int = 1, from_pos: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	if health <= 0:
		if animated_sprite:
			animated_sprite.stop()
		state = State.DEAD
		death_timer = 0.0
		velocity = Vector2(0, death_fall_speed)
		return

	# knockback
	var kb_dir := Vector2(0, -1)
	if from_pos != Vector2.ZERO:
		kb_dir = (global_position - from_pos).normalized()
	velocity = kb_dir * max(walk_speed * 1.5, 120)
	# briefly retreat in opposite horizontal direction
	direction = -sign(kb_dir.x) if kb_dir.x != 0 else direction
	state = State.IDLE
	idle_timer = idle_duration
