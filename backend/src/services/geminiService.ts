import { GoogleGenerativeAI } from '@google/generative-ai';
import { config } from '../config';

/**
 * Initialize Google Gemini AI model
 */
function initializeAIModel() {
  // Use Google Gemini only
  if (!config.google.apiKey) {
    throw new Error('Google API key not configured. Please add GOOGLE_API_KEY to .env');
  }
  
  console.log(`🤖 Using Google Gemini: ${config.google.model}`);
  const genAI = new GoogleGenerativeAI(config.google.apiKey);
  return genAI.getGenerativeModel({ model: config.google.model });
}

/**
 * Receipt scan result interface
 */
export interface ReceiptData {
  amount: number;
  category: string;
  merchant: string;
  date: string;
  rawText?: string;
}

/**
 * Scan receipt text and extract transaction data using Google Gemini AI
 * @param receiptText - Text content from the receipt
 * @returns Extracted receipt data
 */
export async function scanReceipt(receiptText: string): Promise<ReceiptData> {
  try {
    console.log(`📸 Scanning receipt text...`);

    // Initialize AI model
    const model = initializeAIModel();

    // Create the prompt
    const prompt = `Bạn PHẢI đọc và phân tích hóa đơn BÊN DƯỚI. KHÔNG được tự nghĩ, KHÔNG được dùng ví dụ mẫu.

CÁC BƯỚC PHÂN TÍCH:
1. Tìm số tiền lớn nhất (thường là tổng tiền): 150.000, 50000, 1.234.567 VNĐ, etc.
   → Chuyển thành số nguyên: bỏ dấu chấm/phẩy/khoảng trắng, bỏ "VND"/"đ"/"VNĐ"
   → Ví dụ: "150.000 VND" → 150000, "1.234.567đ" → 1234567
   
2. Tìm tên cửa hàng/ngân hàng/merchant: BIDV, Vinmart, Circle K, v.v.
   → Nếu không tìm thấy: "Unknown Merchant"
   
3. Phân loại category dựa trên nội dung:
   → Thực phẩm/đồ ăn/nước uống: "Food"
   → Vận chuyển/Grab/taxi/xăng: "Transport"
   → Mua sắm/quần áo/đồ dùng: "Shopping"
   → Giải trí/phim/game: "Entertainment"
   → Hóa đơn/điện/nước/internet: "Bills"
   → Y tế/thuốc/bệnh viện: "Health"
   → Khác: "Other"
   
4. Tìm ngày tháng (DD/MM/YYYY, YYYY-MM-DD): nếu không có dùng hôm nay ${new Date().toISOString().split('T')[0]}

5. Tóm tắt nội dung giao dịch vào rawText (1 câu ngắn)

===== NỘI DUNG HÓA ĐƠN (${receiptText.length} ký tự) =====
${receiptText}
===== KẾT THÚC =====

BẮT BUỘC: Dựa trên nội dung hóa đơn TRÊN để trích xuất, KHÔNG tự nghĩ ra số liệu.
Trả về CHỈ MỘT dòng JSON (không markdown, không giải thích):
{"amount":<số từ hóa đơn>,"category":"<phân loại>","merchant":"<tên từ hóa đơn>","date":"YYYY-MM-DD","rawText":"<tóm tắt>"}`;

    // Generate content
    const result = await model.generateContent(prompt);
    const response = result.response.text();

    console.log('📄 Receipt text:', receiptText.substring(0, 200) + '...');
    console.log('🤖 AI raw response:', response);

    // Parse the JSON response
    const receiptData = parseReceiptResponse(response);

    // Validate the data
    validateReceiptData(receiptData);

    console.log('✅ Receipt scanned successfully:', receiptData);
    return receiptData;

  } catch (error) {
    console.error('❌ Error scanning receipt:', error);
    throw new Error(
      error instanceof Error 
        ? `Receipt scan failed: ${error.message}` 
        : 'Receipt scan failed: Unknown error'
    );
  }
}

/**
 * Parse AI response and extract JSON
 */
function parseReceiptResponse(response: string): ReceiptData {
  try {
    // Remove any explanatory text before or after JSON
    let cleanResponse = response.trim();
    
    // Try to find JSON object in the response
    const jsonMatch = cleanResponse.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      cleanResponse = jsonMatch[0];
    }
    
    // Remove markdown code blocks if present
    cleanResponse = cleanResponse.replace(/^```json\s*\n?/i, '');
    cleanResponse = cleanResponse.replace(/^```\s*\n?/i, '');
    cleanResponse = cleanResponse.replace(/\n?```\s*$/i, '');
    cleanResponse = cleanResponse.trim();
    
    // Remove any text before the first {
    const firstBrace = cleanResponse.indexOf('{');
    if (firstBrace > 0) {
      cleanResponse = cleanResponse.substring(firstBrace);
    }
    
    // Remove any text after the last }
    const lastBrace = cleanResponse.lastIndexOf('}');
    if (lastBrace > 0 && lastBrace < cleanResponse.length - 1) {
      cleanResponse = cleanResponse.substring(0, lastBrace + 1);
    }

    console.log('🧹 Cleaned JSON:', cleanResponse);

    // Parse JSON
    const data = JSON.parse(cleanResponse);

    return {
      amount: parseFloat(data.amount),
      category: data.category || 'Other',
      merchant: data.merchant || 'Unknown Merchant',
      date: data.date || new Date().toISOString().split('T')[0],
      rawText: data.rawText || '',
    };
  } catch (error) {
    console.error('❌ Parse error:', error);
    console.error('Response was:', response);
    throw new Error('Failed to parse receipt data. AI response was not valid JSON.');
  }
}

/**
 * Validate extracted receipt data
 */
function validateReceiptData(data: ReceiptData): void {
  if (!data.amount || isNaN(data.amount) || data.amount <= 0) {
    throw new Error('Invalid amount extracted from receipt');
  }

  const validCategories = ['Food', 'Transport', 'Shopping', 'Entertainment', 'Bills', 'Health', 'Other'];
  if (!validCategories.includes(data.category)) {
    data.category = 'Other';
  }

  // Validate date format (YYYY-MM-DD)
  const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
  if (!dateRegex.test(data.date)) {
    const today = new Date().toISOString().split('T')[0];
    data.date = today || '';
  }
}
