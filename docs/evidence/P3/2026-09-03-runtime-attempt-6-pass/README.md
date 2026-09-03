# P3 runtime attempt #6 — auditable local PASS

日期：2026-09-03（Europe/Rome）

结果：**RUNTIME GATE PASS / TARGETED INDEPENDENT REVIEW PENDING**

## Exact candidate and entry

- candidate commit=`6e3cd7bbd3cd89b2ebbe7d97b4d69b2a23ace365`；branch=`codex/rebuy-v1-local-complete`；origin/main=`3c6ebf20b56f7ab37956a4ad9c543389a5636e65`。
- local project=`rebuy-g2-a1-e2a-local-email-otp-exec`；CLI=`2.101.0`；Node=`22.12.0`；loopback=`55320–55329`。
- actual 前目标 containers、volumes、network、listeners 为空；`.env.local` 不存在且无 `* 2.*` 重复生成文件。
- source hashes 见 `candidate-sha256.txt`；本包唯一 start，`database_actual_count=1`。

## Runtime and quality

- 固定 Node 22 AMR 到达 `P2L_PREFLIGHT_PASS`；fresh reset exit `0`。
- P2-L + P3 四份 pgTAP：`Files=4, Tests=224, Failed=0, Result=PASS`。
- 三场景双连接 harness 到达 `P3_APPROVAL_CONCURRENCY_PASS`；同键结果稳定、不同键只有一个成功且 loser 为 `merchant_application_state_conflict`、save/withdraw 锁序与最终零残留均通过。
- strict lint、security strict、performance/warn strict 均无问题；all/info 只有 10 条 fresh DB `unused_index` INFO，`auth_rls_initplan=0`、`unindexed_foreign_keys=0`、WARN/ERROR=`0`。
- migration list 的 local/database history 都是 `20260831183358,20260903120000`。
- Auth contract `46/46`、P2-L/P3 structure、typecheck、全量 ESLint、Next `16.3.2` production build 和 diff check 全部 PASS；build 生成漂移已恢复。

## Auditable artifacts

- `entry.txt`、`amr-preflight.txt`、`reset.txt`、`pgtap.txt`、`concurrency.txt`、`lint.txt`、`advisors.txt`、`migration-list.txt`、`app-quality.txt` 保存本次实际调用后立即记录的脱敏有限输出。
- `commands.txt` 保存顺序和 exact commands；`candidate-sha256.txt` 绑定源码；`evidence-sha256.txt` 绑定本目录除自身外的全部证据文件。
- 工件不含 key、password、OTP、JWT、token、cookie、合成邮箱值、provider response 或真实 PII。

## Cleanup and boundary

- exact stop/no-backup exit `0`；start/reset raw 已删除；目标 containers、volumes、network 与 listeners 均为空。
- 本包只修复前次 reviewer 的 `P2-E01` evidence finding，源码候选保持不变。targeted reviewer GO 前 P3 local Exit 仍不关闭，P4、hosted/Production、main push/deploy 继续 CLOSED。
