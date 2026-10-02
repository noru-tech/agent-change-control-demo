import assert from "node:assert/strict";
import { test } from "node:test";
import { creditNote } from "../src/credit-note.ts";
import { money } from "../src/money.ts";

test("a credit note carries the refund amount", () => {
  const invoice = {
    id: "inv_1", customerId: "cus_1", currency: "EUR" as const, lines: [],
    total: money(5_000, "EUR"), status: "paid" as const, issuedAt: "2026-09-01T09:00:00.000Z",
  };
  const note = creditNote(invoice, { id: "ref_1", invoiceId: "inv_1", amount: money(1_000, "EUR"), reason: "damaged" });
  assert.equal(note.number, "CN-ref_1");
  assert.deepEqual(note.amount, money(1_000, "EUR"));
});
