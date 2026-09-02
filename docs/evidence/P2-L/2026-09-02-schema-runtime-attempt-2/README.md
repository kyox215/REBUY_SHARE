# P2-L schema runtime attempt #2

日期：2026-09-02（Europe/Rome）
结果：**STOP / FAIL；PostgreSQL 17 自动 role-admin grant 根因已修，尚未重跑**

## Entry and actual

- Branch / HEAD：`codex/rebuy-v1-local-complete` / `0e5084b62c76275a781ec08edea287a06d442209`
- Worktree：`.worktrees/rebuy-v1-local-complete-exec`
- Local project / ports：`rebuy-g2-a1-e2a-local-email-otp-exec` / `55320–55329`
- CLI：`2.101.0`
- Pre-actual migration hash：`6ca01ad8f3508b7df8408cef400e3ff7a465c679`
- 入口资源、结构门、文件 hashes 与端口：PASS。
- `actual_count=1`；唯一 `supabase start` 在 migration 的 `pg_auth_members` 双向零关系 guard 处返回 `rebuy_invite_executor_role_membership_present`。
- 未进入：业务 table DDL、seed、pgTAP、db lint、db advisors。

## Root cause

PostgreSQL 17 对非 SUPERUSER `CREATEROLE` 创建的新角色自动建立一条相当于以下语义的管理关系：

`ADMIN TRUE / SET FALSE / INHERIT FALSE`

该 grant 由 bootstrap superuser 建立，创建者自己不能删除。此前 migration runner 创建 executor，因此即使 executor 本身七项属性均安全，catalog 中仍必然出现一条 membership。P2-L Gate 明确要求 executor 作为 granted role 或 member 的双向查询均为空，所以 guard 的 STOP 是正确行为。

官方依据：

- [PostgreSQL 17 Role Attributes](https://www.postgresql.org/docs/17/role-attributes.html)
- [PostgreSQL 17 `createrole_self_grant`](https://www.postgresql.org/docs/17/runtime-config-client.html#GUC-CREATEROLE-SELF-GRANT)
- [Supabase CLI custom roles / start](https://supabase.com/docs/reference/cli/supabase-start)

## Candidate fix

- 新增 `supabase/roles.sql`，由 Supabase globals 阶段在 migration 前创建 executor。
- `roles.sql` 创建时固定 `NOLOGIN/NOSUPERUSER/NOCREATEDB/NOCREATEROLE/NOINHERIT/NOREPLICATION/NOBYPASSRLS`，并对危险属性与双向 membership fail closed。
- Migration 不再 CREATE 或 ALTER cluster role，只验证角色存在、安全属性和双向 membership。
- Roles hash：`233d6fb4bf048bc99d027e0cf98b2463513cc216`
- Migration hash：`bdf9fc156920ed2cdeded27a655551046a52e24f`
- Structure test hash：`eaf7aa321dfdee678762d078fabadf210749c978`
- Static verification：`P2L_MIGRATION_STRUCTURE_PASS`、目标 ESLint、`git diff --check`。

## Cleanup and boundary

- Exact `stop --project-id ... --no-backup`：exit `0`。
- Cleanup 后目标 containers、volumes、network、`55320–55329` listeners：空。
- 未记录 key、DB URL/password、token、JWT、cookie、raw status 或真实 PII。
- 本工作包不重跑 actual；P2-L runtime 仍未通过，未 commit/push/deploy。
