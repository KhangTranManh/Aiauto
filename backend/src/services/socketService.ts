import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import { config } from '../config';
import { runFinanceAgent } from '../agents/financeAgent';
import { HumanMessage, AIMessage } from '@langchain/core/messages';

/**
 * Socket.io service for managing real-time communication
 * Handles client connections, messages, and finance agent interactions
 */
export class SocketService {
  private io: SocketIOServer;
  private connectedClients: Map<string, Socket> = new Map();
  private chatHistories: Map<string, (HumanMessage | AIMessage)[]> = new Map();

  constructor(httpServer: HttpServer) {
    
    // Initialize Socket.io server with CORS
    this.io = new SocketIOServer(httpServer, {
      cors: {
        origin: true, // Allow all origins in development
        methods: ['GET', 'POST'],
        credentials: true,
      },
      transports: ['websocket', 'polling'],
    });

    this.setupEventHandlers();
  }

  /**
   * Setup Socket.io event handlers
   */
  private setupEventHandlers(): void {
    this.io.on('connection', (socket: Socket) => {
      // Extract userId from handshake query (sent from Flutter)
      const userId = (socket.handshake.query.userId as string) || 'default';
      
      console.log(`✅ Client connected: ${socket.id} (User: ${userId})`);
      this.connectedClients.set(socket.id, socket);
      this.chatHistories.set(socket.id, []); // Initialize empty chat history

      // Send welcome message
      socket.emit('connected', {
        message: 'Kết nối thành công với AI Shopping Agent!',
        socketId: socket.id,
        userId: userId,
        timestamp: new Date().toISOString(),
      });

      // Handle user messages
      socket.on('user_message', async (data: { message: string }) => {
        await this.handleUserMessage(socket, data, userId);
      });

      // Handle clear history request
      socket.on('clear_history', () => {
        this.chatHistories.set(socket.id, []);
        console.log(`🗑️ Chat history cleared for ${socket.id}`);
        socket.emit('history_cleared', {
          message: 'Lịch sử hội thoại đã được xóa',
          timestamp: new Date().toISOString(),
        });
      });

      // Handle disconnection
      socket.on('disconnect', () => {
        console.log(`❌ Client disconnected: ${socket.id}`);
        this.connectedClients.delete(socket.id);
        this.chatHistories.delete(socket.id); // Clear chat history on disconnect
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
    data: { message: string },
    userId: string
  ): Promise<void> {
    try {
      const userMessage = data.message?.trim();

      if (!userMessage) {
        socket.emit('error', {
          message: 'Tin nhắn không được để trống',
        });
        return;
      }

      console.log(`📨 Message from ${socket.id} (User: ${userId}): "${userMessage}"`);

      // Emit acknowledgment
      socket.emit('message_received', {
        message: userMessage,
        timestamp: new Date().toISOString(),
      });

      // Get chat history for this socket
      const chatHistory = this.chatHistories.get(socket.id) || [];

      // Run the finance agent with the user query, chat history, and userId
      const response = await runFinanceAgent(userMessage, socket, chatHistory, userId);

      // Update chat history with user message and AI response
      if (response.success && response.answer) {
        chatHistory.push(new HumanMessage(userMessage));
        chatHistory.push(new AIMessage(response.answer));
        
        // Keep only last 10 exchanges (20 messages) to avoid context overflow
        if (chatHistory.length > 20) {
          chatHistory.splice(0, chatHistory.length - 20);
        }
        
        this.chatHistories.set(socket.id, chatHistory);
        console.log(`💾 Chat history updated. Total messages: ${chatHistory.length}`);
      }

      // Emit the final response
      socket.emit('agent_response', {
        success: response.success,
        answer: response.answer,
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
export function initializeSocketService(
  httpServer: HttpServer
): SocketService {
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
