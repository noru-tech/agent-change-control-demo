// Amounts are integer minor units (cents) so that no arithmetic is done in floating point.

export type Currency = "EUR" | "SEK" | "USD";

export interface Money {
  amount: number;
  currency: Currency;
}

export function money(amount: number, currency: Currency): Money {
  if (!Number.isSafeInteger(amount)) {
    throw new RangeError(`amount must be an integer number of minor units, got ${amount}`);
  }
  return { amount, currency };
}

export function add(a: Money, b: Money): Money {
  if (a.currency !== b.currency) {
    throw new TypeError(`cannot add ${a.currency} to ${b.currency}`);
  }
  return money(a.amount + b.amount, a.currency);
}

export function sum(items: Money[], currency: Currency): Money {
  return items.reduce((total, item) => add(total, item), money(0, currency));
}

export function multiply(a: Money, quantity: number): Money {
  if (!Number.isInteger(quantity) || quantity < 0) {
    throw new RangeError(`quantity must be a non-negative integer, got ${quantity}`);
  }
  return money(a.amount * quantity, a.currency);
}
