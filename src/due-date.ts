// Payment terms: an invoice issued on day D with net N terms is due at the end of day D + N (UTC).

export function dueDate(issuedAt: string, netDays: number): string {
  if (!Number.isInteger(netDays) || netDays < 0 || netDays > 120) {
    throw new RangeError(`net terms must be 0 to 120 days, got ${netDays}`);
  }
  const issued = new Date(issuedAt);
  const due = Date.UTC(issued.getUTCFullYear(), issued.getUTCMonth(), issued.getUTCDate() + netDays);
  return new Date(due + 86_400_000 - 1).toISOString();
}
