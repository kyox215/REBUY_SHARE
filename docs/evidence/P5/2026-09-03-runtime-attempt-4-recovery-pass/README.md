# P5 runtime attempt #4 recovery — auditable local PASS

日期：2026-09-03（Europe/Rome）

结果：**RECOVERY RUNTIME GATE PASS / FINAL INDEPENDENT REVIEW PENDING**

## Exact candidate and entry

- candidate commit=`bc8195929c58caf68173c1b4e2b1231a066b117d`；branch=`codex/rebuy-v1-local-complete`；origin/main=`3c6ebf20b56f7ab37956a4ad9c543389a5636e65`。
- local project=`rebuy-g2-a1-e2a-local-email-otp-exec`；CLI=`2.101.0`；Node=`22.12.0`；loopback=`3000,9225,55320–55329`。
- actual 前目标 containers、volumes、network、listeners 为空；source hashes 见 `candidate-sha256.txt`；本包唯一 fresh start/reset，`database_actual_count=1`。
- 前三轮失败均在测试 fixture/harness，环境均已 exact stop 并清理；达到普通失败上限后，专项独立复核给出 `RECOVERY GO`、P0/P1/P2=`0/0/0`，允许本轮一次 bounded recovery runtime。

## Runtime and quality

- 固定 Node 22 AMR 到达 `P2L_PREFLIGHT_PASS`；fresh reset exit `0`，四条 migration 与两份 seed 由空库重建。
- P2-L + P3 + P4 + P5 八份 pgTAP：`Files=8, Tests=446, Failed=0, Result=PASS`。
- P2-L 邀请、P3 审批、P4 库存、P5 checkout 与 P5 race 五套双连接/竞态 harness 全部 PASS；全局锁顺序、幂等重放、跨商家订单、取消竞态、库存碰撞和清理均通过。
- strict lint、security strict、performance/warn strict 均无问题；all/info 只有 31 条 fresh DB `unused_index` INFO，WARN/ERROR=`0`、`auth_rls_initplan=0`、`unindexed_foreign_keys=0`。
- migration list 的 local/database history 均为 `20260831183358,20260903120000,20260903170000,20260904120000`。
- Auth contract `46/46`、P2-L/P3/P4/P5 structure、typecheck、全量 ESLint、Next `16.3.2` production build、diff check 全部 PASS；build 生成漂移已恢复。
- 浏览器真实链路覆盖注册、已有账号登录、空购物车、无效商品恢复、加购、checkout 双提交、取消、移动端、跨用户订单拒绝、批发 MOQ，最终到达 `P5_BROWSER_E2E_PASS`。

## Auditable artifacts

- `entry.txt`、`amr-preflight.txt`、`reset.txt`、`pgtap.txt`、`concurrency.txt`、`lint.txt`、`advisors.txt`、`migration-list.txt`、`app-quality.txt`、`browser-e2e.txt` 保存本轮实际调用后立即记录的脱敏有限结果。
- `commands.txt` 保存顺序和 exact commands；`candidate-sha256.txt` 绑定源码；cleanup 后生成 `cleanup.txt` 与 `evidence-sha256.txt`。
- 工件不含 key、password、OTP、JWT、token、cookie、合成邮箱值、订单 UUID、provider response 或真实 PII。

## Boundary

- dev server 与 Chrome 均正常结束；exact stop/no-backup exit `0`；目标 containers、volumes、network、temp profile 与 listeners 均为空。
- 本包仅证明 synthetic-only local P5 runtime candidate；final independent GO 前不关闭 P5、不打开 P6，不外推到 hosted/Production。
- 证据 manifest 和 final independent review 完成前，不 push main，不部署。
