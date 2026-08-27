# G2-A1 Auth Spike 准备与资源门禁

文档状态：**G2-A1 技术阶段未开始；无资源 Entry preparation 已完成/待审；resource/cost/secret Gate 关闭**
记录日期：2026-08-28（Europe/Rome）
证据级别：规划 + 本地静态（docs-only）；不代表 Auth、Staging、数据库或生产能力
前置阶段：G2-A0 Exit GO，远端 docs-only reconciliation 已完成，事实见[本批 Entry preparation 证据](../evidence/G2-A1/2026-08-28-entry-preparation/README.md)

## 1. 本批声明与边界

本文件记录 G2-A1 的无资源 Entry preparation。它完成了后续执行合同、资源/费用/密钥 Gate 字段、Auth 实测矩阵和公开证据边界的准备；**没有开始 G2-A1 技术验证**。当前不创建或连接 Supabase 项目，不连接 Auth/DB/Storage/OAuth/SMTP，不读取或写入 secret，不创建真实账号或 fixture，不部署、不改变 Production，也不修改已冻结的 G0/P1 UI、prototype、workflow、package 或 lockfile。

G2-A0 的远端闭环已经在 `main` 完成：PR #7 的 merge commit 为 `fd9b712c7b07bf34399f9838eebb75846425c1d1`，parents 为 `7ea1e45ad22ab29105910665baf4bbd7212241c5` 与 `1433e7c7c141df0f5498fff7cd645a8d5c92340c`。这只证明已批准的 G2-A0 docs-only 变更完成远端闭环，不把 A1 变成技术通过。

本批可以做的事情限于：维护 Markdown 合同、填写脱敏字段说明、定义 `.invalid` 合成样例、核对链接和静态敏感信息边界。只有新的 resource/cost/secret Gate 明确通过后，才可进入 A1 的独立环境执行；“无需重复批准”不扩大为未来付费资源、真实 PII、Auth/DB 或 Production 的豁免。

## 2. Entry 状态与下一 Gate

| Gate | 当前状态 | 允许动作 | 不能据此声称 |
|---|---|---|---|
| G2-A0 Exit | 已通过；远端 reconciliation 已完成 | 进入 A1 无资源准备 | Supabase/Auth/DB/Storage 已连接 |
| G2-A1 无资源 Entry preparation | 已完成/待审 | 文档、接口草图、测试矩阵、合成字段定义 | A1 技术验证开始或通过 |
| resource/cost/secret Gate | **关闭** | 仅维护[资源成本与密钥 Gate 模板](../templates/G2-A1-资源成本与密钥Gate模板.md) | 组织、项目、套餐、区域、费用或密钥已批准 |
| G2-A1 技术阶段 | **未开始** | 等待独立资源授权后按四批合同执行 | Staging、真实登录、Auth/MFA、DB/RLS 或生产验收 |

推荐的后续入口顺序是：先完成本文件和模板的 Owner/安全复核；再由 Owner 另行确认 provider、组织、项目、计划、区域、环境、成本上限、密钥责任人与停止联系人；最后才可打开资源 Gate。A1 结果不能自动打开 P2/P3+，A0–A6 与 P0–P8 的映射仍需在 P2 之前由 Owner/主计划明确。

## 3. 四批后续执行合同

四批均必须在资源 Gate 通过后、独立 non-production 环境内使用合成数据执行。每批开始前重新核对 provider 文档、版本、项目隔离、费用边界和证据位置；任一前置条件消失即停止。

### A1-B1｜环境预检

目的：证明测试项目、区域、计划、域名、redirect、SMTP、Storage、OAuth client、密钥和日志边界与 Production 分离，并记录实际版本与配置摘要。

最小范围：

- 记录 provider、组织、project、plan、region、environment、SDK/CLI 版本、测试域名和 redirect allowlist；不记录 host、密钥或原始配置值。
- 核对项目 owner/成本责任、Spend Cap、add-on、税费处理、预算/停机联系人、到期清理时间和回退路径。
- 仅使用合成账号、虚构组织和 `.invalid` 邮箱；local 可用 SMTP catcher 或合成发送器，preview-staging 只能使用专用测试 SMTP。
- 若存在生产 client、生产 redirect、真实 SMTP、真实 PII、无法证明的日志/Storage 隔离或未授权费用，立即 STOP。

