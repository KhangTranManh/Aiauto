# 🚀 Quick Setup Guide

## Step-by-Step Installation

### 1️⃣ Install Dependencies

Open terminal in the `backend` folder and run:

```bash
npm install
```

This will install all required packages including:
- Express & Socket.io for the server
- LangChain & OpenAI for the AI agent
- Puppeteer for web scraping
- TypeScript and development tools

**Expected time:** 2-3 minutes

---

### 2️⃣ Configure Environment Variables

The `.env` file has been created for you with default values. You MUST add your OpenAI API key:

1. Open the `.env` file in this folder
2. Replace `your_openai_api_key_here` with your actual OpenAI API key
3. Get your API key from: https://platform.openai.com/api-keys

Example:
```env
OPENAI_API_KEY=sk-proj-abc123xyz...
```

**Important:** Keep your API key secret! Never commit it to version control.

---

### 3️⃣ Start the Development Server

Run the server with auto-reload:

```bash
npm run dev
```

You should see output like:

```
============================================================
🚀 AI Shopping Agent Server Started Successfully!
============================================================
🔧 Configuration loaded:
   - Environment: development
   - Port: 3000
   - OpenAI Model: gpt-4o
   - Puppeteer Headless: true
   - CORS Origins: http://localhost:3000, http://localhost:8080
============================================================
🌐 Server running at: http://localhost:3000
🔌 Socket.io ready for connections
📊 Health check: http://localhost:3000/health
============================================================

💡 Waiting for client connections...
```

---

### 4️⃣ Test the Server

#### Option A: Test with curl (HTTP)

Open a new terminal and run:

```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2026-01-09T...",
  "uptime": 12.34,
  "environment": "development"
}
```

#### Option B: Test with Socket.io Client

Create a simple test file `test-client.js` in the backend folder:

```javascript
const io = require('socket.io-client');

const socket = io('http://localhost:3000');

socket.on('connected', (data) => {
  console.log('✅ Connected:', data);
  
  // Send a test message
  socket.emit('user_message', {
    message: 'Tìm iPhone 15 cho tôi'
  });
});

socket.on('agent_status', (data) => {
  console.log('🤖 Status:', data.message);
});

socket.on('agent_response', (data) => {
  console.log('\n✅ Agent Response:');
  console.log('Answer:', data.answer);
  
  if (data.products) {
    console.log('\n📦 Products Found:');
    data.products.forEach((product, idx) => {
      console.log(`\n${idx + 1}. ${product.name}`);
      console.log(`   Price: ${product.price}`);
      console.log(`   Link: ${product.link}`);
    });
  }
  
  process.exit(0);
});

socket.on('error', (data) => {
  console.error('❌ Error:', data);
});
```

Run it:
```bash
node test-client.js
```

---

### 5️⃣ Integration with Flutter App

Your Flutter app should connect to:

```
Socket URL: http://localhost:3000
```

Or if running on a physical device, replace `localhost` with your computer's IP address:

```
Socket URL: http://192.168.1.100:3000
```

To find your IP:
- **Windows:** `ipconfig` (look for IPv4 Address)
- **Mac/Linux:** `ifconfig` or `ip addr`

---

## 🎯 Common Use Cases

### Send a Search Query

```javascript
socket.emit('user_message', {
  message: 'Tìm laptop gaming giá rẻ'
});
```

### Listen for Updates

```javascript
// Real-time status
socket.on('agent_status', (data) => {
  // data.status: 'thinking', 'searching', 'complete', 'error'
  // data.message: Vietnamese status message
});

// Final response
socket.on('agent_response', (data) => {
  // data.success: boolean
  // data.answer: AI-generated response
  // data.products: Array of products (if found)
});
```

---

## 🐛 Troubleshooting

### Error: "Missing required environment variables: OPENAI_API_KEY"

**Solution:** Add your OpenAI API key to the `.env` file.

### Error: "Cannot find module 'xyz'"

**Solution:** Run `npm install` again to ensure all dependencies are installed.

### Error: Port 3000 is already in use

**Solution:** Change the PORT in `.env` to another port (e.g., 3001).

### Puppeteer fails to launch on Linux

**Solution:** Install Chromium dependencies:
```bash
sudo apt-get install -y chromium-browser
```

### OpenAI API rate limit errors

**Solution:** 
- Check your OpenAI account has credits
- Consider using `gpt-3.5-turbo` instead of `gpt-4o` (cheaper)
- Change `AGENT_MODEL=gpt-3.5-turbo` in `.env`

---

## 📝 Development Tips

### View Logs

The server logs all activity to the console. Watch for:
- `🔍` Shopee search started
- `🛠️` Tool called by agent
- `✅` Successful operations
- `❌` Errors

### Debug Mode

To see the browser during scraping, set in `.env`:
```env
PUPPETEER_HEADLESS=false
```

### Hot Reload

The `npm run dev` command uses `ts-node-dev` for auto-reload. Any changes to `.ts` files will automatically restart the server.

---

## 🚢 Production Deployment

### Build for Production

```bash
npm run build
```

This compiles TypeScript to JavaScript in the `dist/` folder.

### Run Production Server

```bash
npm start
```

### Environment Variables for Production

Update `.env` for production:

```env
NODE_ENV=production
PORT=3000
PUPPETEER_HEADLESS=true
CORS_ORIGINS=https://your-flutter-app-domain.com
```

### Deploy to Cloud

Recommended platforms:
- **Railway**: Auto-deploy from Git
- **Render**: Free tier available
- **Heroku**: Easy setup
- **AWS/Azure/GCP**: Full control

Make sure to:
1. Set environment variables in your hosting platform
2. Install Chromium for Puppeteer
3. Configure CORS for your domain

---

## 📞 Need Help?

- Check the main [README.md](README.md) for detailed documentation
- Review code comments in each file
- Test individual components before integrating

---

**Happy Coding! 🎉**
