import type { AuditLog } from "./audit.ts";
import type { Invoices } from "./invoices.ts";
import { type Money, add, sum } from "./money.ts";

export interface Refund {
  id: string;
  invoiceId: string;
  amount: Money;
  reason: string;
}

export class Refunds {
  #all: Refund[] = [];
  #invoices: Invoices;
  #audit: AuditLog;

  constructor(invoices: Invoices, audit: AuditLog) {
    this.#invoices = invoices;
    this.#audit = audit;
  }

  create(invoiceId: string, amount: Money, reason: string, actor: string): Refund {
    const invoice = this.#invoices.get(invoiceId);
    if (!invoice) throw new TypeError(`unknown invoice ${invoiceId}`);
    if (invoice.status !== "paid") throw new TypeError("only paid invoices can be refunded");
    if (amount.amount <= 0) throw new RangeError("a refund must be positive");
    const refunded = add(this.refundedFor(invoiceId), amount);
    if (refunded.amount > invoice.total.amount) {
      throw new RangeError("refunds cannot exceed the invoice total");
    }
    const refund: Refund = { id: `ref_${this.#all.length + 1}`, invoiceId, amount, reason };
    this.#all.push(refund);
    this.#audit.record(actor, "refund.created", refund.id);
    return refund;
  }

  refundedFor(invoiceId: string): Money {
    const invoice = this.#invoices.get(invoiceId);
    if (!invoice) throw new TypeError(`unknown invoice ${invoiceId}`);
    return sum(
      this.#all.filter((r) => r.invoiceId === invoiceId).map((r) => r.amount),
      invoice.currency,
    );
  }
}
