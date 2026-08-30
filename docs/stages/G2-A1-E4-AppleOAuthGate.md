# G2-A1-E4-Apple OAuth Gate

> 文档性质：阶段 Gate 合同与 action-time 入口。当前为 CLOSED / NO-GO / PAID-BLOCKED，不是 Apple provider 启用记录，也不是 G2-A1 整体通过记录。

## 1. 当前状态

| 项目 | 当前结论 |
|---|---|
| E4 overall | **NO-GO / CLOSED / PAID-BLOCKED** |
| 资料专项 | Apple Developer、identifier、hosted callback/provider、signing secret、relay 是五个独立 Gate；Apple 依赖 E5 callback/provider |
| 暴露情况 | 当前没有活动 Apple provider 配置、secret、.p8、client secret、relay、hosted callback 或真实身份暴露 |
| 当前允许 | 仅本地 code-only callback/协议安全修复、纯合同测试、文档和脱敏静态检查 |
| 当前不允许 | Apple Developer enrollment、费用或法定资料、Team/App/Services ID、Key/.p8/client secret、relay、hosted provider 或真实 Apple OAuth |

Apple disabled UI、provider 名称缺失或登录按钮不可用只是当前冻结状态，不能作为 E4 通过证据。E4 只有在五个独立 Gate 按顺序单独获批后才能复审；任何一个 Gate 关闭，E4 overall 仍为 NO-GO。

本次独立 Sol 官方资料专项结论为 P0=0；P1 聚焦 callback 固定边界、provider token 不持久化、signup containment，并确认 Apple 依赖 E5 hosted callback/provider；P2 为测试覆盖缺口；当前没有活动 provider 暴露。

## 2. 五个独立 Gate 与前提

| 分项 | 当前状态 | 需要的前提 | 明确禁止 |
|---|---|---|---|
| E4-1 Apple Developer enrollment | CLOSED / PAID-BLOCKED | Owner 明确指定组织、action-time 官方费用和合法账单/法定资料处理边界 | 当前付款、注册、提交法定资料或使用个人/客户身份 |
| E4-2 Team/App/Services ID | CLOSED | E4-1 获批后，Owner 指定唯一 non-production bundle/web 标识并记录回退 | 当前创建、复用、输出任何 Team ID/App ID/Services ID |
| E4-3 hosted HTTPS callback/provider | CLOSED | E5 callback/provider 先完成对应 Gate；固定 HTTPS origin/Host/path、redirect allowlist 和环境隔离 | 当前创建 hosted callback、改 provider、放宽 redirect 或连接 hosted/Production |
| E4-4 Key/.p8/client secret | CLOSED | E4-1/E4-2/E4-3 都获批；secret 只进 owner-only 受控 secret store/ignored env，短时使用并可轮换 | 当前生成、读取、输出、提交或记录 key、.p8、client secret |
| E4-5 private email relay | CLOSED | Owner 明确 relay 责任、目标域和清理方案；仅 synthetic-only 验证 | 当前配置 relay、收集 relay 地址、真实邮件或真实 PII |

Apple Developer enrollment 的费用、法定资料、identifier、hosted HTTPS、密钥和 relay 不互相隐含授权。E4-3 明确依赖 E5 callback/provider；E4-4 的 secret 不得用普通公开环境变量或客户端配置承载。

## 3. Local code-only 边界

在所有外部 Gate CLOSED 时，可以独立进行以下本地安全工作，但不得发起 Apple OAuth：

1. callback 固定 scheme、origin、Host、path 和最终 redirect；拒绝动态 Host、localhost、通配符、open redirect、query/hash 变体和任意 next。
2. 服务端协调一次性 state、nonce、PKCE verifier、authorization code；缺失、错配、过期和 replay 必须 fail closed。
3. provider access/refresh/ID token 不落库、不进 cookie、不进客户端、不进日志/截图/evidence；exchange 异常只返回有限状态。
4. Apple relay、姓名缺失、取消授权、provider error 和邮箱不匹配只作为未来合同边界，不可由当前 disabled UI 伪造通过。
5. local test double 只能证明协议拒绝边界；不证明 Apple Developer、hosted HTTPS、relay、费用或 provider 可用。

## 4. 允许与禁止

### 允许

- 在当前 worktree 修改 callback/redirect 安全合同、注入式 OAuth 适配接口、Node node:test、脱敏证据和本 Gate 文档。
- 在所有五个分项有明确 action-time phrase 后，按一次一 Gate、一次一目标、可回退的顺序受监督验证。
- 仅使用伪名测试身份；对 authorization/token/cookie/relay 做脱敏检查，并完成撤销/删除/cleanup。

### 禁止

- 当前阶段支付 Apple Developer 费用、提交法定材料、创建或输出 Team/App/Services ID、Key/.p8/client secret、relay 或 hosted provider。
- 将 Apple identity 自动 link 到已有业务账号、组织、店铺、membership、角色或批发资格。
- 把 Apple disabled UI、缺少 provider name、静态 callback 或 fake token 结果写成 E4 通过。
- 连接 Production、使用真实 Apple 账号/邮箱/姓名、写入真实邮件或保留 provider token。

