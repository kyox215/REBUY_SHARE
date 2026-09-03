# P2-L 本地 Schema 与 RLS 纵切 Gate

文档状态：**P2-L local Exit 已关闭 / REVIEW GO；允许打开 P3 bounded Gate**
记录日期：2026-09-03（Europe/Rome）
适用分支：`codex/rebuy-v1-local-complete`；本文件保留全部 bounded runtime、审查与修复事实，不把历史 PASS 外推为当前 Exit。

## 1. 推荐路线例外与当前冻结

在 E2a 已 REVIEW GO、E2b provider invite 与 E3 Google/E4 Apple/E5 hosted 均保持冻结的前提下，Owner 已批准一个 **P2-L synthetic-only local slice**。该例外只打开本地 preflight execution，不打开完整 P2，不改变 G2-A1 整体状态，也不替 E2b provider invite Gate。

普通身份通过现有 E2a local email OTP 创建。真正的组织/员工邀请不依赖 admin key 或 provider invite，而是在 P2-L 内使用 RLS 保护的 membership invitation record 与接受事务实现，先证明目标邮箱控制权，再在服务端事务中完成 membership 关联和最小审计。该路线不使用 `service_role`，也不把客户端提交的角色当作可信输入。

当前状态为 **Owner 已批准 / preflight PASS / schema 尚未执行**：下述首批十表与邀请安全路线已由第 4 节 exact phrase 绑定批准，第三次最终 bounded pinned local GoTrue preflight 已完整 PASS。该 PASS 只满足前置条件；本批未授权或执行 P2-L schema、migration、seed、业务数据库写入或 P2-L schema/RLS runtime，下一步仍须独立 bounded Gate。

## 2. Exact scope

### 2.1 允许范围

- 唯一代码范围：`codex/rebuy-v1-local-complete` 分支与其 `.worktrees/rebuy-v1-local-complete-exec` worktree。
- 唯一运行范围：本地 Supabase，loopback 端口 `55320–55329`；不得连接 hosted/Production，不得触碰其他项目容器、volume、network 或 `54321–54324`。
- 数据范围：合成身份、合成组织/店铺/成员关系、`@rebuy.test` 成功路径；不使用真实邮箱、账号、客户/员工资料或其他 PII。
- 允许的实现产物：数据库 migrations、合成 seed、pgTAP 或项目相关数据库测试、prototype server auth/DTO、脱敏 docs/evidence。第三次最终 bounded preflight 已 PASS；migration、seed、schema/DB write 仍须新的有效 Gate，且不因 preflight PASS 自动开始执行。

### 2.2 首批表

推荐的首批 scope 只覆盖以下十张业务表，依赖关系和权限必须逐表明确；该 scope 已由 Owner exact phrase 批准，preflight 前置条件现已 PASS，但本次 one-shot Gate 不构成 schema/DB write 执行授权：

`profiles`、`organizations`、`stores`、`memberships`、`membership_invitations`、`membership_store_scopes`、`role_definitions`、`permissions`、`role_permissions`、`audit_logs`。

`wholesale applications/qualifications` 后置到下一批；`security_events` 再后置。不得借 P2-L 首批顺手创建其他业务表、Storage 对象、支付对象或生产迁移。

### 2.3 组织成员邀请路线

P2-L 的 Rebuy membership invite 是业务记录，不是 Supabase provider invite：

1. 普通用户用现有 local OTP 建立已验证 identity/session。
2. 推荐的首批邀请只允许组织级，或绑定 exactly one store 的单店级；不支持 multi-store JSONB/数组。未来多店邀请必须使用独立关联表并另开新 Gate，不得扩写首批 `membership_invitations` 字段来绕过 scope。
3. 创建和接受邀请推荐采用固定 **10 分钟** recent-OTP window，以数据库当前时间为准，并只容许 Auth claim 时间最多领先数据库 **60 秒**。每个 create/accept RPC 链路都从已经 Data API 验签的 `auth.jwt()` 读取最前面的 `amr[0]`，要求其 `method='otp'` 且数值 `timestamp` 位于该窗口；同时要求 `auth.uid()` 非空、`is_anonymous=false`，且签名 JWT 中的规范化 email 属于 `@rebuy.test`。
4. `amr[0].timestamp` 是 Supabase Auth 签发 JWT 中的签名 claim；`user_metadata`、客户端时间戳、客户端布尔值和 JWT `iat` 均不得作为 recent-OTP 证据。该合同已获批准但仅限 synthetic-only local 的 AAL1 例外，不宣称 MFA/AAL2，也不得外推到 hosted/Production。
5. `membership_invitations` 必须绑定可信 `organization_id`、`role_definition_id`、`role_version`、`scope_type`、可选的 exactly-one `store_id`、规范化 synthetic target email、creator membership、expiry/status，以及接受后的 user/membership 结果。
6. 创建时 inviter 必须仍是当前 active membership 且拥有 `member.invite`；候选 role/store 只作为不可信输入，RPC 必须重新解析并验证角色可分配、role active/version 及 organization/store 关系。接受时先锁定 invitation 行，再重新验证 creator 仍有 `member.invite`、role active/version/assignability、签名 JWT 目标 email、scope、过期、撤销与消费状态。
7. 数据库公开入口 precisely two：`public.create_membership_invitation` 与 `public.accept_membership_invitation`，均为 `SECURITY INVOKER` wrapper；真正实现分别位于未 exposed 的 private schema，使用 `private.create_membership_invitation_impl` 与 `private.accept_membership_invitation_impl` `SECURITY DEFINER`。无论攻击者尝试直接调用 wrapper 或 private impl，函数都必须重做完整 identity、recent OTP、permission、role、scope 与状态校验。
8. `rebuy_invite_executor` 只能通过最小列权限与 RLS 工作：每张 touched table 至少配置一条仅适用于该 executor、按当前签名 JWT/invitation/permission/scope 事实收窄的 `PERMISSIVE` allow policy；`RESTRICTIVE` policies 只能作为额外 AND guards。禁止任何适用于 executor 的 blanket 或 `PUBLIC` permissive policy；membership 仅允许第 19 节批准的唯一 PostgreSQL 17 bootstrap 行。
9. provider/admin invite、`inviteUserByEmail`、service_role 和 admin key 不参与该业务邀请路线。

Owner Gate 已执行；第三次最终 bounded pinned local GoTrue preflight 已验证 `amr[0]` 的顺序、`method` 与 `timestamp`，并验证 refresh 未把原 OTP timestamp 重置为“现在”。前两次在 STATUS 检查处的历史 `STATUS_FAIL` 已保留；第三次在相同 reviewed 脚本、由父 Node 继承 Docker socket 权限后完整 `P2L_PREFLIGHT_PASS`。本批仍不进入 schema migration；P2-L invite/schema 执行继续 defer 到独立 bounded Gate。

## 3. 必须满足的安全合同

- 所有首批业务表启用 RLS，并配置显式、最小化 `GRANT`；被 invitation create/accept 链路触及的 tables 必须同时 `ENABLE ROW LEVEL SECURITY` 与 `FORCE ROW LEVEL SECURITY`。表级 grants 与行级 RLS 分开验证。
- empty scope 默认 deny；用户没有明确 membership/store scope 时，不得读取、写入、更新或删除组织/店铺业务行。
- `memberships`、`membership_invitations`、`membership_store_scopes` 与关联路径的组织、店铺、用户、角色版本、状态和过期字段建立所需 FK/约束/查询索引；索引不得被写成越权条件。
- 不使用 `service_role`、admin key 或客户端可信角色作为授权捷径；public/publishable key 只用于受 RLS 保护的普通请求。
- 首批 invitation scope 只能是组织级或 exactly one store 的单店级；multi-store JSONB/数组一律拒绝，未来多店邀请必须使用独立关联表并经新 Gate。
- 创建和接受邀请均在数据库内校验经过 Data API 验签的 `auth.jwt()`：最前面的 `amr[0]` 必须是 10 分钟内的 `otp`，数据库时间为准且未来偏差不得超过 60 秒；`auth.uid()` 非空、`is_anonymous=false`、签名 email 为规范化 `@rebuy.test`。`user_metadata`、客户端时间/布尔值与 JWT `iat` 不得参与该判断。
- `private.*_impl` 的 owner 固定为专用 `rebuy_invite_executor`；该角色必须是 `NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS`，不得拥有 schema 或 table，只持有 touched tables 的最小列权限。definer 不得绕过 RLS 或业务授权。
- `rebuy_invite_executor` 不得属于任何 role，也不得授予给 `anon`、`authenticated`、`authenticator`、`service_role` 或其他 login；`pg_auth_members` 与 executor 相关的总行数必须恰好为一，且只能是第 19 节批准的 `postgres` / `supabase_admin`、`ADMIN=true/INHERIT=false/SET=false` bootstrap 行。
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

Owner Gate 字段已由下方 action-time exact phrase 绑定确认：exact branch/HEAD、唯一 worktree、local project id、`55320–55329` loopback 隔离、首批十表、synthetic identity 生命周期、10 分钟 AMR window/+60 秒偏差、AAL1 local exception、组织级/exactly one store 邀请边界、两个 public invoker wrappers/private definer impl、`rebuy_invite_executor` 属性/最小权限/双向 role-membership 为空、touched tables FORCE RLS、executor-only narrow `PERMISSIVE` allow + `RESTRICTIVE` AND guards 且无 blanket/`PUBLIC` permissive policy、role/version/scope/idempotency、migration/seed 回退、RLS/grant 审查、数据库测试范围、server auth/DTO 入口、cleanup、证据位置和停止条件。本批实际 pinned local GoTrue 为 `public.ecr.aws/supabase/gotrue:v2.188.1`，完整 image ID/digest 见第 9 节与 evidence。

