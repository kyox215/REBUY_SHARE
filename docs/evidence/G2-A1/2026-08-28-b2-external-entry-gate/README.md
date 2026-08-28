# G2-A1-B2 外部入口 Gate 设计与资源预检

文档状态：**B2 external entry Gate design/preflight complete；不是 B2/Auth 技术通过**
记录日期：2026-08-28（Europe/Rome）
日期边界：资源核对始于 2026-08-28；本批文档收口于 2026-08-29（Europe/Rome）。资源事实不因文档收口日期变化而被写成持续健康保证。
阶段：G2-A1 / B2 外部入口 Gate 设计、只读资源刷新与本地 preflight
风险路由：**关键（critical）**；执行代理 `luna_worker / max`；默认单一写入者；静态验证 + 独立安全审查
环境：docs-only worktree；无 hosted Auth/DB/Storage/SMTP/OAuth 写入，无部署
代码/部署引用：`main@b3e53a71ca40729b139724a492e8d20afd02f341`；deploy/environment ref：`N/A`

本 README 是本批脱敏证据摘要，不是第二份状态源。当前阶段状态、Owner 决策和下一动作以[项目状态与阶段台账](../../../15-项目状态与阶段台账.md)为准；阶段合同见[G2-A1 准备与资源门禁](../../../stages/G2-A1-Auth-Spike准备与资源门禁.md)。

## 1. 目标、范围与结论

本批只完成 B2 外部入口的设计与 preflight：把后续 E1–E5 的允许动作、依赖、停止条件、回退/清理和证据责任写成可审查的 Gate，并刷新当前可用资源与本地隔离事实。

结论：

- **已完成**：B2 external entry Gate design/preflight；可供独立审查。
- **可在本 Gate 独立审查并合并到 `main` 后自动打开的下一动作**：E1 local bootstrap，但仍只限本地配置、合成数据、隔离端口和缓存复用。
- **仍关闭**：E2 local email OTP/invite、E3 Google、E4 Apple、E5 hosted callback/linking/invite、custom SMTP、hosted Auth writes，以及 DB business schema、Storage、Production、deploy。
- 该结论不等于 B2/Auth/G2-A1 通过，不产生真实登录、用户、邮件、OAuth callback、session、MFA、DB 或 Storage 证据。

本批非目标：不改源码、workflow、package、lockfile、env、配置或生成物；不创建/连接/修改 hosted Auth、OAuth、SMTP、DB、Storage；不读取或保存 secret；不创建 Google/Apple client；不发送邮件；不部署 Preview/Production；不连接生产或真实业务数据。

## 2. 远端 main 与交付边界事实

只读核对结果：

| 项目 | 结果 | 边界 |
|---|---|---|
| 当前 `main` | PR #13 的 docs-only closeout merge=`b3e53a71ca40729b139724a492e8d20afd02f341` | 仅作为本批 docs baseline；不执行 direct push |
| main Actions | run=`33212054195`，job=`98987321203`，success；`test:auth` 12 项且仅运行一次 | 证明 exact main 的 CI 结果，不证明 Auth 运行 |
| GitHub deployments | `0` | 不等于未来部署已授权 |
| Vercel | 仍有 3 个既有 READY deployments；本批无新增部署 | 不打开 Preview/Production/promote/alias |
| 本批外部写入 | 无 | 未 push、未建 PR、未运行 hosted Auth/DB/Storage/SMTP/OAuth、未部署 |

## 3. 资源只读刷新（不把历史快照写成持续健康）

- Supabase connector 当前只显示另一账号下的资源，不能列出本目标；本批不尝试切换账号、访问其他项目或以 connector 缺失推断目标资源不存在。
- 通过已登录 Chrome 控制台的只读页面，曾确认目标为独立 Free、EU Central/Frankfurt、状态 `ACTIVE_HEALTHY` 且未暂停；该管理面观察是时间界定事实，不是当前持续健康或 Auth 通过证据。
- 脱敏能力观察：Email provider 开启；signup 与 email confirmation 开启；Phone、Google、Apple、manual linking、custom SMTP 关闭；Site URL 仅归类为 local/default；redirect allowlist 条目数为 `0`；TOTP 能力开启；Phone MFA 关闭；Free session controls 受计划限制。
- 临时浏览器标签已关闭；没有 Save、Enable、Create、Reveal、Copy 或其他配置写入。
- 不记录目标资源的组织名、项目名、host、URL、ref/ID、key、secret、密码、cookie、OTP、TOTP seed、真实邮箱或其他真实 PII。

## 4. 本地 preflight 事实

