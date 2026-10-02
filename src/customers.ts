import type { AuditLog } from "./audit.ts";

export interface Customer {
  id: string;
  name: string;
  email: string;
  country: string;
}

export interface NewCustomer {
  name: string;
  email: string;
  country: string;
}

export class Customers {
  #byId = new Map<string, Customer>();
  #audit: AuditLog;

  constructor(audit: AuditLog) {
    this.#audit = audit;
  }

  create(input: NewCustomer, actor: string): Customer {
    if (input.name.trim() === "") throw new TypeError("name is required");
    if (!input.email.includes("@")) throw new TypeError("email is invalid");
    const country = input.country.trim().toUpperCase();
    if (!/^[A-Z]{2}$/.test(country)) throw new TypeError("country must be ISO 3166-1 alpha-2");
    const customer: Customer = { id: `cus_${this.#byId.size + 1}`, ...input, country };
    this.#byId.set(customer.id, customer);
    this.#audit.record(actor, "customer.created", customer.id);
    return customer;
  }

  get(id: string): Customer | undefined {
    return this.#byId.get(id);
  }

  list(): Customer[] {
    return [...this.#byId.values()];
  }
}
