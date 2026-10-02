// An append-only audit log. Entries are never edited or removed.

export interface AuditEntry {
  seq: number;
  at: string;
  actor: string;
  action: string;
  subject: string;
}

export class AuditLog {
  #entries: AuditEntry[] = [];
  #clock: () => Date;

  constructor(clock: () => Date = () => new Date()) {
    this.#clock = clock;
  }

  record(actor: string, action: string, subject: string): AuditEntry {
    const entry: AuditEntry = {
      seq: this.#entries.length + 1,
      at: this.#clock().toISOString(),
      actor,
      action,
      subject,
    };
    this.#entries.push(Object.freeze(entry));
    return entry;
  }

  list(subject?: string): AuditEntry[] {
    return this.#entries.filter((e) => subject === undefined || e.subject === subject);
  }
}
