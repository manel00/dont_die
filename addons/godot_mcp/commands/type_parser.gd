@tool
extends RefCounted
## Smart type parser — converts string representations to proper Godot types.
## Supports: Vector2, Vector3, Color, Rect2, Transform2D, Basis, etc.


static func parse_value(value: Variant) -> Variant:
	if typeof(value) != TYPE_STRING:
		return value

	var s := String(value).strip_edges()

	# Boolean
	if s == "true":
		return true
	if s == "false":
		return false

	# Null
	if s == "null" or s == "":
		return null

	# Integer (no decimal point)
	if s.is_valid_int():
		return int(s)

	# Float
	if s.is_valid_float():
		return float(s)

	# Color hex: #ff0000 or #80ff0000
	if s.begins_with("#") and (s.length() == 7 or s.length() == 9):
		return Color.html(s)

	# Color("name") e.g. Color.RED
	if s.begins_with("Color."):
		var color_name := s.substr(6).to_upper()
		match color_name:
			"RED": return Color.RED
			"GREEN": return Color.GREEN
			"BLUE": return Color.BLUE
			"WHITE": return Color.WHITE
			"BLACK": return Color.BLACK
			"YELLOW": return Color.YELLOW
			"CYAN": return Color.CYAN
			"MAGENTA": return Color.MAGENTA
			"TRANSPARENT": return Color.TRANSPARENT
			"ORANGE": return Color(1, 0.647, 0)
			"PURPLE": return Color(0.5, 0, 0.5)
			"GRAY", "GREY": return Color.GRAY

	# Vector2(x, y)
	var vec2_match := _parse_constructor(s, "Vector2", 2)
	if vec2_match.size() == 2:
		return Vector2(vec2_match[0], vec2_match[1])

	# Vector2i(x, y)
	var vec2i_match := _parse_constructor(s, "Vector2i", 2)
	if vec2i_match.size() == 2:
		return Vector2i(int(vec2i_match[0]), int(vec2i_match[1]))

	# Vector3(x, y, z)
	var vec3_match := _parse_constructor(s, "Vector3", 3)
	if vec3_match.size() == 3:
		return Vector3(vec3_match[0], vec3_match[1], vec3_match[2])

	# Vector3i(x, y, z)
	var vec3i_match := _parse_constructor(s, "Vector3i", 3)
	if vec3i_match.size() == 3:
		return Vector3i(int(vec3i_match[0]), int(vec3i_match[1]), int(vec3i_match[2]))

	# Vector4(x, y, z, w)
	var vec4_match := _parse_constructor(s, "Vector4", 4)
	if vec4_match.size() == 4:
		return Vector4(vec4_match[0], vec4_match[1], vec4_match[2], vec4_match[3])

	# Color(r, g, b) or Color(r, g, b, a)
	var color3_match := _parse_constructor(s, "Color", 3)
	if color3_match.size() == 3:
		return Color(color3_match[0], color3_match[1], color3_match[2])
	var color4_match := _parse_constructor(s, "Color", 4)
	if color4_match.size() == 4:
		return Color(color4_match[0], color4_match[1], color4_match[2], color4_match[3])

	# Rect2(x, y, w, h)
	var rect2_match := _parse_constructor(s, "Rect2", 4)
	if rect2_match.size() == 4:
		return Rect2(rect2_match[0], rect2_match[1], rect2_match[2], rect2_match[3])

	# Rect2i(x, y, w, h)
	var rect2i_match := _parse_constructor(s, "Rect2i", 4)
	if rect2i_match.size() == 4:
		return Rect2i(int(rect2i_match[0]), int(rect2i_match[1]), int(rect2i_match[2]), int(rect2i_match[3]))

	# Transform2D — pass-through as string for now
	# Basis, Transform3D — complex types, pass-through

	# NodePath
	if s.begins_with("NodePath(") or s.begins_with("^"):
		var inner := s
		if inner.begins_with("NodePath("):
			inner = inner.substr(9)
			if inner.ends_with(")"):
				inner = inner.left(inner.length() - 1)
			inner = inner.strip_edges().trim_prefix("\"").trim_suffix("\"")
		elif inner.begins_with("^"):
			inner = inner.substr(1).trim_prefix("\"").trim_suffix("\"")
		return NodePath(inner)

	# StringName
	if s.begins_with("&\"") and s.ends_with("\""):
		return StringName(s.substr(2, s.length() - 3))

	return s


static func _parse_constructor(s: String, type_name: String, expected_args: int) -> Array[float]:
	if not s.begins_with(type_name + "(") or not s.ends_with(")"):
		return []

	var inner := s.substr(type_name.length() + 1, s.length() - type_name.length() - 2)
	var parts := inner.split(",")

	if parts.size() != expected_args:
		return []

	var result: Array[float] = []
	for part in parts:
		var trimmed := part.strip_edges()
		if not trimmed.is_valid_float():
			return []
		result.append(float(trimmed))

	return result


## Parse a dictionary of property key-values, converting string values to Godot types.
static func parse_properties(props: Dictionary) -> Dictionary:
	var result := {}
	for key in props.keys():
		result[key] = parse_value(props[key])
	return result
