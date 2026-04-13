# Godot MCP Pro

**168 AI-powered tools for the Godot 4 Editor** — connect your AI assistant (Claude, Cursor, Cline, Copilot) to Godot and build games with natural language.

<p align="center">
<strong>168 Tools</strong> · <strong>25 Categories</strong> · <strong>Undo/Redo on all mutations</strong> · <strong>5-minute setup</strong>
</p>

## How It Works

Connect your AI assistant to Godot in under 5 minutes.

### 1. Install the Plugin
Copy `addons/godot_mcp/` into your Godot project. Enable it in **Project > Project Settings > Plugins**. The plugin starts a WebSocket server inside the editor automatically.

### 2. Build the MCP Server
```bash
cd server
npm install && npm run build
```
This compiles the TypeScript MCP server that bridges your AI client to the Godot plugin.

### 3. Start Building with AI
Add the server to your AI client's MCP config. Open Godot, and your AI assistant now has real-time access to 168 tools — creating scenes, editing scripts, simulating input, and analyzing your running game.

## MCP Client Config

### Claude Code / Claude Desktop
Add to `.claude/mcp.json`:
```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": ["/absolute/path/to/server/dist/index.js"]
    }
  }
}
```

### VS Code / Cursor
Add to `.vscode/mcp.json`:
```json
{
  "servers": {
    "godot": {
      "command": "node",
      "args": ["./server/dist/index.js"]
    }
  }
}
```

### Any stdio MCP Client
```bash
node server/dist/index.js
```
The server communicates over stdio (stdin/stdout) using the MCP protocol.

## Automated Setup (recommended)

```bash
cd server
npm run run
```

This will automatically:
- Build the MCP server
- Detect `project.godot` in parent folders (or `GODOT_PROJECT_PATH`)
- Sync addon to `addons/godot_mcp`
- Enable plugin in `project.godot`
- Create MCP config files
- Sync AI context files

## Tool Categories

| # | Category | Tools | Highlights |
|---|----------|-------|------------|
| 1 | **Project** | 7 | Settings read/write, UID conversion |
| 2 | **Scene** | 9 | Create, open, play, stop, instance, save |
| 3 | **Node** | 14 | Add/delete/rename/move with UndoRedo, signals, groups |
| 4 | **Script** | 8 | CRUD, attach, validate, search with line numbers |
| 5 | **Editor** | 10 | Screenshots, execute GDScript, error log, reload |
| 6 | **Input** | 7 | Keyboard, mouse, action simulation, sequences |
| 7 | **Runtime** | 19 | Game inspection, frame capture, recording/replay, UI |
| 8 | **Animation** | 6 | CRUD, tracks, keyframes |
| 9 | **AnimationTree** | 8 | State machine, transitions, blend tree |
| 10 | **TileMap** | 6 | Cell operations (TileMapLayer for Godot 4.3+) |
| 11 | **3D Scene** | 6 | Mesh primitives, .glb import, lighting presets, PBR |
| 12 | **Physics** | 6 | Auto 2D/3D collision, raycasts, layers |
| 13 | **Particles** | 5 | GPU particles + fire/smoke/rain/snow/sparks presets |
| 14 | **Navigation** | 6 | Region, agent, bake, pathfinding |
| 15 | **Audio** | 6 | Player (auto 2D/3D), bus effects chain |
| 16 | **Theme/UI** | 6 | StyleBoxFlat, color/constant/font overrides |
| 17 | **Shader** | 6 | Templates (canvas_item, spatial, particles, sky) |
| 18 | **Resource** | 6 | .tres CRUD, autoload management |
| 19 | **Batch** | 8 | Find by type, bulk set, dependency analysis |
| 20 | **Testing** | 6 | Automated scenarios, assertions, stress testing |
| 21 | **Analysis** | 4 | Scene complexity, signal flow, unused resources |
| 22 | **Profiling** | 2 | FPS, memory, physics, rendering monitors |
| 23 | **Export** | 3 | Preset listing, build commands |
| | **Total** | **168** | + 4 core connection tools |

## Key Features

### 🧠 Smart Type Parsing
No need to construct complex objects manually. Property values auto-convert:

```
"Vector2(100, 200)"  → Vector2(100, 200)
"Color(1, 0, 0)"    → Color(1, 0, 0)
"#ff0000"            → Color(1, 0, 0)
"Color.RED"          → Color(1, 0, 0)
"true"               → true
"42"                 → 42
```

