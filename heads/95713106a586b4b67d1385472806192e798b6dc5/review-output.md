Overall, this is a clean, dependency-free in-memory idempotency store with straightforward semantics. The basic behavior is correct and the tests cover the core cases.

Notes and suggestions:
- src/idempotency.ts:12-22: The handler is synchronous in the type, but callers may naturally pass an async handler returning a Promise<T>. This implementation will cache and replay the Promise (including its rejection), which is reasonable. Consider:
  - Documenting that T may be a Promise and that rejections are replayed.
  - Adding a test for Promise<T> to ensure consistent behavior (pending resolution is shared; rejection is replayed).
- src/idempotency.ts:15-17: Throwing a TypeError is fine, but a dedicated error class (e.g., IdempotencyKeyConflictError) would make upstream handling easier (non-blocking).
- Behavior choice: Currently, thrown synchronous errors are not cached, while rejected Promises are cached. Decide if this asymmetry is intentional. If not, either:
  - Don’t cache rejections (wrap and clear on rejection), or
  - Cache thrown errors too (requires changing T or wrapping the stored value).
  This is a design decision; not necessarily a blocker, but worth clarifying.
- Long-term: This map grows unbounded. If this will be used in production paths, consider TTL/eviction or an explicit clear API (non-blocking).

Tests:
- test/idempotency.test.ts: Good coverage for sync success path and fingerprint mismatch. Consider adding:
  - A test with async handler returning a Promise (resolve and reject cases).
  - A test ensuring that a mismatch does not overwrite the stored value (implicit now, but an explicit assertion would be nice).

Fit:
- Matches the project’s “no runtime dependencies” approach and is small and focused.

Given the scope, there are no correctness blockers; suggestions above are improvements rather than required fixes.

DECISION: APPROVE
