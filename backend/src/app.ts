import express, { Application, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { config } from './config';
import { Transaction } from './models/Transaction';
import { scanReceipt } from './services/geminiService';
import { predictEndOfMonth } from './services/forecastService';
import authRoutes from './routes/auth';
import { authenticate, AuthRequest } from './middleware/auth';
import { User } from './models/User';

/**
 * Create and configure Express application
 */
export function createApp(): Application {
  const app = express();

  // Middleware - CORS with permissive settings for development
  app.use(cors({
    origin: true, // Allow all origins in development
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }));
  
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // Request logging middleware
  app.use((req: Request, res: Response, next: NextFunction) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
    next();
  });

  // Auth routes (public)
  app.use('/api/auth', authRoutes);

  // Health check endpoint
  app.get('/health', (req: Request, res: Response) => {
    res.json({
      status: 'ok',
      message: 'Personal Finance AI Agent is running',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  });

  // API status endpoint
  app.get('/api/status', (req: Request, res: Response) => {
    res.json({
      service: 'Personal Finance AI Agent',
      version: '1.0.0',
      agent: config.agent.model,
      features: [
        'Expense tracking',
        'Monthly summaries',
        'Gold price lookup',
        'USD exchange rate',
      ],
    });
  });

  // Get recent transactions (protected)
  app.get('/api/transactions/recent', authenticate, async (req: AuthRequest, res: Response) => {
    try {
      const limit = parseInt(req.query.limit as string) || 10;
      const transactions = await Transaction.find({ userId: req.userId })
        .sort({ date: -1 })
        .limit(limit);

      res.json({
        success: true,
        count: transactions.length,
        transactions,
      });
    } catch (error) {
      console.error('Error fetching transactions:', error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });

  // Get transactions by month (protected)
  app.get('/api/transactions/month/:year/:month', authenticate, async (req: AuthRequest, res: Response) => {
    try {
      const { year, month } = req.params;
      const startDate = `${year}-${month.padStart(2, '0')}-01`;
      const endDate = `${year}-${month.padStart(2, '0')}-31`;

      console.log(`📊 Querying transactions for user ${req.userId}: ${startDate} to ${endDate}`);

      const transactions = await Transaction.find({
        userId: req.userId,
        date: { $gte: startDate, $lte: endDate },
      }).sort({ date: -1 });

      console.log(`📊 Found ${transactions.length} transactions for ${month}/${year}`);
      if (transactions.length > 0) {
        console.log('First transaction:', {
          date: transactions[0].date,
          amount: transactions[0].amount,
          category: transactions[0].category,
          merchant: transactions[0].merchant,
        });
      }

      const total = transactions.reduce((sum, t) => sum + t.amount, 0);

      res.json({
        success: true,
        period: `${month}/${year}`,
        count: transactions.length,
        total,
        totalFormatted: `${total.toLocaleString('vi-VN')}đ`,
        transactions,
      });
    } catch (error) {
      console.error('Error fetching monthly transactions:', error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });

  // ==================== RECEIPT SCANNING ENDPOINT ====================
  /**
   * POST /api/scan-receipt
   * Submit receipt text and extract transaction data using local AI
   */
  app.post('/api/scan-receipt', authenticate, async (req: AuthRequest, res: Response) => {
    try {
      console.log('📱 Scan receipt request from user:', req.userId);
      const { receiptText } = req.body;

      if (!receiptText || typeof receiptText !== 'string') {
        return res.status(400).json({
          success: false,
          error: 'Missing receipt text. Please provide receiptText in request body.',
        });
      }

      console.log(`📄 Processing receipt text (${receiptText.length} chars)...`);

      // Scan the receipt using local Ollama AI
      const receiptData = await scanReceipt(receiptText);

      // Save to MongoDB with userId from authenticated request
      const transaction = await Transaction.create({
        userId: req.userId,
        amount: receiptData.amount,
        category: receiptData.category,
        merchant: receiptData.merchant,
        note: receiptData.rawText || '',
        date: receiptData.date,
      });

      console.log(`✅ Transaction saved: ${transaction._id}`);

      return res.json({
        success: true,
        message: 'Receipt scanned and transaction saved successfully',
        data: {
          transactionId: transaction._id,
          amount: transaction.amount,
          category: transaction.category,
          merchant: transaction.merchant,
          date: transaction.date,
          note: transaction.note,
        },
      });

    } catch (error) {
      console.error('❌ Receipt scan error:', error);
      return res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Failed to process receipt',
      });
    }
  });

  // ==================== EXPENSE FORECAST ENDPOINT ====================
  /**
   * GET /api/forecast?budget=10000000
   * Predict end-of-month spending using linear regression
   */
  app.get('/api/forecast', authenticate, async (req: AuthRequest, res: Response) => {
    try {
      const budgetParam = req.query.budget as string | undefined;
      const budget = budgetParam ? parseInt(budgetParam, 10) : undefined;
      
      console.log(`📊 Generating expense forecast... (budget: ${budget || 'default'})`);

      // Get forecast prediction
      const forecast = await predictEndOfMonth('default', budget);

      console.log(`✅ Forecast generated: ${forecast.predicted_total} VND (${forecast.safety_status})`);

      return res.json({
        success: true,
        forecast,
      });

    } catch (error) {
      console.error('❌ Forecast error:', error);
      return res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Failed to generate forecast',
      });
    }
  });

  // 404 handler
  app.use((req: Request, res: Response) => {
    res.status(404).json({
      error: 'Not Found',
      message: `Route ${req.method} ${req.path} not found`,
    });
  });

  // Error handling middleware
  app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
    console.error('Express error:', err);
    res.status(500).json({
      error: 'Internal Server Error',
      message: err.message,
    });
  });

  return app;
}
