# Godot MCP Pro — AI Agent Context

> **168 AI tools** for Godot 4 via MCP. Copy this file to your Godot project root as `AGENTS.md`.

## Setup

```bash
cd server && npm install && npm run build
```

Add to MCP client config:
```json
{ 
    "mcpServers": { 
        "godot": { 
            "command": "node", 
            "args": ["server/dist/index.js"] 
        } 
    } 
}
```

Enable plugin: **Project > Project Settings > Plugins > Godot MCP Bridge > Enable**

---

You have access to 168 MCP tools that connect directly to the Godot 4 editor. You can create scenes, write scripts, simulate player input, inspect running games, and more — all without the user leaving this conversation. Every change goes through Godot's UndoRedo system, so the user can always Ctrl+Z.

### 1. Explore a Project
Always start by understanding the project before making changes:

```
get_project_info          → project name, Godot version, autoloads, main scene
get_filesystem_tree       → recursive directory structure
get_scene_tree            → node hierarchy of the currently open scene
read_script               → read any GDScript file
get_project_settings      → check project configuration by key
get_project_statistics    → total scenes, scripts, assets, GDScript line count
```

### 2. Build a 2D Scene
```
create_scene   → create .tscn file with root node type
add_node       → add child nodes with properties
create_script  → write GDScript for game logic
attach_script  → attach script to a node
update_property → set position, scale, modulate, etc.
save_scene     → save to disk
```

**Example — creating a player:**
1. `create_scene` with rootType `CharacterBody2D`, path `res://scenes/player.tscn`
2. `add_node` type `Sprite2D` with properties `{"texture": "res://icon.svg"}`
3. `add_node` type `CollisionShape2D`
4. `add_resource` to assign a shape (e.g., `RectangleShape2D`) to the CollisionShape2D
5. `create_script` with movement logic
6. `attach_script` to the root node
7. `save_scene`

### 3. Build a 3D Scene
```
create_scene         → rootType: Node3D
add_mesh_instance    → add primitives (box, sphere, cylinder, plane, torus) or import .glb/.gltf
setup_lighting       → presets: sun, indoor, dramatic, spot
setup_environment    → sky, ambient light, fog, glow, SSAO, SSR, tonemap
setup_camera_3d      → camera with FOV, projection, transform
set_material_3d      → PBR materials (albedo, metallic, roughness, emission, texture)
setup_collision      → add collision shapes (auto-detects 2D/3D)
setup_physics_body   → configure mass, gravity_scale, floor angle
add_gridmap          → GridMap node with MeshLibrary
```

### 4. Write & Edit Scripts
```
create_script  → create new .gd file (provide full content)
edit_script    → modify existing scripts
  - Use replacements: [{search: "old code", replace: "new code"}] for targeted edits
  - Use newContent for full file replacement
  - Use insert_after + code for inserting code after a marker
  - Use find + replace for simple string replacement
validate_script → check for syntax errors without running
read_script    → read current content before editing
attach_script  → attach to a node
get_open_scripts → list scripts open in editor
search_in_files → search text across project with line numbers
```

### 5. Playtest & Debug
```
play_scene             → launch the game (path for specific scene, empty for current)
get_game_screenshot    → see what the game looks like right now
capture_frames         → capture multiple frames to observe motion/animation
get_game_scene_tree    → inspect the live scene tree at runtime
get_game_node_properties → read runtime values (position, health, state, etc.)
set_game_node_property → modify values in the running game
simulate_key           → press keys (A–Z, Space, Enter, Escape, arrows, F1–F12)
simulate_mouse_click   → click at viewport coordinates
simulate_action        → trigger InputMap actions (move_left, jump, etc.)
simulate_sequence      → multi-step input with delays between actions
get_editor_errors      → check for runtime errors
get_output_log         → read print() output and warnings
stop_scene             → stop the game
```

**Playtesting loop:**
1. `play_scene` → start the game
2. `get_game_screenshot` → see current state
3. `simulate_key` / `simulate_action` → interact with the game
4. `capture_frames` → observe behavior over time
5. `get_game_node_properties` → check specific values
6. `stop_scene` → stop when done
7. Fix issues in scripts → repeat

### 6. Animations
```
# Ensure an AnimationPlayer node exists in the scene
create_animation       → new animation with length and loop mode
add_animation_track    → add value/position/rotation/scale/method/bezier tracks
set_animation_keyframe → insert keyframes at specific times
get_animation_info     → inspect existing animations (tracks + keyframes)
list_animations        → list all animations in a player
remove_animation       → delete an animation
```

