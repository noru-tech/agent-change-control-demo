import type { Invoice } from "./invoices.ts";
import type { Refund } from "./refunds.ts";

// A credit note references the invoice it corrects and carries the refunded amount.
export interface CreditNote {
  number: string;
  invoiceId: string;
  amount: Refund["amount"];
  reason: string;
}

export function creditNote(invoice: Invoice, refund: Refund): CreditNote {
  if (refund.invoiceId !== invoice.id) throw new TypeError("refund belongs to another invoice");
  return { number: `CN-${refund.id}`, invoiceId: invoice.id, amount: refund.amount, reason: refund.reason };
}
