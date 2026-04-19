import { WebSocketServer } from "ws";
export class GodotWsServer {
    wss;
    clients = [];
    requestId = 0;
    pending = new Map();
    port;
    constructor(port = 6505) {
        this.port = port;
    }
    start() {
        this.wss = new WebSocketServer({ port: this.port });
        this.wss.on("connection", (ws) => {
            console.error(`[GodotWsServer] Client connected on port ${this.port}`);
            this.clients.push(ws);
            ws.on("message", (data) => {
                this.handleMessage(data.toString());
            });
            ws.on("close", () => {
                console.error(`[GodotWsServer] Client disconnected from port ${this.port}`);
                const idx = this.clients.indexOf(ws);
                if (idx >= 0) {
                    this.clients.splice(idx, 1);
                }
            });
            ws.on("error", (err) => {
                console.error(`[GodotWsServer] WebSocket error:`, err.message);
            });
        });
        console.error(`[GodotWsServer] WebSocket server listening on ws://127.0.0.1:${this.port}`);
    }
    stop() {
        this.rejectAllPending("Server shutting down");
        for (const client of this.clients) {
            client.close();
        }
        this.clients = [];
        this.wss?.close();
    }
    isConnected() {
        return this.clients.length > 0;
    }
    getClientCount() {
        return this.clients.length;
    }
    async sendCommand(command, payload, timeoutMs = 5000) {
        if (this.clients.length === 0) {
            throw new Error("No Godot clients connected");
        }
        // Use the first connected client
        const client = this.clients[0];
        const id = ++this.requestId;
        const request = {
            jsonrpc: "2.0",
            id,
            method: command,
            params: payload,
        };
        return new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
                this.pending.delete(id);
                reject(new Error(`Godot command timed out: ${command}`));
            }, timeoutMs);
            this.pending.set(id, { resolve, reject, timer });
            client.send(JSON.stringify(request), (err) => {
                if (err) {
                    const pendingRequest = this.pending.get(id);
                    if (pendingRequest) {
                        clearTimeout(pendingRequest.timer);
                        this.pending.delete(id);
                        pendingRequest.reject(new Error(`Failed to send command to Godot: ${err.message}`));
                    }
                }
            });
        });
    }
    handleMessage(rawMessage) {
        let parsed;
        try {
            parsed = JSON.parse(rawMessage);
        }
        catch {
            console.error("[GodotWsServer] Failed to parse message:", rawMessage);
            return;
        }
        if (typeof parsed.id !== "number") {
            return;
        }
        const pendingRequest = this.pending.get(parsed.id);
        if (!pendingRequest) {
            return;
        }
        clearTimeout(pendingRequest.timer);
        this.pending.delete(parsed.id);
        if (parsed.error) {
            const message = typeof parsed.error === "string"
                ? parsed.error
                : (parsed.error.message ?? "Godot returned an unknown error");
            pendingRequest.reject(new Error(message));
            return;
        }
        pendingRequest.resolve(parsed.result);
    }
    rejectAllPending(message) {
        for (const [id, pendingRequest] of this.pending) {
            clearTimeout(pendingRequest.timer);
            pendingRequest.reject(new Error(message));
            this.pending.delete(id);
        }
    }
}
