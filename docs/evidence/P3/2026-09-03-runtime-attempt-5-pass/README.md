# P3 runtime attempt #5 — complete local PASS

日期：2026-09-03（Europe/Rome）
范围：`synthetic-only local`；project=`rebuy-g2-a1-e2a-local-email-otp-exec`；loopback `55320–55329`

## Candidate binding

| 文件 | SHA-256 |
|---|---|
| `supabase/migrations/20260903120000_p3_merchant_onboarding.sql` | `4eb494895efb52005fbe0e09e35f995b3bd62231a7691aba844f83776480a895` |
| `supabase/tests/p3_merchant_schema_security.test.sql` | `ee27863ba99588424bc984003775babfea7bb7ea88cc529381868e1e51e7a520` |
| `supabase/tests/p3_merchant_workflow.test.sql` | `8c95d05582d6b26ea14fc7aaef77b6378a316cb18283e6f5cd51d7fc1d87f033` |
| `prototype/scripts/run-p3-approval-concurrency.mjs` | `77454f74487ec0ce8c9fb8e85ce9c0c2b6ffe59ff589b80f12999bfc52476b87` |
| `prototype/scripts/test-p3-migration-structure.mjs` | `38fbc5ebd94108f2a5511154974032819379d46efd40acae42c5a06769905e57` |
| `supabase/roles.sql` | `96648642ac331df0fe801dadee5e1252cc80ec1ce792339d279d2624a59aea1a` |
| `supabase/seed.sql` | `d7d6468882d01760385cd4ad3cd0122dabdfca16aebd492fb4043a3decb16297` |
| `prototype/package.json` | `e0271a5dc4e410fad458ad88ac36b4d7b392a5b7c9e7158bef939b0ecc93d360` |

## Entry and runtime

- independent index-only follow-up 对以上候选给出 `REVIEW GO / P0=0 / P1=0 / P2=0`，只允许本次 bounded rerun。
- 入口预检确认目标 containers、volumes、network、`55320–55329` listeners 为空；`prototype/.env.local` 不存在且无重复生成文件。
- 唯一 `supabase start --yes` exit `0`；固定 Node `22.12.0` 的 AMR preflight 到达 `P2L_PREFLIGHT_PASS`；fresh `supabase db reset --local` exit `0`。
- P2-L + P3 四份 pgTAP：`Files=4, Tests=224, Failed=0, Result=PASS`。
- 三场景双连接批准/撤回竞争 harness 到达 `P3_APPROVAL_CONCURRENCY_PASS`。

## Database quality

- `supabase db lint --local --schema public,private --level warning --fail-on warning`：`No schema errors found`。
- security info/fail-on-warn：`No issues found`。
- performance warn/fail-on-warn：`No issues found`。
- all/info 只有 fresh empty database 的 10 条 `unused_index` INFO；`unindexed_foreign_keys=0`、`auth_rls_initplan=0`、WARN/ERROR=`0`。attempt #4 的复合外键 finding 已关闭。
- migration list 的 local/database history 完全一致：`20260831183358`、`20260903120000`。

## Application quality

- 固定 Node `22.12.0`：Auth contract `46/46` PASS。
- P2-L AMR structure、P2-L migration structure、P3 migration structure 均 PASS。
- TypeScript `--noEmit`、全量 ESLint、Next `16.3.2` production build、`git diff --check` 均 exit `0`。
- build 产生的 `prototype/next-env.d.ts` 路径漂移已恢复，文件不在最终 diff 中。

## Cleanup and privacy

- exact `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` exit `0`。
- start/reset raw 已删除；目标 containers、volumes、network 与 `55320–55329` listeners 均为空。
- 未使用 hosted/Production、Storage、真实 PII、真实商家资料、外部通知或生产凭据。

## Status

本 evidence 记录绑定候选完成一次完整 synthetic-only local runtime，但 initial final review 发现本目录只有摘要，缺少有限输出与 manifests，因此它不能单独作为独立可审计证明。后续以 [attempt #6 auditable PASS](../2026-09-03-runtime-attempt-6-pass/README.md) 为准；targeted reviewer GO 前不打开 P4，不推送 main，不部署。
