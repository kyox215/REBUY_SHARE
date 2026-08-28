# G2-A1 Auth Spike 准备与资源门禁

文档状态：**G2-A1 技术阶段未开始；独立安全复审已完成、首轮 finding 已关闭；Owner/主代理批准打开 A1-B1 最小技术范围（已授权/待执行）；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 关闭**
记录日期：2026-08-28（Europe/Rome）
证据级别：规划 + 外部资源存在性核验 + 本地静态（docs-only）；不代表 Auth、Staging、数据库或生产能力
前置阶段：G2-A0 Exit GO，远端 docs-only reconciliation 已完成，事实见[本批 Entry preparation 证据](../evidence/G2-A1/2026-08-28-entry-preparation/README.md)

## 1. 本批声明与边界

本文件先记录 G2-A1 的无资源 Entry preparation：它完成了后续执行合同、资源/费用/密钥 Gate 字段、Auth 实测矩阵和公开证据边界的准备。2026-08-28 随后只完成了独立 Free Supabase 资源的管理面存在性/基础健康预检；**G2-A1 Auth 技术验证仍未开始**。本批新增了“最小 Auth spike 风险 Gate”设计和复用优先预检；独立安全复审已完成且首轮 finding 已关闭，Owner/主代理仅批准 A1-B1 最小技术范围，当前仍是“已授权/待执行”，不能写成 G2-A1 Auth/B1 技术通过。当前项目尚未接入 Auth/DB/Storage/OAuth/SMTP，不读取或写入 secret，不创建真实账号或 fixture，不部署、不改变 Production，也不修改已冻结的 G0/P1 UI、prototype、workflow、package 或 lockfile。

G2-A0 的远端闭环已经在 `main` 完成：PR #7 的 merge commit 为 `fd9b712c7b07bf34399f9838eebb75846425c1d1`，parents 为 `7ea1e45ad22ab29105910665baf4bbd7212241c5` 与 `1433e7c7c141df0f5498fff7cd645a8d5c92340c`。这只证明已批准的 G2-A0 docs-only 变更完成远端闭环，不把 A1 变成技术通过。

本批可以做的事情限于：维护 Markdown 合同、填写脱敏字段说明、定义 `.invalid` 合成样例、核对链接和静态敏感信息边界。只有新的 resource/cost/secret Gate 明确通过后，才可进入 A1 的独立环境执行；“无需重复批准”不扩大为未来付费资源、真实 PII、Auth/DB 或 Production 的豁免。

## 2. Entry 状态与下一 Gate

| Gate | 当前状态 | 允许动作 | 不能据此声称 |
|---|---|---|---|
| G2-A0 Exit | 已通过；远端 reconciliation 已完成 | 进入 A1 无资源准备 | Supabase/Auth/DB/Storage 已连接 |
| G2-A1 无资源 Entry preparation | 已完成/已归档 | 文档、接口草图、测试矩阵、合成字段定义 | A1 技术验证开始或通过 |
| G2-A1 最小资源存在性/基础预检 | **已完成（窄范围）** | 核对独立组织、Free 项目、区域、报价确认和健康状态 | Auth、secret/env、DB/RLS、Storage、OAuth、SMTP 或生产能力 |
| G2-A1 最小 Auth spike 风险 Gate | **已授权/待执行** | 独立安全复审已完成、首轮 finding 已关闭；仅可按 B1 最小动作只读取得 project URL + modern publishable key，写入 gitignored local env，复用/定向扩展现有 SSR/client/health 做 EU non-production synthetic-only 连接验证，并记录 Free 限制、STOP/cleanup | 当前不连接 Auth，不启用 OAuth/SMTP/Storage，不建表/写数据；不使用 secret/service_role/secret key/db password |
| 完整 resource/cost/secret Gate | **关闭** | 仅允许维护[资源成本与密钥 Gate 模板](../templates/G2-A1-资源成本与密钥Gate模板.md)及窄范围资源预检 | secret、环境变量、Auth/DB/Storage/OAuth/SMTP 或任何付费/生产能力已批准 |
| G2-A1 技术阶段 | **未开始** | A1-B1 最小技术范围已获授权但待执行；下一步按该窄范围进行 B1 复用/连接验证 | Staging、真实登录、Auth/MFA、DB/RLS 或生产验收 |

