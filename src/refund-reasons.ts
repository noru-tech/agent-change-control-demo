// Refund reasons are free text from support staff; reports group them by a fixed code.

export type RefundCode = "duplicate" | "damaged" | "cancelled" | "other";

const KEYWORDS: [RefundCode, RegExp][] = [
  ["duplicate", /\b(duplicate|charged twice|double)\b/i],
  ["damaged", /\b(damaged|broken|spoiled)\b/i],
  ["cancelled", /\b(cancel(l)?ed|cancellation)\b/i],
];

export function refundCode(reason: string): RefundCode {
  for (const [code, pattern] of KEYWORDS) {
    if (pattern.test(reason)) return code;
  }
  return "other";
}
