import assert from "node:assert/strict";

import {
  hasMinimumAmrEpochSeparation,
  isAllowedPublicKey,
  selectAllowedPublicKey,
} from "./p2l-amr-preflight-config.mjs";

const legacyAnonKey = [
  Buffer.from(JSON.stringify({ alg: "HS256" })).toString("base64url"),
  Buffer.from(JSON.stringify({ role: "anon" })).toString("base64url"),
  "synthetic-signature",
].join(".");
const publishableKey = "sb_publishable_synthetic_fallback";

assert.equal(isAllowedPublicKey(legacyAnonKey), true);
assert.equal(
  selectAllowedPublicKey({ PUBLISHABLE_KEY: "", ANON_KEY: legacyAnonKey }),
  legacyAnonKey,
);
assert.equal(
  selectAllowedPublicKey({ PUBLISHABLE_KEY: "invalid", ANON_KEY: legacyAnonKey }),
  legacyAnonKey,
);
assert.equal(
  selectAllowedPublicKey({ PUBLISHABLE_KEY: publishableKey, ANON_KEY: legacyAnonKey }),
  publishableKey,
);
assert.equal(selectAllowedPublicKey({ PUBLISHABLE_KEY: "", ANON_KEY: "" }), undefined);
assert.equal(hasMinimumAmrEpochSeparation(1_000, 1_000), false);
assert.equal(hasMinimumAmrEpochSeparation(1_001, 1_000), false);
assert.equal(hasMinimumAmrEpochSeparation(1_002, 1_000), true);
assert.equal(hasMinimumAmrEpochSeparation(1_000, 1_002), true);
assert.equal(hasMinimumAmrEpochSeparation(1_000, 1_060), true);

console.log("P2L_PREFLIGHT_STRUCTURE_PASS");
