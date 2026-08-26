# 发布与 Supabase 连接记录

文档状态：本地连接骨架；G2-A1 尚未开始；本工作范围未连接 Supabase 项目，外部实际存在性 unknown

## 1. A1 边界

本记录只描述 GitHub/Vercel/Supabase 独立测试环境的连接骨架，不代表已经创建或连接任何外部项目。

- GitHub 仓库可见性保持用户指定的现状；本记录不执行可见性变更、提交、推送或部署。
- 本工作范围未创建或连接 Supabase 项目；外部项目实际存在性 unknown。
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

## 3. 环境变量与密钥边界

唯一允许的环境变量是：

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

只使用 publishable key。不得加入、读取或部署 service role、secret key、数据库密码或其他管理凭据。环境缺失时，client 工具只在被调用时抛出可控配置错误；模块导入和 Next.js build 不应因缺少环境变量崩溃。

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

这些证据只证明本地 A1 连接骨架可构建、可运行和能安全处理未配置状态；仍未创建 Supabase 项目、配置 Vercel env、启用真实登录/OAuth/SMTP，也不构成生产批准。
