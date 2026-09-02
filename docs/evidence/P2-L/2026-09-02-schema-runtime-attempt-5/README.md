# P2-L schema runtime attempt #5

日期：2026-09-02（Europe/Rome）
结果：**STOP / FAIL；migration 到达 private function owner transfer**

## Entry and actual

- Branch / base HEAD：`codex/rebuy-v1-local-complete` / `0e5084b62c76275a781ec08edea287a06d442209`
- Worktree / local project：`.worktrees/rebuy-v1-local-complete-exec` / `rebuy-g2-a1-e2a-local-email-otp-exec`
- CLI / Node / ports：`2.101.0` / `22.12.0` / `55320–55329`
- Entry：目标 containers、volumes、network 与 listeners 均为空；Auth `40/40`、typecheck、全量 lint、`P2L_PREFLIGHT_STRUCTURE_PASS`、`P2L_MIGRATION_STRUCTURE_PASS` 与 `git diff --check` 均通过。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`f2a76aaea9d3380117c7930ffbd7de3c27e45b6d`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`b9252cbf6c932ed1b9899e3048de660673f35587`；invitation pgTAP=`b53c224b282b0cc5270ad1de999f2bc67f72924b`；structure=`8fe75b64c45d3b1009c3dc8a297ed22f0716e094`。
- `actual_count=1`：唯一 `supabase start` 越过 globals、exact membership guard、conditional expressions、tables、policies 与 function creation；在 `ALTER FUNCTION private.create_membership_invitation_impl(...) OWNER TO rebuy_invite_executor` 返回 `must be able to SET ROLE "rebuy_invite_executor"` / SQLSTATE `42501`。
- 未进入 seed、pgTAP、db reset、db lint/advisors 或 migration list；未保留 key、DB URL/password、OTP、token、JWT、cookie、raw status 或真实 PII。

## Confirmed platform rule

PostgreSQL 17 明确要求 function owner transfer 的当前会话能 `SET ROLE` 到新 owner，新 owner还必须对目标 schema 有 `CREATE`。当前最终 bootstrap grant 为 `SET=false`，executor 对 private schema 只有 `USAGE`，所以按现合同无法完成 owner transfer。

官方依据：

- [PostgreSQL 17 ALTER FUNCTION](https://www.postgresql.org/docs/17/sql-alterfunction.html)
- [PostgreSQL 17 GRANT on roles](https://www.postgresql.org/docs/17/sql-grant.html)
- [PostgreSQL 17 role membership](https://www.postgresql.org/docs/17/role-membership.html)
- [PostgreSQL 17 REVOKE](https://www.postgresql.org/docs/17/sql-revoke.html)

## Cleanup and boundary

- 失败后立即执行 exact `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`，exit `0`。
- Cleanup 后目标 containers、volumes、network 与 `55320–55329` listeners 均为空；未使用 `--all`。
- 本批未实现临时 SET/CREATE 例外，也未重跑。P2-L、P3–P7、hosted/Production、main push/deploy 保持关闭。
