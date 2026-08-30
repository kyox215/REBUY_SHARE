# P2-L 本地 Schema 与 RLS 纵切 Gate

文档状态：**待 Owner 决定 / CLOSED**
记录日期：2026-08-30（Europe/Rome）
适用分支：`codex/rebuy-v1-local-complete`；本文件只准备推荐路线和 Gate，不预写授权。

## 1. 推荐路线例外与当前冻结

在 E2a 已 REVIEW GO、E2b provider invite 与 E3 Google/E4 Apple/E5 hosted 均保持冻结的前提下，建议由 Owner 单独决定是否允许一个 **P2-L synthetic-only local slice**。该例外只打开本地 schema/RLS/组织成员权限纵切，不打开完整 P2，不改变 G2-A1 整体状态，也不替 E2b provider invite Gate。

普通身份通过现有 E2a local email OTP 创建。真正的组织/员工邀请不依赖 admin key 或 provider invite，而是在 P2-L 内使用 RLS 保护的 membership invitation record 与接受事务实现，先证明目标邮箱控制权，再在服务端事务中完成 membership 关联和最小审计。该路线不使用 `service_role`，也不把客户端提交的角色当作可信输入。

当前状态仍为 **待 Owner 决定 / CLOSED**：本条是 docs-only Gate 准备，未批准 schema、migration、seed、数据库写入或 P2-L runtime。

## 2. Exact scope

### 2.1 允许范围

- 唯一代码范围：`codex/rebuy-v1-local-complete` 分支与其 `.worktrees/rebuy-v1-local-complete-exec` worktree。
- 唯一运行范围：本地 Supabase，loopback 端口 `55320–55329`；不得连接 hosted/Production，不得触碰其他项目容器、volume、network 或 `54321–54324`。
- 数据范围：合成身份、合成组织/店铺/成员关系、`@rebuy.test` 成功路径；不使用真实邮箱、账号、客户/员工资料或其他 PII。
- 允许的实现产物：数据库 migrations、合成 seed、pgTAP 或项目相关数据库测试、prototype server auth/DTO、脱敏 docs/evidence。所有执行仍需新的 action-time Owner Gate。

### 2.2 首批表

首批只覆盖以下业务表，依赖关系和权限必须逐表明确：

`profiles`、`organizations`、`stores`、`memberships`、`membership_store_scopes`、`role_definitions`、`permissions`、`role_permissions`、`audit_logs`。

`wholesale applications/qualifications` 后置到下一批；`security_events` 再后置。不得借 P2-L 首批顺手创建其他业务表、Storage 对象、支付对象或生产迁移。

### 2.3 组织成员邀请路线

P2-L 的 Rebuy membership invite 是业务记录，不是 Supabase provider invite：

1. 普通用户用现有 local OTP 建立已验证 identity/session。
2. 服务端创建 RLS 保护的 membership invitation record，绑定组织、目标邮箱控制权、过期时间、一次性消费状态和最小审计字段；客户端不能提交可信 role、organization owner、scope 或审批结果。
3. 接受者用 OTP 证明目标邮箱控制权，服务端每入口重新认证并在事务中校验邀请、组织、并发、过期、一次性消费和权限，再创建 membership 与允许的 store scope。
4. provider/admin invite、`inviteUserByEmail`、service_role 和 admin key 不参与该业务邀请路线。

## 3. 必须满足的安全合同

- 所有首批业务表启用 RLS，并配置显式、最小化 `GRANT`；默认无隐式公开可达性。表级 grants 与行级 RLS 分开验证。
- empty scope 默认 deny；用户没有明确 membership/store scope 时，不得读取、写入、更新或删除组织/店铺业务行。
- `memberships`、`membership_store_scopes` 与 invitation/关联路径的组织、店铺、用户、状态和过期字段建立所需 FK/查询索引；索引不得被写成越权条件。
- 不使用 `service_role`、admin key 或客户端可信角色作为授权捷径；public/publishable key 只用于受 RLS 保护的普通请求。
- 不创建 `auth.users` trigger。采用受控的 lazy `ensure_my_profile` 路径：每次服务端入口重新认证当前 user，并在最小权限下确保对应 profile，不把 trigger side effect 当作授权证明。
- 每个 Server Action/Route Handler 入口都重新认证并执行授权校验，不能依赖页面可见性、客户端状态、缓存或上游调用者已验证的 role。
- 客户端不得提交或决定可信 `role`、permission、organization owner、membership status、store scope、audit actor 或邀请接受结果；服务端从已认证身份和数据库关系推导。
- `audit_logs` 只记录最小、脱敏、不可伪造的业务事件摘要；不得写入 token、OTP、cookie、secret、真实 PII 或完整请求原文。

