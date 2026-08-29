# G2-A1 Auth Spike 准备与资源门禁

文档状态：**G2-A1 执行中（B1 最小连接与配置/能力只读预检、B2 本地安全基础及远端闭环已完成；当前 B2 external entry Gate design/preflight 已完成）**；PR #13 docs-only closeout merge=`b3e53a71ca40729b139724a492e8d20afd02f341`，main Actions run=`33212054195`/job=`98987321203` success，`test:auth` 12 项且仅运行一次，exact merge 的 GitHub deployments=`0`，Vercel 无新增部署；该闭环仅关闭文档 Gate 设计与本地基础交付，不等于完整 B2/Auth/G2-A1 整体通过；真实 Auth/OAuth/SMTP/DB/Storage/user/session/MFA 未开始；E1 local bootstrap 已以 PR #15 merge commit 完成 main/远端交付闭环，仅代表 E1 本地隔离骨架；独立安全审查 GO（P0=0/P1=0，唯一 P2 已修），E2–E5、hosted Auth/SMTP/DB/Storage/Production/deploy 全部继续 CLOSED；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 关闭**
记录日期：2026-08-29（Europe/Rome）
当前批次状态纠正（2026-08-29）：E1 local bootstrap 已以 PR #15 merge commit 完成 main/远端交付闭环，仅代表 E1 本地隔离骨架；独立安全审查 GO（P0=0/P1=0，唯一 P2 已修）；两轮 `supabase start` 均为 6/6 本地缓存命中，目标服务 health/API/DB/Studio/Mailpit 探针通过，随后项目限定 stop/cleanup 成功；本条覆盖上方历史性“待独立审查后打开”表述。E2–E5、hosted Auth/DB/Storage/OAuth/SMTP、真实 Auth/OTP/invite、业务 schema、deploy、Production 继续 CLOSED。
证据级别：规划 + 外部资源只读核验 + 本地静态/运行 + agent-browser；不代表 Auth、Staging、数据库或生产能力
前置阶段：G2-A0 Exit GO，远端 docs-only reconciliation 已完成，事实见[本批 Entry preparation 证据](../evidence/G2-A1/2026-08-28-entry-preparation/README.md)

## 1. 本批声明与边界

本文件先记录 G2-A1 的无资源 Entry preparation：它完成了后续执行合同、资源/费用/密钥 Gate 字段、Auth 实测矩阵和公开证据边界的准备。随后完成独立 Free Supabase 资源的管理面存在性/基础健康预检，并在已批准的窄范围内完成 A1-B1 最小本地连接与配置/能力只读预检；**Auth/OAuth/SMTP/DB/Storage/user/session/MFA 技术验证仍未开始**。既有文档治理复审首轮 finding 已关闭；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge，也不等于 G2-A1 Auth/B1 技术通过。当前项目不创建真实账号或 fixture，不部署、不改变 Production，也不修改已冻结的 G0/P1 UI、prototype、workflow、package 或 lockfile；不得读取或使用 secret/service_role key、secret key 或 DB password。

G2-A0 的远端闭环已经在 `main` 完成：PR #7 的 merge commit 为 `fd9b712c7b07bf34399f9838eebb75846425c1d1`，parents 为 `7ea1e45ad22ab29105910665baf4bbd7212241c5` 与 `1433e7c7c141df0f5498fff7cd645a8d5c92340c`。这只证明已批准的 G2-A0 docs-only 变更完成远端闭环，不把 A1 变成技术通过。

本批可做范围已按 Owner/主代理授权收窄为：只读核对官方 docs/changelog 与目标 Free 资源，取得当前 active modern publishable key，确认 env 隔离，复用现有 client/config/health 做 EU non-production synthetic-only 本地连接验证，并记录脱敏结果、Free 限制、STOP/cleanup。完整 resource/cost/secret Gate 与 Auth/DB 等后续能力仍需另行打开；“无需重复批准”不扩大为未来付费资源、真实 PII、Auth/DB 或 Production 的豁免。

## 2. Entry 状态与下一 Gate

