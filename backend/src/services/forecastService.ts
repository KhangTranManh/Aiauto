import { linearRegression, linearRegressionLine } from 'simple-statistics';
import { Transaction } from '../database/db';

interface DailySpending {
  day: number;
  amount: number;
}

interface ForecastResult {
  current_date: number;
  current_spent: number;
  predicted_total: number;
  safety_status: 'Safe' | 'Warning' | 'Danger';
  message: string;
  chart_data: DailySpending[];
  budget: number;
  days_in_month: number;
}

/**
 * Predict end-of-month spending using linear regression
 */
export async function predictEndOfMonth(_userId: string = 'default'): Promise<ForecastResult> {
  // Step A: Get current month transactions
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth(); // 0-indexed
  const currentDay = now.getDate();
  
  const startDate = new Date(year, month, 1); // First day of month
  const endDate = new Date(year, month + 1, 0); // Last day of month
  const daysInMonth = endDate.getDate();

  console.log(`📊 Forecasting for month ${month + 1}/${year} (Days: ${daysInMonth})`);

  // Query transactions for current month (date is stored as ISO string)
  const startDateStr = startDate.toISOString();
  const endDateStr = new Date(year, month, currentDay, 23, 59, 59).toISOString();

  const transactions = await Transaction.find({
    date: {
      $gte: startDateStr,
      $lte: endDateStr,
    },
  }).sort({ date: 1 });

  console.log(`📦 Found ${transactions.length} transactions`);

  if (transactions.length === 0) {
    // No data yet, return default forecast
    return {
      current_date: currentDay,
      current_spent: 0,
      predicted_total: 0,
      safety_status: 'Safe',
      message: 'Chưa có giao dịch nào trong tháng này.',
      chart_data: [],
      budget: 10000000, // 10 million VND default budget
      days_in_month: daysInMonth,
    };
  }

  // Step B: Group by day and calculate cumulative spending
  const dailySpending: Map<number, number> = new Map();
  
  transactions.forEach((tx: any) => {
    const txDate = new Date(tx.date);
    const txDay = txDate.getDate();
    const currentAmount = dailySpending.get(txDay) || 0;
    dailySpending.set(txDay, currentAmount + Math.abs(tx.amount));
  });

  // Create cumulative data points
  let cumulativeAmount = 0;
  const chartData: DailySpending[] = [];
  const regressionData: [number, number][] = [];

  for (let day = 1; day <= currentDay; day++) {
    const dayAmount = dailySpending.get(day) || 0;
    cumulativeAmount += dayAmount;
    
    chartData.push({ day, amount: cumulativeAmount });
    regressionData.push([day, cumulativeAmount]);
  }

  console.log(`📈 Cumulative spending data points: ${regressionData.length}`);

  // Step C: Calculate linear regression
  let predictedTotal: number;
  
  if (regressionData.length < 2) {
    // Not enough data for regression, use simple average
    const avgDailySpending = cumulativeAmount / currentDay;
    predictedTotal = avgDailySpending * daysInMonth;
    console.log('⚠️ Not enough data for regression, using average');
  } else {
    // Calculate linear regression: y = mx + c
    const regression = linearRegression(regressionData);
    const predict = linearRegressionLine(regression);
    
    // Step D: Predict spending at the last day of month
    predictedTotal = predict(daysInMonth);
    
    console.log(`📐 Regression: y = ${regression.m.toFixed(2)}x + ${regression.b.toFixed(2)}`);
    console.log(`🎯 Predicted total at day ${daysInMonth}: ${predictedTotal.toFixed(0)} VND`);
  }

  // Ensure predicted total is at least current spent
  predictedTotal = Math.max(predictedTotal, cumulativeAmount);

  // Step E: Compare with budget and generate warning
  const budget = 10000000; // 10 million VND
  const percentOfBudget = (predictedTotal / budget) * 100;
  
  let safetyStatus: 'Safe' | 'Warning' | 'Danger';
  let message: string;

  if (percentOfBudget >= 100) {
    safetyStatus = 'Danger';
    message = `⚠️ CẢNH BÁO: Với tốc độ này, cuối tháng bạn sẽ chi tiêu ${formatCurrency(predictedTotal)}, vượt ngân sách ${formatCurrency(budget - predictedTotal)}!`;
  } else if (percentOfBudget >= 80) {
    safetyStatus = 'Warning';
    message = `⚡ CHÚ Ý: Bạn đang chi tiêu nhanh. Dự đoán cuối tháng: ${formatCurrency(predictedTotal)} (${percentOfBudget.toFixed(0)}% ngân sách).`;
  } else {
    safetyStatus = 'Safe';
    message = `✅ AN TOÀN: Với tốc độ này, cuối tháng bạn sẽ chi ${formatCurrency(predictedTotal)}. Còn dư ${formatCurrency(budget - predictedTotal)}.`;
  }

  return {
    current_date: currentDay,
    current_spent: cumulativeAmount,
    predicted_total: Math.round(predictedTotal),
    safety_status: safetyStatus,
    message,
    chart_data: chartData,
    budget,
    days_in_month: daysInMonth,
  };
}

/**
 * Format currency to Vietnamese Dong
 */
function formatCurrency(amount: number): string {
  if (amount >= 1000000) {
    return `${(amount / 1000000).toFixed(1)} triệu`;
  } else if (amount >= 1000) {
    return `${(amount / 1000).toFixed(0)}k`;
  }
  return `${amount.toFixed(0)} đ`;
}
