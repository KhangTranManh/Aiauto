import mongoose from 'mongoose';

/**
 * Connect to MongoDB
 */
export async function connectDatabase(mongoUri?: string): Promise<void> {
  const uri = mongoUri || process.env.MONGODB_URI || 'mongodb://localhost:27017/finance-agent';

  try {
    await mongoose.connect(uri);
    console.log('✅ Connected to MongoDB:', uri);
  } catch (error) {
    console.error('❌ MongoDB connection error:', error);
    throw error;
  }
}

export async function disconnectDatabase(): Promise<void> {
  await mongoose.disconnect();
  console.log('✅ Disconnected from MongoDB');
}
