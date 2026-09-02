# P2-L schema runtime attempt #9

日期：2026-09-03（Europe/Rome）
结果：**STOP / FAIL in pgTAP evidence query；schema security file 全部通过，invitation RPC 前三项通过**

## Entry and actual

- 本轮重新加载 long-running、Supabase 与 Postgres/RLS 规则；Supabase breaking-change 索引确认平台 `auth` schema 限制和 public table 显式 Data API 暴露要求与当前 least-privilege 设计一致。
- CLI=`2.101.0`；分支/HEAD/worktree/project/ports 未变。结构门、`git diff --check`、目标 containers/volumes/network/listeners 入口通过。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`4d4cab7415312fe361a95a3afb873ebcd2dc7e51`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`889c21e63ec1a3986e7ba53ee783c86af36a010f`；structure=`baa32ffec5d016093a66ce801f45ded09c7040bb`。
- `supabase start --yes` 从空资源完成 roles、migration、owner handoff、helper/ACL、seed 和 health checks，且不再出现 attempt #8 的 ACL warnings。
- `p2l_schema_security.test.sql`：全部通过。
- `p2l_invitation_flows.test.sql`：前三个 RPC/expiry/idempotency assertions 通过；随后测试仍以 `authenticated` 直接 SELECT `membership_invitations` 做证据计数，被数据库按设计拒绝。失败证明“authenticated 无邀请表 direct grant”正在生效，不是 wrapper 业务失败。
- pgTAP Gate 因测试 harness 身份错误停止；lint/advisors/migration list 未运行。

## Offline correction and cleanup

- 在需要核对 invitation/membership/scope/audit 持久状态的测试证据段前 `RESET ROLE` 回到测试管理员，核对后立即恢复 `SET LOCAL ROLE authenticated` 再调用 RPC；JWT request GUC 保持在同一测试事务内。
- 静态门新增 role-state 扫描：忽略 `$sql$` 中刻意以 authenticated 执行的 RPC，但禁止 authenticated 身份在测试正文直接读取四张受保护表。
- 新候选 hashes：invitation pgTAP=`ae36795623bc23edcf721a10b71e9a2b6916ca91`；structure=`bc227db974da8e4bd6ede60199feb1858468230f`；其余 actual hashes不变。结构门、Node syntax 与 diff check 通过。
- exact stop/no-backup exit `0`；目标 containers、volumes、network/listeners 均为空。本包未重跑。