当前已完成资源存在性/基础预检，独立安全复审已完成且首轮 finding 已关闭；Owner/主代理批准打开 A1-B1 最小技术范围，当前为“已授权/待执行”。该批准不是 broad waiver（全局豁免），也不表示 G2-A1 Auth/B1 技术通过。Free 计划的能力不能被推断为已满足 Pro 专属的 session 配置要求。完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 仍关闭，service_role、secret key、db password 继续禁止，A1 结果不能自动打开 P2/P3+，A0–A6 与 P0–P8 的映射仍需在 P2 之前由 Owner/主计划明确。

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
| 成本责任人 | 待指定 | 接收 provider `get_cost` 实际返回的 amount/recurrence；另行核对 tax/VAT/billing-address effect，并只读核验 organization-level Spend Cap 状态/覆盖范围；Owner 确认后才可产生费用 |
| secret/key owner | 待指定 | 管理 OAuth/SMTP/服务端密钥；只提供 secret 名称/摘要，不把原值交给文档或客户端 |
| 回调/SMTP/Storage 责任人 | 待指定 | 分别记录 redirect、邮件捕获和文件边界；默认关闭 Storage，禁止真实邮件/文件 |
| 证据保管人 | 待指定 | 管理脱敏证据、访问控制、保存期限和销毁记录 |
| 停止联系人 | 待指定 | 一旦越界，立即冻结入口、撤销测试配置并通知 Owner |
| 法律/隐私/税务顾问 | A5/专业顾问待接手 | 不在 A1 对 GDPR、税务、跨境或处理者合同作结论 |

## 5. 公开 Supabase inventory 摘要与候选提案（无资源阶段历史快照）

本批只允许记录最小化公开摘要：**只读 inventory 没有发现已获批准、可用于 Rebuy 的独立 non-production project；任何无关项目禁止复用。** 本批不公开任何 Supabase inventory 的组织/项目名称、ID、数量、套餐、host 或现有 region；也不记录 key、token 或环境值。

候选仅为 proposal，未获得 Owner 明确选择的 organization、resource scope、exact cost 和独立资源 Gate 通过前不得创建：

> 在 Owner 明确选择的 organization 内新建独立 Rebuy non-production project；计划须支持 A1 必测能力（session lifetime/single-session 因官方限制需 Pro 或更高）；候选精确区域为 `eu-central-1`（Frankfurt）；组织级 Spend Cap 状态必须另行只读核验；不启用 add-on；只使用 synthetic-only 数据。

该提案不等同于已选 provider、已选 organization、已选套餐、已确定成本或已创建项目。准确流程是：用户先明确选择 organization + resource scope；provider `get_cost` 返回并确认其实际提供的 amount/recurrence；tax/VAT/billing-address effect 另由 billing page/专业顾问核对；Spend Cap 是 organization-level 设置，另行只读核验其状态和覆盖范围；三项均完成并由 Owner 明确确认后才可创建。禁止从通用价格页推断本项目 exact cost。

## 6. 2026-08-28 官方来源刷新（只作为规划依据）

以下来源均为 Supabase 官方页面。它们用于在 A1 开始前刷新合同，不代表本地仓库已实现这些能力；实施当天仍需按实际版本、区域和配置复核。

