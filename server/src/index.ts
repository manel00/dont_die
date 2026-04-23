import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError
} from "@modelcontextprotocol/sdk/types.js";
import { GodotWsServer } from "./wsServer.js";
import { ALL_COMPAT_TOOLS, ALL_COMPAT_TOOL_NAMES, TOOL_INPUT_SCHEMAS } from "./toolCatalog.js";

const isLiteMode = process.argv.includes("--lite");

const server = new Server(
  {
    name: "godot-mcp-bridge",
    version: "1.0.0"
  },
  {
    capabilities: {
      tools: {}
    }
  }
);

const godotPort = parseInt(process.env.GODOT_WS_PORT ?? process.env.GODOT_PORT ?? "6505", 10);
const godot = new GodotWsServer(godotPort);
godot.start();

const CORE_TOOLS = [
  {
    name: "godot_connect",
    description: "Connect to a running Godot bridge over WebSocket.",
    inputSchema: {
      type: "object" as const,
      properties: {
        timeoutMs: { type: "number", minimum: 100, default: 2000, description: "Connection timeout in milliseconds" }
      },
      additionalProperties: false
    }
  },
  {
    name: "godot_status",
    description: "Return current connection status to the Godot bridge.",
    inputSchema: {
      type: "object" as const,
      properties: {},
      additionalProperties: false
    }
  },
  {
    name: "godot_command",
    description:
      "Send a custom command to Godot bridge. This is a low-level escape hatch when a named tool is not enough.",
    inputSchema: {
      type: "object" as const,
      properties: {
        command: { type: "string", description: "The command name to execute" },
        payload: { type: "object", additionalProperties: true, description: "Command payload" },
        timeoutMs: { type: "number", minimum: 100, default: 5000 },
        autoConnect: { type: "boolean", default: true }
      },
      required: ["command"],
      additionalProperties: false
    }
  },
  {
    name: "godot_disconnect",
    description: "Disconnect from the Godot bridge.",
    inputSchema: {
      type: "object" as const,
      properties: {},
      additionalProperties: false
    }
  }
];

// Lite mode core categories
const LITE_CATEGORIES = new Set([
  "project", "scene", "node", "script", "editor", "input", "runtime"
]);

function getBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function getNumber(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function toCompatInputPayload(rawArgs: Record<string, unknown>): Record<string, unknown> {
  const payload: Record<string, unknown> = { ...rawArgs };
  delete payload.timeoutMs;
  delete payload.autoConnect;
  return payload;
}

function getToolsToRegister() {
  if (isLiteMode) {
    return ALL_COMPAT_TOOLS.filter((tool) => {
      // In lite mode, only register tools from core categories
      for (const cat of LITE_CATEGORIES) {
        if (TOOL_INPUT_SCHEMAS[tool.name]) return true; // Keep tools with schemas
      }
      return false;
    }).slice(0, 76); // Lite mode: max 76 tools
  }
  return ALL_COMPAT_TOOLS;
}

server.setRequestHandler(ListToolsRequestSchema, async () => {
  const compatTools = getToolsToRegister();
  return {
    tools: [
      ...CORE_TOOLS,
      ...compatTools.map((tool) => ({
        name: tool.name,
        description: tool.description,
        inputSchema: TOOL_INPUT_SCHEMAS[tool.name] ?? {
          type: "object" as const,
          properties: {
            timeoutMs: { type: "number", minimum: 100, default: 5000 },
            autoConnect: { type: "boolean", default: true }
          },
          additionalProperties: true
        }
      }))
    ]
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const toolName = request.params.name;
  const args = (request.params.arguments ?? {}) as Record<string, unknown>;

  try {
    if (toolName === "godot_connect") {
      return {
        content: [{ type: "text", text: `WebSocket server running on ws://127.0.0.1:${godotPort} (${godot.getClientCount()} clients connected)` }]
      };
    }

    if (toolName === "godot_status") {
      return {
        content: [{ type: "text", text: JSON.stringify({ connected: godot.isConnected(), port: godotPort, clients: godot.getClientCount() }, null, 2) }]
      };
    }

    if (toolName === "godot_command") {
      if (typeof args.command !== "string" || args.command.length === 0) {
        throw new Error("Missing required argument: command");
      }

      const payload =
        typeof args.payload === "object" && args.payload !== null
          ? (args.payload as Record<string, unknown>)
          : {};

      const result = await godot.sendCommand(args.command, payload, getNumber(args.timeoutMs, 5000));

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({ ok: true, command: args.command, result }, null, 2)
          }
        ]
      };
    }

    if (ALL_COMPAT_TOOL_NAMES.has(toolName)) {
      const payload = toCompatInputPayload(args);
      const result = await godot.sendCommand(toolName, payload, getNumber(args.timeoutMs, 10000));

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({ ok: true, tool: toolName, result }, null, 2)
          }
        ]
      };
    }

    if (toolName === "godot_disconnect") {
      godot.stop();
      return {
        content: [{ type: "text", text: "WebSocket server stopped" }]
      };
    }

    throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${toolName}`);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return {
      isError: true,
      content: [{ type: "text", text: message }]
    };
  }
});

async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  const mode = isLiteMode ? "LITE" : "FULL";
  const toolCount = CORE_TOOLS.length + (isLiteMode ? 76 : ALL_COMPAT_TOOLS.length);
  console.error(`godot-mcp-bridge v1.0.0 is running on stdio (${mode} mode, ${toolCount} tools)`);
}

main().catch((error) => {
  console.error("Failed to start godot-mcp-bridge:", error);
  process.exit(1);
});
