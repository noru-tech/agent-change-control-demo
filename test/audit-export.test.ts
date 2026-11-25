import assert from "node:assert/strict";
import { test } from "node:test";
import { AuditLog } from "../src/audit.ts";
import { auditToJsonLines } from "../src/audit-export.ts";

test("one JSON object per line, in sequence order", () => {
  const log = new AuditLog(() => new Date("2026-09-01T09:00:00Z"));
  log.record("alice", "invoice.created", "inv_1");
  log.record("alice", "invoice.paid", "inv_1");
  const lines = auditToJsonLines(log.list()).split("\n").map((l) => JSON.parse(l));
  assert.deepEqual(lines.map((l) => l.seq), [1, 2]);
});
