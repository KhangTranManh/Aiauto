# 🏗️ Architecture & Implementation Summary

## 📊 Complete Backend Structure

```
backend/
├── src/
│   ├── config/
│   │   └── index.ts              # ⚙️ Configuration management
│   ├── agents/
│   │   └── shoppingAgent.ts      # 🤖 LangChain AI Agent
│   ├── tools/
│   │   ├── shopeeScraper.ts      # 🔍 Puppeteer web scraper
│   │   └── currency.ts           # 💰 VND currency utilities
│   ├── services/
│   │   └── socketService.ts      # 🔌 Socket.io manager
│   ├── app.ts                    # 🌐 Express application
│   └── server.ts                 # 🚀 Entry point
├── .env                          # 🔐 Environment variables
├── .env.example                  # 📋 Environment template
├── package.json                  # 📦 Dependencies
├── tsconfig.json                 # 🔧 TypeScript config
├── .eslintrc.js                  # 📏 ESLint rules
├── .prettierrc                   # 🎨 Code formatting
├── .gitignore                    # 🚫 Git exclusions
├── README.md                     # 📖 Main documentation
├── SETUP.md                      # 🚀 Setup guide
└── ARCHITECTURE.md               # 📐 This file
```

---

## 🔄 Complete Data Flow

### 1. Client Connection
```
Flutter App → Socket.io Connect → Server
```

**Implementation:** [socketService.ts](src/services/socketService.ts)
- Client connects via Socket.io
- Receives `connected` event with socket ID
- Connection stored in `connectedClients` Map

### 2. User Sends Message
```
User Input → "user_message" event → Socket Service
```

**Event Payload:**
```javascript
{
  message: "Tìm iPhone 15 cho tôi"
}
```

### 3. Agent Processing
```
Socket Service → Shopping Agent → LangChain Executor
```

**Implementation:** [shoppingAgent.ts](src/agents/shoppingAgent.ts)
- Receives user query
- Emits `agent_status` (thinking)
- LangChain analyzes intent
- Decides which tool to use

### 4. Tool Execution
```
Agent → search_shopee Tool → Puppeteer → Shopee.vn
```

**Implementation:** [shopeeScraper.ts](src/tools/shopeeScraper.ts)
- Launches headless Chrome with stealth plugin
- Navigates to Shopee search URL
- Waits for product list to load
- Extracts top 5 products
- Returns structured data

### 5. Response Generation
```
Tool Results → Agent → GPT-4o → Formatted Response
```

**Agent behavior:**
- Receives product data from tool
- Uses GPT-4o to format response
- Adds recommendations and insights
- Returns user-friendly Vietnamese text

### 6. Stream Back to Client
```
Agent → Socket Service → "agent_response" event → Flutter App
```

**Response Payload:**
```javascript
{
  success: true,
  answer: "Tôi đã tìm thấy 5 sản phẩm iPhone 15...",
  products: [
    {
      name: "iPhone 15 Pro Max 256GB",
      price: "28.990.000 ₫",
      priceRaw: 28990000,
      link: "https://shopee.vn/...",
      imageUrl: "https://...",
      rating: 4.8,
      soldCount: "1.2k"
    },
    // ... more products
  ],
  timestamp: "2026-01-09T..."
}
```

---

## 🧩 Component Details

### 1. Configuration Module (`src/config/index.ts`)

**Purpose:** Centralized configuration management

**Key Features:**
- Loads environment variables from `.env`
- Validates required variables on startup
- Type-safe configuration object
- Exports singleton config instance

**Configuration Structure:**
```typescript
interface Config {
  server: {
    port: number;
    nodeEnv: string;
    corsOrigins: string[];
  };
  openai: {
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
```

---

### 2. Shopping Agent (`src/agents/shoppingAgent.ts`)

**Purpose:** AI-powered shopping assistant using LangChain

**Key Components:**

#### a) Tool Definition
```typescript
DynamicStructuredTool({
  name: 'search_shopee',
  description: 'Searches for products on Shopee.vn...',
  schema: z.object({
    query: z.string()
  }),
  func: async ({ query }) => {
    const result = await searchShopee(query);
    return JSON.stringify(result);
  }
})
```

