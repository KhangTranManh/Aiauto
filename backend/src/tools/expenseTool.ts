import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import { Transaction, ITransaction } from '../database/db';

/**
 * Add expense tool
 */
export function createAddExpenseTool() {
  return new DynamicStructuredTool({
    name: 'add_expense',
    description:
      'Adds a new expense transaction to the database. ' +
      'Use when user mentions spending money. ' +
      'Examples: "Sáng nay ăn phở hết 50k", "Mua cafe 30 nghìn".',
    schema: z.object({
      amount: z.number().positive().describe('Amount in VND. "50k" = 50000, "30 nghìn" = 30000'),
      category: z.string().describe('Category: Food, Transport, Shopping, Entertainment, Bills, Health, Other'),
      note: z.string().optional().describe('Additional note'),
      date: z.string().describe('Date in YYYY-MM-DD format'),
    }),
    func: async ({ amount, category, note, date }) => {
      console.log(`💰 Adding expense: ${amount} VND - ${category}`);

      try {
        const transaction = await Transaction.create({
          amount,
          category,
          note: note || '',
          date,
        });

        return JSON.stringify({
          success: true,
          message: `Đã lưu chi tiêu: ${amount.toLocaleString('vi-VN')}đ cho ${category}`,
          id: transaction._id,
        });
      } catch (error) {
        return JSON.stringify({
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    },
  });
}

/**
 * Get monthly expenses tool
 */
export function createGetMonthlyExpensesTool() {
  return new DynamicStructuredTool({
    name: 'get_monthly_expenses',
    description:
      'Gets expense summary for a specific month. ' +
      'Use when user asks: "Tháng này tiêu bao nhiêu?", "Chi tiêu tháng 10".',
    schema: z.object({
      year: z.number().int().min(2020).max(2030).describe('Year (e.g., 2026)'),
      month: z.number().int().min(1).max(12).describe('Month (1-12)'),
    }),
    func: async ({ year, month }) => {
      console.log(`📊 Getting expenses for ${month}/${year}`);

      try {
        const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
        const endDate = `${year}-${String(month).padStart(2, '0')}-31`;

        const transactions = await Transaction.find({
          date: { $gte: startDate, $lte: endDate },
        }).sort({ date: -1 });

        const total = transactions.reduce((sum, t) => sum + t.amount, 0);

        // Group by category
        const summary: { [key: string]: { total: number; count: number } } = {};
        transactions.forEach(t => {
          if (!summary[t.category]) {
            summary[t.category] = { total: 0, count: 0 };
          }
          summary[t.category].total += t.amount;
          summary[t.category].count += 1;
        });

        return JSON.stringify({
          success: true,
          period: `${month}/${year}`,
          total,
          totalFormatted: `${total.toLocaleString('vi-VN')}đ`,
          transactionCount: transactions.length,
          summary: Object.entries(summary).map(([category, data]) => ({
            category,
            total: data.total,
            totalFormatted: `${data.total.toLocaleString('vi-VN')}đ`,
            count: data.count,
          })),
          recentTransactions: transactions.slice(0, 5),
        });
      } catch (error) {
        return JSON.stringify({
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    },
  });
}

/**
 * Get expense statistics tool
 */
export function createGetExpenseStatsTool() {
  return new DynamicStructuredTool({
    name: 'get_expense_stats',
    description:
      'Gets detailed expense statistics. ' +
      'Use when user asks: "Phân tích chi tiêu", "Tôi tiêu nhiều nhất vào gì?".',
    schema: z.object({
      year: z.number().int().describe('Year to analyze'),
      month: z.number().int().min(1).max(12).describe('Month to analyze'),
    }),
    func: async ({ year, month }) => {
      console.log(`📈 Getting statistics for ${month}/${year}`);

      try {
        const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
        const endDate = `${year}-${String(month).padStart(2, '0')}-31`;

        const transactions = await Transaction.find({
          date: { $gte: startDate, $lte: endDate },
        });

        const total = transactions.reduce((sum, t) => sum + t.amount, 0);

        const summary: { [key: string]: { total: number; count: number } } = {};
        transactions.forEach(t => {
          if (!summary[t.category]) {
            summary[t.category] = { total: 0, count: 0 };
          }
          summary[t.category].total += t.amount;
          summary[t.category].count += 1;
        });

        const categoriesWithPercentage = Object.entries(summary)
          .map(([category, data]) => ({
            category,
            total: data.total,
            totalFormatted: `${data.total.toLocaleString('vi-VN')}đ`,
            count: data.count,
            percentage: total > 0 ? ((data.total / total) * 100).toFixed(1) : 0,
          }))
          .sort((a, b) => b.total - a.total);

        const topCategory = categoriesWithPercentage[0];

        return JSON.stringify({
          success: true,
          period: `${month}/${year}`,
          total,
          totalFormatted: `${total.toLocaleString('vi-VN')}đ`,
          categories: categoriesWithPercentage,
          topCategory,
          insights: topCategory
            ? `Bạn chi tiêu nhiều nhất cho ${topCategory.category} với ${topCategory.totalFormatted} (${topCategory.percentage}%)`
            : 'Chưa có dữ liệu chi tiêu',
        });
      } catch (error) {
        return JSON.stringify({
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    },
  });
}

/**
 * Delete expense tool
 */
export function createDeleteExpenseTool() {
  return new DynamicStructuredTool({
    name: 'delete_expense',
    description:
      'Deletes expense transaction(s) from the database. ' +
      'Use when user wants to remove/delete transactions. ' +
      'Examples: "Xóa giao dịch cuối", "Xóa chi tiêu Food", "Xóa hết".',
    schema: z.object({
      category: z.string().optional().describe('Delete by category (Food, Transport, etc.). Leave empty to delete recent.'),
      deleteAll: z.boolean().optional().describe('Set true to delete ALL transactions. Use carefully!'),
      limit: z.number().int().positive().optional().default(1).describe('Number of transactions to delete (default: 1, most recent)'),
    }),
    func: async ({ category, deleteAll, limit = 1 }) => {
      console.log(`🗑️ Delete request - category: ${category}, deleteAll: ${deleteAll}, limit: ${limit}`);

      try {
        if (deleteAll) {
          const result = await Transaction.deleteMany({});
          return JSON.stringify({
            success: true,
            message: `Đã xóa tất cả ${result.deletedCount} giao dịch`,
            deletedCount: result.deletedCount,
          });
        }

        if (category) {
          // Delete by category (most recent first)
          const transactions = await Transaction.find({ category })
            .sort({ date: -1 })
            .limit(limit);

          if (transactions.length === 0) {
            return JSON.stringify({
              success: false,
              message: `Không tìm thấy giao dịch ${category}`,
            });
          }

          const ids = transactions.map(t => t._id);
          const result = await Transaction.deleteMany({ _id: { $in: ids } });

          return JSON.stringify({
            success: true,
            message: `Đã xóa ${result.deletedCount} giao dịch ${category}`,
            deletedCount: result.deletedCount,
          });
        }

        // Delete most recent transaction(s)
        const transactions = await Transaction.find()
          .sort({ date: -1, _id: -1 })
          .limit(limit);

        if (transactions.length === 0) {
          return JSON.stringify({
            success: false,
            message: 'Không có giao dịch nào để xóa',
          });
        }

        const ids = transactions.map(t => t._id);
        const result = await Transaction.deleteMany({ _id: { $in: ids } });

        return JSON.stringify({
          success: true,
          message: `Đã xóa ${result.deletedCount} giao dịch gần nhất`,
          deletedCount: result.deletedCount,
          deleted: transactions.map(t => ({
            category: t.category,
            amount: t.amount,
            note: t.note,
          })),
        });
      } catch (error) {
        return JSON.stringify({
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    },
  });
}
