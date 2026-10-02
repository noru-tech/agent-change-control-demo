// Human-facing invoice numbers: KF-<year>-<sequence>, sequence restarting every year.

export function invoiceNumber(year: number, sequence: number): string {
  if (!Number.isInteger(sequence) || sequence < 1) {
    throw new RangeError(`sequence must be a positive integer, got ${sequence}`);
  }
  return `KF-${year}-${String(sequence).padStart(4, "0")}`;
}
