extends CharacterBody2D

class_name Player

@export var SPEED: float = 300.0
@export var JUMP_VELOCITY: float = -400.0
@export var max_jumps: int = 1

var jump_count: int = 0

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta
    else:
        jump_count = 0

    if Input.is_action_just_pressed("ui_accept") and jump_count < max_jumps:
        velocity.y = JUMP_VELOCITY
        jump_count += 1

    var direction := Input.get_axis("ui_left", "ui_right")
    if direction:
        velocity.x = direction * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)

    move_and_slide()
