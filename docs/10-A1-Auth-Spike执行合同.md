# A1 Auth Spike 执行合同

文档状态：**G2-A1 执行中（B1 最小连接与配置/能力只读预检、B2 本地安全基础及其远端闭环已完成；当前 B2 external entry Gate design/preflight 已完成；E1 local bootstrap 本地候选，start 因 Docker/Colima socket mount 失败，已完成项目限定 stop）**；PR #13 docs-only closeout merge=`b3e53a71ca40729b139724a492e8d20afd02f341`，main Actions run=`33212054195`/job=`98987321203` success，`test:auth` 12 项且仅运行一次，exact merge 的 GitHub deployments=`0`，Vercel 无新增部署；该闭环仅关闭文档 Gate 设计与本地基础交付，不等于完整 B2/Auth/G2-A1 整体通过；Auth/OAuth/SMTP/DB/Storage/user/session/MFA 未开始；本批仅完成 E1 init/config/cache/start attempt/cleanup，未形成 API/DB/Studio/Mailpit health 证据；E2–E5、hosted Auth/SMTP/DB/Storage/Production/deploy 全部继续 CLOSED；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 关闭**；G2-A0 Exit GO，七项 Owner 政策已采纳；即使资源已存在，也须另行完成 Auth/secret/DB 等技术 Gate 后才可进入独立测试
适用范围：验证 Rebuy 三入口认证、OAuth callback、identity linking、邀请邮箱控制权、MFA、会话和最小服务端集成边界  
当前允许：A1-B1 最小连接与配置/能力只读预检、B2 本地安全基础及其远端闭环、B2 external entry Gate design/preflight 已完成；本批已按 Gate 执行 E1 local config init、静态配置、获批 image-download Gate、start attempt 和项目限定 cleanup，结果为候选但因 Docker/Colima mount 失败而未达到健康运行。本批不改变已冻结的 G0/P1 UI，也不打开 E2–E5、完整 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 external Auth success。
当前不允许：不得把 A1 标记为“技术验证通过”；除已授权 B1 窄范围内只读取得 project URL + modern publishable key 外，不得读取任何 key/secret，不得配置或连接 Supabase Auth/OAuth/SMTP，不得建表/写数据，不得连接 production、真实业务数据、真实客户邮箱或真实证件；本 A1 合同不授予 service_role、secret key、db password 或其他管理凭据使用权。
关联文档：[完整账号系统规划](./07-完整账号系统规划.md)、[账号系统思维导图](./08-账号系统思维导图.md)、[A0 账号架构 ADR 与威胁模型](./09-A0-账号架构ADR与威胁模型.md)、[G2-A1 准备与资源门禁](./stages/G2-A1-Auth-Spike准备与资源门禁.md)、[资源成本与密钥 Gate 模板](./templates/G2-A1-资源成本与密钥Gate模板.md)、[Auth 实测矩阵模板](./templates/G2-A1-Auth实测矩阵模板.md)。

## 1. 合同目的与入口条件

A1 是短期、可回退、证据驱动的 Auth spike。它只回答“候选认证方案在独立测试环境是否满足 Rebuy 的账号安全合同”，不负责交付完整账号系统、组织后台、批发审核或生产部署。

A1 的执行入口条件：

1. A1 开始前，Owner 必须完成 G2-A0 Exit，明确验收 09 的 A0-01～A0-15、日期化 Entry 补充、威胁模型和风险登记；本阶段使用的七项 MFA/AAL2/复核/provider/会话/法律边界政策已于 2026-08-27 采纳。
2. Owner 已单独授权 non-production resource/cost/secret，并明确 provider、project、plan、region、环境、费用上限、密钥责任人和停止联系人；A0 Exit 本身不包含该授权。
3. 测试项目、client、secret、SMTP、Storage、redirect 和域名均已证明不属于 production。
4. 所有测试账号、邮箱、组织、申请、文件和订单均为合成或专用测试数据。
5. 证据保存位置、停止联系人和回退方式已记录，且不保存 secret/token/PII 原值。

在第 1–2 项未满足前，执行代理只能做文档、接口草图、静态 UI、测试用例和合成 fixture，不得初始化完整 Supabase/Auth/OAuth 技术执行；当前仅可按已授权的 A1-B1 最小技术范围进行 project URL + modern publishable key 的只读取得、gitignored local env 保存和 EU non-production synthetic-only SSR/client/health 连接验证。

### 1.1 A0 Exit 与 A1 资源授权分离

