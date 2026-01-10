# 📊 Expense Forecasting API - Usage Guide

## 🎯 Overview
The Expense Forecasting API uses **linear regression** to predict your end-of-month spending based on your current transactions.

---

## 🚀 How It Works

### Step-by-Step Process:

1. **Query Current Month Data**: Gets all transactions from day 1 to today
2. **Group by Day**: Calculates cumulative spending per day
   - Day 1: 100,000 đ
   - Day 2: 250,000 đ (100k + 150k)
   - Day 3: 400,000 đ (250k + 150k)
3. **Linear Regression**: Finds the trend line `y = mx + c`
   - Uses `simple-statistics` library
   - Creates a mathematical model of your spending pattern
4. **Predict End of Month**: Uses the equation to forecast total spending on the last day
5. **Compare with Budget**: Checks against 10 million VND budget
   - **Safe**: < 80% of budget
   - **Warning**: 80-99% of budget
   - **Danger**: ≥ 100% of budget

---

## 📡 API Endpoint

### GET /api/forecast

**Request:**
```bash
GET http://localhost:3000/api/forecast
```

**Response Example:**
```json
{
  "success": true,
  "forecast": {
    "current_date": 10,
    "current_spent": 2500000,
    "predicted_total": 7500000,
    "safety_status": "Safe",
    "message": "✅ AN TOÀN: Với tốc độ này, cuối tháng bạn sẽ chi 7.5 triệu. Còn dư 2.5 triệu.",
    "chart_data": [
      { "day": 1, "amount": 100000 },
      { "day": 2, "amount": 250000 },
      { "day": 3, "amount": 400000 },
      { "day": 4, "amount": 600000 },
      { "day": 5, "amount": 850000 },
      { "day": 6, "amount": 1100000 },
      { "day": 7, "amount": 1400000 },
      { "day": 8, "amount": 1800000 },
      { "day": 9, "amount": 2100000 },
      { "day": 10, "amount": 2500000 }
    ],
    "budget": 10000000,
    "days_in_month": 31
  }
}
```

---

## 🧪 Testing Methods

### Method 1: Using Postman
1. Open Postman
2. Create new GET request: `http://localhost:3000/api/forecast`
3. Click "Send"
4. View the forecast results

### Method 2: Using Browser
Simply visit: `http://localhost:3000/api/forecast`

### Method 3: Using cURL
```bash
curl http://localhost:3000/api/forecast
```

### Method 4: Using Node.js Test Script
```bash
cd d:\bottrade\Aiauto\backend
node test-forecast.js
```

### Method 5: Using Thunder Client (VS Code Extension)
1. Install Thunder Client extension
2. New Request → GET
3. URL: `http://localhost:3000/api/forecast`
4. Send

---

## 💡 Response Fields Explained

| Field | Type | Description |
|-------|------|-------------|
| `current_date` | number | Today's day of the month (1-31) |
| `current_spent` | number | Total spent so far this month (VND) |
| `predicted_total` | number | Forecasted total by month end (VND) |
| `safety_status` | string | "Safe", "Warning", or "Danger" |
| `message` | string | Human-readable Vietnamese message |
| `chart_data` | array | Daily cumulative spending data for charts |
| `budget` | number | Monthly budget (default: 10,000,000 VND) |
| `days_in_month` | number | Total days in current month (28-31) |

---

## 📊 Safety Status Logic

```javascript
if (predicted >= budget) {
  status = "Danger"  // 🔴 Over budget
  message = "⚠️ CẢNH BÁO: Vượt ngân sách!"
}
else if (predicted >= budget * 0.8) {
  status = "Warning"  // 🟡 Close to budget
  message = "⚡ CHÚ Ý: Đang chi tiêu nhanh"
}
else {
  status = "Safe"  // 🟢 Under budget
  message = "✅ AN TOÀN: Còn dư tiền"
}
```

---

## 🎨 Example Scenarios

### Scenario 1: Early Month (Few Transactions)
```json
{
  "current_date": 3,
  "current_spent": 500000,
  "predicted_total": 5000000,
  "safety_status": "Safe",
  "message": "✅ AN TOÀN: Với tốc độ này, cuối tháng bạn sẽ chi 5.0 triệu. Còn dư 5.0 triệu."
}
```

### Scenario 2: Mid-Month (Warning)
```json
{
  "current_date": 15,
  "current_spent": 6500000,
  "predicted_total": 8700000,
  "safety_status": "Warning",
  "message": "⚡ CHÚ Ý: Bạn đang chi tiêu nhanh. Dự đoán cuối tháng: 8.7 triệu (87% ngân sách)."
}
```

