# G2-A1-B1 配置/能力只读预检

文档状态：本批只读证据；B1 配置/能力只读预检已完成，等待独立安全复审；不代表 G2-A1 Auth 技术通过，也不打开 B2。
记录日期：2026-08-28（Europe/Rome）
执行：Codex 自动化执行，luna_worker / max，单一写入代理
独立审查：首次独立复审为 REVIEW NO-GO；本轮 findings 已按反馈修复，待定向复审；不预写 REVIEW GO、PR、Actions 或 merge；B2 开启前必须完成独立安全复审与 Owner/主代理 Gate
基线：从远端 main 的 3ef16ea5cd2869d7456127dd8236f0def7dde93a 建立本地隔离 worktree；本批不预写最终提交 SHA

## 1. 目标、范围与事实边界

- 目标资源标签为 Rebuy Lab / rebuy-auth-spike，Free，EU non-production synthetic-only，区域记录为 eu-central-1。
- 已登录 Chrome 的 Supabase dashboard Auth 配置页面顶部可见组织、项目和 Free 计划标签，确认本批访问的是指定目标；Auth 配置页未显示区域，因此区域只沿用既有资源记录，不由页面推断。
- Supabase connector 当前无法再次列出该精确目标，是已知管理面漂移；本批未尝试其他账号、组织或项目，也未执行 connector 外部写入。
- 仅打开 Auth configuration 页面做 DOM 只读观察；没有点击 Save、Enable、Create、Reveal 或 Copy，没有修改开关、文本框、provider、redirect、SMTP、hook 或任何资源。
- 没有打开 API Keys、SQL/Table Editor、数据库表、Storage 文件、Auth 用户列表或 Audit Logs 数据；没有读写 DB、Storage、用户、日志、OAuth client、SMTP credential、secret 或 service role。
- 不记录 project URL、host、project ref/ID、publishable key、secret、密码、token、cookie、OTP、TOTP seed、真实邮箱或其他真实 PII。

## 2. Auth Provider 与注册能力（dashboard 脱敏观察）

| 配置区域 | 只读观察 | 本批含义 |
|---|---|---|
| 新用户注册 | 允许注册：开启 | 仅为管理面配置观察，不是注册运行结果 |
| 手动 linking | 关闭 | 不执行 link/unlink |
| 匿名登录 | 关闭 | 与 G2-A0 政策一致，未进行匿名登录 |
| 邮箱确认 | 开启 | 没有真实邮箱或确认结果 |
| Email provider | 开启 | 不等于邮箱 OTP/Magic Link 已运行 |
| Phone provider | 关闭 | 不启用 phone/SMS MFA |
| Apple provider | 关闭 | 未创建或读取 Apple client/secret |
| Google provider | 关闭 | 未创建或读取 Google client/secret |
| 其他列表 provider | 页面列出的 provider 均为关闭 | 不比较或启用其他 provider |
| Custom providers | 未显示已配置 custom provider | 未点击 New Provider |

Email provider 的可见安全项为：secure email change 开启；secure password change 关闭；更新密码时要求当前密码关闭；防泄露密码能力页面提示仅 Pro 及以上可配置且当前未启用。页面可见 Email OTP 过期时间为 3600 秒、长度为 8 位；这些是管理面字段观察，不是 OTP 发送或验证证据。

## 3. URL、邮件与限流能力

| 页面 | 脱敏观察 |
|---|---|
| Site URL | 仅记录为 local/default；不保存文本框原值 |
| Redirect allowlist | No Redirect URLs；条目数为 0；未添加条目 |
| Email templates | 仅进入模板导航，不读取或修改消息内容 |
| SMTP | Enable custom SMTP 开关为关闭；未配置、保存或发送邮件；未将默认邮件服务当作已验证能力 |
| Email rate limit | 页面显示邮件发送限流字段受计划约束，未修改 |
| SMS rate limit | 页面显示为 30/h 且字段受限；未发送 SMS |
| Token refresh | 页面显示 150 requests/5 min |
| Token verification | 页面显示 30 requests/5 min |
| Anonymous sign-in | 页面显示 30 requests/h 且字段受限；匿名入口仍关闭 |
| Sign-up/sign-in | 页面显示 30 requests/5 min 且字段受限 |
| Web3 sign-up/sign-in | 页面显示 30 requests/5 min 且字段受限 |
| IP forwarding | 开关未开启；未改动 |

当前 Free 限制依据官方文档与 changelog：新建 Free 项目使用默认 SMTP 时不能自定义 Auth 邮件模板；自定义 SMTP 或付费计划才提供相应能力。本批没有启用自定义 SMTP、没有发生非零费用、没有发送真实邮件。

### 3.1 Hosted SMTP 与成功投递边界（B2 仍 CLOSED）

依据 [Supabase Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)、[Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits) 与 [Free 邮件模板变更](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier) 的当前约束：hosted 默认 SMTP 仅向项目团队预授权的邮箱地址发送；当前基线为每小时 2 封，具体限额可能变化；该默认服务无 SLA，仅适合非生产探索。