### Owner 明确批准语句（action-time approval record）

> 批准 P2-L 本地纵切：允许在 codex/rebuy-v1-local-complete 中使用本地 Supabase 与合成身份实施首批十表（profiles、organizations、stores、memberships、membership_invitations、membership_store_scopes、role_definitions、permissions、role_permissions、audit_logs）的 schema/RLS/grants；Rebuy membership invite 首批仅允许组织级或 exactly one store 的单店级，不允许 multi-store JSONB/数组；批准仅限 synthetic-only local 的 AAL1 例外，create/accept 采用数据库时间固定 10 分钟 recent-OTP window 和最多 +60 秒偏差，从 Data API 验签的 auth.jwt() 读取最前 amr[0] 并要求 method=otp、auth.uid() 非空、is_anonymous=false、签名 email 为规范化 @rebuy.test，禁止 user_metadata、客户端时间/布尔值与 JWT iat 充当证明，且不宣称 MFA/AAL2、不外推 hosted/Production；批准 precisely two 个 public SECURITY INVOKER wrappers（public.create_membership_invitation、public.accept_membership_invitation）调用未 exposed private schema 中 search_path 为空且对象全限定的 private.*_impl SECURITY DEFINER，由不拥有 schema/table 的专用 rebuy_invite_executor（NOLOGIN/NOSUPERUSER/NOCREATEDB/NOCREATEROLE/NOINHERIT/NOREPLICATION/NOBYPASSRLS）以最小列权限执行，该 executor 不属于任何 role、也不授予任何 login/anon/authenticated/authenticator/service_role 或其他角色且 pg_auth_members 双向为空，每张 touched table 至少有一条仅适用于 executor、按当前签名 JWT/invitation/permission/scope 事实收窄的 PERMISSIVE allow policy，RESTRICTIVE policies 仅作额外 AND guards，禁止任何适用于 executor 的 blanket 或 PUBLIC permissive policy，touched tables ENABLE+FORCE RLS，同一 migration 先 revoke PUBLIC/anon EXECUTE 再只 grant authenticated 对 wrappers 及调用 private impl 所需最小 schema/function 权限，anon/authenticated 无 invitation/membership/scope/audit 直接 DML，任一直接 wrapper/private 调用均重做全部校验且不得使用 service_role/admin key；批准 invitation 绑定 organization_id、role_definition_id、role_version、scope_type、可选 exactly-one store_id、规范化 target email、creator membership、expiry/status/accepted result，create/accept 重新验证 inviter/creator active member.invite、role active/version/assignability、同组织 store、签名目标 email、行锁、过期/撤销/消费，organization 与 store scope 均写显式 membership_store_scopes 行且零 scope deny，并以 invitation id + accepted_user_id/accepted_membership_id 保证同身份重试不重复 membership/scope/audit、不同身份拒绝；任何 migration 前先对 pinned local GoTrue 真实 local email OTP 验证 amr[0] 且 refresh 不重置原 OTP timestamp，失败即 STOP 并 defer P2-L invite；E2b、E3-E5、hosted、真实数据、推送部署继续冻结。

上面是本 Gate 的 exact approval phrase。主代理已将用户在本线程的原始回复 `批准全部`（2026-08-31，Europe/Rome）绑定为该语句及 `P2-L → P3 → P4 → P5 → P6` 本地顺序的有效 action-time Owner approval；该批准不等于 preflight PASS，也不自动打开后续阶段。

### 4.1 Action-time approval record

- 批准时间：`2026-08-31`（Europe/Rome；用户未提供具体时刻）；用户原始回复：`批准全部`。
- 基线与隔离：canonical root 为 `/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划`；基线分支为 `codex/rebuy-v1-local-complete`；唯一写入 worktree 为 `/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划/.worktrees/rebuy-v1-local-complete-exec`；base `HEAD`=`0e5084b62c76275a781ec08edea287a06d442209`。
- 主代理绑定的完整批准范围：第 4 节 exact phrase 全部内容，即首批十表 schema/RLS/grants、synthetic-only local AAL1、10 分钟 recent-OTP/+60 秒偏差与签名 `auth.jwt()` `amr[0]` 合同、组织级或 exactly one store membership invite、两个 public wrapper/private definer 链、`rebuy_invite_executor`/最小权限/双向 role-membership 空、touched-table ENABLE+FORCE RLS、executor-only narrow `PERMISSIVE` allow 与 `RESTRICTIVE` AND guards、role/version/scope/idempotency、migration 前 preflight 与全部冻结边界；同时批准按 `P2-L → P3 → P4 → P5 → P6` 的本地顺序推进，但每个后续阶段仍须满足自己的 Gate，不构成自动开门。
- 当前执行项与未决项：本批真实 pinned local GoTrue email OTP + refresh AMR preflight 已执行但为 **STOP / FAIL**。P2-L schema、migration、seed、业务数据库写入和 P2-L schema/RLS runtime 均保持 CLOSED。
- pinned local GoTrue exact image ref：`public.ecr.aws/supabase/gotrue:v2.188.1`；image ID/digest 见第 9 节与 evidence。
- 继续冻结：Google/Apple 真实 OAuth、E2b provider invite、hosted Supabase/Production、真实数据、GitHub push、Vercel deployment，以及任何其他外部写入。

## 5. 最小验证与证据

获批后才可执行以下最小验证，且必须使用本地合成数据。当前 `preflight execution-only` 只允许第一项；在第一项 PASS 前，第 2 项及之后的 migration/seed/schema/DB/RLS/runtime 验证均保持 CLOSED：

- 在任何 schema migration 前记录 pinned local GoTrue exact ref/config，完成真实 local email OTP→签名 JWT `amr[0]` 检查与 refresh 后复查；method/order/timestamp 缺失或格式异常、refresh 把原 OTP timestamp 重置为当前时间、10 分钟/+60 秒边界不符合合同，均 STOP 且不得进入 migration。本批执行结果为 `STATUS_FAIL` / `P2L_PREFLIGHT_FAIL`，未形成 PASS，故不得进入 migration。
- migration/seed/pgTAP 或项目数据库测试能从空库重复建立首批十表，且不创建后置表、`auth.users` trigger 或隐含管理员路径。
- 每张首批表验证显式 grants、RLS policy、authenticated/anonymous/跨组织/跨店铺/empty-scope 的允许与拒绝矩阵；拒绝结果只记录有限分类。
- 验证普通 OTP identity 的 lazy profile、组织创建边界、membership、store scope、role/permission 解析和最小 `audit_logs`；任何客户端伪造 role/scope 都必须被拒绝。
- pgTAP/数据库矩阵必须覆盖两个 wrappers 与两个 private impl 的创建/替换、owner、空 `search_path`、全限定对象、private schema 未 exposed、`PUBLIC`/`anon`/`authenticated` grants、`rebuy_invite_executor` 全部 role attributes/无对象 ownership/最小列权限、touched tables `ENABLE`+`FORCE RLS`，以及 `anon`/`authenticated` direct DML deny。
- 对每张 touched table 检查 `pg_policy.polpermissive` 组合：至少一条仅适用于 `rebuy_invite_executor` 且按当前签名 JWT/invitation/permission/scope 收窄的 permissive allow，restrictive policies 只作额外 AND guards；证明不存在适用于 executor 的 blanket allow 或 `PUBLIC` permissive policy。
- 对 `pg_auth_members` 做精确断言：executor 作为 member 为零；作为 granted role 恰好为批准的唯一 `postgres` bootstrap 行；同时证明 `postgres` 不能继承 executor 权限、不能 `SET ROLE`，且不存在任何其他关系。
- 验证 create/accept 对 `auth.jwt()` 最前 `amr[0]`、method=`otp`、数据库时间 10 分钟窗口、+60 秒偏差、`auth.uid()`、`is_anonymous`、签名 `@rebuy.test` email 的正负边界；分别拒绝 user_metadata、客户端 timestamp/boolean、JWT `iat`、缺失/乱序/格式错误 claim，并验证直接调用 wrapper/private impl 仍完整拒绝。
- 验证 `membership_invitations` 字段绑定及 create 时 inviter active/`member.invite`、role active/version/assignability、org/store 关系；accept 行锁后再次验证 creator 权限、role/version、签名目标 email、scope、过期、撤销和消费。
- 验证 organization scope 写一条 `scope_type='organization'`/`store_id IS NULL`，单店 scope 写一条 `scope_type='store'`/同组织非空 `store_id`，零 scope deny、multi-store JSONB/数组拒绝；验证 invitation id + accepted user/membership 幂等，同身份重试返回同一结果且不重复 membership/scope/audit，不同身份拒绝。
- Server Action/Route 每入口验证 re-auth、组织/membership/scope 授权、RLS 与 DTO 边界；不能以浏览器隐藏按钮、缓存或页面状态代替服务端检查。
- 只核对本批 exact local project 的 containers/volumes/network/listeners cleanup；保留脱敏 schema/RLS 结果，不保存 secret、service_role、DB password、token、cookie 或真实 PII。

