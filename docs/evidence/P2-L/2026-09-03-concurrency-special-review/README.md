# P2-L concurrency harness independent special review

日期：2026-09-03（Europe/Rome）

结果：**SPECIAL REVIEW NO-GO / HARNESS-ONLY FIX REQUIRED**

Runtime actual count：`0`

## Reviewed boundary

- 审查对象是 attempt #19 在 `stable_retry` 区间失败时的并发 harness，旧文件 SHA-256=`2792dd7a1e5b580b0b33da133689e1e8f26b28e2bff8125457390710a4052f82`。
- 只读审查未启动 Supabase/Docker、未运行 migration/seed/pgTAP、未连接 hosted/Production，也未读取或保存 key、OTP、token、cookie、邮箱或其他 PII。
- 审查结论不把 attempt #19 改写为 PASS，也不打开 P3–P7、main push 或部署。

## Independent finding

- `membership_invitations` 同时引用 creator membership 和 accepted membership；接受后 membership 又通过 `source_invitation_id` 回指 invitation。旧 cleanup 在 invitations 之前删除 memberships，形成确定性的外键循环失败。
- 仅交换两条 DELETE 的顺序仍不能解除循环；必须先把本夹具 membership 的 `source_invitation_id` 置空。
- 旧 cleanup 没有事务，且失败路径使用 `.catch(() => undefined)` 吞掉 cleanup 结果；全局 `stage` 也未切到 cleanup，因此有限输出仍标成宽泛 `stable_retry`。
- `profiles.user_id` 对 `auth.users(id)` 已为 `ON DELETE CASCADE`；显式 profile DELETE 不是根因，也不应成为清理依赖。
- 以上源码依赖关系对“当前失败来自 harness cleanup、不是 invitation migration 缺陷”的置信度高于 95%；但旧 stage 范围过宽，不能把历史运行伪写为某一精确断言已通过。

## Required closeout implemented offline

- cleanup 使用单一 `BEGIN/COMMIT`；顺序固定为 audit → scopes → 清空 exact fixture membership 的 `source_invitation_id` → invitations → memberships → stores → organization → `auth.users`，profiles 依赖既有 cascade。
- 正常和失败路径都验证 audit/scopes/memberships/invitations/stores/organization/profiles/users 精确为零；失败输出保留原 stage 并只报告固定 `cleanup_pass|cleanup_fail`，不输出数据或 stderr 原文。
- stable retry lookup 必须是 exactly one invitation/membership UUID pair；accepted invitation 必须精确属于 A/B，成功 retry 的 signal/exit 与 membership/org/store/scope 全字段必须相等；未接受邀请必须为无 signal 的非零退出、只暴露 `invitation_not_available`，并排除内部状态码。
- 静态 verifier 锁定事务、解除回链、依赖顺序、无 `TRUNCATE/CASCADE`、无显式 profile delete、无 silent cleanup catch、精确 stage、完整结果断言、零残留验证及 auth profile cascade 合同。

## Offline candidate verification

- 修复后 concurrency harness SHA-256=`7938ce267e1d0febfad746bb7dcc8b575321e04719595b9b95c1e9a7ff294feb`。
- 修复后 migration structure verifier SHA-256=`8f8df05ce02c3173d186aa116fda35a5252295e8129e3ccc7c9ad40b31885b79`。
- invitation migration 保持 SHA-256=`13af3f60d2e665efaf3ae228cad2ffdee04d55c0a3969f55bbe65e4599ce28ba`，没有因本次 harness failure 修改。
- Node `22.12.0` 下两个脚本 `node --check`、`P2L_MIGRATION_STRUCTURE_PASS`、定向 ESLint 与 `git diff --check` 均通过。

## Gate decision

专项只读审查已完成，三次失败后的诊断暂停条件解除。当前只允许从空资源为上述 exact candidate 新开一次 bounded runtime packet；如失败立即停止并精确清理，不在同包重试。只有完整 runtime PASS、脱敏工件/哈希和 exact candidate 独立最终复审 GO 后，P2-L 才能关闭。
