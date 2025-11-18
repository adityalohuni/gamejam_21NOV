extends CharacterBody2D


@export var speed: float = 150.0
@export var jump_velocity: float = -220.0
@export var max_jumps: int = 2
@export var wall_jump_horizontal: float = 160.0
@export var wall_jump_vertical_multiplier: float = 0.9
@export var wall_slide_speed: float = 50.0
@export var wall_slide_gravity_scale: float = 0.35

var jumps_remaining: int

func _ready() -> void:
	jumps_remaining = max_jumps

func _physics_process(delta: float) -> void:
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
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
