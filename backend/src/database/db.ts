import mongoose from 'mongoose';

/**
 * Transaction interface
 */
export interface ITransaction {
  amount: number;
  category: string;
  note: string;
  date: string;
  merchant?: string;
  rawText?: string;
  createdAt?: Date;
}

/**
 * Transaction Schema
 */
const transactionSchema = new mongoose.Schema<ITransaction>({
  amount: {
    type: Number,
    required: true,
  },
  category: {
    type: String,
    required: true,
  },
  note: {
    type: String,
    default: '',
  },
  date: {
    type: String,
    required: true,
  },
  merchant: {
    type: String,
    default: '',
  },
  rawText: {
    type: String,
    default: '',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

transactionSchema.index({ date: 1 });
transactionSchema.index({ category: 1 });
transactionSchema.index({ merchant: 1 });

export const Transaction = mongoose.model<ITransaction>('Transaction', transactionSchema);

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
