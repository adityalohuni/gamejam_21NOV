extends Area2D
class_name CustomAnimatableBody2D

@export var extra_jumps: int = 1

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.has_variable("max_jumps"):
		body.max_jumps += extra_jumps
		queue_free()