- `.invalid` 地址只用于 no-send、负向和反枚举路径，绝不能用于成功 OTP/Magic Link 投递。
- 成功 OTP/Magic Link 路径必须使用专用 synthetic test mailbox/domain、隔离 catcher，或在另行批准后使用 custom SMTP；本批不执行成功投递。
- custom SMTP credential/secret、费用、持久连接，以及任何浏览器/控制台配置动作继续 CLOSED；每次实际动作都需要 action-time Owner Gate，不能用总体批准替代。

## 4. MFA、session、攻击防护与 hooks

| 能力 | 只读观察 | 运行结论 |
|---|---|---|
| TOTP / App Authenticator | Enabled；页面显示每用户最多 10 个 factor | 仅为配置能力观察；没有 enrollment、seed 或验证 |
| Phone/SMS MFA | Disabled；页面提示 SMS MFA 仅 Pro 及以上 | 遵守 Owner 排除 phone/SMS MFA 政策 |
| Enhanced MFA security | Limit duration of AAL1 sessions 开启 | 仅配置观察，不等于 AAL2 流程已测试 |
| 单用户单 session | Free 页面控件 disabled | 没有改变或执行多设备 session 操作 |
| Session time-box / inactivity timeout | Free 页面控件 disabled | Pro 限制可见；没有运行时 session 结果 |
| Access token expiry | 页面显示 3600 秒 | 未执行 token 颁发、刷新或撤销测试 |
| Refresh token replay protection | 开启；reuse interval 页面显示 10 秒 | 未执行重放测试 |
| Captcha | Attack Protection 页面显示 Disabled | 未配置 captcha |
| Leaked password protection | 页面显示能力说明；Email provider 中未开启且提示 Pro 限制 | 不把它写成已启用 |
| Auth hooks | 未显示已配置 hook，仅显示 Add hook 入口 | 未创建、连接或测试 hook |
| Audit logs | 本批未打开日志数据 | 不对审计事件作存在或完整性结论 |

静态恢复码继续排除；备用 TOTP、受审计人工恢复、AAL2 强制时点与六类高风险动作双人复核仍按 G2-A0 政策留待后续专项，未在本批实施。

## 5. 官方资料刷新（规划依据，不是运行通过）

