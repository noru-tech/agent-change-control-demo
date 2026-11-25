import { createHmac, timingSafeEqual } from "node:crypto";

// Outgoing webhooks carry `t=<unix seconds>,v1=<hex HMAC-SHA256 of "t.body">`.
const TOLERANCE_SECONDS = 300;

export function sign(secret: string, body: string, timestamp: number): string {
  const mac = createHmac("sha256", secret).update(`${timestamp}.${body}`).digest("hex");
  return `t=${timestamp},v1=${mac}`;
}

export function verify(secret: string, body: string, header: string, now: number): boolean {
  const parts = Object.fromEntries(header.split(",").map((p) => p.split("=", 2)));
  const timestamp = Number(parts.t);
  if (!Number.isInteger(timestamp) || Math.abs(now - timestamp) > TOLERANCE_SECONDS) return false;
  const expected = Buffer.from(sign(secret, body, timestamp));
  const actual = Buffer.from(header);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}