G2-A0 Exit 只表示账号安全合同、威胁模型、Owner 已采纳的七项政策和独立文档治理审查完成，并且至多打开 G2-A1 的准备门；该 Exit 本身不创建或连接 provider/project，也不批准费用、计划、区域、OAuth、SMTP、Storage、secret 或真实账号。当前因既有文档治理复审首轮 finding 已关闭且 Owner/主代理明确批准，打开并完成 A1-B1 最小连接与配置/能力只读预检；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge；完整 non-production resource/cost/secret/Auth/DB 等 Gate 仍关闭，不能据此进入完整 A1 技术执行。当前最小资源存在性/基础预检已完成。当前 A0 Exit 已 GO（验收 ref=`140ea15d9c3f178a326709d35ad1750a156df0d1`），远端 reconciliation 已以 PR #7 merge commit=`fd9b712c7b07bf34399f9838eebb75846425c1d1` 完成；无资源 Entry preparation 已归档，当前资源事实见[G2-A1 Entry preparation](./evidence/G2-A1/2026-08-28-entry-preparation/README.md)。

| A1 provider 候选 | 本阶段定位 | A0 约束 |
|---|---|---|
| Supabase | 优先候选，待 A1 独立实测 | A0 不锁定项目、计划、区域、版本或费用 |
| Clerk | 仅作能力、限制、数据/区域和成本比较 | 不创建账号、项目或连接 |
| Auth0 | 仅作能力、限制、数据/区域和成本比较 | 不创建账号、租户或连接 |

候选比较至少记录三入口、MFA/恢复、会话/退出、SSR、linking、地区/计划限制、费用、secret 责任和迁移/回退影响。候选矩阵不是最终 provider 选择，也不是 A1 运行证据；A1 按 Owner 已采纳的 Supabase 优先、Clerk/Auth0 仅比较范围执行。

## 2. 目标

- 验证候选 Auth provider（当前优先候选 Supabase；Clerk/Auth0 仅作比较）是否能在独立环境提供 Apple、Google、邮箱 OTP 三个等价 V1 入口；Magic Link 只作为邮箱兼容/后备路径。
- 验证 user 状态 `pending_identity_verification -> active` 的三入口转换、失败、取消、重试、限流和反枚举语义。
- 验证 Apple/Google OAuth callback 的 PKCE、`state`、`nonce`、一次性 code、精确 redirect allowlist、环境绑定和 open redirect 防护。
- 验证 Google 最小 scope `openid`、`email`、`profile`，不读取 Gmail、Drive、联系人等其他服务，不保存 provider token。
- 验证 Apple relay/隐藏邮箱、首次姓名缺失、取消授权、client secret 轮换和错误响应。
- 验证同验证邮箱自动 linking 是否可用；验证手动 link/unlink、重新认证、至少保留一种可用登录方式和重复业务用户冲突路径。
- 验证员工邀请先证明目标邮箱控制权；当前 Apple/Google identity 邮箱不精确匹配时拒绝；验证目标邮箱 OTP→link OAuth 与撤销重发两条允许路径。
- 验证平台/商家高权限的 AAL2/TOTP、主因子与备用 TOTP 因子、不同设备/安全位置约束、受审计人工恢复、通知和会话重置。
- 按 Owner 已采纳政策，为 MFA 人工恢复、owner 转移、角色/权限策略变更、敏感导出、隐私删除/导出、证明文件高风险访问六类动作保留双人复核/禁止自审的后续验证接口；第二责任人和业务映射由对应阶段细化。
- 若 A1 选择 Supabase，先校准其原生 `signOut` 的 `local`、`global`、`others`；无论选择何种候选，都要调查 session 可见性、服务端权限、字段和单设备列表/撤销实现边界。
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

Owner 已于 2026-08-27 采纳 A1 不以静态一次性码作为恢复路径；A1 验证不同设备/安全位置备用 TOTP、受审计人工恢复及供应商实际语义、生命周期、存储和安全风险，不能把相近界面命名当作未经验证的备用因子替代。

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
| MFA 范围 | Owner 已于 2026-08-27 采纳 V1 排除 phone/SMS MFA 与静态恢复码；A1 继续验证 TOTP、不同设备/安全位置备用因子、受审计人工恢复、AAL/会话重置 | A5 后续验证高风险业务动作与恢复审查；六类高风险动作双人复核且禁止自审 | 按已采纳范围不测试 phone/SMS/静态恢复码路径；恢复缺少职责分离、通知或审计即停止 |

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
- `A0-01～A0-15` 及日期化 Entry 补充没有被测试结果推翻或绕过；任何未验证能力都标记为后置，不写成已具备。
- 无 production/真实 PII 连接；无原始短时 OAuth 材料、provider token、密钥或验证码泄露。
- `signOut` 语义、`auth.sessions` 能力、token `exp` 窗口和高风险实时检查结论被写入 07/后续 ADR 的变更建议，而不是隐含在 UI 中。
- Owner 选择供应商、入口、linking 规则、人工恢复责任、SMTP/Apple 密钥责任和下一阶段范围。

