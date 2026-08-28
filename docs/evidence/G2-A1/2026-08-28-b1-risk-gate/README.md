# G2-A1 A1-B1 最小 Auth spike 风险 Gate 与复用预检

记录日期：2026-08-28（Europe/Rome）
批次：G2-A1 / A1-B1 risk Gate 设计与复用优先预检
证据级别：本地静态（docs-only）+ 外部资源存在性核验摘要
阶段状态：**G2-A1 技术阶段未开始；独立安全复审已完成、首轮 finding 已关闭；Owner/主代理批准打开 A1-B1 最小技术范围（已授权/待执行）；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 关闭**

本 README 是批次证据摘要，不是第二份状态源。当前阶段状态、Owner 决定和下一动作以[项目状态与阶段台账](../../../15-项目状态与阶段台账.md)为准；阶段合同见[G2-A1 准备与资源门禁](../../../stages/G2-A1-Auth-Spike准备与资源门禁.md)。

## 1. 本批范围与结果

本批只做以下工作：

- 从远端 `main=3b2b8aed4c97b64f36338021adae0a45bec2215d` 建立隔离 docs-only worktree 与 `codex/g2-a1-b1-risk-gate` 分支。
- 完整读取并对照 G2-A1 阶段合同、A1 执行合同、发布与 Supabase 连接记录、资源 Gate 模板、Auth 矩阵模板和当前 Entry preparation evidence。
- 使用 `rg` 对 prototype 现有 Supabase client、SSR client、配置/env 名称、health route、Auth UI/handlers/types/tests 做定向复用预检；不修改代码。
- 在阶段记录、A1 合同、状态台账、连接记录和阶段索引中追加最小 Auth spike 风险 Gate，并保持唯一状态源关系。

本批没有修改源码、依赖、lockfile、workflow、配置、env、生成物或外部资源；没有读取 project URL/key、secret、service_role、DB password 或任何环境值；没有配置 Auth/DB/Storage/OAuth/SMTP、建表、写数据、创建真实账号、部署或触碰 Production。

## 2. 已核验资源事实（仅管理面摘要）

| 项目 | 事实 | 证据边界 |
|---|---|---|
| 组织 | `Rebuy Lab` | Supabase connector 核验为独立组织；不记录组织 ID |
| 计划 | `Free` | 只证明当前组织计划；不推断 Pro 专属 session 配置能力 |
| 项目 | `rebuy-auth-spike` | 独立 Rebuy non-production 项目；不记录 project ref/ID/host/URL |
| 区域 | `eu-central-1`（Frankfurt） | 数据位置选择；不等于 GDPR、税务或跨境合规结论 |
| 数据模式 | `synthetic-only` | 只允许合成标签与 `.invalid` 地址；不使用真实 PII |
| quote | `amount=0`、`recurrence=monthly` | provider project quote 实际返回；API 未返回 currency |
| quote 确认 | Owner 已确认实际 quote，并完成 `confirm_cost` | 不等于税费、Spend Cap 或完整成本责任确认 |
| 管理面状态 | `ACTIVE_HEALTHY` | 只证明资源存在且管理面健康；不证明 Auth/MFA/session/DB/RLS/Storage/OAuth/SMTP/SSR |

## 3. 风险 Gate 当前决定

| Gate | 当前状态 | 条件与限制 |
|---|---|---|
| 最小资源存在性/基础预检 | 已完成（窄范围） | 仅核对组织、Free 计划、项目标签、区域、quote 确认和管理面健康 |
| A1-B1 最小 Auth spike 风险 Gate | **已授权/待执行** | 独立安全复审已完成，首轮文档状态漂移 finding 已关闭；仅可只读取得 project URL + modern publishable key，写入 gitignored local env，复用/定向扩展现有 SSR/client/health 做 EU non-production synthetic-only 连接验证，并记录 Free 限制、STOP/cleanup |
| 完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate | **关闭** | 不读取或使用 secret/service_role/secret key/db password，不配置 Auth/OAuth/SMTP/Storage，不建表/写数据，不创建真实账号或 PII，不部署、不 promote、不 alias、不触碰 Production |
| G2-A1 技术阶段 | **未开始** | 不记录 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 运行时通过 |
| P2–P8 / Production | **关闭** | 不部署、不 promote、不 alias、不写入真实业务数据 |

