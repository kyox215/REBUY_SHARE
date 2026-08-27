# A1 Auth Spike 执行合同

文档状态：G2-A1 尚未开始；G1 Exit 通过并完成 G2-A0 Owner Gate 后，才可连接独立测试环境
适用范围：验证 Rebuy 三入口认证、OAuth callback、identity linking、邀请邮箱控制权、MFA、会话和最小服务端集成边界  
当前允许：在 G1 Exit 通过并完成 G2-A0 Owner Gate 前，仅可准备文档、接口草图、测试用例和合成 fixture；不得以此改变已冻结的 G0/P1 UI。
当前不允许：不得把 A1 标记为“技术验证通过”，不得初始化或连接 Supabase/OAuth/SMTP，不得连接 production、真实业务数据、真实客户邮箱或真实证件。
关联文档：[完整账号系统规划](./07-完整账号系统规划.md)、[账号系统思维导图](./08-账号系统思维导图.md)、[A0 账号架构 ADR 与威胁模型](./09-A0-账号架构ADR与威胁模型.md)。

## 1. 合同目的与入口条件

A1 是短期、可回退、证据驱动的 Auth spike。它只回答“候选认证方案在独立测试环境是否满足 Rebuy 的账号安全合同”，不负责交付完整账号系统、组织后台、批发审核或生产部署。

A1 的执行入口条件：

1. Owner 已验收 09 的 A0 ADR、威胁模型、八项修正和风险登记。
2. A0 Owner Gate 明确允许连接独立 `local`/`preview-staging` 测试环境。
3. 测试项目、client、secret、SMTP、Storage、redirect 和域名均已证明不属于 production。
4. 所有测试账号、邮箱、组织、申请、文件和订单均为合成或专用测试数据。
5. 密钥责任人、证据保存位置、停止联系人和回退方式已记录。

在第 1–2 项未满足前，执行代理只能做文档、接口草图、静态 UI、测试用例和合成 fixture，不得初始化 Supabase 连接或 OAuth 控制台回调。

## 2. 目标

- 验证 Supabase Auth 是否能在独立环境提供 Apple、Google、邮箱 OTP 三个等价 V1 入口；Magic Link 只作为邮箱兼容/后备路径。
- 验证 user 状态 `pending_identity_verification -> active` 的三入口转换、失败、取消、重试、限流和反枚举语义。
- 验证 Apple/Google OAuth callback 的 PKCE、`state`、`nonce`、一次性 code、精确 redirect allowlist、环境绑定和 open redirect 防护。
- 验证 Google 最小 scope `openid`、`email`、`profile`，不读取 Gmail、Drive、联系人等其他服务，不保存 provider token。
- 验证 Apple relay/隐藏邮箱、首次姓名缺失、取消授权、client secret 轮换和错误响应。
- 验证同验证邮箱自动 linking 是否可用；验证手动 link/unlink、重新认证、至少保留一种可用登录方式和重复业务用户冲突路径。
- 验证员工邀请先证明目标邮箱控制权；当前 Apple/Google identity 邮箱不精确匹配时拒绝；验证目标邮箱 OTP→link OAuth 与撤销重发两条允许路径。
- 验证平台/商家高权限的 AAL2/TOTP、主因子与备用 TOTP 因子、不同设备/安全位置约束、受审计人工恢复、通知和会话重置。
- 先校准 Supabase 原生 `signOut` 的 `local`、`global`、`others`；调查 `auth.sessions` 可见性、服务端权限、字段和单设备列表/撤销实现边界。
- 形成足够证据供 Owner 选择供应商、锁定 A2 入口和开启后续专项审查；未通过时提供明确停止/回退建议。

## 3. 非目标

