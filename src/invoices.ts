import type { AuditLog } from "./audit.ts";
import type { Customers } from "./customers.ts";
import { type Currency, type Money, multiply, sum } from "./money.ts";

export interface Line {
  description: string;
  quantity: number;
  unitPrice: Money;
}

export type InvoiceStatus = "open" | "paid" | "void";

export interface Invoice {
  id: string;
  customerId: string;
  currency: Currency;
  lines: Line[];
  total: Money;
  status: InvoiceStatus;
  issuedAt: string;
}

export interface NewInvoice {
  customerId: string;
  currency: Currency;
  lines: Line[];
}

export class Invoices {
  #byId = new Map<string, Invoice>();
  #customers: Customers;
  #audit: AuditLog;
  #clock: () => Date;

  constructor(customers: Customers, audit: AuditLog, clock: () => Date = () => new Date()) {
    this.#customers = customers;
    this.#audit = audit;
    this.#clock = clock;
  }

  create(input: NewInvoice, actor: string): Invoice {
    if (!this.#customers.get(input.customerId)) throw new TypeError("unknown customer");
    if (input.lines.length === 0) throw new TypeError("an invoice needs at least one line");
    for (const line of input.lines) {
      if (line.unitPrice.currency !== input.currency) throw new TypeError("line currency mismatch");
    }
    const total = sum(
      input.lines.map((l) => multiply(l.unitPrice, l.quantity)),
      input.currency,
    );
    const invoice: Invoice = {
      id: `inv_${this.#byId.size + 1}`,
      customerId: input.customerId,
      currency: input.currency,
      lines: input.lines,
      total,
      status: "open",
      issuedAt: this.#clock().toISOString(),
    };
    this.#byId.set(invoice.id, invoice);
    this.#audit.record(actor, "invoice.created", invoice.id);
    return invoice;
  }

  get(id: string): Invoice | undefined {
    return this.#byId.get(id);
  }

  list(customerId?: string): Invoice[] {
    return [...this.#byId.values()].filter(
      (i) => customerId === undefined || i.customerId === customerId,
    );
  }

  markPaid(id: string, actor: string): Invoice {
    const invoice = this.#require(id);
    if (invoice.status !== "open") throw new TypeError(`cannot pay a ${invoice.status} invoice`);
    invoice.status = "paid";
    this.#audit.record(actor, "invoice.paid", id);
    return invoice;
  }

  void(id: string, actor: string): Invoice {
    const invoice = this.#require(id);
    if (invoice.status !== "open") throw new TypeError(`cannot void a ${invoice.status} invoice`);
    invoice.status = "void";
    this.#audit.record(actor, "invoice.voided", id);
    return invoice;
  }

  #require(id: string): Invoice {
    const invoice = this.#byId.get(id);
    if (!invoice) throw new TypeError(`unknown invoice ${id}`);
    return invoice;
  }
}
