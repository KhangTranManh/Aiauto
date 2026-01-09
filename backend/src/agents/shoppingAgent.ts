import { ChatGoogleGenerativeAI } from '@langchain/google-genai';
import { DynamicStructuredTool } from '@langchain/core/tools';
import { AgentExecutor, createOpenAIFunctionsAgent } from 'langchain/agents';
import { ChatPromptTemplate, MessagesPlaceholder } from '@langchain/core/prompts';
import { z } from 'zod';
import { Socket } from 'socket.io';
import { config } from '../config';
import { searchShopee, ShopeeProduct } from '../tools/shopeeScraper';

/**
 * Agent response interface
 */
export interface AgentResponse {
  success: boolean;
  answer: string;
  products?: ShopeeProduct[];
  error?: string;
}

/**
 * Create the Shopee search tool for the agent
 */
function createShopeeTool() {
  return new DynamicStructuredTool({
    name: 'search_shopee',
    description: 
      'Searches for products on Shopee.vn, the leading e-commerce platform in Vietnam. ' +
      'Use this tool when the user asks to find, search, or look for products. ' +
      'Input should be a search query in Vietnamese or English (e.g., "điện thoại iPhone 15" or "Samsung Galaxy S24").',
    schema: z.object({
      query: z.string().describe('The search query to find products on Shopee'),
    }),
    func: async ({ query }) => {
      console.log(`🛠️ Tool called: search_shopee with query: "${query}"`);
      
      const result = await searchShopee(query);
      
      if (!result.success) {
        return JSON.stringify({
          error: result.message,
          products: result.products, // Include mock data
        });
      }

      // Format products for the agent
      const productsFormatted = result.products.map((p, idx) => ({
        position: idx + 1,
        name: p.name,
        price: p.price,
        shop: p.shop,
        rating: p.rating,
        soldCount: p.soldCount,
        link: p.link,
      }));

      return JSON.stringify({
        products: productsFormatted,
        totalFound: result.products.length,
        timestamp: result.timestamp,
      });
    },
  });
}

/**
 * Create the agent prompt template
 */
function createAgentPrompt() {
  return ChatPromptTemplate.fromMessages([
    [
      'system',
      `You are an intelligent Vietnamese shopping assistant specialized in helping users find products on Shopee.vn.

Your capabilities:
- Search for products on Shopee.vn using the search_shopee tool
- Provide product recommendations based on price, ratings, and popularity
- Compare products and help users make informed decisions
- Answer questions about Vietnamese e-commerce

Guidelines:
1. Always greet users warmly in Vietnamese style
2. When users ask for products, use the search_shopee tool
3. Present results clearly with product names, prices, ratings, and links
4. If a search fails, apologize and suggest alternative keywords
5. Be conversational and helpful
6. Format prices in Vietnamese Dong (₫)
7. Use emojis to make responses friendly: 🛒 📱 💰 ⭐

Example interactions:
- User: "Tìm iPhone 15 cho tôi"
  You: Use search_shopee("iPhone 15") and present the top results
  
- User: "Laptop gaming giá rẻ"
  You: Use search_shopee("laptop gaming giá rẻ") and show products under certain price range

Current date: ${new Date().toLocaleDateString('vi-VN')}`,
    ],
    ['human', '{input}'],
    new MessagesPlaceholder('agent_scratchpad'),
  ]);
}

/**
 * Initialize the LangChain agent
 */
async function initializeAgent() {
  // Initialize Google Gemini model
  const model = new ChatGoogleGenerativeAI({
    modelName: config.agent.model,
    temperature: config.agent.temperature,
    apiKey: config.google.apiKey,
  });

  // Create tools
  const tools = [createShopeeTool()];

  // Create prompt
  const prompt = createAgentPrompt();

  // Create agent
  const agent = await createOpenAIFunctionsAgent({
    llm: model,
    tools,
    prompt,
  });

  // Create executor
  const executor = new AgentExecutor({
    agent,
    tools,
    verbose: true, // Log agent thoughts in development
    maxIterations: 5, // Prevent infinite loops
    returnIntermediateSteps: true, // Get intermediate reasoning steps
  });

  return executor;
}

/**
 * Run the shopping agent with a user query
 * Streams thoughts and results via Socket.io
 * 
 * @param userQuery - The user's question or request
 * @param socket - Socket.io socket for real-time communication
 * @returns AgentResponse with the final answer
 */
export async function runAgent(
  userQuery: string,
  socket: Socket
): Promise<AgentResponse> {
  try {
    console.log(`🤖 Agent starting for query: "${userQuery}"`);

    // Emit thinking status
    socket.emit('agent_status', {
      status: 'thinking',
      message: 'Đang suy nghĩ...',
    });

    // Initialize agent
    const executor = await initializeAgent();

    // Track intermediate steps
    let toolUsed = false;
    let productsFound: ShopeeProduct[] = [];

    // Execute agent
    const result = await executor.invoke({
      input: userQuery,
    });

    // Parse intermediate steps to extract products
    if (result.intermediateSteps && Array.isArray(result.intermediateSteps)) {
      for (const step of result.intermediateSteps) {
        const action = step.action;
        const observation = step.observation;

        // Emit tool usage to client
        if (action && action.tool === 'search_shopee') {
          toolUsed = true;
          socket.emit('agent_status', {
            status: 'searching',
            message: `Đang tìm kiếm "${action.toolInput.query}" trên Shopee...`,
          });
        }

        // Try to extract products from observation
        try {
          const parsed = JSON.parse(observation);
          if (parsed.products && Array.isArray(parsed.products)) {
            // Get the full product data from the scraper result
            const scrapeResult = await searchShopee(action.toolInput.query, 5);
            productsFound = scrapeResult.products;
          }
        } catch {
          // Observation is not JSON, skip
        }
      }
    }

    // Emit completion status
    socket.emit('agent_status', {
      status: 'complete',
      message: 'Hoàn thành!',
    });

    console.log(`✅ Agent completed successfully`);

    // Return final response
    return {
      success: true,
      answer: result.output,
      products: productsFound.length > 0 ? productsFound : undefined,
    };
  } catch (error) {
    console.error('❌ Agent error:', error);

    // Emit error status
    socket.emit('agent_status', {
      status: 'error',
      message: 'Đã xảy ra lỗi khi xử lý yêu cầu',
    });

    return {
      success: false,
      answer: 'Xin lỗi, tôi gặp sự cố khi xử lý yêu cầu của bạn. Vui lòng thử lại.',
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Test function to verify agent setup
 */
export async function testAgent(): Promise<boolean> {
  try {
    const executor = await initializeAgent();
    console.log('✅ Agent initialized successfully');
    return true;
  } catch (error) {
    console.error('❌ Agent initialization failed:', error);
    return false;
  }
}
