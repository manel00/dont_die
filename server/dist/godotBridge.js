import WebSocket from "ws";
export class GodotBridge {
    url;
    ws;
    connectPromise;
    requestId = 0;
    pending = new Map();
    reconnectTimer;
    heartbeatTimer;
    reconnectDelayMs = 1000;
    maxReconnectDelayMs = 60000;
    lastPongAt = 0;
    shouldReconnect = true;
    activeUrl;
    constructor(url) {
        this.url = url;
        this.activeUrl = url;
    }
    isConnected() {
        return this.ws?.readyState === WebSocket.OPEN;
    }
    async connect(timeoutMs = 2000) {
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
    async disconnect() {
        this.shouldReconnect = false;
        this.clearReconnectTimer();
        this.stopHeartbeat();
        if (!this.ws) {
            return;
        }
        const ws = this.ws;
        this.ws = undefined;
        this.rejectAllPending("Godot bridge disconnected");
        await new Promise((resolve) => {
            ws.once("close", () => resolve());
            ws.close();
            setTimeout(resolve, 500);
        });
    }
    getStatus() {
        return {
            connected: this.isConnected(),
            url: this.url,
            activeUrl: this.activeUrl,
            pendingRequests: this.pending.size,
            reconnectDelayMs: this.reconnectDelayMs
        };
    }
    async sendCommand(command, payload, timeoutMs = 5000) {
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
        return new Promise((resolve, reject) => {
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
    handleMessage(rawMessage) {
        let parsed;
        try {
            parsed = JSON.parse(rawMessage);
        }
        catch {
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
            const message = typeof parsed.error === "string"
                ? parsed.error
                : (parsed.error.message ?? "Godot bridge returned an unknown error");
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
    async connectWithFallback(timeoutMs) {
        const candidateUrls = this.getCandidateUrls();
        let lastError;
        for (const candidateUrl of candidateUrls) {
            try {
                const ws = await this.connectToUrl(candidateUrl, timeoutMs);
                this.setActiveSocket(ws, candidateUrl);
                this.reconnectDelayMs = 1000;
                return;
            }
            catch (error) {
                lastError =
                    error instanceof Error
                        ? error
                        : new Error(`Failed to connect to Godot bridge at ${candidateUrl}`);
            }
        }
        throw (lastError ??
            new Error(`Failed to connect to Godot bridge using candidates: ${candidateUrls.join(", ")}`));
    }
    connectToUrl(url, timeoutMs) {
        return new Promise((resolve, reject) => {
            const ws = new WebSocket(url);
            let settled = false;
            const finishError = (message) => {
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
            const onOpen = () => {
                if (settled) {
                    return;
                }
                settled = true;
                cleanup();
                resolve(ws);
            };
            const onError = (err) => {
                finishError(`Failed to connect to Godot bridge at ${url}: ${err.message}`);
            };
            const onClose = () => {
                finishError(`Connection closed while connecting to Godot bridge at ${url}`);
            };
            const cleanup = () => {
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
    setActiveSocket(ws, connectedUrl) {
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
    startHeartbeat() {
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
            }
            catch {
                this.ws.terminate();
            }
        }, 10000);
    }
    stopHeartbeat() {
        if (!this.heartbeatTimer) {
            return;
        }
        clearInterval(this.heartbeatTimer);
        this.heartbeatTimer = undefined;
    }
    scheduleReconnect() {
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
    clearReconnectTimer() {
        if (!this.reconnectTimer) {
            return;
        }
        clearTimeout(this.reconnectTimer);
        this.reconnectTimer = undefined;
    }
    getCandidateUrls() {
        const configuredUrl = process.env.GODOT_WS_URL ?? this.url;
        const scanEnabled = (process.env.GODOT_WS_SCAN_PORTS ?? "true").toLowerCase() !== "false";
        let parsedUrl;
        try {
            parsedUrl = new URL(configuredUrl);
        }
        catch {
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
        const urls = new Set([configuredUrl]);
        for (let port = start; port <= end; port += 1) {
            const next = new URL(configuredUrl);
            next.port = String(port);
            urls.add(next.toString());
        }
        return Array.from(urls);
    }
}
