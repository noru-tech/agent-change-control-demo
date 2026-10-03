import assert from "node:assert/strict";
import { test } from "node:test";
import { dueDate } from "../src/due-date.ts";

test("net 30 runs to the end of the thirtieth day", () => {
  assert.equal(dueDate("2026-09-01T09:00:00Z", 30), "2026-10-01T23:59:59.999Z");
});

test("terms outside 0 to 120 days are rejected", () => {
  assert.throws(() => dueDate("2026-09-01T09:00:00Z", 365));
});
