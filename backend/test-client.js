/**
 * Personal Finance AI Agent - Socket.io Test Client
 * 
 * This script tests the Socket.io connection and finance agent functionality.
 * 
 * Usage:
 *   1. Make sure MongoDB is running (mongod)
 *   2. Make sure the server is running (npm run dev)
 *   3. Install socket.io-client if not already: npm install socket.io-client
 *   4. Run this script: node test-client.js
 */

const io = require('socket.io-client');

// Configuration
const SERVER_URL = 'http://localhost:3000';
const TEST_QUERIES = [
  'Sáng nay ăn phở hết 50k',
  'Tháng này tôi tiêu bao nhiêu?',
  'Giá vàng SJC hôm nay thế nào?',
];
const TEST_QUERY = TEST_QUERIES[0]; // Change index to test different queries

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
  console.log('✅ Connected to Finance Agent!');
  console.log('   Socket ID:', data.socketId);
  console.log('   Message:', data.message);
  console.log('─'.repeat(60));
  console.log('\n💡 Available test queries:');
  TEST_QUERIES.forEach((q, i) => console.log(`   ${i + 1}. ${q}`));
  console.log('─'.repeat(60));

  // Send test query after connection
  setTimeout(() => {
    console.log(`\n📤 Sending query to agent: "${TEST_QUERY}"`);
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
  console.log('\n🎉 FINANCE AGENT RESPONSE\n');
  
  if (data.success) {
    console.log('✅ Success:', data.success);
    console.log('\n📝 Agent Answer:');
    console.log('─'.repeat(60));
    console.log(data.answer);
    console.log('─'.repeat(60));
  } else {
    console.log('❌ Error:', data.error);
    console.log('\n⚠️ Possible issues:');
    console.log('   - MongoDB not running');
    console.log('   - Google API key invalid');
    console.log('   - Network connection issue');
  }
  
  console.log('\n✅ Test completed!');
  console.log('─'.repeat(60));
  console.log('\n💡 Try these queries next:');
  TEST_QUERIES.forEach((q, i) => {
    if (q !== TEST_QUERY) console.log(`   - ${q}`);
  });
  console.log('   - "Tỷ giá USD bao nhiêu?"');
  console.log('   - "Hôm qua mua cafe 30k, ăn trưa 80k"');
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
