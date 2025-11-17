extends AnimatableBody2D

class_name ExtraJumpPowerup

@export var extra_jumps: int = 1

func _ready():
    connect("body_entered", _on_body_entered)

func _on_body_entered(body):
    if body.has_variable("max_jumps"):
        body.max_jumps += extra_jumps
        queue_free()
