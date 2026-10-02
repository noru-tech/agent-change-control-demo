import assert from "node:assert/strict";
import { test } from "node:test";
import { searchCustomers } from "../src/customer-search.ts";

const customers = [
  { id: "cus_1", name: "Café Åkersberga", email: "hej@cafe.example", country: "SE" },
  { id: "cus_2", name: "Fjord Bakery AB", email: "billing@fjord.example", country: "SE" },
];

test("search ignores case and accents", () => {
  assert.deepEqual(searchCustomers(customers, "akers").map((c) => c.id), ["cus_1"]);
  assert.deepEqual(searchCustomers(customers, "FJORD").map((c) => c.id), ["cus_2"]);
});