- 不创建或修改生产 Supabase 项目，不读取或写入生产数据库、Storage、Auth、SMTP、域名、OAuth client 或生产日志。
- 不导入真实客户、商家、员工、申请、订单、地址、证件、真实邮箱或真实支付资料；不得用真实 PII 作为“更接近真实”的测试数据。
- 不在 A1 实现完整组织、membership、permission point、RLS 业务表、商家审批、批发资格、订单、价格、库存、隐私删除或支付闭环。
- 不把 OAuth provider token、refresh token、Apple `.p8`、SMTP secret、service role key 或测试用户秘密提交到仓库、客户端 bundle、日志、截图或工单。
- 不以姓名、头像、组织关系、相似邮箱或 Apple relay 推测 identity 合并；不自动搬运重复业务用户的订单、membership、资格或审计。
- 不承诺 `auth.sessions` 设备列表、单设备撤销或“access token 立即失效”；这些能力必须有 A1 实测证据。
- 不把本地视觉原型、静态截图、Mock Auth 或浏览器表单点击标记为 A1 技术验证通过。

## 4. 环境合同

| 环境 | A1 用途 | 允许的数据/连接 | 禁止事项 |
|---|---|---|---|
| `local` | callback、UI、错误、OTP/Magic Link、限流和合成流程开发 | 本地捕获 SMTP、专用测试 OAuth client、合成用户和本地 fixture；必要时使用明确隔离的本地 Auth 服务 | 不默认连接 preview/production；不使用生产 client、secret、redirect、SMTP 或真实 PII |
| `preview-staging` | 独立集成和浏览器验证 | 独立 Supabase 项目、独立 Auth/Storage/SMTP、专用 Google/Apple client、测试域名、合成数据 | 与 production 项目、密钥、bucket、域名、日志、备份完全分离；不导入真实 PII |
| `production` | A1 不得使用 | 无 | 禁止登录、迁移、OAuth callback、SMTP、Storage 上传、真实账号创建和任何业务写入 |

环境验收必须记录项目标识、区域、URL、redirect allowlist、Auth provider 配置、Storage bucket、SMTP 捕获方式、密钥来源和确认人；敏感值只记录 secret 名称/摘要，不记录原值。

## 5. 前置项与责任

### 5.1 Supabase 前置项

| 前置项 | 最小要求 | 责任与证据 |
|---|---|---|
| 独立项目 | A0 Gate 后由 Owner 指定 non-production 项目和区域 | Owner 记录 project ref、区域和隔离证明，不提供 production 权限 |
| Auth 配置 | 只启用测试 provider、测试 redirect、测试邮箱和最小设置 | 实现代理记录配置摘要和回退步骤 |
| Auth MFA | 可测试 TOTP enrollment/challenge/verify/factors/unenroll；不假设静态恢复材料能力 | 实现代理保存官方行为与测试结果；安全审查人检查恢复流程 |
| 数据/Storage | 仅合成 schema/fixture；如 A1 不需要业务文件则保持 Storage 关闭 | 不创建真实业务 bucket；A4 再验证申请三元组和文件 RLS/Storage |
| 服务端权限 | 使用明确的测试服务端权限；浏览器不得得到 service role | 技术负责人检查环境变量、bundle、Network 和日志 |
| 版本/区域 | 记录 SDK、Auth 配置和测试日期，复核官方文档 | Owner 决定是否因版本漂移重跑 |

### 5.2 Google 前置项

- 使用独立测试 OAuth client、测试 redirect URI 和测试 consent screen；不得复用 production client。
- 仅请求 `openid`、`email`、`profile`；A1 记录最终授权请求和 consent screen，发现额外 scope 即停止。
- 测试取消授权、重复登录、同验证邮箱、不同邮箱、provider 错误和 redirect mismatch。
- 不保存 `provider_token` 或 `provider_refresh_token`；检查数据库、日志、错误、浏览器 Network 和事件载荷。

### 5.3 Apple 前置项

- 使用独立 Services ID、测试 redirect、测试 client secret 和受控 `.p8`；`.p8` 不进入仓库、普通 `.env`、截图或聊天记录。
- 指定密钥保管人、最短访问角色、约 6 个月 secret 轮换责任、到期提醒、失败告警、回滚和紧急重签演练责任。
- 覆盖 Apple relay 邮箱、首次姓名、姓名缺失、用户取消授权、不同 relay 与已有业务账号冲突。
- 不要求用户暴露 Apple 真实邮箱；但邀请接受仍要求当前 identity 已验证邮箱与目标邮箱精确匹配。

