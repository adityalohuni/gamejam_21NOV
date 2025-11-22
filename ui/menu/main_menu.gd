extends Control


func _on_start_botton_pressed() -> void:
	# Change to the game scene. Adjust path if your scene is elsewhere.
	# Godot 4: use change_scene_to_file
	get_tree().change_scene_to_file("res://scene/game.tscn")
