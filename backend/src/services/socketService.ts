import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import { config } from '../config';
import { runAgent } from '../agents/shoppingAgent';

/**
 * Socket.io service for managing real-time communication
 * Handles client connections, messages, and agent interactions
 */
export class SocketService {
  private io: SocketIOServer;
  private connectedClients: Map<string, Socket> = new Map();

  constructor(httpServer: HttpServer) {
    // Initialize Socket.io server with CORS
    this.io = new SocketIOServer(httpServer, {
      cors: {
        origin: config.server.corsOrigins,
        methods: ['GET', 'POST'],
        credentials: true,
      },
      transports: ['websocket', 'polling'], // Support both transports for reliability
    });

    this.setupEventHandlers();
  }

  /**
   * Setup Socket.io event handlers
   */
  private setupEventHandlers(): void {
    this.io.on('connection', (socket: Socket) => {
      console.log(`✅ Client connected: ${socket.id}`);
      this.connectedClients.set(socket.id, socket);

      // Send welcome message
      socket.emit('connected', {
        message: 'Kết nối thành công với AI Shopping Agent!',
        socketId: socket.id,
        timestamp: new Date().toISOString(),
      });

      // Handle user messages
      socket.on('user_message', async (data: { message: string }) => {
        await this.handleUserMessage(socket, data);
      });

      // Handle disconnection
      socket.on('disconnect', () => {
        console.log(`❌ Client disconnected: ${socket.id}`);
        this.connectedClients.delete(socket.id);
      });

      // Handle errors
      socket.on('error', (error: Error) => {
        console.error(`Socket error for ${socket.id}:`, error);
        socket.emit('error', {
          message: 'Đã xảy ra lỗi kết nối',
          error: error.message,
        });
      });

      // Handle ping for connection health check
      socket.on('ping', () => {
        socket.emit('pong', { timestamp: new Date().toISOString() });
      });
    });
  }

  /**
   * Handle incoming user messages
   * Runs the agent and streams responses back to client
   */
  private async handleUserMessage(
    socket: Socket,
    data: { message: string }
  ): Promise<void> {
    try {
      const userMessage = data.message?.trim();

      if (!userMessage) {
        socket.emit('error', {
          message: 'Tin nhắn không được để trống',
        });
        return;
      }

      console.log(`📨 Message from ${socket.id}: "${userMessage}"`);

      // Emit acknowledgment
      socket.emit('message_received', {
        message: userMessage,
        timestamp: new Date().toISOString(),
      });

      // Run the agent with the user query
      const response = await runAgent(userMessage, socket);

      // Emit the final response
      socket.emit('agent_response', {
        success: response.success,
        answer: response.answer,
        products: response.products,
        error: response.error,
        timestamp: new Date().toISOString(),
      });

      console.log(`✅ Response sent to ${socket.id}`);
    } catch (error) {
      console.error('Error handling user message:', error);

      socket.emit('agent_response', {
        success: false,
        answer: 'Xin lỗi, đã xảy ra lỗi khi xử lý yêu cầu của bạn.',
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: new Date().toISOString(),
      });
    }
  }

  /**
   * Broadcast a message to all connected clients
   */
  public broadcast(event: string, data: unknown): void {
    this.io.emit(event, data);
    console.log(`📢 Broadcasted ${event} to ${this.connectedClients.size} clients`);
  }

  /**
   * Send a message to a specific client
   */
  public sendToClient(socketId: string, event: string, data: unknown): void {
    const socket = this.connectedClients.get(socketId);
    if (socket) {
      socket.emit(event, data);
      console.log(`📤 Sent ${event} to client ${socketId}`);
    } else {
      console.warn(`⚠️ Client ${socketId} not found`);
    }
  }

  /**
   * Get the number of connected clients
   */
  public getClientCount(): number {
    return this.connectedClients.size;
  }

  /**
   * Get Socket.io server instance
   */
  public getIO(): SocketIOServer {
    return this.io;
  }

  /**
   * Cleanup and close all connections
   */
  public async shutdown(): Promise<void> {
    console.log('🔌 Shutting down Socket service...');
    
    // Notify all clients about shutdown
    this.broadcast('server_shutdown', {
      message: 'Server đang bảo trì',
      timestamp: new Date().toISOString(),
    });

    // Close all connections
    this.io.close();
    this.connectedClients.clear();
    
    console.log('✅ Socket service shutdown complete');
  }
}

/**
 * Singleton instance
 */
let socketServiceInstance: SocketService | null = null;

/**
 * Initialize the socket service
 */
export function initializeSocketService(httpServer: HttpServer): SocketService {
  if (socketServiceInstance) {
    console.warn('⚠️ Socket service already initialized');
    return socketServiceInstance;
  }

  socketServiceInstance = new SocketService(httpServer);
  console.log('✅ Socket service initialized');
  
  return socketServiceInstance;
}

/**
 * Get the socket service instance
 */
export function getSocketService(): SocketService {
  if (!socketServiceInstance) {
    throw new Error('Socket service not initialized. Call initializeSocketService first.');
  }
  return socketServiceInstance;
}
