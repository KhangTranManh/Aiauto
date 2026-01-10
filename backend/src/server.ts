import http from 'http';
import { config, logConfig } from './config';
import { createApp } from './app';
import { initializeSocketService } from './services/socketService';
import { connectDatabase, disconnectDatabase } from './database/db';

/**
 * Main server entry point
 * Sets up HTTP server, Express app, Socket.io, and MongoDB database
 */

// Create Express app
const app = createApp();

// Create HTTP server
const httpServer = http.createServer(app);

// Initialize Socket.io service
const socketService = initializeSocketService(httpServer);

/**
 * Start the server
 */
async function startServer(): Promise<void> {
  try {
    // Connect to MongoDB first
    await connectDatabase();

    // Start HTTP server
    httpServer.listen(config.server.port, () => {
      console.log('\n' + '='.repeat(60));
      console.log('🚀 Personal Finance AI Agent Server Started!');
      console.log('='.repeat(60));
      logConfig();
      console.log('='.repeat(60));
      console.log(`🌐 Server running at: http://localhost:${config.server.port}`);
      console.log(`🔌 Socket.io ready for connections`);
      console.log(`📊 Health check: http://localhost:${config.server.port}/health`);
      console.log('='.repeat(60) + '\n');
      console.log('💡 Waiting for client connections...\n');
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

/**
 * Graceful shutdown handler
 */
async function gracefulShutdown(signal: string): Promise<void> {
  console.log(`\n⚠️  Received ${signal}, starting graceful shutdown...`);

  try {
    // Stop accepting new connections
    httpServer.close(async () => {
      console.log('✅ HTTP server closed');

      // Shutdown Socket.io
      await socketService.shutdown();

      // Disconnect from MongoDB
      await disconnectDatabase();

      console.log('✅ Graceful shutdown complete');
      process.exit(0);
    });

    // Force shutdown after 10 seconds
    setTimeout(() => {
      console.error('❌ Forced shutdown after timeout');
      process.exit(1);
    }, 10000);
  } catch (error) {
    console.error('❌ Error during shutdown:', error);
    process.exit(1);
  }
}

/**
 * Error handlers
 */

// Handle uncaught exceptions
process.on('uncaughtException', (error: Error) => {
  console.error('❌ Uncaught Exception:', error);
  gracefulShutdown('uncaughtException');
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason: unknown, promise: Promise<unknown>) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  gracefulShutdown('unhandledRejection');
});

// Handle SIGTERM (Docker, Kubernetes)
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

// Handle SIGINT (Ctrl+C)
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Start the server
startServer();

export { httpServer, socketService };
