/**
 * Format number as Vietnamese Dong currency
 * @param amount - Amount in VND
 * @returns Formatted string like "1.000.000₫"
 */
export function formatVND(amount: number): string {
  return `${amount.toLocaleString('vi-VN')}₫`;
}

/**
 * Extract numeric price from Vietnamese currency string
 * @param priceString - String like "1.000.000₫" or "50k"
 * @returns Numeric amount
 */
export function extractPrice(priceString: string): number {
  // Remove currency symbols
  let cleaned = priceString.replace(/[₫đ]/gi, '').trim();
  
  // Handle "k" suffix (thousands)
  if (cleaned.toLowerCase().includes('k')) {
    const num = parseFloat(cleaned.replace(/k/gi, ''));
    return num * 1000;
  }
  
  // Remove dots (thousand separators in Vietnamese format)
  cleaned = cleaned.replace(/\./g, '');
  
  // Replace comma with dot for decimal parsing
  cleaned = cleaned.replace(/,/g, '.');
  
  return parseFloat(cleaned) || 0;
}
