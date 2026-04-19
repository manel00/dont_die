import { WebSocketServer, WebSocket } from "ws";

interface PendingRequest {
  resolve: (value: unknown) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
}

interface GodotResponse {
  jsonrpc?: string;
  id?: number;
  result?: unknown;
  error?:
    | string
    | {
        code?: number;
        message?: string;
        data?: unknown;
      };
}

export class GodotWsServer {
  private wss?: WebSocketServer;
  private clients: WebSocket[] = [];
  private requestId = 0;
  private readonly pending = new Map<number, PendingRequest>();
  private port: number;

  constructor(port: number = 6505) {
    this.port = port;
  }

  start(): void {
    this.wss = new WebSocketServer({ port: this.port });
    
    this.wss.on("connection", (ws: WebSocket) => {
      console.error(`[GodotWsServer] Client connected on port ${this.port}`);
      this.clients.push(ws);
      
      ws.on("message", (data: Buffer) => {
        this.handleMessage(data.toString());
      });
      
      ws.on("close", () => {
        console.error(`[GodotWsServer] Client disconnected from port ${this.port}`);
        const idx = this.clients.indexOf(ws);
        if (idx >= 0) {
          this.clients.splice(idx, 1);
        }
      });
      
      ws.on("error", (err: Error) => {
        console.error(`[GodotWsServer] WebSocket error:`, err.message);
      });
    });
    
    console.error(`[GodotWsServer] WebSocket server listening on ws://127.0.0.1:${this.port}`);
  }

  stop(): void {
    this.rejectAllPending("Server shutting down");
    for (const client of this.clients) {
      client.close();
    }
    this.clients = [];
    this.wss?.close();
  }

  isConnected(): boolean {
    return this.clients.length > 0;
  }

  getClientCount(): number {
    return this.clients.length;
  }

  async sendCommand(command: string, payload: unknown, timeoutMs = 5000): Promise<unknown> {
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

    return new Promise<unknown>((resolve, reject) => {
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

  private handleMessage(rawMessage: string): void {
    let parsed: GodotResponse;

    try {
      parsed = JSON.parse(rawMessage) as GodotResponse;
    } catch {
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
      const message =
        typeof parsed.error === "string"
          ? parsed.error
          : (parsed.error.message ?? "Godot returned an unknown error");
      pendingRequest.reject(new Error(message));
      return;
    }

    pendingRequest.resolve(parsed.result);
  }

  private rejectAllPending(message: string): void {
    for (const [id, pendingRequest] of this.pending) {
      clearTimeout(pendingRequest.timer);
      pendingRequest.reject(new Error(message));
      this.pending.delete(id);
    }
  }
}
