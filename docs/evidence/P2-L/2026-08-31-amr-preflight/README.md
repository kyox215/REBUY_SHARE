# P2-L AMR preflight evidence

Current status: **PASS** after the third and final bounded one-shot. The first and second STOP/FAIL results remain preserved below as historical evidence.

## Historical first one-shot result

- Status: **STOP / FAIL**
- Date: `2026-08-31` (Europe/Rome)
- Project: `rebuy-g2-a1-e2a-local-email-otp-exec`
- Worktree: `/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划/.worktrees/rebuy-v1-local-complete-exec`
- Branch / HEAD: `codex/rebuy-v1-local-complete` / `0e5084b62c76275a781ec08edea287a06d442209`

## Execution

- Node: `/Users/kyox215/.nvm/versions/node/v22.12.0/bin/node`; `node --check prototype/scripts/run-p2l-amr-preflight.mjs` passed.
- Supabase CLI: `2.101.0`.
- CLI environment: `SUPABASE_TELEMETRY_DISABLED=1`, `SUPABASE_HOME=/private/tmp/rebuy-p2l-supabase-home`.
- Actual command: `/Users/kyox215/.nvm/versions/node/v22.12.0/bin/node prototype/scripts/run-p2l-amr-preflight.mjs`.
- `actual_count=1`; the command was not retried.

## Sanitized assertions

The only retained assertions were:

- `STATUS_FAIL`
- `P2L_PREFLIGHT_FAIL`

No identity value, OTP, publishable key, secret, token, cookie, JWT, or raw provider/status output was retained in this evidence.

## GoTrue runtime

- Image tag: `public.ecr.aws/supabase/gotrue:v2.188.1`
- Image ID: `sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`
- RepoDigest: `public.ecr.aws/supabase/gotrue@sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`

## Cleanup

- `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`: exit `0`.
- Exact project containers: empty.
- Exact project volumes: empty.
- Exact project network: empty.
- Loopback listeners `55320–55329`: empty.
- `--all` was not used.

## Historical first one-shot STOP decision

The preflight did not PASS. P2-L schema, migration, seed, business DB write, and P2-L schema/RLS runtime remain **CLOSED**. Hosted/Production, service-role/admin-key paths, real data, deployment, and other external writes remain frozen.

No migration, schema, seed, host/hosted service, service-role/admin-key action, real data, or commit was performed.

## Follow-up: status-shape diagnosis and selector repair

- This follow-up preserved the historical STOP/FAIL above. It started the same exact local project once for diagnosis only and did not run `run-p2l-amr-preflight.mjs`; follow-up `actual_count=0`.
- The only status-shape output retained was:

  ```text
  CLI_RC=0
  JSON_PARSE=true
  KEY_NAMES=ANON_KEY,API_URL,DB_URL,GRAPHQL_URL,INBUCKET_URL,JWT_SECRET,MAILPIT_URL,MCP_URL,PUBLISHABLE_KEY,REST_URL,SECRET_KEY,SERVICE_ROLE_KEY,STUDIO_URL
  API_URL_PRESENT=true API_URL_TYPE=string API_URL_LOCAL_ORIGIN=true
  PUBLISHABLE_KEY_PRESENT=true PUBLISHABLE_KEY_TYPE=string PUBLISHABLE_KEY_ALLOWED_FORMAT=true PUBLISHABLE_KEY_LENGTH=46
  ANON_KEY_PRESENT=true ANON_KEY_TYPE=string ANON_KEY_ALLOWED_FORMAT=true ANON_KEY_LENGTH=153
  ```

