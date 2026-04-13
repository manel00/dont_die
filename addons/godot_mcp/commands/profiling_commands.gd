@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Profiling commands: performance monitors.


func get_handlers() -> Dictionary:
	return {
		"get_performance_monitors": Callable(self, "_cmd_get_performance_monitors"),
		"get_editor_performance": Callable(self, "_cmd_get_editor_performance"),
	}


func _cmd_get_performance_monitors(p: Dictionary) -> Dictionary:
	var monitors := {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_time": Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_process_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"navigation_process_time": Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS),
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"static_memory_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"message_buffer_max": Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"object_resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"object_node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"object_orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"render_total_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_total_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"render_total_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"physics_2d_active_objects": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"physics_2d_collision_pairs": Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
		"physics_2d_island_count": Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT),
		"physics_3d_active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"physics_3d_collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		"physics_3d_island_count": Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT),
		"navigation_active_maps": Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS),
		"navigation_region_count": Performance.get_monitor(Performance.NAVIGATION_REGION_COUNT),
		"navigation_agent_count": Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT),
	}
	# Filter by requested keys if specified
	var keys: Array = p.get("monitors", [])
	if not keys.is_empty():
		var filtered := {}
		for key in keys:
			var k := String(key)
			if monitors.has(k):
				filtered[k] = monitors[k]
		return filtered
	return monitors


func _cmd_get_editor_performance(_p: Dictionary) -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_time_ms": snapped(Performance.get_monitor(Performance.TIME_PROCESS) * 1000, 0.01),
		"physics_time_ms": snapped(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, 0.01),
		"static_memory_mb": snapped(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	}
