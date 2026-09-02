# P2-L schema runtime attempt #16

日期：2026-09-03（Europe/Rome）
结果：**RUNTIME PASS / INDEPENDENT REVIEW PENDING**

## Entry and integrity

- 使用 long-running、Supabase 与 Postgres/RLS/索引规范；先读取 Supabase 官方 changelog。当前最新 breaking changes 中，Management API logs endpoint、extension version pinning、self-hosted Envoy/API URL、platform-owned Realtime schema、Postgres 17 与 Data API 显式暴露要求均未改变本地 P2-L 验证路径。
- 唯一写入 worktree=`/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划/.worktrees/rebuy-v1-local-complete-exec`；branch=`codex/rebuy-v1-local-complete`；base HEAD=`0e5084b62c76275a781ec08edea287a06d442209`；local project id=`rebuy-g2-a1-e2a-local-email-otp-exec`。
- CLI 固定为本 Gate 已预检的 `2.101.0`；运行时提示 `2.116.0` 可用，但没有在 Gate 中途变更工具链。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`11a7ffc7daf34833a81f7eec78138e5055b876f2`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`7a2e43343c7bba4e08a06d56c989f15e66430785`。
- 实际调用前，结构门输出 `P2L_MIGRATION_STRUCTURE_PASS`，Node syntax 与 `git diff --check` 通过；目标 containers、volumes、network 与 `55320–55329` listeners 均为空。沙箱内 CLI help 因用户级 telemetry 文件权限失败，只读预检以获批的受控权限重新执行后通过，不计入数据库 actual；本批数据库实际启动仍恰好一次。

## Runtime results

- 唯一 `supabase start --yes` exit `0`；可能包含本地 key/URL 的输出仅进入精确临时文件，不进入终端、证据或仓库。
- `supabase test db --local supabase/tests/p2l_schema_security.test.sql supabase/tests/p2l_invitation_flows.test.sql`：两文件全部通过，schema/security `54/54` + invitation `33/33`，合计 `87/87` PASS。
- `supabase db lint --local --schema public,private --level warning --fail-on warning`：`No schema errors found`，exit `0`。
- `supabase db advisors --local --type security --level info --fail-on warn`：`No issues found`，exit `0`。
- `supabase db advisors --local --type performance --level warn --fail-on warn`：`No issues found`，exit `0`。
- all/info JSON 精确解析：`total=23`、`INFO=23`、规则全部为 `unused_index`；`auth_rls_initplan=0`、`unindexed_foreign_keys=0`、WARN/ERROR=`0`。这些 unused-index INFO 来自无代表性业务流量的 fresh empty database，不构成移除 FK/RLS/query-path 索引的证据。
- `supabase migration list --local`：local 与 database history 均只有 `20260831183358`，一致性检查通过。

## Cleanup, status, and next Gate

- `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` exit `0`；精确 start/advisors 临时文件删除并确认不存在。
- 目标 containers、volumes、network 与 `55320–55329` listeners 均为空，输出 `P2L_ATTEMPT16_CLEANUP_PASS`。
- 本次建立 P2-L schema/RLS/runtime PASS 证据，但 P2-L Exit 合同还要求独立审查。当前状态因此为 **RUNTIME PASS / INDEPENDENT REVIEW PENDING**，不是完整 P2-L PASS，也不是完整 P2/G2-A1/hosted/Production 通过。
- 独立复审需要绑定上述 exact candidate hashes 与本证据，至少覆盖角色/owner-transfer 例外、RLS/grants、request GUC init-plan、invitation create/accept 事务、pgTAP 覆盖与 advisors 判定。只读输入见 [independent review packet](../2026-09-03-independent-review-packet/README.md)；复审完成前不打开 P3–P7，不 push main，不部署。