#### b) Agent Prompt
- System role: Vietnamese shopping assistant
- Capabilities: Search, recommend, compare products
- Guidelines: Be friendly, use emojis, format prices

#### c) Agent Executor
```typescript
const executor = new AgentExecutor({
  agent,
  tools: [shopeeTool],
  verbose: true,
  maxIterations: 5,
  returnIntermediateSteps: true
});
```

#### d) Execution Flow
1. Initialize OpenAI model (GPT-4o)
2. Create tools array
3. Build prompt template
4. Create agent with functions
5. Execute with user query
6. Stream status updates via Socket.io
7. Return final response with products

---

### 3. Shopee Scraper (`src/tools/shopeeScraper.ts`)

**Purpose:** Extract product data from Shopee.vn

**Technology Stack:**
- **Puppeteer**: Headless browser automation
- **puppeteer-extra**: Plugin system
- **puppeteer-extra-plugin-stealth**: Anti-detection

**Scraping Process:**

#### Step 1: Browser Launch
```typescript
const browser = await puppeteerExtra.launch({
  headless: 'new',
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--window-size=1920x1080'
  ]
});
```

#### Step 2: Navigation
```typescript
const url = `https://shopee.vn/search?keyword=${query}`;
await page.goto(url, { waitUntil: 'networkidle2' });
```

#### Step 3: Wait for Products
```typescript
await page.waitForSelector('[data-sqe="item"]', { timeout: 15000 });
```

#### Step 4: Extract Data
```typescript
const products = await page.evaluate((max) => {
  const cards = document.querySelectorAll('[data-sqe="item"]');
  // Extract name, price, link, image, rating, etc.
  return results;
}, maxResults);
```

#### Step 5: Format & Return
- Parse prices using currency utilities
- Format Vietnamese Dong
- Return structured product array

**Error Handling:**
- On scraping failure, returns mock data
- Prevents app crashes
- Logs errors for debugging

---

### 4. Currency Utilities (`src/tools/currency.ts`)

**Purpose:** Handle Vietnamese Dong formatting and parsing

**Functions:**

#### `formatVND(amount: number): string`
```typescript
formatVND(1000000) // → "1.000.000 ₫"
```

#### `parseVND(currencyString: string): number`
```typescript
parseVND("1.000.000đ") // → 1000000
```

#### `extractPrice(priceText: string): number`
- Handles various formats
- Extracts numeric value
- Used by scraper

---

### 5. Socket Service (`src/services/socketService.ts`)

**Purpose:** Manage real-time WebSocket connections

**Class Structure:**
```typescript
class SocketService {
  private io: SocketIOServer;
  private connectedClients: Map<string, Socket>;
  