| 官方来源 | 2026-08-28 记录的事实 | 对 A1 的约束 |
|---|---|---|
| [Node.js 20 support changelog](https://supabase.com/changelog/45715-deprecation-notice-dropping-support-for-node-js-20) | Supabase client libraries 的 Node 20 支持已于 2026-06-30 结束；仓库 Node 22 符合该运行时门槛 | 不修改本批 Node/config；执行日重新核对 SDK/Node 版本 |
| [OAuth token endpoint breaking change](https://supabase.com/changelog/45468-breaking-change-oauth-token-endpoint-will-return-http-200-instead-of-201) | `/v1/oauth/token` 自 2026-06-01 起成功响应为 HTTP 200；客户端应接受任意成功 2xx，不硬编码 201 | B2 callback 测试必须包含 2xx 兼容性 |
| [Data API exposure breaking change](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically) | 新表默认可能不自动暴露给 Data/GraphQL API；grants 控制对象可达性，RLS 控制行级可见性，二者分离 | A1 只做最小 reachability 观察；完整 grants/RLS 归 A3/A4 |
| [Free-tier email template change](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier) | 新 Free 项目使用默认 SMTP 时，认证邮件模板自定义受限；Pro 或配置自有 SMTP 的项目不受该限制 | B1 必须记录 plan/SMTP 事实；不发送真实邮件 |
| [Available regions](https://supabase.com/docs/guides/platform/regions) | 精确 EU 候选为 `eu-central-1` Frankfurt；region 是数据位置控制，不等于 GDPR 合规证明 | 区域与合规法律判断分离，GDPR 转 A5/专业顾问 |
| [Control your costs](https://supabase.com/docs/guides/platform/cost-control) | Spend Cap 是 organization-level 设置，仅适用于 Pro；它不是细粒度预算或告警系统；超 quota 时会限制被覆盖的 usage item | 单独只读核验 cap 状态与覆盖范围，记录 stop 联系人 |
| [Billing FAQ](https://supabase.com/docs/guides/platform/billing-faq) | provider `get_cost` 的 amount/recurrence 与账单税费不是同一返回值；tax/VAT/billing-address effect 依实际账单和专业意见核对 | 用户先选 organization + resource scope，再取并确认 `get_cost` 实际返回值；税费另核对 |
| [MFA guide](https://supabase.com/docs/guides/auth/auth-mfa) / [TOTP guide](https://supabase.com/docs/guides/auth/auth-mfa/totp) | Auth 支持 App Authenticator/TOTP 与 phone factor；TOTP 可通过 enrollment/challenge/verify 形成 AAL2 | Owner 已排除 phone/SMS 与静态恢复码；B3 只按 TOTP/人工恢复合同实测 |
| [Signing out](https://supabase.com/docs/guides/auth/signout) | `local`、`global`、`others` 具有不同退出范围；撤销 session 的 access token 仍可能在 `exp` 前有效 | B3 必须记录退出语义和 token 窗口，不承诺即时失效 |
| [User sessions](https://supabase.com/docs/guides/auth/sessions) | session lifetime 与 single-session per user 只在 Pro 及以上可配置；刷新时才逐步执行设置 | B3 记录计划、配置和观察窗口，不能把默认值写成承诺 |

## 7. 停止条件、回退与证据边界

出现以下任一情况，停止当前批次，不用绕过方式继续：

- 超出本记录第 9 节窄范围、在完整 resource/cost/secret Gate 未明确通过时需要读取密钥、启用 OAuth/SMTP/Storage、写入数据或产生费用；无法证明组织、项目、区域和 Production 隔离。
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

当前 15 台账已记录为“准备中（最小资源存在性/基础预检已完成）”；技术阶段仍必须保持“未开始”，独立安全复审已完成且首轮 finding 已关闭，Owner/主代理批准打开 A1-B1 最小技术范围，当前为“已授权/待执行”。完整 resource/cost/secret Gate 仍关闭；下一步执行 B1 最小范围，不扩大到完整 Auth/资源或 Production。

## 9. 2026-08-28｜Free Supabase 资源存在性与基础预检（窄 Gate）

记录类型：外部资源管理面核验；不是 Auth 运行时证据，也不是完整 resource/cost/secret Gate 批准。

- 独立 Supabase 组织 `Rebuy Lab` 已创建；Supabase connector 只读核验该组织 `plan=Free`。
- 独立项目 `rebuy-auth-spike` 已在 `eu-central-1`（Frankfurt）创建；用途限定为 EU non-production Auth spike，数据模式为 synthetic-only。
- provider project quote 已返回 `amount=0`、`recurrence=monthly`；该 API 未返回 currency。Owner 已确认该实际 quote，随后已完成 `confirm_cost`。此记录不把 quote 当作税费、Spend Cap 或完整成本责任确认。
- 项目当前管理面状态为 `ACTIVE_HEALTHY`。健康状态只证明资源存在且 provider 管理面报告健康，不等于 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 验证通过。
- 本批没有读取、记录或传播 secrets、keys、passwords、环境变量值、host、URL、project ref、组织/项目 ID 或其他账号资源标识；没有配置 Auth/DB/Storage/OAuth/SMTP，没有建表、写数据、创建真实账号、部署、promote、alias 或 Production 操作。

| Gate | 当前状态 | 允许范围 | 明确关闭 |
|---|---|---|---|
| 最小资源存在性/基础预检 | **已打开并完成（窄范围）** | 组织/Free 计划、项目名称、区域、quote 确认、管理面健康状态 | 不延伸为运行时/Auth/DB 证据 |
| 完整 resource/cost/secret Gate | **关闭** | 仅维护脱敏记录和新的风险 Gate 设计 | secret/env、成本责任/税费/Spend Cap 完整确认、Auth/DB/Storage/OAuth/SMTP |
| 真实数据与 Production | **关闭** | 无 | 真实客户/商户/PII、真实账号、部署、Production/promote/写入 |

独立安全复审已完成且首轮 finding 已关闭；Owner/主代理已批准 A1-B1 最小技术范围，当前为“已授权/待执行”。该批准不是 broad waiver；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续关闭，service_role、secret key、db password 继续禁止。执行前仍不得把 `ACTIVE_HEALTHY` 外推为技术通过。

## 10. 2026-08-28｜A1-B1 最小 Auth spike 风险 Gate 与复用优先预检

本批执行级别为**关键**：范围涉及认证、密钥、隐私和外部 non-production 资源；执行代理档位为 `luna_worker / max`；默认一个执行代理。独立安全复审已完成且首轮 finding 已关闭，Owner/主代理批准打开 A1-B1 最小技术范围。本节是风险 Gate 与复用预检记录，不是技术执行结果，不代表 G2-A1 Auth/B1 已通过，也不打开完整 resource/cost/secret/Auth/DB Gate。

### 10.1 Gate 决定与最小授权范围

| 项目 | 本批决定 |
|---|---|
| Gate 状态 | **A1-B1 最小技术范围已授权/待执行**；独立安全复审已完成、首轮 finding 已关闭；不代表 G2-A1 Auth/B1 技术通过 |
| 目标资源 | Supabase 组织 `Rebuy Lab`（Free）；项目 `rebuy-auth-spike`；`eu-central-1`（Frankfurt）；仅 EU non-production、synthetic-only |
| 已核验成本事实 | provider project quote 返回 `amount=0`、`recurrence=monthly`；API 未返回 currency；Owner 已确认该实际 quote 并完成 `confirm_cost` |
| 成本边界 | 不授权任何非零费用、add-on、upgrade、自定义 SMTP 或其他付费能力；tax/VAT/billing-address effect、Spend Cap 状态/覆盖范围和完整成本责任仍待另行只读核验 |
| 管理面事实 | `ACTIVE_HEALTHY`；只证明资源存在且管理面健康，不证明 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 通过 |
| 当前阶段 | G2-A1 技术阶段仍未开始；没有真实账号、真实 PII、Auth/DB/Storage/OAuth/SMTP 配置或运行时证据 |
| 下一批可申请动作 | 复核当前官方 docs/changelog；只读取得 project URL + modern publishable key；确认 `.gitignore` 阻止 env；复用/扩展现有 SSR client 与 health route；在 EU non-production local synthetic-only 连接中验证不依赖 service_role；记录 Free limitations 与 STOP/cleanup |
| 密钥保存边界 | project URL 与 modern publishable key 仅可进入 gitignored local env 或受控 Preview env；本仓库、证据、聊天、日志、截图和客户端 bundle 不保存原值；不得读取或使用 secret/service_role/secret key/db password |
| 明确未授权 | 不配置 Auth/OAuth/SMTP，不建表/写数据，不启用 Storage，不创建真实账号/fixture，不部署、promote、alias、Production 或 Supabase 生产资源 |

上述“下一批可申请动作”现为已授权但待执行的 B1 最小动作清单，不是 broad waiver，也不等于 G2-A1 Auth/B1 技术通过。任何实际连接成功、配置成功或技术通过都必须在后续批次以实时证据记录；本节不预写结果。

### 10.2 责任与停止合同

| 责任项 | 当前指定 | 边界 |
|---|---|---|
| Product / cost / stop / provider admin | Hexiang Huang | 负责范围、费用确认、provider 管理面与立即停止；不得以“无需重复批准”扩大到付费、真实 PII 或 Production |
| 技术执行 | Codex 自动化执行（后续由 `luna_worker / max` 按批次执行） | 只执行明确的 non-production 最小动作；Owner 保留最终责任和停止权；不得自行扩大范围 |
| 独立安全复审 | 首轮独立只读 Codex reviewer 结论为 NO-GO；实现代理修复状态 finding，主代理只读核对精确 diff 后关闭 finding；Owner/主代理当前批准继续 | 本授权仍只覆盖 B1 最小动作；不扩大到完整资源、Auth/DB/Storage/OAuth/SMTP 或 Production |
| secret/key owner | Hexiang Huang | 原值只允许存在 provider/Vercel secret store 或 gitignored local env；证据只写名称/引用/不可逆摘要，不写原值 |
| 证据保管 | 仓库脱敏摘要 + provider 审计记录 | 不保存 secret、URL/host/ref/ID、cookie、token、OTP、TOTP seed 或真实 PII；阶段事实仍以 15 台账为唯一当前状态源 |
| 法律 / 隐私 / 税务 | A5 / 专业顾问待处理 | 不在 A1 对 GDPR、税务、跨境或处理者合同作结论 |

### 10.3 复用优先预检结论

本批先以 `rg` 定向检查既有实现，再决定复用/扩展/新建；没有代码写入。

| 目标能力 | 现有证据 | 本批结论 |
|---|---|---|
| 浏览器 Supabase client | `prototype/lib/supabase/client.ts` 已存在，使用 `createBrowserClient` 与统一配置读取 | **复用**；后续只在需要时扩展，不新建第二个浏览器 client |
| SSR Supabase client | `prototype/lib/supabase/server.ts` 已存在，按调用创建 `createServerClient`，读取 request cookies，并保留受控 cookie 写回 | **复用/定向扩展**；B1 仅核验每请求创建、未配置处理与未来 Proxy 边界，不重复新建 factory |
| 配置与 env 名称 | `prototype/lib/supabase/config.ts` 与 `prototype/.env.example` 已统一为 `NEXT_PUBLIC_SUPABASE_URL`、`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`，缺失/非法配置会受控失败 | **复用**；只读取得值后写入 gitignored local env，不新增别名或 secret env |
| Supabase health | `prototype/app/api/health/supabase/route.ts` 已请求 `/auth/v1/settings`，固定最小 JSON、`no-store`、503/502/200 分支，不返回 URL/key/堆栈 | **复用/定向扩展**；B1 验证配置缺失、独立项目可达与错误脱敏，不把 health 200 当作 Auth 通过 |
| Auth UI/handlers | `prototype/app/account/login/LoginPrototype.tsx` 是明确的本地演示，Apple/Google 与邮箱 OTP 仅写“等待 A1/界面演示”，不创建会话 | **复用现有演示边界**；B1 不把 UI 点击改写为真实 Auth，不新建业务 handler |
| 类型、测试与业务 domain | 本批定向扫描未发现 Supabase Auth 业务 hooks/types 或可复用真实登录测试；未发现 `prototype` 下独立 test/spec 目录 | **暂不新建**；待 B1 复核最小需求后，由执行代理提出最小扩展并单独评估文件边界 |
| 依赖与工具链 | `prototype/package.json` 已固定 `@supabase/ssr=0.12.5`、`@supabase/supabase-js=2.112.4`，Node `22.x`、pnpm `10.33.3` | **复用**；B1 记录运行版本，未经新授权不改依赖、lockfile 或配置 |

预检选择为“复用现有 client/config/SSR/health；必要时在原文件内定向扩展；暂不新建 Auth 业务 handler、hooks、types 或测试套件”。该选择不证明现有骨架已经安全连接或已通过 A1。

### 10.4 B1 最小验收与停止条件

在独立安全复审完成、首轮 finding 关闭且 Owner/主代理批准后，B1 已获最小范围授权但仍待执行；按下列最小证据顺序执行：

1. 重新核对 Supabase 官方 docs/changelog、Node/SDK 版本和 Free 计划限制，记录日期与版本；不从本节推断 Pro 专属 session 能力。
2. 只读取得 project URL + modern publishable key；确认仓库 `.gitignore` 阻止 env；仅写入 gitignored local env 或受控 Preview env，并以 secret scan/文件状态证明未入仓库。
3. 复用现有 browser/SSR client 与 `/api/health/supabase`；验证 local synthetic-only 连接只使用 publishable key，不依赖或读取 service_role、secret key、DB password。
4. 记录配置缺失、远端不可达、非 2xx、可达等脱敏结果；health/管理面结果不得写成 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或生产通过。
5. 记录 Free limitations、测试期限、STOP 联系人、expiry/cleanup/回退路径；不启用 Auth/OAuth/SMTP/Storage，不建表、不写数据、不创建真实账号。

任一真实 PII/secret、Production 连接、非零费用、生产 redirect/SMTP、service_role 依赖、环境串线、日志/Network/bundle 泄露或无法清理，立即停止并保留脱敏失败摘要；不得用绕过方式继续。B1 仍不自动打开 B2/B3、P2 或 Production。

### 10.5 本批证据入口

本批复用预检和风险 Gate 的脱敏证据见[2026-08-28 B1 风险 Gate 证据](../evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)。证据 README 只记录批次事实、复用结论和验证结果，不替代 [15 台账](../15-项目状态与阶段台账.md) 的当前状态。