| 范围 | 只读事实 | 结论/限制 |
|---|---|---|
| Supabase CLI | `2.101.0` | 仅记录版本；未执行 hosted 写入 |
| Docker | client `29.5.2` / server `29.2.1`，Linux arm64；可达 | running `14` / total `19` 仅作为计数；不干预现有容器 |
| Mailpit/缓存 | Mailpit 不在当前 `PATH`；缓存包含 Supabase 常见栈与 Mailpit，但 exact compatibility 未确认 | E1 必须实际确认；不能把缓存存在写成可运行 |
| Rebuy 本地资源 | 未发现 Rebuy 容器、config、migrations 或 harness | E1 需要新建最小隔离本地配置；不连接 hosted 项目 |
| 端口保护 | `54321–54324` 被现有 SSH 监听；本批不触碰；`55320–55329` 当前全空闲 | E1 推荐使用 `55320–55329`，冲突即 STOP |
| Node/复用 | Node 20 为默认；Node `22.12.0` 已安装；现有 SSR、callback、契约测试可复用 | 不在本批改变 Node、依赖或源码 |
| 忽略规则 | env/temp 类路径已有 ignore 覆盖 | E1 仍须在实际 worktree 重新验证 ignored、untracked、权限和清理 |

### 4.1 CLI 离线模板与 E1 隔离映射

只把 CLI 模板端口作为规划参考：shadow `54320`、API `54321`、DB `54322`、Studio `54323`、inbucket `54324`、analytics `54327`、pooler `54329`、edge inspector `8083`。

E1 的推荐隔离映射为：shadow `55320`、API `55321`、DB `55322`、Studio `55323`、inbucket `55324`、analytics `55327`、pooler `55329`；55325/55326/55328/55330 以后仅在实际配置确认后分配给额外 SMTP、POP3 或 inspector。端口、镜像、健康探针和兼容性必须以 E1 实际结果为准，不得从模板猜测。

## 5. Gate 分层与允许动作

| Gate | 状态 | 允许动作 | 依赖/停止条件 |
|---|---|---|---|
| B2 external entry design/preflight | **本批完成** | 独立安全审查、文档 closeout；审查通过后可审议 E1 | 不等于 B2/Auth 运行通过 |
| E1 local bootstrap | 待独立审查后可打开 | 仅新建 Rebuy local config、合成数据、55320–55329 隔离映射、复用本地缓存；保持现有 SSH/容器不变 | 拉新镜像、非零费用、端口冲突、修改现有容器或无法清理即 STOP，并另开 Gate |
| E2 local email OTP/invite | **CLOSED** | 只有 E1 健康后才可另开 local catcher 方案 | 成功邮件只能投递/捕获于 local catcher；local-only admin/service-role 若确有需要须另开专项，绝不进客户端、仓库或日志 |
| E3 Google | **CLOSED** | 另开 exact action-time Gate 后再决定是否创建独立测试 Cloud project/client | 额外 scope、billing、secret、控制台写入或真实身份越界即 STOP |
| E4 Apple | **CLOSED / PAID-BLOCKED** | 保持 disabled；另开付费/注册/密钥 Gate 后才可评估 | 不注册、不付款、不生成 client secret 或 `.p8` |
| E5 hosted callback/linking/invite | **CLOSED** | 另开 exact action-time Gate 后才可进行 hosted Auth 写入/运行 | 需要 hosted Auth/OAuth/SMTP/真实邮件/真实身份即停止本批 |
| DB/Storage/Production/deploy | **CLOSED** | 无 | 始终需要独立专项与 Owner Gate；不得由 E1–E5 自动打开 |

E1 若完成并通过独立审查，只打开 local bootstrap；不自动打开 E2–E5、B3、P2 或 Production。每个 Gate 都必须有独立的环境、密钥责任、expiry/cleanup、回退和证据入口。

## 6. 邮件与 hosted SMTP 边界

当前 hosted 默认 SMTP 只面向项目团队预授权地址；限额是动态的、无 SLA、仅适合非生产探索。早期观察到的每小时 `2` 封仅作为历史基线，不作为当前承诺或验收门槛。

- `.invalid` 仅用于 no-send、负向和反枚举路径，不得用于成功 OTP/Magic Link。
- 成功 OTP/Magic Link/invite 只能使用专用 synthetic mailbox/domain、隔离 local catcher，或在单独 Gate 批准后使用 custom SMTP；禁止真实个人或客户邮箱。
- custom SMTP credential/secret、持久连接、费用、域名和控制台配置继续 CLOSED；每次实际动作都需 action-time Gate，不能用“全部批准”替代。

## 7. Google 独立测试方案（E3 仍关闭）

官方资料复核结论：使用独立 Google Cloud 测试项目，OAuth consent publishing status 设为 Testing；Testing 通常最多允许 `100` 个 test users，授权通常 `7` 天，具体以当前 Google 控制台和政策提示为准。请求范围仅限 `openid`、`email`、`profile`，不申请 Gmail、Drive、联系人或其他额外 scope。

执行前置：

- 需要独立测试 Cloud project、Web OAuth client、精确 non-production redirect、合成 Google identity 和 support contact；Client ID/secret 只进受控 secret store，不进仓库、客户端、截图、日志或本 README。
- 任何控制台创建、保存、secret 生成或真实身份授权都必须有独立 action-time Gate；本批不执行。
- 发现 billing 提示、非零费用、额外 scope、生产 redirect、provider token/refresh token 落地或无法清理，立即 STOP。