| Gate | 当前状态 | 允许动作 | 不能据此声称 |
|---|---|---|---|
| G2-A0 Exit | 已通过；远端 reconciliation 已完成 | 进入 A1 无资源准备 | Supabase/Auth/DB/Storage 已连接 |
| G2-A1 无资源 Entry preparation | 已完成/已归档 | 文档、接口草图、测试矩阵、合成字段定义 | A1 技术验证开始或通过 |
| G2-A1 最小资源存在性/基础预检 | **已完成（窄范围）** | 核对独立组织、Free 项目、区域、报价确认和健康状态 | Auth、secret/env、DB/RLS、Storage、OAuth、SMTP 或生产能力 |
| G2-A1 最小 Auth spike 风险 Gate | **B1 最小连接及配置/能力只读预检已完成；B2 本地安全基础及远端闭环已完成；B2 external entry Gate design/preflight 已完成**；PR #13 docs-only closeout merge=`b3e53a71ca40729b139724a492e8d20afd02f341`，main Actions run=`33212054195`/job=`98987321203` success，`test:auth` 12 项且仅运行一次，exact merge 的 GitHub deployments=`0`，Vercel 无新增部署；不等于 B2/Auth/G2-A1 整体通过 | E1 local bootstrap 已以 PR #15 merge commit 完成 main/远端交付闭环，仅代表 E1 本地隔离骨架；独立安全审查 GO（P0=0/P1=0，唯一 P2 已修）；下一步仅可进入 E2 action-time Gate 评估，不代表 E2 已打开或可执行 | 完整 B2、E2–E5、真实 Auth/OAuth/SMTP/session/DB/Storage、Production 与外部 action-time Owner Gate 仍 CLOSED；不使用 service_role/secret key/db password |
| 完整 resource/cost/secret Gate | **关闭** | 仅允许维护[资源成本与密钥 Gate 模板](../templates/G2-A1-资源成本与密钥Gate模板.md)及窄范围资源预检 | secret、环境变量、Auth/DB/Storage/OAuth/SMTP 或任何付费/生产能力已批准 |
| G2-A1 技术阶段 | **执行中（B1 完成；B2 本地安全基础及远端闭环完成；B2 external entry Gate design/preflight 完成）** | PR #15/main exact-head 与 Actions closeout 已记录；E1 local bootstrap 已完成 main/远端交付闭环，仅代表 E1 本地隔离骨架；下一步仅可进入 E2 action-time Gate 评估，不代表 E2 已打开或可执行；不预写 external Auth success，不自动打开 E2–E5 或真实 Auth 运行 | Staging、真实登录、Auth/MFA、session、DB/RLS、Storage、OAuth、SMTP、Production 或完整 B2 验收 |

截至本次文档收口（2026-08-29），资源存在性/基础预检与 B1 最小本地连接验证已完成；B2 本地安全基础及其远端闭环已完成，随后完成 B2 external entry Gate design/preflight。当前 `main` 为 PR #15 merge commit=`a5e7fd1ae2ca7468610c0aab936121a27d124c02`；PR head=`fc6153b60872328b55b525730f3c653579ac2ea2`，parents=`b3240577026a0f390ae634f2119426842827805e` + `fc6153b60872328b55b525730f3c653579ac2`；PR head CI run=`33256006999`/job=`99109715930` success；main exact merge CI run=`33256185497`/job=`99110205068` success；精确 merge 的 GitHub deployments=`0`；来源分支保留；Vercel 仍为 3 个既有 READY deployments（2 个 Preview、1 个 Production），本批无新增 deployment。该闭环仅关闭 Gate 设计与文档/本地基础交付，不等于完整 B2/Auth/G2-A1 整体通过；E1 local bootstrap 已完成 main/远端交付闭环，仅代表 E1 本地隔离骨架；独立安全审查 GO（P0=0/P1=0，唯一 P2 已修）；下一步仅可进入 E2 action-time Gate 评估，不代表 E2 已打开或可执行。该结论不是 broad waiver（全局豁免）。Free 计划的能力不能被推断为已满足 Pro 专属的 session 配置要求。真实 Auth callback/session refresh/replay/rate-limit/OAuth/SMTP/DB/Storage/Production 仍 CLOSED，service_role、secret key、db password 继续禁止，B2 结果不能自动打开 B3/P2/P3+，A0–A6 与 P0–P8 的映射仍需在 P2 之前由 Owner/主计划明确。

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

当前 15 台账已记录为“执行中（B1 完成；B2 本地安全基础及远端闭环完成；B2 external entry Gate design/preflight 完成）”；文档收口日期为 2026-08-29，资源核对始于 2026-08-28；PR #15 head=`fc6153b60872328b55b525730f3c653579ac2`、merge=`a5e7fd1ae2ca7468610c0aab936121a27d124c02`、双 CI success、精确 merge 的 GitHub deployments=0、来源分支保留、Vercel 3 个既有 READY deployments（2 个 Preview、1 个 Production）且本批无新增 deployment 事实见第 18 节；该 E1 闭环仅代表本地隔离骨架，不等于完整 B2/Auth/G2-A1 整体通过。下一步仅可进入 E2 action-time Gate 评估，不代表 E2 已打开或可执行。完整 resource/cost/secret Gate 仍关闭；真实 Auth/OAuth/SMTP/session/DB/Storage/Production 与外部 action-time Owner Gate 继续关闭。

## 9. 2026-08-28｜Free Supabase 资源存在性与基础预检（历史资源快照；当前 B2 外部入口 Gate 见第 15 节）

记录类型：外部资源管理面核验；不是 Auth 运行时证据，也不是完整 resource/cost/secret Gate 批准。

- 独立 Supabase 组织 `Rebuy Lab` 已创建；Supabase connector 只读核验该组织 `plan=Free`。
- 独立项目 `rebuy-auth-spike` 已在 `eu-central-1`（Frankfurt）创建；用途限定为 EU non-production Auth spike，数据模式为 synthetic-only。
- provider project quote 已返回 `amount=0`、`recurrence=monthly`；该 API 未返回 currency。Owner 已确认该实际 quote，随后已完成 `confirm_cost`。此记录不把 quote 当作税费、Spend Cap 或完整成本责任确认。
- （历史运行窗口）项目管理面状态为 `ACTIVE_HEALTHY`。健康状态只证明当时资源存在且 provider 管理面报告健康，不等于 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 验证通过；独立运行时复审期间 connector 无法再次列出精确目标，当前状态无法复验。
- （资源预检历史时点）当时资源预检证据范围不包含 secrets、keys、passwords、环境变量值、host、URL、project ref、组织/项目 ID 或其他账号资源标识；后续 B1 仅按授权将原值存入 gitignored local env，执行结果见第 11 节。没有配置 Auth/DB/Storage/OAuth/SMTP，没有建表、写数据、创建真实账号、部署、promote、alias 或 Production 操作。

