import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverRoot = path.resolve(__dirname, "..");
const workspaceRoot = path.resolve(serverRoot, "..");
const repoName = path.basename(workspaceRoot);

const LEGACY_AUTOLOAD_NAME = "McpBridge";
const PLUGIN_CFG_PATH = "res://addons/godot_mcp/plugin.cfg";
const SOURCE_ADDON_DIR = path.join(workspaceRoot, "addons", "godot_mcp");
const SOURCE_SKILLS_FILE = path.join(SOURCE_ADDON_DIR, "skills.md");
const HOOK_SENTINEL = "godot-mcp-bridge-auto-setup";

function log(message) {
  console.log(`[setup] ${message}`);
}

function toPosix(inputPath) {
  return inputPath.split(path.sep).join("/");
}

function pathExists(targetPath) {
  try {
    fs.accessSync(targetPath);
    return true;
  } catch {
    return false;
  }
}

function fileExists(filePath) {
  try {
    return fs.statSync(filePath).isFile();
  } catch {
    return false;
  }
}

function dirExists(dirPath) {
  try {
    return fs.statSync(dirPath).isDirectory();
  } catch {
    return false;
  }
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function findGodotProjectRoot(startDir) {
  if (process.env.GODOT_PROJECT_PATH) {
    const explicit = path.resolve(process.env.GODOT_PROJECT_PATH);
    if (fileExists(path.join(explicit, "project.godot"))) {
      return explicit;
    }
    log(`GODOT_PROJECT_PATH found but project.godot missing: ${explicit}`);
  }

  let current = path.resolve(startDir);
  for (let i = 0; i < 8; i += 1) {
    if (fileExists(path.join(current, "project.godot"))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) {
      break;
    }
    current = parent;
  }

  return null;
}

function copyFileIfChanged(source, target) {
  const sourceContent = fs.readFileSync(source, "utf8");
  const targetContent = fileExists(target) ? fs.readFileSync(target, "utf8") : null;

  if (sourceContent !== targetContent) {
    ensureDir(path.dirname(target));
    fs.writeFileSync(target, sourceContent, "utf8");
  }
}

function syncDirectory(sourceDir, targetDir) {
  if (!dirExists(sourceDir)) {
    throw new Error(`Source directory missing: ${sourceDir}`);
  }

  ensureDir(targetDir);
  const entries = fs.readdirSync(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      syncDirectory(sourcePath, targetPath);
    } else if (entry.isFile()) {
      copyFileIfChanged(sourcePath, targetPath);
    }
  }
}

function upsertBlock(filePath, title, body) {
  const startMarker = "<!-- GODOT_MCP_SERVER_CONTEXT:START -->";
  const endMarker = "<!-- GODOT_MCP_SERVER_CONTEXT:END -->";
  const block = `${startMarker}\n${title}\n\n${body}\n${endMarker}`;

  if (!fileExists(filePath)) {
    ensureDir(path.dirname(filePath));
    fs.writeFileSync(filePath, `${block}\n`, "utf8");
    return;
  }

  const original = fs.readFileSync(filePath, "utf8");
  if (original.includes(startMarker) && original.includes(endMarker)) {
    const updated = original.replace(new RegExp(`${startMarker}[\\s\\S]*?${endMarker}`, "m"), block);
    fs.writeFileSync(filePath, updated, "utf8");
    return;
  }

  const separator = original.endsWith("\n") ? "" : "\n";
  fs.writeFileSync(filePath, `${original}${separator}\n${block}\n`, "utf8");
}

function ensureCursorIgnore(projectRoot) {
  const filePath = path.join(projectRoot, ".cursorignore");
  const desired = [`/${repoName}/`, `/${repoName}/**`];

  if (!fileExists(filePath)) {
    fs.writeFileSync(filePath, `${desired.join("\n")}\n`, "utf8");
    return;
  }

  const existing = fs.readFileSync(filePath, "utf8").split(/\r?\n/);
  const merged = [...existing];
  for (const line of desired) {
    if (!existing.includes(line)) {
      merged.push(line);
    }
  }
  fs.writeFileSync(filePath, `${merged.filter(Boolean).join("\n")}\n`, "utf8");
}

