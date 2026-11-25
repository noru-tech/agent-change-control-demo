import type { Invoice } from "./invoices.ts";

const HEADER = ["id", "customer", "currency", "total_minor", "status", "issued_at"];

function cell(value: string | number): string {
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

export function invoicesToCsv(invoices: Invoice[]): string {
  const rows = invoices.map((i) =>
    [i.id, i.customerId, i.currency, i.total.amount, i.status, i.issuedAt].map(cell).join(","),
  );
  return [HEADER.join(","), ...rows].join("\n") + "\n";
}