- Confirmed latent selector defect; not a unique root cause for the historical `STATUS_FAIL`: `PUBLISHABLE_KEY ?? ANON_KEY` treats an empty or otherwise invalid string as present, so it can mask a valid `ANON_KEY`. The live diagnostic shape had both keys in an allowed format and does not uniquely reproduce the historical failure; raw status was intentionally not retained.
- Local repair: added the pure `selectAllowedPublicKey` selector in `prototype/scripts/p2l-amr-preflight-config.mjs`, updated `run-p2l-amr-preflight.mjs` to use it, and added the no-network `test-p2l-amr-preflight-structure.mjs` coverage for empty/invalid fallback and key precedence.
- Validation: `node --check` passed for the harness, helper, and structure test; structure output was `P2L_SELECTOR_STRUCTURE_PASS`; `git diff --check` passed. No Auth, OTP, identity, refresh, migration, schema, seed, or DB write was run.
- Cleanup: exact `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` returned `0`; exact project containers, volumes, network, and `55320–55329` listeners were empty afterward.
- Next actual: not run in this follow-up. A new one-shot Gate is required before any future identity preflight; P2-L schema/migration/seed/DB write remains **CLOSED**. No commit, push, or deploy was performed.

## Follow-up: refresh timing hardening

- Scope: no Supabase or Docker start, no `run-p2l-amr-preflight.mjs` execution, and no Auth/OTP/identity/refresh request. This hardening batch has `actual_count=0`; the historical STOP/FAIL and historical `actual_count=1` remain unchanged.
- Timing separation: before the real refresh path can run, the harness now waits until `abs(current_epoch_seconds - initial_amr_timestamp) >= 2`. The wait polls every `100 ms`, has a bounded `10,000 ms` timeout, and emits only `REFRESH_AMR_TIME_SEPARATION_PASS` or `REFRESH_AMR_TIME_SEPARATION_FAIL`; it does not log timestamps or tokens. Absolute difference preserves the approved future-skew handling.
- Refresh evidence: `REFRESH_ACCESS_TOKEN_CHANGED` requires a different refreshed access token. Refreshed claims now also require `is_anonymous === false`, while retaining the existing OTP method, numeric timestamp, timestamp equality, and normalized-email assertions.
- Pure coverage: the helper test rejects same-second and one-second separation, accepts separation of at least two seconds in either direction including future skew, and retains publishable/anon key fallback coverage.
- Package entry: `test:auth:p2l:structure` runs only `test-p2l-amr-preflight-structure.mjs`; ordinary `test:auth` does not invoke the actual P2-L identity preflight.
- Validation: the specified Node `22.12.0` passed `node --check` for the harness, helper, and structure test. The package structure test passed with the finite output `P2L_PREFLIGHT_STRUCTURE_PASS`.
- Next actual: still not run. A new one-shot Gate remains required; P2-L schema/migration/seed/DB write and runtime remain **CLOSED**.

## Second one-shot AMR preflight

- Gate: the Owner's action-time reply `全部批准` was bound only to this second one-shot run against the exact local project and `@rebuy.test` synthetic identity path. The repaired harness was not changed after entry validation.
- Result: **STOP / FAIL**. This second Gate has `actual_count=1`; it was not retried. The historical first Gate and its separate `actual_count=1` remain recorded above.
- Sanitized assertions retained from this run: `STATUS_FAIL`, `P2L_PREFLIGHT_FAIL`. The run stopped before OTP, identity, or refresh, so the AMR timing-separation, changed-access-token, refreshed `is_anonymous=false`, method, timestamp-equality, and normalized-email assertions were not exercised.
- GoTrue runtime: tag=`public.ecr.aws/supabase/gotrue:v2.188.1`; image ID=`sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`; RepoDigest=`public.ecr.aws/supabase/gotrue@sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`.
- Output handling: sensitive start/status stdout and stderr were discarded. No raw status, key, OTP, identity email, token, JWT, cookie, DB password, or provider response was retained.
- Cleanup: exact `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` returned `0`; exact project containers, volumes, network, and loopback listeners `55320–55329` were empty afterward. `--all` was not used.
- Final offline validation: Node `22.12.0` passed separate `node --check` runs for the harness, helper, and structure test; `test:auth:p2l:structure` returned `P2L_PREFLIGHT_STRUCTURE_PASS`; `git diff --check` passed.
- Boundary: no migration, schema, seed, business DB write, hosted/Production connection, service-role/admin-key path, real data, commit, push, or deploy was performed. Full test/build/lint/E2E were not run.
- Decision: P2-L preflight remains **STOP / FAIL**. Schema/migration/seed/DB write and schema/RLS runtime remain **CLOSED**; this result does not open a schema Gate. Any diagnosis or future actual requires a separately bounded Gate.