### 5.4 SMTP 前置项

- `local` 使用本地 SMTP 捕获器或完全合成发送器；`preview-staging` 使用独立测试 SMTP/域名，不发送给真实客户。
- A1 记录 OTP、Magic Link、邀请、MFA 通知和安全通知的模板版本、TTL、重发限制、失败和退信事件。
- production custom SMTP、发件域、SPF/DKIM、退信、投诉、合规留存和监控只做前置清单，不在 A1 配置生产。

## 6. 三个正式入口与用户状态

| 入口 | 主要路径 | 成功结果 | 必测失败/边界 |
|---|---|---|---|
| Apple | start → provider → callback → session | 建立或关联 identity；`pending_identity_verification` 可转 active | relay、无姓名、取消、redirect mismatch、重复登录、不同已有 identity |
| Google | start → provider → callback → session | 只请求最小 scope；建立或关联 identity；可转 active | scope 超额、取消、错误、不同邮箱、同验证邮箱、重复登录 |
| 邮箱 OTP | request → deliver/capture → verify | 证明目标邮箱控制权；可转 active | 过期、重放、错误次数、重发、枚举、限流、换设备 |
| Magic Link 后备 | request → capture → consume | 作为邮箱路径兼容后备，不增加业务权限 | 过期、重放、跨会话、错误回跳、枚举 |

user 状态必须使用 `pending_identity_verification`，而不是只表达邮箱验证。邮箱 OTP/Magic Link 和受信任 Apple/Google callback 均可转 `active`。未 active 的用户不能读取受保护订单、组织、店铺、申请或证明文件。

入口成功只能建立 identity 会话，不能直接创建 membership、角色、商家批准、批发申请批准或 `wholesale_qualifications`。

## 7. OAuth callback 合同

每个 provider 的 callback 逐项验证：

1. callback 所属环境、provider、client、redirect URI 和允许的相对 `next`。
2. authorization code 存在、未消费、未过期且只允许一次兑换。
3. PKCE verifier 与发起会话绑定并匹配；`state` 防 CSRF；`nonce` 与 provider ID token 匹配。
4. callback 会话、浏览器 cookie、环境和 redirect allowlist 精确匹配；跨环境 client、通配外域和 open redirect 一律拒绝。
5. provider 返回的 email/identity 只用于认证事实和 A1 linking 测试，不能直接产生业务 membership 或资格。
6. code、PKCE verifier、state、nonce 在消费/失败/过期后不保留原值；不得进入数据库、日志、URL、截图、客户端响应或长缓存。
7. 只保留必要脱敏安全事件：provider、环境、结果分类、时间、不可逆事件标识、关联 session 摘要和错误类别；不写原始 code、邮箱、token 或完整 provider payload。
8. 取消、错误、账号冲突和不存在账号使用尽量统一的反枚举响应；安全事件仍按最小字段记录。

## 8. Identity linking 与冲突合同

测试矩阵至少覆盖：

- email OTP → Google、email OTP → Apple、Google → Apple、Apple → Google。
- 同一已验证邮箱、不同已验证邮箱、Apple relay 与普通邮箱、未验证邮箱声明、姓名/头像相同、组织关系相同。
- 已存在两个业务用户时，link、unlink、登录、购物车、订单、membership、merchant application、wholesale application、qualification 和审计的行为。

硬规则：

- 自动 linking 只有在 A1 记录真实测试结果、版本和风险结论后才能进入 A2；文档推断不算证据。
- 手动 link/unlink 必须在已登录安全中心发起，重新认证，验证目标 identity 和当前用户状态；unlink 后至少保留一个已验证、可用登录方式。
- Apple relay、姓名、头像、未验证邮箱、组织关系或客服判断不能自动合并。
- 两个 identity 已形成两个业务用户时，不自动搬运或合并订单、membership、组织、申请、资格、地址、购物车或审计；建立受审计人工冲突记录，等待 Owner 规则。

