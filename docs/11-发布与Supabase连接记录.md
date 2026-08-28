# 发布与 Supabase 连接记录

文档状态：本地连接骨架 + 独立资源存在性预检 + A1-B1 最小技术范围已授权/待执行（独立安全复审已完成、首轮 finding 已关闭）；G2-A1 Auth 技术阶段尚未开始；完整 resource/cost/secret Gate 关闭

## 1. A1 边界

本记录描述 GitHub/Vercel/Supabase 独立测试环境的连接骨架，并追加独立资源管理面存在性预检；不代表应用已经连接或配置 Auth、DB、Storage、OAuth、SMTP 或生产环境。

- GitHub 仓库可见性保持用户指定的现状；本记录不执行可见性变更、提交、推送或部署。
- 独立 Supabase 资源已创建并完成管理面存在性/基础健康预检；应用仍未连接该资源，完整 resource/cost/secret Gate 继续关闭。
- 尚未配置 Vercel 环境变量。
- 尚未启用真实登录、OAuth 或 SMTP。
- 不连接 production，不写入真实业务数据，不使用真实客户、商家或员工 PII。
- 当前原型没有数据库迁移、Storage、支付、订单写入或生产业务流程。

## 2. 发布包边界

当前 Next.js 应用根目录是 `prototype/`。Vercel 后续若建立独立测试项目，Root Directory 应指向 `prototype/`，构建命令使用 package script 的 `pnpm build`。

本地骨架包含：

- 根目录 `.gitignore`：排除环境文件、依赖、Next.js 生成物、Vercel 状态和 Supabase 临时状态；仅保留 `.env.example`。
- `prototype/.env.example`：只记录两个公开环境变量名称，不包含任何值。
- `prototype/lib/supabase/client.ts`：浏览器 `createBrowserClient` 工具。
- `prototype/lib/supabase/server.ts`：带 Next.js cookie 适配的 `createServerClient` 工具。
- `prototype/app/api/health/supabase/route.ts`：服务端探针，不返回 URL、key、provider 细节或错误堆栈。

`client.ts` 与 `server.ts` 都以 `createClient()` 工厂在每次调用时创建 client；server factory 每次读取当前 request cookies，并为未来 Proxy 的 cookie 写回保留受控处理。这里仅是本地连接骨架，不是 SSR、会话刷新或并发安全的运行证据。

## 3. 环境变量、密钥与授权边界

唯一允许的环境变量是：

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

只使用 publishable key。publishable key 可以出现在浏览器，但只是连接/API key，不是授权边界；服务端授权、Data API grants、RLS、Storage policy、membership 和业务状态共同决定访问。不得加入、读取或部署 service role、secret key、数据库密码或其他管理凭据。环境缺失时，client 工具只在被调用时抛出可控配置错误；模块导入和 Next.js build 不应因缺少环境变量崩溃。

后续保护页面或数据时，服务端鉴权必须使用 `supabase.auth.getClaims()`；不得使用 `getSession()` 的用户对象作为鉴权依据。

## 4. 健康探针合同

`GET /api/health/supabase` 在服务端请求 `<project>/auth/v1/settings`，并通过 `apikey` header 发送 publishable key。响应固定为最小 JSON：`configured`、`reachable`、`status`，并设置 `Cache-Control: no-store`。

| 情况 | HTTP 状态 | JSON 状态 |
|---|---:|---|
| 环境变量缺失或配置无效 | 503 | `configured: false, reachable: false, status: 503` |
| 远端不可达或返回非 2xx | 502 | `configured: true, reachable: false, status: 502` |
| 远端返回 2xx | 200 | `configured: true, reachable: true, status: 200` |

## 5. 当前验证记录

首次受限环境尝试曾遇到 pnpm store symlink 权限和 registry DNS 阻塞；随后经用户批准的 escalated pnpm 命令成功完成依赖安装，未使用 npm，也未手改 lockfile。当前固定版本为：`@supabase/ssr` `0.12.5`、`@supabase/supabase-js` `2.112.4`。

当前证据如下：`pnpm typecheck`、`pnpm lint`、`pnpm build` 全部通过。复用的本地开发服务器上，无环境变量的 `/api/health/supabase` 返回 HTTP 503，响应为 `{"configured":false,"reachable":false,"status":503}` 并带 `Cache-Control: no-store`。此前同一服务器上的 `/` 与 `/account/login` 均返回 200。

