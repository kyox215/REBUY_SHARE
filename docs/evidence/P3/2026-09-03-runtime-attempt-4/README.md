# P3 runtime attempt #4 — functional PASS, advisor INFO STOP

日期：2026-09-03（Europe/Rome）
范围：`synthetic-only local`；project=`rebuy-g2-a1-e2a-local-email-otp-exec`；loopback `55320–55329`

## 结果

- independent follow-up #2 对输入候选给出 `REVIEW GO / P0=0 / P1=0 / P2=0`，明确允许本次 bounded runtime。
- 空资源入口、唯一 start、固定 Node `22.12.0` AMR preflight、fresh reset 全部通过。
- P2-L + P3 四份 pgTAP 全部通过：`Files=4, Tests=223, Failed=0, Result=PASS`。
- 三场景双连接 harness 到达 `P3_APPROVAL_CONCURRENCY_PASS`。
- strict DB lint、security info/fail-on-warn、performance warn/fail-on-warn 均为 `No issues found`。
- all/info 首项发现 `merchant_application_private` 的复合 FK `(application_id, applicant_user_id)` 缺少覆盖索引；其余为 fresh DB unused-index INFO。为保持 `unindexed_foreign_keys=0` 的质量标准，本包在这里 STOP，没有继续 migration list 或 app quality。

## Cleanup

- exact stop/no-backup exit `0`；start/reset raw 已删除。
- 目标 containers、volumes、network 与 `55320–55329` listeners 均为空。
- 未接触 hosted/Production、secret、真实 PII、Storage 或外部通知。

## 离线修复

- 增加 `(application_id, applicant_user_id)` covering composite index，并由 schema pgTAP 与 structure verifier 同时锁定。
- 新 candidate 通过 Node 22 structure/syntax/定向 ESLint/diff check；重新 runtime 前须绑定新 hashes 做只读复核。
