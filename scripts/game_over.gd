extends Control


func _on_go_to_main_menu_pressed() -> void:
	# Ensure the tree is unpaused then go to main menu scene.
	get_tree().paused = false
	# Adjust the path below if your main menu scene is at a different location.
	# Godot 4: use change_scene_to_file
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")

func _ready() -> void:
	# When this scene is loaded on its own (game over scene), show the UI.
	# If you use this as an overlay inside the game scene, you can call
	# `show_game_over()` instead to both show and pause the game.
		# When configured in the scene the Control will process while paused.
		# (We avoid referencing PauseMode here to keep the linter quiet.)
	visible = true

func show_game_over() -> void:
	visible = true
	# Do not pause the entire scene tree here — pausing prevents UI input
	# in some editor/runtime setups and editing .tscn files is avoided per request.
	# If you want the game to stop when showing the Game Over UI, handle
	# pausing in the scene that calls `show_game_over()` (for example, disable
	# player processing or physics there).
