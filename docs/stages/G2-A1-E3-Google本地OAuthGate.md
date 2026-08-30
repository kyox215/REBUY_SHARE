# G2-A1-E3-Google 本地 OAuth Gate

> 文档性质：阶段 Gate 合同与 action-time 入口。当前为 CLOSED / NO-GO，不是 Google provider 启用记录，也不是 G2-A1 整体通过记录。

## 1. 当前状态

| 项目 | 当前结论 |
|---|---|
| E3 overall | **NO-GO / CLOSED** |
| 本次资料专项 | 独立 Sol 官方资料复核：P0=0；P1 聚焦 callback 固定边界、provider token 不持久化和 signup containment；Apple 依赖 hosted callback/provider；P2 为测试覆盖缺口 |
| 暴露情况 | 当前没有活动 provider 配置、secret、token、外部 OAuth 写入或真实账号暴露 |
| 当前允许 | 仅本地 code-only 安全修复、纯合同/适配层测试、文档和脱敏静态检查 |
| 当前不允许 | 创建/配置 Google Cloud project 或 OAuth client，发起 Google OAuth，读取或生成 client secret，连接 hosted/Production |

E3 的外部 provider Gate 必须在 code-only callback hardening 完成并经独立复审后另行打开。E2a 的 local GoTrue/Mailpit @rebuy.test 结论不打开 E3；E2b provider invite 也不构成 Google OAuth 或 Rebuy membership invite 授权。

## 2. 允许的未来窄 Gate

只有 Owner 在 action-time 明确批准后，才允许一次受监督、可回退的本地 Google OAuth primitive 测试。前置条件固定如下：

| 前置项 | 约束 |
|---|---|
| Google Cloud 资源 | 只用专用 Google Cloud Testing project；只创建或使用一个 Web OAuth client；不复用其他项目或 Production client |
| 费用 | 预计成本必须为 0；出现 billing、付费 API、预算或组织级费用提示立即 STOP，不自行确认 |
| origin/redirect | 只允许固定 http://127.0.0.1:3000 app origin 与固定 127.0.0.1 redirect；local GoTrue callback 只允许当日脱敏核验的 http://127.0.0.1:55321/auth/v1/callback，不接受 localhost、通配符、动态 Host 或 Host 派生地址 |
| scope | 只请求 openid、userinfo.email、userinfo.profile；对应完整 Google scope 只能是 openid、https://www.googleapis.com/auth/userinfo.email、https://www.googleapis.com/auth/userinfo.profile |
| identity | 仅伪名、合成、可删除的测试账号；不得使用真实个人、客户、员工、法定资料或真实邮箱 |
| secret | Google client secret 仅由 Owner 指定的受控 secret 位置按需注入，owner-only、ignored、短时使用；不得进入仓库、客户端 bundle、日志、截图、聊天或 evidence |
| 结束条件 | 受监督完成 callback/session、错误/取消/replay 负向、provider token 检查、撤销和删除；无法精确清理则 STOP |

Google Testing 状态及基础 scope 只是 provider 的测试配置，不是可靠的 signup containment。test user 数量、授权期限或“通常 100 个用户/通常 7 天”等规划数字不作为硬边界，不能替代应用侧 signup containment、目标 project 隔离和服务端 allowlist。

## 3. 必须先完成的 local code-only 边界

当前可以单独开一个本地安全修复批次，但这不打开 provider：

1. callback 的 scheme、origin、Host、path 和最终 redirect 必须固定 allowlist；拒绝 localhost、userinfo、非根 path、query/hash 变体、Host spoof、open redirect 和任意 next。
2. authorization state、OIDC nonce 和 PKCE verifier 必须由受信任服务端协调，短时、绑定本地会话/浏览器、一次性消费；缺失、错配、过期、重放均 fail closed。
3. authorization code 只允许在服务端一次性交换；provider access/refresh token 不落库、不进 cookie、不进客户端、不进日志/截图/evidence，内存中的短时处理结束即丢弃。
4. callback 的 provider error、scope 变化、userinfo/ID token 校验失败和 exchange 失败必须映射为有限状态，不透传 provider 原文。
5. 代码合同应证明 state、nonce、PKCE、code replay、origin/Host/path、最终 redirect 和 token persistence 的拒绝边界；合同通过不等于 live provider Gate 通过。

## 4. 允许与禁止

### 允许

- 在当前 codex/rebuy-v1-local-complete worktree 内修改 callback 安全合同、注入式适配层、Node node:test 和脱敏 docs。
- 使用纯 fake provider 响应测试错误映射、state/nonce/PKCE/replay 和 token 不落地；fake 测试不得被写成真实 Google 证据。
- 在 action-time Gate 获批后，仅对专用 Testing project、固定 loopback、伪名测试账号做一次受监督 live primitive 验证。

### 禁止

- 在当前 Gate CLOSED 时创建 Google project、OAuth client、secret、billing、额外 scope 或 provider 配置。
- 连接 hosted/Production、复用其他项目 client、允许 localhost/通配符/动态 callback，或从 Host/Referer 推导信任 origin。
- 持久化或输出 authorization code、access/refresh token、ID token、client secret、合成邮箱原值或任何真实 PII。
- 把 Google identity 直接授予 Rebuy organization、store、membership、角色、商家批准或批发资格；membership 必须由后续受保护业务流程决定。

