import type { Money } from "./money.ts";

const LOCALES = { EUR: "de-DE", SEK: "sv-SE", USD: "en-US" } as const;

export function formatMoney(value: Money): string {
  return new Intl.NumberFormat(LOCALES[value.currency], {
    style: "currency",
    currency: value.currency,
  }).format(value.amount / 100);
}
