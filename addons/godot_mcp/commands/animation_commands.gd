@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Animation commands: CRUD operations on animations, tracks, and keyframes.


func get_handlers() -> Dictionary:
	return {
		"list_animations": Callable(self, "_cmd_list_animations"),
		"create_animation": Callable(self, "_cmd_create_animation"),
		"add_animation_track": Callable(self, "_cmd_add_animation_track"),
		"set_animation_keyframe": Callable(self, "_cmd_set_animation_keyframe"),
		"get_animation_info": Callable(self, "_cmd_get_animation_info"),
		"remove_animation": Callable(self, "_cmd_remove_animation"),
	}


func _get_anim_player(p: Dictionary) -> AnimationPlayer:
	var path := String(p.get("playerPath", p.get("path", "")))
	if path.is_empty():
		return null
	var node := _find_node(path)
	if node is AnimationPlayer:
		return node as AnimationPlayer
	return null


func _cmd_list_animations(p: Dictionary) -> Dictionary:
	var player := _get_anim_player(p)
	if player == null:
		return _error(-32602, "AnimationPlayer not found", "Pass valid playerPath")
	var anims: Array[Dictionary] = []
	for anim_name in player.get_animation_list():
		var anim := player.get_animation(anim_name)
		anims.append({"name": anim_name, "length": anim.length, "loop": anim.loop_mode != Animation.LOOP_NONE, "tracks": anim.get_track_count()})
	return {"path": String(player.get_path()), "count": anims.size(), "animations": anims}


func _cmd_create_animation(p: Dictionary) -> Dictionary:
	var player := _get_anim_player(p)
	if player == null:
		return _error(-32602, "AnimationPlayer not found", "Pass valid playerPath")
	var anim_name := String(p.get("name", "new_animation"))
	var length := float(p.get("length", 1.0))
	var loop := bool(p.get("loop", false))
	var anim := Animation.new()
	anim.length = length
	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR
	var lib := player.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)
	lib.add_animation(anim_name, anim)
	return {"name": anim_name, "length": length, "ok": true}


func _cmd_add_animation_track(p: Dictionary) -> Dictionary:
	var player := _get_anim_player(p)
	if player == null:
		return _error(-32602, "AnimationPlayer not found", "Pass valid playerPath")
	var anim_name := String(p.get("animation", ""))
	if anim_name.is_empty():
		return _error(-32602, "Missing animation name", "Pass payload.animation")
	var anim := player.get_animation(anim_name)
	if anim == null:
		return _error(-32011, "Animation not found: %s" % anim_name, "Create it first")
	var track_type_str := String(p.get("trackType", "value")).to_lower()
	var track_type: Animation.TrackType
	match track_type_str:
		"value": track_type = Animation.TYPE_VALUE
		"position_3d", "position": track_type = Animation.TYPE_POSITION_3D
		"rotation_3d", "rotation": track_type = Animation.TYPE_ROTATION_3D
		"scale_3d", "scale": track_type = Animation.TYPE_SCALE_3D
		"method": track_type = Animation.TYPE_METHOD
		"bezier": track_type = Animation.TYPE_BEZIER
		"animation": track_type = Animation.TYPE_ANIMATION
		_: track_type = Animation.TYPE_VALUE
	var track_path := String(p.get("trackPath", ""))
	if track_path.is_empty():
		return _error(-32602, "Missing trackPath", "e.g. 'Sprite2D:position'")
	var idx := anim.add_track(track_type)
	anim.track_set_path(idx, NodePath(track_path))
	return {"animation": anim_name, "track_index": idx, "track_type": track_type_str, "path": track_path, "ok": true}


func _cmd_set_animation_keyframe(p: Dictionary) -> Dictionary:
	var player := _get_anim_player(p)
	if player == null:
		return _error(-32602, "AnimationPlayer not found", "Pass valid playerPath")
	var anim_name := String(p.get("animation", ""))
	var anim := player.get_animation(anim_name)
	if anim == null:
		return _error(-32011, "Animation not found: %s" % anim_name, "Create it first")
	var track := int(p.get("track", 0))
	var time := float(p.get("time", 0.0))
	var value = _parse_value(p.get("value"))
	if track >= anim.get_track_count():
		return _error(-32602, "Track index out of range", "Max: %d" % (anim.get_track_count() - 1))
	var key_type := anim.track_get_type(track)
	match key_type:
		Animation.TYPE_VALUE:
			anim.track_insert_key(track, time, value)
		Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D:
			anim.track_insert_key(track, time, value)
		Animation.TYPE_BEZIER:
			anim.bezier_track_insert_key(track, time, float(value) if value != null else 0.0)
		_:
			anim.track_insert_key(track, time, value)
	return {"animation": anim_name, "track": track, "time": time, "ok": true}


func _cmd_get_animation_info(p: Dictionary) -> Dictionary:
	var player := _get_anim_player(p)
	if player == null:
		return _error(-32602, "AnimationPlayer not found", "Pass valid playerPath")
	var anim_name := String(p.get("animation", ""))
	var anim := player.get_animation(anim_name)
	if anim == null:
		return _error(-32011, "Animation not found: %s" % anim_name, "Check name")
	var tracks: Array[Dictionary] = []
	for i in range(anim.get_track_count()):
		var keys: Array[Dictionary] = []
		for k in range(anim.track_get_key_count(i)):
			keys.append({"time": anim.track_get_key_time(i, k), "value": _safe_value(anim.track_get_key_value(i, k))})
		tracks.append({"index": i, "type": anim.track_get_type(i), "path": String(anim.track_get_path(i)), "keys": keys})
	return {"name": anim_name, "length": anim.length, "loop": anim.loop_mode != Animation.LOOP_NONE, "tracks": tracks}


func _cmd_remove_animation(p: Dictionary) -> Dictionary:
	var player := _get_anim_player(p)
	if player == null:
		return _error(-32602, "AnimationPlayer not found", "Pass valid playerPath")
	var anim_name := String(p.get("animation", p.get("name", "")))
	if anim_name.is_empty():
		return _error(-32602, "Missing animation name", "Pass name or animation")
	var lib := player.get_animation_library("")
	if lib == null or not lib.has_animation(anim_name):
		return _error(-32011, "Animation not found: %s" % anim_name, "Check name")
	lib.remove_animation(anim_name)
	return {"name": anim_name, "ok": true}
