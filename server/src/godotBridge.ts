import WebSocket from "ws";

export interface GodotBridgeStatus {
  connected: boolean;
  url: string;
  activeUrl: string;
  pendingRequests: number;
  reconnectDelayMs: number;
}

interface PendingRequest {
  resolve: (value: unknown) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
}

interface GodotResponse {
  jsonrpc?: string;
  id?: number;
  result?: unknown;
  method?: string;
  error?:
    | string
    | {
        code?: number;
        message?: string;
        data?: unknown;
      };
}

export class GodotBridge {
  private ws?: WebSocket;
  private connectPromise?: Promise<void>;
  private requestId = 0;
  private readonly pending = new Map<number, PendingRequest>();
  private reconnectTimer?: NodeJS.Timeout;
  private heartbeatTimer?: NodeJS.Timeout;
  private reconnectDelayMs = 1000;
  private readonly maxReconnectDelayMs = 60000;
  private lastPongAt = 0;
  private shouldReconnect = true;
  private activeUrl: string;

  constructor(private readonly url: string) {
    this.activeUrl = url;
  }

  isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  async connect(timeoutMs = 2000): Promise<void> {
    this.shouldReconnect = true;

    if (this.isConnected()) {
      return;
    }

    if (this.connectPromise) {
      return this.connectPromise;
    }

    this.connectPromise = this.connectWithFallback(timeoutMs).finally(() => {
      this.connectPromise = undefined;
    });

    return this.connectPromise;
  }

  async disconnect(): Promise<void> {
    this.shouldReconnect = false;
    this.clearReconnectTimer();
    this.stopHeartbeat();

    if (!this.ws) {
      return;
    }

    const ws = this.ws;
    this.ws = undefined;
    this.rejectAllPending("Godot bridge disconnected");

    await new Promise<void>((resolve) => {
      ws.once("close", () => resolve());
      ws.close();
      setTimeout(resolve, 500);
    });
  }

  getStatus(): GodotBridgeStatus {
    return {
      connected: this.isConnected(),
      url: this.url,
      activeUrl: this.activeUrl,
      pendingRequests: this.pending.size,
      reconnectDelayMs: this.reconnectDelayMs
    };
  }

