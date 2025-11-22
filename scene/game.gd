extends Node2D

# Simple loader for enemy and level scenes.
# Scans `res://enemies` and `res://levels` for `.tscn`/`.scn` files,
# indexes them by filename (basename) and provides helpers to load
# or instantiate them at runtime.

var enemy_index: Dictionary = {}
var level_index: Dictionary = {}
var _resource_cache: Dictionary = {}

func _ready() -> void:
	_build_indices()
	# Debug listing to verify available assets
	print("[Game] Enemies found:", enemy_index.keys())
	print("[Game] Levels found:", level_index.keys())


func _build_indices() -> void:
	enemy_index.clear()
	level_index.clear()
	_scan_dir("res://enemies", enemy_index)
	_scan_dir("res://levels", level_index)


func _scan_dir(base_path: String, out_index: Dictionary) -> void:
	var dir := DirAccess.open(base_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var is_dir := dir.current_is_dir()
		var full_path := base_path.rstrip("/") + "/" + entry
		if is_dir:
			_scan_dir(full_path, out_index)
		else:
			var ext := entry.get_extension().to_lower()
			if ext == "tscn" or ext == "scn":
				var key := entry.get_basename()
				if out_index.has(key):
					push_warning("Duplicate asset name '%s' found at %s (already indexed at %s)" % [key, full_path, out_index[key]])
				out_index[key] = full_path
		entry = dir.get_next()
	dir.list_dir_end()


func _load_resource(path: String):
	if path == "":
		return null
	if _resource_cache.has(path):
		return _resource_cache[path]
	var res = ResourceLoader.load(path)
	if res == null:
		push_error("Failed to load resource: %s" % path)
		return null
	_resource_cache[path] = res
	return res


func has_enemy(asset_name: String) -> bool:
	return enemy_index.has(asset_name)


func has_level(asset_name: String) -> bool:
	return level_index.has(asset_name)


func load_enemy(asset_name: String):
	if not has_enemy(asset_name):
		push_error("Enemy '%s' not found" % asset_name)
		return null
	return _load_resource(enemy_index[asset_name])


func instantiate_enemy(asset_name: String):
	var packed = load_enemy(asset_name)
	if packed == null:
		return null
	# Godot 4: PackedScene.instantiate()
	if packed is PackedScene:
		return packed.instantiate()
	push_error("Resource for '%s' is not a PackedScene: %s" % [asset_name, enemy_index.get(asset_name)])
	return null


func load_level(asset_name: String):
	if not has_level(asset_name):
		push_error("Level '%s' not found" % asset_name)
		return null
	return _load_resource(level_index[asset_name])


func instantiate_level(asset_name: String):
	var packed = load_level(asset_name)
	if packed == null:
		return null
	if packed is PackedScene:
		return packed.instantiate()
	push_error("Resource for level '%s' is not a PackedScene: %s" % [asset_name, level_index.get(asset_name)])
	return null
