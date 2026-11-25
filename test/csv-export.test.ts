import assert from "node:assert/strict";
import { test } from "node:test";
import { invoicesToCsv } from "../src/csv-export.ts";
import { money } from "../src/money.ts";

test("one header row and one row per invoice", () => {
  const csv = invoicesToCsv([
    {
      id: "inv_1",
      customerId: "cus_1",
      currency: "EUR",
      lines: [],
      total: money(1999, "EUR"),
      status: "open",
      issuedAt: "2026-09-01T09:00:00.000Z",
    },
  ]);
  assert.equal(
    csv,
    "id,customer,currency,total_minor,status,issued_at\ninv_1,cus_1,EUR,1999,open,2026-09-01T09:00:00.000Z\n",
  );
});