| Gate | 当前状态 | 允许范围 | 明确关闭 |
|---|---|---|---|
| 最小资源存在性/基础预检 | **已打开并完成（窄范围）** | 组织/Free 计划、项目名称、区域、quote 确认、管理面健康状态 | 不延伸为运行时/Auth/DB 证据 |
| 完整 resource/cost/secret Gate | **关闭** | 仅维护脱敏记录和新的风险 Gate 设计 | secret/env、成本责任/税费/Spend Cap 完整确认、Auth/DB/Storage/OAuth/SMTP |
| 真实数据与 Production | **关闭** | 无 | 真实客户/商户/PII、真实账号、部署、Production/promote/写入 |

既有文档治理复审首轮 finding 已关闭；本次独立运行时复审首次结论为 REVIEW NO-GO，本批 findings 由 `c15b11c` 修复；本节属于历史资源快照，历史复审记录曾针对 `c15b11c` 给出 REVIEW GO，无未关闭 P0/P1 finding；该历史 review GO 仅表示当时本批复审闭环，不改变 B1/B2 或完整 Gate。Owner/主代理已批准并完成 A1-B1 最小连接范围，当前为“已完成（窄范围）”。该批准不是 broad waiver；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续关闭，service_role、secret key、db password 继续禁止。B1 health/管理面结果不得外推为 Auth、DB 或其他技术通过；B1 配置/能力只读预检已完成；当前待定向复审，不预写 REVIEW GO、PR、Actions 或 merge；下一步为 B2 专项风险 Gate 草案独立复审与 Owner/主代理 Gate。

## 10. 2026-08-28｜A1-B1 最小 Auth spike 风险 Gate 与复用优先预检（历史设计快照；当前 B2 外部入口 Gate 见第 15 节）

本批执行级别为**关键**：范围涉及认证、密钥、隐私和外部 non-production 资源；执行代理档位为 `luna_worker / max`；默认一个执行代理。既有文档治理复审首轮 finding 已关闭；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge；Owner/主代理批准打开 A1-B1 最小技术范围。本节保留风险 Gate 设计快照，实际 B1 执行结果见第 11 节；不代表 G2-A1 Auth/B1 已通过，也不打开完整 resource/cost/secret/Auth/DB Gate。

### 10.1 Gate 决定与最小授权范围（历史设计快照；当前 B2 外部入口 Gate 见第 15 节）

| 项目 | 本批决定 |
|---|---|
| Gate 状态 | **A1-B1 最小连接及配置/能力只读预检已完成（窄范围）**；既有文档治理复审首轮 finding 已关闭；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge；不代表 G2-A1 Auth/B1 技术通过 |
| 目标资源 | Supabase 组织 `Rebuy Lab`（Free）；项目 `rebuy-auth-spike`；`eu-central-1`（Frankfurt）；仅 EU non-production、synthetic-only |
| 已核验成本事实 | provider project quote 返回 `amount=0`、`recurrence=monthly`；API 未返回 currency；Owner 已确认该实际 quote 并完成 `confirm_cost` |
| 成本边界 | 不授权任何非零费用、add-on、upgrade、自定义 SMTP 或其他付费能力；tax/VAT/billing-address effect、Spend Cap 状态/覆盖范围和完整成本责任仍待另行只读核验 |
| 管理面事实 | `ACTIVE_HEALTHY`；只证明资源存在且管理面健康，不证明 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 通过 |
| 当前阶段 | G2-A1 执行中；B1 最小连接及配置/能力只读预检已完成；B2 CLOSED/待独立复审和专项 Gate；没有真实账号、真实 PII、Auth/DB/Storage/OAuth/SMTP 配置或运行时 Auth 证据 |
| 下一批可申请动作 | B2 专项风险 Gate 草案的独立复审与 Owner/主代理 Gate；不自动进入 B2 |
| 密钥保存边界 | project URL 与 modern publishable key 仅可进入 gitignored local env 或受控 Preview env；本仓库、证据、聊天、日志、截图和客户端 bundle 不保存原值；不得读取或使用 secret/service_role/secret key/db password |
| 明确未授权 | 不配置 Auth/OAuth/SMTP，不建表/写数据，不启用 Storage，不创建真实账号/fixture，不部署、promote、alias、Production 或 Supabase 生产资源 |

上述风险 Gate 设计已在窄范围执行；B1 连接与配置/能力只读预检结果见第 11 节和第 12 节，不是 broad waiver，也不等于 G2-A1 Auth/B1 技术通过。B2 专项风险 Gate 草案待独立复审与 Owner/主代理 Gate，不自动打开 B2/B3、P2 或 Production。

### 10.2 责任与停止合同