P2-L 通过判据是：Owner 明确批准首批十表、10 分钟 AMR local exception、两个 invoker/private definer 函数链、隔离 executor/FORCE RLS、executor-only permissive allow + restrictive guards、第 19 节唯一 bootstrap 关系、role/version/显式 scope/idempotency，pinned GoTrue preflight 通过，scope 未越界，首批 RLS/grants/deny 与 invitation 事务矩阵通过，cleanup 通过且独立审查完成。即使这些条件全部满足，也只代表 P2-L local slice，不代表完整 P2 Exit 或 G2-A1 整体通过。

## 6. STOP 与回退

出现以下任一情况，立即停止并保持 P2-L schema/migration/seed/DB write CLOSED；不得把未完成的 preflight 记录为 PASS：

- 需要 service_role、admin key、hosted/Production、custom SMTP、真实 PII、真实邮件、Storage、支付、push、PR/merge、Vercel 或其他外部写入。
- pinned local GoTrue preflight 的 `amr[0]` 缺失/格式不符、method/timestamp 不满足窗口，或 refresh 重置原 OTP timestamp；此时不得进入 schema migration。
- RLS/grant、FK、scope、事务、re-auth 或 DTO 边界无法证明；anonymous、empty scope、跨组织或跨店铺路径意外可达。
- 任一 touched table 缺少 executor-only、事实收窄的 permissive allow，restrictive policy 被误作独立授权，存在适用于 executor 的 blanket/`PUBLIC` permissive policy，或 `pg_auth_members` 偏离第 19 节唯一 bootstrap 行、executor 被授予其他角色/属于其他 role。
- invitation 尝试使用 multi-store JSONB/数组、缺少签名 AMR recent-OTP 证明、role/version/creator 权限失效、scope 行缺失，或 wrapper/private impl 的 owner/空 `search_path`/grants/FORCE RLS/direct DML deny/行锁/原子性无法证明。
- 客户端可提交可信角色/权限/组织归属，Server Action/Route 依赖旧 session 或页面状态，或 `auth.users` trigger 被作为必要授权链路。
- 目标资源无法精确归属本批，端口/网络与其他项目冲突，出现未授权镜像/费用，或 cleanup 不完整。
- 任何 secret、service_role、DB password、OTP、token、cookie、真实邮箱/账号/PII 或 raw database/provider output 进入输出、日志、仓库、截图或 evidence。

回退只允许停止本地执行、回滚本批新建的 local migrations/seed/data（在获批的可逆窗口内）、清理精确 project 资源并追加脱敏记录；不得改写历史 Gate、不得用 provider invite 或 fake replay 替代 membership invite 证据。任何未完成项都记录为未验证，P2-L schema/migration/seed/DB write 继续 CLOSED，等待后续 Gate 决定。

## 7. 明确非目标

E2b provider invite/admin key、Google、Apple、hosted Auth、custom SMTP、真实 PII、Storage、支付、push、PR、merge、Vercel、Staging、Production、完整 P2 Exit、G2-A1 整体通过、`wholesale applications/qualifications`、`security_events`、multi-store invitation 关联表以及任何超出首批十表的业务 schema 均不在本 Gate 打开范围内。

## 8. References

