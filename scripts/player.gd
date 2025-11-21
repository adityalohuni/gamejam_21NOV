extends CharacterBody2D
@onready var character_body_2d: CharacterBody2D = $"."
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


@export var speed: float = 150.0
@export var jump_velocity: float = -220.0
@export var max_jumps: int = 2
@export var wall_jump_horizontal: float = 160.0
@export var wall_jump_vertical_multiplier: float = 0.9
@export var wall_slide_speed: float = 50.0
@export var wall_slide_gravity_scale: float = 0.35

# Health system (new)
signal health_changed(current: int, max: int)
signal died()

@export var max_health: int = 5
@export var invincibility_time: float = 0.5
@export var knockback_force: Vector2 = Vector2(150, -180)

# death by falling threshold (new)
@export var fall_death_y: float = 500.0
@export var use_viewport_fall_death: bool = false
@export var fall_death_margin: float = 200.0

var current_health: int
var invincible_timer: float = 0.0

var jumps_remaining: int

func _ready() -> void:
	jumps_remaining = max_jumps
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

func _physics_process(delta: float) -> void:
	# invincibility timer
	if invincible_timer > 0.0:
		invincible_timer = max(invincible_timer - delta, 0.0)

	# Gravity / wallslide handling
	var direction := Input.get_axis("ui_left", "ui_right")
	var on_wall := is_on_wall() and not is_on_floor() and velocity.y > 0

	if on_wall:
		# apply reduced gravity while sliding and cap fall speed
		velocity += get_gravity() * wall_slide_gravity_scale * delta
		velocity.y = min(velocity.y, wall_slide_speed)
	else:
		if not is_on_floor():
			velocity += get_gravity() * delta

	# Reset available jumps when touching the floor
	if is_on_floor():
		jumps_remaining = max_jumps

	# Handle jump input (supports ground jump, double jump, wall jump)
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = jump_velocity
			jumps_remaining -= 1
			# after wall-jumping, restore mid-air jumps (allow one less because we used a jump)
			jumps_remaining = max_jumps - 1
		elif jumps_remaining > 0 :
			# mid-air double jump
			velocity.y = jump_velocity
			jumps_remaining -= 1

	# Horizontal movement
	if direction:
		velocity.x = direction * speed
		
		animated_sprite_2d.flip_h = true if (velocity.x < 0)  else false
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()

	# Die if player falls below the configured Y threshold (new)
	if use_viewport_fall_death:
		# Calculate bottom of visible area in world coordinates and add a margin
		var visible_rect := get_viewport().get_visible_rect()
		var bottom := visible_rect.position.y + visible_rect.size.y
		if global_position.y > bottom + fall_death_margin:
			current_health = 0
			emit_signal("health_changed", current_health, max_health)
			print_debug("Player fell: y=", global_position.y, " bottom=", bottom, " margin=", fall_death_margin)
			_die()
			return
	else:
		if global_position.y > fall_death_y:
			current_health = 0
			emit_signal("health_changed", current_health, max_health)
			print_debug("Player fell: y=", global_position.y, " threshold=", fall_death_y)
			_die()
			return

# Health-related public API (new)

func take_damage(amount: int = 1, from_position: Vector2 = Vector2.ZERO) -> void:
	# ignore damage while invincible
	if invincible_timer > 0.0:
		return

	current_health = max(current_health - amount, 0)
	invincible_timer = invincibility_time
	emit_signal("health_changed", current_health, max_health)

	# simple knockback away from damage source if provided
	if from_position != Vector2.ZERO:
		var dir = sign(global_position.x - from_position.x)
		velocity.x = dir * knockback_force.x
		velocity.y = knockback_force.y

	if current_health <= 0:
		_die()

func heal(amount: int = 1) -> void:
	current_health = min(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)

func _die() -> void:
	emit_signal("died")
	# Change to a dedicated Game Over scene so the game scene is unloaded.
	# Adjust the path below if your game_over scene is located elsewhere.
	# if Engine.is_editor_hint():
	# 	# Don't change scenes while editing in the editor.
	# 	return
	get_tree().change_scene_to_file("res://scene/game_over.tscn")