function ensureMcpConfig(projectRoot) {
  const mcpPath = path.join(projectRoot, ".mcp.json");
  const distPath = path.join(serverRoot, "dist", "index.js");
  let relativeDist = toPosix(path.relative(projectRoot, distPath));
  if (!relativeDist.startsWith(".")) {
    relativeDist = `./${relativeDist}`;
  }

  const desiredEntry = {
    command: "node",
    args: [relativeDist],
    env: {
      GODOT_WS_URL: "ws://127.0.0.1:6505"
    }
  };

  let content = { mcpServers: {} };
  if (fileExists(mcpPath)) {
    try {
      content = JSON.parse(fs.readFileSync(mcpPath, "utf8"));
    } catch {
      log("Existing .mcp.json is invalid JSON, skipping update.");
      return;
    }
  }

  if (!content.mcpServers || typeof content.mcpServers !== "object") {
    content.mcpServers = {};
  }

  content.mcpServers["godot-mcp-server-local"] = desiredEntry;
  fs.writeFileSync(mcpPath, `${JSON.stringify(content, null, 2)}\n`, "utf8");
}

function ensureAddonPlugin(projectRoot) {
  const targetAddonDir = path.join(projectRoot, "addons", "godot_mcp");
  syncDirectory(SOURCE_ADDON_DIR, targetAddonDir);
  log(`Addon synced to ${toPosix(path.relative(projectRoot, targetAddonDir))}`);
}

function parsePackedStringArray(rawLine) {
  const line = rawLine ?? "";
  const match = line.match(/PackedStringArray\((.*)\)/);
  if (!match) {
    return [];
  }

  const values = [];
  const regex = /"([^"\\]*(?:\\.[^"\\]*)*)"/g;
  let item = regex.exec(match[1]);
  while (item) {
    values.push(item[1].replace(/\\"/g, '"'));
    item = regex.exec(match[1]);
  }
  return values;
}

function formatPackedStringArray(values) {
  const serialized = values.map((value) => `"${value.replace(/"/g, '\\"')}"`).join(", ");
  return `PackedStringArray(${serialized})`;
}

function ensureEditorPluginEnabled(projectRoot) {
  const projectFile = path.join(projectRoot, "project.godot");
  if (!fileExists(projectFile)) {
    throw new Error(`project.godot not found at ${projectRoot}`);
  }

  const original = fs.readFileSync(projectFile, "utf8");
  const newline = original.includes("\r\n") ? "\r\n" : "\n";
  const lines = original.split(/\r?\n/);
  const enabledLinePrefix = "enabled=";
  let sectionStart = lines.findIndex((line) => line.trim() === "[editor_plugins]");

  if (sectionStart === -1) {
    const suffix = lines.length > 0 && lines[lines.length - 1] === "" ? [] : [""];
    const enabledValue = formatPackedStringArray([PLUGIN_CFG_PATH]);
    const updated = [...lines, ...suffix, "[editor_plugins]", `${enabledLinePrefix}${enabledValue}`].join(newline);
    fs.writeFileSync(projectFile, `${updated}${newline}`, "utf8");
    log("Editor plugin section created in project.godot.");
    return;
  }

  let sectionEnd = lines.length;
  for (let i = sectionStart + 1; i < lines.length; i += 1) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
      sectionEnd = i;
      break;
    }
  }

  let foundEnabled = false;
  for (let i = sectionStart + 1; i < sectionEnd; i += 1) {
    if (lines[i].startsWith(enabledLinePrefix)) {
      const values = parsePackedStringArray(lines[i].slice(enabledLinePrefix.length));
      if (!values.includes(PLUGIN_CFG_PATH)) {
        values.push(PLUGIN_CFG_PATH);
      }
      lines[i] = `${enabledLinePrefix}${formatPackedStringArray(values)}`;
      foundEnabled = true;
      break;
    }
  }

  if (!foundEnabled) {
    lines.splice(sectionEnd, 0, `${enabledLinePrefix}${formatPackedStringArray([PLUGIN_CFG_PATH])}`);
    log("Plugin entry added to project.godot.");
  } else {
    log("Plugin entry already present and refreshed.");
  }

  fs.writeFileSync(projectFile, `${lines.join(newline)}${newline}`, "utf8");
}

function removeLegacyAutoload(projectRoot) {
  const projectFile = path.join(projectRoot, "project.godot");
  if (!fileExists(projectFile)) {
    return;
  }

  const original = fs.readFileSync(projectFile, "utf8");
  const newline = original.includes("\r\n") ? "\r\n" : "\n";
  const lines = original.split(/\r?\n/);
  const sectionStart = lines.findIndex((line) => line.trim() === "[autoload]");
  if (sectionStart === -1) {
    return;
  }

  let sectionEnd = lines.length;
  for (let i = sectionStart + 1; i < lines.length; i += 1) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
      sectionEnd = i;
      break;
    }
  }

  let changed = false;
  for (let i = sectionEnd - 1; i > sectionStart; i -= 1) {
    const line = lines[i];
    if (line.startsWith(`${LEGACY_AUTOLOAD_NAME}=`)) {
      lines.splice(i, 1);
      changed = true;
    }
  }

  if (changed) {
    fs.writeFileSync(projectFile, `${lines.join(newline)}${newline}`, "utf8");
    log("Removed legacy McpBridge autoload to avoid WebSocket port conflicts.");
  }
}