| 责任项 | 当前指定 | 边界 |
|---|---|---|
| Product / cost / stop / provider admin | Hexiang Huang | 负责范围、费用确认、provider 管理面与立即停止；不得以“无需重复批准”扩大到付费、真实 PII 或 Production |
| 技术执行 | Codex 自动化执行（后续由 `luna_worker / max` 按批次执行） | 只执行明确的 non-production 最小动作；Owner 保留最终责任和停止权；不得自行扩大范围 |
| 独立安全复审 | 既有文档治理复审首轮 NO-GO finding 已关闭；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge；Owner/主代理当前批准继续 | 本授权仍只覆盖 B1 最小动作；不扩大到完整资源、Auth/DB/Storage/OAuth/SMTP 或 Production |
| secret/key owner | Hexiang Huang | 原值只允许存在 provider/Vercel secret store 或 gitignored local env；证据只写名称/引用/不可逆摘要，不写原值 |
| 证据保管 | 仓库脱敏摘要 + provider 审计记录 | 不保存 secret、URL/host/ref/ID、cookie、token、OTP、TOTP seed 或真实 PII；阶段事实仍以 15 台账为唯一当前状态源 |
| 法律 / 隐私 / 税务 | A5 / 专业顾问待处理 | 不在 A1 对 GDPR、税务、跨境或处理者合同作结论 |

### 10.3 复用优先预检结论（历史设计快照；当前 B2 外部入口 Gate 见第 15 节）

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

### 10.4 B1 最小验收与停止条件（历史设计快照；当前 B2 外部入口 Gate 见第 15 节）

本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge。B1 最小连接与配置/能力只读预检已完成；下列清单保留为 B2 独立复审与 action-time Owner Gate 前的重新核验边界：

1. 复核当前官方 docs/changelog、Node/SDK 版本和 Free 计划限制；不从本节推断 Pro 专属 session 能力。
2. B2 执行前必须在实际 worktree 重新验证 env 被 `.gitignore` 阻止跟踪、保持 untracked 且权限为 mode `600`；只读复核 active publishable key 状态，不得读取 secret/service_role、secret key 或 DB password。当前 capability-preflight worktree 不包含 `prototype/.env.local`，不得沿用旧连接 worktree 权限结论。
3. 若后续经 action-time Owner Gate 授权继续，仍只复用现有 browser/SSR client 与 health；不得扩展为真实 Auth、DB、Storage、OAuth 或 SMTP。
4. 记录配置缺失、远端不可达、非 2xx、可达等脱敏结果；health/管理面结果不得写成 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或生产通过。
5. 继续维护 Free limitations、测试期限、STOP 联系人、expiry/cleanup/回退路径；hosted 默认 SMTP 仅向项目团队预授权邮箱发送，当前基线每小时 2 封且可能变化、无 SLA，仅用于非生产探索；`.invalid` 只用于 no-send/负向/反枚举，成功 OTP/Magic Link 必须使用专用 synthetic test mailbox/domain、隔离 catcher 或另行批准的 custom SMTP；不启用 Auth/OAuth/SMTP/Storage，不建表、不写数据、不创建真实账号。

任一真实 PII/secret、Production 连接、非零费用、生产 redirect/SMTP、默认 SMTP 成功投递无法限定到预授权地址、需要 custom SMTP credential/secret/费用/持久连接或浏览器/控制台配置动作、service_role 依赖、环境串线、日志/Network/bundle 泄露或无法清理，立即停止并保留脱敏失败摘要；不得用绕过方式继续。B2 仍不自动打开 B2/B3、P2 或 Production。

### 10.5 本批证据入口

本批复用预检和风险 Gate 的脱敏证据见[2026-08-28 B1 风险 Gate 证据](../evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)。证据 README 只记录批次事实、复用结论和验证结果，不替代 [15 台账](../15-项目状态与阶段台账.md) 的当前状态。

## 11. 2026-08-28｜A1-B1 最小连接验证执行结果（历史快照；当前 B2 外部入口 Gate 见第 15 节）

- 初次 B1 运行前 connector 曾核对目标为 `Rebuy Lab` / `rebuy-auth-spike`、Free、`eu-central-1`、`ACTIVE_HEALTHY`；独立运行时复审期间 connector 再次无法列出精确目标，当前管理面状态无法复验。未访问其他项目、未执行任何外部动作；此前本地 health `200` 仅为当时运行窗口的时间界定证据，不是当前持续健康保证。
- Chrome DOM 与内部交接曾出现一个截断的 publishable 参数展示值，该值首次导致 health `401 invalid-credential-response`，按停止条件主动停止；随后按授权改用 connector 返回的唯一 active modern publishable key，未创建、轮换或删除 key。该展示值不是当前 active key；不记录长度、前后缀或原值。
- `prototype/.env.local` 已由 `.gitignore:11` 忽略且权限类别为 owner-only；当前 tracked tree/diff 未发现完整 active key、host、project ref 或 secret。不对所有非 tracked 命令回显、日志、截图、浏览器输出或内部状态作绝对无值断言。
- 先以无配置启动隔离端口 `3101`，`GET /api/health/supabase` 返回 `503` 与固定 `configured=false/reachable=false/status=503`；再使用当前 active key 返回 `200` 与固定 `configured=true/reachable=true/status=200`，两者均为 `Cache-Control: no-store`。这只证明 settings health 可达，不证明 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 技术通过。
- 使用 Node `22.12.0`、pnpm `10.33.3` 和固定 SDK 复用现有 client/config/SSR/health；`pnpm typecheck`、`pnpm lint`、`pnpm build` 全部成功。未修改源码、依赖、lockfile、workflow 或配置；build 生成的 `next-env.d.ts` 漂移已按 HEAD 恢复。
- 用临时 `npm exec agent-browser` 按技能完成 localhost 页面 load/networkidle、非空主结构、无可见 Next 错误覆盖层、console `[]`、关键元素快照；使用非敏感 `usb` 完成搜索结果与商品详情导航，浏览器和 dev server 已关闭，截图仅保留在 `/private/tmp`。
- 当前结论：**B1 最小连接及配置/能力只读预检完成（窄范围）**；G2-A1 仍执行中，Auth/OAuth/SMTP/DB/Storage/user/session/MFA 未开始，完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续 CLOSED。本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge；下一步为 B2 专项风险 Gate 草案独立复审与 Owner/主代理 Gate；不自动进入 B2。
## 12. 2026-08-28｜A1-B1 配置/能力只读预检完成（历史快照；当前 B2 外部入口 Gate 见第 15 节）

