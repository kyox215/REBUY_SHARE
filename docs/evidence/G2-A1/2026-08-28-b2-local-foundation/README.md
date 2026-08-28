# G2-A1-B2 本地安全基础实现

状态：**G2-A1 执行中；B2 本地 callback 基础完成候选，待独立安全复审与 Owner/主代理 Gate**
记录日期：2026-08-28（Europe/Rome）
证据级别：本地源码、契约测试、依赖/构建检查；浏览器运行复核受工具阻塞，不代表 Auth 运行时通过
执行风险：关键；执行代理 `luna_worker / max`，单一写入代理；Owner 保留最终责任、停止权和后续 Gate 决定

## 1. 范围与结论

本批在隔离的本地 Next.js 原型中实现最小 callback 安全基础，仅覆盖同源相对 `next` 规范化、受控 callback decision、服务端 callback route 的错误/成功重定向边界，以及登录页对有限错误码的通用提示。结论是 **候选完成**，不是 B2 或 G2-A1 Auth 技术通过。

当前状态统一为：G2-A1 执行中；B1 最小连接与配置/能力只读预检已完成；B2 本地 callback 基础完成候选；下一步为独立安全复审与 action-time Owner/主代理 Gate。完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续 CLOSED，不自动进入 B3、P2 或 Production。

## 2. 复用优先结论

- **复用**现有 `prototype/lib/supabase/config.ts`、`client.ts`、`server.ts`、既有登录演示和 `/api/health/supabase`；没有新建第二套 client、config、env 或 health route。
- **定向扩展**登录 page/演示组件，仅传入受控、有限的 callback 错误提示；Apple、Google 和邮箱入口仍是未启用的本地演示，不发送邮件、不调用 Auth。
- **新建最小纯函数与契约层**：`lib/auth/redirect.ts`、`lib/auth/callback.ts`、`app/auth/callback/route.ts`、Node 内置 `node:test` 契约测试及其临时 TypeScript runner；没有引入第三方测试依赖。
- 现有 SSR client 仅在 callback route 的有效 code 路径按请求创建并调用 `exchangeCodeForSession`；本批未接入 proxy/session refresh、identity linking、invite、MFA、DB、Storage 或业务权限。

## 3. 实现边界

### 3.1 安全 redirect 与 callback decision

- `normalizeSafeNext` 只接受同源相对路径，默认 `/`；拒绝 absolute、protocol-relative、反斜杠、控制字符、编码/双编码绕过、非法百分号编码和其他 origin。
- callback decision 先处理 provider error，再处理缺失/空 code；这两类均不调用 exchange。
- 有效 code 最多调用注入的 exchange 一次；exchange 抛错、返回有限错误对象、`null` 或 `undefined` 均映射为有限错误码，不回显或记录 raw code、provider description 或 raw error。
- route 只产生同源 `303` redirect，并设置 `Cache-Control: no-store` 与 `Referrer-Policy: no-referrer`；失败只带有限 `auth_error`，不把原始 query、code 或 provider 错误写回 URL。
- 登录页只接受 callback 模块导出的有限错误码与映射；未知值不显示状态，避免页面另维护一套枚举。

### 3.2 明确非目标

本批不实现 email/OTP verify、Magic Link 或任何 email 发送，OAuth initiation/provider enable，密码登录，session refresh/proxy，cookie/session/user 创建验证，identity linking，invite，MFA，数据库 schema/RLS，Storage，SMTP，真实账号/PII，Preview/Production 部署或 Supabase 控制台写入。

## 4. 本地验证

工具链固定为 Node `22.12.0`、Corepack pnpm `10.33.3`；依赖使用现有 lockfile，未增加测试依赖或修改 lockfile。执行结果：

