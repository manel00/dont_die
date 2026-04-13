@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## TileMap tile operations.


func get_handlers() -> Dictionary:
	return {
		"tilemap_set_cell": Callable(self, "_cmd_tilemap_set_cell"),
		"tilemap_fill_rect": Callable(self, "_cmd_tilemap_fill_rect"),
		"tilemap_get_cell": Callable(self, "_cmd_tilemap_get_cell"),
		"tilemap_clear": Callable(self, "_cmd_tilemap_clear"),
		"tilemap_get_info": Callable(self, "_cmd_tilemap_get_info"),
		"tilemap_get_used_cells": Callable(self, "_cmd_tilemap_get_used_cells"),
	}


func _get_tilemap(p: Dictionary) -> TileMapLayer:
	var path := String(p.get("path", p.get("tilemapPath", "")))
	if path.is_empty():
		return null
	var node := _find_node(path)
	if node is TileMapLayer:
		return node as TileMapLayer
	return null


func _cmd_tilemap_set_cell(p: Dictionary) -> Dictionary:
	var tm := _get_tilemap(p)
	if tm == null:
		return _error(-32602, "TileMapLayer not found", "Pass valid path to TileMapLayer node")
	var x := int(p.get("x", 0))
	var y := int(p.get("y", 0))
	var source_id := int(p.get("sourceId", 0))
	var atlas_x := int(p.get("atlasX", 0))
	var atlas_y := int(p.get("atlasY", 0))
	var alt := int(p.get("alternativeTile", 0))
	tm.set_cell(Vector2i(x, y), source_id, Vector2i(atlas_x, atlas_y), alt)
	return {"x": x, "y": y, "ok": true}


func _cmd_tilemap_fill_rect(p: Dictionary) -> Dictionary:
	var tm := _get_tilemap(p)
	if tm == null:
		return _error(-32602, "TileMapLayer not found", "Pass valid path")
	var x1 := int(p.get("x1", 0))
	var y1 := int(p.get("y1", 0))
	var x2 := int(p.get("x2", 0))
	var y2 := int(p.get("y2", 0))
	var source_id := int(p.get("sourceId", 0))
	var atlas_x := int(p.get("atlasX", 0))
	var atlas_y := int(p.get("atlasY", 0))
	var count := 0
	for x in range(min(x1, x2), max(x1, x2) + 1):
		for y in range(min(y1, y2), max(y1, y2) + 1):
			tm.set_cell(Vector2i(x, y), source_id, Vector2i(atlas_x, atlas_y))
			count += 1
	return {"filled": count, "ok": true}


func _cmd_tilemap_get_cell(p: Dictionary) -> Dictionary:
	var tm := _get_tilemap(p)
	if tm == null:
		return _error(-32602, "TileMapLayer not found", "Pass valid path")
	var x := int(p.get("x", 0))
	var y := int(p.get("y", 0))
	var coords := Vector2i(x, y)
	var source_id := tm.get_cell_source_id(coords)
	var atlas_coords := tm.get_cell_atlas_coords(coords)
	var alt := tm.get_cell_alternative_tile(coords)
	return {"x": x, "y": y, "sourceId": source_id, "atlasCoords": [atlas_coords.x, atlas_coords.y], "alternativeTile": alt}


func _cmd_tilemap_clear(p: Dictionary) -> Dictionary:
	var tm := _get_tilemap(p)
	if tm == null:
		return _error(-32602, "TileMapLayer not found", "Pass valid path")
	tm.clear()
	return {"ok": true}


func _cmd_tilemap_get_info(p: Dictionary) -> Dictionary:
	var tm := _get_tilemap(p)
	if tm == null:
		return _error(-32602, "TileMapLayer not found", "Pass valid path")
	var tile_set := tm.tile_set
	var info := {"path": String(tm.get_path()), "has_tileset": tile_set != null}
	if tile_set:
		info["tile_size"] = [tile_set.tile_size.x, tile_set.tile_size.y]
		info["sources_count"] = tile_set.get_source_count()
	info["used_cells"] = tm.get_used_cells().size()
	return info


func _cmd_tilemap_get_used_cells(p: Dictionary) -> Dictionary:
	var tm := _get_tilemap(p)
	if tm == null:
		return _error(-32602, "TileMapLayer not found", "Pass valid path")
	var cells := tm.get_used_cells()
	var result: Array[Dictionary] = []
	var max_cells := int(p.get("maxCells", 500))
	for i in range(min(cells.size(), max_cells)):
		var c: Vector2i = cells[i]
		result.append({"x": c.x, "y": c.y, "sourceId": tm.get_cell_source_id(c)})
	return {"count": cells.size(), "cells": result, "truncated": cells.size() > max_cells}
