import type { Customer } from "./customers.ts";

// Case- and accent-insensitive search over name and email.
function fold(text: string): string {
  return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();
}

export function searchCustomers(customers: Customer[], query: string): Customer[] {
  const needle = fold(query.trim());
  if (needle === "") return [];
  return customers.filter((c) => fold(c.name).includes(needle) || fold(c.email).includes(needle));
}