### 3.1 已授权但待执行的 B1 最小动作

独立安全复审已完成，首轮 finding 已关闭，Owner/主代理已批准打开 A1-B1 最小技术范围；该范围仍待执行，按以下最小顺序进行：

1. 重新核对当前 Supabase 官方 docs/changelog、Node/SDK 版本和 Free 计划限制，并记录日期/版本。
2. 只读取得 project URL + modern publishable key；确认 `.gitignore` 阻止 env；只存入 gitignored local env 或受控 Preview env。
3. 复用现有 browser/SSR client 与 `/api/health/supabase`，在 local synthetic-only 连接中验证只依赖 publishable key，不依赖或读取 service_role、secret key、DB password。
4. 记录配置缺失、远端不可达、非 2xx、可达等脱敏结果；不把 health 200 或管理面健康写成 Auth 技术通过。
5. 记录 Free limitations、STOP 联系人、expiry/cleanup、回退和清理摘要；不启用 Auth/OAuth/SMTP/Storage、不建表、不写数据、不创建真实账号。

project URL/key 原值不得写入仓库、证据、聊天、日志、截图或客户端 bundle。以上是窄范围、已授权但待执行的 B1 动作清单，不是 broad waiver（全局豁免），也不代表 G2-A1 Auth/B1 技术通过；本 README 不预写连接成功。

## 4. 责任、审查与停止

| 责任项 | 指定与边界 |
|---|---|
| Product / cost / stop / provider admin | Hexiang Huang；负责范围、费用确认、provider 管理面和立即停止 |
| 技术执行 | Codex 自动化执行；后续由 `luna_worker / max` 执行明确批次；Owner 保留责任和停止权 |
| 独立安全复审 | 首轮独立只读 Codex reviewer 结论为 NO-GO；实现代理修复状态 finding，主代理只读核对精确 diff 后关闭 finding；Owner/主代理当前批准继续，但不扩大本批边界 |
| secret/key owner | Hexiang Huang；原值只在 provider/Vercel secret store 或 gitignored local env；证据只记录引用/摘要 |
| 证据保管 | 仓库脱敏摘要 + provider 审计记录；不保留 URL/host/ref/ID、token、cookie、OTP、TOTP seed、secret 或真实 PII |
| 法律/隐私/税务 | A5 / 专业顾问待处理；不在 A1 作 GDPR、税务、跨境或处理者合同结论 |

以下任一情况都必须 STOP：非零费用、add-on/upgrade、生产或真实 PII 连接、service_role 依赖、secret/URL/key 进入仓库/日志/证据、无法证明 env 隔离、callback/health 错误泄露、无法清理或其他越界。停止后只保留脱敏时间线、错误分类、影响范围和 Owner 决定，不用绕过方式继续。

## 5. 复用优先预检

预检只针对当前仓库已有实现，结论如下：

