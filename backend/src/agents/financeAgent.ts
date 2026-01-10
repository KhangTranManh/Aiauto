import { ChatGoogleGenerativeAI } from '@langchain/google-genai';
import { ChatOllama } from '@langchain/ollama';
import { HumanMessage, SystemMessage, AIMessage, ToolMessage } from '@langchain/core/messages';
import { Socket } from 'socket.io';
import { config } from '../config';
import {
  createAddExpenseTool,
  createGetMonthlyExpensesTool,
  createGetExpenseStatsTool,
  createDeleteExpenseTool,
} from '../tools/expenseTool';
import {
  createBtcPriceTool,
  createUsdRateTool,
  createMarketInfoTool,
} from '../tools/marketTool';

export interface AgentResponse {
  success: boolean;
  answer: string;
  error?: string;
}

function getSystemPrompt(): string {
  return `Bạn là trợ lý tài chính thông minh giúp người Việt quản lý chi tiêu.

Khả năng:
1. Ghi nhận chi tiêu
2. Xem báo cáo chi tiêu theo tháng
3. Xóa giao dịch
4. Tra cứu giá Bitcoin, tỷ giá USD

Hướng dẫn:
- "50k" = 50000, "30 nghìn" = 30000
- "hôm nay" = ${new Date().toISOString().split('T')[0]}
- "tháng này" = ${new Date().getMonth() + 1}/${new Date().getFullYear()}
- Phân loại: Food, Transport, Shopping, Entertainment, Bills, Health

Ngày hiện tại: ${new Date().toLocaleDateString('vi-VN')}

Bạn có các công cụ sau:
1. add_expense - Thêm chi tiêu mới
2. get_monthly_expenses - Xem chi tiêu theo tháng
3. get_expense_stats - Thống kê chi tiêu
4. delete_expense - Xóa giao dịch
5. get_btc_price - Xem giá Bitcoin
6. get_usd_rate - Xem tỷ giá USD
7. get_market_info - Thông tin thị trường tổng hợp

Hãy trả lời ngắn gọn, thân thiện bằng tiếng Việt.`;
}

async function initializeModel() {
  if (config.ai.provider === 'ollama') {
    console.log(`🤖 Using Ollama: ${config.ai.model} at ${config.ai.ollamaBaseUrl}`);
    return new ChatOllama({
      model: config.ai.model,
      baseUrl: config.ai.ollamaBaseUrl,
      temperature: config.ai.temperature,
    });
  } else {
    console.log(`🤖 Using Google Gemini: ${config.ai.model}`);
    return new ChatGoogleGenerativeAI({
      model: config.ai.model,
      temperature: config.ai.temperature,
      apiKey: config.google.apiKey,
    });
  }
}

async function handleToolCall(toolName: string, args: any): Promise<string> {
  const tools: { [key: string]: any } = {
    add_expense: createAddExpenseTool(),
    get_monthly_expenses: createGetMonthlyExpensesTool(),
    get_expense_stats: createGetExpenseStatsTool(),
    delete_expense: createDeleteExpenseTool(),
    get_btc_price: createBtcPriceTool(),
    get_usd_rate: createUsdRateTool(),
    get_market_info: createMarketInfoTool(),
  };

  const tool = tools[toolName];
  if (!tool) {
    return `Tool ${toolName} not found`;
  }

  try {
    const result = await tool.func(args);
    return typeof result === 'string' ? result : JSON.stringify(result);
  } catch (error) {
    return `Error executing ${toolName}: ${error}`;
  }
}

export async function runFinanceAgent(
  userQuery: string,
  socket: Socket
): Promise<AgentResponse> {
  try {
    console.log(`\n📨 User Query: "${userQuery}"`);

    socket.emit('agent_status', {
      status: 'thinking',
      message: 'Đang xử lý...',
    });

    const model = await initializeModel();
    
    // Create all tools
    const tools = [
      createAddExpenseTool(),
      createGetMonthlyExpensesTool(),
      createGetExpenseStatsTool(),
      createDeleteExpenseTool(),
      createBtcPriceTool(),
      createUsdRateTool(),
      createMarketInfoTool(),
    ];

    // Bind tools to model
    const modelWithTools = model.bindTools(tools);
    
    const messages: (SystemMessage | HumanMessage | AIMessage | ToolMessage)[] = [
      new SystemMessage(getSystemPrompt()),
      new HumanMessage(userQuery),
    ];

    // First model call
    let response = await modelWithTools.invoke(messages);
    
    // Handle tool calls if any
    if (response.tool_calls && response.tool_calls.length > 0) {
      console.log(`🔧 Tool calls detected: ${response.tool_calls.length}`);
      
      for (const toolCall of response.tool_calls) {
        console.log(`  → Calling: ${toolCall.name}`);
        const toolResult = await handleToolCall(toolCall.name, toolCall.args);
        console.log(`  ✓ Result: ${toolResult}`);
        
        // Add AI response and tool result to messages
        messages.push(new AIMessage(response));
        messages.push(
          new ToolMessage({
            content: toolResult,
            tool_call_id: toolCall.id || '',
          })
        );
      }
      
      // Get final response from model
      response = await modelWithTools.invoke(messages);
    }

    const answer = typeof response.content === 'string' 
      ? response.content 
      : JSON.stringify(response.content);

    console.log('✅ Agent Response:', answer);

    return {
      success: true,
      answer,
    };
  } catch (error) {
    console.error('❌ Agent error:', error);

    return {
      success: false,
      answer: 'Xin lỗi, đã có lỗi xảy ra khi xử lý yêu cầu.',
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}
