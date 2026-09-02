# P2-L schema runtime attempt #7

日期：2026-09-03（Europe/Rome）
结果：**STOP / FAIL；schema pgTAP 44/49，通过 fixture 入口后发现权限与断言问题**

## Entry and actual

- 从 attempt #6 exact cleanup 后的空目标资源进入；结构门、`git diff --check`、容器与 `55320–55329` 端口入口通过。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`af8ac6b1c113201c9679b34b5336c767f1de2c58`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`6aacf9f84d0f1556411a7fb852010f57312e8a8e`；invitation pgTAP=`c2042230ad9867f08fe2ccd5062d111fc62fc368`；structure=`3fbbd16d9e65c486787ec205b246ac0993662a5d`。
- `supabase start --yes` 再次通过 globals、migration、owner handoff 与 seed。
- schema pgTAP 执行 49 条、44 条通过；失败为 executor 对 `auth` schema 无 USAGE，以及四条空 search-path catalog 断言。
- invitation pgTAP 越过 seed natural-key collision，但首次 claims setup 在 `pg_catalog.extract(...)` 返回语法错误，未进入业务流程矩阵。
- 按独立包一次实际序列停止；未运行 lint/advisors/migration list。

## Diagnosis and least-privilege decision

- migration 日志已经给出 `auth` schema/function grant/revoke 的 `no privileges` warnings；Supabase 平台拥有 `auth` schema，普通 migration runner 不能把其权限转授给隔离 executor。接管 auth owner、增加宽角色 membership 或使用 privileged key 均被拒绝。
- Supabase 官方 `auth.jwt()`/`auth.uid()` 实现本身只包装由 PostgREST 在已验签请求上设置的 `request.jwt.claim`/`request.jwt.claims` GUC。候选改为 private schema 中两个项目自有 `SECURITY INVOKER` helper，空 `search_path`、owner=`postgres`，读取相同 GUC；只给 `authenticated` 与 executor EXECUTE，`PUBLIC`/`anon` 无权限。executor 不再需要 `auth` schema 或平台函数权限。
- `SET search_path = ''` 在 `pg_proc.proconfig` 的规范值为 `search_path=""`；四条失败属于测试断言编码错误，不是函数缺少固定 search path。
- invitation test 中所有 schema-qualified 特殊 `pg_catalog.extract` 已改为合法 `EXTRACT`，结构门扩展为同时检查 migration 与两份 pgTAP。

## Cleanup and offline candidate

- exact stop/no-backup exit `0`；目标 containers、volumes、network 与 listeners 均为空。
- 新候选 hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`8d92bfd7f545aab6c04b76e3b1de3f4081b2172c`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`464237cdb9b63397564b2043282662810f5fce7b`；invitation pgTAP=`fc26c426b486a6f834d29be252604b2b10f5fa6c`；structure=`6eef878d2cd524e6f61dedb6d4a87183d0957946`。
- 静态门、Node syntax 与 `git diff --check` 通过；本包不重启 runtime。下一独立包须从空资源复验 helper grants、最终 owner/membership catalog、完整 invitation 正负矩阵与之后的 lint/advisors。