A1 通过只打开 A2 买家账号或 Owner 指定的下一阶段，不自动打开生产、真实批发、商家审核、支付或跨租户业务。任何 A1 失败都保持关闭并回到补充 ADR/重新实验。

## 18. 当前原型边界

resource/cost/secret Gate 通过前，仅可继续维护无资源后端原型、接口合同、测试矩阵和合成字段；G2-A0 已通过，不应将当前限制表述为 A0 未通过。可继续维护的无资源原型范围如下：

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
- [Supabase Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
- [Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits)
- [Free 邮件模板变更](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier)

这些来源需要在 A1 执行时按当前版本、区域和实际配置重新复核；链接本身不是测试通过证据。

当前 hosted SMTP 约束：默认 SMTP 仅向项目团队预授权的邮箱地址发送；当前基线为每小时 2 封且可能变化；无 SLA，仅用于非生产探索。`.invalid` 仅可用于 no-send、负向和反枚举，不能用于成功 OTP/Magic Link 投递；成功路径必须使用专用 synthetic test mailbox/domain、隔离 catcher，或在另行批准后使用 custom SMTP。custom SMTP credential/secret、费用、持久连接及任何浏览器/控制台配置动作保持 CLOSED，每次实际动作都需要 action-time Owner Gate，不能以总体批准替代。

## 20. 2026-08-27 G2-A0 Exit closeout 历史状态

- G2-A0 Exit 已由 Owner 以验收 ref=`140ea15d9c3f178a326709d35ad1750a156df0d1` 于 2026-08-27 明确 GO；**在该日的历史快照中**为 `Exit GO；远端 docs-only reconciliation 已获批、尚未执行`。前一 exact-head 独立文档治理审查 findings=`none/GO`，不等于 Auth/MFA/DB/Storage 或运行时测试；该历史快照不代表当前状态。
- 该状态承接紧前完整授权：允许公开本阶段 12 个 Markdown、相关 Git 历史、Owner 姓名、账号安全架构、威胁模型、角色权限和阶段治理信息到 `kyox215/REBUY_SHARE`，并在 docs-only、exact-head Actions 成功、独立复审通过后按非强制 branch push/PR/merge commit 边界执行；A1 的资源、费用、secret、Auth、DB、Storage、OAuth、SMTP、部署和 Production Gate 继续关闭。
- G2-A1 仍为“未开始”。A0 Exit 只开放准备门；provider、plan、region、session、真实账号、真实 PII 和任何外部连接仍待独立资源授权与后续阶段证据，不得由本合同自动开始。

## 21. 2026-08-28 G2-A1 无资源 Entry preparation 与资源存在性预检当前状态（历史快照；当前见第 27 节）

- G2-A0 远端 reconciliation 已完成：PR #7 merge=`fd9b712c7b07bf34399f9838eebb75846425c1d1`，parents=`7ea1e45ad22ab29105910665baf4bbd7212241c5` + `1433e7c7c141df0f5498fff7cd645a8d5c92340c`；main Actions run=`33122238997` / job=`98691703085` 的 install/typecheck/lint/build 全部 success，merge SHA 的 GitHub deployments=`0`，来源分支保留。完整摘要见[G2-A1 Entry preparation 证据](./evidence/G2-A1/2026-08-28-entry-preparation/README.md)。
- （历史状态）当时正式状态为：**G2-A1 技术阶段未开始；最小资源存在性/基础预检已完成；独立安全复审已完成、首轮 finding 已关闭；Owner/主代理批准打开 A1-B1 最小技术范围（已授权/待执行）；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 关闭**。无资源 Entry preparation 已归档；当时窄范围预检仅核对独立 Free 组织、项目、区域、provider quote 确认和管理面健康状态。当前 B1 配置/能力预检见第 24 节；连接结果见第 23.5 节；不预写 Auth/DB/Storage/OAuth/SMTP 结果，不读取 secret/env/PII，不部署或修改 Production。
- A1 资源 Gate 字段与 Auth 矩阵分别见[资源成本与密钥 Gate 模板](./templates/G2-A1-资源成本与密钥Gate模板.md)和[Auth 实测矩阵模板](./templates/G2-A1-Auth实测矩阵模板.md)。资源存在性与 A1-B1 最小连接验证已完成，但完整 resource/cost/secret、secret/env、Auth、DB/schema/RLS、Storage、OAuth、SMTP、真实数据、部署和 Production Gate 仍关闭；B1 配置/能力只读预检已完成；下一步为 B2 专项风险 Gate 草案独立复审与 Owner/主代理 Gate。service_role、secret key、db password 继续禁止，B1 结果不能写成 G2-A1 Auth/B1 技术通过。
- 2026-08-28 官方来源刷新、EU `eu-central-1` proposal、Node 20→22、OAuth 2xx、Data API grants/RLS 分离、Free SMTP 限制、Pro session 约束与 region/GDPR 边界见[G2-A1 准备与资源门禁](./stages/G2-A1-Auth-Spike准备与资源门禁.md)；这些是规划依据，不是实现证据。

## 22. 2026-08-28 Free Supabase 资源存在性/基础预检事实（历史资源快照；当前 B2 外部入口 Gate 见第 27 节）

- 独立 Supabase 组织 `Rebuy Lab` 已创建，connector 核验 `plan=Free`；独立项目 `rebuy-auth-spike` 已在 `eu-central-1`（Frankfurt）创建，限定用于 EU non-production Auth spike，数据模式为 synthetic-only。
- provider project quote 实际返回 `amount=0`、`recurrence=monthly`；API 未返回 currency。Owner 已确认该实际 quote，随后已完成 `confirm_cost`。这不等于税费、Spend Cap 或完整成本责任确认。
- （历史运行窗口）管理面状态为 `ACTIVE_HEALTHY`；仅证明当时资源存在且管理面健康，不证明 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 已验证。独立运行时复审期间 connector 无法再次列出精确目标，当前管理面状态无法复验。
- （资源预检历史时点）当时没有读取、记录或传播 secrets、keys、passwords、环境变量值、host、URL、project ref、组织/项目 ID 或其他账号资源标识；后续 B1 仅按授权将原值存入 gitignored local env，执行结果见第 23.5 节。没有配置 Auth/DB/Storage/OAuth/SMTP，没有建表、写数据、创建真实账号、部署、promote、alias 或 Production 操作。

## 23. 2026-08-28 A1-B1 最小 Auth spike 风险 Gate 与复用优先预检（历史设计快照；当前 B2 见第 27 节）

本节是 A1-B1 的最小风险 Gate 与复用预检记录。既有文档治理复审首轮 finding 已关闭；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge。Owner/主代理批准打开 A1-B1 最小技术范围。本节设计快照与实际执行结果分开，详见 23.5；不代表 G2-A1 Auth/B1 技术通过。该批按关键风险路由执行：`luna_worker / max`、默认一个执行代理。

### 23.1 Gate 范围与当前决定

| 项目 | 本批决定 |
|---|---|
| Gate 状态 | **A1-B1 最小连接及配置/能力只读预检已完成（窄范围）**；既有文档治理复审首轮 finding 已关闭；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge；不代表 G2-A1 Auth/B1 技术通过 |
| 目标资源 | Supabase 组织 `Rebuy Lab`（Free）；项目 `rebuy-auth-spike`；`eu-central-1`（Frankfurt）；仅 EU non-production、synthetic-only |
| 已核验成本事实 | provider project quote 返回 `amount=0`、`recurrence=monthly`；API 未返回 currency；Owner 已确认该实际 quote 并完成 `confirm_cost` |
| 成本边界 | 不授权任何非零费用、add-on、upgrade、自定义 SMTP 或其他付费能力；tax/VAT/billing-address effect、Spend Cap 状态/覆盖范围和完整成本责任仍待另行只读核验；custom SMTP credential/secret、费用和持久连接继续 CLOSED |
| 管理面事实 | `ACTIVE_HEALTHY`；只证明资源存在且管理面健康，不证明 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 通过 |
| 下一批可申请动作 | B2 专项风险 Gate 草案的独立复审与 Owner/主代理 Gate；不自动进入 B2 |
| 密钥保存边界 | project URL 与 modern publishable key 仅可进入 gitignored local env 或受控 Preview env；本仓库、证据、聊天、日志、截图和客户端 bundle 不保存原值；不得读取或使用 secret/service_role/secret key/db password |
| 当前阶段 | G2-A1 执行中；B1 最小连接及配置/能力只读预检已完成；B2 CLOSED/待独立复审和专项 Gate；没有真实账号、真实 PII、Auth/DB/Storage/OAuth/SMTP 配置或运行时 Auth 证据 |

上述风险 Gate 设计已在窄范围执行；B1 最小连接与配置/能力只读预检结果见 23.5 与第 24 节，不是 broad waiver（全局豁免），也不等于 G2-A1 Auth/B1 技术通过。B2 专项风险 Gate 草案待独立复审和 Owner/主代理 Gate，不自动打开 B2/B3、P2 或 Production。

### 23.2 责任与停止合同

| 责任项 | 指定与边界 |
|---|---|
| Product / cost / stop / provider admin | Hexiang Huang；负责范围、费用确认、provider 管理面和立即停止 |
| 技术执行 | Codex 自动化执行；后续由 `luna_worker / max` 处理明确批次；Owner 保留责任和停止权 |
| 独立安全复审 | 既有文档治理复审首轮 NO-GO finding 已关闭；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge；Owner/主代理当前批准继续，但不扩大本批边界 |
| secret/key owner | Hexiang Huang；原值只在 provider/Vercel secret store 或 gitignored local env，证据只写引用/摘要 |
| 证据保管 | 仓库脱敏摘要 + provider 审计记录；不保存 URL/host/ref/ID、token、cookie、OTP、TOTP seed、secret 或真实 PII |
| 法律/隐私/税务 | A5 / 专业顾问待处理；A1 不作 GDPR、税务、跨境或处理者合同结论 |

### 23.3 复用优先结论

- **复用** `prototype/lib/supabase/client.ts` 的 `createBrowserClient`，不新建第二个浏览器 client。
- **复用/定向扩展** `prototype/lib/supabase/server.ts` 的按请求 `createServerClient` 和受控 cookie 适配；B1 只核验 SSR 边界，不新建重复 factory。
- **复用** `prototype/lib/supabase/config.ts` 与 `prototype/.env.example` 的 `NEXT_PUBLIC_SUPABASE_URL`、`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` 变量名及受控缺失配置错误；不新增别名或 secret env。
- **复用/定向扩展** `prototype/app/api/health/supabase/route.ts` 的 `/auth/v1/settings`、最小 JSON、`Cache-Control: no-store` 和 503/502/200 分支；health 200 不作为 Auth 通过。
- **保留现有演示边界** `prototype/app/account/login/LoginPrototype.tsx` 的 Apple/Google/邮箱 OTP UI；当前仅设置“等待 A1/界面演示”，不创建 session，不把点击改写为真实 Auth。
- **暂不新建** Auth hooks、业务 handlers、独立测试套件或新的 domain types；定向扫描未发现可直接复用的真实 Auth 测试。任何扩展必须在 B1 重新声明文件边界并复核。
- **复用**已固定的 `@supabase/ssr=0.12.5`、`@supabase/supabase-js=2.112.4`、Node `22.x`、pnpm `10.33.3`；本批不改依赖、lockfile、workflow、配置或源码。

### 23.4 B1 最小停止条件

出现非零费用、add-on/upgrade、生产或真实 PII 连接、service_role 依赖、secret/URL/key 进入仓库/日志/证据、无法证明 `.gitignore` 或环境隔离、health 错误泄露、无法清理、默认 SMTP 成功投递无法限定到预授权地址、需要 custom SMTP credential/secret/费用/持久连接或需要浏览器/控制台配置动作，立即停止并保留脱敏失败摘要；不得绕过 Gate 继续。B1 技术结果已回写阶段证据；B2 仍需独立复审和 action-time Owner Gate。

### 23.5 B1 最小连接验证执行结果（历史运行窗口；当前配置/能力预检见第 24 节）

- 初次 B1 运行前 connector 曾核对目标为精确的 Rebuy Lab / rebuy-auth-spike、Free、EU non-production、`eu-central-1`、`ACTIVE_HEALTHY`；独立运行时复审期间 connector 再次无法列出精确目标，当前管理面状态无法复验。未访问其他项目、未执行任何外部动作；此前本地 health `200` 仅为当时运行窗口的时间界定证据，不是当前持续健康保证。
- Chrome DOM 与内部交接曾出现一个截断的 publishable 参数展示值，该值首次导致 health `401 invalid-credential-response`，按停止条件主动停止；随后仅按授权改用 connector 返回的唯一 active modern publishable key，未创建、轮换或删除 key。该展示值不是当前 active key；只记录错误类别，不记录长度、前后缀或原值。
- `prototype/.env.local` 已由 `.gitignore:11` 忽略且权限类别为 owner-only；当前 tracked tree/diff 未发现完整 active key、host、project ref 或 secret。不对所有非 tracked 命令回显、日志、截图、浏览器输出或内部状态作绝对无值断言。
- 复用现有 config、browser/SSR client 与 `/api/health/supabase`：无配置返回 HTTP `503`，真实 local synthetic-only 连接返回 HTTP `200`，均为固定最小 JSON 并带 `Cache-Control: no-store`；health 200 不代表 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 技术通过。
- Node `22.12.0`、pnpm `10.33.3` 下 `pnpm typecheck`、`pnpm lint`、`pnpm build` 已成功；未修改源码、依赖、lockfile、workflow 或配置，build 生成的 `next-env.d.ts` 漂移已按 HEAD 恢复。localhost agent-browser 已完成 networkidle、非空、无可见 Next 错误覆盖层、console `[]`、关键元素快照与搜索→结果→商品详情导航；dev server 与浏览器均已关闭。
- （历史运行窗口）当前结论仅为 **B1 最小连接验证完成（窄范围）**；G2-A1 仍执行中，Auth/OAuth/SMTP/DB/Storage/user/session/MFA 未开始，完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续 CLOSED。独立运行时复审首次结论为 REVIEW NO-GO，本批 findings 由 `c15b11c` 修复；独立定向复审针对 `c15b11c` 给出 REVIEW GO，无未关闭 P0/P1 finding；该 review GO 仅表示本批复审闭环，不改变 B1/B2 或完整 Gate。下一步为 B1 配置/能力只读预检，不自动进入 B2。
## 24. 2026-08-28 G2-A1-B1 配置/能力只读预检（历史快照；当前 B2 见第 27 节）

- B1 配置/能力只读预检已完成，范围仅为指定 Supabase Auth 配置页面的脱敏能力观察；signup/provider、URL/redirect、邮件/SMTP、MFA、session、rate limits、attack protection 与 hooks 的分类证据见[B1 配置/能力预检证据](./evidence/G2-A1/2026-08-28-b1-capability-preflight/README.md)。
- 观察到的 Free 能力限制、TOTP/phone MFA 状态、AAL1 会话限制、session 可配置边界、邮件模板/SMTP限制和限流字段只作为配置事实记录，不等于 Auth、用户、邮件、OAuth callback、session、MFA 或 SSR 运行时通过。
- （历史状态）B2 专项风险 Gate 草案已定义独立复审、Owner/主代理 Gate、.invalid synthetic-only、三入口前提、Free 限制、停止和清理条件；当时 B2 实施仍 CLOSED。OAuth client/redirect/secret、SMTP、DB/schema、Storage、真实账号/PII、部署和 Production 继续关闭。
- 本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge。当前 B2 草案采用 hosted SMTP 仅预授权项目团队邮箱、当前基线每小时 2 封且可能变化、无 SLA/非生产探索的约束；`.invalid` 只用于 no-send/负向/反枚举，成功 OTP/Magic Link 必须使用专用 synthetic mailbox/domain、隔离 catcher 或另行批准的 custom SMTP。
- 当前 capability-preflight worktree 不包含 `prototype/.env.local`；此前连接 worktree 的 ignored/owner-only 状态不可复用。B2 执行前必须在实际 worktree 重新验证 ignored、untracked 与 mode `600`，并重新完成 action-time Owner Gate；custom SMTP credential/secret、费用、持久连接及浏览器/控制台配置动作继续 CLOSED。

## 25. 2026-08-28｜G2-A1-B2 本地安全基础实现（本地候选历史；当前外部入口 Gate 见第 27 节）

- 本批在隔离的 local worktree 实现 B2 最小 callback 安全基础：复用既有 Supabase config、browser/SSR client 与登录演示；新增 safe-next 规范化、受控 callback decision、可注入 callback handler、仅绑定 SSR client 的 `/auth/callback` 同源 no-store redirect、有限错误码映射、Node 内置契约测试和一次性 CI 测试步骤。未新建第二套 client/env/health，也未改变冻结视觉结构。
- 本批证明源码契约、typecheck、lint、build 和 12 项 Node `node:test` 契约通过；契约覆盖 code 输入门禁、稳定解码/深层编码/dot-segment、route 303/headers/origin 二次校验和 exchange 0/1 次。隔离端口 `3102` 的首页按 agent-browser-verify 完成 open/networkidle、截图、非空、无 Next 错误覆盖层、console `[]` 和交互快照；浏览器与 dev server 已关闭。因无有效 Auth 凭据或授权 code，未执行 callback 缺 code/假 code HTTP 或 Auth 运行证据。详细脱敏记录见[B2 本地安全基础证据](./evidence/G2-A1/2026-08-28-b2-local-foundation/README.md)。
- 首轮独立安全复审结论为 **REVIEW NO-GO**，发现 1 项 P1 与 2 项 P2：callback code 缺少明确长度/边界/控制字符门禁，safe-next 解码与路径边界覆盖不足，route 缺少独立可注入行为契约。本批 checkpoint 已修正：code 上限 `4096` 且无效输入在 exchange 前映射为有限错误码；safe-next 总长度 `2048`、最多 `3` 次且必须稳定；route handler 仅绑定既有 SSR client 并补齐 `303`、header、同源二次校验测试。当前仍待独立定向复审，不预写 REVIEW GO、PR、Actions 或 merge。
- 当前状态为 **B2 本地 callback 基础完成候选，待独立安全复审与 action-time Owner/主代理 Gate**；G2-A1 仍执行中。Auth 登录、OAuth initiation/provider enable、email/OTP/Magic Link、session refresh/proxy、identity linking、invite、MFA、DB/Storage、真实账号/PII、SMTP、部署和 Production 均未开始或继续关闭。
- 完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续 CLOSED；不得读取或使用 `service_role`、secret key、DB password，不得以 broad approval 绕过 Gate；本批没有创建 env、访问 Supabase dashboard 或执行外部管理动作。
- 下一步为独立安全复审；复审前不打开 B2 真实 Auth 运行、B3、P2 或任何外部配置。回退方式为移除本批新增 callback 模块、测试与登录提示，保留 B1 骨架和脱敏证据。
- 未点击 Save、Enable、Create、Reveal 或 Copy；未读取 API Keys、SQL/Table Editor、DB/Storage 数据、用户、Audit Logs 数据或管理凭据。connector 精确目标当前不可复验，未访问其他项目或执行外部写入。

## 26. 2026-08-28｜G2-A1-B2 本地安全基础远端闭环（历史快照；当前外部入口 Gate 见第 27 节）

- B2 本地安全基础已合并 main/远端闭环通过：PR #12 已以 merge commit 合并到远端 `main`，head=`55b7497953bc22e002e4c75a4b039c5b08fd98e7`，merge=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`，parents=`689d9679293f255c44feb314428a2678b9fe4d06` + `55b7497953bc22e002e4c75a4b039c5b08fd98e7`；来源分支 `codex/g2-a1-b2-local-foundation` 保留。
- 远端 `main` exact head=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`；main Actions run=`33209420614` / job=`98978680399` success，`test:auth` 12/12 且仅运行一次；exact merge 的 GitHub deployments=`0`。Vercel 仍为 `3` 个既有 deployments，Production 仍为 `READY`，aliases=`2`，本次无新增 Preview/Production deployment。
- 该 closeout 仅关闭本地安全基础的远端 source/CI 交付记录；完整 B2、real Auth/OAuth/SMTP/session/DB/Storage/Production 与外部 action-time Owner Gate 继续 CLOSED。下一步仅可进入 B2 外部入口 Gate 设计/资源检查，不预写 external Auth success；不自动打开 B3、P2 或 Production。
- 本次仅更新文档记录，不运行本地 build/tests/browser，不执行 Supabase/Auth/DB/Storage/SMTP、secret、部署或 Production 操作。

## 27. 2026-08-28｜G2-A1-B2 外部入口 Gate 设计与资源 preflight（当前）

- 本批完成 B2 external entry Gate design/preflight，风险等级 critical，执行代理 `luna_worker / max`，单一写入者，需独立安全审查；本批只写权威 Markdown 与 evidence README，不等于 B2/Auth/G2-A1 技术通过。
- 当前 `main` 为 PR #13 docs-only closeout merge=`b3e53a71ca40729b139724a492e8d20afd02f341`；main Actions run=`33212054195`/job=`98987321203` success，`test:auth` 12 项且仅运行一次，exact merge 的 GitHub deployments=`0`；Vercel 保持 3 个既有 READY deployments，本批无新增部署。
- E1 local bootstrap 仅在独立审查并合并后按条件打开，限新 Rebuy local config、合成数据、55320–55329 隔离端口和缓存复用；不登录/link hosted project、不读取 hosted secret、不干预现有 SSH/容器。E2 local email OTP/invite 依赖 E1 健康且成功邮件只进入 local catcher；E3 Google、E4 Apple、E5 hosted callback/linking/invite、custom SMTP、hosted Auth writes、DB/Storage/Production/deploy 继续 CLOSED，各需 action-time Gate。
- 只读刷新与本地 preflight：connector 目前无法列出目标资源；Chrome 历史只读观察曾确认独立 Free、EU Central/Frankfurt、`ACTIVE_HEALTHY` 且未暂停，Email/signup/confirm 开启，Phone/Google/Apple/manual linking/custom SMTP 关闭，redirect allowlist 为 0，TOTP 开启、Phone MFA 关闭，Free session controls 受限；Supabase CLI `2.101.0`、Docker `29.5.2/29.2.1` 可达；55320–55329 空闲，54321–54324 现有 SSH 监听不触碰；Mailpit PATH 缺失但缓存可见且兼容性待确认；Node 20 默认、Node `22.12.0` 已安装，既有 SSR/callback/tests 可复用。
- Hosted 默认 SMTP 仅预授权团队地址，限额动态、无 SLA；早期每小时 2 封只作历史基线。`.invalid` 只用于 no-send/负向/反枚举，成功 OTP/Magic Link/invite 使用专用 synthetic mailbox/domain 或 local catcher，不使用真实个人/客户邮箱。Google 仅 `openid`/`email`/`profile` 最小范围；Apple 需付费能力，保持 disabled/PAID-BLOCKED，不付款、注册或生成 secret。
- 任何非零费用、额外 scope、secret/PII、生产 redirect/邮件、端口冲突、现有容器变更、控制台写入或无法清理均 STOP 并另开 Gate。回退只移除未来 E1 新建的 local 对象，不删除既有 SSH、容器、远端资源或历史证据。详见[B2 外部入口 Gate 证据](./evidence/G2-A1/2026-08-28-b2-external-entry-gate/README.md)。

## 28. 2026-08-29｜G2-A1 E1 local bootstrap start 失败与 Docker/Colima mount STOP

- 本批仅执行 E1 本地运行骨架，不执行 Auth 技术验证：基于实时 `origin/main`=`b3240577026a0f390ae634f2119426842827805e` 创建唯一分支/worktree；复用 CLI `2.101.0` 的 `supabase init` 生成 config 后，以最小补丁锁定 Rebuy local-only `project_id` 与 `55320–55329` 端口范围。未改 prototype、package、lockfile 或 workflow。
- 配置事实：shadow/API/DB/Studio/Inbucket web=`55320/55321/55322/55323/55324`，analytics vector/analytics=`55326/55327`，edge inspector=`55328`，pooler=`55329` 但 disabled；SMTP/POP3 未发布；Auth signup、email signup、Google、Apple、OAuth server disabled；无 secret/env 值、custom SMTP 或 hosted link。`seed.sql` 仅 comments，无 SQL 语句和数据行。
- Cache Gate 先只检查 CLI 当前 exact refs 的通用 Supabase/Mailpit 镜像并记录候选缺失，随后按授权开启 image-download Gate。获批后的 `supabase start` Pull 阶段为 `13/13`，每项均显示 `Skipped - Image is already present locally`，没有网络 pull/download/tag；命令随后完成数据库初始化、globals/seed（comments-only）阶段，进入容器启动时因 Docker mount source `/Users/kyox215/.colima/default/docker.sock` 返回 `operation not supported` 失败，未执行 E2 OTP/invite 或任何真实 Auth。
- 本批未执行未限定的 `docker ps`，未读取其他项目容器详情；项目限定 `supabase stop --project-id rebuy-g2-a1-e1-local-bootstrap-exec` 返回成功，项目名容器、项目名 volume 和 55320–55329 TCP listener 复核均无输出。没有 hosted login/link、费用、secret、PII、Auth/DB/Storage/SMTP 写入；`supabase status` 在启动失败前后均因缺少 `supabase_db_rebuy-g2-a1-e1-local-bootstrap-exec` 返回诊断，API/DB/Studio/Mailpit health 未形成通过证据。E2–E5、hosted Auth/DB/Storage/OAuth/SMTP、业务 schema、deploy、Production 继续 CLOSED。详细脱敏记录见[E1 local bootstrap evidence](./evidence/G2-A1/2026-08-29-e1-local-bootstrap/README.md)。