- [Supabase MFA FAQ：AMR 最近认证方法与 timestamp](https://supabase.com/docs/guides/auth/auth-mfa#how-do-i-check-when-a-user-went-through-mfa)
- [Supabase Row Level Security：`auth.jwt()` 与 `user_metadata` 授权警告](https://supabase.com/docs/guides/database/postgres/row-level-security#authjwt)

## 9. 2026-08-31｜Pinned local GoTrue AMR preflight STOP

- 结果：**STOP / FAIL**。指定 Node `22.12.0` 的 `node --check` 通过；唯一 actual 调用返回脱敏断言 `STATUS_FAIL`、`P2L_PREFLIGHT_FAIL`，未重试，`actual_count=1`。
- 执行范围：唯一 worktree 为 `/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划/.worktrees/rebuy-v1-local-complete-exec`，local project id 为 `rebuy-g2-a1-e2a-local-email-otp-exec`，仅使用 loopback `55320–55329`；Supabase CLI `2.101.0`，CLI 环境设置 `SUPABASE_TELEMETRY_DISABLED=1` 与 `SUPABASE_HOME=/private/tmp/rebuy-p2l-supabase-home`。
- GoTrue runtime：tag=`public.ecr.aws/supabase/gotrue:v2.188.1`；image ID=`sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`；RepoDigest=`public.ecr.aws/supabase/gotrue@sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`。
- 输出处理：start/status 的敏感 stdout 未进入终端或 evidence；只保留上述有限断言。未记录合成身份值、OTP、publishable key、secret、token、cookie、JWT 或 raw provider/status output。
- Cleanup：立即执行 `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`，返回成功；目标 project containers、volumes、network 均为空，`55320–55329` listeners 为零。
- 结论：preflight 未 PASS，P2-L schema/migration/seed/DB write 与 P2-L schema/RLS runtime 继续 **CLOSED**；E2b、E3–E5、hosted/Production、真实数据、service_role/admin key、部署与其他外部写入继续冻结。脱敏证据见 [P2-L AMR preflight evidence](../evidence/P2-L/2026-08-31-amr-preflight/README.md)。

## 10. 2026-08-31｜Harness status-shape diagnosis 与 selector 修正（仍 STOP）

- 本节是对第 9 节历史 STOP/FAIL 的 follow-up，不改写历史 actual 结果。本次只启动 exact local Supabase 一次做 shape 诊断，未运行 `run-p2l-amr-preflight.mjs`，未发 Auth/OTP/identity/refresh 请求，follow-up `actual_count=0`。
- 脱敏 shape：`CLI_RC=0`、`JSON_PARSE=true`；sorted keys=`ANON_KEY,API_URL,DB_URL,GRAPHQL_URL,INBUCKET_URL,JWT_SECRET,MAILPIT_URL,MCP_URL,PUBLISHABLE_KEY,REST_URL,SECRET_KEY,SERVICE_ROLE_KEY,STUDIO_URL`；`API_URL`=`present=true/type=string/local-origin=true`；`PUBLISHABLE_KEY`=`present=true/type=string/allowed-format=true/length=46`；`ANON_KEY`=`present=true/type=string/allowed-format=true/length=153`。没有记录任何值。
- Confirmed latent selector defect（不是历史 `STATUS_FAIL` 唯一根因）：harness 原有 `status?.PUBLISHABLE_KEY ?? status?.ANON_KEY` 对空/非法 string 不回退，会遮蔽有效 `ANON_KEY`。当前现场两个 key 均合法，因此该 shape 不足以唯一重放第 9 节历史失败；raw status 按白名单合同未保留。
- 局部修正：新增纯 `selectAllowedPublicKey` 至 `prototype/scripts/p2l-amr-preflight-config.mjs`，`run-p2l-amr-preflight.mjs` 改用第一个合法候选；新增无网络 `prototype/scripts/test-p2l-amr-preflight-structure.mjs`，覆盖空值/非法值回退、legacy anon 格式、publishable 优先和双空失败。
- 验证：三个 harness 文件 `node --check` 通过；结构测试输出 `P2L_SELECTOR_STRUCTURE_PASS`；`git diff --check` 通过。未运行 actual、Auth/OTP/identity/refresh、migration、schema、seed 或 DB write。
- Cleanup：精确 `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` 成功；目标 containers、volumes、network 为空，`55320–55329` listeners 为零；未使用 `--all`。
- 结论：第 9 节 STOP/FAIL 保持有效；本次修正不构成 P2-L PASS。下一次 actual 仍未运行，必须重新取得一次性 Gate；P2-L schema/migration/seed/DB write 与 runtime 继续 **CLOSED**。详见 [follow-up evidence](../evidence/P2-L/2026-08-31-amr-preflight/README.md)。

## 11. 2026-08-31｜Refresh timing hardening（仍 STOP）

- 本批不启动 Supabase/Docker，不运行 `run-p2l-amr-preflight.mjs`，不发 Auth/OTP/identity/refresh 请求，`actual_count=0`；第 9 节历史 STOP/FAIL 与历史 `actual_count=1` 保持不变。
- Refresh 前置时间门：当前 epoch seconds 与 initial AMR timestamp 的绝对差必须 `>=2`；每 `100 ms` 检查一次，`10,000 ms` 有限超时。日志只允许 `REFRESH_AMR_TIME_SEPARATION_PASS/FAIL`，不输出 timestamp 或 token；绝对差覆盖获批的 future-skew 情况。
- Refresh 证据加固：`REFRESH_ACCESS_TOKEN_CHANGED` 要求 refreshed access token 与 initial token 不同；refreshed claims 新增 `is_anonymous === false`，并保留 OTP method、numeric timestamp、timestamp equality 与 normalized email 断言。
- 纯结构测试覆盖同秒和一秒差拒绝、双向 `>=2` 秒允许、future skew 允许及 key fallback；package 新增 `test:auth:p2l:structure`，不会由普通 `test:auth` 自动触发 actual identity preflight。
- 验证：指定 Node `22.12.0` 对 harness、helper、结构测试的 `node --check` 均通过；package 结构测试有限输出为 `P2L_PREFLIGHT_STRUCTURE_PASS`。未运行 full test/build/lint/E2E。
- 结论：本次 timing hardening 未运行 actual，不构成 PASS；下一次 actual 仍需新的 one-shot Gate。P2-L schema/migration/seed/DB write 与 runtime 继续 **CLOSED**。

## 12. 2026-08-31｜第二次 one-shot AMR preflight STOP

- Action-time Gate：Owner 在主线程回复 `全部批准`，仅绑定 exact local project、`@rebuy.test` synthetic identity、修正后 harness 的第二次 one-shot preflight，以及 PASS/FAIL 后立即精确清理；未打开 migration/schema/seed/业务 DB write、hosted、push 或 deploy。
- 入口：分支、唯一 worktree、project id、Node `22.12.0` 路径、脚本入口、目标资源为空及 `55320–55329` 无监听均符合合同；harness/helper/test/package/evidence/Gate/docs15 与上一批一致，actual 前未修改 harness。
- 结果：**STOP / FAIL**。第二次 one-shot 仅运行一次且未重试，本次 `actual_count=1`；第 9 节首次 FAIL 及其独立 `actual_count=1` 保留。有限输出仅为 `STATUS_FAIL`、`P2L_PREFLIGHT_FAIL`。
- 覆盖边界：执行在 OTP、identity、refresh 前停止；因此 `>=2` 秒 AMR timing separation、changed access token、refreshed `is_anonymous=false`、method、timestamp equality 与 normalized email 断言均未被本次 actual 执行，不得写成 PASS。
- GoTrue runtime：tag=`public.ecr.aws/supabase/gotrue:v2.188.1`；image ID=`sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`；RepoDigest=`public.ecr.aws/supabase/gotrue@sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`。敏感 start/status stdout、stderr、raw status、key、OTP、identity email、token、JWT、cookie、DB password 与 provider response 均未保留。
- Cleanup：立即精确执行 `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` 并返回 `0`；目标 containers、volumes、network 与 `55320–55329` listeners 均为空，未使用 `--all`。
- 最终离线验证：Node `22.12.0` 分别对 harness、helper、结构测试执行 `node --check` 并通过；`test:auth:p2l:structure` 输出 `P2L_PREFLIGHT_STRUCTURE_PASS`；`git diff --check` 通过。未运行 full test/build/lint/E2E。
- 结论：preflight 继续 **STOP / FAIL**，P2-L schema/migration/seed/DB write 与 schema/RLS runtime 继续 **CLOSED**；不打开下一步 schema Gate。后续诊断或 actual 必须另立边界明确的 Gate。本批未 commit/push/deploy。

## 13. 2026-08-31｜第三次最终 bounded one-shot AMR preflight PASS

- Gate / review：Owner action-time 回复 `全部批准` 与获批的父 Node `require_escalated` 工具审批共同绑定本次唯一 actual。独立只读 Sol 审查结论为 `REVIEW GO`、`P0=0/P1=0/P2=1`，并以 90–95% 高置信将前两次 status failure 指向 Docker socket 权限。
- Integrity：actual 前后 `git hash-object` 完全一致：harness=`0bf3a6b102598b5291365d92defa825f4a1a91e8`、helper=`f8d7e485abbbba0d430de075e2fa57b5674df83a`、structure test=`4f5a88b7b194494cfc9d7834041a3c43c001720a`；未修改 harness/helper/test/package。
- Entry：exact cwd/branch/HEAD=`0e5084b62c76275a781ec08edea287a06d442209`、project id、Node `22.12.0`、CLI `2.101.0`、空目标 resources 与 `55320–55329` 无监听均通过。
- Result：**PASS**。第三次 bounded actual 仅运行一次、未重试，本次 `actual_count=1`；第 9 与第 12 节两次历史 FAIL 及各自 `actual_count=1` 原样保留。完整结束 category 为 `P2L_PREFLIGHT_PASS`。
- 有限断言：`STATUS_PASS`、合成 identity 生成、OTP request/capture/verify、initial get-user、initial OTP AMR method/numeric timestamp/recency、initial `is_anonymous=false`、normalized email、refresh 前 `>=2` 秒绝对时间差、refresh session、changed access token、refresh get-user、refreshed OTP method/numeric timestamp/unchanged timestamp、refreshed `is_anonymous=false`、refreshed normalized email 与最终 `P2L_PREFLIGHT_PASS` 均 PASS；未保留任何值。
- 权限根因：受控对比验证父 Node 继承的 Docker socket 权限边界是前两次 `STATUS_FAIL` 的运行根因。exact reviewed harness 直接以提权父进程运行后，其内部原生 `execFile` status 调用与完整 AMR/refresh 路径通过；未使用 wrapper、mock、PATH 替身或外部 status handoff。selector 仍是 confirmed latent defect，但不是历史失败的观测唯一根因。
- Runtime / privacy：GoTrue tag=`public.ecr.aws/supabase/gotrue:v2.188.1`；image ID=`sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`；RepoDigest=`public.ecr.aws/supabase/gotrue@sha256:87db8c737af49a64236c461882ed3925f8b1e5c2c47176c64694dedc65153573`。敏感 start/status stdout、stderr、raw status、key、OTP、identity email、token、JWT、cookie、DB password 与 provider response 均未保留。
- Cleanup：立即精确执行 `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` 并返回 `0`；目标 containers、volumes、network 与 `55320–55329` listeners 均为空，未使用 `--all`。
- 最终离线验证：Node `22.12.0` 分别对 harness、helper、结构测试执行 `node --check` 并通过；`test:auth:p2l:structure` 输出 `P2L_PREFLIGHT_STRUCTURE_PASS`；`git diff --check` 通过。未运行 full test/build/lint/E2E。
- Boundary / Next：本次未执行 migration/schema/seed/业务 DB write、hosted/Production、真实数据、privileged-key 路径、commit/push/deploy。preflight 前置条件现为 PASS；下一步只可另开 schema Gate 候选，不得从本批自动执行。

## 14. 2026-09-01｜Schema 候选离线静态审计（runtime 仍 CLOSED）

- Scope：本批只读取并修订未执行的 migration 候选及无数据库结构测试；未启动 Supabase/Docker，未读取或修改 Supabase 用户配置，未运行 migration、seed、pgTAP、schema/RLS runtime 或任何业务 DB write。
- Confirmed defect / fix：`accept_membership_invitation_impl` 原本把两个 `hashtextextended(...)` `bigint` 传给 `pg_advisory_xact_lock`，而 PostgreSQL 不提供 `(bigint, bigint)` overload。当前改为先用 `concat(user_id, ':', organization_id)` 形成单一哈希输入，再调用受支持的单 `bigint` advisory transaction lock；仍按接受者与组织串行化首次接受。
- Regression gate：新增 `test:auth:p2l:migration:structure`，离线断言首批恰好十张 public 表、每表 `ENABLE`+`FORCE ROW LEVEL SECURITY`、executor 非特权属性、无 `service_role` grant、无 `auth.users` trigger、两个 public `SECURITY INVOKER` wrapper、两个 private `SECURITY DEFINER` implementation、空 `search_path`，以及 advisory lock 恰为单参数组合键。
- Verification：指定 Node `22.12.0` 下 `P2L_MIGRATION_STRUCTURE_PASS`、`P2L_PREFLIGHT_STRUCTURE_PASS`、现有 Auth 契约测试 `37/37`、typecheck、lint、Next `16.3.2` production build 与 `git diff --check` 均通过；build 生成的 `next-env.d.ts` 漂移已恢复，未把生成态混入候选。
- Boundary / Next：本批不构成 migration/schema/RLS/pgTAP PASS，不打开后续阶段，也未 commit/push/deploy。下一步仍须新的 P2-L schema runtime Gate，且需要明确授权 exact local Docker socket 与 Supabase CLI 用户级 telemetry 文件访问；获批后才可执行空库重建与数据库正负向矩阵。

## 15. 2026-09-02｜Schema runtime attempt #1 STOP 与角色属性根因修复

- Gate / Entry：Owner 回复 `允许之后的所有批准`，主代理只将其绑定到上一条已完整展示的 P2-L schema runtime exact phrase；不把概括授权外推为未定义的 hosted、Production、真实数据或付费资源动作。当前分支、唯一 worktree、HEAD=`0e5084b62c76275a781ec08edea287a06d442209`、Supabase CLI `2.101.0`、local project id、`55320–55329`、单一 migration/seed/两份 pgTAP 与结构门均核对通过；Colima 启动后目标容器、卷、网络和端口为空。
- Actual：抑制可能包含本地 key/DB URL 的 `supabase start` stdout 后执行唯一一次启动，`actual_count=1`。数据库进入 migration `20260831183358_p2l_local_schema_rls_invites.sql` 后，在 `ALTER ROLE rebuy_invite_executor NOSUPERUSER ...` 处返回 SQLSTATE `42501`；未进入 seed、pgTAP、lint 或 advisors。
- Root cause：本地 migration runner 可创建已明确为 `NOSUPERUSER` 的新角色，但 PostgreSQL 只允许 SUPERUSER 改变 `SUPERUSER` 属性；即使目标是 `NOSUPERUSER`，把该属性放在后续 `ALTER ROLE` 中仍会被拒绝。失败候选 migration hash=`c32318bb90fa28c0f6b12e94721dd261b00ba441`。
- Fix：保留创建语句一次性设置 `NOLOGIN/NOSUPERUSER/NOCREATEDB/NOCREATEROLE/NOINHERIT/NOREPLICATION/NOBYPASSRLS`；删除全部后续 `ALTER ROLE`。若同名角色已存在，migration 现在逐项检查七个危险属性，任一开启即 `rebuy_invite_executor_attributes_invalid` fail closed，不尝试由 migration runner 提权修复。修复后 migration hash=`6ca01ad8f3508b7df8408cef400e3ff7a465c679`。
- Cleanup / Verification：失败后立即精确执行 `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`，返回 `0`；目标容器、卷、网络和 `55320–55329` listener 均为空。修复后的无数据库结构门 `P2L_MIGRATION_STRUCTURE_PASS`、目标脚本 ESLint 与 `git diff --check` 通过；结构测试 hash=`abb0510d2bf7621743462175c6a0e9a5450ebaab`。
- Boundary / Next：本工作包按一次性验证合同不重试实际启动；当前修复仍只是静态候选，不构成 schema/seed/pgTAP/RLS PASS。下一工作包从空资源状态重新做入口哈希与结构预检，只允许一次 `start → db reset --local → test db --local → lint/advisors → exact cleanup`；失败仍立即 STOP。详见 [attempt #1 evidence](../evidence/P2-L/2026-09-02-schema-runtime-attempt-1/README.md)。

## 16. 2026-09-02｜Schema runtime attempt #2 STOP 与 `roles.sql` bootstrap 修复

- Entry：从 attempt #1 cleanup 后的空资源状态恢复；CLI=`2.101.0`、exact worktree/branch/HEAD、migration hash=`6ca01ad8f3508b7df8408cef400e3ff7a465c679`、seed/pgTAP hashes、结构门、Colima 与端口均通过。第二工作包实际调用前 `actual_count=0`。
- Actual：唯一 `supabase start` 进入同一 migration，角色属性 guard 已通过，随后 `pg_auth_members` 双向零关系 guard 抛出 `rebuy_invite_executor_role_membership_present`；`actual_count=1`。未进入首批 table DDL、seed、pgTAP、lint 或 advisors。
- Root cause：PostgreSQL 17 对非 SUPERUSER `CREATEROLE` 创建的新角色自动回授 `ADMIN TRUE / SET FALSE / INHERIT FALSE`；该 grant 由 bootstrap superuser 产生，创建者自己不能删除。这正是 catalog 中被 Gate 正确拒绝的 membership，不应降低双向零关系合同来绕过。
- Fix：按 Supabase CLI 官方 custom-role 工作流新增 `supabase/roles.sql`，由 `start/reset` 的 globals 阶段在 migrations 前创建 `rebuy_invite_executor`。角色脚本创建时固定七项安全属性，并对属性与双向 membership fail closed；migration 删除所有 cluster-role CREATE/ALTER，只要求角色已存在并重复验证属性与零 membership。新 hashes：roles=`233d6fb4bf048bc99d027e0cf98b2463513cc216`、migration=`bdf9fc156920ed2cdeded27a655551046a52e24f`、structure test=`eaf7aa321dfdee678762d078fabadf210749c978`。
- Cleanup / Verification：失败后 exact stop/no-backup 返回 `0`；目标 containers/volumes/network/listeners 为空。修复后 `P2L_MIGRATION_STRUCTURE_PASS`、目标 ESLint 与 `git diff --check` 通过。
- Boundary / Next：本工作包不重跑 actual；当前修复仍未建立 schema/seed/pgTAP/RLS runtime PASS。第三工作包须从空资源、新 hashes 和结构门开始，只允许一次完整序列；如再出现新的 runtime failure，仍立即 cleanup，并按 Supabase 2–3 次失败上限停止盲目补丁。详见 [attempt #2 evidence](../evidence/P2-L/2026-09-02-schema-runtime-attempt-2/README.md)。

## 17. 2026-09-02｜Schema runtime attempt #3 STOP 与尝试上限

- **Entry / Actual**：从空目标资源进入；CLI `2.101.0`，结构门、目标 ESLint 与 `git diff --check` 通过。唯一 `supabase start` 在 `Seeding globals from roles.sql` 阶段返回 `rebuy_invite_executor_role_membership_present`，本批 `actual_count=1`；未进入 migration、seed、pgTAP、lint 或 advisors。
- **Finding**：当前 Supabase CLI globals 阶段没有改变 executor 的创建者语义；`roles.sql` 仍由非 SUPERUSER `CREATEROLE` 身份执行，PostgreSQL 17 自动产生 role-admin membership。双向 `pg_auth_members` 零关系 guard 的拒绝符合 Gate，不能删除或放宽。
- **Limit / Next**：连续三次 runtime 尝试上限已到。本工作包不修改候选、不再重跑；下一步只允许先做专项离线设计审查，证明一种不依赖 superuser/service-role/hosted 管理路径且创建时不产生自授予的方案，再单独开新 Gate。
- **Cleanup / Boundary**：exact stop/no-backup exit `0`；目标 containers、volumes、network、`55320–55329` listeners 均为空，Colima 未停止。P2-L runtime、P3–P7、commit/push/deploy 继续关闭。证据见 [attempt #3](../evidence/P2-L/2026-09-02-schema-runtime-attempt-3/README.md)。

## 18. 2026-09-02｜Executor bootstrap 专项根因审查与 Gate 修订候选

- **Confirmed**：Supabase CLI `2.101.0` 以非超级用户 `postgres` 在同一连接直接执行 `roles.sql`，没有切换 `supabase_admin` 的受支持入口；精确 `17.6.1.106` 镜像中 `postgres` 不是 `supabase_admin` 成员。PostgreSQL 17 强制把非 SUPERUSER `CREATEROLE` 创建的新角色以 `ADMIN=true/INHERIT=false/SET=false` 授给创建者，并以 bootstrap superuser 为 grantor；创建者不能撤销该行，`createrole_self_grant=''` 也不会取消它。
- **Rejected**：不采用 `SET createrole_self_grant` 伪修复、创建后 self-REVOKE、`SET ROLE supabase_admin`、内嵌管理密码/dblink/container init、service-role/table-owner 绕过或删除 guard。
- **Proposed exact exception（待 Owner action-time approval）**：executor 作为 member 仍必须零行；作为 granted role 必须且只能有一行 `member=postgres`、`grantor=bootstrap superuser/supabase_admin`、`admin=true`、`inherit=false`、`set=false`。所有其他 member/grantor/options 以及任何 `anon/authenticated/authenticator/service_role` 关系继续 fail closed，并新增 pgTAP 证明 `postgres` 不继承且不能 `SET ROLE`。
- **Status / Boundary**：本批 `actual_count=0`，未修改 SQL/migration/tests，未启动 runtime。Owner 明确批准该精确例外前，attempt #3 候选与 P2-L runtime 保持 STOP，P3–P7/commit/push/deploy 关闭。详见 [design review](../evidence/P2-L/2026-09-02-role-bootstrap-design-review/README.md)。

## 19. 2026-09-02｜Owner 批准 executor bootstrap 精确例外

- **Approval**：Owner 在收到第 18 节完整精确例外后明确回复“批准”。该回复只绑定这一条 PostgreSQL 17 平台强制关系：`roleid=rebuy_invite_executor`、`member=postgres`、`grantor=supabase_admin/bootstrap`、`ADMIN=true`、`INHERIT=false`、`SET=false`。
- **Still fail closed**：executor 作为 member 必须零行；与 executor 相关的总行数必须恰好为一；任何其他 member、grantor、options，或 `anon/authenticated/authenticator/service_role` 关系都必须拒绝。七项受限属性、FORCE RLS、最小列权限、invoker wrapper/private definer、无 service-role grant、无 `auth.users` trigger 等合同不变。
- **Verification required**：`roles.sql` 与 migration 必须重复执行同一精确 guard；静态门必须识别白名单及额外关系拒绝；pgTAP 必须证明 exact row、executor 无上游 membership、`postgres` 无继承且不能 `SET ROLE`。以上均通过后，才允许一次新的 bounded local runtime Gate。
- **Boundary**：本批准不开放 hosted/Production、真实邮箱/PII、付费资源、main push 或部署；这些仍按后续阶段独立取证。

## 20. 2026-09-02｜Schema runtime attempt #4 STOP 与 SQL conditional-expression 修复

- **Entry**：Owner 第 19 节批准已落入 `roles.sql`、migration、静态门与 pgTAP；Node 22 下 Auth `40/40`、typecheck、全量 lint、Next build、`P2L_PREFLIGHT_STRUCTURE_PASS`、`P2L_MIGRATION_STRUCTURE_PASS` 与 `git diff --check` 均通过。目标 containers/volumes/network/listeners 为空；CLI=`2.101.0`。
- **Actual**：唯一 `supabase start` 成功完成 globals，并进入 migration，证明批准的 exact bootstrap guard 已通过；随后首条 profile executor insert policy 报 `function pg_catalog.nullif(text, unknown) does not exist`（SQLSTATE `42883`）。未进入 seed、pgTAP、db lint/advisors，本批 `actual_count=1`。
- **Root cause / offline fix**：`NULLIF`、`COALESCE`、`EXTRACT` 是 PostgreSQL 特殊 SQL 表达式语法，不能作为 schema-qualified 普通函数调用。已离线机械修复 migration 中全部三类错误，并把禁止 `pg_catalog.nullif/coalesce/extract(` 加入结构门；不在本工作包内重跑 runtime。
- **Cleanup / Boundary**：exact stop/no-backup exit `0`；目标 containers、volumes、network 与 `55320–55329` listeners 均为空。P2-L runtime 仍未通过，P3–P7、hosted/Production、main push/deploy 保持关闭。证据见 [attempt #4](../evidence/P2-L/2026-09-02-schema-runtime-attempt-4/README.md)。

## 21. 2026-09-02｜Schema runtime attempt #5 STOP 与 owner-transfer 冲突

- **Entry**：attempt #4 离线修复后，Auth `40/40`、typecheck、全量 lint、两个 P2-L 结构门、`git diff --check` 与空目标资源入口再次通过；候选 hashes 见 evidence。
- **Actual**：唯一 `supabase start` 已越过 globals、executor exact membership guard、conditional expressions、全部 table/policy/function DDL，随后在 `ALTER FUNCTION ... OWNER TO rebuy_invite_executor` 返回 SQLSTATE `42501`：`must be able to SET ROLE "rebuy_invite_executor"`。未进入 seed、pgTAP、lint/advisors，本批 `actual_count=1`。
- **Confirmed conflict**：PostgreSQL 17 官方合同要求变更 function owner 的当前会话能 `SET ROLE` 到新 owner，且新 owner 对函数所在 schema 有 `CREATE`。当前批准的最终 bootstrap 行刻意为 `SET=false`，executor 也只有 schema `USAGE`，因此 owner transfer 在不增加临时能力时不可达。
- **Proposed next Gate（待 Owner exact approval）**：仅在 owner-transfer 的显式事务内，由已有 `ADMIN=true` 的 local migration runner 以 `GRANTED BY CURRENT_USER` 新增第二条 `postgres` grant（`ADMIN=false/INHERIT=false/SET=true`），临时授予 executor 对 `private` schema 的 `CREATE`；完成两个 private function owner transfer 后立即撤销该第二条 grant 和 `CREATE`，在 `COMMIT` 前重新执行最终 catalog guard，证明只剩第 19 节唯一 bootstrap 行、`postgres` 无 `USAGE/SET`、executor 无 schema CREATE。任一语句失败则事务回滚，不能留下临时能力。
- **Cleanup / Boundary**：exact stop/no-backup exit `0`，目标 containers/volumes/network/listeners 为空。本批不实现该新增安全例外、不再重跑；P2-L runtime、P3–P7、hosted/Production、main push/deploy 继续关闭。证据见 [attempt #5](../evidence/P2-L/2026-09-02-schema-runtime-attempt-5/README.md) 与 [owner-transfer review](../evidence/P2-L/2026-09-02-owner-transfer-design-review/README.md)。

## 22. 2026-09-03｜Owner 批准 owner-transfer 原子事务例外

- **Approval**：Owner 在收到第 21 节完整精确例外后回复“批准全部”。本 Gate 将该回复绑定为 owner-transfer 所需的最小、原子、可回滚能力：migration runner 只在单条原子 `DO` 语句内，以 `GRANTED BY CURRENT_USER` 建立 `role=rebuy_invite_executor/member=postgres/grantor=postgres/ADMIN=false/INHERIT=false/SET=true` 的第二条临时 membership，并临时授予 executor 对 `private` schema 的 `CREATE`。
- **Atomic contract**：同一 `DO` 语句必须只转移 `private.create_membership_invitation_impl(uuid,uuid,integer,text,uuid,text,uuid)` 与 `private.accept_membership_invitation_impl(uuid)` 两个函数；随后先撤销临时 membership 和 schema `CREATE`，再执行最终 catalog 断言。任何 grant、owner transfer、revoke 或断言失败都使整条语句回滚，禁止跨语句保留临时能力。
- **Required final state**：与 executor 相关的 membership 总数仍恰好一行且只能是第 19 节 bootstrap 行；executor 作为 member 零行；`postgres` 对 executor 的 `USAGE=false/SET=false`；executor 对 `private` schema 的 `CREATE=false`；两个 private functions 的 owner 恰为 executor。静态门与 pgTAP 必须重复验证最终状态。
- **Boundary**：开放该 SQL/tests 实现及一次新的 bounded local runtime Gate；本批准本身不把 P2-L 标为 PASS，也不跳过空库重建、seed、pgTAP、RLS 正负矩阵、lint/advisors、migration list 与 exact cleanup。

## 23. 2026-09-03｜Schema runtime attempt #6 STOP；owner handoff 已过，pgTAP fixture 待复验

- **Passed before STOP**：唯一 bounded sequence 中，`start` 完成 globals/migration/原子 owner handoff/seed，合成邮箱 AMR preflight 全部通过，`db reset --local` 又从重建数据库重复完成 migration/owner handoff/seed。第 21 节的 owner-transfer 冲突已由真实 runtime 解除。
- **STOP point**：两份 pgTAP 在业务断言前分别因扩展 search path 未含 `extensions`、以及测试权限 UUID 与 seed 的 `member.invite`/`member.read` unique key 冲突而停止。未运行 lint/advisors/migration list，P2-L 仍未 PASS。
- **Offline candidate**：两份测试加入 `extensions` transaction search path；邀请测试复用 seed canonical permission IDs；结构门新增两类回归断言。修复后只做离线结构门与 diff check，本包不重跑 runtime。
- **Cleanup / Next**：exact stop/no-backup 后目标 containers、volumes、network/listeners 为空。下一独立 bounded Gate 从空资源复验修复后的 pgTAP，再继续 lint/advisors/migration list；详见 [attempt #6](../evidence/P2-L/2026-09-03-schema-runtime-attempt-6/README.md)。

## 24. 2026-09-03｜Schema runtime attempt #7 STOP；请求声明 helper 修订候选

- **Progress / STOP**：从空资源重建再次通过；schema pgTAP 已执行 49 条并通过 44 条。失败项显示 executor 无法获得平台 `auth` schema USAGE，四条空 search-path 断言使用了错误的 catalog 编码；invitation test 的 claims fixture 仍含非法 `pg_catalog.extract(...)`，在业务矩阵前停止。
- **Least-privilege revision**：拒绝接管 `auth` schema、宽角色 membership 或 privileged key。P2-L SQL 改用 private schema 中两个项目自有 `SECURITY INVOKER`/owner=`postgres`/空 search-path helper，读取 Supabase 官方 `auth.jwt()/auth.uid()` 同源的 `request.jwt.claim(s)` GUC；只授权 `authenticated` 与 executor，`PUBLIC`/`anon` 拒绝。executor 对 `auth` schema 和平台 auth functions 保持无权限。
- **Test corrections**：空 search-path 按 `pg_proc.proconfig` 的 `search_path=""` 断言；两份 pgTAP 与 migration 一并禁止 schema-qualified `NULLIF/COALESCE/EXTRACT`。helper owner/security/grants 和 auth-schema 非依赖进入静态门与 pgTAP。
- **Cleanup / Next**：exact cleanup 后资源与端口为空，本包不重跑。下一 bounded Gate 从空资源验证完整矩阵；详见 [attempt #7](../evidence/P2-L/2026-09-03-schema-runtime-attempt-7/README.md)。

## 25. 2026-09-03｜Schema runtime attempt #8 STOP；ACL 顺序与 temp fixture 修复候选

- **Progress**：schema pgTAP 从 `44/49` 推进到 `50/53`；helper owner/search-path/grants 与 owner handoff final state 的主体断言通过。invitation test 已越过 seed 和特殊表达式入口。
- **Failures**：两条 auth helper 断言误把平台 PUBLIC execute 视作 executor direct grant；profile policy 仍匹配旧函数名；authenticated 测试角色无 postgres-owned temp result table 权限。另外 start warnings 揭示 private impl ACL 在 owner handoff 后修改，postgres 已不再是 owner，因此 grant/revoke 未生效。
- **Offline fixes**：改用 catalog ACL 展开证明无 executor direct auth grant；策略断言改为项目 helper；第一次 role switch 前显式 grant temp tables；private impl ACL 全部移到 handoff 前并由 postgres owner 完成，静态门禁止 handoff 后修改，pgTAP新增 anon private execute deny。
- **Cleanup / Next**：exact cleanup 后资源与端口为空，本包不重跑。下一独立包从空资源复验；详见 [attempt #8](../evidence/P2-L/2026-09-03-schema-runtime-attempt-8/README.md)。

## 26. 2026-09-03｜Schema runtime attempt #9 STOP；schema security 已全绿

- **Passed**：空资源重建无 ACL warnings；`p2l_schema_security.test.sql` 全部通过。invitation test 的前三个 RPC/expiry/idempotency assertions 也通过。
- **STOP**：测试随后在 authenticated 身份下直接读取 `membership_invitations` 做证据计数，被既有 no-direct-table-grant 合同正确拒绝。业务 wrapper 未在此处失败；lint/advisors/migration list 尚未运行。
- **Offline fix**：受保护表证据查询前临时 `RESET ROLE` 回测试管理员，完成后立即恢复 authenticated 继续 RPC；静态门解析测试 role state，禁止 authenticated 测试正文直接读取 invitation/membership/scope/audit 表。
- **Cleanup / Next**：exact cleanup 后资源与端口为空，本包不重跑。下一 bounded 包继续完整 invitation 矩阵；详见 [attempt #9](../evidence/P2-L/2026-09-03-schema-runtime-attempt-9/README.md)。

## 27. 2026-09-03｜Schema runtime attempt #10 STOP；invitation immutable-field 绑定修复

- **Progress / STOP**：空资源 start 与 schema security pgTAP 全部通过；invitation pgTAP 执行 33 条并通过 26 条。首次 organization accept 在更新 invitation 时被严格 RLS `WITH CHECK` 拒绝，后续 5 条依赖断言随事务回滚失败；末尾 store create 因 fixture 未恢复 creator claims 失败。lint/advisors/migration list 未运行。
- **Confirmed root cause**：accept 在 membership insert 阶段把内部 `created_at` 上下文切成当前时间，更新 invitation 前未恢复 locked row 的原始 `created_at`；实现也没有把 persisted `idempotency_key` 载入 accept 上下文。policy 的 immutable-field 精确绑定正确识别了两处缺失。
- **Offline fix**：不弱化任何 policy。accept 锁行时同时读取 idempotency key，并在 invitation update 前恢复该 key 与原始 created_at；末尾 store-create 用例显式恢复 creator recent-OTP claims。静态门新增相应读取与 update-before-RLS 回归断言，结构门和 diff check 通过。
- **Cleanup / Next**：exact cleanup 后指定 containers、volumes、network、listeners 均为空。下一独立 bounded Gate 从空资源复验 invitation 33 条并在通过后运行 lint/advisors/migration list；详见 [attempt #10](../evidence/P2-L/2026-09-03-schema-runtime-attempt-10/README.md)。

## 28. 2026-09-03｜Schema runtime attempt #11 STOP；acceptance audit 时间绑定修复

- **Progress / STOP**：空资源 start 通过；schema security `54/54` PASS，invitation `27/33`。Attempt #10 的 invitation update RLS 与末尾 store fixture 已解除；第 7 条走到 acceptance audit 后被 `audit_logs` strict RLS 拒绝，第 8–12 条因同事务回滚失败。lint/advisors/migration list 未运行。
- **Confirmed root cause**：invitation update 为 immutable-field 校验恢复了 invitation 原始 `created_at`，随后 audit insert 没有把同一受信上下文键切回 audit row 的数据库时间 `v_now`。既有 audit policy 正确拒绝，不需放宽授权。
- **Offline fix**：进入 `accept_audit` 后、插入前显式设置 `rebuy.invite.created_at=v_now`；静态门固定 op → time binding → insert 顺序。结构门、Node syntax 与 diff check 通过，本包不重跑。
- **Cleanup / Next**：exact cleanup 后指定 containers、volumes、network、listeners 均为空。下一 bounded Gate 复验 54+33 矩阵；详见 [attempt #11](../evidence/P2-L/2026-09-03-schema-runtime-attempt-11/README.md)。

## 29. 2026-09-03｜Schema runtime attempt #12 STOP at lint；pgTAP 87/87

- **Runtime progress**：空资源 start 通过；schema/security `54/54` 与 invitation `33/33` 合计 `87/87` PASS，证明 invitation immutable fields、acceptance audit、显式 scope、幂等和拒绝矩阵已闭环。
- **STOP**：db lint 在 create implementation 的 expiry UPDATE 报一个 ambiguous `expires_at` error，并报告两个 dead-variable warnings。按 Gate 停止，advisors 与 migration list 未运行。
- **Offline fix**：两个 expiry UPDATE 均添加目标表别名并限定 `id/status/expires_at`；移除未使用的 invitation updated-at 快照和 creator-role scope 读取。授权矩阵不变；静态门新增未限定 expiry-column 回归拒绝。
- **Cleanup / Next**：exact cleanup 后目标 containers、volumes、network、listeners 均为空；新候选结构门、Node syntax、diff check 通过。本包不重跑，下一 bounded Gate 从空资源复验 pgTAP+lint 后继续 advisors/list；详见 [attempt #12](../evidence/P2-L/2026-09-03-schema-runtime-attempt-12/README.md)。

## 30. 2026-09-03｜Schema runtime attempt #13 STOP at strict lint；控制流收敛

- **Runtime progress**：空资源 start 与 pgTAP `87/87` 再次通过；attempt #12 的 ambiguity error 及旧 warnings 已消失。
- **STOP**：warning 即失败的 strict lint 新暴露 create loop-after code unreachable 与 `v_existing_updated_at` never read 两项；advisors/list 未运行。
- **Offline fix**：INSERT 成功直接 `EXIT insert_invitation`，仅 unique conflict 继续解析已有行；删除布尔中间态和 unused updated-at projection。静态门固定显式 success exit/unique-handler 顺序，并禁止两个 dead state。
- **Cleanup / Next**：exact cleanup 与临时敏感日志删除完成，目标资源/端口为空；结构门、Node syntax、diff check 通过。下一 bounded Gate 复验 pgTAP+strict lint，再继续 advisors/list；详见 [attempt #13](../evidence/P2-L/2026-09-03-schema-runtime-attempt-13/README.md)。

## 31. 2026-09-03｜Schema runtime attempt #14 STOP at strict lint；审计移入 retry loop

- **Runtime progress**：空资源 start 与 pgTAP `87/87` 再次通过；unused updated-at warning 已消失。
- **STOP**：strict lint 仍把 retry loop 后 audit `PERFORM` 判为 unreachable；advisors/list 未运行。
- **Offline fix**：unique-conflict 解析完整收进 invitation INSERT exception handler；正常 INSERT 成功在同一 loop iteration 内写 create audit 并 RETURN，handler 只允许 RETURN/RAISE/expire 后 CONTINUE。audit 不在 exception 捕获范围内，避免审计唯一键异常被误判为 invitation conflict。
- **Cleanup / Next**：exact cleanup、资源/端口确认及临时敏感日志删除完成；结构门固定新的三终态控制流。下一 bounded Gate 复验 pgTAP+strict lint 后继续 advisors/list；详见 [attempt #14](../evidence/P2-L/2026-09-03-schema-runtime-attempt-14/README.md)。

## 32. 2026-09-03｜Schema runtime attempt #15 STOP at advisors；pgTAP/lint 已通过

- **Runtime progress**：空资源 start 与 pgTAP `87/87` 再次通过；strict warning lint 返回 `No schema errors found`，exit `0`，证明 attempt #14 的控制流修复已关闭 PL/pgSQL warning。
- **STOP**：all/info advisors 虽 exit `0`，但命中 Rebuy 项目对象的 14 条 `auth_rls_initplan` WARN 与 4 条 `unindexed_foreign_keys` INFO；fresh empty database 另报告 `unused_index` INFO。按上线保障标准在 advisors 停止，migration list 未运行。
- **Offline fix**：只在 executor policy 区间把 179 处请求 GUC 读取改成 scalar `(SELECT current_setting(...))` init plan；implementation/helper 语义不变。四个 FK lookup index 扩展为与复合外键完全相同的 leading-column 顺序；静态门固定两类要求。
- **Cleanup / Next**：exact cleanup、资源/端口确认及临时敏感日志删除完成；新候选结构门、Node syntax、diff check 通过。本包不重跑；下一 bounded Gate 复验 pgTAP、strict lint、security/performance advisors，通过后才运行 migration list。详见 [attempt #15](../evidence/P2-L/2026-09-03-schema-runtime-attempt-15/README.md)。

## 33. 2026-09-03｜Schema runtime attempt #16 PASS；独立审查待完成

- **Runtime PASS**：从空资源以 exact candidate 启动一次；schema/security `54/54` 与 invitation `33/33` 合计 `87/87` PASS；strict warning lint 为 `No schema errors found`。
- **Advisors / migration**：security info 与 performance warn 两个 strict Gate 均 `No issues found`。all/info 的 23 条均为 fresh empty database `unused_index` INFO；`auth_rls_initplan=0`、`unindexed_foreign_keys=0`、WARN/ERROR=`0`。migration list 的 local/database history 均为唯一 `20260831183358`。
- **Cleanup**：exact stop/no-backup、三份精确临时文件删除、project containers/volumes/network 与 `55320–55329` listeners 清空全部通过。
- **Current Gate**：schema/RLS/runtime 已 PASS；完整 P2-L 仍等待绑定 exact hashes 的独立安全/数据库复审，输入见 [review packet](../evidence/P2-L/2026-09-03-independent-review-packet/README.md)。该复审完成前 P3–P7、hosted/Production、main push/deploy 继续 CLOSED。详见 [attempt #16](../evidence/P2-L/2026-09-03-schema-runtime-attempt-16/README.md)。

## 34. 2026-09-03｜独立审查 NO-GO；两项 P1 阻断

- **Verdict**：独立只读 Sol/max reviewer 对 attempt #16 exact hashes 给出 `REVIEW NO-GO`，`P0=0 / P1=2 / P2=2`。
- **P1 blockers**：一是未显式 revoke/验证 `service_role` 对 private schema、十表和六个函数的 effective ACL；二是 `87/87` 未覆盖 accept recent-OTP/email、邀请创建后 creator/candidate/org/store authority 失效，以及真实双连接并发。
- **P2 findings**：accept 对目标用户泄露内部授权状态码；attempt #16 缺少脱敏 TAP/lint/advisor/migration/cleanup 原始工件及 SHA-256。
- **Gate**：P2-L Exit 回到 NO-GO。完整报告见 [independent review verdict](../evidence/P2-L/2026-09-03-independent-review-packet/REVIEW.md)；新候选完成完整 runtime 和同一 reviewer 定向 GO 前，P3–P7、main push/deploy 保持 CLOSED。

## 35. 2026-09-03｜Review 修复候选与 schema runtime attempt #17 STOP

- **Offline fixes**：migration 显式 revoke `service_role` private schema、首批十表、两 request helpers、两 private implementations 和两 public wrappers；pgTAP 增加 effective ACL 断言。accept 外部错误收敛为 `invitation_not_available`；pgTAP 增加 recent-OTP/email、creator membership/permission/scope/role、candidate assignability、organization/store 失效、store accept/exact scope；新增两个独立 `psql` 连接的同邀请及同 target/org 多邀请并发 harness。静态门同步锁定上述合同。
- **Attempt #17**：空资源、CLI `2.101.0` 与候选 hashes 锁定后，唯一 `supabase start` exit `0` 并应用 migration/seed；AMR preflight 被默认 Node `20.20.2` 启动，在 `createClient()` 初始化返回有限 `UNEXPECTED_FAIL / P2L_PREFLIGHT_FAIL`。按 one-shot Gate 立即停止；reset、pgTAP、concurrency、lint/advisors 与 migration list 均未运行。
- **Root cause / hardening**：离线对照确认 Node 20 缺少新版 Supabase SDK 要求的 native WebSocket，固定 Node `22.12.0` 构造成功。harness 新增 major=22 的首动作 guard，纯测试覆盖 20/22/24/invalid；Node 20 现在在 status/network/OTP/DB 前 fail closed。
- **Cleanup / next**：exact stop/no-backup、敏感 start raw 与 telemetry temp 删除、目标 containers/volumes/network/listeners 清空均通过。attempt #17 `actual_count=1` 且本包不重试。下一工作包从空资源、固定 Node `22.12.0` 运行一次完整 Gate并保存脱敏工件/哈希；详见 [attempt #17](../evidence/P2-L/2026-09-03-schema-runtime-attempt-17/README.md)。

## 36. 2026-09-03｜Schema runtime attempt #18 STOP；creator store-scope context 修复候选

- **Entry / progress**：固定 Node `22.12.0` 后，Auth `46/46`、两项结构门、typecheck、全量 ESLint、build 与空资源入口通过。唯一 start、完整 AMR preflight 和 fresh db reset 全部 PASS。
- **STOP**：schema/security pgTAP 文件 PASS；invitation `52` 项中 `48` PASS、`4` FAIL，总计 `109` 项失败 `4`。失败只在 organization-scoped creator 创建的两条 store invitation accept 正向路径；按 Gate 停止，未运行 concurrency、lint/advisors 或 migration list。
- **Root cause / offline fix**：`accept_validate` 的 membership-scope SELECT policy 故意要求 context scope/store 精确相等；store invitation 的 context 因此隐藏了 creator 的合法 organization scope。policy 不放宽；private implementation 在 store 状态验证后显式切到 organization context 检查 creator org scope，不存在时切回 exact store context 检查 creator store scope，最后恢复 invitation context。pgTAP 新增 creator exact-store fixture，静态门锁定 context 顺序。
- **Cleanup / next**：exact stop/no-backup、敏感 temp 删除与目标 resources/listeners 清空通过；attempt #18 `actual_count=1`，本包不重试。下一工作包从空资源与新 hashes 完整复验。详见 [attempt #18](../evidence/P2-L/2026-09-03-schema-runtime-attempt-18/README.md)。

## 37. 2026-09-03｜Schema runtime attempt #19 STOP；pgTAP 110/110 / concurrency 专项审查

- **Passed**：唯一 start、固定 Node 22 完整 AMR、fresh reset 与两份 pgTAP 全部通过，`Files=2, Tests=110, Failed=0, Result=PASS`。attempt #18 的 organization/exact-store creator scope 两条路径已关闭。
- **Concurrency STOP**：双连接 harness 已越过 same-invitation、same-target/org multi-invitation 与 final-state 断言，随后有限输出 `P2L_INVITATION_CONCURRENCY_FAIL:stable_retry`。旧 stage 同时覆盖 accepted lookup/parse、accepted retry/result、unavailable retry 与 cleanup，当前不能把失败诚实归因到某一项。
- **Limit / review**：attempt #17–#19 达到本轮三次实际失败上限。exact cleanup、敏感 temp 删除与 resources/listeners 清空完成；strict lint/advisors/list 未运行。新 runtime 当时停止并进入同一独立 reviewer 的只读专项审查；harness 下一候选必须拆分有限子阶段且不输出数据。
- **Status**：该时点 P2-L=`PGTAP PASS / CONCURRENCY REVIEW BLOCKED`，详见 [attempt #19](../evidence/P2-L/2026-09-03-schema-runtime-attempt-19/README.md)。后续专项审查结论见第 38 节；完整 runtime 和独立最终 GO 前不打开 P3–P7/main/deploy。

## 38. 2026-09-03｜Concurrency 专项独立审查完成；harness-only 修复候选

- **Independent verdict**：专项 `REVIEW NO-GO`；对 attempt #19 当前失败来自 harness cleanup 外键循环、而非 invitation migration defect 的置信度高于 95%。accepted membership 通过 `source_invitation_id` 回指 invitation，而 invitation 又引用 membership，旧 cleanup 先删 membership 且无事务；旧全局 stage 未切到 cleanup，并吞掉 cleanup failure，故历史输出仍是宽泛 `stable_retry`。
- **Offline fix**：migration 不变。cleanup 现在单事务执行 audit → scopes → exact fixture `source_invitation_id=NULL` → invitations → memberships → stores → organization → auth users；profiles 使用既有 `ON DELETE CASCADE`。正常和失败路径均做精确零残留验证，失败只输出原 stage 与固定 cleanup outcome。
- **Harness hardening**：accepted lookup 固定 exactly one UUID pair 和 A/B invitation；accepted retry 验证 signal/exit 及 membership/org/store/scope 全字段；unavailable retry 验证无 signal、非零 exit、generic public error 且排除内部码。静态门固定顺序、事务、无 destructive broad cleanup、stage 与断言。
- **Verification / hashes**：Node 22 syntax、`P2L_MIGRATION_STRUCTURE_PASS`、定向 ESLint 与 diff check PASS。修复后 concurrency=`7938ce267e1d0febfad746bb7dcc8b575321e04719595b9b95c1e9a7ff294feb`，structure verifier=`8f8df05ce02c3173d186aa116fda35a5252295e8129e3ccc7c9ad40b31885b79`，migration 仍为 `13af3f60d2e665efaf3ae228cad2ffdee04d55c0a3969f55bbe65e4599ce28ba`。
- **Next**：专项审查解除三次失败后的诊断暂停，只允许从空资源对 exact candidate 新开一次 bounded runtime packet；失败立即 STOP/cleanup，不在同包重试。证据见 [concurrency special review](../evidence/P2-L/2026-09-03-concurrency-special-review/README.md)。

## 39. 2026-09-03｜Schema runtime attempt #20 PASS；最终独立复审待完成

- **Runtime PASS**：从空目标资源唯一启动；固定 Node 22 AMR preflight、fresh reset、schema/security 与 invitation pgTAP `113/113`、真实双连接 concurrency harness 全部 PASS。accepted retry、unavailable retry 与事务化零残留 cleanup 均已真实执行。
- **Database quality**：strict warning lint=`No schema errors found`；security info/fail-on-warn 与 performance warn/fail-on-warn 均=`No issues found`。all/info 只有 fresh empty database 的 8 条 `unused_index` INFO，WARN/ERROR、`auth_rls_initplan` 与 `unindexed_foreign_keys` 均为 0；migration history 两侧均为唯一 `20260831183358`。
- **Application quality**：Node `22.12.0` 下 Auth contract `46/46`、typecheck、全量 ESLint、Next `16.3.2` production build、两个 P2-L structure verifier 与 diff check 全部 PASS；生成态漂移已恢复。
- **Cleanup / evidence**：exact stop/no-backup 完成；敏感 raw/temp 删除；目标 containers/volumes/network/listeners 全空。已保存脱敏 entry、AMR、reset、pgTAP、concurrency、lint、advisors、migration list、app quality、cleanup、commands 与两组 SHA-256。
- **Gate**：P2-L runtime Gate 当前 PASS，但 Exit 仍等待同一独立 reviewer 对 exact commit/hashes 的最终 GO。证据见 [attempt #20 PASS](../evidence/P2-L/2026-09-03-schema-runtime-attempt-20-pass/README.md)；GO 前 P3–P7、hosted/Production、main push/deploy 继续 CLOSED。

## 40. 2026-09-03｜Final independent REVIEW GO；P2-L local Exit 关闭

- **Exact verdict**：独立 reviewer 绑定 commit `285c2361c6362e5be30e03ee445f2c4d5b6f7361` 与 candidate manifest，给出 `REVIEW GO / P0=0 / P1=0 / P2=1`。原 P1-01、P1-02、P2-01、P2-02 全部关闭；11 项 candidate hashes、两个结构门和 concurrency syntax 复核通过。
- **Non-blocking debt**：失败 cleanup 用双 `JSON.stringify` 比较解析对象，jsonb 键序理论上可造成 `cleanup_fail` 诊断假阴性；它不能制造 cleanup 假 PASS，也不影响 attempt #20 正常路径的全零验证，故不阻塞 Exit。后续修复需 deep equality + 静态拒绝旧模式，并另立 hash/验证记录。
- **Decision**：P2-L local Exit 关闭；允许按批准顺序打开 P3 自身的 bounded Gate。该决定不把 local slice 外推为 hosted/Production，也不开放 main push/deploy。完整 verdict 见 [final independent review](../evidence/P2-L/2026-09-03-final-independent-review/REVIEW.md)。