### ♻️ Undo/Redo on All Mutations
Every `add_node`, `delete_node`, `update_property`, `rename_node`, and `move_node` goes through Godot's UndoRedo system. Your users can **Ctrl+Z** any AI action.

### 🎯 Auto 2D/3D Detection
Physics bodies, collision shapes, audio players, particles, and navigation nodes automatically detect whether the parent is 2D or 3D — the right type is created every time.

### 🔥 Built-in Presets
- **Lighting**: sun, indoor, dramatic, spot
- **Particles**: fire, smoke, rain, snow, sparks
- **Shaders**: canvas_item, spatial, particles, sky templates
- **Audio effects**: reverb, delay, compressor, EQ, distortion, chorus, phaser

## Quick Example

```
AI: godot_connect
AI: create_scene path="res://scenes/level.tscn" rootType="Node2D"
AI: add_node type="CharacterBody2D" name="Player" parentPath="."
AI: add_node type="Sprite2D" name="Sprite" parentPath="Player"
AI: update_property path="Player/Sprite" property="texture" value="res://icon.svg"
AI: setup_collision path="Player" shapeType="rectangle" size="Vector2(32, 32)"
AI: create_script path="res://scripts/player.gd" content="extends CharacterBody2D..."
AI: attach_script nodePath="Player" scriptPath="res://scripts/player.gd"
AI: save_scene
AI: play_scene
AI: simulate_key key="Space"
AI: get_game_screenshot
AI: stop_scene
```

## Architecture

```
server/src/
├── index.ts           TypeScript MCP server (stdio transport)
├── toolCatalog.ts     168 tool definitions with input schemas
└── godotBridge.ts     WebSocket client → Godot editor

addons/godot_mcp/
├── plugin.gd          Plugin entry point
├── websocket_server.gd Local WebSocket server (port 6505)
├── command_router.gd  Loads 20 handler modules, dispatches commands
└── commands/
    ├── base_commands.gd        Shared utilities (type parser, undo, I/O)
    ├── type_parser.gd          Smart string→Godot type conversion
    ├── undo_helper.gd          UndoRedo wrapper
    ├── core_commands.gd        Project, scene, node, script, editor (47 handlers)
    ├── editor_commands.gd      Screenshots, execute script (4)
    ├── input_commands.gd       Input simulation (7)
    ├── runtime_commands.gd     Game inspection & UI (15)
    ├── animation_commands.gd   Animation CRUD (6)
    ├── animation_tree_commands.gd  State machine & blend tree (8)
    ├── tilemap_commands.gd     Tile operations (6)
    ├── scene3d_commands.gd     3D scene building (6)
    ├── physics_commands.gd     Physics & collision (6)
    ├── particles_commands.gd   GPU particles + presets (5)
    ├── navigation_commands.gd  Nav regions & pathfinding (6)
    ├── audio_commands.gd       Audio players & bus effects (6)
    ├── theme_commands.gd       Theme & UI styling (6)
    ├── shader_commands.gd      Shader management (4)
    ├── resource_commands.gd    Resource & autoload (6)
    ├── batch_commands.gd       Batch operations (8)
    ├── testing_commands.gd     Testing & QA (5)
    ├── analysis_commands.gd    Code analysis (4)
    ├── profiling_commands.gd   Performance profiling (2)
    └── export_commands.gd      Export management (3)
```

## Bridge Protocol

JSON-RPC 2.0 over WebSocket (`ws://127.0.0.1:6505`):

```json
→ { "jsonrpc": "2.0", "id": 1, "method": "add_node", "params": { "type": "Sprite2D", "name": "Player" } }
← { "jsonrpc": "2.0", "id": 1, "result": { "tool": "add_node", "data": { "path": "/root/Main/Player" } } }
```

Override bridge URL: `GODOT_WS_URL=ws://127.0.0.1:6505 node server/dist/index.js`

## Requirements

- **Godot 4.2+** (4.3+ recommended for TileMapLayer)
- **Node.js 18+**
- Any MCP-compatible AI client

## AI Agent Context Files

When deployed to a Godot project, these context files help AI assistants understand the available tools:

| File | Purpose | Used by |
|------|---------|---------|
| `addons/godot_mcp/skills.md` | Complete 168-tool reference with workflows | All AI agents |
| `AGENTS.md` | Architecture + capability summary | Codex, Gemini, agents |
| `CLAUDE.md` | Quick reference + build commands | Claude Code |
| `.github/copilot-instructions.md` | Copilot-specific instructions | GitHub Copilot |

## References

- [MCP Protocol](https://modelcontextprotocol.io/docs)
- [TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [Godot Engine](https://godotengine.org/)