- [Server-side Auth client and getClaims](https://supabase.com/docs/guides/auth/server-side/creating-a-client)：服务端后续授权检查应使用受验证的 claims；不能仅信任共享 cookie 中的 getSession 用户对象。
- [Supabase sessions](https://supabase.com/docs/guides/auth/sessions)：session 生命周期与 Free 计划可配置边界需在后续独立测试中实测。
- [Supabase MFA guide](https://supabase.com/docs/guides/auth/auth-mfa)：TOTP、AAL 与 factor 状态仍需按测试矩阵验证。
- [Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits)：限流字段和 IP forwarding 需结合计划与入口测试。
- [Supabase Auth hooks](https://supabase.com/docs/guides/auth/auth-hooks)：hooks 只作为后续能力候选，本批未配置。
- [Email template customization on Free](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier)：Free 默认 SMTP 的模板限制已纳入 B2 风险。
- [OAuth token endpoint 2xx change](https://supabase.com/changelog/45468-breaking-change-oauth-token-endpoint-will-return-http-200-instead-of-201)：后续 callback/ token 测试接受成功 2xx，不硬编码单一状态码。

## 6. 复用优先结论

- 复用现有 prototype 的 config、browser client、SSR client 与 health route；不新建第二套 client、env 名称、handler 或测试框架。
- 本批没有代码、依赖、lockfile、workflow、配置或生成物变更；没有必要扩展现有实现。
- B1 配置/能力只读预检的产物是本证据与权威文档同步，不是 Auth 登录、用户、session、OAuth、SMTP、DB 或 Storage 实现。

## 7. B2 专项风险 Gate 草案（保持 CLOSED）

本节只定义下一批的入口和停止条件，不授权当前实施。独立安全复审完成并由 Owner/主代理明确打开前，B2 保持 CLOSED。

### 7.1 入口条件

1. 重新确认指定 Free、EU non-production、synthetic-only 目标；组织、项目、计划、区域或管理面状态不匹配即停止。
2. 通过独立安全复审；由 Owner/主代理明确记录 B2 Gate 决定、测试期限、cleanup/expiry、责任人与回退方式。
3. 仅允许 project URL 与 modern publishable key 进入已确认 ignored、owner-only 的 local env 或后续受控 Preview env；不得读取或使用 secret、service role、DB password，也不得将任何原值写入仓库、证据、日志、截图、聊天或客户端 bundle。
4. 复用既有 SSR/client/health；先用无配置和无网络依赖负向路径，再做合成环境连接。服务端授权设计应基于 getClaims/getUser 的当前官方语义，不把 getSession 用户对象当作授权依据。
5. 使用 .invalid 合成邮箱和虚构身份；禁止真实邮箱、真实账号、真实组织、真实订单、真实证件、真实支付资料与生产 callback。
6. 事先锁定 no-send 邮件捕获方案或隔离测试 SMTP；Free 默认 SMTP 模板限制、邮件 TTL、重放、限流和反枚举要有可复核证据。

### 7.2 三入口的逐项前提

| 入口 | B2 打开前的最小前提 |
|---|---|
| Apple | 独立测试 Services ID/client 与精确 non-production redirect；秘密只在受控 secret store；覆盖 relay/隐藏邮箱、首登无姓名、取消、state/nonce、重放和错误路径；不复用生产 client |
| Google | 独立测试 OAuth client 与精确 non-production redirect；仅 openid、email、profile；覆盖 PKCE、state、nonce、取消、错误、重放和 token 不留存；不申请额外 scope |
| Email OTP / Magic Link | 仅 .invalid 合成地址；使用本地 catcher 或隔离测试 SMTP；覆盖 TTL、一次性消费、重放、限流、反枚举、失败/取消/重试；不发送真实邮件 |

身份 linking 前提沿用现有 [A1 Auth Spike 执行合同](../../../10-A1-Auth-Spike执行合同.md) 的 automatic/manual linking 约束：先证明目标邮箱控制权，再按受控流程 link；当前管理面 `manual linking` 关闭只是配置观察，不等于 linking 测试通过。B2 必须在独立 Gate 打开后分别验证自动 linking、手动 link/unlink、重新认证、至少保留一种可用登录方式和冲突恢复，不得把 UI 点击或配置状态写成成功结果。

### 7.3 明确继续关闭与 STOP

- OAuth client、redirect allowlist、client secret、SMTP credential、Storage、DB/schema、用户/session/MFA 实测、任何费用/add-on/upgrade、部署、Preview、Production、promote、alias 和真实数据继续关闭。
- 出现目标漂移、connector 账号无法确认且需要额外访问、计划或费用变化、需要 Save/Enable/Create/Reveal/Copy、secret/service role/DB password、真实 PII、真实邮件、生产域名或无法证明隔离时，立即 STOP，保存脱敏失败摘要，不绕过门禁。
- B2 只有在本草案满足、独立安全复审通过且 Owner/主代理显式 Gate 后才可执行；本批不预写用户、Auth、邮件、回调或登录结果。

## 8. 本批结论与后续

- **已完成：B1 配置/能力只读预检（窄范围）**。这是 Supabase dashboard Auth 配置页的能力分类和 Free 限制记录，不是 Auth 技术通过。
- G2-A1 仍为执行中；B2 实施保持 CLOSED。完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续 CLOSED。
- 本候选首次独立复审结论为 REVIEW NO-GO；本轮 findings 已按反馈修复，待定向复审；不预写 REVIEW GO、PR、Actions 或 merge。
- 当前无真实登录、OAuth callback、邮件、用户、session、MFA、DB、Storage、hook、audit 或生产结果。下一步为 B2 草案独立复审与 Owner/主代理 Gate，不自动开始 B2。
- 当前 capability-preflight worktree 不包含 `prototype/.env.local`；此前连接 worktree 的 ignored/owner-only 状态不可复用。B2 执行前必须在实际 worktree 重新验证该文件被 `.gitignore` 阻止跟踪、保持 untracked 且权限为 mode `600`，不得沿用旧 worktree 权限结论。
- 相关权威记录：[15 台账](../../../15-项目状态与阶段台账.md)、[G2-A1 阶段记录](../../../stages/G2-A1-Auth-Spike准备与资源门禁.md)、[A1 执行合同](../../../10-A1-Auth-Spike执行合同.md)、[连接记录](../../../11-发布与Supabase连接记录.md)、[阶段索引](../../../stages/README.md)、[B1 风险 Gate](../2026-08-28-b1-risk-gate/README.md)。

## 9. 脱敏验证记录（2026-08-28）

- `git diff --check`：通过。
- 相对 Markdown 链接与 fragment 检查：通过；本 worktree 共 56 份 tracked Markdown 文件，本批未引入新的相对目标或 fragment finding。
- Markdown fence/backtick 配对检查：通过（本 worktree 共 56 份 tracked Markdown 文件）。
- 敏感值扫描：通过；tracked 文档未发现项目 host/ref、publishable/secret key、JWT 或值赋值模式。
- 当前状态 stale 定向扫描：通过；当前段落统一为 G2-A1 执行中、B1 配置/能力只读预检完成、B2 CLOSED/待独立复审和专项 Gate；仍保留的旧 B1-only 文句均明确标为历史快照/历史运行窗口。本扫描仅覆盖仓库 Markdown，不推断非 tracked 日志或浏览器内部状态。
- 本批为 docs-only；不重复运行 build、lint、typecheck、dev server 或应用浏览器检查，沿用未变化代码在 main 上已有的验证证据。
- 验证结果必须保持“配置能力只读预检完成、B2 CLOSED”，不能写成 Auth 或 G2-A1 技术通过。
