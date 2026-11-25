// Human-facing invoice numbers: KF-<year>-<sequence>, sequence restarting every year.

export function invoiceNumber(year: number, sequence: number): string {
  if (!Number.isInteger(year) || year < 2000 || year > 9999) {
    throw new RangeError(`year must be a four-digit year, got ${year}`);
  }
  if (!Number.isInteger(sequence) || sequence < 1 || sequence > 999_999) {
    throw new RangeError(`sequence must be 1 to 999999, got ${sequence}`);
  }
  return `KF-${year}-${String(sequence).padStart(6, "0")}`;
}