## 4. Owner Gate 字段与精确批准语句

Owner 决定前必须确认：exact branch/HEAD、唯一 worktree、local project id、`55320–55329` loopback 隔离、synthetic identity 生命周期、migration/seed 回退、RLS/grant 审查人、数据库测试范围、server auth/DTO 入口、cleanup 负责人、证据位置和停止联系人。当前所有字段均属于待决定项。

### Owner 明确批准语句（模板；当前未批准）

> 批准 P2-L 本地纵切：允许在 codex/rebuy-v1-local-complete 中使用本地 Supabase 与合成身份实施 schema/RLS/组织成员权限和 Rebuy membership invite；E2b、E3-E5、hosted、真实数据、推送部署继续冻结。

上面是要求 Owner 明确作出的精确语句，不是本文件代替 Owner 作出的批准；在该语句及其他 Gate 字段实际确认前，P2-L 保持 CLOSED。

## 5. 最小验证与证据

获批后才可执行以下最小验证，且必须使用本地合成数据：

- migration/seed/pgTAP 或项目数据库测试能从空库重复建立首批表，且不创建后置表、`auth.users` trigger 或隐含管理员路径。
- 每张首批表验证显式 grants、RLS policy、authenticated/anonymous/跨组织/跨店铺/empty-scope 的允许与拒绝矩阵；拒绝结果只记录有限分类。
- 验证普通 OTP identity 的 lazy profile、组织创建边界、membership、store scope、role/permission 解析和最小 `audit_logs`；任何客户端伪造 role/scope 都必须被拒绝。
- 验证 membership invitation record 的创建、目标邮箱控制权、过期、重复接受、并发接受、撤销/拒绝和事务原子性；证据只记录状态和阶段，不记录 invite token 或邮箱原值。
- Server Action/Route 每入口验证 re-auth、组织/membership/scope 授权、RLS 与 DTO 边界；不能以浏览器隐藏按钮、缓存或页面状态代替服务端检查。
- 只核对本批 exact local project 的 containers/volumes/network/listeners cleanup；保留脱敏 schema/RLS 结果，不保存 secret、service_role、DB password、token、cookie 或真实 PII。

P2-L 通过判据是：Owner 明确批准、scope 未越界、首批 RLS/grants/deny 矩阵通过、membership invitation 接受事务通过、cleanup 通过且独立审查完成。即使这些条件全部满足，也只代表 P2-L local slice，不代表完整 P2 Exit 或 G2-A1 整体通过。

## 6. STOP 与回退

出现以下任一情况，立即停止并保持 P2-L CLOSED：

- 需要 service_role、admin key、hosted/Production、custom SMTP、真实 PII、真实邮件、Storage、支付、push、PR/merge、Vercel 或其他外部写入。
- RLS/grant、FK、scope、事务、re-auth 或 DTO 边界无法证明；anonymous、empty scope、跨组织或跨店铺路径意外可达。
- 客户端可提交可信角色/权限/组织归属，Server Action/Route 依赖旧 session 或页面状态，或 `auth.users` trigger 被作为必要授权链路。
- 目标资源无法精确归属本批，端口/网络与其他项目冲突，出现未授权镜像/费用，或 cleanup 不完整。
- 任何 secret、service_role、DB password、OTP、token、cookie、真实邮箱/账号/PII 或 raw database/provider output 进入输出、日志、仓库、截图或 evidence。

回退只允许停止本地执行、回滚本批新建的 local migrations/seed/data（在获批的可逆窗口内）、清理精确 project 资源并追加脱敏记录；不得改写历史 Gate、不得用 provider invite 或 fake replay 替代 membership invite 证据。任何未完成项都记录为未验证，等待新的 Owner 决定。

## 7. 明确非目标

E2b provider invite/admin key、Google、Apple、hosted Auth、custom SMTP、真实 PII、Storage、支付、push、PR、merge、Vercel、Staging、Production、完整 P2 Exit、G2-A1 整体通过、`wholesale applications/qualifications`、`security_events` 以及任何超出首批九表的业务 schema 均不在本 Gate 打开范围内。
