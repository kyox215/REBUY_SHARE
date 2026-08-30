# P2-L 本地 Schema 与 RLS 纵切 Gate

文档状态：**待 Owner 决定 / CLOSED**
记录日期：2026-08-30（Europe/Rome）
适用分支：`codex/rebuy-v1-local-complete`；本文件只准备推荐路线和 Gate，不预写授权。

## 1. 推荐路线例外与当前冻结

在 E2a 已 REVIEW GO、E2b provider invite 与 E3 Google/E4 Apple/E5 hosted 均保持冻结的前提下，建议由 Owner 单独决定是否允许一个 **P2-L synthetic-only local slice**。该例外只打开本地 schema/RLS/组织成员权限纵切，不打开完整 P2，不改变 G2-A1 整体状态，也不替 E2b provider invite Gate。

普通身份通过现有 E2a local email OTP 创建。真正的组织/员工邀请不依赖 admin key 或 provider invite，而是在 P2-L 内使用 RLS 保护的 membership invitation record 与接受事务实现，先证明目标邮箱控制权，再在服务端事务中完成 membership 关联和最小审计。该路线不使用 `service_role`，也不把客户端提交的角色当作可信输入。

当前状态仍为 **待 Owner 决定 / CLOSED**：下述首批十表与邀请安全路线都只是推荐 scope，本条仅作 docs-only Gate 准备，未批准 schema、migration、seed、数据库写入或 P2-L runtime。

## 2. Exact scope

### 2.1 允许范围

- 唯一代码范围：`codex/rebuy-v1-local-complete` 分支与其 `.worktrees/rebuy-v1-local-complete-exec` worktree。
- 唯一运行范围：本地 Supabase，loopback 端口 `55320–55329`；不得连接 hosted/Production，不得触碰其他项目容器、volume、network 或 `54321–54324`。
- 数据范围：合成身份、合成组织/店铺/成员关系、`@rebuy.test` 成功路径；不使用真实邮箱、账号、客户/员工资料或其他 PII。
- 允许的实现产物：数据库 migrations、合成 seed、pgTAP 或项目相关数据库测试、prototype server auth/DTO、脱敏 docs/evidence。所有执行仍需新的 action-time Owner Gate。

### 2.2 首批表

推荐的首批 scope 只覆盖以下十张业务表，依赖关系和权限必须逐表明确；该 scope 仍待 Owner 精确批准，不是当前授权：

`profiles`、`organizations`、`stores`、`memberships`、`membership_invitations`、`membership_store_scopes`、`role_definitions`、`permissions`、`role_permissions`、`audit_logs`。

`wholesale applications/qualifications` 后置到下一批；`security_events` 再后置。不得借 P2-L 首批顺手创建其他业务表、Storage 对象、支付对象或生产迁移。

### 2.3 组织成员邀请路线

P2-L 的 Rebuy membership invite 是业务记录，不是 Supabase provider invite：

1. 普通用户用现有 local OTP 建立已验证 identity/session。
2. 推荐的首批邀请只允许组织级，或绑定 exactly one store 的单店级；不支持 multi-store JSONB/数组。未来多店邀请必须使用独立关联表并另开新 Gate，不得扩写首批 `membership_invitations` 字段来绕过 scope。
3. 创建和接受邀请推荐采用固定 **10 分钟** recent-OTP window，以数据库当前时间为准，并只容许 Auth claim 时间最多领先数据库 **60 秒**。每个 create/accept RPC 链路都从已经 Data API 验签的 `auth.jwt()` 读取最前面的 `amr[0]`，要求其 `method='otp'` 且数值 `timestamp` 位于该窗口；同时要求 `auth.uid()` 非空、`is_anonymous=false`，且签名 JWT 中的规范化 email 属于 `@rebuy.test`。
4. `amr[0].timestamp` 是 Supabase Auth 签发 JWT 中的签名 claim；`user_metadata`、客户端时间戳、客户端布尔值和 JWT `iat` 均不得作为 recent-OTP 证据。该合同只是待 Owner 批准、仅限 synthetic-only local 的 AAL1 例外，不宣称 MFA/AAL2，也不得外推到 hosted/Production。
5. `membership_invitations` 必须绑定可信 `organization_id`、`role_definition_id`、`role_version`、`scope_type`、可选的 exactly-one `store_id`、规范化 synthetic target email、creator membership、expiry/status，以及接受后的 user/membership 结果。
6. 创建时 inviter 必须仍是当前 active membership 且拥有 `member.invite`；候选 role/store 只作为不可信输入，RPC 必须重新解析并验证角色可分配、role active/version 及 organization/store 关系。接受时先锁定 invitation 行，再重新验证 creator 仍有 `member.invite`、role active/version/assignability、签名 JWT 目标 email、scope、过期、撤销与消费状态。
7. 数据库公开入口 precisely two：`public.create_membership_invitation` 与 `public.accept_membership_invitation`，均为 `SECURITY INVOKER` wrapper；真正实现分别位于未 exposed 的 private schema，使用 `private.create_membership_invitation_impl` 与 `private.accept_membership_invitation_impl` `SECURITY DEFINER`。无论攻击者尝试直接调用 wrapper 或 private impl，函数都必须重做完整 identity、recent OTP、permission、role、scope 与状态校验。
8. `rebuy_invite_executor` 只能通过最小列权限与 RLS 工作：每张 touched table 至少配置一条仅适用于该 executor、按当前签名 JWT/invitation/permission/scope 事实收窄的 `PERMISSIVE` allow policy；`RESTRICTIVE` policies 只能作为额外 AND guards。禁止任何适用于 executor 的 blanket 或 `PUBLIC` permissive policy，且 executor 与其他 roles 的双向 membership 必须为空。
9. provider/admin invite、`inviteUserByEmail`、service_role 和 admin key 不参与该业务邀请路线。

