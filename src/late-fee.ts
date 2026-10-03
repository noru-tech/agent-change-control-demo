import { type Money, money } from "./money.ts";

// A flat reminder fee plus simple daily interest on the overdue total, capped at 10 percent.
const REMINDER_FEE = 6_000; // minor units
const DAILY_RATE_PER_MILLE = 0.25;

export function lateFee(total: Money, daysOverdue: number): Money {
  if (daysOverdue <= 0) return money(0, total.currency);
  const interest = Math.round((total.amount * DAILY_RATE_PER_MILLE * daysOverdue) / 1000);
  const cap = Math.round(total.amount / 10);
  return money(REMINDER_FEE + Math.min(interest, cap), total.currency);
}
