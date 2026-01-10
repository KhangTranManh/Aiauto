# 💰 Personal Finance AI Agent Backend# 🤖 AI Shopping Agent Backend



AI-powered personal finance assistant for Vietnamese users built with Node.js, TypeScript, Google Gemini, and SQLite.A production-ready Node.js backend for an Autonomous AI Shopping Agent targeting the Vietnamese e-commerce market (Shopee, Tiki). Built with TypeScript, Express, Socket.io, and LangChain for intelligent product search and recommendations.



## 🎯 Features## 🎯 Features



- **💳 Expense Tracking**: Record expenses naturally in Vietnamese- **🧠 AI-Powered Agent**: Uses LangChain + OpenAI (GPT-4o) for intelligent shopping assistance

- **📊 Financial Reports**: Monthly spending summaries- **🔍 Web Scraping**: Puppeteer-based scraper for Shopee.vn with anti-bot detection

- **💰 Market Data**: Real-time gold prices & USD/VND rates  - **⚡ Real-time Communication**: Socket.io for streaming agent thoughts and results

- **🧠 AI-Powered**: Google Gemini for natural language understanding- **🌐 Vietnamese Language Support**: Optimized for Vietnamese e-commerce platforms

- **⚡ Real-time**: Socket.io streaming responses- **🛡️ Type Safety**: Full TypeScript with strict mode enabled

- **🗄️ SQLite**: Local database storage- **📦 Scalable Architecture**: Modular design following best practices



## 🚀 Quick Start## 📁 Project Structure



```bash```

npm installai-agent-backend/

# Edit .env and add GOOGLE_API_KEY├── src/

npm run dev│   ├── config/               # Environment variables & configuration

```│   │   └── index.ts

│   ├── agents/               # LangChain Agent Logic

Server runs on `http://localhost:3000`│   │   └── shoppingAgent.ts  # Main AI agent implementation

│   ├── tools/                # Custom Tools

## 💬 Example Usage│   │   ├── shopeeScraper.ts  # Puppeteer scraping logic

│   │   └── currency.ts       # VND currency utilities

- *"Sáng nay ăn phở hết 50k"* → Records expense│   ├── services/             # Services

- *"Tháng này tiêu bao nhiêu?"* → Shows summary│   │   └── socketService.ts  # Socket.io connection manager

- *"Giá vàng SJC hôm nay?"* → Gold prices│   ├── app.ts                # Express app configuration

│   └── server.ts             # Entry point (HTTP + Socket.io)

## 📊 Tech Stack├── .env.example              # Environment variables template

├── .gitignore

- Node.js + TypeScript├── package.json

- Express + Socket.io├── tsconfig.json

- Google Gemini + LangChain└── README.md

- SQLite (better-sqlite3)```

- Puppeteer (market scraping)

## 🚀 Quick Start

---

Built for Vietnamese personal finance management 🇻🇳### Prerequisites


- **Node.js**: v18+ (LTS recommended)
- **npm**: v9+
- **OpenAI API Key**: Get one from [OpenAI Platform](https://platform.openai.com/)

### Installation

1. **Clone and navigate to the backend folder**:
   ```bash
   cd backend
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Setup environment variables**:
   ```bash
   cp .env.example .env
   ```

4. **Edit `.env` and add your OpenAI API key**:
   ```env
   OPENAI_API_KEY=sk-your-actual-api-key-here
   PORT=3000
   NODE_ENV=development
   ```

### Running the Server

#### Development Mode (with auto-reload):
```bash
npm run dev
```

#### Production Mode:
```bash
npm run build
npm start
```

The server will start on `http://localhost:3000`

## 🔌 API Usage

### HTTP Endpoints

#### Health Check
```http
GET /health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2026-01-09T...",
  "uptime": 123.45,
  "environment": "development"
}
```

#### API Status
```http
GET /api/status
```

### Socket.io Real-time Communication

#### Connect to Socket.io
```javascript
import io from 'socket.io-client';

const socket = io('http://localhost:3000');

socket.on('connected', (data) => {
  console.log('Connected:', data);
});
```

#### Send a User Message
```javascript
socket.emit('user_message', {
  message: 'Tìm iPhone 15 cho tôi'
});
```

#### Listen for Agent Status Updates
```javascript
socket.on('agent_status', (data) => {
  console.log('Status:', data.message);
  // Outputs: "Đang suy nghĩ...", "Đang tìm kiếm...", etc.
});
```

#### Receive Agent Response
```javascript
socket.on('agent_response', (data) => {
  console.log('Answer:', data.answer);
  console.log('Products:', data.products);
});
```

### Complete Socket.io Flow Example

```javascript
const socket = io('http://localhost:3000');

// Connection established
socket.on('connected', (data) => {
  console.log('✅ Connected:', data.socketId);
  
  // Send a query
  socket.emit('user_message', {
    message: 'Tìm laptop gaming giá rẻ'
  });
});

// Message received acknowledgment
socket.on('message_received', (data) => {
  console.log('📨 Message received:', data.message);
});

// Agent thinking/searching status
socket.on('agent_status', (data) => {
  console.log('🤖 Status:', data.message);
  // "Đang suy nghĩ...", "Đang tìm kiếm...", "Hoàn thành!"
});

// Final response with products
socket.on('agent_response', (data) => {
  if (data.success) {
    console.log('✅ Answer:', data.answer);
    data.products?.forEach((product, idx) => {
      console.log(`${idx + 1}. ${product.name}`);
      console.log(`   Price: ${product.price}`);
      console.log(`   Link: ${product.link}`);
    });
  } else {
    console.error('❌ Error:', data.error);
  }
});

// Handle errors
socket.on('error', (data) => {
  console.error('❌ Socket error:', data.message);
});
```

