import puppeteer, { Browser, Page } from 'puppeteer';
import puppeteerExtra from 'puppeteer-extra';
import StealthPlugin from 'puppeteer-extra-plugin-stealth';
import { config } from '../config';
import { extractPrice, formatVND } from './currency';

// Add stealth plugin to avoid bot detection
puppeteerExtra.use(StealthPlugin());

/**
 * Interface for a single product result
 */
export interface ShopeeProduct {
  name: string;
  price: string;
  priceRaw: number;
  link: string;
  imageUrl: string;
  shop?: string;
  rating?: number;
  soldCount?: string;
}

/**
 * Scraping result with products and metadata
 */
export interface ScrapeResult {
  success: boolean;
  products: ShopeeProduct[];
  message?: string;
  timestamp: string;
}

/**
 * Main function to search products on Shopee.vn
 * @param query - Search query (e.g., "iphone 15")
 * @param maxResults - Maximum number of products to return (default: 5)
 * @returns ScrapeResult with products or error information
 */
export async function searchShopee(
  query: string,
  maxResults: number = config.agent.maxProductsPerSearch
): Promise<ScrapeResult> {
  let browser: Browser | null = null;

  try {
    console.log(`🔍 Starting Shopee search for: "${query}"`);

    // Launch browser with stealth plugin
    browser = await puppeteerExtra.launch({
      headless: config.puppeteer.headless ? 'new' : false,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--disable-gpu',
        '--window-size=1920x1080',
      ],
    });

    const page = await browser.newPage();

    // Set viewport and user agent
    await page.setViewport({ width: 1920, height: 1080 });
    await page.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    );

    // Encode query for URL
    const encodedQuery = encodeURIComponent(query);
    const searchUrl = `https://shopee.vn/search?keyword=${encodedQuery}`;

    console.log(`📄 Navigating to: ${searchUrl}`);

    // Navigate to search page
    await page.goto(searchUrl, {
      waitUntil: 'domcontentloaded',
      timeout: config.puppeteer.timeout,
    });

    // Wait for page to be fully loaded
    await new Promise(resolve => setTimeout(resolve, 5000));

    console.log('✅ Page loaded, extracting products...');

    // Extract product data with very flexible approach
    const products = await page.evaluate((max) => {
      const results: any[] = [];

      // Strategy: Look for product containers with images and prices
      // Shopee uses various structures, so we'll be very flexible
      
      // Try to find all image elements that might be products
      const allImages = Array.from(document.querySelectorAll('img'));
      console.log(`Found ${allImages.length} total images on page`);

      // Find all price elements (containing ₫ or đ)
      const priceElements = Array.from(document.querySelectorAll('*')).filter(el => {
        const text = el.textContent || '';
        return text.includes('₫') || text.includes('đ');
      });
      console.log(`Found ${priceElements.length} elements with currency symbols`);

      // Look for product links - try multiple patterns
      const productLinks = Array.from(document.querySelectorAll('a')).filter(a => {
        const href = a.getAttribute('href') || '';
        return href.includes('-i.') || href.includes('/product') || href.includes('.vn/');
      });
      console.log(`Found ${productLinks.length} potential product links`);

      const seenProducts = new Set<string>();

      // Method 1: Extract from product links
      for (const link of productLinks) {
        if (results.length >= max) break;

        const href = (link as HTMLAnchorElement).href;
        
        // Skip duplicates
        const urlKey = href.split('?')[0]; // Remove query params for deduplication
        if (seenProducts.has(urlKey)) continue;

        // Find the closest container that has both image and price
        let container: Element | null = link;
        for (let i = 0; i < 5; i++) { // Go up max 5 levels
          if (!container) break;
          
          const hasImage = container.querySelector('img');
          const hasPrice = container.textContent?.includes('₫') || container.textContent?.includes('đ');
          
          if (hasImage && hasPrice) {
            break; // Found good container
          }
          container = container.parentElement;
        }

        if (!container) continue;

        try {
          // Extract name
          let name = '';
          
          // Try getting from link title or text
          const linkText = link.getAttribute('title') || link.textContent?.trim() || '';
          if (linkText && linkText.length > 5) {
            name = linkText;
          }
          
          // Try finding text in container
          if (!name) {
            const textDivs = container.querySelectorAll('div, span');
            for (const div of Array.from(textDivs)) {
              const text = div.textContent?.trim() || '';
              if (text.length > 10 && text.length < 200 && !text.includes('₫') && !text.includes('đ')) {
                name = text;
                break;
              }
            }
          }

          if (!name || name.length < 5) continue;

          // Extract price
          let priceText = '0';
          const containerText = container.textContent || '';
          
          // Look for patterns like "18.000₫" or "24.840đ"
          const priceMatch = containerText.match(/[\d,.]+\s*[₫đ]/);
          if (priceMatch) {
            priceText = priceMatch[0];
          }

          // Extract image
          let imageUrl = '';
          const img = container.querySelector('img');
          if (img) {
            imageUrl = img.src || img.getAttribute('data-src') || img.getAttribute('srcset')?.split(' ')[0] || '';
            if (imageUrl.startsWith('//')) {
              imageUrl = 'https:' + imageUrl;
            }
          }

          // Extract rating
          let rating: number | undefined;
          const ratingMatch = containerText.match(/([0-5]\.?[0-9]?)\s*★/);
          if (ratingMatch) {
            rating = parseFloat(ratingMatch[1]);
          }

          // Make sure we have minimum required data
          if (name && priceText !== '0' && href) {
            seenProducts.add(urlKey);
            results.push({
              name: name.substring(0, 200).trim(),
              price: priceText,
              priceRaw: 0,
              link: href,
              imageUrl,
              rating,
            });
          }

        } catch (err) {
          console.error('Error extracting product:', err);
        }
      }

      console.log(`Extracted ${results.length} products`);
      return results;
    }, maxResults);

    // Close browser
    await browser.close();
    browser = null;

    console.log(`✅ Raw extraction found ${products.length} products`);

    if (products.length === 0) {
      throw new Error('No products found on page');
    }

    // Parse prices and format
    const formattedProducts = products.map((product) => {
      const priceRaw = extractPrice(product.price);
      return {
        ...product,
        priceRaw,
        price: formatVND(priceRaw),
      };
    });

    console.log(`✅ Successfully scraped ${formattedProducts.length} products`);

    return {
      success: true,
      products: formattedProducts,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    console.error('❌ Shopee scraping error:', error);

    // Close browser if still open
    if (browser) {
      try {
        await browser.close();
      } catch (closeError) {
        console.error('Error closing browser:', closeError);
      }
    }

    // Return mock data for testing purposes so the app doesn't crash
    console.log('⚠️ Returning mock data for testing...');
    
    return {
      success: false,
      products: getMockProducts(query),
      message: `Scraping failed: ${error instanceof Error ? error.message : 'Unknown error'}. Returning mock data for testing.`,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Returns mock products for testing when scraping fails
 * This prevents the app from crashing and allows testing the full flow
 */
function getMockProducts(query: string): ShopeeProduct[] {
  return [
    {
      name: `${query} - Premium Version (Mock Data)`,
      price: formatVND(15900000),
      priceRaw: 15900000,
      link: 'https://shopee.vn/product/123456',
      imageUrl: 'https://via.placeholder.com/300x300?text=Product+1',
      shop: 'Mock Shop 1',
      rating: 4.8,
      soldCount: '1.2k',
    },
    {
      name: `${query} - Standard Version (Mock Data)`,
      price: formatVND(12500000),
      priceRaw: 12500000,
      link: 'https://shopee.vn/product/234567',
      imageUrl: 'https://via.placeholder.com/300x300?text=Product+2',
      shop: 'Mock Shop 2',
      rating: 4.5,
      soldCount: '850',
    },
    {
      name: `${query} - Budget Version (Mock Data)`,
      price: formatVND(8900000),
      priceRaw: 8900000,
      link: 'https://shopee.vn/product/345678',
      imageUrl: 'https://via.placeholder.com/300x300?text=Product+3',
      shop: 'Mock Shop 3',
      rating: 4.2,
      soldCount: '500',
    },
  ];
}

/**
 * Utility function to test if Shopee is accessible
 * Can be used for health checks
 */
export async function testShopeeConnection(): Promise<boolean> {
  let browser: Browser | null = null;

  try {
    browser = await puppeteerExtra.launch({
      headless: 'new',
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });

    const page = await browser.newPage();
    await page.goto('https://shopee.vn', { timeout: 10000 });
    
    await browser.close();
    return true;
  } catch (error) {
    if (browser) {
      try {
        await browser.close();
      } catch {}
    }
    return false;
  }
}