function upsertSkillsFile(projectRoot) {
  if (!fileExists(SOURCE_SKILLS_FILE)) {
    return;
  }

  const targetDir = path.join(projectRoot, ".claude");
  const targetFile = path.join(targetDir, "skills.md");
  const title = "# Godot MCP Bridge - Skills for AI Assistants";
  const sourceBody = fs.readFileSync(SOURCE_SKILLS_FILE, "utf8").trim();
  upsertBlock(targetFile, title, sourceBody);
}

function ensureAgentContext(projectRoot) {
  const pathFromProject = toPosix(path.relative(projectRoot, workspaceRoot));
  const scanHint = pathFromProject ? `/${pathFromProject}/` : `/${repoName}/`;

  const title = "# Godot MCP Server Context";
  const body = [
    "- This Godot project includes a local MCP server and a Godot editor plugin addon for automation.",
    `- MCP server folder: ${scanHint}`,
    "- Addon plugin path: res://addons/godot_mcp/plugin.cfg",
    "- Prefer calling MCP tools for scene, script, and runtime tasks before broad repository scans.",
    `- Avoid scanning ${scanHint} recursively unless debugging the MCP server implementation itself.`,
    "- MCP entry id in .mcp.json: godot-mcp-server-local",
    "- External agent skills are synced to .claude/skills.md"
  ].join("\n");

  upsertBlock(path.join(projectRoot, "AGENTS.md"), title, body);
  upsertBlock(path.join(projectRoot, "CLAUDE.md"), title, body);
  upsertBlock(path.join(projectRoot, ".github", "copilot-instructions.md"), title, body);
}

function ensureGitHook(hookName, hookBody) {
  const hooksDir = path.join(workspaceRoot, ".git", "hooks");
  if (!dirExists(hooksDir)) {
    return;
  }

  const hookPath = path.join(hooksDir, hookName);
  let content = "";
  if (pathExists(hookPath)) {
    content = fs.readFileSync(hookPath, "utf8");
  }

  if (content.includes(HOOK_SENTINEL)) {
    return;
  }

  let next = content;
  if (!next.startsWith("#!")) {
    next = "#!/bin/sh\n" + next;
  }

  if (!next.endsWith("\n")) {
    next += "\n";
  }

  next += `\n# ${HOOK_SENTINEL}\n${hookBody}\n# end ${HOOK_SENTINEL}\n`;
  fs.writeFileSync(hookPath, next, "utf8");
  try {
    fs.chmodSync(hookPath, 0o755);
  } catch {
    // Ignore chmod failures on Windows.
  }
  log(`Git hook installed: ${hookName}`);
}

function ensureGitHooks() {
  const hookBody = [
    "if [ -f server/package.json ]; then",
    "  npm --prefix server run setup --silent >/dev/null 2>&1 || npm --prefix server run setup >/dev/null 2>&1 || true",
    "fi"
  ].join("\n");

  ensureGitHook("post-merge", hookBody);
  ensureGitHook("post-checkout", hookBody);
}

function setup() {
  ensureGitHooks();

  const projectRoot = findGodotProjectRoot(workspaceRoot);
  if (!projectRoot) {
    log("No parent Godot project found (project.godot). Skipping project setup.");
    log("Tip: clone this repo inside a Godot project folder, or set GODOT_PROJECT_PATH.");
    return;
  }

  log(`Godot project detected: ${projectRoot}`);

  ensureAddonPlugin(projectRoot);
  ensureEditorPluginEnabled(projectRoot);
  removeLegacyAutoload(projectRoot);
  ensureMcpConfig(projectRoot);
  ensureCursorIgnore(projectRoot);
  ensureAgentContext(projectRoot);
  upsertSkillsFile(projectRoot);

  log("Setup complete. You can now run npm --prefix server run run.");
}

try {
  setup();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[setup] Failed: ${message}`);
  process.exitCode = 1;
}
