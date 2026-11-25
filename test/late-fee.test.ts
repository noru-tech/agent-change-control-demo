import assert from "node:assert/strict";
import { test } from "node:test";
import { lateFee } from "../src/late-fee.ts";
import { money } from "../src/money.ts";

test("no fee before the due date", () => {
  assert.deepEqual(lateFee(money(100_000, "SEK"), 0), money(0, "SEK"));
});

test("interest is capped at a tenth of the total", () => {
  assert.deepEqual(lateFee(money(100_000, "SEK"), 10), money(6_250, "SEK"));
  assert.deepEqual(lateFee(money(100_000, "SEK"), 1000), money(16_000, "SEK"));
});