| 能力 | 已发现实现 | 结论 |
|---|---|---|
| 浏览器 client | `prototype/lib/supabase/client.ts` 使用 `createBrowserClient` 与统一配置 | **复用**；不新建第二个 browser client |
| SSR client | `prototype/lib/supabase/server.ts` 按调用创建 `createServerClient`，读取 request cookies 并保留受控写回 | **复用/定向扩展**；B1 只核验每请求边界，不重复新建 factory |
| 配置/env | `prototype/lib/supabase/config.ts` 与 `.env.example` 统一使用 `NEXT_PUBLIC_SUPABASE_URL`、`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`，缺失/非法配置受控失败 | **复用**；不新增别名或 secret env |
| health | `prototype/app/api/health/supabase/route.ts` 请求 `/auth/v1/settings`，固定最小 JSON，`no-store`，覆盖 503/502/200 | **复用/定向扩展**；B1 仅验证可达与脱敏，不以 200 作为 Auth 通过 |
| Auth UI | `prototype/app/account/login/LoginPrototype.tsx` 的 Apple/Google/邮箱 OTP 是本地演示，显示等待 A1/界面演示，不创建 session | **保留演示边界**；不把点击改成真实 Auth |
| Auth handlers/hooks/types/tests | 定向扫描未发现可直接复用的真实 Auth handlers、hooks、业务 types 或独立 test/spec 目录 | **暂不新建**；B1 若需要扩展，先重新声明文件边界 |
| 依赖/运行时 | `@supabase/ssr=0.12.5`、`@supabase/supabase-js=2.112.4`、Node `22.x`、pnpm `10.33.3` 已固定 | **复用**；本批不改依赖、lockfile、workflow、配置或源码 |

选择总结：复用现有 client/config/SSR/health；必要时在原文件内定向扩展；暂不新建 Auth 业务 handler、hooks、types 或测试套件。该选择不证明现有骨架已连接或通过 A1。

## 6. 本批验证

| 检查 | 结果 |
|---|---|
| 远端基线 | `git fetch origin main` 后，`git rev-parse origin/main` 为 `3b2b8aed4c97b64f36338021adae0a45bec2215d` |
| 隔离 worktree | `/private/tmp/rebuy-g2-a1-b1-risk-gate`；分支 `codex/g2-a1-b1-risk-gate`；基于上述 main |
| 文件范围 | 仅 Markdown；未改 prototype 源码、package、lockfile、workflow、配置、env 或生成物 |
| 文档静态检查 | `git diff --check`；相对链接/fragment；Markdown fence/backtick；当前状态 stale；敏感值/URL/host/ref/key/ID 扫描 |
| 构建类检查 | 不运行 build/lint/typecheck：源码、依赖、workflow、lockfile、配置、生成物均未变化；后续连接阶段必须重新验证 |
| 独立复审 | 首轮结论为一项文档状态漂移 NO-GO；实现代理已按范围修复，主代理只读核对精确 diff 后关闭 finding；不声称 reviewer 第二轮或未保留的具体时间 |
| 哈希 | 未做；本批不是确定性生成或文件传输校验，且无异常覆盖迹象 |

## 7. 独立安全复审收口与 Owner/主代理当前授权

- 首轮独立安全复审结论为 **NO-GO**；唯一的 P1 finding 是当前文档状态漂移，另有一项 P2 旧证据表述已按历史快照标注。
- 实现代理已在同一 worktree 内按范围修复；主代理只读核对精确 diff 后关闭该 finding。本记录不声称 reviewer 第二轮复审，也不补写未保留的具体分钟。
- Owner 当前消息批准继续；该批准仅打开 A1-B1 最小技术范围：只读取得 project URL + modern publishable key、仅存入 gitignored local env、复用/定向扩展现有 SSR/client/health 做 EU non-production synthetic-only 连接验证、记录 Free 限制与 STOP/cleanup。
- 这不是 broad waiver（全局豁免）。完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续 CLOSED；service_role、secret key、db password 继续禁止；G2-A1 技术阶段仍未开始，B1 仅为“已授权/待执行”，不代表 G2-A1 Auth 或 B1 已通过。

## 8. 关联文档

- [G2-A1 准备与资源门禁](../../../stages/G2-A1-Auth-Spike准备与资源门禁.md)
- [A1 Auth Spike 执行合同](../../../10-A1-Auth-Spike执行合同.md)
- [发布与 Supabase 连接记录](../../../11-发布与Supabase连接记录.md)
- [项目状态与阶段台账](../../../15-项目状态与阶段台账.md)
- [全局执行总计划](../../../14-全局执行总计划.md)
- [G2-A1 Entry preparation 证据](../2026-08-28-entry-preparation/README.md)
