extends Area2D

@export var speed: float = 1000.0
@export var max_lifetime: float = 3.0

var _life: float = 0.0

func _ready() -> void:
	# connect collision signals so the bullet can react and destroy itself
	if has_method("connect"):
		connect("body_entered", Callable(self, "_on_body_entered"))
		connect("area_entered", Callable(self, "_on_area_entered"))
	pass

func _physics_process(delta: float) -> void:
	var direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	position += direction * speed * delta
	
	_life += delta

func _on_body_entered(body: Node) -> void:
	# avoid self-collision or unexpected frees
	if body == self:
		return

	# try applying damage if the body exposes a method for it
	if body and body.has_method("take_damage"):
		body.take_damage(1)
	elif body and body.has_method("apply_damage"):
		body.apply_damage(1)

	# Stop further monitoring and free the bullet. Use deferred to avoid in/out signal blocking.
	set_deferred("monitoring", false)

func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return

	if area and area.has_method("take_damage"):
		area.take_damage(1)
	elif area and area.has_method("apply_damage"):
		area.apply_damage(1)

	set_deferred("monitoring", false)