## 9. 邀请目标邮箱控制权合同

员工接受邀请的最小顺序：

1. 服务端验证 token hash、期限、一次性消费、目标组织、scope、角色版本和邀请人权限。
2. 接受者先用邀请目标邮箱完成 OTP 验证，证明对该邮箱的控制权；OTP 事件受限速并写最小安全事件。
3. 如果当前 Apple/Google identity 的已验证邮箱与目标邮箱不完全匹配，拒绝接受。Apple relay 只在它本身就是目标邮箱且完成控制权证明时作为精确邮箱使用。
4. OTP 成功后，只有 A1 验证允许的 link 流程才能关联 OAuth identity；否则邀请人撤销旧邀请并重发到已经验证控制的新邮箱。
5. 接受邀请和激活 membership 在同一事务中完成；并发接受只能一个成功；发送新邀请先撤销旧 token。
6. 失败响应不泄露组织、成员、角色或邮箱是否存在；成功、失败、撤销、重发和接受均通知并审计。

## 10. TOTP、备用因子与人工恢复合同

| 项目 | 合同要求 | A1 证据 |
|---|---|---|
| 主因子 | enrollment、challenge、verify、AAL2、重新认证和撤销可用 | 测试用户正向/负向记录、AAL 变化 |
| 备用因子 | 第二个独立 TOTP 因子，必须放在与主因子不同的设备或安全位置 | 因子元数据、设备分离声明、重复/并发挑战结果 |
| 因子撤销 | 撤销、重新 enrollment、错误、限速和通知 | 因子列表、事件、通知和审计 |
| 人工恢复 | 身份核验、support 收件与沟通、独立 reviewer/安全负责人批准、AAL/会话重置、通知和追加式审计 | 双人流程记录、权限负向、会话重置和通知证据 |
| 责任边界 | support 不得单独批准或解除 MFA；人工恢复不得仅凭姓名、工单文本或未验证邮箱 | API/角色/字段负向测试 |
| 恢复后状态 | 旧高风险会话按策略失效/降级；重新 enrollment 和高风险动作重新认证 | 旧/新 session、AAL、membership 和通知对照 |

Entry preflight 候选建议（待 G2-A0 Owner 确认）：建议 A1 不以静态一次性码作为恢复路径；若 Owner 不采纳，必须先修订本 A1 合同并重新评审。若供应商界面或 API 出现相近命名，A1 仍必须记录其实际语义、生命周期、存储和安全风险，不能把它当作未经验证的备用因子替代。

## 11. 会话与退出能力合同

### 11.1 先验证的原生退出语义

| 语义 | A1 要回答的问题 |
|---|---|
| `local` | 当前客户端的 session/cookie 如何清理？其他设备是否继续有效？刷新和并发请求如何表现？ |
| `global` | 全部 session 如何处理？access/refresh token、旧 cookie 和并发请求的观察结果是什么？ |
| `others` | 是否由 Supabase 原生支持？实际影响哪些 session？是否需要服务端权限或额外实现？ |

### 11.2 `auth.sessions` 与单设备边界

- 检查业务服务端能否安全看到 `auth.sessions`、哪些字段可见、RLS 或管理权限如何工作、是否能关联用户和 `session_id`。
- 在证据不足前，不提供设备列表、设备名称、单设备撤销或“已即时踢出”的产品承诺。
- 如果 A1 无法获得稳定、最小权限、可审计的实现，保留已验证的 `signOut` 语义和全量退出/成员撤销策略，把单设备能力列为后置 ADR。

### 11.3 token 窗口与业务风控

- 被撤销 access token 可能在 `exp` 到期前仍有效；A1 必须观察并记录，而不是假定即时失效。
- 高风险请求必须实时查 `session_id`、user 状态、membership、组织/店铺状态和批发资格；普通请求遵循 Owner 批准的 JWT 时限。
- membership、组织、店铺或资格撤销后，业务授权必须拒绝，即使页面、缓存或旧 JWT 仍显示旧状态。
- 安全事件记录 signOut 语义、撤销动作、session 摘要、时间、结果和通知，不记录 token 原值。