Owner Gate 执行后、任何 schema migration 之前，必须先对 pinned local GoTrue 做真实 local email OTP preflight：验证 `amr[0]` 的顺序、`method` 与 `timestamp`，并验证 refresh 不会把原 OTP timestamp 重置为“现在”。claim 缺失、格式不符或 refresh 重置即 STOP，不进入 schema migration；当前 docs-only Gate 不声称该 preflight 已实测。若 Owner 不批准上述 AAL1 local exception 或 preflight 失败，P2-L invite 继续 defer。

## 3. 必须满足的安全合同

- 所有首批业务表启用 RLS，并配置显式、最小化 `GRANT`；被 invitation create/accept 链路触及的 tables 必须同时 `ENABLE ROW LEVEL SECURITY` 与 `FORCE ROW LEVEL SECURITY`。表级 grants 与行级 RLS 分开验证。
- empty scope 默认 deny；用户没有明确 membership/store scope 时，不得读取、写入、更新或删除组织/店铺业务行。
- `memberships`、`membership_invitations`、`membership_store_scopes` 与关联路径的组织、店铺、用户、角色版本、状态和过期字段建立所需 FK/约束/查询索引；索引不得被写成越权条件。
- 不使用 `service_role`、admin key 或客户端可信角色作为授权捷径；public/publishable key 只用于受 RLS 保护的普通请求。
- 首批 invitation scope 只能是组织级或 exactly one store 的单店级；multi-store JSONB/数组一律拒绝，未来多店邀请必须使用独立关联表并经新 Gate。
- 创建和接受邀请均在数据库内校验经过 Data API 验签的 `auth.jwt()`：最前面的 `amr[0]` 必须是 10 分钟内的 `otp`，数据库时间为准且未来偏差不得超过 60 秒；`auth.uid()` 非空、`is_anonymous=false`、签名 email 为规范化 `@rebuy.test`。`user_metadata`、客户端时间/布尔值与 JWT `iat` 不得参与该判断。
- `private.*_impl` 的 owner 固定为专用 `rebuy_invite_executor`；该角色必须是 `NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS`，不得拥有 schema 或 table，只持有 touched tables 的最小列权限。definer 不得绕过 RLS 或业务授权。
- `rebuy_invite_executor` 不得属于任何 role，也不得授予给任何 login、`anon`、`authenticated`、`authenticator`、`service_role` 或其他角色；`pg_auth_members` 以 executor 作为 member 或 granted role 的双向查询结果必须均为空。
- 每张 touched table 至少有一条仅 `TO rebuy_invite_executor`、覆盖实现所需精确 command 且按当前签名 JWT/invitation/permission/scope 事实收窄的 `PERMISSIVE` allow policy；`RESTRICTIVE` policies 只能作为额外 AND guards，不能替代 permissive allow。禁止任何适用于 executor 的 blanket allow 或 `PUBLIC` permissive policy。
- `private.*_impl` 固定 `search_path=''`，所有对象使用全限定名。private schema 不加入 Data API exposed schemas；`anon`/`authenticated` 对 invitation/membership/scope/audit tables 均无直接 DML 权限。
- 同一 migration 中，函数创建或替换后必须先 revoke `PUBLIC`/`anon` 的 `EXECUTE`，再只 grant `authenticated` 对两个 `public` wrappers 的 `EXECUTE`，以及 wrapper 调用 private impl 所需的最小 private schema/function 权限；不得授予 table 直接 DML，也不得使用 `service_role`/admin key。直接调用 wrapper/private impl 时仍执行全部身份、OTP、权限、role、scope 与状态检查。
- invitation 创建必须重新解析 inviter active membership、`member.invite`、可分配 role、role active/version 与 org/store 关系；接受事务必须行锁 invitation，并再次验证 creator 权限、role active/version/assignability、签名目标 email、scope、expiry/revocation/consumption。
- organization scope 必须原子写入显式 `membership_store_scopes` 行：`scope_type='organization'` 且 `store_id IS NULL`；单店 scope 必须写入 `scope_type='store'` 且非空 `store_id` 属于同一 organization。零 scope 行始终 deny，不得把 absence 解释为 organization scope。
- 接受幂等性绑定 invitation id、`accepted_user_id` 与 `accepted_membership_id`：同一接受者重试返回同一结果，不重复 membership/scope/audit；不同身份重试必须拒绝。multi-store invite 继续 defer。
- 不创建 `auth.users` trigger。采用受控的 lazy `ensure_my_profile` 路径：每次服务端入口重新认证当前 user，并在最小权限下确保对应 profile，不把 trigger side effect 当作授权证明。
- 每个 Server Action/Route Handler 入口都重新认证并执行授权校验，不能依赖页面可见性、客户端状态、缓存或上游调用者已验证的 role。
- 客户端不得提交或决定可信 `role`、permission、organization owner、membership status、store scope、audit actor 或邀请接受结果；服务端从已认证身份和数据库关系推导。
- `audit_logs` 只记录最小、脱敏、不可伪造的业务事件摘要；不得写入 token、OTP、cookie、secret、真实 PII 或完整请求原文。

