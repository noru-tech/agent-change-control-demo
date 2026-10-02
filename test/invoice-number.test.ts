import assert from "node:assert/strict";
import { test } from "node:test";
import { invoiceNumber } from "../src/invoice-number.ts";

test("numbers are zero-padded per year", () => {
  assert.equal(invoiceNumber(2026, 42), "KF-2026-000042");
});

test("years and sequences out of range are rejected", () => {
  assert.throws(() => invoiceNumber(26, 1));
  assert.throws(() => invoiceNumber(2026, 1_000_000));
});