本批通过已登录 Chrome 的指定 Supabase Auth 配置页面完成只读能力分类，精确目标的组织/项目/Free 标签可见；区域沿用既有 EU non-production 资源记录。connector 当前无法再次列出精确目标，未访问其他项目，也未执行外部写入。详细脱敏证据见[B1 配置/能力预检证据](../evidence/G2-A1/2026-08-28-b1-capability-preflight/README.md)。

- 观察范围：signup、manual linking、anonymous、email/phone/Apple/Google/其他 provider、email security、URL/redirect、SMTP/template、rate limits、TOTP/phone MFA、AAL1 session duration、Free session controls、token/refresh、captcha、leaked-password 与 hooks。
- 本批没有 Save、Enable、Create、Reveal 或 Copy；没有读取 API Keys、SQL/Table Editor、DB/Storage 数据、用户、Audit Logs 数据、secret、service_role、DB password 或真实 PII；没有配置或发送邮件、OAuth、MFA、session、DB、Storage、hook 或真实账号。
- 当前分类仅能判定 B1 配置/能力只读预检完成；不能写成 Auth/G2-A1 技术通过。B2 专项风险 Gate 草案已记录三入口前提、synthetic .invalid、Free 限制、STOP/cleanup 和独立复审要求，但 B2 继续 CLOSED。
- 完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续关闭；service_role、secret key、db password、真实邮件/账号/数据、生产 callback、付费升级和 Production 操作继续禁止。
- 依据 [Supabase Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)、[Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits) 与 [Free 邮件模板变更](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier)：hosted 默认 SMTP 仅向项目团队预授权邮箱发送，当前基线为每小时 2 封且可能变化，无 SLA，仅用于非生产探索。`.invalid` 仅用于 no-send、负向和反枚举，不能用于成功 OTP/Magic Link；成功路径必须使用专用 synthetic test mailbox/domain、隔离 catcher 或另行批准的 custom SMTP。
- custom SMTP credential/secret、费用、持久连接及任何浏览器/控制台配置动作继续 CLOSED，每次实际动作需要 action-time Owner Gate，不能以总体批准替代；当前 capability-preflight worktree 不包含 `prototype/.env.local`，B2 执行前必须在实际 worktree 重新验证 ignored、untracked 与 mode `600`，不得沿用旧 worktree 权限结论。
- 本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge。

## 13. 2026-08-28｜G2-A1-B2 本地安全基础实现（本地 closeout 历史；当前外部入口 Gate 见第 15 节）

- 本批复用既有 `prototype/lib/supabase/config.ts`、`client.ts`、`server.ts`、登录演示和 health route；新增 safe-next 规范化、callback decision、同源 no-store callback route、有限错误提示、Node 内置契约测试和一次性 workflow 测试步骤。未新建第二套 client/env/health。
- 本批形成 **B2 本地安全基础通过/可进入远端 PR 候选**；`test:auth`、typecheck、lint、build 通过，隔离端口 `3102` 首页按 agent-browser-verify 完成 open/networkidle、截图、非空、无错误覆盖层、console `[]` 与交互快照并已关闭 server；因无有效 Auth 凭据或授权 code，未产生 callback/Auth 运行证据。详细脱敏证据见[B2 本地安全基础](../evidence/G2-A1/2026-08-28-b2-local-foundation/README.md)。
- 首轮独立安全复审为 REVIEW NO-GO，发现 1 项 P1 与 2 项 P2；当前 checkpoint 已修正 callback code 输入上限/空白与控制字符门禁、safe-next 总长度与稳定解码边界、可注入 route handler 及最终 origin 二次校验，并补齐 12 项 Node `node:test` 契约。独立定向复审随后针对 candidate exact-head `761de2b3a8ce22247501cddbad2da6e2cfc3ae59` 给出 REVIEW GO，P0/P1/P2=0；复审 shell Node `20.20.2` 的 `test:auth` 12/12 与 typecheck 出现 engine warning，复用候选 exact-head Node `22.12.0` 的 build/lint/browser 证据；不预写 PR、Actions 或 merge。
- 真实 Auth/OAuth/SMTP/email/OTP/Magic Link、session/user、MFA、DB/Storage、真实 PII、部署和 Production Gate 继续 CLOSED；下一步由主代理决定是否进入远端 PR 候选治理，不自动进入 B3/P2。

