# G2-A1 Auth 实测矩阵模板

用途：在 resource/cost/secret Gate 通过后，记录独立 non-production Auth spike 的可复核结果。
状态：模板，不是运行证据；当前 G2-A1 技术阶段仍未开始。
数据规则：只使用合成标签和 `.invalid` 域。禁止填写真实 email、phone、地址、客户/商家资料、密码、token、JWT、OAuth code、PKCE verifier、`state`、`nonce`、OTP、TOTP seed、cookie、API key、SMTP secret 或完整 provider payload。

## 1. 填写约定

| 字段 | 规则 |
|---|---|
| Case ID | 稳定标签，例如 `A1-AUTH-001`；不放敏感值 |
| Synthetic fixture | 只写标签，例如 `user-apple-01`、`org-demo-01`、`buyer-01@demo.invalid` |
| Environment | 只能写 `local` 或已证明隔离的 `preview-staging`；禁止 `production` |
| Observed | 记录结果分类、状态码、时间窗口、版本和脱敏摘要；原值统一写 `[REDACTED]` |
| Evidence | 写受控脱敏路径或截图标签，不嵌入原始日志/网络载荷 |
| Result | `PASS / FAIL / BLOCKED / NOT RUN`；`NOT RUN` 不得解释为通过 |
| Owner decision | 未验证能力标为后置；A1 通过需另行 Owner Gate |

## 2. 环境与版本前置记录

| 项目 | 填写值 |
|---|---|
| provider / project label | `待 Gate 通过后填写` |
| plan / region | `待 Gate 通过后填写；候选区域使用标签，不写未确认事实` |
| environment isolation evidence | `待填写` |
| SDK / CLI / runtime versions | `待填写` |
| redirect allowlist label | `https://auth-test.invalid/callback`（示例） |
| SMTP mode | `local catcher / independent test SMTP / NOT RUN` |
| Storage | `OFF unless separately authorized` |
| synthetic fixture manifest | `待填写；只列标签，不列原值` |
| test window / executor / reviewer | `待填写` |

## 3. 认证入口与 callback 矩阵

| Case ID | 入口/场景 | 合成前置 | 动作 | 预期控制 | Observed/版本/窗口 | Evidence | Result |
|---|---|---|---|---|---|---|---|
| A1-AUTH-001 | Apple 正向 | `user-apple-01`、relay label | start → provider → callback | 精确 client/redirect，identity/session 建立；不产生业务 membership | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-002 | Apple relay/无姓名 | `apple-relay-01@demo.invalid`、name-missing label | callback | relay 只作为认证事实；姓名缺失不阻断合法流程，不自动合并 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-003 | Apple 取消/错误/重复 | `user-apple-01` | cancel、provider error、replay label | 统一反枚举错误；code 一次性、失败不留原值 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-004 | Google 最小 scope | `user-google-01` | start → consent → callback | 只请求 `openid email profile`；不保存 provider token | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-005 | Google 超额 scope | `user-google-01` | inject extra-scope label | 拒绝/停止；不进入业务会话 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-006 | Google 取消/错误/不同邮箱 | `user-google-01`、`other-01@demo.invalid` | cancel/error/mismatch | 不泄露账号存在性；不自动 linking | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-007 | email OTP 正向 | `buyer-01@demo.invalid` | request → capture → verify | 控制邮箱后转 `active`；TTL/尝试次数符合配置 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-008 | email OTP 过期/重放/跨会话 | `buyer-01@demo.invalid`、otp-event-01 | expired/replay/cross-session labels | 拒绝且不泄露存在性；原值不写入日志/DB/URL | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-009 | Magic Link 后备 | `buyer-02@demo.invalid` | request → capture → consume | 只建立 identity/session；过期/重放/错误回跳拒绝 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-010 | user 状态转换 | `pending-user-01` | 三入口成功/失败/取消 | `pending_identity_verification -> active`；未 active 不可读受保护资源 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-011 | callback PKCE | `oauth-run-01`、`redirect-test-01` | valid/invalid verifier labels | verifier 与发起会话绑定；错配/缺失拒绝 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-012 | callback state | `oauth-run-02` | valid/missing/mismatch state labels | CSRF 绑定；错配拒绝 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-013 | callback nonce | `oauth-run-03` | valid/missing/mismatch nonce labels | ID token nonce 绑定；错配拒绝 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-014 | code replay | `oauth-code-event-01` | consume then replay label | code 只能兑换一次；重放拒绝 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-015 | open redirect | `next-path-01` | relative/absolute/external next labels | 只允许精确相对 `next`；外部/通配 redirect 拒绝 | `待填写` | `待填写` | `NOT RUN` |
| A1-AUTH-016 | OAuth token response | `oauth-token-event-01` | simulate 2xx response labels | 接受成功 2xx，不硬编码 201；失败分类脱敏 | `待填写` | `待填写` | `NOT RUN` |

## 4. Identity linking / unlink 与邀请目标邮箱

