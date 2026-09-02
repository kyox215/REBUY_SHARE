# P2-L schema runtime attempt #12

日期：2026-09-03（Europe/Rome）
结果：**STOP / FAIL at db lint；pgTAP 87/87 PASS**

## Entry and actual

- 重新加载 long-running、Supabase 与 Postgres/RLS 规范；Supabase breaking-change 索引继续确认 public Data API 显式授权和平台 schema 限制与当前 least-privilege 方案一致。
- CLI=`2.101.0`；从 attempt #11 exact cleanup 后的空目标资源进入。分支、HEAD、唯一 worktree、结构门、Node syntax、`git diff --check` 与候选 hashes 一致。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`671fcfe764d73c7a821067c290b47d86220fd291`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`aa0c24bdeb3cc26ec87018348c68bcdd29970bd9`。
- `supabase start --yes` 从空资源完成 roles、migration、owner handoff、helper/ACL、seed 与 health checks。
- `supabase test db --local` 同时执行两份文件：schema/security `54/54`、invitation flow `33/33`，合计 `87/87` PASS。Attempt #11 的 acceptance audit 修复已由真实 runtime 证明。
- `supabase db lint --local --schema public,private --level warning --fail-on error` 返回一个 error：`private.create_membership_invitation_impl` 的 expiry UPDATE 使用未限定 `expires_at`，与 PL/pgSQL 返回列同名；另报告两个未使用变量 warning。
- Gate 在 lint 停止；security/performance advisors 与 migration list 未运行，本次不得记录为 P2-L PASS。

## Offline correction

- 两个同构的过期邀请 UPDATE 均改为 `UPDATE public.membership_invitations AS i`，且 `id/status/expires_at` 全部使用目标表别名；消除与输出列 `expires_at` 的歧义，不改变行条件或事务语义。
- 删除锁行后从未消费的 `v_invitation_updated_at` 快照；删除未参与授权决策的 creator role scope 读取。实际 creator 授权仍由 locked active membership、exact role/version/org、active role、`member.invite` permission 和显式 active organization/store scope 联合决定。
- 静态门新增禁止 expiry UPDATE 使用未限定 `expires_at` 的回归断言。
- 新候选 hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`15e83f403e421400672dc81aa547f44e3c911cc8`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`552622076713c5d60d23a13b90fa686eac9383e8`。
- 修复后 `P2L_MIGRATION_STRUCTURE_PASS`、Node syntax、`git diff --check` 通过；本工作包不重跑 runtime。

## Cleanup and boundary

- lint FAIL 后立即精确执行 `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`，返回 `0`；目标 containers、volumes、network 与 `55320–55329` listeners 均为空，未使用 `--all`。
- 敏感 start output 未纳入仓库或证据；未保存 local key、DB URL、token、cookie、OTP、DB password、provider response 或真实 PII。
- 下一 bounded Gate 从空资源复验 `87/87`、零 lint error/warning，再运行 advisors 与 migration list。P2-L 仍 OPEN；P3–P7、hosted/Production、main push/deploy 未打开。
