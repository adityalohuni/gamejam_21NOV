extends HBoxContainer

@onready var heart_template: Sprite2D = $Heart1
var hearts: Array[Sprite2D] = []

@export var heart_spacing: int = 64

var heart_on_rect: Rect2 = Rect2(0, 0, 16, 16)
var heart_off_rect: Rect2 = Rect2(16, 0, 16, 16)

@onready var player: CharacterBody2D = $"../../Player"

func _ready() -> void:
	# Hide the template (used only for duplication) and connect signal
	if heart_template:
		heart_template.visible = false

	if player:
		player.connect("health_changed", Callable(self, "update_hearts"))

func _create_heart(index: int) -> Sprite2D:
	var new_heart := heart_template.duplicate() as Sprite2D
	new_heart.visible = true
	# position each heart to the right of the previous one
	new_heart.position = Vector2(index * heart_spacing, 0)
	# enable region mode if available
	if "region_enabled" in new_heart:
		new_heart.region_enabled = true
	add_child(new_heart)
	hearts.append(new_heart)
	return new_heart

func _ensure_hearts(max_health: int) -> void:
	if hearts.size() != 0:
		return
	for i in range(max_health):
		_create_heart(i)

func update_hearts(current_health: int, max_health: int) -> void:
	# Create hearts once (lazy init) and then only update visuals
	if not heart_template:
		return
	_ensure_hearts(max_health)

	for i in range(hearts.size()):
		var h := hearts[i]
		h.region_rect = heart_on_rect if i < current_health else heart_off_rect
