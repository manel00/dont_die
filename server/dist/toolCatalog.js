export const TOOL_CATEGORIES = [
    {
        category: "project",
        tools: [
            { name: "get_project_info", description: "Get project metadata, autoloads, and version info." },
            { name: "get_filesystem_tree", description: "Get recursive file tree with optional filters." },
            { name: "search_files", description: "Search files by pattern or glob." },
            { name: "get_project_settings", description: "Read project settings by key array." },
            { name: "set_project_setting", description: "Set a project setting value." },
            { name: "uid_to_project_path", description: "Convert UID to res:// project path." },
            { name: "project_path_to_uid", description: "Convert res:// path to UID." }
        ]
    },
    {
        category: "scene",
        tools: [
            { name: "get_scene_tree", description: "Get live scene hierarchy from editor." },
            { name: "get_scene_file_content", description: "Read raw .tscn file content." },
            { name: "create_scene", description: "Create a new scene file with root node type." },
            { name: "open_scene", description: "Open a scene in the editor." },
            { name: "delete_scene", description: "Delete a scene file from disk." },
            { name: "add_scene_instance", description: "Instance a PackedScene as a child node." },
            { name: "play_scene", description: "Run scene from editor (F5)." },
            { name: "stop_scene", description: "Stop the running scene." },
            { name: "save_scene", description: "Save the current scene." }
        ]
    },
    {
        category: "node",
        tools: [
            { name: "add_node", description: "Add a node with type, name, and optional properties. Supports smart type parsing for Vector2, Color, etc." },
            { name: "delete_node", description: "Delete a node from the scene tree (with undo support)." },
            { name: "duplicate_node", description: "Duplicate a node and all its children." },
            { name: "move_node", description: "Reparent a node to a new parent (with undo support)." },
            { name: "update_property", description: "Update a node property with smart type parsing. Supports Vector2(x,y), Color(r,g,b), #hex, etc." },
            { name: "get_node_properties", description: "Get all properties of a node." },
            { name: "add_resource", description: "Create and attach a Resource (e.g. shape, material) to a node property." },
            { name: "set_anchor_preset", description: "Set anchor preset for a Control node." },
            { name: "rename_node", description: "Rename a node (with undo support)." },
            { name: "connect_signal", description: "Connect a signal from source node to target node method." },
            { name: "disconnect_signal", description: "Disconnect a signal between nodes." },
            { name: "get_node_groups", description: "Get groups a node belongs to." },
            { name: "set_node_groups", description: "Set groups for a node, replacing existing groups." },
            { name: "find_nodes_in_group", description: "Find all nodes in a specific group." }
        ]
    },
    {
        category: "script",
        tools: [
            { name: "list_scripts", description: "List all .gd/.cs/.gdshader scripts in the project." },
            { name: "read_script", description: "Read the content of a script file." },
            { name: "create_script", description: "Create a new script file with content." },
            { name: "edit_script", description: "Edit a script: full replace, find/replace, or batch replacements." },
            { name: "attach_script", description: "Attach a script to a node." },
            { name: "get_open_scripts", description: "List scripts currently open in the editor." },
            { name: "validate_script", description: "Validate GDScript syntax by compiling." },
            { name: "search_in_files", description: "Search text across project files with line numbers." }
        ]
    },
    {
        category: "editor",
        tools: [
            { name: "get_editor_errors", description: "Get editor errors and stack traces." },
            { name: "get_editor_screenshot", description: "Capture editor viewport as base64 PNG." },
            { name: "get_game_screenshot", description: "Capture running game viewport as base64 PNG." },
            { name: "compare_screenshots", description: "Compare two screenshots pixel by pixel with threshold." },
            { name: "execute_editor_script", description: "Execute arbitrary GDScript in editor context." },
            { name: "get_signals", description: "Inspect all signals and connections on a node." },
            { name: "reload_plugin", description: "Reload the MCP plugin." },
            { name: "reload_project", description: "Rescan the project filesystem." },
            { name: "get_output_log", description: "Get editor output log lines." },
            { name: "clear_output", description: "Clear the output log." }
        ]
    },
    {
        category: "input",
        tools: [
            { name: "simulate_key", description: "Simulate keyboard input with modifiers (shift, ctrl, alt)." },
            { name: "simulate_mouse_click", description: "Simulate mouse click at position." },
            { name: "simulate_mouse_move", description: "Simulate mouse movement to position." },
            { name: "simulate_action", description: "Simulate a Godot InputAction press/release." },
            { name: "simulate_sequence", description: "Run a multi-step input sequence with delays." },
            { name: "get_input_actions", description: "List all project input actions and their events." },
            { name: "set_input_action", description: "Create or update an input action mapping." }
        ]
    },
    {
        category: "runtime",
        tools: [
            { name: "get_game_scene_tree", description: "Get runtime scene hierarchy (alias for get_scene_tree)." },
            { name: "get_game_node_properties", description: "Read runtime node properties." },
            { name: "set_game_node_property", description: "Set a single runtime node property." },
            { name: "set_game_node_properties", description: "Set multiple runtime node properties." },
            { name: "execute_game_script", description: "Execute GDScript in the running game context." },
            { name: "capture_frames", description: "Capture multiple game frames as base64 PNGs." },
            { name: "monitor_properties", description: "Monitor property values over time intervals." },
            { name: "start_recording", description: "Start recording input events for replay." },
            { name: "stop_recording", description: "Stop recording and save captured input." },
            { name: "replay_recording", description: "Replay a previously recorded input session." },
            { name: "find_nodes_by_script", description: "Find all nodes using a specific script." },
            { name: "get_autoload", description: "Get autoload singleton details or list all." },
            { name: "batch_get_properties", description: "Read multiple node properties in a single call." },
            { name: "find_ui_elements", description: "Find all UI elements (buttons, labels, etc.) in the scene." },
            { name: "click_button_by_text", description: "Find and click a button by its text content." },
            { name: "wait_for_node", description: "Wait for a node to appear in the tree with timeout." },
            { name: "find_nearby_nodes", description: "Find nodes within a radius of a position." },
            { name: "navigate_to", description: "Set a node's position directly." },
            { name: "move_to", description: "Move a node to a target position." }
        ]
    },
    {
        category: "animation",
        tools: [
            { name: "list_animations", description: "List all animations in an AnimationPlayer." },
            { name: "create_animation", description: "Create a new animation with length and loop settings." },
            { name: "add_animation_track", description: "Add a track (value, position, rotation, bezier, method) to an animation." },
            { name: "set_animation_keyframe", description: "Insert a keyframe at a time position." },
            { name: "get_animation_info", description: "Get detailed animation info including all tracks and keyframes." },
            { name: "remove_animation", description: "Remove an animation from the player." }
        ]
    },
    {
        category: "animation_tree",
        tools: [
            { name: "create_animation_tree", description: "Create an AnimationTree with StateMachine or BlendTree root." },
            { name: "get_animation_tree_structure", description: "Inspect the full AnimationTree structure." },
            { name: "set_tree_parameter", description: "Set an AnimationTree parameter (conditions, blends)." },
            { name: "add_state_machine_state", description: "Add a state to the AnimationTree state machine." }
        ]
    },
    {
        category: "state_machine",
        tools: [
            { name: "remove_state_machine_state", description: "Remove a state from the state machine." },
            { name: "add_state_machine_transition", description: "Add a transition with conditions between states." },
            { name: "remove_state_machine_transition", description: "Remove a transition between states." }
        ]
    },
    {
        category: "blend_tree",
        tools: [
            { name: "set_blend_tree_node", description: "Add/configure a blend tree node (Add2, Blend2, TimeScale, OneShot)." }
        ]
    },
    {
        category: "tilemap",
        tools: [
            { name: "tilemap_set_cell", description: "Place a tile at a grid position." },
            { name: "tilemap_fill_rect", description: "Fill a rectangular region with tiles." },
            { name: "tilemap_get_cell", description: "Read tile data at a position." },
            { name: "tilemap_clear", description: "Clear all tiles from the tilemap." },
            { name: "tilemap_get_info", description: "Get tilemap metadata and tileset sources." },
            { name: "tilemap_get_used_cells", description: "List all used tile cells." }
        ]
    },
    {
        category: "scene3d",
        tools: [
            { name: "add_mesh_instance", description: "Add MeshInstance3D with primitive (box, sphere, capsule, cylinder, plane, torus) or import .glb/.gltf." },
            { name: "setup_camera_3d", description: "Create or configure Camera3D with FOV, projection, and transform." },
            { name: "setup_lighting", description: "Set up lighting with presets: sun, indoor, dramatic, spot." },
            { name: "setup_environment", description: "Configure WorldEnvironment with sky, fog, glow, SSAO, SSR, tonemap." },
            { name: "add_gridmap", description: "Create a GridMap node with optional MeshLibrary." },
            { name: "set_material_3d", description: "Set StandardMaterial3D properties: albedo, metallic, roughness, emission, texture." }
        ]
    },
    {
        category: "physics",
        tools: [
            { name: "setup_physics_body", description: "Configure CharacterBody or RigidBody properties (mass, gravity, floor angle)." },
            { name: "setup_collision", description: "Add collision shapes auto-detecting 2D/3D (box, sphere, capsule, cylinder)." },
            { name: "set_physics_layers", description: "Set collision layer and mask values." },
            { name: "get_physics_layers", description: "Get collision layer and mask values." },
            { name: "get_collision_info", description: "Get full collision shape audit for a node." },
            { name: "add_raycast", description: "Add RayCast2D or RayCast3D with target position and mask." }
        ]
    },
    {
        category: "particles",
        tools: [
            { name: "create_particles", description: "Create GPUParticles2D or GPUParticles3D with optional preset (fire, smoke, rain, snow, sparks)." },
            { name: "set_particle_material", description: "Configure ParticleProcessMaterial: direction, velocity, emission shape, scale." },
            { name: "set_particle_color_gradient", description: "Set particle color gradient ramp with offset/color stops." },
            { name: "apply_particle_preset", description: "Apply a built-in particle preset (fire, smoke, rain, snow, sparks)." },
            { name: "get_particle_info", description: "Get detailed particle system configuration." }
        ]
    },
    {
        category: "navigation",
        tools: [
            { name: "setup_navigation_region", description: "Set up NavigationRegion2D/3D with mesh parameters." },
            { name: "setup_navigation_agent", description: "Configure NavigationAgent with pathfinding and avoidance." },
            { name: "bake_navigation_mesh", description: "Bake navigation mesh or polygon." },
            { name: "set_navigation_layers", description: "Set navigation layers on a node." },
            { name: "get_navigation_info", description: "Get navigation diagnostics (region, agent, mesh info)." },
            { name: "get_navigation_path", description: "Calculate navigation path between two points." }
        ]
    },
    {
        category: "audio",
        tools: [
            { name: "add_audio_player", description: "Add AudioStreamPlayer/2D/3D auto-detecting parent type." },
            { name: "add_audio_bus", description: "Add an audio bus to the layout." },
            { name: "add_audio_bus_effect", description: "Add effect to bus (reverb, delay, compressor, EQ, distortion, chorus, etc.)." },
            { name: "set_audio_bus", description: "Configure audio bus properties (volume, solo, mute, send)." },
            { name: "get_audio_bus_layout", description: "Get full audio bus layout with effects." },
            { name: "get_audio_info", description: "Get audio player/node information." }
        ]
    },
    {
        category: "theme_ui",
        tools: [
            { name: "create_theme", description: "Create a new Theme resource and optionally apply to a node." },
            { name: "set_theme_color", description: "Set a theme color override on a Control node." },
            { name: "set_theme_constant", description: "Set a theme constant override." },
            { name: "set_theme_font_size", description: "Set a theme font size override." },
            { name: "set_theme_stylebox", description: "Set a StyleBoxFlat override with colors, borders, corners." },
            { name: "get_theme_info", description: "Inspect all theme overrides on a Control node." }
        ]
    },
    {
        category: "shader",
        tools: [
            { name: "create_shader", description: "Create a shader file from template (canvas_item, spatial, particles, sky)." },
            { name: "read_shader", description: "Read shader file content (alias for read_script)." },
            { name: "edit_shader", description: "Edit shader file content (alias for edit_script)." },
            { name: "assign_shader_material", description: "Create ShaderMaterial and assign to node with initial uniforms." },
            { name: "set_shader_param", description: "Set a shader uniform parameter value." },
            { name: "get_shader_params", description: "Read all shader parameters from a ShaderMaterial." }
        ]
    },
    {
        category: "resource",
        tools: [
            { name: "read_resource", description: "Read .tres resource properties." },
            { name: "edit_resource", description: "Modify resource properties and save." },
            { name: "create_resource", description: "Create a new .tres resource of any type." },
            { name: "get_resource_preview", description: "Get resource preview thumbnail." },
            { name: "add_autoload", description: "Register an autoload singleton." },
            { name: "remove_autoload", description: "Unregister an autoload singleton." }
        ]
    },
    {
        category: "batch_refactor",
        tools: [
            { name: "find_nodes_by_type", description: "Find all nodes matching a class type in the scene." },
            { name: "find_signal_connections", description: "Audit all signal connections in the scene tree." },
            { name: "batch_set_property", description: "Bulk set a property on all nodes matching a type filter." },
            { name: "find_node_references", description: "Search for node name references across project files." },
            { name: "get_scene_dependencies", description: "Get external resource dependencies of a scene." },
            { name: "cross_scene_set_property", description: "Find and replace text across all .tscn files." },
            { name: "find_script_references", description: "Find all files that reference a script path." },
            { name: "detect_circular_dependencies", description: "Detect circular scene dependencies." }
        ]
    },
    {
        category: "testing",
        tools: [
            { name: "run_test_scenario", description: "Run an automated test scenario with assert/wait/input/click steps." },
            { name: "assert_node_state", description: "Assert that a node property equals an expected value." },
            { name: "assert_screen_text", description: "Assert that text is visible on screen (searches Labels, Buttons, etc.)." },
            { name: "compare_screenshots", description: "Compare two base64 PNG screenshots pixel-by-pixel." },
            { name: "run_stress_test", description: "Run random input fuzzing for a duration." },
            { name: "get_test_report", description: "Get aggregated pass/fail test report." }
        ]
    },
    {
        category: "analysis",
        tools: [
            { name: "analyze_scene_complexity", description: "Analyze scene node count, depth, and type distribution." },
            { name: "analyze_signal_flow", description: "Map signal graph with most-connected sources and targets." },
            { name: "find_unused_resources", description: "Find unreferenced resources (textures, audio, etc.) in the project." },
            { name: "get_project_statistics", description: "Get full project statistics: scenes, scripts, assets, GDScript lines, autoloads." }
        ]
    },
    {
        category: "profiling",
        tools: [
            { name: "get_performance_monitors", description: "Get Godot performance monitors: FPS, memory, physics, rendering, navigation." },
            { name: "get_editor_performance", description: "Get quick editor performance summary (FPS, memory, draw calls)." }
        ]
    },
    {
        category: "export",
        tools: [
            { name: "list_export_presets", description: "List configured export presets from export_presets.cfg." },
            { name: "export_project", description: "Generate export command for a preset." },
            { name: "get_export_info", description: "Get export paths, templates location, and version info." }
        ]
    }
];
// Input schemas for each tool — provides proper parameter documentation to LLMs
export const TOOL_INPUT_SCHEMAS = {
    // Project
    get_project_info: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    get_filesystem_tree: { type: "object", properties: { root: { type: "string", description: "Root path (default: res://)" }, maxEntries: { type: "number", description: "Max files to return" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    search_files: { type: "object", properties: { query: { type: "string", description: "Search pattern" }, root: { type: "string" }, maxResults: { type: "number" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["query"], additionalProperties: false },
    get_project_settings: { type: "object", properties: { keys: { type: "array", items: { type: "string" }, description: "Setting keys to read" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    set_project_setting: { type: "object", properties: { key: { type: "string" }, value: {}, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["key", "value"], additionalProperties: false },
    uid_to_project_path: { type: "object", properties: { uid: { type: "string", description: "UID like uid://xxxxx" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["uid"], additionalProperties: false },
    project_path_to_uid: { type: "object", properties: { path: { type: "string", description: "res:// path" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    // Scene
    get_scene_tree: { type: "object", properties: { maxDepth: { type: "number", description: "Max tree depth (default: 8)" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    get_scene_file_content: { type: "object", properties: { path: { type: "string", description: "Scene file path (res://)" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    create_scene: { type: "object", properties: { path: { type: "string" }, rootType: { type: "string", description: "e.g. Node2D, Node3D, Control" }, rootName: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    open_scene: { type: "object", properties: { path: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    delete_scene: { type: "object", properties: { path: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    add_scene_instance: { type: "object", properties: { scenePath: { type: "string" }, parentPath: { type: "string" }, name: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["scenePath"], additionalProperties: false },
    play_scene: { type: "object", properties: { path: { type: "string", description: "Scene to play (empty = current)" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    stop_scene: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    save_scene: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    // Node
    add_node: { type: "object", properties: { parentPath: { type: "string" }, type: { type: "string", description: "Node class name" }, name: { type: "string" }, properties: { type: "object", description: "Initial properties with smart type parsing" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["type"], additionalProperties: false },
    delete_node: { type: "object", properties: { path: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    duplicate_node: { type: "object", properties: { path: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    move_node: { type: "object", properties: { path: { type: "string" }, newParentPath: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path", "newParentPath"], additionalProperties: false },
    update_property: { type: "object", properties: { path: { type: "string" }, property: { type: "string" }, value: { description: "Value with smart type parsing: Vector2(x,y), Color(r,g,b), #hex" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path", "property", "value"], additionalProperties: false },
    get_node_properties: { type: "object", properties: { path: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    add_resource: { type: "object", properties: { path: { type: "string" }, resourceType: { type: "string" }, property: { type: "string" }, properties: { type: "object" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path", "resourceType", "property"], additionalProperties: false },
    set_anchor_preset: { type: "object", properties: { path: { type: "string" }, preset: { type: "number" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path", "preset"], additionalProperties: false },
    rename_node: { type: "object", properties: { path: { type: "string" }, newName: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path", "newName"], additionalProperties: false },
    connect_signal: { type: "object", properties: { sourcePath: { type: "string" }, targetPath: { type: "string" }, signal: { type: "string" }, method: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["sourcePath", "targetPath", "signal", "method"], additionalProperties: false },
    disconnect_signal: { type: "object", properties: { sourcePath: { type: "string" }, targetPath: { type: "string" }, signal: { type: "string" }, method: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["sourcePath", "targetPath", "signal", "method"], additionalProperties: false },
    get_node_groups: { type: "object", properties: { path: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    set_node_groups: { type: "object", properties: { path: { type: "string" }, groups: { type: "array", items: { type: "string" } }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path", "groups"], additionalProperties: false },
    find_nodes_in_group: { type: "object", properties: { group: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["group"], additionalProperties: false },
    // Script
    list_scripts: { type: "object", properties: { root: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    read_script: { type: "object", properties: { path: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    create_script: { type: "object", properties: { path: { type: "string" }, content: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    edit_script: { type: "object", properties: { path: { type: "string" }, newContent: { type: "string" }, find: { type: "string" }, replace: { type: "string" }, replacements: { type: "array", items: { type: "object", properties: { search: { type: "string" }, replace: { type: "string" } } } }, insert_after: { type: "string" }, code: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    attach_script: { type: "object", properties: { nodePath: { type: "string" }, scriptPath: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["nodePath", "scriptPath"], additionalProperties: false },
    get_open_scripts: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    validate_script: { type: "object", properties: { path: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    search_in_files: { type: "object", properties: { query: { type: "string" }, root: { type: "string" }, maxResults: { type: "number" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["query"], additionalProperties: false },
    // Editor
    get_editor_errors: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    get_editor_screenshot: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    get_game_screenshot: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    compare_screenshots: { type: "object", properties: { imageA: { type: "string" }, imageB: { type: "string" }, threshold: { type: "number" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["imageA", "imageB"], additionalProperties: false },
    execute_editor_script: { type: "object", properties: { code: { type: "string", description: "GDScript code to execute" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["code"], additionalProperties: false },
    get_signals: { type: "object", properties: { path: { type: "string" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["path"], additionalProperties: false },
    reload_plugin: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    reload_project: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    get_output_log: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    clear_output: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    // Input — schemas kept brief, full params in additionalProperties
    simulate_key: { type: "object", properties: { key: { type: "string", description: "Key name: A-Z, Space, Enter, Escape, Up, etc." }, pressed: { type: "boolean" }, shift: { type: "boolean" }, ctrl: { type: "boolean" }, alt: { type: "boolean" }, autoRelease: { type: "boolean" }, duration: { type: "number" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["key"], additionalProperties: false },
    simulate_mouse_click: { type: "object", properties: { x: { type: "number" }, y: { type: "number" }, button: { type: "number" }, double: { type: "boolean" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["x", "y"], additionalProperties: false },
    simulate_mouse_move: { type: "object", properties: { x: { type: "number" }, y: { type: "number" }, relativeX: { type: "number" }, relativeY: { type: "number" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    simulate_action: { type: "object", properties: { action: { type: "string" }, pressed: { type: "boolean" }, strength: { type: "number" }, autoRelease: { type: "boolean" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["action"], additionalProperties: false },
    simulate_sequence: { type: "object", properties: { steps: { type: "array", items: { type: "object" }, description: "Array of {type, delay, ...} steps" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["steps"], additionalProperties: false },
    get_input_actions: { type: "object", properties: { timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, additionalProperties: false },
    set_input_action: { type: "object", properties: { action: { type: "string" }, key: { type: "string" }, deadzone: { type: "number" }, timeoutMs: { type: "number" }, autoConnect: { type: "boolean" } }, required: ["action"], additionalProperties: false },
};
// For tools not in the explicit schema, generate a permissive schema
for (const cat of TOOL_CATEGORIES) {
    for (const tool of cat.tools) {
        if (!TOOL_INPUT_SCHEMAS[tool.name]) {
            TOOL_INPUT_SCHEMAS[tool.name] = {
                type: "object",
                properties: {
                    timeoutMs: { type: "number", minimum: 100, default: 5000 },
                    autoConnect: { type: "boolean", default: true }
                },
                additionalProperties: true
            };
        }
    }
}
const seen = new Set();
export const ALL_COMPAT_TOOLS = TOOL_CATEGORIES.flatMap((category) => category.tools.filter((tool) => {
    if (seen.has(tool.name)) {
        return false;
    }
    seen.add(tool.name);
    return true;
}));
export const ALL_COMPAT_TOOL_NAMES = new Set(ALL_COMPAT_TOOLS.map((tool) => tool.name));
