# P4 runtime attempt #5 — auditable local PASS

日期：2026-09-03（Europe/Rome）

结果：**RUNTIME GATE PASS / FINAL INDEPENDENT REVIEW PENDING**

## Exact candidate and entry

- candidate commit=`abf4dfa0367c60310fcb29a932cd99d559c55a17`；branch=`codex/rebuy-v1-local-complete`；origin/main=`3c6ebf20b56f7ab37956a4ad9c543389a5636e65`。
- local project=`rebuy-g2-a1-e2a-local-email-otp-exec`；CLI=`2.101.0`；Node=`22.12.0`；loopback=`55320–55329`。
- actual 前目标 containers、volumes、network、listeners 为空；source hashes 见 `candidate-sha256.txt`；本包唯一 start，`database_actual_count=1`。
- 达到普通三次失败上限及 recovery #4 后均停止并完成清理；两轮专项独立复核分别给出 recovery GO，P0/P1/P2=`0/0/0`。历史有限分类见 `recovery-history.txt`。

## Runtime and quality

- 固定 Node 22 AMR 到达 `P2L_PREFLIGHT_PASS`；fresh reset exit `0`，三条 migration 与 seed 全部由空库重建。
- P2-L + P3 + P4 六份 pgTAP：`Files=6, Tests=364, Failed=0, Result=PASS`。
- 三场景双连接 harness 到达 `P4_INVENTORY_CONCURRENCY_PASS`：同键返回稳定原结果；不同键标准库存与二手 unit 均只有一个成功，loser 为 `inventory_version_conflict`；不存在 deadlock/timeout；fixture 与临时角色清理通过并保留 Supabase bootstrap membership。
- strict lint、security strict、performance/warn strict 均无问题；all/info 只有 41 条 fresh DB `unused_index` INFO，WARN/ERROR=`0`、`auth_rls_initplan=0`、`unindexed_foreign_keys=0`。
- migration list 的 local/database history 均为 `20260831183358,20260903120000,20260903170000`。
- Auth contract `46/46`、P2-L/P3/P4 structure、typecheck、全量 ESLint、Next `16.3.2` production build 和 diff check 全部 PASS；build 生成漂移已恢复。

## Auditable artifacts

- `entry.txt`、`amr-preflight.txt`、`reset.txt`、`pgtap.txt`、`concurrency.txt`、`lint.txt`、`advisors.txt`、`migration-list.txt`、`app-quality.txt` 保存本次实际调用后立即记录的脱敏有限结果。
- `commands.txt` 保存顺序和 exact commands；`candidate-sha256.txt` 绑定源码；cleanup 后生成 `cleanup.txt` 与 `evidence-sha256.txt`。
- 工件不含 key、password、OTP、JWT、token、cookie、合成邮箱值、provider response 或真实 PII。

## Boundary

- exact stop/no-backup exit `0`；start/reset raw 已删除；目标 containers、volumes、network 与 listeners 均为空。
- 本包仅证明 synthetic-only local P4 runtime candidate；final independent GO 前不关闭 P4、不打开 P5，不外推到 hosted/Production。
- 证据 manifest 和 final independent review 完成前，不 push main，不部署。