| Case ID | 场景 | 合成前置 | 预期控制 | Observed/Evidence | Result |
|---|---|---|---|---|---|
| A1-LINK-001 | email OTP → Google 同验证邮箱 | `buyer-01@demo.invalid`、`user-google-01` | 只有实际实测后决定是否允许；重新认证并审计 | `待填写` | `NOT RUN` |
| A1-LINK-002 | email OTP → Apple relay | `buyer-02@demo.invalid`、`relay-02@demo.invalid` | 只按已验证精确邮箱；relay/姓名不作推断 | `待填写` | `NOT RUN` |
| A1-LINK-003 | Google ↔ Apple 不同邮箱 | `user-google-01`、`user-apple-02` | 拒绝自动合并；不搬运订单/membership/资格 | `待填写` | `NOT RUN` |
| A1-LINK-004 | 手动 link | `security-center-01` | 安全中心发起、重新认证、目标 identity 验证、事件审计 | `待填写` | `NOT RUN` |
| A1-LINK-005 | unlink 保留可用方式 | `user-link-01`、`identity-a/b` | 至少保留一个已验证可用登录方式 | `待填写` | `NOT RUN` |
| A1-LINK-006 | unlink 最后方式/陈旧 session | `user-link-02` | 拒绝或升级验证；旧 session 按策略处理 | `待填写` | `NOT RUN` |
| A1-LINK-007 | 邀请目标邮箱 OTP | `invite-01`、`target-01@demo.invalid` | 先证明目标邮箱控制权，再进入允许的 link 流程 | `待填写` | `NOT RUN` |
| A1-LINK-008 | 邀请 identity mismatch | `target-01@demo.invalid`、`other-identity-01` | Apple/Google 已验证邮箱不精确匹配则拒绝 | `待填写` | `NOT RUN` |
| A1-LINK-009 | 邀请 token/并发/撤销 | `invite-02`、`invite-03` | hash/期限/一次性/并发单成功；新邀请撤销旧 token | `待填写` | `NOT RUN` |
| A1-LINK-010 | 邀请反枚举 | `target-missing@demo.invalid` | 成功/失败响应不泄露组织、角色或邮箱存在性 | `待填写` | `NOT RUN` |

## 5. MFA、TOTP、AAL2 与人工恢复

| Case ID | 场景 | 合成前置 | 预期控制 | Observed/Evidence | Result |
|---|---|---|---|---|---|
| A1-MFA-001 | 主 TOTP enrollment | `admin-01`、`totp-device-primary-01` | enrollment → challenge → verify；仅写因子标签，不写 seed/QR | `待填写` | `NOT RUN` |
| A1-MFA-002 | 主 TOTP 负向/限流 | `admin-01` | wrong/replay/rate-limit labels | 拒绝、限流、通知和审计 | `待填写` | `NOT RUN` |
| A1-MFA-003 | AAL2 提升 | `admin-01` | conventional login → TOTP verify | 高权限动作前达到 `aal2`；服务端/DB/API 同步 enforce | `待填写` | `NOT RUN` |
| A1-MFA-004 | 备用 TOTP | `admin-01`、`totp-device-backup-01` | 第二因子位于不同设备/安全位置 | 不接受同设备或未验证替代；记录因子元数据标签 | `待填写` | `NOT RUN` |
| A1-MFA-005 | 备用因子撤销/重复 | `admin-01`、`totp-device-backup-01` | revoke/re-enroll/replay labels | 状态、通知、审计符合合同；不恢复为静态码 | `待填写` | `NOT RUN` |
| A1-MFA-006 | 人工恢复双人复核 | `admin-01`、`reviewer-a`、`reviewer-b` | 身份核验 → 独立批准 → AAL/session reset → 通知/审计 | support 不得单人批准；禁止自审 | `待填写` | `NOT RUN` |
| A1-MFA-007 | 人工恢复负向 | `admin-01`、`reviewer-a` | no-proof/single-reviewer/unverified-email labels | 缺少核验、职责分离或通知则拒绝 | `待填写` | `NOT RUN` |
| A1-MFA-008 | 六类高风险操作 | `risk-action-01…06`、`reviewer-a/b` | MFA 恢复、owner 转移、权限策略变更、敏感导出、隐私删除/导出、证明文件高风险访问均双人复核 | `待填写` | `NOT RUN` |
| A1-MFA-009 | phone/SMS 与静态恢复码 | `admin-01` | V1 产品范围排除；不以未验证 provider UI 代替 | `Not applicable by Owner decision` | `NOT RUN` |

## 6. Session / signOut / token 窗口