## 4. Owner Gate 字段与精确批准语句

Owner 决定前必须确认：exact branch/HEAD、唯一 worktree、local project id、pinned local GoTrue ref、`55320–55329` loopback 隔离、首批十表、synthetic identity 生命周期、10 分钟 AMR window/+60 秒偏差、AAL1 local exception、组织级/exactly one store 邀请边界、两个 public invoker wrappers/private definer impl、`rebuy_invite_executor` 属性/最小权限/双向 role-membership 为空、touched tables FORCE RLS、executor-only narrow `PERMISSIVE` allow + `RESTRICTIVE` AND guards 且无 blanket/`PUBLIC` permissive policy、role/version/scope/idempotency、migration/seed 回退、RLS/grant 审查人、数据库测试范围、server auth/DTO 入口、cleanup 负责人、证据位置和停止联系人。当前所有字段均属于待决定项。

### Owner 明确批准语句（模板；当前未批准）

> 批准 P2-L 本地纵切：允许在 codex/rebuy-v1-local-complete 中使用本地 Supabase 与合成身份实施首批十表（profiles、organizations、stores、memberships、membership_invitations、membership_store_scopes、role_definitions、permissions、role_permissions、audit_logs）的 schema/RLS/grants；Rebuy membership invite 首批仅允许组织级或 exactly one store 的单店级，不允许 multi-store JSONB/数组；批准仅限 synthetic-only local 的 AAL1 例外，create/accept 采用数据库时间固定 10 分钟 recent-OTP window 和最多 +60 秒偏差，从 Data API 验签的 auth.jwt() 读取最前 amr[0] 并要求 method=otp、auth.uid() 非空、is_anonymous=false、签名 email 为规范化 @rebuy.test，禁止 user_metadata、客户端时间/布尔值与 JWT iat 充当证明，且不宣称 MFA/AAL2、不外推 hosted/Production；批准 precisely two 个 public SECURITY INVOKER wrappers（public.create_membership_invitation、public.accept_membership_invitation）调用未 exposed private schema 中 search_path 为空且对象全限定的 private.*_impl SECURITY DEFINER，由不拥有 schema/table 的专用 rebuy_invite_executor（NOLOGIN/NOSUPERUSER/NOCREATEDB/NOCREATEROLE/NOINHERIT/NOREPLICATION/NOBYPASSRLS）以最小列权限执行，该 executor 不属于任何 role、也不授予任何 login/anon/authenticated/authenticator/service_role 或其他角色且 pg_auth_members 双向为空，每张 touched table 至少有一条仅适用于 executor、按当前签名 JWT/invitation/permission/scope 事实收窄的 PERMISSIVE allow policy，RESTRICTIVE policies 仅作额外 AND guards，禁止任何适用于 executor 的 blanket 或 PUBLIC permissive policy，touched tables ENABLE+FORCE RLS，同一 migration 先 revoke PUBLIC/anon EXECUTE 再只 grant authenticated 对 wrappers 及调用 private impl 所需最小 schema/function 权限，anon/authenticated 无 invitation/membership/scope/audit 直接 DML，任一直接 wrapper/private 调用均重做全部校验且不得使用 service_role/admin key；批准 invitation 绑定 organization_id、role_definition_id、role_version、scope_type、可选 exactly-one store_id、规范化 target email、creator membership、expiry/status/accepted result，create/accept 重新验证 inviter/creator active member.invite、role active/version/assignability、同组织 store、签名目标 email、行锁、过期/撤销/消费，organization 与 store scope 均写显式 membership_store_scopes 行且零 scope deny，并以 invitation id + accepted_user_id/accepted_membership_id 保证同身份重试不重复 membership/scope/audit、不同身份拒绝；任何 migration 前先对 pinned local GoTrue 真实 local email OTP 验证 amr[0] 且 refresh 不重置原 OTP timestamp，失败即 STOP 并 defer P2-L invite；E2b、E3-E5、hosted、真实数据、推送部署继续冻结。

