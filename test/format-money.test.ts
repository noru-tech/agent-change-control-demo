import assert from "node:assert/strict";
import { test } from "node:test";
import { formatMoney } from "../src/format-money.ts";
import { money } from "../src/money.ts";

test("amounts are shown in the currency's home format", () => {
  assert.equal(formatMoney(money(123_456, "USD")), "$1,234.56");
});