## Third and final bounded one-shot AMR preflight

- Gate and review: the Owner's action-time reply `全部批准` and the approved `require_escalated` execution jointly bound this one run. The independent read-only Sol review returned `REVIEW GO`, `P0=0`, `P1=0`, `P2=1`, with Docker socket permission assessed as the 90–95% high-confidence cause of the prior status failures.
- Integrity binding: `git hash-object` recorded the reviewed harness=`0bf3a6b102598b5291365d92defa825f4a1a91e8`, helper=`f8d7e485abbbba0d430de075e2fa57b5674df83a`, and structure test=`4f5a88b7b194494cfc9d7834041a3c43c001720a`. All three IDs were identical before and after the actual; harness/helper/test/package were not modified.
- Entry: exact cwd, branch, HEAD=`0e5084b62c76275a781ec08edea287a06d442209`, project id, Node `22.12.0` executable, Supabase CLI `2.101.0`, empty target resources, and no `55320–55329` listeners all passed.
- Result: **PASS**. This third Gate has `actual_count=1`; it was not retried. The first and second Gates retain their separate historical `actual_count=1` and `STATUS_FAIL` records.
- Retained finite output:

  ```text
  STATUS_PASS
  EMAIL_GENERATED_PASS
  OTP_REQUEST_PASS
  MAILPIT_CAPTURE_PASS
  OTP_VERIFY_PASS
  INITIAL_GET_USER_PASS
  INITIAL_AMR_METHOD_PASS
  INITIAL_AMR_TIMESTAMP_NUMERIC_PASS
  INITIAL_AMR_RECENCY_PASS age_seconds=0
  INITIAL_IS_ANONYMOUS_FALSE_PASS
  INITIAL_EMAIL_NORMALIZED_PASS
  REFRESH_AMR_TIME_SEPARATION_PASS
  REFRESH_SESSION_PASS
  REFRESH_ACCESS_TOKEN_CHANGED_PASS
  REFRESH_GET_USER_PASS
  REFRESH_AMR_METHOD_PASS
  REFRESH_AMR_TIMESTAMP_NUMERIC_PASS
  REFRESH_AMR_TIMESTAMP_UNCHANGED_PASS
  REFRESH_IS_ANONYMOUS_FALSE_PASS
  REFRESH_EMAIL_NORMALIZED_PASS
  P2L_PREFLIGHT_PASS
  ```

- Root cause: the controlled comparison validates the inherited Docker socket permission boundary as the operational cause of the two prior `STATUS_FAIL` results. With the exact reviewed parent Node harness granted Docker socket access, its internal direct `execFile` status call succeeded and the complete identity/AMR/refresh path passed. The selector issue remains a confirmed latent defect, not the observed unique cause of those historical failures.
- GoTrue runtime: tag=`public.ecr.aws/supabase/gotrue:v2.188.1`; image ID=`sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`; RepoDigest=`public.ecr.aws/supabase/gotrue@sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`.
- Output handling: sensitive start/status stdout and stderr were discarded. No raw status, key, OTP, identity email, token, JWT, cookie, DB password, or provider response was retained.
- Cleanup: exact `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` returned `0`; exact project containers, volumes, network, and loopback listeners `55320–55329` were empty afterward. `--all` was not used.
- Final offline validation: Node `22.12.0` passed separate `node --check` runs for the harness, helper, and structure test; `test:auth:p2l:structure` returned `P2L_PREFLIGHT_STRUCTURE_PASS`; `git diff --check` passed.
- Boundary: no migration, schema, seed, business DB write, hosted/Production connection, privileged-key path, real data, commit, push, or deploy was performed. The PASS establishes only the local AMR preflight prerequisite; a separately bounded schema Gate is still required before any schema work.
