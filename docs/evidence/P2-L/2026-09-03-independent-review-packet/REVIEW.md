# P2-L independent review verdict

日期：2026-09-03（Europe/Rome）

Reviewer：独立只读 Sol / max 复审

结论：**REVIEW NO-GO**

计数：`P0=0 / P1=2 / P2=2`

## Reviewed candidate

- roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`
- migration=`11a7ffc7daf34833a81f7eec78138e5055b876f2`
- seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`
- schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`
- invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`
- structure verifier=`7a2e43343c7bba4e08a06d56c989f15e66430785`

## Findings

### P1-01 — `service_role` effective ACL 未显式关闭和验证

Supabase 默认权限可能让 `service_role` 保留显式 DML；同时 `service_role` 绕过 RLS。候选只证明未主动 grant，不足以证明 effective privilege 为零。最小关闭条件：对 private schema、首批十表、request helpers、private implementations 和 public wrappers 显式 revoke `service_role`，并由 pgTAP 用 effective privilege 断言、静态门用源码结构断言双重锁定。

### P1-02 — `87/87` 未覆盖关键 accept 与真实并发路径

缺口包括：accept 的 recent-OTP/AMR/email 负向矩阵；邀请创建后 creator membership/permission/scope、candidate role/version/assignability、organization/store 状态失效的重新验证；store accept 成功与 exactly-one-store scope；同一邀请并发接受，以及同一 target/organization 的不同邀请并发冲突。最小关闭条件：补齐 pgTAP，并使用两个独立数据库连接证明幂等、串行化、唯一 membership/scope/audit 和有限外部错误。

### P2-01 — public accept RPC 泄露内部授权状态码

`creator_membership_not_active`、`creator_role_not_active`、`creator_permission_revoked`、`creator_scope_not_active`、`store_not_available` 等内部状态可向 invitation target 暴露。最小关闭条件：public accept 路径统一为有限 `invitation_not_available`，内部细节不得进入不可信调用者响应。

### P2-02 — attempt #16 缺少可复核的脱敏原始工件与哈希

attempt #16 主要是叙述，没有保存脱敏 TAP、lint、advisor、migration list、cleanup 输出和对应 SHA-256，独立复现性不足。下一次 PASS 必须保存有限输出、版本、精确命令、cleanup 与工件 hash。该项单独不构成 P1 阻断，但必须在复审收口前完成。

## Gate result

P2-L Exit 被两项 P1 阻断。修复候选必须完成离线门、一次 fresh empty database 的完整 runtime Gate、脱敏工件和哈希，然后由独立 reviewer 对新的 exact commit/hashes 定向复审；复审 GO 前不得打开 P3–P7、push main 或部署。