这些证据只证明本地 A1 连接骨架可构建、可运行和能安全处理未配置状态；独立 Supabase 资源的管理面状态另见下节。仍未配置 Vercel env、启用真实登录/OAuth/SMTP，也不构成 Auth、DB 或生产批准。

## 5.1 2026-08-28 独立资源存在性/基础预检

- 独立组织 `Rebuy Lab` 已创建并由 Supabase connector 核验 `plan=Free`。
- 独立项目 `rebuy-auth-spike` 已在 `eu-central-1`（Frankfurt）创建，限定 EU non-production Auth spike、synthetic-only；管理面状态为 `ACTIVE_HEALTHY`。
- provider project quote 实际返回 `amount=0`、`recurrence=monthly`；API 未返回 currency。Owner 已确认该实际 quote，随后已完成 `confirm_cost`。
- 本节只记录资源管理面事实。没有读取、记录或传播 secrets、keys、passwords、环境变量值、host、URL、project ref、组织/项目 ID 或其他账号资源标识；没有配置 Auth/DB/Storage/OAuth/SMTP，没有建表、写数据、创建真实账号、部署、promote、alias 或 Production 操作。
- Gate 仅打开到最小资源存在性/基础预检；完整 resource/cost/secret、secret/env、Auth、DB/schema/RLS、Storage、OAuth、SMTP、真实数据与 Production Gate 继续关闭。`ACTIVE_HEALTHY` 不等于 Auth/DB/运行时通过。

## 6. SSR 与发布前安全边界

- 当前 `client.ts`/`server.ts` 是按调用创建 client 的骨架；当前仓库没有已运行的 Proxy。未来 SSR 必须每请求创建新 client，避免跨请求、跨用户复用 session 或数据。
- Next.js Server Components 不能自行写 cookie；未来 Proxy 必须负责刷新 Auth token，并把刷新后的 cookie 正确写回 request/response。当前没有 cookie refresh、过期 session、并发刷新或竞态的运行证明，这些全部留给 A1 独立测试环境。
- A1 必须覆盖过期 session、刷新延迟、两个并发请求、同一用户多设备、不同用户并发、刷新失败重试和 cookie 清理；证据只保存脱敏时间线和结果，不保存 token/cookie 原值。
- `/api/health/supabase` 未配置时预期返回 503；这只证明配置缺失边界，不证明 provider 可达、Auth 已启用或 SSR 安全成立。

## 7. 2026-08-28 A1-B1 复用与 Gate 入口

- 复用现有 `prototype/lib/supabase/client.ts`、`server.ts`、`config.ts`、`.env.example` 与 `/api/health/supabase`；不新建第二套 client/config/health 实现。
- `prototype/app/account/login/LoginPrototype.tsx` 继续保持本地演示边界；Apple、Google、邮箱 OTP 点击不改写为真实 Auth，不创建真实 session。
- A1-B1 最小技术范围已获授权但待执行；独立安全复审已完成、首轮 finding 已关闭。B1 只允许复核官方 docs/changelog，读取 project URL + modern publishable key，确认 `.gitignore` 阻止 env，仅存入 gitignored local env/受控 Preview env，并用 EU non-production local synthetic-only 连接验证不依赖 service_role；不预写连接成功。
- 这不是 broad waiver（全局豁免），也不代表 G2-A1 Auth/B1 技术通过。完整 resource/cost/secret、secret/env、Auth、DB/schema/RLS、Storage、OAuth、SMTP、真实 PII、部署和 Production Gate 继续关闭；service_role、secret key、db password 继续禁止，不触碰 Production。
- 脱敏 Gate 证据见[G2-A1 B1 风险 Gate 证据](./evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)；完整资源/技术结果仍须按[阶段记录](./stages/G2-A1-Auth-Spike准备与资源门禁.md)和[15 台账](./15-项目状态与阶段台账.md)更新。

规划依据：[Supabase SSR client](https://supabase.com/docs/guides/auth/server-side/creating-a-client)、[Supabase sessions](https://supabase.com/docs/guides/auth/sessions)、[Supabase securing your API](https://supabase.com/docs/guides/api/securing-your-api)。官方页面和本地骨架都不能替代 A1/A3/A4 运行证据。