上面是要求 Owner 明确作出的精确语句，不是本文件代替 Owner 作出的批准；在该语句及其他 Gate 字段实际确认前，P2-L 保持 CLOSED。

## 5. 最小验证与证据

获批后才可执行以下最小验证，且必须使用本地合成数据：

- 在任何 schema migration 前记录 pinned local GoTrue exact ref/config，完成真实 local email OTP→签名 JWT `amr[0]` 检查与 refresh 后复查；method/order/timestamp 缺失或格式异常、refresh 把原 OTP timestamp 重置为当前时间、10 分钟/+60 秒边界不符合合同，均 STOP 且不得进入 migration。当前尚未实测。
- migration/seed/pgTAP 或项目数据库测试能从空库重复建立首批十表，且不创建后置表、`auth.users` trigger 或隐含管理员路径。
- 每张首批表验证显式 grants、RLS policy、authenticated/anonymous/跨组织/跨店铺/empty-scope 的允许与拒绝矩阵；拒绝结果只记录有限分类。
- 验证普通 OTP identity 的 lazy profile、组织创建边界、membership、store scope、role/permission 解析和最小 `audit_logs`；任何客户端伪造 role/scope 都必须被拒绝。
- pgTAP/数据库矩阵必须覆盖两个 wrappers 与两个 private impl 的创建/替换、owner、空 `search_path`、全限定对象、private schema 未 exposed、`PUBLIC`/`anon`/`authenticated` grants、`rebuy_invite_executor` 全部 role attributes/无对象 ownership/最小列权限、touched tables `ENABLE`+`FORCE RLS`，以及 `anon`/`authenticated` direct DML deny。
- 对每张 touched table 检查 `pg_policy.polpermissive` 组合：至少一条仅适用于 `rebuy_invite_executor` 且按当前签名 JWT/invitation/permission/scope 收窄的 permissive allow，restrictive policies 只作额外 AND guards；证明不存在适用于 executor 的 blanket allow 或 `PUBLIC` permissive policy。
- 对 `pg_auth_members` 做双向断言：`rebuy_invite_executor` 作为 member 与 granted role 均为零行；同时证明该角色未授予任何 login、`anon`、`authenticated`、`authenticator`、`service_role` 或其他角色，也不属于任何其他 role。
- 验证 create/accept 对 `auth.jwt()` 最前 `amr[0]`、method=`otp`、数据库时间 10 分钟窗口、+60 秒偏差、`auth.uid()`、`is_anonymous`、签名 `@rebuy.test` email 的正负边界；分别拒绝 user_metadata、客户端 timestamp/boolean、JWT `iat`、缺失/乱序/格式错误 claim，并验证直接调用 wrapper/private impl 仍完整拒绝。
- 验证 `membership_invitations` 字段绑定及 create 时 inviter active/`member.invite`、role active/version/assignability、org/store 关系；accept 行锁后再次验证 creator 权限、role/version、签名目标 email、scope、过期、撤销和消费。
- 验证 organization scope 写一条 `scope_type='organization'`/`store_id IS NULL`，单店 scope 写一条 `scope_type='store'`/同组织非空 `store_id`，零 scope deny、multi-store JSONB/数组拒绝；验证 invitation id + accepted user/membership 幂等，同身份重试返回同一结果且不重复 membership/scope/audit，不同身份拒绝。
- Server Action/Route 每入口验证 re-auth、组织/membership/scope 授权、RLS 与 DTO 边界；不能以浏览器隐藏按钮、缓存或页面状态代替服务端检查。
- 只核对本批 exact local project 的 containers/volumes/network/listeners cleanup；保留脱敏 schema/RLS 结果，不保存 secret、service_role、DB password、token、cookie 或真实 PII。