## 5. 最小文件与测试矩阵

| 层 | 最小范围 | 必须证明 |
|---|---|---|
| callback | prototype/lib/auth/callback.ts、callback-route.ts、redirect.ts、prototype/app/auth/callback/route.ts | origin/Host/path、redirect、state/nonce/PKCE、code replay 和有限错误 |
| Supabase/服务端 | prototype/lib/supabase/server.ts、config.ts、prototype/lib/auth/session.ts | 严格 cookie/session 写入；provider token 不持久化；错误不吞、不外泄 |
| 登录入口 | prototype/app/account/login/LoginPrototype.tsx | Apple 保持 disabled；不可发起 OAuth；状态文案不冒充生产可用 |
| 契约 runner | prototype/tests/auth/contract.test.ts、prototype/scripts/run-auth-contract-tests.mjs | 五项 Gate 前置拒绝、固定 callback、state/nonce/PKCE/replay、relay/姓名缺失和 provider raw error 脱敏 |
| action-time 五 Gate | 每个分项单独的短 harness/浏览器步骤和脱敏 evidence | 目标/费用/凭据范围、最小 scope、token 检查、撤销/删除、回退和 cleanup |

E4-1 至 E4-5 的 live 证据必须分别归档；一个分项的批准、测试或 secret 存在性不替代其他四项。

## 6. 凭据、费用、日志与 STOP

- Apple Developer 费用、组织/法定资料、identifier、key/.p8、client secret、relay 和 hosted callback 均需 action-time Owner 明确批准；本批默认 0 费用、0 凭据、0 外部写入。
- 任何 secret、provider token、authorization code、state、nonce、PKCE verifier、cookie、relay 地址、真实姓名/邮箱或 provider 原始错误进入日志、截图、仓库、聊天或 evidence，立即 STOP 并不继续清理之外的动作。
- 发现付费、法定资料要求、目标漂移、hosted/Production、redirect 漂移、scope 超额、provider token 持久化、无法撤销删除或无法 cleanup 时立即 STOP。
- 获批后 cleanup 顺序为撤销授权、删除伪名测试身份/identifier/relay 配置、删除短时 secret/ignored env、确认 hosted/local listener 与 evidence 无敏感值；当前不执行其中任何一步。

## 7. Owner exact phrase

以下五条是分项 action-time Owner phrase **模板，当前全部未批准、不可视为授权**。每条只能打开对应分项，不能用一条宽泛的“批准 Apple”替代：

> 批准 E4-1 Apple Developer enrollment Gate：允许 Owner 指定的 Apple Developer 组织按 action-time 官方价格和法定资料要求完成一次 non-production enrollment；当前不创建 identifier、key、relay 或 hosted callback，费用/资料超出记录范围立即 STOP。

> 批准 E4-2 Apple identifier Gate：仅在已获批 enrollment 下，为本地/指定 non-production 目标创建一个 Team/App/Services ID 组合；固定目标和回退先记录，不创建 Production 标识，不生成或读取 key。

> 批准 E4-3 Apple hosted callback/provider Gate：仅在 E5 callback/provider 先通过后，使用固定 HTTPS origin/Host/path、唯一 redirect allowlist 和 non-production Apple provider 做一次受监督 callback 验证；不打开 Production、不保存 provider token。

> 批准 E4-4 Apple signing secret Gate：仅为已获批的 non-production identifier/callback 生成或注入短时 Key/.p8/client secret；只进 owner-only 受控 secret store/ignored env，禁止仓库、客户端、日志和 evidence，测试后立即轮换/删除。

> 批准 E4-5 Apple private email relay Gate：仅使用伪名测试身份和指定 non-production relay 配置验证 relay/姓名缺失边界；不收集真实 relay/邮箱，不发真实邮件，完成撤销、删除和脱敏 cleanup。

这些模板只描述未来最小动作，当前 E4 仍 NO-GO/PAID-BLOCKED；不得把模板写成已批准原话。

## 8. 官方来源

- [Apple Developer Program enrollment](https://developer.apple.com/programs/enroll/)
- [Sign in with Apple for the web](https://developer.apple.com/help/account/configure-app-capabilities/configure-sign-in-with-apple-for-the-web/)
- [Create a private key](https://developer.apple.com/help/account/keys/create-a-private-key/)
- [Configure Private Email Relay](https://developer.apple.com/help/account/configure-app-capabilities/configure-private-email-relay-service/)
- [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/)
- [Supabase Login with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Supabase social login](https://supabase.com/docs/guides/auth/social-login)

官方来源只用于 action-time 复核和实现输入；不能替代五项 Gate、独立安全复审、Owner phrase 或 live cleanup 证据。
