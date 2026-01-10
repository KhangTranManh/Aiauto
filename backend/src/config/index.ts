import dotenv from 'dotenv';
import path from 'path';

// Load environment variables from .env file
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

/**
 * Configuration interface with strict typing
 */
interface Config {
  server: {
    port: number;
    nodeEnv: string;
    corsOrigins: string[];
  };
  ai: {
    provider: 'google' | 'ollama';
    model: string;
    temperature: number;
    ollamaBaseUrl?: string;
  };
  google: {
    apiKey: string;
    model: string;
  };
  puppeteer: {
    headless: boolean;
    timeout: number;
  };
  agent: {
    maxProductsPerSearch: number;
  };
}

/**
 * Validates that required environment variables are set
 * @throws {Error} if required variables are missing
 */
function validateEnv(): void {
  const provider = process.env.AI_PROVIDER || 'ollama';
  
  if (provider === 'google') {
    const required = ['GOOGLE_API_KEY'];
    const missing = required.filter((key) => !process.env[key]);

    if (missing.length > 0) {
      throw new Error(
        `Missing required environment variables for Google AI: ${missing.join(', ')}\n` +
        `Please copy .env.example to .env and fill in the values.`
      );
    }
  }
  // Ollama doesn't require API keys, just needs to be running locally
}

/**
 * Parse CORS origins from environment variable
 */
function parseCorsOrigins(): string[] {
  const origins = process.env.CORS_ORIGINS || 'http://localhost:3000';
  return origins.split(',').map((origin) => origin.trim());
}

/**
 * Application configuration object
 * Centralized configuration management with type safety
 */
export const config: Config = {
  server: {
    port: parseInt(process.env.PORT || '3000', 10),
    nodeEnv: process.env.NODE_ENV || 'development',
    corsOrigins: parseCorsOrigins(),
  },
  ai: {
    provider: (process.env.AI_PROVIDER || 'ollama') as 'google' | 'ollama',
    model: process.env.AI_MODEL || 'llama3.1:8b',
    temperature: parseFloat(process.env.AI_TEMPERATURE || '0.7'),
    ollamaBaseUrl: process.env.OLLAMA_BASE_URL || 'http://localhost:11434',
  },
  google: {
    apiKey: process.env.GOOGLE_API_KEY || '',
    model: process.env.GOOGLE_MODEL || 'gemini-1.5-flash',
  },
  puppeteer: {
    headless: process.env.PUPPETEER_HEADLESS === 'true',
    timeout: parseInt(process.env.PUPPETEER_TIMEOUT || '30000', 10),
  },
  agent: {
    maxProductsPerSearch: parseInt(process.env.MAX_PRODUCTS_PER_SEARCH || '5', 10),
  },
};

// Validate environment on import
validateEnv();

/**
 * Log configuration on startup (excluding sensitive data)
 */
export function logConfig(): void {
  console.log('🔧 Configuration loaded:');
  console.log(`   - Environment: ${config.server.nodeEnv}`);
  console.log(`   - Port: ${config.server.port}`);
  console.log(`   - AI Provider: ${config.ai.provider.toUpperCase()}`);
  console.log(`   - AI Model: ${config.ai.model}`);
  if (config.ai.provider === 'ollama') {
    console.log(`   - Ollama URL: ${config.ai.ollamaBaseUrl}`);
  }
  console.log(`   - Puppeteer Headless: ${config.puppeteer.headless}`);
  console.log(`   - CORS Origins: ${config.server.corsOrigins.join(', ')}`);
}
