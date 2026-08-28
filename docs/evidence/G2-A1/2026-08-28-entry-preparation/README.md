# G2-A1 Entry preparation 与资源存在性预检证据

记录日期：2026-08-28（Europe/Rome）
文档属性：**历史快照（Entry preparation 完成时点；当前 B1 状态见[B1 配置/能力预检证据](../2026-08-28-b1-capability-preflight/README.md)；连接与复审收口见[B1 风险 Gate 证据](../2026-08-28-b1-risk-gate/README.md)）**
阶段状态（历史快照）：**G2-A1 技术阶段未开始；最小资源存在性/基础预检已完成；独立安全复审已完成、首轮 finding 已关闭；A1-B1 最小技术范围已授权/待执行；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 关闭**
证据级别：本地静态（docs-only）+ 外部资源存在性核验 + 已完成的 G2-A0 远端闭环摘要
执行范围：Entry preparation 文档、阶段导航、资源 Gate 模板和 Auth 实测矩阵模板；另附独立资源管理面预检摘要

## 1. 本批结论

本批完成 G2-A1 的无资源准备：建立四批后续执行合同、资源/成本/密钥 Gate 字段、Auth 实测矩阵字段、官方资料刷新和脱敏证据边界。该无资源准备本身**没有开始 G2-A1 Auth 技术验证**；随后追加的资源事件仅完成独立 Free Supabase 资源的管理面存在性/基础健康预检，没有连接应用或配置 Auth/DB/Storage/OAuth/SMTP，没有读取 secret/env/PII，没有创建真实账号或 fixture，没有部署、promote、alias、Production 写入或 UI/代码变更。

完整 resource/cost/secret Gate 继续关闭；仅打开到“最小资源存在性/基础预检”这一窄范围。**以下“下一步必须形成新的最小 Auth spike 设计与风险 Gate”是前一批 Entry preparation 完成时的历史时点表述。** Entry preparation 完成时，A1-B1 最小技术范围已获授权但待执行，独立文档安全复审已完成且首轮 finding 已关闭；当前 B1 最小连接与独立运行时复审收口见[B1 风险 Gate 证据](../2026-08-28-b1-risk-gate/README.md)；配置/能力只读预检见[B1 配置/能力预检证据](../2026-08-28-b1-capability-preflight/README.md)。当时不能把资源健康状态外推为 Auth/DB 验证；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP、真实 PII、部署和 Production 继续关闭，service_role、secret key、db password 继续禁止。

关联入口：

- [G2-A1 Auth Spike 准备与资源门禁](../../../stages/G2-A1-Auth-Spike准备与资源门禁.md)
- [G2-A1 资源成本与密钥 Gate 模板](../../../templates/G2-A1-资源成本与密钥Gate模板.md)
- [G2-A1 Auth 实测矩阵模板](../../../templates/G2-A1-Auth实测矩阵模板.md)
- [A1 Auth Spike 执行合同](../../../10-A1-Auth-Spike执行合同.md)
- [项目状态与阶段台账](../../../15-项目状态与阶段台账.md)

## 2. G2-A0 远端闭环事实（本批纳入的既有证据）

以下是 G2-A0 已完成远端 reconciliation 的只读摘要，不是本批新增的外部写入：

