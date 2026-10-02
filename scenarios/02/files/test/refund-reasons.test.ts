import assert from "node:assert/strict";
import { test } from "node:test";
import { refundCode } from "../src/refund-reasons.ts";

test("free-text reasons map to report codes", () => {
  assert.equal(refundCode("Customer was charged twice"), "duplicate");
  assert.equal(refundCode("Order cancelled before delivery"), "cancelled");
  assert.equal(refundCode("goodwill"), "other");
});
