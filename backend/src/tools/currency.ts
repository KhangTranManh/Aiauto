/**
 * Currency utility functions for Vietnamese Dong (VND)
 */

/**
 * Formats a number as Vietnamese Dong currency
 * @param amount - The amount to format
 * @returns Formatted currency string (e.g., "1.000.000 ₫")
 */
export function formatVND(amount: number): string {
  if (isNaN(amount) || amount < 0) {
    return '0 ₫';
  }

  // Format with dot as thousands separator
  const formatted = amount
    .toFixed(0)
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.');

  return `${formatted} ₫`;
}

/**
 * Parses a Vietnamese currency string to a number
 * @param currencyString - String like "1.000.000đ" or "1,000,000"
 * @returns Numeric value
 */
export function parseVND(currencyString: string): number {
  if (!currencyString) return 0;

  // Remove currency symbols and whitespace
  const cleaned = currencyString
    .replace(/₫|đ|VND/gi, '')
    .replace(/\s/g, '')
    .trim();

  // Handle both dot and comma separators
  const normalized = cleaned.replace(/\./g, '').replace(/,/g, '');

  const amount = parseFloat(normalized);
  return isNaN(amount) ? 0 : amount;
}

/**
 * Formats price range
 * @param minPrice - Minimum price
 * @param maxPrice - Maximum price
 * @returns Formatted range string
 */
export function formatPriceRange(minPrice: number, maxPrice: number): string {
  return `${formatVND(minPrice)} - ${formatVND(maxPrice)}`;
}

/**
 * Extracts numeric value from various price formats
 * Handles formats like: "1.000.000", "1,000,000", "đ1000000", etc.
 */
export function extractPrice(priceText: string): number {
  if (!priceText) return 0;

  // Try multiple patterns
  const patterns = [
    /[\d.,]+/g, // Match any sequence of digits, dots, and commas
  ];

  for (const pattern of patterns) {
    const match = priceText.match(pattern);
    if (match) {
      // Take the first match and parse it
      return parseVND(match[0] || '');
    }
  }

  return 0;
}
