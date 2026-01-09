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
  google: {
    apiKey: string;
  };
  puppeteer: {
    headless: boolean;
    timeout: number;
  };
  agent: {
    model: string;
    temperature: number;
    maxProductsPerSearch: number;
  };
}

/**
 * Validates that required environment variables are set
 * @throws {Error} if required variables are missing
 */
function validateEnv(): void {
  const required = ['GOOGLE_API_KEY'];
  const missing = required.filter((key) => !process.env[key]);

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(', ')}\n` +
      `Please copy .env.example to .env and fill in the values.`
    );
  }
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
  google: {
    apiKey: process.env.GOOGLE_API_KEY || '',
  },
  puppeteer: {
    headless: process.env.PUPPETEER_HEADLESS === 'true',
    timeout: parseInt(process.env.PUPPETEER_TIMEOUT || '30000', 10),
  },
  agent: {
    model: process.env.AGENT_MODEL || 'gemini-pro',
    temperature: parseFloat(process.env.AGENT_TEMPERATURE || '0.7'),
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
  console.log(`   - Gemini Model: ${config.agent.model}`);
  console.log(`   - Puppeteer Headless: ${config.puppeteer.headless}`);
  console.log(`   - CORS Origins: ${config.server.corsOrigins.join(', ')}`);
}
