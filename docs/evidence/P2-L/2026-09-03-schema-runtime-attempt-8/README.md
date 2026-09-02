# P2-L schema runtime attempt #8

日期：2026-09-03（Europe/Rome）
结果：**STOP / FAIL；schema pgTAP 50/53，invitation fixture temp-table privilege 待修**

## Entry and actual

- 从 attempt #7 cleanup 后的空目标资源进入；结构门、diff check、目标 containers/volumes/network/listeners 入口通过。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`8d92bfd7f545aab6c04b76e3b1de3f4081b2172c`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`464237cdb9b63397564b2043282662810f5fce7b`；invitation pgTAP=`fc26c426b486a6f834d29be252604b2b10f5fa6c`；structure=`6eef878d2cd524e6f61dedb6d4a87183d0957946`。
- `supabase start --yes` 通过 migration/owner handoff/seed。此前 `auth` schema warnings 已消失；但 owner handoff 后由 postgres 尝试修改 executor-owned private implementation ACL 产生 `no privileges` warnings。
- schema pgTAP 执行 53 条、50 条通过。两条失败因为 `has_function_privilege` 计入平台 `PUBLIC EXECUTE`，即使 executor 无 `auth` schema USAGE 且无 direct grant；第三条仍按旧 `auth.uid` 文本匹配 profile policy。
- invitation pgTAP 越过全部特殊表达式解析，在第一次 `SET LOCAL ROLE authenticated` 后对 postgres-owned `pg_temp.p2l_create_result` 执行 TRUNCATE 时被拒绝，业务 RPC 尚未运行。
- lint/advisors/migration list 未运行；P2-L 未 PASS。

## Offline corrections

- auth helper 断言改查 `pg_proc.proacl` 展开后的 executor direct grant，不再把平台 PUBLIC default 当作 direct privilege；同时继续证明 executor 无 auth schema USAGE。
- profile policy 文本断言改为要求 `rebuy_request_uid` 与 `rebuy_request_jwt`。
- 两张 pgTAP temp result tables 在第一次切换 `authenticated` 前显式授予该测试角色所需表权限。
- 更重要的实现修正：private implementations 的 `PUBLIC/anon/authenticated/executor` revoke 与 authenticated execute grant 移到 owner handoff 前，由当时的 owner postgres 完成；ACL 随 owner transfer 保留。静态门禁止 handoff 后再由 migration runner 修改这两个 executor-owned functions，并新增 anon direct execute deny。

## Cleanup and candidate

- exact stop/no-backup exit `0`；目标 containers、volumes、network 与 `55320–55329` listeners 均为空。
- 新候选 hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`4d4cab7415312fe361a95a3afb873ebcd2dc7e51`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`；invitation pgTAP=`889c21e63ec1a3986e7ba53ee783c86af36a010f`；structure=`baa32ffec5d016093a66ce801f45ded09c7040bb`。
- 结构门、Node syntax、`git diff --check` 通过；本包不重跑 runtime。