| 检查项 | 已核对事实 |
|---|---|
| PR | [PR #7](https://github.com/kyox215/REBUY_SHARE/pull/7) 已以 merge commit 合并 |
| merge commit | `fd9b712c7b07bf34399f9838eebb75846425c1d1` |
| parents | `7ea1e45ad22ab29105910665baf4bbd7212241c5` + `1433e7c7c141df0f5498fff7cd645a8d5c92340c` |
| main Actions | [run 33122238997](https://github.com/kyox215/REBUY_SHARE/actions/runs/33122238997) / job `98691703085`；install、typecheck、lint、build 全部 success |
| merge SHA 的 GitHub deployments | `0` |
| 来源分支 | `codex/g2-a0-security-contract` 保留，未删除 |
| merge 方式 | 非强制 merge commit；未使用 squash、rebase、force/direct push；未删除分支或 deployment |

这些事实证明 G2-A0 的批准 docs-only 变更完成远端闭环，不证明 A1 的 Auth、MFA、DB、RLS、Storage、SMTP 或 Production 能力。

## 3. Vercel / Production 不变量

本批仅复用既有只读核验，不执行部署类操作：

- Vercel 仍只有 `3` 个既有 deployments；本批没有新 deployment。
- 既有 Production deployment `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` 仍为 `READY` / `PROMOTED`；Production alias 未变。
- Git link 仍为空；本批未创建 link、未改变项目设置、未 promote、未 alias、未 rollback、未删除 deployment。
- 遗留风险：项目设置为 Node `24.x`，既有 Production 构建元数据为 Node `22.x`；该差异在本批未改变，也不能由本批文档解释为已解决。

以上只读摘要不包含 URL、cookie、token、环境值或 secret 原值；Vercel 复核仅用于保护既有 Production 不变量，不打开 Preview 或 Production Gate。

## 4. 公开 Supabase inventory 摘要（无资源阶段历史快照）

允许公开的最小摘要仅为：**只读 inventory 没有发现已获批准、可用于 Rebuy 的独立 non-production project；任何无关项目禁止复用。** 本批不公开任何 Supabase inventory 的组织/项目名称、ID、数量、套餐、host 或现有 region，也不记录 key、token 或环境值。

候选只是 proposal，尚未获得 Owner 明确选择的 organization、resource scope、exact cost 或资源 Gate 通过：在该 organization 内新建独立 Rebuy non-production project；计划须支持 A1 必测能力（session lifetime/single-session 因官方限制需 Pro 或更高）；候选区域 `eu-central-1`（Frankfurt）；组织级 Spend Cap 状态必须另行只读核验；无 add-on、synthetic-only。该 proposal 不等同于 provider/organization/plan/region 已选择，不授权创建项目。

准确费用流程：用户先明确选择 organization + resource scope；provider `get_cost` 返回并确认其实际提供的 amount/recurrence；tax/VAT/billing-address effect 另由 billing page/专业顾问核对；Spend Cap 是 organization-level 设置，另行只读核验其状态和覆盖范围；三项均完成并有 Owner 明确确认后才可创建。通用价格页不能替代本项目 exact cost。

## 5. 2026-08-28 官方来源刷新

本节仅记录 Supabase 官方来源的日期化规划依据；来源不会替代 A1 的实际版本、配置和隔离环境证据。

| 官方来源 | 刷新事实 | 规划影响 |
|---|---|---|
| [Node.js 20 support changelog](https://supabase.com/changelog/45715-deprecation-notice-dropping-support-for-node-js-20) | Supabase client libraries 的 Node 20 支持已于 2026-06-30 结束；仓库 Node 22 符合 | A1 运行时复核以 Node 22 为基线；本批不改代码/config |
| [OAuth token endpoint breaking change](https://supabase.com/changelog/45468-breaking-change-oauth-token-endpoint-will-return-http-200-instead-of-201) | `/v1/oauth/token` 自 2026-06-01 成功响应为 HTTP 200；客户端应接受任意成功 2xx，而非硬编码 201 | callback 矩阵保留 2xx 兼容检查 |
| [Data API exposure breaking change](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically) | 新表默认可能不自动暴露给 Data/GraphQL API；grants 与 RLS 分离 | A1 只做最小 reachability 观察；完整 grants/RLS 归 A3/A4 |
| [Free-tier email template change](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier) | 新 Free 项目使用默认 SMTP 时认证邮件模板自定义受限；Pro 或配置自有 SMTP 不受该限制 | B1 必须记录 plan/SMTP；不发送真实邮件 |
| [Available regions](https://supabase.com/docs/guides/platform/regions) | 精确 EU 候选为 `eu-central-1` Frankfurt；region 是数据位置控制，不等于 GDPR 合规 | GDPR、税务、跨境和处理者合同转 A5/专业顾问 |
| [Control your costs](https://supabase.com/docs/guides/platform/cost-control) / [Billing FAQ](https://supabase.com/docs/guides/platform/billing-faq) | Spend Cap 是 organization-level 设置，状态/覆盖范围需独立核验；`get_cost` 的 amount/recurrence 与 tax/VAT/billing-address effect 分开确认 | 用户先选 organization + resource scope，再确认 `get_cost` 实际返回值；税费和 Spend Cap 另行核对 |
| [MFA](https://supabase.com/docs/guides/auth/auth-mfa) / [TOTP](https://supabase.com/docs/guides/auth/auth-mfa/totp) | TOTP enrollment/challenge/verify 可形成 AAL2；平台另有 phone factor | Owner 已排除 phone/SMS 与静态恢复码；只按备用 TOTP + 人工恢复合同验证 |
| [Signing out](https://supabase.com/docs/guides/auth/signout) | `local`、`global`、`others` 作用域不同；撤销 session 的 access token 可能直到 `exp` 才失效 | 记录退出语义和 token 窗口，不承诺即时失效 |
| [User sessions](https://supabase.com/docs/guides/auth/sessions) | session lifetime 和 single-session per user 只在 Pro 及以上可配置 | A1 记录 plan、配置和观察窗口，不把默认值写成承诺 |

## 6. 本批静态证据与验证

执行分支从 `main@fd9b712c7b07bf34399f9838eebb75846425c1d1` 建立独立 docs-only worktree；本批文件范围仅限 Markdown。已完成的文档级检查：

- `git diff --check` 通过。
- 当前差异仅为 Markdown；未修改 prototype、workflow、package、lockfile、环境配置或生成物。
- 相对链接与标题锚点已核对；代码块 fence/backtick 成对；新模板的样例只使用 `.invalid` 域与合成标签。
- 当前差异扫描未发现 secret、token、JWT、OTP、TOTP seed、真实 email、phone、address、host 或未授权外部资源值；官方文档链接、公开 Git SHA 和必要 deployment ID 属于可追溯引用，不是凭据。
- 不运行 typecheck/lint/build：源码、依赖、workflow、lockfile、配置和生成物均未变化；复用精确 `main` Actions run `33122238997` / job `98691703085` 的 install/typecheck/lint/build 全绿证据。
- 未做 hash：本批不是确定性生成或文件传输校验，且没有异常覆盖迹象。
- （历史快照）当时未启动独立运行时审查：本记录覆盖无资源 Entry preparation 及其后的管理面资源存在性/基础预检，未进行 provider 技术实施或候选比较；应用未连接 Auth/DB/Storage/OAuth/SMTP；完整 resource/cost/secret Gate 仍关闭。当前 B1 最小连接与运行时复审状态见[B1 风险 Gate 证据](../2026-08-28-b1-risk-gate/README.md)；配置/能力只读预检见[B1 配置/能力预检证据](../2026-08-28-b1-capability-preflight/README.md)，不由本历史记录单独判断；仍不得扩大至完整 Auth/资源或 Production。

## 6.1 2026-08-28 独立文档审查修复记录

独立文档审查发现两项需要收敛的问题：P1 公开边界中残留历史 Supabase org/project 名称；P2 `A0 通过前` 的原型表述已不能反映当前 G2-A0 Exit GO 状态。

- 本提交已从当前 tree 脱敏上述 Supabase 名称，并将 inventory 公开摘要收敛为“没有发现已获批准、可用于 Rebuy 的独立 non-production project；任何无关项目禁止复用”。当前 tree 不公开 Supabase inventory 的组织/项目名称、ID、数量、套餐、host 或现有 region。
- 本提交已将 A1 原型边界改为 `resource/cost/secret Gate` 通过前仅可继续无资源后端原型、接口合同、测试矩阵和合成字段维护；不再暗示 G2-A0 未通过。
- `615de47` 的历史 diff 仍是不可重写的既有提交；其中已被 supersede 的 inventory 数量/套餐表述已从当前 tree 移除，本批不改写 Git history。
- 当前 tree 已脱敏，但既有公开 Git history 仍可能保留历史名称；Owner 已授权公开历史，本批不做破坏性 rewrite。
- （该修复批次的历史状态）本提交修复已完成；exact new head 当时待独立复审。此处不预写复审 GO、PR、Actions 或 merge 结果。

## 7. 停止、回退与遗留风险

完整资源、费用、密钥、Auth、DB、Storage、OAuth、SMTP、部署和 Production Gate 继续关闭；仅允许本文件第 8 节记录的最小资源存在性/基础预检。若后续发现项目/组织/区域隔离不清、费用边界未确认、真实 PII/secret 进入证据、callback 可重放或 open redirect、MFA 恢复缺少双人审计、SSR 串线或 token 窗口被误报为即时失效，应立即停止并保留脱敏失败记录。

本批回退只针对本地 docs-only 提交：可回退该提交或追加带日期的纠正，不使用 force/reset，不修改 G0/P1、代码、依赖、workflow、外部资源或 Production。将来资源的 expiry/cleanup 必须以[资源成本与密钥 Gate 模板](../../../templates/G2-A1-资源成本与密钥Gate模板.md)记录，并在不保留原值的前提下完成审计。

已知风险：Supabase 官方文档、套餐、区域、Auth/SSR API、默认权限和 SMTP 限制可能继续变化；Node 24 项目设置与 Node 22 Production 构建元数据的历史差异仍未解决；provider 技术实施与候选选择比较、session 方案和 GDPR/税务结论尚未开始。组织、项目、计划、区域和 quote 事实仅来自第 8 节管理面预检，不能从本批证据推导为技术或生产通过。

## 8. 2026-08-28｜Free Supabase 资源存在性与基础预检（历史资源快照；当前 B1 状态见 B1 配置/能力预检证据与 B1 风险 Gate 证据）

本节取代第 4 节中“尚无独立项目”的无资源阶段快照；不删除历史记录，也不把资源管理面状态写成 Auth 运行证据。当前 B1 最小连接及复审收口不在本 Entry preparation 记录中，详见[B1 风险 Gate 证据](../2026-08-28-b1-risk-gate/README.md)；配置/能力只读预检见[B1 配置/能力预检证据](../2026-08-28-b1-capability-preflight/README.md)。

- 独立 Supabase 组织 `Rebuy Lab` 已创建，Supabase connector 已核验 `plan=Free`。
- 独立项目 `rebuy-auth-spike` 已创建于 `eu-central-1`（Frankfurt），用途仅为 EU non-production Auth spike，数据模式为 synthetic-only。
- provider project quote 实际返回 `amount=0`、`recurrence=monthly`；API 未返回 currency。Owner 已确认该实际 quote，随后已完成 `confirm_cost`。此 quote 不等于税费、Spend Cap 或完整成本责任结论。
- provider 管理面报告项目状态 `ACTIVE_HEALTHY`。该状态只证明资源存在且健康，不证明 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 技术通过。独立运行时复审期间 connector 无法再次列出精确目标，当前管理面状态无法复验；此前 B1 health `200` 仅为当时运行窗口的时间界定证据。
- 没有读取、记录或传播 secrets、keys、passwords、环境变量值、host、URL、project ref、组织/项目 ID 或其他账号资源标识；没有配置 Auth/DB/Storage/OAuth/SMTP，没有建表、写数据、创建真实账号、部署、promote、alias 或 Production 操作。

### 脱敏操作追溯

- 日期：2026-08-28（Europe/Rome）。
- 操作类别：Chrome 创建 Free organization；Supabase connector `get_organization`、`get_cost`、`confirm_cost`、`create_project`、`get_project`。
- 精确操作分钟未保留；没有记录或保留 organization/project ID、ref、host、URL、key、secret、password 或其他凭据。

### Gate 结果

| Gate | 当前状态 | 证据/允许范围 | 继续关闭 |
|---|---|---|---|
| 最小资源存在性/基础预检 | **已打开并完成（窄范围）** | 组织/Free 计划、项目名称、区域、quote 确认、管理面健康状态 | Auth、DB、RLS、Storage、OAuth、SMTP、SSR |
| 完整 resource/cost/secret | **关闭** | 仅保留脱敏事实并设计后续风险 Gate | secret/env、密钥责任、税费/Spend Cap 完整确认、任何技术连接 |
| 真实数据与 Production | **关闭** | 无 | 真实客户/商户/PII、真实账号、部署、Production/promote/写入 |

**历史时点（Entry preparation 完成时）：** 下一步是新的最小 Auth spike 设计与风险 Gate。当前 B1 evidence 与配置/能力预检证据已记录 A1-B1 最小技术范围“已授权/待执行”，独立安全复审已完成且首轮 finding 已关闭，详见[B1 风险 Gate 证据](../2026-08-28-b1-risk-gate/README.md)与[B1 配置/能力预检证据](../2026-08-28-b1-capability-preflight/README.md)。Free 计划与 Pro 专属 session 配置之间的差异必须在设计中单独处理；当前仍不读取或传播 secret、service_role、secret key、db password，不把 `ACTIVE_HEALTHY` 外推为技术通过；完整 Auth/资源/Production Gate 继续关闭。

当前残余风险：`prototype/.env.local` 仍是 ignored、owner-only 的本地隔离文件；后续 expiry/cleanup 尚未在本记录中完成，不能把“ignored”表述为已清理。当前运行时复审期间 connector 无法再次列出精确目标，当前管理面状态无法复验；请以[B1 配置/能力预检证据](../2026-08-28-b1-capability-preflight/README.md)与[B1 风险 Gate 证据](../2026-08-28-b1-risk-gate/README.md)中的脱敏收口为准。
