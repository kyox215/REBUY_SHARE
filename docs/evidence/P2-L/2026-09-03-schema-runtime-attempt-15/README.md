# P2-L schema runtime attempt #15

日期：2026-09-03（Europe/Rome）
结果：**STOP / FAIL at advisors；pgTAP 87/87 PASS；strict warning lint PASS**

## Entry and actual

- 重新加载 long-running、Supabase 与 Postgres/RLS/索引规范，并复核 Supabase breaking-change 索引；本次没有扩大 local synthetic-only P2-L 边界。
- CLI=`2.101.0`；从 attempt #14 exact cleanup 后空资源进入，分支、HEAD、唯一 worktree、静态结构门、Node syntax、diff check 与候选 hashes 一致。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`df777c36563657ef2d8e35826931f1a64046b2e1`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`062d5a002aded17a9e21b61c3a666a0bf578ff81`。
- 空环境 `supabase start --yes` 通过；schema/security `54/54` 与 invitation flow `33/33`，合计 `87/87` PASS。
- `supabase db lint --local --schema public,private --level warning --fail-on warning` 返回 `No schema errors found`，exit `0`；attempt #14 的 unreachable warning 已关闭。
- `supabase db advisors --local --type all --level info --fail-on error` exit `0`，但报告了项目自有对象的 14 条 `auth_rls_initplan` WARN 和 4 条 `unindexed_foreign_keys` INFO；另有 fresh empty database 的 `unused_index` INFO。上线保障 Gate 不把仅有 exit `0` 视为通过，因此在 advisors 停止，未运行 migration list。

## Offline correction

- 14 条 warning 精确对应 16 条 executor policy 中直接读取请求 GUC 的 14 条；另两条只调用已缓存的 project-owned request helper。候选只在 policy 区间把每个 `pg_catalog.current_setting(...)` 包装为 scalar `(SELECT ...)`，允许 PostgreSQL 生成 statement init plan；不修改 implementation function 的 `set_config` 或 helper 读取语义。
- 为四个复合外键按相同 leading-column 顺序补齐覆盖索引：memberships source invitation `(source_invitation_id, organization_id, organization_type)`；accepted membership `(accepted_membership_id, accepted_user_id, organization_id, organization_type)`；两条 audit event 外键分别以 invitation/membership id 开头并覆盖 organization id/type。
- 保留 source invitation 的 partial unique index；它继续承担业务唯一性，而新增/扩展的非 partial composite index承担完整外键 lookup。fresh empty database 的 `unused_index` 只表示本次无代表性业务流量，不据此移除支撑 FK/RLS/查询路径的索引。
- 静态门新增两类 fail-closed 回归：executor policy 区间不得出现未包裹的 `current_setting`；四个索引必须保留精确列顺序。
- 新候选 hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`11a7ffc7daf34833a81f7eec78138e5055b876f2`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`7a2e43343c7bba4e08a06d56c989f15e66430785`。
- `P2L_MIGRATION_STRUCTURE_PASS`、Node syntax 与 `git diff --check` 通过；本工作包不重跑 runtime。

## Cleanup and boundary

- advisors 后立即 exact stop/no-backup，返回 `0`；目标 containers、volumes、network 与 `55320–55329` listeners 均为空。
- 精确临时 start log 已删除；未保留 key、DB URL/password、token、OTP、cookie、JWT 或真实 PII。
- 下一 bounded Gate 从空资源复验 `87/87`、zero-warning lint、security/performance advisors；只有项目 RLS init-plan warning 与四条 missing-FK finding 均消失后才运行 migration list。P2-L 仍 OPEN，P3–P7、hosted/Production、main push/deploy 未打开。
