import assert from "node:assert/strict";
import { test } from "node:test";
import { money } from "../src/money.ts";
import { vat } from "../src/vat.ts";

test("Swedish standard VAT is 25 percent", () => {
  assert.deepEqual(vat(money(10_000, "SEK"), "SE"), money(2_500, "SEK"));
});