**Example — bouncing sprite:**
1. `create_animation` name `bounce`, length `1.0`, loop `true`
2. `add_animation_track` trackPath `Sprite2D:position`, trackType `value`
3. `set_animation_keyframe` time `0.0`, value `Vector2(0, 0)`
4. `set_animation_keyframe` time `0.5`, value `Vector2(0, -50)`
5. `set_animation_keyframe` time `1.0`, value `Vector2(0, 0)`

### 7. AnimationTree & State Machines
```
create_animation_tree           → set up with StateMachine or BlendTree root
add_state_machine_state         → add states (idle, walk, run, jump)
add_state_machine_transition    → define transitions with conditions
remove_state_machine_state      → remove a state
remove_state_machine_transition → remove a transition
set_tree_parameter              → control blend/condition parameters
set_blend_tree_node             → add Add2, Blend2, TimeScale, OneShot nodes
get_animation_tree_structure    → inspect full tree layout
```

### 8. UI / HUD
```
add_node          → Control, Label, Button, TextureRect, ProgressBar, etc.
set_anchor_preset → position Controls (full_rect, center, bottom_wide, etc.)
set_theme_color   → change font_color, font_pressed_color, etc.
set_theme_font_size → adjust text size
set_theme_stylebox  → backgrounds, borders, rounded corners, shadows
set_theme_constant  → margins, separation values
create_theme     → create Theme resource and apply to node
get_theme_info   → inspect current overrides
connect_signal   → wire up button pressed, value_changed, etc.
disconnect_signal → remove signal connections
```

### 9. TileMap
```
tilemap_get_info      → check tile set sources and atlas layout
tilemap_set_cell      → place individual tiles
tilemap_fill_rect     → fill rectangular regions
tilemap_get_cell      → read tile at position
tilemap_get_used_cells → see what's already placed
tilemap_clear         → clear all cells
```

### 10. Audio
```
add_audio_bus        → create audio buses (SFX, Music, UI)
set_audio_bus        → adjust volume, solo, mute, send
add_audio_bus_effect → add reverb, delay, compressor, EQ, distortion, chorus, phaser
add_audio_player     → add AudioStreamPlayer/2D/3D (auto-detects parent type)
get_audio_bus_layout → inspect full bus chain
get_audio_info       → audio node details
```

### 11. Particles
```
create_particles          → GPUParticles2D/3D (auto-detects parent type)
apply_particle_preset     → built-in presets: fire, smoke, rain, snow, sparks
set_particle_material     → direction, velocity, emission shape, scale
set_particle_color_gradient → color ramp with offset/color stops
get_particle_info         → inspect current settings
```

### 12. Navigation
```
setup_navigation_region → define walkable area (2D/3D auto-detected)
bake_navigation_mesh   → generate navmesh
setup_navigation_agent → add pathfinding agent with avoidance
set_navigation_layers  → configure navigation layers
get_navigation_info    → diagnostics
get_navigation_path    → calculate path between two points
```

### 13. Shaders
```
create_shader        → templates: canvas_item, spatial, particles, sky
read_shader          → read .gdshader content
edit_shader          → edit .gdshader content
assign_shader_material → apply ShaderMaterial to node with uniforms
set_shader_param     → adjust uniform values at runtime
get_shader_params    → inspect current uniform values
```

### 14. Project Configuration
```
set_project_setting  → change viewport size, physics settings, renderer, etc.
get_project_settings → read current settings
set_input_action     → define input mappings (move_left → A, etc.)
get_input_actions    → list all project input actions
add_autoload         → register autoload singletons
remove_autoload      → unregister autoload
set_physics_layers   → set collision layer and mask
get_physics_layers   → read collision layers
```

### 15. Resources
```
read_resource    → read .tres resource properties
edit_resource    → modify and save resource
create_resource  → create any Resource type as .tres
get_resource_preview → resource thumbnail
```

---

## Property Values
Properties are auto-parsed from strings. Use these formats:
- Vector2: `"Vector2(100, 200)"`
- Vector3: `"Vector3(1, 2, 3)"`
- Vector2i: `"Vector2i(10, 20)"`
- Color: `"Color(1, 0, 0, 1)"` or `"#ff0000"` or `"Color.RED"`
- Rect2: `"Rect2(0, 0, 100, 50)"`
- Bool: `"true"` / `"false"`
- Numbers: `"42"`, `"3.14"`
- NodePath: `"NodePath(../Sprite2D)"` or `"^../Sprite2D"`
- Enums: Use integer values (e.g., `0` for the first enum value)

## Never Edit project.godot Directly
Godot editor constantly overwrites `project.godot`. Always use `set_project_setting` to change project settings.

## GDScript Type Annotations
When writing GDScript with `for` loops over untyped arrays, use explicit type annotations:
```gdscript
# BAD — will cause errors
for item in some_untyped_array:
    var x := item.value  # type inference fails

# GOOD
for i in range(some_untyped_array.size()):
    var item: Dictionary = some_untyped_array[i]
    var x: int = item.value
```