### 11.4 A1/A3/A4 验证责任分配

本节只分配后续证据责任，不表示 G2-A1 已开始，也不打开数据库、Storage 或真实账号实现。A1 只在独立测试环境使用合成数据；本节不提供 SQL 实现、不创建 fixture 值。

| 控制/问题 | A1 Auth spike | A3/A4 业务与数据专项 | 通过证据与停止条件 |
|---|---|---|---|
| provider、plan、region | 记录候选 provider、计划、区域、版本、环境归属和日期，比较实际限制 | 检查业务数据、租户和 Storage 是否仍在独立资源 | 配置摘要和 Owner 选择；无法证明隔离或区域/计划限制时停止 |
| session lifetime、single-session、refresh delay | 实测 JWT/session lifetime、刷新延迟、单/多设备和 `signOut` local/global/others 的观察窗口 | 验证成员/资格撤销后的业务拒绝和并发一致性 | 时间线、配置摘要、并发结果；不把默认值或页面状态写成即时失效 |
| 删除/暂停与 token 窗口 | 观察 session/token 时间窗口、用户删除/暂停、退出、refresh token 和旧 access token 在 `exp` 前后的行为 | 验证删除/暂停后的业务拒绝、membership/资格状态和跨租户负向；高风险请求实时检查 `session_id`、user、scope 和资格 | A1 时间线与 A3/A4 业务拒绝/跨租户负向证据；若旧 token 仍可执行高风险动作，立即停止并修正 |
| SSR client 与 cookie refresh | 每请求创建新 browser/server client；验证未来 Proxy 刷新 request/response cookie、过期 session、并发请求和用户串线 | 验证业务页面/数据不跨用户复用并与服务端授权一致 | 运行记录和并发负向；当前连接骨架无运行证明，未通过前不开放受保护页面 |
| Data API grants、RLS、exposed allowlist | 可做最小公开/认证角色和对象 reachability 核验，确认 grants 与 RLS 是两层 | 覆盖所有业务表、view、function、跨租户读取/写入和拒绝路径 | A1 只提供候选基础证据；完整业务 RLS 归 A3/A4，缺 allowlist 或任一层绕过即停止 |
| UPDATE / view / function 控制 | 记录需要在 A3/A4 验证的候选规则：UPDATE 的 SELECT + USING + WITH CHECK、view `security_invoker` | 实测 view 行范围、function invoker/definer、固定 search_path、撤销 PUBLIC EXECUTE、角色 allowlist | policy/function/view 负向和权限记录；不以客户端隐藏或 publishable key 代替授权 |
| Storage policy 与 upsert | 若 A1 不需要业务文件则不启用；只记录接口/权限问题 | A4 验证私有桶、申请三元组、签名 URL，以及 upsert 的 INSERT + SELECT + UPDATE | 上传/替换/读取/删除和跨租户拒绝；任一对象公开或权限过宽即停止 |
| managed schema 限制 | 记录当前官方限制与迁移边界，不创建 `auth`/`storage`/`realtime` 自定义对象 | A3/A4 复核自有 schema、迁移和业务对象不依赖 managed schema 写入 | 按官方文档复核；发现破坏性 managed schema 操作即停止 |
| MFA 范围 | Entry preflight 候选建议（待 G2-A0 Owner 确认）：建议 V1 不采用 phone/SMS MFA；Owner 采纳后 A1 才可不测试该路径，若不采纳必须先修订本合同并重新评审；A1 继续验证 TOTP、备用因子、人工恢复、AAL/会话重置 | A5 后续验证高风险业务动作与恢复审查 | phone/SMS 测试取决于 Owner 决定；恢复缺少职责分离、通知或审计即停止 |