## 🏗️ Architecture

### Agent Flow

1. **Client sends message** → Socket.io receives `user_message` event
2. **Agent processes** → LangChain agent analyzes the query
3. **Tool execution** → Agent decides to use `search_shopee` tool
4. **Scraping** → Puppeteer scrapes Shopee.vn for products
5. **Response generation** → Agent formats results with AI
6. **Stream back** → Results streamed via Socket.io to client

### Key Components

#### 1. **Shopping Agent** (`src/agents/shoppingAgent.ts`)
- LangChain agent with OpenAI GPT-4o
- Custom tool for Shopee search
- Streams status updates via Socket.io

#### 2. **Shopee Scraper** (`src/tools/shopeeScraper.ts`)
- Puppeteer with stealth plugin
- Anti-bot detection bypass (basic)
- Extracts: name, price, rating, image, link
- Fallback to mock data on failure

#### 3. **Socket Service** (`src/services/socketService.ts`)
- Manages Socket.io connections
- Handles message routing
- Broadcasts updates to clients

#### 4. **Currency Utilities** (`src/tools/currency.ts`)
- Format Vietnamese Dong (₫)
- Parse price strings
- Handle various price formats

## 🧪 Testing

### Test the Server
```bash
curl http://localhost:3000/health
```

### Test Socket.io Connection
Use the provided example in the "Socket.io Flow Example" section above, or use tools like:
- [Socket.io Client Tool](https://amritb.github.io/socketio-client-tool/)
- Postman (with WebSocket support)

## 🔧 Configuration

Edit `.env` to customize:

```env
# Server
PORT=3000
NODE_ENV=development

# OpenAI
OPENAI_API_KEY=sk-your-key
AGENT_MODEL=gpt-4o
AGENT_TEMPERATURE=0.7

# Scraping
PUPPETEER_HEADLESS=true
PUPPETEER_TIMEOUT=30000
MAX_PRODUCTS_PER_SEARCH=5

# CORS (for Flutter app)
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
```

## 📝 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `3000` |
| `NODE_ENV` | Environment mode | `development` |
| `OPENAI_API_KEY` | OpenAI API key | **Required** |
| `AGENT_MODEL` | OpenAI model | `gpt-4o` |
| `AGENT_TEMPERATURE` | Model creativity (0-1) | `0.7` |
| `PUPPETEER_HEADLESS` | Run browser headless | `true` |
| `PUPPETEER_TIMEOUT` | Scraping timeout (ms) | `30000` |
| `MAX_PRODUCTS_PER_SEARCH` | Max products to return | `5` |
| `CORS_ORIGINS` | Allowed origins | `http://localhost:3000` |

## 🛠️ Development

### Scripts

```bash
npm run dev       # Start development server with auto-reload
npm run build     # Compile TypeScript to JavaScript
npm start         # Run production server
npm run lint      # Lint code with ESLint
npm run format    # Format code with Prettier
```

### Code Style

- **TypeScript Strict Mode** enabled
- **ESLint** for code quality
- **Prettier** for formatting
- Follow modular architecture patterns

## 🐛 Troubleshooting

### Issue: Puppeteer fails to launch

**Solution**: Install Chromium dependencies (Linux):
```bash
sudo apt-get install -y chromium-browser
```

### Issue: OpenAI API errors

**Solution**: 
1. Verify your API key in `.env`
2. Check your OpenAI account has credits
3. Ensure the model name is correct (`gpt-4o` or `gpt-3.5-turbo`)

### Issue: Socket.io connection refused

**Solution**:
1. Check CORS origins in `.env`
2. Verify the server is running
3. Test with `curl http://localhost:3000/health`

### Issue: Shopee scraping fails

**Note**: The scraper returns mock data when scraping fails, so the app won't crash. Check logs for details.

## 🔒 Security Notes

- Never commit `.env` file
- Keep OpenAI API key secure
- Use environment variables for sensitive data
- Enable rate limiting in production
- Validate and sanitize user inputs

## 📦 Dependencies

### Core
- **express**: Web framework
- **socket.io**: Real-time communication
- **langchain**: AI agent framework
- **@langchain/openai**: OpenAI integration

### Scraping
- **puppeteer**: Headless browser
- **puppeteer-extra**: Plugin system
- **puppeteer-extra-plugin-stealth**: Anti-detection
- **cheerio**: HTML parsing (optional)

### Utilities
- **typescript**: Type safety
- **dotenv**: Environment variables
- **cors**: Cross-origin support

## 📄 License

MIT License - Feel free to use this project for learning or commercial purposes.

## 🤝 Contributing

Contributions welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests

## 📞 Support

For issues or questions:
1. Check the troubleshooting section
2. Review the code comments
3. Open an issue on GitHub

---

**Built with ❤️ for the Vietnamese E-commerce Market**

🇻🇳 Made for Shopee.vn • Tiki.vn • And more...