## 14. 2026-08-28｜G2-A1-B2 本地安全基础远端闭环（历史快照；当前见第 15 节）

- B2 本地安全基础已合并 main/远端闭环通过：PR #12 已以 merge commit 合并到远端 `main`，head=`55b7497953bc22e002e4c75a4b039c5b08fd98e7`，merge=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`，parents=`689d9679293f255c44feb314428a2678b9fe4d06` + `55b7497953bc22e002e4c75a4b039c5b08fd98e7`；来源分支 `codex/g2-a1-b2-local-foundation` 保留。
- 远端 `main` exact head=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`；main Actions run=`33209420614` / job=`98978680399` success，`test:auth` 12/12 且仅运行一次；exact merge 的 GitHub deployments=`0`。Vercel 仍为 `3` 个既有 deployments，Production 仍为 `READY`，aliases=`2`，本次无新增 Preview/Production deployment。
- 该 closeout 仅关闭本地安全基础的远端 source/CI 交付记录；完整 B2、real Auth/OAuth/SMTP/session/DB/Storage/Production 与外部 action-time Owner Gate 继续 CLOSED。下一步仅可进入 B2 外部入口 Gate 设计/资源检查，不预写 external Auth success；不自动打开 B3、P2 或 Production。
- 本次仅更新文档记录，不运行本地 build/tests/browser，不执行 Supabase/Auth/DB/Storage/SMTP、secret、部署或 Production 操作。

## 15. 2026-08-28｜G2-A1-B2 外部入口 Gate 设计与资源 preflight（历史快照；当前 E1 远端闭环见第 18 节）

### 15.1 Gate 结论与阶段分层

- **本批完成**：B2 external entry Gate design/preflight；风险等级为 critical，执行代理 `luna_worker / max`，单一写入者，需独立安全审查；本批不是 B2/Auth 技术通过。
- **E1 可候选打开**：在本 docs-only 分支独立审查通过并以 merge commit 合并 `main` 后，只打开 local bootstrap：新 Rebuy local config、合成数据、55320–55329 隔离映射和缓存复用。不得登录/link hosted project、读取 hosted secret、触碰现有 SSH/容器；拉新镜像、非零费用、端口冲突、修改现有容器或无法清理即 STOP 并另开 Gate。
- **E2–E5 继续关闭**：E2 local email OTP/invite 依赖 E1 健康且成功邮件只能进入 local catcher；E3 Google、E4 Apple、E5 hosted callback/linking/invite、custom SMTP 和 hosted Auth writes 均需各自 action-time Gate。DB business schema、Storage、Production、deploy 永远不由本 Gate 自动打开。

### 15.2 只读资源与本地 preflight

- 当前远端 `main` 为 PR #13 docs-only closeout merge=`b3e53a71ca40729b139724a492e8d20afd02f341`；main Actions run=`33212054195`/job=`98987321203` success，`test:auth` 12 项且仅运行一次，exact merge 的 GitHub deployments=`0`；Vercel 仍有 3 个既有 READY deployments，本批无新增部署。
- connector 当前只显示另一账号资源，无法列出目标；已登录 Chrome 控制台的只读观察曾确认独立 Free、EU Central/Frankfurt、`ACTIVE_HEALTHY` 且未暂停。Email/signup/confirm 开启；Phone/Google/Apple/manual linking/custom SMTP 关闭；redirect allowlist 条目数为 0；TOTP 开启、Phone MFA 关闭；Free session controls 受限。临时浏览器标签已关闭，无配置写入；这些是脱敏配置/历史管理面事实，不是持续健康或 Auth 通过证据。
- Supabase CLI=`2.101.0`；Docker client/server=`29.5.2`/`29.2.1`（Linux arm64）可达；running/total=`14/19` 仅记计数；Mailpit 不在 PATH，缓存可见但 exact 兼容性待确认；无 Rebuy 容器/config/migrations/harness；54321–54324 被现有 SSH 监听且不干预，55320–55329 空闲；Node 20 默认、Node 22.12.0 已安装；现有 SSR/callback/tests 可复用，env/temp ignore 覆盖仍需 E1 实际 worktree 重验。
- CLI offline 模板端口为 shadow 54320、API 54321、DB 54322、Studio 54323、inbucket 54324、analytics 54327、pooler 54329、edge inspector 8083；E1 推荐映射到 55320、55321、55322、55323、55324、55327、55329，其他 SMTP/POP3/inspector 字段必须等实际配置确认后再使用，不得猜测。

### 15.3 邮件与 OAuth/Apple 责任边界

- Hosted 默认 SMTP 仅向预授权团队地址发送，限额动态、无 SLA、仅适合非生产探索；早期每小时 2 封只作为历史基线，不是当前保证。`.invalid` 只用于 no-send/负向/反枚举，成功 OTP/Magic Link/invite 必须使用专用 synthetic mailbox/domain 或 local catcher；不得使用真实个人/客户邮箱。
- Google 仅可在独立测试 Cloud project、Testing 状态和合成 identity 下另开 E3；通常最多 100 个 test users、授权通常 7 天，范围只允许 `openid`、`email`、`profile`。需要 Client ID/secret、support contact 和精确 non-production redirect；任何控制台创建、secret、billing 提示或额外 scope 都触发 STOP。
- Apple Web OAuth 需要 Team ID、App ID、Services ID、client secret、受控 `.p8` 和 relay 配置；Apple Developer Program 官方年费为 99 USD/year。按免费优先，Apple 保持 disabled/PAID-BLOCKED；不付款、不注册、不生成 secret。它不阻塞 E1/E2 局部工作，但阻塞完整三入口、B2 整体和 G2-A1 Exit。
- 依据：[Supabase SMTP](https://supabase.com/docs/guides/auth/auth-smtp)、[Supabase Identity Linking](https://supabase.com/docs/guides/auth/auth-identity-linking)、[Supabase Passwordless email](https://supabase.com/docs/guides/auth/auth-email-passwordless)、[Supabase Google](https://supabase.com/docs/guides/auth/social-login/auth-google)、[Supabase Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple)、[Supabase Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls)、[Google OAuth audience/testing](https://support.google.com/cloud/answer/15549945?hl=en)、[Apple membership](https://developer.apple.com/programs/whats-included/)。以上官方资料于 2026-08-28 复核，仅为规划依据。

### 15.4 回退、清理与残余风险

- E1 回退只移除本批新建的 local config、合成 fixture、local catcher 和 55320–55329 新建容器；不得停止、修改或删除既有 SSH 监听、既有容器、54321–54324 对象或远端资源。清理后重新核对 tracked tree、ignored env/temp 类别、容器清单和端口。
- 发现目标漂移、env 未 ignore、权限不符、secret/PII 进入仓库/日志、需要 Save/Enable/Create/Reveal/Copy、端口冲突、非零费用、需修改现有容器、无法证明隔离或无法清理时，立即 STOP，只保存脱敏错误分类和影响范围；若需 hosted/Auth/SMTP/DB/Storage/Production 动作，另开 exact action-time Gate。
- 残余风险：connector 目标当前不可列出；管理面健康不能证明持续健康；Mailpit 兼容性未确认；空闲端口可能变化；Free session/SMTP 限制可能变化；Google/Apple client、hosted callback/linking/invite、真实邮件、Auth/session/MFA、DB/Storage 和部署均未运行；本批没有 Auth runtime/browser 证据。

### 15.5 本批验证与证据入口

- 本批仅需执行 docs link/fragment、fence/backtick、sensitive scan、stale-current、diff-check；不重复源码 build/lint/typecheck/browser/Auth runtime，因代码与 workflow 未改变且本批为 docs-only。
- 详细脱敏记录与官方链接见[B2 外部入口 Gate 证据](../evidence/G2-A1/2026-08-28-b2-external-entry-gate/README.md)。本节完成后仍不得把 Gate 设计或资源观察写成 B2/Auth/G2-A1 技术通过。

## 16. 2026-08-29｜G2-A1 E1 local bootstrap 首轮失败诊断（历史；当前纠正见第 17 节）

### 16.1 执行范围与生成结果

- 本批唯一执行者在新 worktree `.worktrees/rebuy-g2-a1-e1-local-bootstrap-exec`、分支 `codex/g2-a1-e1-local-bootstrap-exec` 工作，基线为实时 `origin/main`=`b3240577026a0f390ae634f2119426842827805e`。未触碰旧根 checkout、其他 worktree 或 `rebuy-private-merchant-access`，未修改 prototype、package、lockfile、workflow。
- CLI `/opt/homebrew/bin/supabase` 版本为 `2.101.0`；在 `SUPABASE_TELEMETRY_DISABLED=1` 下执行 `supabase init` 成功。仅生成当期 `supabase/config.toml`、`.gitignore` 和 comments-only `seed.sql`；seed 无 SQL 语句和数据行。
- 配置为 Rebuy local-only：shadow/API/DB/Studio/Inbucket web=`55320/55321/55322/55323/55324`，analytics vector/analytics=`55326/55327`，edge inspector=`55328`，pooler=`55329` 但 disabled；SMTP/POP3 未发布。Auth signup、email signup、Google、Apple、OAuth server disabled；无 secret/env 值、custom SMTP 或 hosted link。

### 16.2 Image-download Gate 与启动结果

- 通过 CLI binary 当前模板和 `supabase services -o json` 辅助解析 exact refs；只检查通用 Supabase/Mailpit 镜像 cache，不执行 `docker ps`，不读取其他项目容器详情。
- Docker client/server=`29.5.2/29.2.1`、Linux arm64。初始 CLI binary exact ref 检查发现若干候选 tag 缺失；经明确批准开启 image-download Gate。获批后的 `supabase start` Pull 阶段为 `13/13`，每项均显示 `Skipped - Image is already present locally`，没有网络 pull/download/tag。
- `supabase start` 随后完成数据库初始化、globals/seed（comments-only）阶段并进入容器启动；创建 `supabase_vector_rebuy-g2-a1-e1-local-bootstrap-exec` 时因 Docker mount source `/Users/kyox215/.colima/default/docker.sock` 返回 `operation not supported` 失败。未执行 E2 OTP/invite 或任何真实 Auth。
- 项目限定 `supabase stop --project-id rebuy-g2-a1-e1-local-bootstrap-exec` 返回成功；项目名容器、项目名 volume 和 55320–55329 TCP listener 复核均无输出。启动失败前后 `supabase status` 均因缺少 `supabase_db_rebuy-g2-a1-e1-local-bootstrap-exec` 返回诊断；API/DB/Studio/Mailpit health 未形成通过证据。

### 16.3 后续边界与证据

- 当前只记录 **E1 local bootstrap 本地候选/启动失败后已清理**。E2–E5、hosted Auth/DB/Storage/OAuth/SMTP、真实 Auth/OTP/invite、业务 schema、deploy、Production 继续 **CLOSED**；不预写 PR、CI、merge 或外部结果。残余风险是 Docker/Colima socket mount 前提、status 在无 DB 容器时失败、本地栈健康尚未验证。
- 详细脱敏命令结果、官方当日资料和回退边界见[E1 local bootstrap evidence](../evidence/G2-A1/2026-08-29-e1-local-bootstrap/README.md)。官方入口：[Supabase CLI getting started](https://supabase.com/docs/guides/local-development/cli/getting-started)、[config.toml reference](https://supabase.com/docs/guides/local-development/cli/config)、[CLI reference](https://supabase.com/docs/reference/cli)、[Supabase changelog](https://supabase.com/changelog)。

## 17. 2026-08-29｜G2-A1 E1 local bootstrap 复验通过候选与 cleanup 纠正（历史候选；当前远端闭环见第 18 节）

- 第 16 节仅保留首次未排除 Vector 的 Docker/Colima socket mount 失败诊断；binary-derived image refs 仅作首次 cache 诊断，非权威运行时事实。本批未修改全局 Colima、Docker socket、symlink 或 host runtime。
- 两轮差异：首轮使用 `start --help` 逻辑排除名，CLI 警告 `analytics/storage/functions` 无效；Pull=`6/6` 全部 local/skipped，目标容器 health、健康探针和 cleanup 通过。第二轮使用实际有效排除名 `logflare/vector/realtime/storage-api/imgproxy/edge-runtime/gotrue/supavisor`；无 warning，Pull=`6/6` 全部 local/skipped，得到相同服务集合并复验通过。两轮均无 image pull/download/tag 或版本漂移。
- 六个实际服务容器为 `supabase_db_*`、`supabase_kong_*`、`supabase_rest_*`、`supabase_pg_meta_*`、`supabase_studio_*`、`supabase_inbucket_*`，对应 DB、API gateway/API、REST/API、Meta、Studio、Inbucket/Mailpit。published HostIP 全部为 `127.0.0.1`；API REST=`200`、DB `pg_isready` accepting、Studio=`307`、Mailpit=`200`；未出现 Auth、Realtime、Storage、Vector、Analytics、Imgproxy、Edge Runtime、Functions 或 Supavisor。
- 通过 `require_escalated` 获批创建唯一 `supabase_network_rebuy-g2-a1-e1-local-bootstrap-exec` loopback bridge，option=`com.docker.network.bridge.host_binding_ipv4=127.0.0.1`；两轮均使用 help 确认的 `stop --project-id ... --no-backup`，随后仅删除该精确 network。最终项目 containers、volumes、network 与 `55320–55329` listeners 均为空；`54321–54324` 仅核对端口存在性仍为 `LISTENING`，未读取其所属进程/容器/network 详情。
- 当前状态：**E1 local bootstrap 本地完成候选/待独立审查**。E2–E5、hosted Auth/DB/Storage/OAuth/SMTP、真实 Auth/OTP/invite、业务 schema、deploy、Production 继续 **CLOSED**；未执行真实 Auth/DB/Storage 写入、hosted 登录/link、费用、push、PR、merge 或 deploy。

## 18. 2026-08-29｜G2-A1 E1 local bootstrap 远端交付闭环（当前）

- E1 local bootstrap 已以 PR #15 用 merge commit 合并 `main`，完成远端 docs-only 交付闭环；该结果仅代表 E1 本地隔离骨架，不代表 E2 或 hosted/Production 能力已打开。
- PR head=`fc6153b60872328b55b525730f3c653579ac2ea2`，merge=`a5e7fd1ae2ca7468610c0aab936121a27d124c02`，parents=`b3240577026a0f390ae634f2119426842827805e` + `fc6153b60872328b55b525730f3c653579ac2ea2`；PR head CI run=`33256006999`/job=`99109715930` success；main exact merge CI run=`33256185497`/job=`99110205068` success；精确 merge 的 GitHub deployments=`0`；来源分支保留。
- 刚刚只读核对的 Vercel 事实为 3 个既有 READY deployments，其中 2 个 Preview、1 个 Production；本批没有新增 deployment。不记录 creator email 或其他 PII。
- 独立安全审查 GO，P0=0、P1=0，唯一 P2 已修。E2–E5、hosted Supabase/Auth/DB/Storage/OAuth/SMTP、真实账号/邮件、业务 schema、新 Vercel deployment、promote/alias/rollback、Production 操作继续 CLOSED；下一步仅可进入 E2 action-time Gate 评估，不代表 E2 已打开或可执行。