  async sendCommand(command: string, payload: unknown, timeoutMs = 5000): Promise<unknown> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("Godot bridge is not connected");
    }

    const id = ++this.requestId;
    const request = {
      jsonrpc: "2.0",
      id,
      method: command,
      params: payload,
      command,
      payload
    };

    return new Promise<unknown>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Godot command timed out: ${command}`));
      }, timeoutMs);

      this.pending.set(id, { resolve, reject, timer });

      this.ws?.send(JSON.stringify(request), (err) => {
        if (!err) {
          return;
        }
        const pendingRequest = this.pending.get(id);
        if (!pendingRequest) {
          return;
        }
        clearTimeout(pendingRequest.timer);
        this.pending.delete(id);
        pendingRequest.reject(new Error(`Failed to send command to Godot: ${err.message}`));
      });
    });
  }

  private handleMessage(rawMessage: string): void {
    let parsed: GodotResponse;

    try {
      parsed = JSON.parse(rawMessage) as GodotResponse;
    } catch {
      return;
    }

    if (parsed.method === "ping") {
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
          : (parsed.error.message ?? "Godot bridge returned an unknown error");
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

  private async connectWithFallback(timeoutMs: number): Promise<void> {
    const candidateUrls = this.getCandidateUrls();
    let lastError: Error | undefined;

    for (const candidateUrl of candidateUrls) {
      try {
        const ws = await this.connectToUrl(candidateUrl, timeoutMs);
        this.setActiveSocket(ws, candidateUrl);
        this.reconnectDelayMs = 1000;
        return;
      } catch (error) {
        lastError =
          error instanceof Error
            ? error
            : new Error(`Failed to connect to Godot bridge at ${candidateUrl}`);
      }
    }

    throw (
      lastError ??
      new Error(`Failed to connect to Godot bridge using candidates: ${candidateUrls.join(", ")}`)
    );
  }

  private connectToUrl(url: string, timeoutMs: number): Promise<WebSocket> {
    return new Promise<WebSocket>((resolve, reject) => {
      const ws = new WebSocket(url);
      let settled = false;

      const finishError = (message: string): void => {
        if (settled) {
          return;
        }
        settled = true;
        cleanup();
        ws.terminate();
        reject(new Error(message));
      };

      const timeout = setTimeout(() => {
        finishError(`Timed out connecting to Godot bridge at ${url}`);
      }, timeoutMs);

      const onOpen = (): void => {
        if (settled) {
          return;
        }
        settled = true;
        cleanup();
        resolve(ws);
      };

      const onError = (err: Error): void => {
        finishError(`Failed to connect to Godot bridge at ${url}: ${err.message}`);
      };

      const onClose = (): void => {
        finishError(`Connection closed while connecting to Godot bridge at ${url}`);
      };

      const cleanup = (): void => {
        clearTimeout(timeout);
        ws.off("open", onOpen);
        ws.off("error", onError);
        ws.off("close", onClose);
      };

      ws.on("open", onOpen);
      ws.on("error", onError);
      ws.on("close", onClose);
    });
  }

  private setActiveSocket(ws: WebSocket, connectedUrl: string): void {
    this.clearReconnectTimer();
    this.stopHeartbeat();

    this.ws = ws;
    this.activeUrl = connectedUrl;
    this.lastPongAt = Date.now();

    ws.on("message", (data) => {
      this.handleMessage(data.toString());
    });

    ws.on("pong", () => {
      this.lastPongAt = Date.now();
    });

    ws.on("close", () => {
      if (this.ws === ws) {
        this.ws = undefined;
      }
      this.stopHeartbeat();
      this.rejectAllPending("Godot bridge connection closed");

      if (this.shouldReconnect) {
        this.scheduleReconnect();
      }
    });

    ws.on("error", (err) => {
      this.rejectAllPending(`Godot bridge error: ${err.message}`);
    });

    this.startHeartbeat();
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();

    this.heartbeatTimer = setInterval(() => {
      if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
        return;
      }

      const pongAgeMs = Date.now() - this.lastPongAt;
      if (pongAgeMs > 25000) {
        this.ws.terminate();
        return;
      }

      try {
        this.ws.ping();
      } catch {
        this.ws.terminate();
      }
    }, 10000);
  }

  private stopHeartbeat(): void {
    if (!this.heartbeatTimer) {
      return;
    }
    clearInterval(this.heartbeatTimer);
    this.heartbeatTimer = undefined;
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer || this.connectPromise || this.isConnected() || !this.shouldReconnect) {
      return;
    }

    const delayMs = this.reconnectDelayMs;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = undefined;
      this.connect(2000).catch(() => {
        if (this.shouldReconnect) {
          this.scheduleReconnect();
        }
      });
    }, delayMs);

    this.reconnectDelayMs = Math.min(this.reconnectDelayMs * 2, this.maxReconnectDelayMs);
  }

  private clearReconnectTimer(): void {
    if (!this.reconnectTimer) {
      return;
    }
    clearTimeout(this.reconnectTimer);
    this.reconnectTimer = undefined;
  }

  private getCandidateUrls(): string[] {
    const configuredUrl = process.env.GODOT_WS_URL ?? this.url;
    const scanEnabled = (process.env.GODOT_WS_SCAN_PORTS ?? "true").toLowerCase() !== "false";

    let parsedUrl: URL;
    try {
      parsedUrl = new URL(configuredUrl);
    } catch {
      return [configuredUrl];
    }

    if (!scanEnabled) {
      return [configuredUrl];
    }

    const hostname = parsedUrl.hostname.toLowerCase();
    if (hostname !== "127.0.0.1" && hostname !== "localhost") {
      return [configuredUrl];
    }

    const start = Number(process.env.GODOT_WS_SCAN_START ?? 6505);
    const end = Number(process.env.GODOT_WS_SCAN_END ?? 6509);
    if (!Number.isFinite(start) || !Number.isFinite(end) || start > end) {
      return [configuredUrl];
    }

    const urls = new Set<string>([configuredUrl]);
    for (let port = start; port <= end; port += 1) {
      const next = new URL(configuredUrl);
      next.port = String(port);
      urls.add(next.toString());
    }

    return Array.from(urls);
  }
}