输出：环境隔离表、成本/secret Gate 完整字段、只读配置摘要、停止/回退记录；不产生 Auth 运行证据。

### A1-B2｜三入口与 callback

目的：在隔离环境实测 Apple、Google、email OTP 三个等价入口，Magic Link 作为邮箱兼容/后备路径，并验证 callback 的安全绑定。

最小范围：

- Apple：relay/隐藏邮箱、首次姓名缺失、取消、重复登录和错误响应。
- Google：只请求 `openid`、`email`、`profile`；额外 scope、provider token 落地或泄露立即 STOP。
- email OTP/Magic Link：TTL、重发、错误次数、重放、跨会话、换设备、反枚举和限流。
- 每个 OAuth callback 验证环境/provider/client/redirect、PKCE、`state`、`nonce`、code 一次性、相对 `next` allowlist 和 open redirect 防护；OAuth token endpoint 只接受成功的 2xx，不硬编码 `201`。
- 验证三入口只建立 identity/session，不直接创建 membership、角色、商家批准、资格或业务订单。

输出：脱敏入口/失败矩阵、callback 时间线、linking 前置结论和日志/Network/缓存扫描；不在本阶段自动决定 provider。

### A1-B3｜MFA、session 与恢复

目的：验证 Owner 已采纳的 TOTP、AAL2、会话和恢复边界；V1 排除 phone/SMS MFA 与静态恢复码。

最小范围：

- 主 TOTP enrollment/challenge/verify/unenroll、AAL2 提升、错误/重试/限流/通知。
- 第二个 TOTP 备用因子必须位于不同设备或安全位置；禁止把同设备、静态恢复码或未验证的界面标签当作备用因子。
- 人工恢复必须有身份核验、独立 reviewer/安全负责人批准、AAL/会话重置、通知和追加式审计；support 不得单人批准或解除 MFA。六类高风险动作继续双人复核且禁止自审。
- 实测 `signOut` 的 `local`、`global`、`others`，`session_id`/token `exp` 窗口、刷新延迟、并发请求、SSR 每请求新 client、cookie refresh 和跨用户串线负向。
- 不承诺 access token 即时失效、设备列表或单设备撤销；这些能力必须由实际版本和权限证据证明。

输出：AAL2/因子/恢复/会话矩阵、职责分离记录、时间线和通知/审计摘要；任何 token、TOTP seed、OTP、cookie 或密钥原值均不得进入证据。

### A1-B4｜证据 closeout

目的：将 A1 实测结果整理为可复核、最小化、可回退的证据包，并由 Owner 决定是否打开后续阶段。

最小范围：

- 使用[Auth 实测矩阵模板](../templates/G2-A1-Auth实测矩阵模板.md)逐项填入 observed、结果、证据路径、版本和观察窗口；未验证项明确写为后置。
- 完成 DB/log/cache/Network/客户端 bundle 的 secret/PII 扫描，只保留结果分类和脱敏摘要；不得保存原始 OAuth 材料、OTP、TOTP seed、SMTP/服务密钥、真实邮箱或真实 PII。
- 记录 provider/plan/region/session 的实际限制、失败/停止/清理、回退和残余风险；把 plan、区域和 session 的选择与实测证据绑定，不从通用价格或文档默认值推断。
- 由独立安全审查与 Owner Gate 复核后，才可判断 A1 是否通过；A1 通过也不自动打开 P2/P3+、Production、支付或法律/税务范围。

输出：证据 README、实测矩阵、环境隔离摘要、失败/回退记录、Owner 决定；本批之前不预写任何 run、deployment、provider 结果或技术通过声明。

## 4. Owner、成本、密钥与停止责任字段

以下字段是 Entry preparation 的最小责任合同。`待指定` 是未决状态，不是默认授权；资源 Gate 通过前不得以空值或历史账号推断责任人。

