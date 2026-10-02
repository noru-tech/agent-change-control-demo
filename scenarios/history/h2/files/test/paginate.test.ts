import assert from "node:assert/strict";
import { test } from "node:test";
import { paginate } from "../src/paginate.ts";

test("the last page has no next offset", () => {
  assert.deepEqual(paginate([1, 2, 3], 0, 2), { items: [1, 2], next: 2 });
  assert.deepEqual(paginate([1, 2, 3], 2, 2), { items: [3], next: null });
});