### Scenario 3: Late Month (Danger)
```json
{
  "current_date": 20,
  "current_spent": 8000000,
  "predicted_total": 12400000,
  "safety_status": "Danger",
  "message": "⚠️ CẢNH BÁO: Với tốc độ này, cuối tháng bạn sẽ chi tiêu 12.4 triệu, vượt ngân sách 2.4 triệu!"
}
```

### Scenario 4: No Transactions Yet
```json
{
  "current_date": 1,
  "current_spent": 0,
  "predicted_total": 0,
  "safety_status": "Safe",
  "message": "Chưa có giao dịch nào trong tháng này.",
  "chart_data": []
}
```

---

## 🔧 How to Change Budget

Currently hardcoded to **10,000,000 VND**. To change:

**Edit `src/services/forecastService.ts`:**
```typescript
// Line ~110
const budget = 15000000; // Change to 15 million VND
```

**Future Enhancement**: Make it dynamic per user via API parameter:
```
GET /api/forecast?budget=15000000
```

---

## 📈 Chart Data Usage

The `chart_data` array can be used to create a visual chart in your Flutter app:

```dart
// Flutter example
List<FlSpot> spots = forecast['chart_data']
  .map((data) => FlSpot(
    data['day'].toDouble(),
    data['amount'].toDouble(),
  ))
  .toList();
```

This creates a **cumulative spending curve** showing spending trend over the month.

---

## 🐛 Troubleshooting

### Error: "Cannot find module 'simple-statistics'"
**Solution:**
```bash
cd d:\bottrade\Aiauto\backend
npm install
```

### Error: "No transactions found"
**Cause:** No data in database for current month
**Solution:** Add some test transactions first:
```bash
# Use the chat or receipt scanner to add transactions
POST http://localhost:3000/api/scan-receipt
```

### Prediction seems wrong
**Cause:** Not enough data (< 2 days)
**How it works:**
- < 2 days of data: Uses simple average
- ≥ 2 days: Uses linear regression for accuracy

---

## 🎯 Integration with Flutter

Add to `api_service.dart`:
```dart
Future<Map<String, dynamic>> getForecast() async {
  try {
    final response = await _dio.get('/forecast');
    return response.data['forecast'];
  } catch (e) {
    throw Exception('Failed to get forecast: $e');
  }
}
```

Create a new screen:
```dart
class ForecastScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService().getForecast(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final forecast = snapshot.data!;
          return Column(
            children: [
              Text('Dự đoán: ${forecast['predicted_total']} VND'),
              Text(forecast['message']),
              // Add chart here using fl_chart
            ],
          );
        }
        return CircularProgressIndicator();
      },
    );
  }
}
```

---

## 📝 Notes

1. **Linear Regression Assumptions:**
   - Assumes spending pattern continues linearly
   - Works best with consistent daily spending
   - May be less accurate with irregular patterns (big one-time purchases)

2. **Data Requirements:**
   - Minimum: 1 transaction
   - Recommended: 5+ days of data for accurate predictions
   - Best: 10+ days with regular transactions

3. **Currency Format:**
   - All amounts in Vietnamese Dong (VND)
   - No decimal places (whole numbers)

4. **Timezone:**
   - Uses server's local timezone
   - Considers transactions up to 23:59:59 today

---

## 🚀 Quick Start

1. **Start backend:**
```bash
cd d:\bottrade\Aiauto\backend
npm run dev
```

2. **Add some test transactions** (via chat or receipt scanner)

3. **Test the forecast:**
```bash
# Browser
http://localhost:3000/api/forecast

# OR cURL
curl http://localhost:3000/api/forecast
```

4. **Check the prediction!** 📊

---

## 📊 Mathematical Details

**Linear Regression Formula:**
```
y = mx + c

where:
y = cumulative spending
x = day of month
m = slope (daily spending rate)
c = y-intercept (starting amount)
```

**Prediction:**
```
predicted_total = m * (last_day_of_month) + c
```

**Example:**
- Day 5: 1,000,000 đ
- Day 10: 2,000,000 đ
- Slope (m) = 200,000 đ/day
- Prediction for day 30 = 200,000 * 30 + 0 = 6,000,000 đ

---

## ✅ Ready to Use!

Your forecast API is now live at: `http://localhost:3000/api/forecast`

Test it and watch it predict your spending! 🎯📈
