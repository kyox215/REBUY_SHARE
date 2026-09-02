# P2-L schema runtime attempt #14

日期：2026-09-03（Europe/Rome）
结果：**STOP / FAIL at strict warning lint；pgTAP 87/87 PASS**

## Entry and actual

- 重新加载 long-running、Supabase 与 Postgres/RLS 规范；breaking-change 索引未改变本地 P2-L 设计边界。
- CLI=`2.101.0`；从 attempt #13 exact cleanup 后空资源进入，分支、HEAD、唯一 worktree、静态结构门、Node syntax、diff check 与候选 hashes 一致。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`c8d9527f541d39c1131cd4ebf029348ccc6128fb`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`2ced32c0a8a24d6da93f6e921e94bc02fcda521c`。
- 空环境 start 通过；schema/security `54/54` 与 invitation flow `33/33`，合计 `87/87` PASS。Attempt #13 的 dead projections/control state 删除没有改变业务行为。
- strict lint 中 `v_existing_updated_at` warning 已消失，但 create implementation 的 loop 后首个 audit `PERFORM` 仍被 `plpgsql_check` 判为 unreachable；warning 即失败，advisors/migration list 未运行。

## Offline correction

- 确认上一候选虽然在 INSERT success 使用显式 `EXIT`，但 retry loop 后仍保留审计段，静态分析器仍不能证明该段可达。
- 新候选把唯一键冲突的 SELECT、idempotency/active/expiry 解析完整收进 `EXCEPTION WHEN unique_violation` handler；正常 INSERT 成功直接落到同一 loop iteration 内的 create audit 并 `RETURN`。冲突 handler 的每条路径只允许 RETURN、RAISE 或在成功 expire 后 CONTINUE。
- loop 后不再有代码，彻底消除“无限 loop 后可达性”争议；audit unique violation 也位于 invitation-insert exception handler 之外，不会被误当 invitation conflict。
- 静态门禁止 `EXIT insert_invitation` 和 dead states，要求只有 unique handler 进入冲突解析，并要求 create audit + RETURN 位于 retry loop 内。
- 新候选 hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`df777c36563657ef2d8e35826931f1a64046b2e1`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`062d5a002aded17a9e21b61c3a666a0bf578ff81`。
- `P2L_MIGRATION_STRUCTURE_PASS`、Node syntax 与 `git diff --check` 通过；本工作包不重跑 runtime。

## Cleanup and boundary

- strict lint FAIL 后立即 exact stop/no-backup，返回 `0`；目标 containers、volumes、network 与 `55320–55329` listeners 均为空。
- 精确临时 start log 已删除，未保留凭据、token、OTP、cookie、DB password 或真实 PII。
- 下一 bounded Gate 从空资源复验 `87/87` + zero-warning lint，再运行 advisors/migration list。P2-L 仍 OPEN，P3–P7、hosted/Production、main push/deploy 未打开。