## 5. 最小文件与测试矩阵

| 层 | 最小范围 | 必须证明 |
|---|---|---|
| callback | prototype/lib/auth/callback.ts、callback-route.ts、redirect.ts、prototype/app/auth/callback/route.ts | 固定 origin/Host/path、无 open redirect、有限 callback 状态、最终 redirect 二次校验 |
| Supabase 适配 | prototype/lib/supabase/client.ts、server.ts、config.ts 及其调用边界 | provider token 不由 client 持久化；服务端交换只发生一次且异常不吞 |
| 登录入口 | prototype/app/account/login/LoginPrototype.tsx | Google 在 Gate 关闭时 disabled；开启前不发起 OAuth，不冒充 provider 可用 |
| 契约 runner | prototype/tests/auth/contract.test.ts、prototype/scripts/run-auth-contract-tests.mjs | invalid origin/Host/path、缺 state/nonce/PKCE、错配/过期/replay、额外 scope、provider error 脱敏、token 不落地 |
| live action-time | 一次 local harness/浏览器实测，具体脚本由获批批次指定 | 只请求三项 scope、只到固定 loopback、建立 session、错误/取消/replay、token 检查、撤销/删除和 cleanup |

Live provider 结果必须与 fake contract 结果分开记录。不得用 fake replay、静态 disabled UI、Testing user 列表或“7 天”推断 signup containment 或 provider 通过。

## 6. 日志、证据与停止条件

- 日志和 evidence 只能记录固定 stage、状态码/有限 code、时间和脱敏摘要；不记录邮箱原值、authorization code、state、nonce、PKCE verifier、ID/access/refresh token、secret、cookie 或 provider 原文。
- 发现 secret/token/真实 PII、scope 超额、目标 project 漂移、callback 漂移、billing/付费、hosted/Production 目标、无法撤销删除、无法清理或任何外部副作用时立即 STOP。
- cleanup 只针对该次专用 Testing project/client、伪名账号、授权、local containers/listeners 和 ignored env；先撤销授权，再删除测试账号/client/临时配置，最后确认仓库与 evidence 无敏感值。
- E3 本文不授权任何外部写入；Apple、E5 hosted、E2b invite、P2、DB/Storage、push/deploy/Production 继续 CLOSED。

## 7. Owner exact phrase

下列为 action-time Owner phrase **模板，当前未批准、不可视为授权**。批准时必须逐字给出完整句子，不得用“同意 OAuth”“打开 B2”或宽泛 Gate 代替：

> 批准 E3 Google 本地 OAuth Gate：仅使用专用 Google Cloud Testing project、一个 Web OAuth client、零费用、固定 127.0.0.1 origins/redirect、本地 GoTrue callback、openid/userinfo.email/userinfo.profile 最小 scope、伪名合成测试账号和 owner-only ignored secret env；先通过固定 callback origin/Host/path、provider token 不持久化、state/nonce/PKCE/replay 合同；Testing test users/授权期限不作为 signup containment 硬边界；仅允许受监督实测，完成撤销与删除并保留脱敏证据。

这句话只打开本表所列 Google provider primitive，不打开 Apple、E5 hosted、membership invite、业务 DB/RLS 或 Production。

## 8. 官方来源

- [Google OAuth 2.0 for Web Server Applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect)
- [Google OAuth audience/testing 官方说明](https://support.google.com/cloud/answer/15549945?hl=en)
- [Supabase Login with Google](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Supabase Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls)
- [Supabase Auth sessions](https://supabase.com/docs/guides/auth/sessions)

以上来源只是实现和 action-time 复核依据；网页资料、Testing 状态和 UI disabled 均不能替代本地代码合同、真实受监督证据或 Owner Gate。

## 9. 2026-08-30 local callback code-only 安全准备候选（待独立复审）

- 本批状态为 **code-only 安全准备候选 / 待独立复审**；E3 external Google OAuth 仍 **NO-GO / CLOSED**，不预写 Google、Apple 或 provider 成功。Google/Apple 按钮继续 disabled。
- P1-A 已加入固定 local app origin=`http://127.0.0.1:3000`、raw Host=`127.0.0.1:3000`、pathname=`/auth/callback` 的 callback trust；request URL/Host/path/forwarded 任一越界均在 exchange 前 fail closed。success、next、login redirect 均以固定 origin 为根，并保留 safe-next、303、no-store、no-referrer 和 code 上限。
- P1-B 已把 callback 交换和持久化拆成两阶段：ephemeral client 只读取固定 Rebuy PKCE verifier、只允许精确 verifier deletion，忽略所有 session base/chunk 写入；独立 strict client 的 `setSession` 只接收 access/refresh 二元组。provider token 仅在内存提取后丢弃，不返回、不日志、不进 cookie/持久化。
- 同一 `test:auth` runner 直接覆盖 spoofed request URL/Host/path/forwarded、fixed-origin success、unsafe-next login、verifier cookie policy、provider-token sentinel projection、missing token、replay fake 和 persistence failure；fake replay 不作为真实 provider 证据。
- 真实 Google provider、state/nonce 完整合同、signup containment 和外部 callback/session 仍未执行，必须由后续独立 review 与 action-time Owner Gate 决定。脱敏记录见[code-only evidence](../evidence/G2-A1/2026-08-30-e3-code-preparation/README.md)。