依据：[Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)、[Google Cloud 管理 App audience](https://support.google.com/cloud/answer/15549945?hl=en)、[Supabase Login with Google](https://supabase.com/docs/guides/auth/social-login/auth-google)。

## 8. Apple 独立测试方案（E4 仍关闭）

官方资料复核结论：Web OAuth 需要 Team ID、App ID、Services ID、client secret、受控 `.p8` 和 relay/邮件配置；Apple Developer Program 官方年费为 `99 USD/year`（地区货币可能不同）。

按“免费优先”决定：Apple provider 继续 disabled，并标记 **PAID-BLOCKED**。这不阻塞 E1/E2 的局部本地工作，但阻塞完整三入口、B2 整体与 G2-A1 Exit；本批不付款、不注册、不创建 Apple client、不生成或读取 `.p8`/client secret。

依据：[Supabase Login with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple)、[Apple Developer Program membership](https://developer.apple.com/programs/whats-included/)、[Apple compare memberships](https://developer.apple.com/support/compare-memberships/)。

## 9. 回退、清理、STOP 与残余风险

回退与清理合同：

- E1 回退只删除本批新建的 local config、合成 fixture、local catcher 和 55320–55329 新建容器；不得停止、修改或删除既有 SSH 监听、既有容器、54321–54324 端口对象或远端资源。
- 发现 env 未被 ignore、权限不符合、凭据/PII 进入仓库或日志、端口冲突、镜像需新增下载、费用变化、无法证明环境隔离、需要 Save/Enable/Create/Reveal/Copy、connector 目标漂移或需要 hosted 写入时，立即 STOP；只留脱敏失败分类和影响范围。
- expiry/cleanup 完成后再次核对 tracked tree、ignored env/temp 类别、local container 清单和端口，不保存原始 secret、邮件、token、cookie 或测试身份。
- 没有可验证清理点时，不把 E1 或 E2 标记为通过；回到最近可验证 docs-only 状态并追加 Owner 决定。

残余风险：connector 当前无法列出目标资源；管理面健康不能证明持续健康；Mailpit exact compatibility 未确认；55320–55329 目前空闲但未来可能变化；Free session/SMTP 限制可能变化；Google/Apple 客户端、hosted callback/linking/invite、SMTP、Auth/session/MFA、DB/Storage 和真实邮件均未运行；本批无浏览器 Auth runtime evidence。

## 10. 官方资料复核（2026-08-28，规划依据）

Supabase changelog index 已按专项规则刷新；本批仅写入规划和 Gate，不依赖管理 API 或 schema 行为。以下官方页面用于下一 Gate 的重新核对，不是运行通过证据：

- [Supabase Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
- [Supabase Identity Linking](https://supabase.com/docs/guides/auth/auth-identity-linking)
- [Supabase Passwordless email](https://supabase.com/docs/guides/auth/auth-email-passwordless)
- [Supabase Login with Google](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Supabase Login with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Supabase Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls)
- [Supabase changelog](https://supabase.com/changelog.md)
- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
- [Google App audience and Testing](https://support.google.com/cloud/answer/15549945?hl=en)
- [Apple Developer Program](https://developer.apple.com/programs/whats-included/)
- [Apple compare memberships](https://developer.apple.com/support/compare-memberships/)

链接内容应在执行 E2–E5 前按当日版本、区域、计划和实际配置再次复核；官方页面不能替代 isolated runtime evidence。

## 11. 验证与证据等级

| 检查 | 结果 | 说明 |
|---|---|---|
| `git diff --check` | 待最终收口后运行 | 仅检查尾随空格和 patch 问题 |
| 相对 Markdown link/fragment | 待最终收口后运行 | 覆盖变更 Markdown 与本 README 新增链接 |
| fence/backtick 配对 | 待最终收口后运行 | 不把代码块作为运行证据 |
| sensitive/stale-current/diff scope | 待最终收口后运行 | 不扫描或回显 secret/env 原值 |
| 代码质量/应用浏览器/Auth runtime | 未运行 | 本批 docs-only；不重复源码验证，也无合法 Auth 凭据 |
| hash | 未做 | 非确定性生成或文件传输，不存在异常覆盖迹象 |

证据等级为**规划 + 本地静态 + 外部资源只读摘要**。它只证明 Gate 设计和 preflight 已记录，不证明 E1 local runtime、E2 邮件、E3/E4 OAuth、E5 hosted Auth、DB/Storage、Staging 或 Production。

## 12. 关联文档

- [G2-A1 准备与资源门禁](../../../stages/G2-A1-Auth-Spike准备与资源门禁.md)
- [A1 Auth Spike 执行合同](../../../10-A1-Auth-Spike执行合同.md)
- [发布与 Supabase 连接记录](../../../11-发布与Supabase连接记录.md)
- [全局执行总计划](../../../14-全局执行总计划.md)
- [项目状态与阶段台账](../../../15-项目状态与阶段台账.md)
- [阶段记录索引](../../../stages/README.md)
- [B2 本地安全基础证据](../2026-08-28-b2-local-foundation/README.md)