责任分配不替代 Owner Gate：A1 结果必须脱敏并记录实际 provider/plan/region、版本、配置、观察窗口和失败分类；A3/A4 结果必须记录对象、租户、角色、权限、policy、view/function/Storage 和跨租户负向证据。任何能力不能从官方网页或本地骨架直接推断为实现。

## 12. 概念接口与证据边界

以下是 A1 用于讨论和测试的概念接口，不代表已经创建路由：

| 接口 | A1 讨论范围 | 必须拒绝 |
|---|---|---|
| `auth/request-otp` / `auth/verify-otp` | TTL、重发、尝试次数、反枚举、session、状态转换 | 超限、重放、跨会话、错误邮箱推断 |
| `auth/consume-magic-link` | 一次性 token、相对回跳、兼容路径 | 过期、重放、open redirect、越权业务能力 |
| `auth/oauth/{provider}/start` | 环境、client、state/nonce/PKCE 发起 | 未 allowlist provider/redirect、跨环境配置 |
| `auth/oauth/callback` | code 兑换、身份建立、错误语义、安全事件 | code 重放、PKCE/state/nonce 错、open redirect、provider 错误 |
| `auth/identities/link` / `unlink` | 重新认证、目标 identity、孤儿防护 | 最后可用方式、邮箱/relay 猜测、重复业务自动合并 |
| `members/accept-invitation` | 目标邮箱 OTP、精确匹配、token 消费、membership 激活 | 未证明邮箱、不匹配 identity、过期/撤销/重放 |
| `auth/mfa/*` | TOTP、备用因子、人工恢复、AAL/会话重置 | support 单独批准、无身份核验、无通知/审计 |
| `auth/sign-out` | local/global/others 的实测语义 | 未验证的单设备承诺、泄露 token |
| `auth/sessions/list` / `revoke` | 仅在 `auth.sessions` 能力和权限验证后讨论 | 未授权跨用户、对象枚举、假定即时 token 失效 |

## 13. 测试矩阵

| 类别 | 正向案例 | 负向/边界案例 | 通过证据 |
|---|---|---|---|
| 三入口 | Apple、Google、邮箱 OTP 建立同等 identity | 取消、失败、重试、过期、限流、枚举 | 浏览器记录、事件摘要、状态转移 |
| user 状态 | 三入口转 `pending_identity_verification -> active` | 未 active 读受保护资源、错误 provider、重复回调 | 状态和授权断言 |
| Google scope | 仅 `openid email profile` | 任何 Gmail/Drive/联系人或额外 scope | consent screen、请求日志、token 检查 |
| Apple relay | relay 正常登录，姓名缺失仍可用 | 强迫真实邮箱、按姓名合并、不同 relay 自动合并 | identity 与 linking 结果 |
| callback | 精确 redirect、PKCE/state/nonce/code 一次性通过 | 缺失/错/重放、跨环境、open redirect | callback 负向矩阵和脱敏事件 |
| OAuth 留存 | 消费后保留必要安全事件 | 原值进入 DB、日志、URL、截图、缓存 | DB/log/cache/Network 扫描 |
| linking | 同验证邮箱按实测结论处理 | 不同邮箱、未验证邮箱、相似姓名/头像、两个业务用户 | linking 决定表、冲突记录 |
| unlink | 重新认证后保留至少一个登录方式 | 解除最后可用 identity、陈旧 session | 账户可用性和事件 |
| 邀请 | 目标邮箱 OTP 后接受；撤销重发路径成功 | Apple/Google 不匹配、relay/姓名猜测、过期/重放/并发 | token、邮箱证明、membership 事务证据 |
| MFA 主因子 | enrollment/challenge/verify/AAL2 | 错误、重复、撤销、降级、限速 | AAL、因子和通知事件 |
| 备用因子 | 不同设备/安全位置的第二 TOTP 因子 | 与主因子同设备、撤销、错误、重复使用 | 因子配置和负向记录 |
| 人工恢复 | 身份核验→职责分离→AAL/会话重置→通知/审计 | support 单人、无核验、无通知、旧高风险 session 仍可用 | 双人审批和 session 对照 |
| signOut | `local`、`global`、`others` 各自语义 | 未支持语义、刷新/并发/离线 token | 官方行为、客户端/服务端观察 |
| `auth.sessions` | 可见字段、最小服务端权限、关联 session_id | 跨用户读取、浏览器直读、不可审计撤销 | 权限和 API 证据 |
| token 窗口 | 撤销后观察 `exp` 前行为 | 把 access token 当即时失效；高风险不查实时状态 | 时间线和业务拒绝结果 |
| 反枚举/限流 | 存在/不存在邮箱与邀请响应一致 | OTP、邀请、恢复、callback 超限 | 状态码/文案对照、限流计数 |
| 环境隔离 | local 与 preview-staging 使用各自配置 | 生产 client/secret/SMTP/redirect/真实 PII 混入 | 配置清单和人工复核 |
| secrets | `.p8`、OAuth secret、SMTP/service role 仅服务端密钥系统 | 仓库、bundle、URL、日志、截图出现原值 | secret scan、bundle/Network 检查 |

