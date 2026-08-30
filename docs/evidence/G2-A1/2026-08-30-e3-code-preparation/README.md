# G2-A1 E3 callback code-only security preparation

## 状态与边界

- 日期：2026-08-30，Europe/Rome。
- 当前结论：**code-only 安全准备候选 / 待独立复审**。
- E3 external Google OAuth：**NO-GO / CLOSED**；本证据不授权 Google/Apple、hosted Supabase、provider credentials、真实账号或外部写入。
- 本批唯一写入范围为当前 Rebuy local worktree 的 callback trust、provider-token persistence adapter、Node `node:test` 合同和脱敏文档。Google/Apple 登录按钮继续 disabled，不发起 OAuth。
- 基线：开始前 exact HEAD=`0283d483a23dbe5962bb73c1dfd5db6a98f53dd8`，工作树 clean；最终实现 ref 以本批本地 commit 为准。

## P1-A callback trust

- callback 只接受固定 local app origin `http://127.0.0.1:3000`、raw Host `127.0.0.1:3000` 和 pathname `/auth/callback`。
- `localhost`、端口/协议/路径变体、userinfo、hash、缺失或错误 Host，以及 `Forwarded`/`X-Forwarded-*`/原始 Host 代理头均在 decider/exchange 前 fail closed。
- 成功 redirect、login redirect 和 next 解析均以固定 app origin 为基准；最终 redirect 仍要求相对路径、固定 origin、`303`、`Cache-Control: no-store` 和 `Referrer-Policy: no-referrer`。
- code 长度、空白和控制字符门禁及有限错误码合同继续复用既有实现；request URL 不再作为 redirect trust root。

## P1-B provider token persistence

- callback 创建独立 ephemeral exchange client：只读 Rebuy 固定 PKCE verifier cookie，不读取持久 session cookie。
- ephemeral `setAll` 只允许精确 verifier cookie 的空值/`maxAge=0` 删除；session base/chunk、非删除 verifier 写入和 provider-token sentinel 写入均不应用。
- exchange 返回值只在内存中提取 `access_token` 与 `refresh_token`；provider access/refresh token 字段不返回、不记录、不进入 cookie 或其他持久化边界。
- 独立 strict persistence client 只接收 `{ access_token, refresh_token }` 并调用 `setSession`；exchange、token 缺失或 persistence 错误均映射为有限失败。
- verifier cleanup、固定 cookie name 和 session chunk 边界由纯 adapter 合同直接覆盖；strict cookie writer 的异常继续向 Route Handler 传播。

## 脱敏测试矩阵

| 合同 | 证明 |
|---|---|
| callback trust | URL origin、raw Host、path、forwarded header spoof 均为 exchange `0`；固定 origin 成功；unsafe next 固定回 login |
| ephemeral cookies | 只读取固定 verifier；含 provider-token sentinel 的 session base/chunk 写入 `0`；只允许 verifier deletion |
| token projection | persistence callback 只收到 access/refresh 两个字段，provider token 字段被丢弃 |
| finite failures | missing tokens、exchange/replay fake、persistence error 均为有限 code，不包含原始 provider 文本 |
| regression | 既有 OTP、body/origin、config、cookie、session、rate-limit 合同继续在同一 `test:auth` runner 中运行 |

本证据不把 fake replay 当作真实 Supabase/provider 证据；state、nonce、完整 provider signup containment 和 live provider callback 仍是 E3 external Gate 前置项。

## 执行记录

- `PATH=/Users/kyox215/.nvm/versions/node/v22.12.0/bin:$PATH corepack pnpm test:auth`：当前候选阶段 `33/33` 通过。
- 同一 Node/pnpm 工具链下 `typecheck`、`lint`：通过。
- `PATH=/Users/kyox215/.nvm/versions/node/v22.12.0/bin:$PATH corepack pnpm build`：通过；Next `16.3.2` 编译 callback route、session adapter、login 页面和现有 routes。build 造成的 `next-env.d.ts` generated reference 漂移已恢复，未进入提交。
- 当前已有 `127.0.0.1:3000` listener 未被终止；在本地 HTTP 读取权限下，`GET /account/login` 返回 `200`，脱敏 DOM/HTML 核对到本地测试认证标题、`name@rebuy.test` placeholder 和 Apple/Google disabled。worktree 没有 `agent-browser` 或 Playwright runtime，未伪造 console、视口或截图证据。
- 日志、截图和本证据不保存 email 原值、code、state、nonce、PKCE verifier、OTP、session/cookie、key、secret 或真实 PII。

## STOP 与 cleanup

- 发现 provider credential、secret/admin/service_role、真实 PII、hosted/dashboard/API 写入、非固定 redirect、非零费用或无法清理时立即 STOP。
- 本批无 Supabase runtime、local user/data、container、volume、network、listener 或外部资源写入；没有需要执行的 Auth cleanup。
- E3 external、E4 Apple、E5 hosted、E2b invite、P2/DB/RLS、custom SMTP、push/deploy/Production 继续 CLOSED。

## 官方依据

- [Supabase SSR server-side auth](https://supabase.com/docs/guides/auth/server-side)
- [Supabase Auth sessions](https://supabase.com/docs/guides/auth/sessions)
- [Supabase Login with Google](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Supabase Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls)
- [E3 Google OAuth Gate](../../../stages/G2-A1-E3-Google本地OAuthGate.md)
