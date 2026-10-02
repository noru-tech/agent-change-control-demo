import { type Money, money } from "./money.ts";

// Standard VAT rates in basis points, by seller country.
const STANDARD_RATE_BP: Record<string, number> = { SE: 2500, DE: 1900, NL: 2100 };

export function vat(net: Money, country: string): Money {
  const rate = STANDARD_RATE_BP[country];
  if (rate === undefined) throw new TypeError(`no VAT rate for ${country}`);
  return money(Math.round((net.amount * rate) / 10_000), net.currency);
}
