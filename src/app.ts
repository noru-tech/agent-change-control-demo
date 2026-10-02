import { AuditLog } from "./audit.ts";
import { Customers } from "./customers.ts";
import { Invoices } from "./invoices.ts";
import { Refunds } from "./refunds.ts";

export interface App {
  audit: AuditLog;
  customers: Customers;
  invoices: Invoices;
  refunds: Refunds;
}

export function createApp(clock: () => Date = () => new Date()): App {
  const audit = new AuditLog(clock);
  const customers = new Customers(audit);
  const invoices = new Invoices(customers, audit, clock);
  const refunds = new Refunds(invoices, audit);
  return { audit, customers, invoices, refunds };
}
