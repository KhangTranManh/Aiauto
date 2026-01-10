import mongoose, { Schema, Document } from 'mongoose';

/**
 * Transaction interface
 */
export interface ITransaction extends Document {
  userId: string;
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
const transactionSchema = new Schema<ITransaction>({
  userId: {
    type: String,
    required: true,
    index: true,
  },
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
transactionSchema.index({ userId: 1, date: 1 });
transactionSchema.index({ category: 1 });
transactionSchema.index({ merchant: 1 });

export const Transaction = mongoose.model<ITransaction>('Transaction', transactionSchema);
