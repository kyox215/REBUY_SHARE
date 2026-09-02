# P2-L schema runtime attempt #10

日期：2026-09-03（Europe/Rome）
结果：**STOP / FAIL in invitation matrix；schema security 全部通过，invitation pgTAP 26/33 通过**

## Entry and actual

- 从 attempt #9 exact cleanup 后的空目标资源进入；CLI=`2.101.0`，结构门、`git diff --check`、目标 containers/volumes/network/listeners 入口通过。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`4d4cab7415312fe361a95a3afb873ebcd2dc7e51`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`ae36795623bc23edcf721a10b71e9a2b6916ca91`；structure=`bc227db974da8e4bd6ede60199feb1858468230f`。
- `supabase start --yes` 从空资源完成 roles、migration、owner handoff、helper/ACL、seed 与 health checks，且无 ACL warnings。
- `p2l_schema_security.test.sql`：全部通过。
- `p2l_invitation_flows.test.sql`：执行 33 条，26 条通过。第 7 条首次接受 organization invitation 在更新 `membership_invitations` 时触发 SQLSTATE `42501` / new row violates row-level security policy；第 8–12 条因该事务回滚而没有 membership/scope/audit/replay 前置状态；第 32 条 store invitation create 返回 `organization_not_available`。
- Gate 当场停止；lint、advisors、migration list 未运行，本次失败不记为 P2-L PASS。

## Confirmed root cause and offline correction

- 接受实现先把 `rebuy.invite.created_at` 切换为 membership 创建时间，用于受约束地插入新 membership；随后更新 invitation 前没有恢复 invitation 原始 `created_at`，也没有加载及恢复已锁定 invitation 的 `idempotency_key`。严格 `membership_invitations_executor_update WITH CHECK` 因此按设计拒绝新行。
- 修复不放宽 RLS：锁行读取新增 invitation `idempotency_key`；执行 invitation update 前把 `idempotency_key` 和原始 invitation `created_at` 重写入受信事务上下文，再由既有 policy 同时绑定 immutable fields、accepted identity、membership、consumed/updated timestamps。
- 第 32 条不是业务权限缺陷：前一负向用例把 request claims 留在 target user，末尾 store create 没有恢复 creator。测试在调用前重新建立 creator 的 recent-OTP signed claims。
- 静态门新增两项回归：accept 必须在行锁读取 persisted idempotency key；RLS update 前必须恢复该 key 与 invitation 原始 created_at。
- 新候选 hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`a3af0497b47caa2511896a4a16a070015f45d584`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`588aafb5f165e6f7e93cc0336bedda20130ac4df`。
- 修复后 `P2L_MIGRATION_STRUCTURE_PASS` 与 `git diff --check` 通过；本工作包不原地重跑。

## Cleanup and boundary

- 失败后立即精确执行 `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`，返回 `0`；目标 containers、volumes、network 与 `55320–55329` listeners 均为空，未使用 `--all`。
- 未保存 local key、DB URL、token、cookie、OTP、DB password、provider response 或真实 PII。
- 下一 bounded Gate 只从空资源验证新候选 invitation 矩阵；通过后才继续 lint/advisors/migration list。P3–P7、hosted/Production、main push/deploy 尚未因本次运行打开。
