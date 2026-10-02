import type { AuditEntry } from "./audit.ts";

// JSON Lines, one entry per line, in sequence order, for shipping to an external log store.
export function auditToJsonLines(entries: AuditEntry[]): string {
  return [...entries]
    .sort((a, b) => a.seq - b.seq)
    .map((e) => JSON.stringify({ seq: e.seq, at: e.at, actor: e.actor, action: e.action, subject: e.subject }))
    .join("\n");
}
