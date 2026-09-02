# P2-L schema runtime attempt #13

日期：2026-09-03（Europe/Rome）
结果：**STOP / FAIL at strict warning lint；pgTAP 87/87 PASS**

## Entry and actual

- 重新加载 long-running、Supabase 与 Postgres/RLS 规范，并复核 Supabase breaking-change 索引；当前显式 grants、platform-schema isolation 与 pinned local PG17 设计保持适用。
- CLI=`2.101.0`；从 attempt #12 exact cleanup 后的空目标资源进入。分支、HEAD、唯一 worktree、结构门、Node syntax、`git diff --check` 与候选 hashes 一致。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`15e83f403e421400672dc81aa547f44e3c911cc8`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`552622076713c5d60d23a13b90fa686eac9383e8`。
- 空环境 `supabase start --yes` 通过；两份 pgTAP 合计 `87/87` PASS，证明 attempt #12 的 column qualification 未改变事务/RLS 行为。
- 严格运行 `supabase db lint --local --schema public,private --level warning --fail-on warning`：attempt #12 的 ambiguity error 与两个旧 dead-variable warnings 已消失；剩余两个新暴露 warning 为 create implementation 的 loop-after code 被判 unreachable，以及 `v_existing_updated_at` never read。
- Gate 在 strict lint 停止；advisors 与 migration list 未运行，不记录 P2-L PASS。

## Offline correction

- 插入循环不再用 `v_inserted=true/false` 配合 `EXIT WHEN`。现在 invitation INSERT 成功后立即 `EXIT insert_invitation`；只有 `unique_violation` handler 才继续读取冲突行并执行原有 idempotency/active/expiry 解析。审计段因此有显式可达控制流。
- 删除 `v_existing_updated_at` 变量，并从三个冲突查询的 SELECT/INTO projection 同步移除 `i.updated_at`；业务条件从未依赖该字段。
- 静态门新增：禁止保留两个 dead states；要求 invitation INSERT 成功显式退出、unique conflict handler 后才读取冲突行。
- 新候选 hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`c8d9527f541d39c1131cd4ebf029348ccc6128fb`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`；structure=`2ced32c0a8a24d6da93f6e921e94bc02fcda521c`。
- 修复后 `P2L_MIGRATION_STRUCTURE_PASS`、Node syntax 与 `git diff --check` 通过；本工作包不重跑 runtime。

## Cleanup and boundary

- strict lint FAIL 后立即 exact stop/no-backup，返回 `0`；目标 containers、volumes、network 与 `55320–55329` listeners 均为空，未使用 `--all`。
- 精确临时 start log 已删除；未保存 local key、DB URL、token、cookie、OTP、DB password、provider response 或真实 PII。
- 下一 bounded Gate 从空资源复验 `87/87` 与 strict zero-warning lint，再运行 advisors/migration list。P2-L 仍 OPEN，P3–P7、hosted/Production、main push/deploy 未打开。
