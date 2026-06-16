/**
 * WebSocket service for real-time location updates
 */

export interface LocationUpdate {
  type: "location_update";
  child_id: number;
  child_name: string;
  latitude: number;
  longitude: number;
  battery_level: number | null;
  is_in_safe_zone: boolean;
  timestamp: string;
}

export interface AlertUpdate {
  type: "alert";
  alert_id: number;
  child_id: number;
  child_name: string;
  alert_type: string;
  message: string;
  latitude: number;
  longitude: number;
  created_at: string;
}

export interface ConnectionStatus {
  type: "connection_established" | "error";
  message?: string;
}

export type WebSocketMessage = LocationUpdate | AlertUpdate | ConnectionStatus;

type MessageHandler = (message: WebSocketMessage) => void;
type ConnectionHandler = (connected: boolean) => void;

class WebSocketService {
  private socket: WebSocket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private reconnectDelay = 3000;
  private pingInterval: ReturnType<typeof setInterval> | null = null;
  private messageHandlers: Set<MessageHandler> = new Set();
  private connectionHandlers: Set<ConnectionHandler> = new Set();
  private isConnecting = false;
  private token: string | null = null;
  private subscribedChildren: Set<number> = new Set();

  private getWebSocketUrl(): string {
    if (typeof window === "undefined") return "";
    
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const host = window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1"
      ? "localhost:8000"
      : window.location.host;
    
    return `${protocol}//${host}/ws/location/`;
  }

  connect(authToken?: string): void {
    if (this.socket?.readyState === WebSocket.OPEN || this.isConnecting) {
      return;
    }

    this.token = authToken || localStorage.getItem("auth_token");
    if (!this.token) {
      console.error("[WS] No auth token available");
      return;
    }

    this.isConnecting = true;
    const url = `${this.getWebSocketUrl()}?token=${this.token}`;
    
    console.log("[WS] Connecting to:", url.replace(this.token, "***"));

    try {
      this.socket = new WebSocket(url);

      this.socket.onopen = () => {
        console.log("[WS] Connected");
        this.isConnecting = false;
        this.reconnectAttempts = 0;
        this.notifyConnectionHandlers(true);
        this.startPingInterval();
        
        // Re-subscribe to children
        this.subscribedChildren.forEach((childId) => {
          this.subscribeToChild(childId);
        });
      };

      this.socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data) as WebSocketMessage;
          console.log("[WS] Message:", data.type);
          this.notifyMessageHandlers(data);
        } catch (error) {
          console.error("[WS] Error parsing message:", error);
        }
      };

      this.socket.onerror = (error) => {
        console.error("[WS] Error:", error);
        this.isConnecting = false;
      };

      this.socket.onclose = (event) => {
        console.log("[WS] Closed:", event.code, event.reason);
        this.isConnecting = false;
        this.stopPingInterval();
        this.notifyConnectionHandlers(false);
        this.scheduleReconnect();
      };
    } catch (error) {
      console.error("[WS] Failed to create socket:", error);
      this.isConnecting = false;
      this.scheduleReconnect();
    }
  }

  disconnect(): void {
    this.reconnectAttempts = this.maxReconnectAttempts; // Prevent reconnection
    this.stopPingInterval();
    
    if (this.socket) {
      this.socket.close(1000, "Client disconnected");
      this.socket = null;
    }
    
    this.subscribedChildren.clear();
    this.notifyConnectionHandlers(false);
  }

  subscribeToChild(childId: number): void {
    this.subscribedChildren.add(childId);
    
    if (this.socket?.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify({
        type: "subscribe",
        child_id: childId,
      }));
      console.log("[WS] Subscribed to child:", childId);
    }
  }

  unsubscribeFromChild(childId: number): void {
    this.subscribedChildren.delete(childId);
    
    if (this.socket?.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify({
        type: "unsubscribe",
        child_id: childId,
      }));
      console.log("[WS] Unsubscribed from child:", childId);
    }
  }

  subscribeToAllChildren(childIds: number[]): void {
    childIds.forEach((id) => this.subscribeToChild(id));
  }

  onMessage(handler: MessageHandler): () => void {
    this.messageHandlers.add(handler);
    return () => this.messageHandlers.delete(handler);
  }

  onConnectionChange(handler: ConnectionHandler): () => void {
    this.connectionHandlers.add(handler);
    return () => this.connectionHandlers.delete(handler);
  }

  isConnected(): boolean {
    return this.socket?.readyState === WebSocket.OPEN;
  }

  private notifyMessageHandlers(message: WebSocketMessage): void {
    this.messageHandlers.forEach((handler) => {
      try {
        handler(message);
      } catch (error) {
        console.error("[WS] Handler error:", error);
      }
    });
  }

  private notifyConnectionHandlers(connected: boolean): void {
    this.connectionHandlers.forEach((handler) => {
      try {
        handler(connected);
      } catch (error) {
        console.error("[WS] Connection handler error:", error);
      }
    });
  }

  private startPingInterval(): void {
    this.stopPingInterval();
    this.pingInterval = setInterval(() => {
      if (this.socket?.readyState === WebSocket.OPEN) {
        this.socket.send(JSON.stringify({ type: "ping" }));
      }
    }, 25000);
  }

  private stopPingInterval(): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
  }

  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.log("[WS] Max reconnect attempts reached");
      return;
    }

    this.reconnectAttempts++;
    const delay = Math.min(this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1), 30000);
    
    console.log(`[WS] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);
    
    setTimeout(() => {
      if (this.socket?.readyState !== WebSocket.OPEN) {
        this.connect(this.token || undefined);
      }
    }, delay);
  }
}

// Singleton instance
export const webSocketService = new WebSocketService();