| 验证 | 结果 | 说明 |
|---|---|---|
| `corepack pnpm@10.33.3 install --frozen-lockfile` | 通过 | 依赖与 lockfile 一致 |
| `corepack pnpm@10.33.3 test:auth` | 通过 | Node 内置 `node:test`，7 个契约测试通过；覆盖 safe-next 与 callback decision 正/负向、exchange 次数及脱敏边界 |
| `corepack pnpm@10.33.3 typecheck` | 通过 | 包含 Next 16 route/page 类型检查 |
| `corepack pnpm@10.33.3 lint` | 通过 | 无新增 lint 错误 |
| `corepack pnpm@10.33.3 build` | 通过 | Next 16.3.2 编译 callback route 与登录页；build 生成物未作为证据提交 |
| `.github/workflows/prototype-quality.yml` | 已更新 | `test:auth` 仅在 typecheck 后、lint 前运行一次；没有重复 post-build 测试 |
| 浏览器/开发服务器 | 未完成 | 已按 agent-browser-verify 读取的边界启动隔离端口尝试；CLI 不可用并在合理时限内阻塞，已停止 server，未绕过或伪造页面/console 证据 |

浏览器工具阻塞是本批残余风险。没有由该阻塞产生的截图、页面 load、callback 缺 code/假 code HTTP 或 console 证据；不得把本地 build/契约测试写成 Auth 运行时通过。未访问 Supabase dashboard，也未执行外部资源管理动作；本批没有有效凭据或有效授权 code，因此没有创建用户、session 或真实业务数据的运行证据。

## 5. 来源与安全控制

实现前已完整读取本 worktree 的 `prototype/AGENTS.md`、Next 16 本地 route handler、authentication、proxy、server actions、cookies、redirect 文档，以及 Supabase SSR/PKCE callback 官方资料。使用的官方资料：

- [Supabase SSR 创建 server client](https://supabase.com/docs/guides/auth/server-side/creating-a-client)
- [Supabase SSR advanced guide](https://supabase.com/docs/guides/auth/server-side/advanced-guide)
- [Supabase `exchangeCodeForSession` reference](https://supabase.com/docs/reference/javascript/auth-exchangecodeforsession)
- [Supabase social login callback guide](https://supabase.com/docs/guides/auth/social-login)

本批没有创建 `prototype/.env.local`，因此没有可复用的 env 权限结论；后续任何真实连接批次必须重新确认 `.gitignore`、untracked 和 mode `600`。不得读取或使用 `service_role`、secret key、数据库密码或其他管理凭据；公开 publishable 配置只允许在受控的 gitignored local env / action-time Preview env 中处理，不能进入仓库、证据、聊天、日志、截图或客户端 bundle。

## 6. Gate、复审与下一步

- 外部 OAuth client/redirect/secret、SMTP credential/secret、邮件投递、费用、持久连接、Auth provider enable、DB/Storage、真实用户/PII、部署和 Production Gate 继续 **CLOSED**。
- B2 本地基础实现仅为候选；需独立安全复审并由 Owner/主代理作 action-time Gate 决定后，才能讨论下一项最小运行验证。不得以用户的 broad approval 绕过 secret、Auth、DB、SMTP 或 Production 门禁。
- 浏览器验证恢复后，仍只能在隔离本地环境执行缺 code/假 code、无 overlay、console 与同源 redirect 的定向检查；成功 Auth、邮件投递、OAuth、session/user、DB/Storage 结果需另立专项证据和 Gate。
- 回退方式：撤销本批新增 route/pure modules/tests/workflow step 与登录页提示，保留历史证据，不触碰现有 B1 骨架、Supabase 资源或 Production。

当前阶段事实与路线入口：[G2-A1 准备与资源门禁](../../../stages/G2-A1-Auth-Spike准备与资源门禁.md)、[A1 执行合同](../../../10-A1-Auth-Spike执行合同.md)、[发布与 Supabase 连接记录](../../../11-发布与Supabase连接记录.md)、[项目状态与阶段台账](../../../15-项目状态与阶段台账.md)。本 README 是本批脱敏证据，不替代 15 的唯一当前状态源。
