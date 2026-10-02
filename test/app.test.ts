import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp } from "../src/app.ts";
import { money } from "../src/money.ts";

const clock = () => new Date("2026-09-01T09:00:00Z");

function seeded() {
  const app = createApp(clock);
  const customer = app.customers.create(
    { name: "Fjord Bakery AB", email: "billing@fjord.example", country: "SE" },
    "test",
  );
  const invoice = app.invoices.create(
    {
      customerId: customer.id,
      currency: "SEK",
      lines: [
        { description: "Sourdough subscription", quantity: 4, unitPrice: money(12_500, "SEK") },
        { description: "Delivery", quantity: 1, unitPrice: money(4_900, "SEK") },
      ],
    },
    "test",
  );
  return { app, customer, invoice };
}

test("an invoice totals its lines", () => {
  const { invoice } = seeded();
  assert.deepEqual(invoice.total, money(54_900, "SEK"));
  assert.equal(invoice.status, "open");
  assert.equal(invoice.issuedAt, "2026-09-01T09:00:00.000Z");
});

test("an invoice rejects lines in another currency", () => {
  const { app, customer } = seeded();
  assert.throws(() =>
    app.invoices.create(
      {
        customerId: customer.id,
        currency: "SEK",
        lines: [{ description: "x", quantity: 1, unitPrice: money(100, "EUR") }],
      },
      "test",
    ),
  );
});

test("only paid invoices can be refunded, up to their total", () => {
  const { app, invoice } = seeded();
  assert.throws(() => app.refunds.create(invoice.id, money(100, "SEK"), "early", "test"));
  app.invoices.markPaid(invoice.id, "test");
  app.refunds.create(invoice.id, money(50_000, "SEK"), "partial", "test");
  assert.throws(() => app.refunds.create(invoice.id, money(5_000, "SEK"), "too much", "test"));
  assert.deepEqual(app.refunds.refundedFor(invoice.id), money(50_000, "SEK"));
});

test("every change is in the audit log", () => {
  const { app, invoice } = seeded();
  app.invoices.void(invoice.id, "test");
  assert.deepEqual(
    app.audit.list().map((e) => e.action),
    ["customer.created", "invoice.created", "invoice.voided"],
  );
  assert.equal(app.audit.list(invoice.id).length, 2);
});

test("money refuses fractional minor units", () => {
  assert.throws(() => money(10.5, "EUR"));
});
