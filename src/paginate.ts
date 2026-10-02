export interface Page<T> {
  items: T[];
  next: number | null;
}

export function paginate<T>(items: T[], offset = 0, limit = 50): Page<T> {
  if (!Number.isInteger(limit) || limit < 1 || limit > 200) {
    throw new RangeError(`limit must be 1 to 200, got ${limit}`);
  }
  const end = offset + limit;
  return { items: items.slice(offset, end), next: end < items.length ? end : null };
}
