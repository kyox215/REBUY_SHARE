# P2-L schema runtime attempt #1

日期：2026-09-02（Europe/Rome）
结果：**STOP / FAIL；确定性根因已修，尚未重跑**

## Entry

- Branch：`codex/rebuy-v1-local-complete`
- HEAD：`0e5084b62c76275a781ec08edea287a06d442209`
- Worktree：`.worktrees/rebuy-v1-local-complete-exec`
- Local project：`rebuy-g2-a1-e2a-local-email-otp-exec`
- Loopback ports：`55320–55329`
- Supabase CLI：`2.101.0`
- 入口状态：目标 containers、volumes、network 与 listeners 均为空；migration/seed/两份 pgTAP 文件、结构测试、分支与 cwd 已核对。
- 用户授权：`允许之后的所有批准` 仅绑定此前已完整展示的 P2-L schema runtime exact phrase；不外推 hosted/Production/真实数据/付费资源。

## Actual result

- `actual_count=1`；执行 `supabase start`，含本地 key/DB URL 的标准输出被抑制。
- Migration：`20260831183358_p2l_local_schema_rls_invites.sql`
- Pre-actual migration hash：`c32318bb90fa28c0f6b12e94721dd261b00ba441`
- 有限错误：SQLSTATE `42501`，非 SUPERUSER migration runner 无权执行包含 `NOSUPERUSER` 的 `ALTER ROLE rebuy_invite_executor`。
- 未到达：seed、pgTAP、db lint、db advisors。
- 未保留：local keys、DB URL/password、token、JWT、cookie、raw status 或真实 PII。

## Root cause and candidate fix

PostgreSQL 把 `SUPERUSER/NOSUPERUSER` 视为只有 SUPERUSER 才能改变的角色属性。创建语句本身已经用全部 `NO*` 属性建立安全角色，因此后续 `ALTER ROLE ... NOSUPERUSER` 既多余又与 migration runner 权限不兼容。

当前候选删除后续 `ALTER ROLE`，创建时仍固定：

- `NOLOGIN`
- `NOSUPERUSER`
- `NOCREATEDB`
- `NOCREATEROLE`
- `NOINHERIT`
- `NOREPLICATION`
- `NOBYPASSRLS`

同名角色若已存在，则查询上述七个危险属性；任一开启即抛出 `rebuy_invite_executor_attributes_invalid`，不会尝试静默改变或提权修复。

- Fixed migration hash：`6ca01ad8f3508b7df8408cef400e3ff7a465c679`
- Migration structure test hash：`abb0510d2bf7621743462175c6a0e9a5450ebaab`
- Static verification：`P2L_MIGRATION_STRUCTURE_PASS`、目标 ESLint、`git diff --check`。

## Cleanup and boundary

- `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`：exit `0`。
- Cleanup 后目标 containers、volumes、network 与 `55320–55329` listeners：空。
- 本工作包不重跑 actual；修复尚未建立 runtime PASS。
- 未 commit、push、deploy；P3–P7、hosted、Production 与真实数据继续关闭。
