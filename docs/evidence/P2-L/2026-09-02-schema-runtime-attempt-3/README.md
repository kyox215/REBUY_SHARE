# P2-L schema runtime attempt #3

日期：2026-09-02（Europe/Rome）
结果：**STOP / FAIL；三次 runtime 尝试上限已到，不再补丁或重跑**

## Entry and actual

- Branch / HEAD：`codex/rebuy-v1-local-complete` / `0e5084b62c76275a781ec08edea287a06d442209`
- Worktree：`.worktrees/rebuy-v1-local-complete-exec`
- Local project / ports：`rebuy-g2-a1-e2a-local-email-otp-exec` / `55320–55329`
- CLI：`2.101.0`
- Entry：目标 containers、volumes、network 与 listeners 均为空；`git diff --check`、`P2L_MIGRATION_STRUCTURE_PASS`、目标 ESLint 通过。
- Actual hashes：
  - `supabase/roles.sql`：`7f1d81955b78f0879e2ea3870689079db239e0d3`
  - migration：`eb44217e56c1c16a7eb1edb9ca43f9ed2eb9ff84`
  - seed：`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`
  - schema pgTAP：`4ef991debd2d9b7a4414272eacf0ba80c716e970`
  - invitation pgTAP：`b53c224b282b0cc5270ad1de999f2bc67f72924b`
  - structure test：`0540f3117db0874fa6e0c38d750e16d5576b13ea`
- `actual_count=1`；唯一 `supabase start` 在 `Seeding globals from roles.sql` 阶段返回 `rebuy_invite_executor_role_membership_present`，exit `1`。
- 未进入 migration、业务 table DDL、seed、pgTAP、db reset、db lint、db advisors 或 migration list。

## Confirmed finding

把 executor 创建从 migration 移到 Supabase custom-role `roles.sql` 并未改变当前 CLI 本地 globals 阶段的执行身份语义。该阶段仍由具备 `CREATEROLE`、但不是 `SUPERUSER` 的角色创建 `rebuy_invite_executor`；PostgreSQL 17 自动产生 role-admin membership，随后同一文件的双向 `pg_auth_members` 零关系 guard 正确拒绝继续。

因此 attempt #2 的修复假设不成立；不能通过删除 guard 或放宽已批准的 executor 隔离合同换取通过。下一工作包必须先做无运行时的专项设计审查，确认一种能在创建时禁止自授予、且不引入 bootstrap superuser/service-role/hosted 管理路径的可复现方案，再建立新的、边界明确的验证 Gate。

官方依据：

- [PostgreSQL 17 Role Attributes](https://www.postgresql.org/docs/17/role-attributes.html)
- [PostgreSQL 17 `createrole_self_grant`](https://www.postgresql.org/docs/17/runtime-config-client.html#GUC-CREATEROLE-SELF-GRANT)
- [Supabase CLI custom roles / start](https://supabase.com/docs/reference/cli/supabase-start)

## Cleanup and boundary

- 失败后立即执行 exact `stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`，exit `0`。
- Cleanup 后目标 containers、volumes、network、`55320–55329` listeners 均为空；未使用 `--all`，Colima 未停止。
- 未记录 key、DB URL/password、token、JWT、cookie、raw status 或真实 PII。
- 本工作包未修改 `roles.sql`、migration、seed 或 tests，未 commit/push/deploy。
- P2-L runtime 未通过；P3–P7、hosted、Production、真实数据与外部发布继续关闭。
