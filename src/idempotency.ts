// Replays the stored response for a repeated Idempotency-Key, and refuses a reused key whose
// request body differs from the first one.

export interface Stored<T> {
  fingerprint: string;
  response: T;
}

export class IdempotencyStore<T> {
  #byKey = new Map<string, Stored<T>>();

  run(key: string, fingerprint: string, handler: () => T): T {
    const stored = this.#byKey.get(key);
    if (stored) {
      if (stored.fingerprint !== fingerprint) {
        throw new TypeError("idempotency key reused with a different request");
      }
      return stored.response;
    }
    const response = handler();
    this.#byKey.set(key, { fingerprint, response });
    return response;
  }
}