| 责任字段 | 当前值 | 资源 Gate 通过前的要求 |
|---|---|---|
| Product/项目 Owner | 待指定（Owner） | 明确本次 A1 范围、验收人和停止权限 |
| 技术执行负责人 | 待指定 | 只能在 Gate 通过后操作独立 non-production；不得单人扩大范围 |
| 独立安全审查人 | 待指定 | 审查 callback、MFA、session、恢复、日志和隔离负向 |
| provider/项目管理员 | 待指定 | 证明组织、project、plan、region 和 Production 隔离；不得复用既有无关项目 |
| 成本责任人 | 待指定 | 接收 provider exact cost、税费、recurrence、Spend Cap 和 stop 触发；用户确认后才可产生费用 |
| secret/key owner | 待指定 | 管理 OAuth/SMTP/服务端密钥；只提供 secret 名称/摘要，不把原值交给文档或客户端 |
| 回调/SMTP/Storage 责任人 | 待指定 | 分别记录 redirect、邮件捕获和文件边界；默认关闭 Storage，禁止真实邮件/文件 |
| 证据保管人 | 待指定 | 管理脱敏证据、访问控制、保存期限和销毁记录 |
| 停止联系人 | 待指定 | 一旦越界，立即冻结入口、撤销测试配置并通知 Owner |
| 法律/隐私/税务顾问 | A5/专业顾问待接手 | 不在 A1 对 GDPR、税务、跨境或处理者合同作结论 |

## 5. 公开 Supabase inventory 摘要与候选提案

本批只允许记录经过脱敏的公开摘要：**连接账户有 1 个 Pro 组织、2 个与 Rebuy 无关的 active projects、没有 Rebuy 项目。** 不记录组织名、项目名、项目 ID、host、现有项目 region、key、token 或环境值。既有两个项目严禁复用或连接。

候选仅为 proposal，未获得组织确认、exact cost 和独立资源 Gate 通过前不得创建：

> 现有 Pro 组织内新建独立 Rebuy non-production project；候选精确区域为 `eu-central-1`（Frankfurt）；开启 Spend Cap；不启用 add-on；只使用 synthetic-only 数据。

该提案不等同于已选 provider、已选套餐、已确定成本或已创建项目。精确费用只能在指定组织后，由 provider 的 `get_cost` 获取并记录 recurrence、税费和 spend cap，再由 Owner 明确确认；禁止从通用价格页推断本项目 exact cost。

## 6. 2026-08-28 官方来源刷新（只作为规划依据）

以下来源均为 Supabase 官方页面。它们用于在 A1 开始前刷新合同，不代表本地仓库已实现这些能力；实施当天仍需按实际版本、区域和配置复核。

