# G2-A1 无资源 Entry preparation 证据

记录日期：2026-08-28（Europe/Rome）
阶段状态：**G2-A1 技术阶段未开始；无资源 Entry preparation 已完成/待审；resource/cost/secret Gate 关闭**
证据级别：本地静态（docs-only）+ 已完成的 G2-A0 远端闭环摘要
执行范围：仅 Markdown 文档、阶段导航、资源 Gate 模板和 Auth 实测矩阵模板

## 1. 本批结论

本批完成 G2-A1 的无资源准备：建立四批后续执行合同、资源/成本/密钥 Gate 字段、Auth 实测矩阵字段、官方资料刷新和脱敏证据边界。**没有开始 G2-A1 Auth 技术验证**，没有创建或连接 Supabase/Auth/DB/Storage/OAuth/SMTP，没有读取 secret/env/PII，没有创建真实账号或 fixture，没有部署、promote、alias、Production 写入或 UI/代码变更。

resource/cost/secret Gate 继续关闭。下一步只能在新的独立 non-production 授权明确 provider、组织、项目、计划、区域、环境、精确费用、Spend Cap、密钥责任和停止联系人后，重新打开资源 Gate；本批不从通用价格推断 exact cost，也不复用与 Rebuy 无关的项目。

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

## 4. 公开 Supabase inventory 摘要

允许公开的最小摘要仅为：**连接账户有 1 个 Pro 组织、2 个与 Rebuy 无关的 active projects、没有 Rebuy 项目。** 本批不记录组织名、项目名、项目 ID、host、现有项目 region、key、token 或环境值；两个既有项目严禁复用或连接。

候选只是 proposal，尚未获得组织确认、exact cost 或资源 Gate 通过：现有 Pro 组织内新建独立 Rebuy non-production project，候选区域 `eu-central-1`（Frankfurt），开启 Spend Cap、无 add-on、synthetic-only。该 proposal 不等同于 provider/plan/region 已选择，不授权创建项目。

精确成本只能在指定组织后，由 provider `get_cost` 获取并记录 quote、recurrence、tax、spend cap，再由 Owner 明确确认；通用价格页不能替代本项目 exact cost。

## 5. 2026-08-28 官方来源刷新

本节仅记录 Supabase 官方来源的日期化规划依据；来源不会替代 A1 的实际版本、配置和隔离环境证据。

| 官方来源 | 刷新事实 | 规划影响 |
|---|---|---|
| [Node.js 20 support changelog](https://supabase.com/changelog/45715-deprecation-notice-dropping-support-for-node-js-20) | Supabase client libraries 的 Node 20 支持已于 2026-06-30 结束；仓库 Node 22 符合 | A1 运行时复核以 Node 22 为基线；本批不改代码/config |
| [OAuth token endpoint breaking change](https://supabase.com/changelog/45468-breaking-change-oauth-token-endpoint-will-return-http-200-instead-of-201) | `/v1/oauth/token` 自 2026-06-01 成功响应为 HTTP 200；客户端应接受任意成功 2xx，而非硬编码 201 | callback 矩阵保留 2xx 兼容检查 |
| [Data API exposure breaking change](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically) | 新表默认可能不自动暴露给 Data/GraphQL API；grants 与 RLS 分离 | A1 只做最小 reachability 观察；完整 grants/RLS 归 A3/A4 |
| [Free-tier email template change](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier) | 新 Free 项目使用默认 SMTP 时认证邮件模板自定义受限；Pro 或配置自有 SMTP 不受该限制 | B1 必须记录 plan/SMTP；不发送真实邮件 |
| [Available regions](https://supabase.com/docs/guides/platform/regions) | 精确 EU 候选为 `eu-central-1` Frankfurt；region 是数据位置控制，不等于 GDPR 合规 | GDPR、税务、跨境和处理者合同转 A5/专业顾问 |
| [Control your costs](https://supabase.com/docs/guides/platform/cost-control) / [Billing FAQ](https://supabase.com/docs/guides/platform/billing-faq) | Spend Cap 仅适用于 Pro，且不是细粒度预算/告警；账单与税费依赖实际组织和账单地址 | 先指定组织，再取 exact cost/recurrence/tax 并由 Owner 确认 |
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
- 未启动独立运行时审查：本批只形成文档与模板；资源 Gate 关闭，尚无 Auth/DB/Storage/Provider 实施。文档级复核仍需由主代理/Owner 按 Gate 处理。

## 7. 停止、回退与遗留风险

资源、费用、密钥、Auth、DB、Storage、OAuth、SMTP、部署和 Production Gate 继续关闭。若未来准备进入技术阶段，发现项目/组织/区域隔离不清、费用未确认、真实 PII/secret 进入证据、callback 可重放或 open redirect、MFA 恢复缺少双人审计、SSR 串线或 token 窗口被误报为即时失效，应立即停止并保留脱敏失败记录。

本批回退只针对本地 docs-only 提交：可回退该提交或追加带日期的纠正，不使用 force/reset，不修改 G0/P1、代码、依赖、workflow、外部资源或 Production。将来资源的 expiry/cleanup 必须以[资源成本与密钥 Gate 模板](../../../templates/G2-A1-资源成本与密钥Gate模板.md)记录，并在不保留原值的前提下完成审计。

已知风险：Supabase 官方文档、套餐、区域、Auth/SSR API、默认权限和 SMTP 限制可能继续变化；Node 24 项目设置与 Node 22 Production 构建元数据的历史差异仍未解决；exact cost、组织确认、provider 选择、session 方案和 GDPR/税务结论均未发生。任何一项都不能从本批准备证据推导为技术或生产通过。