  constructor(httpServer: HttpServer)
  setupEventHandlers(): void
  handleUserMessage(socket, data): Promise<void>
  broadcast(event, data): void
  sendToClient(socketId, event, data): void
  getClientCount(): number
  shutdown(): Promise<void>
}
```

**Event Handlers:**
- `connection`: New client connects
- `user_message`: Incoming query from client
- `disconnect`: Client disconnects
- `error`: Handle connection errors
- `ping/pong`: Health check

**Emitted Events:**
- `connected`: Welcome message
- `message_received`: Acknowledgment
- `agent_status`: Progress updates
- `agent_response`: Final result
- `error`: Error notifications

---

### 6. Express Application (`src/app.ts`)

**Purpose:** HTTP server and REST endpoints

**Middleware Stack:**
1. **CORS**: Cross-origin support for Flutter app
2. **Body Parser**: JSON parsing (10mb limit)
3. **Request Logger**: Log all incoming requests

**Endpoints:**

#### `GET /`
- API information
- Available endpoints
- Documentation links

#### `GET /health`
- Health check
- Uptime
- Environment info

#### `GET /api/status`
- Detailed status
- Agent configuration
- Feature flags

#### `404 Handler`
- Route not found errors

#### `Error Handler`
- Global error handling
- Stack traces in development
- Sanitized errors in production

---

### 7. Server Entry Point (`src/server.ts`)

**Purpose:** Main application bootstrap

**Initialization Sequence:**
1. Create Express app
2. Create HTTP server
3. Initialize Socket.io
4. Start listening on port
5. Setup graceful shutdown

**Process Handlers:**
- `uncaughtException`: Catch unhandled errors
- `unhandledRejection`: Catch promise errors
- `SIGTERM`: Docker/Kubernetes shutdown
- `SIGINT`: Ctrl+C shutdown

**Graceful Shutdown:**
1. Stop accepting new connections
2. Close HTTP server
3. Shutdown Socket.io
4. Exit process
5. Force exit after 10s timeout

---

## 🔒 Security Features

### 1. Environment Variables
- Sensitive data in `.env`
- `.env` in `.gitignore`
- Validation on startup

### 2. CORS Protection
- Configurable allowed origins
- Credentials support
- Method restrictions

### 3. Input Validation
- Message length checks
- Type checking with TypeScript
- Zod schemas for tool inputs

### 4. Error Handling
- Graceful degradation
- No sensitive data in errors
- Mock data fallback

### 5. Rate Limiting (Recommended for Production)
- Add `express-rate-limit` package
- Limit requests per IP
- Prevent abuse

---

## ⚡ Performance Optimizations

### 1. Puppeteer
- Headless mode for speed
- Stealth plugin to avoid CAPTCHAs
- Connection reuse
- Timeout configuration

### 2. Socket.io
- WebSocket transport (faster than polling)
- Binary data support
- Compression enabled

### 3. LangChain
- Streaming responses
- Intermediate step tracking
- Max iterations limit

### 4. TypeScript
- Compile-time type checking
- No runtime overhead
- Better IDE support

---

## 🧪 Testing Strategy

### Unit Tests (Recommended)
```typescript
// test/tools/currency.test.ts
describe('Currency Utils', () => {
  it('should format VND correctly', () => {
    expect(formatVND(1000000)).toBe('1.000.000 ₫');
  });
});
```

### Integration Tests
```typescript
// test/integration/agent.test.ts
describe('Shopping Agent', () => {
  it('should search products', async () => {
    const result = await runAgent('tìm iPhone', mockSocket);
    expect(result.success).toBe(true);
  });
});
```

### E2E Tests
- Use Socket.io client to test full flow
- Mock Shopee responses
- Verify event emissions

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] Set `NODE_ENV=production`
- [ ] Add production OpenAI API key
- [ ] Configure production CORS origins
- [ ] Enable Puppeteer headless mode
- [ ] Run `npm run build`
- [ ] Test with `npm start`

### Cloud Platform Setup
- [ ] Set environment variables
- [ ] Install Chromium dependencies
- [ ] Configure port binding
- [ ] Setup health check endpoint
- [ ] Enable auto-scaling (optional)

### Monitoring (Recommended)
- [ ] Add logging service (Winston, Pino)
- [ ] Setup error tracking (Sentry)
- [ ] Monitor API costs (OpenAI)
- [ ] Track response times
- [ ] Alert on failures

---

## 📈 Future Enhancements

### 1. Multi-Platform Support
- Add Tiki scraper (`tikiScraper.ts`)
- Add Lazada scraper
- Agent chooses platform automatically

### 2. Advanced Features
- Product price history tracking
- Price comparison across platforms
- Wishlist management
- Deal alerts

### 3. Performance
- Redis caching for frequent searches
- Database for product history
- Rate limiting per user
- Request queuing

### 4. AI Improvements
- Fine-tuned model for Vietnamese
- Custom embeddings for products
- Personalized recommendations
- Multi-turn conversations

---

## 🤝 Contributing Guidelines

### Code Style
- Use TypeScript strict mode
- Follow ESLint rules
- Format with Prettier
- Add JSDoc comments

### Git Workflow
1. Create feature branch
2. Make changes with clear commits
3. Test thoroughly
4. Submit pull request
5. Code review

### Documentation
- Update README.md for user-facing changes
- Update ARCHITECTURE.md for structural changes
- Add inline comments for complex logic

---

## 📞 Support & Maintenance

### Logs Location
- Development: Console output
- Production: Use PM2 or cloud logging

### Common Maintenance Tasks
- Update dependencies: `npm update`
- Security audit: `npm audit`
- Clean build: `rm -rf dist && npm run build`

### Monitoring Metrics
- Response time per query
- Success rate of scraping
- OpenAI API costs
- Socket.io connection count

---

**Built with ❤️ for scalability, maintainability, and performance.**

Last Updated: January 9, 2026
