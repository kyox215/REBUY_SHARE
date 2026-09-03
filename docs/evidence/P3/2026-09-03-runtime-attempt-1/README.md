# P3 runtime attempt #1 — STOP

日期：2026-09-03（Europe/Rome）
范围：`synthetic-only local`；project=`rebuy-g2-a1-e2a-local-email-otp-exec`；loopback `55320–55329`

## 结果

- 空资源入口通过；唯一 `supabase start --yes` exit `0`，P2-L 与 P3 migration/seed 可在空库应用。
- pinned Node `22.12.0` AMR preflight 完整 `P2L_PREFLIGHT_PASS`。
- fresh `supabase db reset --local` exit `0`。
- P2-L 两份 pgTAP 回归均 PASS（合计 `113/113`）。
- P3 schema/security 为 `18` 项中 `2` 项失败；原因是测试对 `proconfig` 的空 `search_path` catalog 表示写错，属于 test defect。
- P3 workflow 为 `51` 项中 `31` 项失败；首个实质失败是同一申请幂等重试触发 open-application unique constraint。后续大部分失败是 application id 为空造成的级联，不逐项视为独立产品缺陷。
- 根因：save implementation 使用 `SELECT ... FOR UPDATE` 查现有申请；PostgreSQL 同时应用 UPDATE policy，而函数在知道 application id 前无法设置 exact-id update context，因此现有行被 FORCE RLS 隐藏并误走 INSERT。
- 独立缺陷：草稿直接撤回被 `submitted_at` 约束错误拒绝。
- 同一运行包未运行 concurrency、db lint、advisors、migration list、app build 或再次数据库测试。

## 离线修复候选

- 申请人 advisory transaction lock 已串行化 save；现有申请查询移除不必要的 `FOR UPDATE`，仍由 advisory lock 防止并发重复。
- `withdrawn` 允许保留 draft 的空 `submitted_at` 或已提交申请的既有时间。
- 补充 suspension 更新所需的 exact organization/store/scope SELECT policies 和对应最小列权限；不扩大 authenticated/service_role 权限。
- pgTAP `proconfig` 断言改为 PostgreSQL 实际的 `search_path=""` 表示。

修复后候选 SHA-256：

```text
roles.sql 96648642ac331df0fe801dadee5e1252cc80ec1ce792339d279d2624a59aea1a
p3 migration 3e5af54de51c938a434acc465f8099e490621370deede2c3fbd7e6dcc81b8f66
seed.sql d7d6468882d01760385cd4ad3cd0122dabdfca16aebd492fb4043a3decb16297
p3 schema test 83d46e3f63e584cbfe7ad73c90b9bd0f5af9d867d3babca5e68471d21e9411f0
p3 workflow test 26aa7d9999b83e4523b03155a5404f8c3298f2dc618f03084b43bda31a77f2dc
p3 structure verifier 0fcb5bc021b8d10ef4387d372d349a86fa4461300641f73ddd17279e1894994c
package.json e8425ecc78fc4300037f38f9fb0f2c5df706b484bee50be86f48344d7008ac35
```

## Cleanup

- `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` exit `0`。
- 精确 start/reset raw 临时日志已删除。
- 目标 containers、volumes、network 与 `55320–55329` listeners 均为空。
- 未停止共享 Colima，未使用 `--all`，未连接 hosted/Production，未使用真实 PII。

当前 P3 保持 `执行中 / runtime STOP`；本证据不构成 P3、P4 或部署通过。