| Case ID | 场景 | 合成前置 | 预期控制 | Observed/Evidence | Result |
|---|---|---|---|---|---|
| A1-SESSION-001 | `signOut` local | `session-a/b` | 当前 session/cookie 清理；其他设备按实际语义保留或失效 | `待填写` | `NOT RUN` |
| A1-SESSION-002 | `signOut` global | `session-a/b` | 所有 session 受影响；记录 refresh/access token 观察窗口 | `待填写` | `NOT RUN` |
| A1-SESSION-003 | `signOut` others | `session-a/b/c` | 当前 session 保留，其余按实际语义失效；若不支持则记录 | `待填写` | `NOT RUN` |
| A1-SESSION-004 | session_id 关联 | `session-a`、`session-b` | 只在最小服务端权限下核对 session_id；禁止浏览器跨用户读取 | `待填写` | `NOT RUN` |
| A1-SESSION-005 | token exp 窗口 | `revoked-session-01` | 记录撤销后 access token 到 `exp` 的观察；不宣称即时失效 | `待填写` | `NOT RUN` |
| A1-SESSION-006 | lifetime/single-session | `user-session-01`、plan label | 记录 plan、配置、刷新时点与实际观察；Pro 约束单独标注 | `待填写` | `NOT RUN` |
| A1-SESSION-007 | refresh/replay | `refresh-event-01` | refresh token 一次性、过期/重放拒绝；原值不落证据 | `待填写` | `NOT RUN` |

## 7. 反枚举、限流与 SSR 并发串线

| Case ID | 场景 | 合成前置 | 预期控制 | Observed/Evidence | Result |
|---|---|---|---|---|---|
| A1-RISK-001 | email/user enumeration | `known-01@demo.invalid`、`missing-01@demo.invalid` | 文案、状态码、延迟和事件摘要尽量一致，不泄露存在性 | `待填写` | `NOT RUN` |
| A1-RISK-002 | OTP/invite/recovery rate limit | `rate-limit-user-01` | 记录阈值/窗口/Retry-After 标签；超限停止发送/恢复 | `待填写` | `NOT RUN` |
| A1-RISK-003 | OAuth callback rate limit | `oauth-abuse-01` | 错误/重放/超限不产生 session 或业务写入 | `待填写` | `NOT RUN` |
| A1-RISK-004 | SSR 每请求新 client | `user-a`、`user-b` | 并发请求不共享 client/cookie；服务端授权隔离 | `待填写` | `NOT RUN` |
| A1-RISK-005 | cookie refresh 并发 | `user-a`、`refresh-a/b` | request/response cookie 更新不串线、不覆盖另一用户 | `待填写` | `NOT RUN` |
| A1-RISK-006 | cache/route reuse | `user-a`、`user-b`、`cache-key-01` | 缓存键含必要隔离，禁止跨用户内容命中 | `待填写` | `NOT RUN` |

## 8. 日志、DB、cache、Network 与 bundle secret scan

| Case ID | 扫描面 | 合成输入标签 | 必须检查 | Observed/Evidence | Result |
|---|---|---|---|---|---|
| A1-SCAN-001 | Auth/应用日志 | `scan-run-01` | 无 email 原文、OAuth code、PKCE/state/nonce、OTP/TOTP、token/cookie、secret | `待填写` | `NOT RUN` |
| A1-SCAN-002 | DB/Auth/Storage | `scan-run-02` | 无 provider token、refresh token、密钥原值或未授权 PII；权限/日志最小化 | `待填写` | `NOT RUN` |
| A1-SCAN-003 | cache/queue | `scan-run-03` | 短时材料消费后不留原值；清理/TTL 可复核 | `待填写` | `NOT RUN` |
| A1-SCAN-004 | Browser Network | `scan-run-04` | 服务端 secret 不进浏览器；URL/header/body 不含原始敏感材料 | `待填写` | `NOT RUN` |
| A1-SCAN-005 | client bundle/source | `scan-run-05` | 无 service role、OAuth/SMTP secret、`.p8`、TOTP seed 或测试凭据 | `待填写` | `NOT RUN` |
| A1-SCAN-006 | evidence export | `scan-run-06` | 只公开结果分类、标签和不可逆摘要；不公开原始附件 | `待填写` | `NOT RUN` |

## 9. 失败与 closeout

### 9.1 立即停止条件

- 任何测试请求触及 Production、真实 PII、真实邮件/文件、未授权组织/项目、生产 client/secret 或未批准费用。
- callback 接受错误/重放 code、PKCE、`state`、`nonce`，存在 open redirect、跨环境 client 或额外 Google scope。
- token/provider secret/OTP/TOTP seed/cookie 进入 DB、日志、cache、Network、bundle、截图或证据；无法证明清理。
- linking/邀请绕过邮箱控制权或重新认证；人工恢复缺少双人职责分离、AAL/会话重置、通知或审计。
- SSR/缓存/并发出现跨用户串线；session/token 观察被误报成即时失效。

### 9.2 Closeout 字段

| 字段 | 填写值 |
|---|---|
| test window / provider version | `待填写` |
| executed cases / PASS / FAIL / BLOCKED / NOT RUN | `待填写` |
| evidence bundle path | `docs/evidence/G2-A1/<date>-<batch>/` |
| secret/PII scan summary | `待填写脱敏摘要` |
| cleanup / expiry / rollback evidence | `待填写` |
| unresolved risks / follow-up ADR | `待填写` |
| independent security review | `待填写` |
| Owner Gate decision | `未决定；A1 技术阶段未开始` |

矩阵填完不等于 A1 通过。只有所有必要正/负向案例、扫描、隔离、回退和独立审查证据完成，且 Owner 明确签署后，才能判断 A1 是否打开下一阶段；任何 `NOT RUN` 或 `BLOCKED` 必须保持可见。
