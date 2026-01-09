/**
 * Simple Socket.io Test Client
 * 
 * This script tests the Socket.io connection and agent functionality.
 * 
 * Usage:
 *   1. Make sure the server is running (npm run dev)
 *   2. Install socket.io-client if not already: npm install socket.io-client
 *   3. Run this script: node test-client.js
 */

const io = require('socket.io-client');

// Configuration
const SERVER_URL = 'http://localhost:3000';
const TEST_QUERY = 'Tìm iPhone 15 cho tôi';

console.log('🔌 Connecting to server:', SERVER_URL);
console.log('📝 Test query:', TEST_QUERY);
console.log('─'.repeat(60));

// Connect to Socket.io server
const socket = io(SERVER_URL, {
  transports: ['websocket', 'polling'],
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionAttempts: 3,
});

// Connection successful
socket.on('connected', (data) => {
  console.log('✅ Connected to server!');
  console.log('   Socket ID:', data.socketId);
  console.log('   Message:', data.message);
  console.log('─'.repeat(60));

  // Send test query after connection
  setTimeout(() => {
    console.log('\n📤 Sending query to agent...');
    socket.emit('user_message', {
      message: TEST_QUERY,
    });
  }, 500);
});

// Message received acknowledgment
socket.on('message_received', (data) => {
  console.log('✅ Message received by server');
  console.log('   Query:', data.message);
  console.log('   Time:', new Date(data.timestamp).toLocaleTimeString());
  console.log('─'.repeat(60));
});

// Agent status updates (thinking, searching, etc.)
socket.on('agent_status', (data) => {
  const icons = {
    thinking: '🤔',
    searching: '🔍',
    complete: '✅',
    error: '❌',
  };
  
  const icon = icons[data.status] || '💭';
  console.log(`${icon} Agent Status: ${data.message}`);
});

// Final agent response
socket.on('agent_response', (data) => {
  console.log('─'.repeat(60));
  console.log('\n🎉 AGENT RESPONSE RECEIVED\n');
  
  if (data.success) {
    console.log('✅ Success:', data.success);
    console.log('\n📝 Answer:');
    console.log(data.answer);
    
    if (data.products && data.products.length > 0) {
      console.log('\n📦 Products Found:', data.products.length);
      console.log('─'.repeat(60));
      
      data.products.forEach((product, idx) => {
        console.log(`\n${idx + 1}. ${product.name}`);
        console.log(`   💰 Price: ${product.price}`);
        if (product.shop) console.log(`   🏪 Shop: ${product.shop}`);
        if (product.rating) console.log(`   ⭐ Rating: ${product.rating}/5`);
        if (product.soldCount) console.log(`   📊 Sold: ${product.soldCount}`);
        console.log(`   🔗 Link: ${product.link}`);
      });
    } else {
      console.log('\n⚠️ No products found in response');
    }
  } else {
    console.log('❌ Error:', data.error);
  }
  
  console.log('\n' + '─'.repeat(60));
  console.log('✅ Test completed successfully!');
  console.log('─'.repeat(60));
  
  // Close connection and exit
  setTimeout(() => {
    socket.close();
    process.exit(0);
  }, 1000);
});

// Connection errors
socket.on('connect_error', (error) => {
  console.error('\n❌ Connection Error:', error.message);
  console.error('\n💡 Make sure the server is running:');
  console.error('   cd backend && npm run dev');
  process.exit(1);
});

// Socket errors
socket.on('error', (data) => {
  console.error('\n❌ Socket Error:', data.message);
  if (data.error) console.error('   Details:', data.error);
});

// Disconnection
socket.on('disconnect', (reason) => {
  console.log('\n🔌 Disconnected from server');
  console.log('   Reason:', reason);
});

// Handle script termination
process.on('SIGINT', () => {
  console.log('\n\n⚠️ Test interrupted by user');
  socket.close();
  process.exit(0);
});

// Timeout after 60 seconds
setTimeout(() => {
  console.error('\n❌ Test timeout after 60 seconds');
  socket.close();
  process.exit(1);
}, 60000);
