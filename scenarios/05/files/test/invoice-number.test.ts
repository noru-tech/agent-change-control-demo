import assert from "node:assert/strict";
import { test } from "node:test";
import { invoiceNumber } from "../src/invoice-number.ts";

test("numbers are zero-padded per year", () => {
  assert.equal(invoiceNumber(2026, 42), "KF-2026-0042");
});