| 官方来源 | 2026-08-28 记录的事实 | 对 A1 的约束 |
|---|---|---|
| [Node.js 20 support changelog](https://supabase.com/changelog/45715-deprecation-notice-dropping-support-for-node-js-20) | Supabase client libraries 的 Node 20 支持已于 2026-06-30 结束；仓库 Node 22 符合该运行时门槛 | 不修改本批 Node/config；执行日重新核对 SDK/Node 版本 |
| [OAuth token endpoint breaking change](https://supabase.com/changelog/45468-breaking-change-oauth-token-endpoint-will-return-http-200-instead-of-201) | `/v1/oauth/token` 自 2026-06-01 起成功响应为 HTTP 200；客户端应接受任意成功 2xx，不硬编码 201 | B2 callback 测试必须包含 2xx 兼容性 |
| [Data API exposure breaking change](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically) | 新表默认可能不自动暴露给 Data/GraphQL API；grants 控制对象可达性，RLS 控制行级可见性，二者分离 | A1 只做最小 reachability 观察；完整 grants/RLS 归 A3/A4 |
| [Free-tier email template change](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier) | 新 Free 项目使用默认 SMTP 时，认证邮件模板自定义受限；Pro 或配置自有 SMTP 的项目不受该限制 | B1 必须记录 plan/SMTP 事实；不发送真实邮件 |
| [Available regions](https://supabase.com/docs/guides/platform/regions) | 精确 EU 候选为 `eu-central-1` Frankfurt；region 是数据位置控制，不等于 GDPR 合规证明 | 区域与合规法律判断分离，GDPR 转 A5/专业顾问 |
| [Control your costs](https://supabase.com/docs/guides/platform/cost-control) | Spend Cap 仅适用于 Pro；它不是细粒度预算或告警系统；超 quota 时会限制被覆盖的 usage item | Gate 必须记录 cap 状态、覆盖范围和 stop 联系人 |
| [Billing FAQ](https://supabase.com/docs/guides/platform/billing-faq) | Pro 的超额、税费和组织账单需按实际组织/账单地址计算；通用价格不能替代本项目 exact cost | 先指定组织，再取 exact quote/recurrence/tax 并由 Owner 确认 |
| [MFA guide](https://supabase.com/docs/guides/auth/auth-mfa) / [TOTP guide](https://supabase.com/docs/guides/auth/auth-mfa/totp) | Auth 支持 App Authenticator/TOTP 与 phone factor；TOTP 可通过 enrollment/challenge/verify 形成 AAL2 | Owner 已排除 phone/SMS 与静态恢复码；B3 只按 TOTP/人工恢复合同实测 |
| [Signing out](https://supabase.com/docs/guides/auth/signout) | `local`、`global`、`others` 具有不同退出范围；撤销 session 的 access token 仍可能在 `exp` 前有效 | B3 必须记录退出语义和 token 窗口，不承诺即时失效 |
| [User sessions](https://supabase.com/docs/guides/auth/sessions) | session lifetime 与 single-session per user 只在 Pro 及以上可配置；刷新时才逐步执行设置 | B3 记录计划、配置和观察窗口，不能把默认值写成承诺 |

## 7. 停止条件、回退与证据边界

出现以下任一情况，停止当前批次，不用绕过方式继续：

- resource/cost/secret Gate 未明确通过却需要创建项目、读取密钥、启用 OAuth/SMTP/Storage 或产生费用；无法证明组织、项目、区域和 Production 隔离。
- 任何真实邮箱、电话、地址、客户/商家资料、证件、订单、真实支付信息、生产 cookie、token、OTP、TOTP seed、OAuth code、SMTP/service key 或原始日志进入仓库、聊天、截图、客户端、数据库或证据。
- callback 接受错误/重放 code、错误 PKCE/state/nonce、跨环境 client、open redirect、额外 Google scope 或 provider token 留存。
- linking/邀请在邮箱控制权、重新认证、目标精确匹配或并发/一次性消费未通过时仍产生 membership/权限；人工恢复缺少双人职责分离、AAL/会话重置、通知或审计。
- SSR/cookie/缓存出现跨用户串线；`auth.sessions` 授权边界不清；把 access token 失效误报为即时；日志/DB/cache/Network 扫描无法证明无秘密原值。

无资源阶段的回退：仅回退本批 docs-only commit，或追加带日期的纠正记录；不使用 force/reset，不修改 G0/P1、代码、依赖、workflow、外部资源或生产。将来资源阶段的清理必须遵循 Gate 模板中的 expiry/cleanup 字段，并保留无秘密的审计摘要。

本文件、证据 README 和模板均不是运行时证据。若实际 A1 未执行，统一写“未开始/未验证”；若官方事实或 provider 配置漂移，先追加日期化纠正，再决定是否重跑。

## 8. 本批文件与复核入口

- [G2-A1 Entry preparation 证据](../evidence/G2-A1/2026-08-28-entry-preparation/README.md)
- [G2-A1 资源成本与密钥 Gate 模板](../templates/G2-A1-资源成本与密钥Gate模板.md)
- [G2-A1 Auth 实测矩阵模板](../templates/G2-A1-Auth实测矩阵模板.md)
- [A1 Auth Spike 执行合同](../10-A1-Auth-Spike执行合同.md)
- [发布与 Supabase 连接记录](../11-发布与Supabase连接记录.md)
- [G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)
- [项目状态与阶段台账](../15-项目状态与阶段台账.md)

Owner/安全审查通过后，15 台账可以把 G2-A1 记录为“准备中（无资源 Entry preparation 已完成/待审）”，但技术阶段仍必须保持“未开始”，直到新的 resource/cost/secret Gate 明确通过。
