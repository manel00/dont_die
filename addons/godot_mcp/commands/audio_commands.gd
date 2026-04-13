@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Audio commands: players, buses, effects.


func get_handlers() -> Dictionary:
	return {
		"add_audio_player": Callable(self, "_cmd_add_audio_player"),
		"add_audio_bus": Callable(self, "_cmd_add_audio_bus"),
		"add_audio_bus_effect": Callable(self, "_cmd_add_audio_bus_effect"),
		"set_audio_bus": Callable(self, "_cmd_set_audio_bus"),
		"get_audio_bus_layout": Callable(self, "_cmd_get_audio_bus_layout"),
		"get_audio_info": Callable(self, "_cmd_get_audio_info"),
	}


func _cmd_add_audio_player(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", ""))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass parentPath")
	var player_type := String(p.get("playerType", "auto")).to_lower()
	var node_name := String(p.get("name", "AudioStreamPlayer"))
	var player: Node
	match player_type:
		"2d":
			var ap := AudioStreamPlayer2D.new()
			ap.name = node_name
			if p.has("bus"): ap.bus = StringName(String(p.bus))
			if p.has("volumeDb"): ap.volume_db = float(p.volumeDb)
			if p.has("maxDistance"): ap.max_distance = float(p.maxDistance)
			player = ap
		"3d":
			var ap := AudioStreamPlayer3D.new()
			ap.name = node_name
			if p.has("bus"): ap.bus = StringName(String(p.bus))
			if p.has("volumeDb"): ap.volume_db = float(p.volumeDb)
			if p.has("maxDistance"): ap.max_distance = float(p.maxDistance)
			player = ap
		_:
			# Auto-detect or default to regular
			if parent is Node3D:
				var ap := AudioStreamPlayer3D.new()
				ap.name = node_name
				if p.has("bus"): ap.bus = StringName(String(p.bus))
				if p.has("volumeDb"): ap.volume_db = float(p.volumeDb)
				player = ap
			elif parent is Node2D:
				var ap := AudioStreamPlayer2D.new()
				ap.name = node_name
				if p.has("bus"): ap.bus = StringName(String(p.bus))
				if p.has("volumeDb"): ap.volume_db = float(p.volumeDb)
				player = ap
			else:
				var ap := AudioStreamPlayer.new()
				ap.name = node_name
				if p.has("bus"): ap.bus = StringName(String(p.bus))
				if p.has("volumeDb"): ap.volume_db = float(p.volumeDb)
				player = ap
	# Load audio stream
	if p.has("stream"):
		var stream = load(String(p.stream))
		if stream is AudioStream:
			player.set("stream", stream)
	_undo().add_child_node(parent, player, "MCP: Add AudioPlayer")
	return {"path": String(player.get_path()), "type": player.get_class(), "ok": true}


func _cmd_add_audio_bus(p: Dictionary) -> Dictionary:
	var bus_name := String(p.get("name", "NewBus"))
	var send_to := String(p.get("sendTo", "Master"))
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, StringName(send_to))
	if p.has("volumeDb"):
		AudioServer.set_bus_volume_db(idx, float(p.volumeDb))
	if p.has("solo"):
		AudioServer.set_bus_solo(idx, bool(p.solo))
	if p.has("mute"):
		AudioServer.set_bus_mute(idx, bool(p.mute))
	return {"name": bus_name, "index": idx, "ok": true}


func _cmd_add_audio_bus_effect(p: Dictionary) -> Dictionary:
	var bus_name := String(p.get("bus", "Master"))
	var bus_idx := AudioServer.get_bus_index(StringName(bus_name))
	if bus_idx < 0:
		return _error(-32602, "Bus not found: %s" % bus_name, "Check bus name")
	var effect_type := String(p.get("effectType", "reverb")).to_lower()
	var effect: AudioEffect
	match effect_type:
		"reverb": effect = AudioEffectReverb.new()
		"delay": effect = AudioEffectDelay.new()
		"compressor": effect = AudioEffectCompressor.new()
		"limiter": effect = AudioEffectLimiter.new()
		"eq", "equalizer": effect = AudioEffectEQ.new()
		"distortion": effect = AudioEffectDistortion.new()
		"chorus": effect = AudioEffectChorus.new()
		"phaser": effect = AudioEffectPhaser.new()
		"amplify": effect = AudioEffectAmplify.new()
		"lowpass", "low_pass": effect = AudioEffectLowPassFilter.new()
		"highpass", "high_pass": effect = AudioEffectHighPassFilter.new()
		"bandpass", "band_pass": effect = AudioEffectBandPassFilter.new()
		_: effect = AudioEffectReverb.new()
	AudioServer.add_bus_effect(bus_idx, effect)
	return {"bus": bus_name, "effect": effect_type, "ok": true}


func _cmd_set_audio_bus(p: Dictionary) -> Dictionary:
	var bus_name := String(p.get("bus", p.get("name", "Master")))
	var bus_idx := AudioServer.get_bus_index(StringName(bus_name))
	if bus_idx < 0:
		return _error(-32602, "Bus not found: %s" % bus_name, "Check bus name")
	if p.has("volumeDb"):
		AudioServer.set_bus_volume_db(bus_idx, float(p.volumeDb))
	if p.has("solo"):
		AudioServer.set_bus_solo(bus_idx, bool(p.solo))
	if p.has("mute"):
		AudioServer.set_bus_mute(bus_idx, bool(p.mute))
	if p.has("sendTo"):
		AudioServer.set_bus_send(bus_idx, StringName(String(p.sendTo)))
	return {"bus": bus_name, "ok": true}


func _cmd_get_audio_bus_layout(_p: Dictionary) -> Dictionary:
	var buses: Array[Dictionary] = []
	for i in range(AudioServer.bus_count):
		var effects: Array[String] = []
		for e in range(AudioServer.get_bus_effect_count(i)):
			var eff := AudioServer.get_bus_effect(i, e)
			effects.append(eff.get_class() if eff else "unknown")
		buses.append({
			"index": i,
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"solo": AudioServer.is_bus_solo(i),
			"mute": AudioServer.is_bus_mute(i),
			"send": String(AudioServer.get_bus_send(i)),
			"effects": effects
		})
	return {"count": buses.size(), "buses": buses}


func _cmd_get_audio_info(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var info := {"path": String(node.get_path()), "type": node.get_class()}
	if node is AudioStreamPlayer:
		var ap := node as AudioStreamPlayer
		info["playing"] = ap.playing
		info["volume_db"] = ap.volume_db
		info["bus"] = String(ap.bus)
		info["has_stream"] = ap.stream != null
	elif node is AudioStreamPlayer2D:
		var ap := node as AudioStreamPlayer2D
		info["playing"] = ap.playing
		info["volume_db"] = ap.volume_db
		info["bus"] = String(ap.bus)
		info["max_distance"] = ap.max_distance
	elif node is AudioStreamPlayer3D:
		var ap := node as AudioStreamPlayer3D
		info["playing"] = ap.playing
		info["volume_db"] = ap.volume_db
		info["bus"] = String(ap.bus)
		info["max_distance"] = ap.max_distance
	return info
