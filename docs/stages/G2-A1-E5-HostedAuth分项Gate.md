# G2-A1-E5-Hosted Auth 分项 Gate

> 文档性质：Hosted Auth umbrella Gate 的窄分项合同。当前 umbrella 为 NO-GO，五个分项均 CLOSED；不允许以一个宽泛批准打开全部 hosted 能力。

## 1. 当前状态与范围

| 分项 | 当前状态 | 本文边界 |
|---|---|---|
| E5-LINK | CLOSED | 仅讨论是否允许连接一个明确的 non-production hosted Auth 目标；不等于 provider 配置或业务 linking |
| E5-CALLBACK | CLOSED | 仅讨论固定 HTTPS callback/origin/Host/path、redirect 和 replay 安全合同 |
| E5-HOSTED-AUTH | CLOSED | 仅讨论一次明确、可回退的 hosted Auth 设置；signup containment 必须先成立 |
| E5-INVITE | CLOSED | 仅讨论 provider invite primitive；需要一次性 trusted admin context，不等于 Rebuy membership invite |
| E5-CUSTOM-SMTP | CLOSED | 仅讨论 sandbox custom SMTP；hosted 默认 SMTP 不证明 local Mailpit，custom SMTP 不打开生产邮件 |
| umbrella | **NO-GO / CLOSED** | E5 不打开 hosted/Production、DB/Storage、provider-wide 变更或 G2-A1 整体 |

当前 Sol 官方资料专项摘要为 P0=0；P1 聚焦 callback 固定边界、provider token 不持久化和 signup containment，并确认 Apple 依赖 hosted callback/provider；P2 为测试缺口；当前没有活动 hosted 暴露。E2a local GoTrue/Mailpit 的 GO 只限 local synthetic-only，不打开任何 E5 分项。

## 2. 共同前置与禁止

以下条件必须在每一个 E5 分项 action-time Gate 之前满足：

1. 目标、组织、项目、环境、费用、Owner 和回退明确且唯一；不得从 Host、默认项目或已有登录态推断目标。
2. signup containment 已先成立并有独立证据；默认 Testing、基础 scope、test user 数量或期限不能替代应用/项目/环境隔离。
3. callback origin、Host、path、redirect allowlist、state/nonce/PKCE、一次性 code/replay 和最终 redirect 合同已通过；provider token 交换后不持久化。
4. 仅使用伪名合成身份、@rebuy.test 成功路径或 .invalid no-send/负向路径；禁止真实 PII/真实邮件。
5. 每个分项一份 exact Owner phrase、一次最小动作、一次回退和一次 cleanup；发现范围扩张即 STOP。

共同禁止：wide Gate、全局 provider toggle、任意 hosted/Production 写入、真实账号/邮件、service_role/admin key 的公开或持久化、DB/Storage/支付、push/PR/merge/deploy/Vercel、将 provider invite 写成 membership invite。

## 3. 五个独立分项

### 3.1 E5-LINK：目标连接 Gate

- **当前：CLOSED。** 只有一个明确的 non-production hosted Auth 目标可被 action-time 指定；不得 link 默认项目、Production 或其他 Rebuy/个人项目。
- **允许前提：** 目标 project/org/region/plan、连接方式、最小权限、0 费用或获批成本、撤销方式和 token 检查均已记录；hosted secret 只由 Owner 受控注入，不进入仓库、客户端或日志。
- **本地 code-only：** 可以测试目标显式传入、server-only env、固定 URL/key validator、不可连接时有限错误；不得读取 hosted secret 或执行 link。
- **最小测试：** wrong project/host、缺 env、secret 形态拒绝、provider token 不落地、撤销后不可继续；不以“能打开 dashboard”作为通过。

### 3.2 E5-CALLBACK：Hosted callback Gate

- **当前：CLOSED。** 需要固定 HTTPS origin、Host、path 和 redirect allowlist；拒绝动态 Host、通配符、open redirect、localhost、query/hash 变体和跨环境 callback。
- **允许前提：** E5-LINK 目标先获批；callback 仅指向明确 non-production；state、nonce、PKCE、一次性 code/replay 和最终 redirect 合同先通过 local code-only 复审。
- **本地 code-only：** 可在 prototype/lib/auth/callback.ts、callback-route.ts、redirect.ts、prototype/app/auth/callback/route.ts 做协议合同和 fake provider 测试，不发起 hosted OAuth。
- **最小测试：** fixed origin/Host/path、state/nonce/PKCE missing/mismatch/expired/replay、provider error 有限映射、token 不持久化；fake 结果不写成 live hosted 证据。

### 3.3 E5-HOSTED-AUTH：单一 HOSTED-AUTH 设置 Gate

- **当前：CLOSED。** 一次只允许一个明确、可观察、可回退的 Auth 设置变更；不得用 umbrella phrase 同时启用 signup、provider、linking、invite、SMTP 或 session 选项。
- **硬前置：** signup containment 必须先成立；需记录设置前后脱敏状态、影响范围、最小测试、回退和 cleanup。Testing 基础限制不等于 containment。
- **允许前提：** Owner 指定 exact project/setting/value/时间窗，确认 0 费用或明确批准费用，且无 Production/真实用户影响。
- **最小测试：** anonymous/unknown/目标外邮箱不能获得业务访问；合法 synthetic identity 只获得预期 Auth 状态；provider token 不落地；设置回退后行为恢复。

### 3.4 E5-INVITE：Provider invite Gate

