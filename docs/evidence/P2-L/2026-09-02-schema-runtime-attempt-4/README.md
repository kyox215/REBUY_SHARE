# P2-L schema runtime attempt #4

日期：2026-09-02（Europe/Rome）
结果：**STOP / FAIL；exact executor bootstrap 已通过，migration 暴露 SQL conditional-expression 错误**

## Entry and actual

- Branch / base HEAD：`codex/rebuy-v1-local-complete` / `0e5084b62c76275a781ec08edea287a06d442209`
- Worktree：`.worktrees/rebuy-v1-local-complete-exec`
- Local project / ports：`rebuy-g2-a1-e2a-local-email-otp-exec` / `55320–55329`
- CLI / Node：`2.101.0` / `22.12.0`
- Entry：目标 containers、volumes、network 与 listeners 均为空；Auth `40/40`、typecheck、全量 lint、Next build、两个 P2-L 结构门及 `git diff --check` 均通过。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`d1ae4d1a7ae8cee9e47cf06864e2a1deda54e30a`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`b9252cbf6c932ed1b9899e3048de660673f35587`；invitation pgTAP=`b53c224b282b0cc5270ad1de999f2bc67f72924b`；structure=`9d7790cc3e2ea45f87ea7375b88e0cd2fa70b312`。
- `actual_count=1`：唯一 `supabase start` 完成 `roles.sql` 并进入 migration，随后在 `profiles_executor_self_insert` policy 返回 `function pg_catalog.nullif(text, unknown) does not exist` / SQLSTATE `42883`。
- 未进入 seed、pgTAP、db reset、db lint/advisors 或 migration list；未保留 key、DB URL/password、OTP、token、JWT、cookie、raw status 或真实 PII。

## Root cause and offline fix

PostgreSQL 的 `NULLIF`、`COALESCE` 与 `EXTRACT` 是特殊 SQL 表达式语法，而不是可以通过 `pg_catalog.<name>(...)` 调用的普通函数。migration 中同类写法已全部离线替换为合法语法；结构测试新增断言，禁止这三种 schema-qualified 形式再次进入候选。修复后 migration hash=`f2a76aaea9d3380117c7930ffbd7de3c27e45b6d`；本工作包不重跑 runtime。

## Cleanup and boundary

- 失败后立即执行 exact `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`，exit `0`。
- Cleanup 后目标 containers、volumes、network 与 `55320–55329` listeners 均为空；未使用 `--all`，Colima 未停止。
- Exact bootstrap 例外已越过实际 globals/migration guard，但 P2-L schema/RLS runtime 仍未通过；P3–P7、hosted/Production、main push/deploy 保持关闭。