## 14. 失败停止条件

出现任一条件，立即停止相关实验、隔离测试账号/secret、保存脱敏证据并通知 Owner；不得用绕过方式继续：

- 任一请求可以读取或写入 production、真实 PII、真实 Storage 或真实 SMTP。
- callback 能接受错误/重放的 code、PKCE、state、nonce，或存在 open redirect/跨环境混用。
- Google 请求额外 scope，或任何 provider token/refresh token 进入日志、数据库、客户端或截图。
- Apple relay、姓名、头像、组织关系或相似邮箱被用于未经验证的自动 linking/邀请接受。
- 邀请目标邮箱未证明控制权、邮箱不匹配仍能激活 membership，或 token 可重放/并发双消费。
- support 能看到完整证件、写审核意见、批准申请或单独解除 MFA。
- MFA 人工恢复缺少身份核验、职责分离、AAL/会话重置、通知或审计。
- 任何策略仅凭 `org_id IS NULL` 允许读取审批前文件，或批准事务绑定失败仍开放组织/资格。
- `auth.sessions` 授权边界不清、跨用户可读、浏览器可直读，或实现把 access token 撤销误报为即时失效。
- 测试发现数据泄露、无法清理原值、无法证明环境隔离、无法复现或无法回退。

停止后的最小处置：撤销测试 client/secret 或测试 session、冻结测试入口、保留不含秘密的时间线和错误分类、删除测试原值/文件、记录影响范围和 Owner 决策。不得删除必要审计证据，不得把失败隐藏成“未复现”。

## 15. 证据清单

A1 结束时必须交付可复核但不含秘密的证据包：

- 环境隔离证明：local/preview-staging 项目摘要、区域、redirect、SMTP 捕获、Storage 和密钥责任。
- 版本与配置摘要：SDK、Auth provider 设置、Google/Apple client 摘要、测试日期、官方文档复核日期。
- 三入口正负向测试矩阵、user 状态转换和反枚举/限流结果。
- OAuth callback 的 PKCE/state/nonce/code 一次性、redirect allowlist、取消、错误、重放和 open redirect 证据。
- OAuth 短时原值不落 DB/log/cache/URL/Network 的扫描结果；脱敏安全事件样例。
- Google scope/Apple relay/首次姓名/secret 轮换责任与故障演练记录。
- identity linking/unlink 决定表、重复业务用户冲突记录和不自动搬运证明。
- 邀请目标邮箱 OTP 控制权、mismatch 拒绝、OTP→link 或撤销重发、并发/重放证据。
- 主 TOTP、备用 TOTP 不同设备/安全位置、人工恢复双人审批、身份核验、AAL/会话重置、通知和审计证据。
- `signOut` local/global/others 实测、`auth.sessions` 可见性/服务端权限/单设备能力结论、access token `exp` 窗口时间线。
- 失败停止记录、清理/回退结果、残余风险和 Owner 选择建议。