P2-L 通过判据是：Owner 以 exact phrase 明确批准首批十表、10 分钟 AMR local exception、两个 invoker/private definer 函数链、隔离 executor/FORCE RLS、executor-only permissive allow + restrictive guards、role-membership 双向为空、role/version/显式 scope/idempotency，pinned GoTrue preflight 通过，scope 未越界，首批 RLS/grants/deny 与 invitation 事务矩阵通过，cleanup 通过且独立审查完成。即使这些条件全部满足，也只代表 P2-L local slice，不代表完整 P2 Exit 或 G2-A1 整体通过。

## 6. STOP 与回退

出现以下任一情况，立即停止并保持 P2-L CLOSED：

- 需要 service_role、admin key、hosted/Production、custom SMTP、真实 PII、真实邮件、Storage、支付、push、PR/merge、Vercel 或其他外部写入。
- pinned local GoTrue preflight 的 `amr[0]` 缺失/格式不符、method/timestamp 不满足窗口，或 refresh 重置原 OTP timestamp；此时不得进入 schema migration。
- RLS/grant、FK、scope、事务、re-auth 或 DTO 边界无法证明；anonymous、empty scope、跨组织或跨店铺路径意外可达。
- 任一 touched table 缺少 executor-only、事实收窄的 permissive allow，restrictive policy 被误作独立授权，存在适用于 executor 的 blanket/`PUBLIC` permissive policy，或 `pg_auth_members` 任一方向非空、executor 被授予其他角色/属于其他 role。
- invitation 尝试使用 multi-store JSONB/数组、缺少签名 AMR recent-OTP 证明、role/version/creator 权限失效、scope 行缺失，或 wrapper/private impl 的 owner/空 `search_path`/grants/FORCE RLS/direct DML deny/行锁/原子性无法证明。
- 客户端可提交可信角色/权限/组织归属，Server Action/Route 依赖旧 session 或页面状态，或 `auth.users` trigger 被作为必要授权链路。
- 目标资源无法精确归属本批，端口/网络与其他项目冲突，出现未授权镜像/费用，或 cleanup 不完整。
- 任何 secret、service_role、DB password、OTP、token、cookie、真实邮箱/账号/PII 或 raw database/provider output 进入输出、日志、仓库、截图或 evidence。

回退只允许停止本地执行、回滚本批新建的 local migrations/seed/data（在获批的可逆窗口内）、清理精确 project 资源并追加脱敏记录；不得改写历史 Gate、不得用 provider invite 或 fake replay 替代 membership invite 证据。任何未完成项都记录为未验证，等待新的 Owner 决定。

## 7. 明确非目标

E2b provider invite/admin key、Google、Apple、hosted Auth、custom SMTP、真实 PII、Storage、支付、push、PR、merge、Vercel、Staging、Production、完整 P2 Exit、G2-A1 整体通过、`wholesale applications/qualifications`、`security_events`、multi-store invitation 关联表以及任何超出首批十表的业务 schema 均不在本 Gate 打开范围内。

## 8. References

- [Supabase MFA FAQ：AMR 最近认证方法与 timestamp](https://supabase.com/docs/guides/auth/auth-mfa#how-do-i-check-when-a-user-went-through-mfa)
- [Supabase Row Level Security：`auth.jwt()` 与 `user_metadata` 授权警告](https://supabase.com/docs/guides/database/postgres/row-level-security#authjwt)