## Script Changes Need Reload
After creating or significantly modifying scripts, use `reload_project` to ensure Godot picks up the changes. This is especially important after `create_script`.

## simulate_key Tips
- Use **short durations** (0.05–0.1 seconds is default) for precise movement
- Long durations cause overshooting
- For gameplay testing, prefer `simulate_action` over `simulate_key` when InputMap actions are defined
- Supports modifiers: `shift`, `ctrl`, `alt`, `meta`

## simulate_mouse_click
- Default `autoRelease: true` sends both press and release — required for UI buttons
- UI buttons fire on release, so both events are needed
- Use `double: true` for double-click

## execute_game_script / execute_editor_script Limitations
- No nested functions (`func` inside `func`) — causes compile error
- Use `.get("property")` instead of `.property` for dynamic access
- Runtime errors will pause the debugger (auto-continued, but avoid if possible)

## Collision & Pickup Areas
- For collectible items, use Area3D/Area2D with radius ≥ 1.5
- Smaller radii are nearly impossible to trigger with simulated input

## Save Frequently
Call `save_scene` after making significant changes. Unsaved changes can be lost if the editor reloads.

---

## Analysis & Debugging Tools
When something goes wrong, use these tools to investigate:

```
get_editor_errors          → check for script errors and runtime exceptions
get_output_log             → read print() output and warnings
analyze_scene_complexity   → node count, depth, type distribution, complexity rating
analyze_signal_flow        → signal graph with most-connected sources/targets
detect_circular_dependencies → find circular scene references
find_unused_resources      → dead assets (textures, audio, etc.)
get_performance_monitors   → FPS, memory, draw calls, physics stats
get_editor_performance     → quick summary (FPS, memory MB, node count)
```

## Testing & QA
```
run_test_scenario   → define and run automated test sequences (assert/wait/input/click steps)
assert_node_state   → verify node properties match expected values
assert_screen_text  → verify text is displayed on screen (searches Labels, Buttons, RichTextLabels)
compare_screenshots → visual regression testing (base64 PNG comparison)
run_stress_test     → random input fuzzing for a duration
get_test_report     → aggregated pass/fail report across all tests
```

## Cross-Scene Operations
```
cross_scene_set_property → find/replace text across all .tscn files
find_node_references     → find all files referencing a node name
find_script_references   → find all files using a script path
batch_set_property       → set a property on all nodes matching a type
find_nodes_by_type       → find nodes by class name
find_signal_connections  → audit all signal connections in the scene
get_scene_dependencies   → external resource dependency list
```

## Export
```
list_export_presets → configured export presets
export_project     → generate export command for a preset
get_export_info    → Godot path, templates location, version
```

---

## Building a New Game from Scratch

1. **Project setup** — `get_project_info`, `set_project_setting` (viewport, physics, renderer)
2. **Input mapping** — `set_input_action` for all player controls
3. **Main scene** — `create_scene`, set as main scene with `set_project_setting`
4. **Player** — create player scene with sprite, collision, script
5. **Level/World** — build environment (TileMap for 2D, meshes for 3D)
6. **Game logic** — scripts for enemies, items, scoring, UI
7. **Audio** — set up buses (Master → SFX, Music), add audio players
8. **Playtest** — `play_scene`, test with simulated input, fix bugs
9. **Polish** — animations, particles, shaders, themes
10. **Export** — `list_export_presets`, `export_project`

## Architecture

```
server/src/index.ts          → MCP server (stdio)
server/src/toolCatalog.ts    → 168 tool definitions
server/src/godotBridge.ts    → WebSocket client → Godot
addons/godot_mcp/plugin.gd  → Plugin entry
addons/godot_mcp/command_router.gd → Loads 20 handler modules
addons/godot_mcp/commands/   → 20 GDScript handlers + 3 utilities
```

## Build

```bash
npm --prefix server install
npm --prefix server run build
```

<!-- GODOT_MCP_SERVER_CONTEXT:START -->
# Godot MCP Server Context

- This Godot project includes a local MCP server and a Godot editor plugin addon for automation.
- MCP server folder: /test_godot/
- Addon plugin path: res://addons/godot_mcp/plugin.cfg
- Prefer calling MCP tools for scene, script, and runtime tasks before broad repository scans.
- Avoid scanning /test_godot/ recursively unless debugging the MCP server implementation itself.
- MCP entry id in .mcp.json: godot-mcp-server-local
- External agent skills are synced to .claude/skills.md
<!-- GODOT_MCP_SERVER_CONTEXT:END -->
