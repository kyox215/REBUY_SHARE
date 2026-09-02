# P2-L schema runtime attempt #11

日期：2026-09-03（Europe/Rome）
结果：**STOP / FAIL at acceptance audit；schema security 54/54，invitation 27/33**

## Entry and actual

- Attempt #10 已记录且离线修复后，结构门、Node syntax、`git diff --check`、候选 hashes 和目标 containers/volumes/network/listeners 空状态均通过。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`a3af0497b47caa2511896a4a16a070015f45d584`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`588aafb5f165e6f7e93cc0336bedda20130ac4df`。
- `supabase start --yes` 从空资源完成 roles、migration、owner handoff、helper/ACL、seed 与 health checks；敏感 start output 只写临时文件且未纳入证据或仓库。
- 首次测试调用误用了本机 CLI 不支持的 `--file`，只输出 help 并未连接数据库或执行任何断言；随后按 CLI `2.101.0` 的 `path...` 位置参数继续同一未变候选。
- `p2l_schema_security.test.sql`：`54/54` PASS。
- `p2l_invitation_flows.test.sql`：执行 33 条，27 条通过。Attempt #10 的 invitation update RLS 与末尾 store-creator fixture 问题均已解除；第 7 条首次接受走到 acceptance audit 后，`audit_logs` insert 被严格 RLS 拒绝，导致第 8–12 条同事务依赖断言失败。其余 27 条通过。
- Gate 当场停止；lint、advisors、migration list 未运行。

## Confirmed root cause and offline correction

- Invitation update 前必须把 `rebuy.invite.created_at` 恢复为 locked invitation 的 immutable original timestamp；该更新完成后，accept flow 直接切换到 `accept_audit`，但没有把同一个上下文键重新绑定为 audit row 的 `v_now`。审计 policy 要求 inserted `created_at` 与受信上下文相等，因而正确拒绝。
- 修复不更改 policy、grant 或用户输入：进入 `accept_audit` 后、插入 `audit_logs` 前，将 `rebuy.invite.created_at` 明确绑定为数据库事务时间 `v_now`。
- 静态门新增回归：`accept_audit` op 与 `audit_logs` insert 之间必须存在 `created_at=v_now` 绑定。
- 新候选 hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`671fcfe764d73c7a821067c290b47d86220fd291`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`aa0c24bdeb3cc26ec87018348c68bcdd29970bd9`。
- 修复后 `P2L_MIGRATION_STRUCTURE_PASS`、Node syntax 与 `git diff --check` 通过；本工作包不重跑 runtime。

## Cleanup and boundary

- 失败后立即精确执行 `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`，返回 `0`；目标 containers、volumes、network 与 `55320–55329` listeners 均为空，未使用 `--all`。
- 未保存 local key、DB URL、token、cookie、OTP、DB password、provider response 或真实 PII。
- 下一 bounded Gate 从空资源复验同一 54+33 矩阵；通过后才继续 lint/advisors/migration list。P2-L 仍 OPEN，P3–P7、hosted/Production、main push/deploy 未打开。
