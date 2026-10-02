import assert from "node:assert/strict";
import { test } from "node:test";
import { sign, verify } from "../src/webhook-signature.ts";

test("a signature verifies within the tolerance window only", () => {
  const header = sign("whsec_test", '{"id":"inv_1"}', 1_790_000_000);
  assert.equal(verify("whsec_test", '{"id":"inv_1"}', header, 1_790_000_100), true);
  assert.equal(verify("whsec_test", '{"id":"inv_2"}', header, 1_790_000_100), false);
  assert.equal(verify("whsec_test", '{"id":"inv_1"}', header, 1_790_001_000), false);
});