证据必须脱敏：不包含邮箱原文、验证码、OAuth code、PKCE verifier、state、nonce、provider token、refresh token、`.p8`、SMTP secret、service role、真实 PII 或完整文件。

## 16. 密钥与责任合同

| 资产 | 责任 | 保存方式 | 轮换/故障 |
|---|---|---|---|
| Supabase 测试密钥 | Owner 指定的测试环境负责人 | 受控 secret manager；服务端使用 | 项目重置或泄露时立即撤销，记录摘要和影响 |
| Google test client/secret | Google 配置责任人 | 独立测试控制台和 secret manager | redirect/client 变更记录；不得复用 production |
| Apple `.p8`/client secret | Apple 密钥保管人 | 最小权限密钥系统；禁止仓库/普通 env/截图 | 约 6 个月轮换、到期提醒、失败告警、紧急重签和回滚 |
| SMTP test credential | 邮件环境负责人 | local catcher 或独立 preview secret | 测试结束撤销；不发送真实用户邮件 |
| service role/管理权限 | 后端安全负责人 | 仅受信服务端 | 浏览器、bundle、日志和 Network 永不出现 |
| 测试账号与 TOTP 因子 | 测试负责人 | 专用测试设备/安全位置；不使用个人主账号 | A1 结束清理或冻结，保留无秘密摘要 |

任何密钥责任人只能决定自己负责的测试配置，不能单独批准 production 连接、真实 PII、权限放宽或安全例外。生产密钥、真实账号和生产 callback 需要新的 Owner Gate 与专项审查。

## 17. A1 验收与后续 Gate

A1 技术验证通过的最低条件：


- 三入口、callback、linking、邀请邮箱控制权、MFA 和会话测试矩阵有可复核结果，失败项有明确分类。
- 八项 A0 修正没有被测试结果推翻或绕过；任何未验证能力都标记为后置，不写成已具备。
- 无 production/真实 PII 连接；无原始短时 OAuth 材料、provider token、密钥或验证码泄露。
- `signOut` 语义、`auth.sessions` 能力、token `exp` 窗口和高风险实时检查结论被写入 07/后续 ADR 的变更建议，而不是隐含在 UI 中。
- Owner 选择供应商、入口、linking 规则、人工恢复责任、SMTP/Apple 密钥责任和下一阶段范围。

A1 通过只打开 A2 买家账号或 Owner 指定的下一阶段，不自动打开生产、真实批发、商家审核、支付或跨租户业务。任何 A1 失败都保持关闭并回到补充 ADR/重新实验。

## 18. 当前原型边界

A0 通过前可以继续制作无后端 UI 原型：

- 可展示 Apple、Google、邮箱 OTP、Magic Link 后备、邀请邮箱 mismatch、备用 TOTP、人工恢复、会话能力“待 A1 验证”等状态。
- 只能使用合成身份、虚构邮箱、虚构组织、不可用的示例 token 文本和静态结果；不得把按钮点击写成真实 Auth 成功。
- 页面文案必须区分“规划/待验证/已通过测试”；不得显示已连接 Supabase、OAuth、SMTP、Storage 或 production。
- 原型截图、视觉检查和 HMR 只证明本地视觉/交互，不证明 A1 技术能力、安全、RLS 或隐私合规。

## 19. 正式来源

- [Supabase Auth MFA JavaScript reference](https://supabase.com/docs/reference/javascript/auth-mfa)
- [Supabase MFA guide](https://supabase.com/docs/guides/auth/auth-mfa)
- [Supabase signOut](https://supabase.com/docs/guides/auth/signout)
- [Supabase sessions](https://supabase.com/docs/guides/auth/sessions)
- [Supabase passwordless email](https://supabase.com/docs/guides/auth/auth-email-passwordless)
- [Supabase Login with Google](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Supabase Login with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Supabase Identity Linking](https://supabase.com/docs/guides/auth/auth-identity-linking)

这些来源需要在 A1 执行时按当前版本、区域和实际配置重新复核；链接本身不是测试通过证据。
