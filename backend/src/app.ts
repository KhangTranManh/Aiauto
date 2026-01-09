import express, { Application, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { config } from './config';
import { searchShopee } from './tools/shopeeScraper';
import { runAgent } from './agents/shoppingAgent';

/**
 * Error interface for consistent error handling
 */
interface ApiError extends Error {
  statusCode?: number;
}

/**
 * Mock socket for HTTP API calls
 */
class MockSocket {
  private events: { [key: string]: any[] } = {};

  emit(event: string, data: any): void {
    if (!this.events[event]) {
      this.events[event] = [];
    }
    this.events[event].push(data);
  }

  getEvents(): { [key: string]: any[] } {
    return this.events;
  }
}

/**
 * Create and configure the Express application
 */
export function createApp(): Application {
  const app = express();

  // ==================== Middleware ====================

  // CORS - Allow cross-origin requests from Flutter app
  app.use(
    cors({
      origin: config.server.corsOrigins,
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    })
  );

  // Body parser - Parse JSON bodies
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request logging middleware
  app.use((req: Request, res: Response, next: NextFunction) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${req.method} ${req.path}`);
    next();
  });

  // ==================== Health Check Routes ====================

  /**
   * Health check endpoint
   * Used by monitoring systems and to verify the server is running
   */
  app.get('/health', (req: Request, res: Response) => {
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: config.server.nodeEnv,
    });
  });

  /**
   * Root endpoint - API information
   */
  app.get('/', (req: Request, res: Response) => {
    res.status(200).json({
      name: 'AI Shopping Agent API',
      version: '1.0.0',
      description: 'Backend for Autonomous AI Shopping Agent targeting Vietnamese e-commerce',
      endpoints: {
        health: '/health',
        websocket: 'Connect via Socket.io on the same port',
      },
      documentation: 'Use Socket.io to connect and send "user_message" events',
    });
  });

  /**
   * API status endpoint with more detailed information
   */
  app.get('/api/status', (req: Request, res: Response) => {
    res.status(200).json({
      server: {
        status: 'running',
        environment: config.server.nodeEnv,
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
      },
      agent: {
        model: config.agent.model,
        temperature: config.agent.temperature,
        maxProducts: config.agent.maxProductsPerSearch,
      },
      features: {
        shopeeSearch: true,
        realTimeUpdates: true,
        vietnameseLanguage: true,
      },
    });
  });

  /**
   * POST /api/search - Direct product search
   * Test with Postman: POST http://localhost:3000/api/search
   * Body: { "query": "iPhone 15" }
   */
  app.post('/api/search', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { query } = req.body;

      if (!query || typeof query !== 'string') {
        return res.status(400).json({
          error: 'Bad Request',
          message: 'Query parameter is required and must be a string',
        });
      }

      console.log(`🔍 API Search request: "${query}"`);

      const result = await searchShopee(query);

      res.status(200).json({
        success: result.success,
        query,
        products: result.products,
        totalFound: result.products.length,
        message: result.message,
        timestamp: result.timestamp,
      });
    } catch (error) {
      next(error);
    }
  });

  /**
   * POST /api/chat - Chat with AI agent
   * Test with Postman: POST http://localhost:3000/api/chat
   * Body: { "message": "Tìm laptop gaming giá rẻ" }
   */
  app.post('/api/chat', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { message } = req.body;

      if (!message || typeof message !== 'string') {
        return res.status(400).json({
          error: 'Bad Request',
          message: 'Message parameter is required and must be a string',
        });
      }

      console.log(`💬 API Chat request: "${message}"`);

      // Use mock socket for HTTP requests
      const mockSocket = new MockSocket() as any;
      const response = await runAgent(message, mockSocket);

      res.status(200).json({
        success: response.success,
        answer: response.answer,
        products: response.products,
        events: mockSocket.getEvents(),
        error: response.error,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      next(error);
    }
  });

  /**
   * GET /api/test - Quick test endpoint
   */
  app.get('/api/test', async (req: Request, res: Response, next: NextFunction) => {
    try {
      const testQuery = req.query.q as string || 'iPhone 15';
      
      console.log(`🧪 Test request: "${testQuery}"`);

      const result = await searchShopee(testQuery, 3);

      res.status(200).json({
        message: 'Test successful!',
        query: testQuery,
        productsFound: result.products.length,
        products: result.products,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      next(error);
    }
  });

  // ==================== Error Handling ====================

  /**
   * 404 handler - Route not found
   */
  app.use((req: Request, res: Response) => {
    res.status(404).json({
      error: 'Not Found',
      message: `Route ${req.method} ${req.path} not found`,
      timestamp: new Date().toISOString(),
    });
  });

  /**
   * Global error handler
   */
  app.use((err: ApiError, req: Request, res: Response, next: NextFunction) => {
    console.error('❌ Express error:', err);

    const statusCode = err.statusCode || 500;
    const message = err.message || 'Internal Server Error';

    res.status(statusCode).json({
      error: statusCode === 500 ? 'Internal Server Error' : err.name,
      message: config.server.nodeEnv === 'production' && statusCode === 500 
        ? 'An unexpected error occurred' 
        : message,
      timestamp: new Date().toISOString(),
      ...(config.server.nodeEnv === 'development' && { stack: err.stack }),
    });
  });

  return app;
}