- **当前：CLOSED。** inviteUserByEmail/provider invite primitive 需要一次性 trusted admin context；不得通过公开 Route Handler、通用 admin client、NEXT_PUBLIC env、普通日志或客户端暴露 admin key。
- **允许前提：** 仅获批的 non-production/sandbox 目标、@rebuy.test synthetic mailbox、一次性 local harness；admin context 只从 gitignored owner-only env 注入，失败即 STOP，执行后销毁/轮换。
- **语义边界：** provider invite 只证明 provider 发送/创建 primitive；不创建、不接受、不授予 Rebuy organization/membership/store/role。真正 membership invite 必须走后续 RLS 保护的业务 invitation record 与接受事务。
- **最小测试：** target mismatch、重复/过期/replay、无 trusted context、provider error 脱敏、Mailpit/approved catcher 捕获、cleanup；不得用真实邮件或真实账号。

### 3.5 E5-CUSTOM-SMTP：Custom SMTP Gate

- **当前：CLOSED。** hosted 默认 SMTP 的邮件结果不能证明 local Inbucket/Mailpit；local E2a 的默认 catcher 与 hosted SMTP 是不同事实。
- **允许前提：** 仅 sandbox/non-production、专用 synthetic domain/catcher、0 真实 PII、最小一次配置和可回退；任何账单、外发真实地址、组织 SMTP 凭据或 production 目标立即 STOP。
- **明确禁止：** 当前配置 custom SMTP、记录 SMTP user/password/API token、发送真实邮件、将 hosted 默认限额写成稳定 SLA，或以 custom SMTP 关闭 E5 其他分项。
- **最小测试：** only approved synthetic recipient、模板/有限错误、失败不泄露 provider text、回退后不发送、cleanup 删除设置和 catcher evidence；local Mailpit 证据不能跨环境移用。

## 4. 最小文件与测试矩阵

| 范围 | 文件/证据 | 最小覆盖 |
|---|---|---|
| callback/redirect | prototype/lib/auth/callback.ts、callback-route.ts、redirect.ts、prototype/app/auth/callback/route.ts | fixed origin/Host/path、state/nonce/PKCE/replay、最终 redirect、有限错误 |
| client/server boundary | prototype/lib/supabase/client.ts、server.ts、config.ts、server-config.ts、prototype/lib/auth/session.ts | server-only env、cookie/session、provider token 不持久化、错误不吞 |
| entry/UI | prototype/app/account/login/LoginPrototype.tsx | E5 全部关闭时不发起 hosted/provider OAuth；状态不冒充生产 |
| existing auth runner | prototype/tests/auth/contract.test.ts、prototype/scripts/run-auth-contract-tests.mjs | 五分项的 invalid input/target/credential/error/replay/cleanup contract；不引入第二套框架 |
| action-time evidence | 每分项单独 README/harness，按批准再创建 | 目标、phrase、设置前后、scope/token 检查、synthetic-only、回退、cleanup |

## 5. 日志、凭据、STOP 与 cleanup

- 日志/evidence 只允许固定 stage、状态码/有限 code、目标类别和脱敏时间线；不得输出 hosted URL 中的 secret、admin/service key、provider token、OTP、cookie、邮箱原值或 provider raw error。
- 任意 secret/admin context/token/真实 PII 出现，目标/Host/path/scope 漂移，signup containment 缺失，费用/账单出现，默认 SMTP 或 hosted project 目标不明，或无法清理时立即 STOP。
- cleanup 必须精确到本分项的 project/config/identity/catcher/listener；撤销授权/删除 synthetic identity/删除临时 env 后，再确认仓库、日志、evidence 无敏感值。不得为 cleanup 触碰其他项目、Production 或 54321–54324。
- 当前只允许本地 code-only 文档/合同工作；不运行 Supabase/hosted Auth，不发真实邮件，不生成任何 admin key。

## 6. Owner exact phrase

以下五条是五个分项的 action-time Owner phrase **模板，当前全部未批准**。每条只能打开对应分项；缺少其中任一句，E5 umbrella 仍 NO-GO：

> 批准 E5-LINK：仅连接 Owner 指定的一个 non-production hosted Auth project；目标、组织、区域、费用、最小权限、server-only secret 注入、provider token 检查、撤销和 cleanup 均按本 Gate 记录执行，不连接 Production 或其他项目。

> 批准 E5-CALLBACK：仅为已批准的 non-production hosted Auth project 使用固定 HTTPS origin/Host/path 与唯一 redirect allowlist；先通过 signup containment、state/nonce/PKCE/replay 和 provider token 不持久化合同，受监督验证后回退并 cleanup。

> 批准 E5-HOSTED-AUTH：仅修改 Owner 指定 hosted Auth project 的一个明确设置；signup containment 先有证据，记录设置前后、影响、回退和 cleanup，不启用其他 provider、invite、linking、SMTP、DB、Storage 或 Production 能力。

> 批准 E5-INVITE：仅在指定 non-production/sandbox 中使用一次性 trusted admin context 和 @rebuy.test synthetic mailbox 验证 provider invite primitive；不公开或持久化 admin key，不发送真实邮件，不将 provider invite 解释为 Rebuy membership invite。

> 批准 E5-CUSTOM-SMTP：仅在指定 non-production sandbox 配置一次可回退的 custom SMTP 与 synthetic catcher；不使用真实 PII/Production/默认 SMTP 作为 Mailpit 证据，secret 仅 owner-only 受控注入，测试后删除并确认无外发。

## 7. 官方来源

- [Supabase Login with Google](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Supabase Login with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Supabase social login](https://supabase.com/docs/guides/auth/social-login)
- [Supabase Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls)
- [Supabase Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
- [Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits)
- [Supabase inviteUserByEmail reference](https://supabase.com/docs/reference/javascript/auth-admin-inviteuserbyemail)
- [Supabase sessions](https://supabase.com/docs/guides/auth/sessions)

官方来源用于 action-time 复核，不构成任何 hosted/provider 授权；每一分项必须以 exact phrase、最小证据和 cleanup 单独关闭。
