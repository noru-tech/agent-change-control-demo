import assert from "node:assert/strict";
import { test } from "node:test";
import { IdempotencyStore } from "../src/idempotency.ts";

test("a repeated key replays the first response", () => {
  const store = new IdempotencyStore<number>();
  let calls = 0;
  assert.equal(store.run("k1", "a", () => ++calls), 1);
  assert.equal(store.run("k1", "a", () => ++calls), 1);
  assert.equal(calls, 1);
});

test("a reused key with another body is refused", () => {
  const store = new IdempotencyStore<number>();
  store.run("k1", "a", () => 1);
  assert.throws(() => store.run("k1", "b", () => 2));
});
