@tool
extends Node
## Command router — loads all command handler files and dispatches requests.

var editor_plugin: EditorPlugin

var _command_handlers: Dictionary = {}
var _tool_aliases: Dictionary = {}

var _handler_files: Array[String] = [
	"res://addons/godot_mcp/commands/core_commands.gd",
	"res://addons/godot_mcp/commands/editor_commands.gd",
	"res://addons/godot_mcp/commands/input_commands.gd",
	"res://addons/godot_mcp/commands/runtime_commands.gd",
	"res://addons/godot_mcp/commands/animation_commands.gd",
	"res://addons/godot_mcp/commands/animation_tree_commands.gd",
	"res://addons/godot_mcp/commands/tilemap_commands.gd",
	"res://addons/godot_mcp/commands/scene3d_commands.gd",
	"res://addons/godot_mcp/commands/physics_commands.gd",
	"res://addons/godot_mcp/commands/particles_commands.gd",
	"res://addons/godot_mcp/commands/navigation_commands.gd",
	"res://addons/godot_mcp/commands/audio_commands.gd",
	"res://addons/godot_mcp/commands/theme_commands.gd",
	"res://addons/godot_mcp/commands/shader_commands.gd",
	"res://addons/godot_mcp/commands/resource_commands.gd",
	"res://addons/godot_mcp/commands/batch_commands.gd",
	"res://addons/godot_mcp/commands/testing_commands.gd",
	"res://addons/godot_mcp/commands/analysis_commands.gd",
	"res://addons/godot_mcp/commands/profiling_commands.gd",
	"res://addons/godot_mcp/commands/export_commands.gd",
]


func _ready() -> void:
	_register_commands()


func _register_commands() -> void:
	_command_handlers.clear()
	_tool_aliases.clear()

	for handler_path in _handler_files:
		var script = load(handler_path)
		if script == null:
			push_warning("[MCP] Failed to load handler: %s" % handler_path)
			continue

		var instance = script.new()
		if instance == null:
			push_warning("[MCP] Failed to instantiate handler: %s" % handler_path)
			continue

		instance.set_editor_plugin(editor_plugin)

		# Register handlers
		var handlers: Dictionary = instance.get_handlers()
		for key in handlers.keys():
			if _command_handlers.has(key):
				push_warning("[MCP] Duplicate handler: %s (from %s)" % [key, handler_path])
			_command_handlers[key] = handlers[key]

		# Register aliases
		var aliases: Dictionary = instance.get_aliases()
		for key in aliases.keys():
			_tool_aliases[key] = aliases[key]

	print("[MCP] Registered %d command handlers + %d aliases from %d modules" % [
		_command_handlers.size(), _tool_aliases.size(), _handler_files.size()
	])


func execute(command: String, payload: Dictionary) -> Dictionary:
	var target := command
	if _tool_aliases.has(command):
		target = String(_tool_aliases[command])

	if not _command_handlers.has(target):
		return {
			"error": {
				"code": -32601,
				"message": "Tool '%s' is not implemented in this bridge yet" % command,
				"suggestion": "Use implemented core tools first or extend handlers"
			}
		}

	var callable: Callable = _command_handlers[target]
	var result = callable.call(payload)

	# Handle async results (Callable returns Signal/Coroutine)
	if result is Signal:
		result = await result

	if typeof(result) == TYPE_DICTIONARY and result.has("__error"):
		return {"error": result.get("__error")}

	return {
		"result": {
			"tool": command,
			"implemented": true,
			"data": result
		}
	}


func get_registered_commands() -> Array[String]:
	var keys: Array[String] = []
	for key in _command_handlers.keys():
		keys.append(String(key))
	keys.sort()
	return keys
