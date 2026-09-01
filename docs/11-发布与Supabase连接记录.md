# 发布与 Supabase 连接记录

文档状态：本地连接骨架 + 独立资源存在性预检 + A1-B1 最小连接与配置/能力只读预检 + B2 本地安全基础及远端闭环已完成；当前 B2 external entry Gate design/preflight 已完成。PR #13 docs-only closeout merge=`b3e53a71ca40729b139724a492e8d20afd02f341`，main Actions run=`33212054195`/job=`98987321203` success，`test:auth` 12 项且仅运行一次，exact merge 的 GitHub deployments=`0`，Vercel 无新增部署；该闭环仅关闭文档 Gate 设计与本地基础交付，不等于完整 B2/Auth/G2-A1 整体通过；G2-A1 仍执行中，真实 Auth/OAuth/SMTP/DB/Storage/user/session/MFA 未开始；E1 local bootstrap 仍待独立审查后按 Gate 打开，E2–E5、hosted Auth/SMTP/DB/Storage/Production/deploy 全部继续 CLOSED；完整 resource/cost/secret Gate 关闭

## 1. A1 边界

本记录描述 GitHub/Vercel/Supabase 独立测试环境的连接骨架，并追加独立资源管理面存在性预检与 B1 最小本地连接结果；不代表应用已经配置 Auth、DB、Storage、OAuth、SMTP 或生产环境。

- GitHub 仓库可见性保持用户指定的现状；本记录不执行可见性变更、提交、推送或部署。
- 独立 Supabase 资源已创建并完成管理面存在性/基础健康预检；应用仅在本地 synthetic-only 范围完成 settings health 连接验证，完整 resource/cost/secret Gate 继续关闭。
- 尚未配置 Vercel 环境变量。
- 尚未启用真实登录、OAuth 或 SMTP。
- 不连接 production，不写入真实业务数据，不使用真实客户、商家或员工 PII。
- 当前原型没有数据库迁移、Storage、支付、订单写入或生产业务流程。

## 2. 发布包边界

当前 Next.js 应用根目录是 `prototype/`。Vercel 后续若建立独立测试项目，Root Directory 应指向 `prototype/`，构建命令使用 package script 的 `pnpm build`。

本地骨架包含：

- 根目录 `.gitignore`：排除环境文件、依赖、Next.js 生成物、Vercel 状态和 Supabase 临时状态；仅保留 `.env.example`。
- `prototype/.env.example`：当前只记录两个 server-only 环境变量名称，不包含任何值。
- `prototype/lib/supabase/client.ts`：浏览器 `createBrowserClient` 工具。
- `prototype/lib/supabase/server.ts`：带 Next.js cookie 适配的 `createServerClient` 工具。
- `prototype/app/api/health/supabase/route.ts`：服务端探针，不返回 URL、key、provider 细节或错误堆栈。

`client.ts` 与 `server.ts` 都以 `createClient()` 工厂在每次调用时创建 client；server factory 每次读取当前 request cookies，并为未来 Proxy 的 cookie 写回保留受控处理。这里仅是本地连接骨架，不是 SSR、会话刷新或并发安全的运行证据。

## 3. 环境变量、密钥与授权边界

当前 tracked `prototype/.env.example` 与实现使用的 server-only 环境变量是：

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

只使用 publishable key。当前 release 将其限制为 server-only configuration；它不是授权边界，服务端授权、Data API grants、RLS、Storage policy、membership 和业务状态共同决定访问。不得加入、读取或部署 service role、secret key、数据库密码或其他管理凭据。环境缺失时，server-side client/config 工具只在被调用时抛出可控配置错误；模块导入和 Next.js build 不应因缺少环境变量崩溃。

早期记录中的 `NEXT_PUBLIC_SUPABASE_URL` 与 `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` 保留为历史 browser-facing skeleton 名称；它们不是当前 tracked `prototype/.env.example` 或当前 release runtime 的事实，不静默抹除历史。

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

当前证据如下：`pnpm typecheck`、`pnpm lint`、`pnpm build` 全部通过。复用的本地开发服务器上，无环境变量的 `/api/health/supabase` 返回 HTTP 503，响应为 `{"configured":false,"reachable":false,"status":503}` 并带 `Cache-Control: no-store`；在当时 connector 返回的目标 Free 项目 active modern publishable key 下返回 HTTP 200，响应为 `{"configured":true,"reachable":true,"status":200}` 并同样带 `Cache-Control: no-store`。该 200 仅属于当时运行窗口的时间界定证据，不是当前持续健康保证；运行时复审期间 connector 无法再次列出精确目标。localhost 页面完成 networkidle、非空、无可见 Next 错误覆盖层、console errors 为空和关键元素快照；搜索→结果→商品详情导航通过。

这些证据只证明本地 A1 连接骨架可构建、可运行、能安全处理未配置状态并可达目标 settings health；不构成 Auth、DB、SSR 或生产批准。仍未配置 Vercel env、启用真实登录/OAuth/SMTP。

## 5.1 2026-08-28 独立资源存在性/基础预检（历史资源快照；当前 B2 外部入口 Gate 见第 11 节）

- 独立组织 `Rebuy Lab` 已创建并由 Supabase connector 核验 `plan=Free`。
- 独立项目 `rebuy-auth-spike` 已在 `eu-central-1`（Frankfurt）创建，限定 EU non-production Auth spike、synthetic-only；在初次资源核验/运行窗口管理面状态为 `ACTIVE_HEALTHY`。
- provider project quote 实际返回 `amount=0`、`recurrence=monthly`；API 未返回 currency。Owner 已确认该实际 quote，随后已完成 `confirm_cost`。
- 本节只记录资源管理面历史事实；后续 B1 连接执行另见 5.2。资源预检证据范围不包含 secrets、passwords、环境变量值、host、URL、project ref、组织/项目 ID 或其他账号资源标识；没有配置 Auth/DB/Storage/OAuth/SMTP，没有建表、写数据、创建真实账号、部署、promote、alias 或 Production 操作。
- Gate 仅打开到最小资源存在性/基础预检；完整 resource/cost/secret、secret/env、Auth、DB/schema/RLS、Storage、OAuth、SMTP、真实数据与 Production Gate 继续关闭。`ACTIVE_HEALTHY` 不等于 Auth/DB/运行时通过。

## 6. SSR 与发布前安全边界

- 当前 `client.ts`/`server.ts` 是按调用创建 client 的骨架；当前仓库没有已运行的 Proxy。未来 SSR 必须每请求创建新 client，避免跨请求、跨用户复用 session 或数据。
- Next.js Server Components 不能自行写 cookie；未来 Proxy 必须负责刷新 Auth token，并把刷新后的 cookie 正确写回 request/response。当前没有 cookie refresh、过期 session、并发刷新或竞态的运行证明，这些全部留给 A1 独立测试环境。
- A1 必须覆盖过期 session、刷新延迟、两个并发请求、同一用户多设备、不同用户并发、刷新失败重试和 cookie 清理；证据只保存脱敏时间线和结果，不保存 token/cookie 原值。
- `/api/health/supabase` 未配置时预期返回 503；这只证明配置缺失边界，不证明 provider 可达、Auth 已启用或 SSR 安全成立。

## 5.2 2026-08-28 A1-B1 最小连接验证

- 初次 B1 运行前 connector 曾核对目标为 `Rebuy Lab` / `rebuy-auth-spike`、Free、`eu-central-1`、`ACTIVE_HEALTHY`；独立运行时复审期间 connector 再次无法列出精确目标，当前管理面状态无法复验。未访问其他项目、未执行任何外部动作；此前本地 health `200` 仅为当时运行窗口的时间界定证据，不是当前持续健康保证。
- 首次 Chrome 交接的截断参数触发 `401 invalid-credential-response`，已按停止条件主动停止；Owner/主代理随后授权改用 connector 对精确目标返回的唯一 active modern publishable key，未创建、轮换或删除 key。
- 按授权将初次运行窗口的 URL/key 原值写入被 `.gitignore:11` 忽略且 owner-only 的 `prototype/.env.local`。Chrome DOM 与内部交接曾出现一个截断的 publishable 参数展示值，该值触发 `401 invalid-credential-response` 后停止，且不是当前 active key；当前 tracked tree/diff 未发现完整 active key、host、project ref 或 secret。不对所有非 tracked 聊天、日志、server/browser 输出或内部状态作绝对无值断言。
- 无配置路径返回 HTTP `503` 固定最小 JSON；真实本地连接返回 HTTP `200` 固定最小 JSON；两者均为 `Cache-Control: no-store`。health 200 仅表示 settings endpoint 可达，不表示 Auth、MFA、session、DB、RLS、Storage、OAuth、SMTP 或 SSR 技术通过。
- 用 Node `22.12.0`、pnpm `10.33.3`、固定 `@supabase/ssr`/`@supabase/supabase-js` 版本复用既有实现；无源码、依赖、lockfile、workflow 或配置改动。浏览器与 dev server 已关闭。

## 7. 2026-08-28 A1-B1 复用与 Gate 入口

- 复用现有 `prototype/lib/supabase/client.ts`、`server.ts`、`config.ts`、`.env.example` 与 `/api/health/supabase`；不新建第二套 client/config/health 实现。
- `prototype/app/account/login/LoginPrototype.tsx` 继续保持本地演示边界；Apple、Google、邮箱 OTP 点击不改写为真实 Auth，不创建真实 session。
- A1-B1 最小连接与配置/能力只读预检已完成；既有文档治理复审首轮 finding 已关闭。本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge。B1 已按授权复核官方 docs/changelog，初次运行窗口读取目标 project URL + active modern publishable key，确认 `.gitignore` 阻止 env，仅存入 gitignored local env，并用 EU non-production local synthetic-only 连接验证不依赖 service_role。
- 这不是 broad waiver（全局豁免），也不代表 G2-A1 Auth/B1 技术通过。完整 resource/cost/secret、secret/env、Auth、DB/schema/RLS、Storage、OAuth、SMTP、真实 PII、部署和 Production Gate 继续关闭；service_role、secret key、db password 继续禁止，不触碰 Production。
- B1 配置/能力只读预检已完成；当前进入 B2 本地 callback 安全基础实现候选，待独立安全复审与 Owner/主代理 Gate。脱敏结果见[B1 配置/能力预检证据](./evidence/G2-A1/2026-08-28-b1-capability-preflight/README.md)、[B1 风险 Gate 证据](./evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)和[B2 本地基础证据](./evidence/G2-A1/2026-08-28-b2-local-foundation/README.md)；不自动打开真实 B2，完整资源/技术结果仍须按[阶段记录](./stages/G2-A1-Auth-Spike准备与资源门禁.md)和[15 台账](./15-项目状态与阶段台账.md)更新。

规划依据：[Supabase SSR client](https://supabase.com/docs/guides/auth/server-side/creating-a-client)、[Supabase sessions](https://supabase.com/docs/guides/auth/sessions)、[Supabase securing your API](https://supabase.com/docs/guides/api/securing-your-api)。官方页面和本地骨架都不能替代 A1/A3/A4 运行证据。
## 8. 2026-08-28 A1-B1 配置/能力只读预检（历史快照；当前 B2 见第 11 节）

- 通过已登录 Supabase dashboard 的指定 Auth configuration 页面完成脱敏只读观察：signup/provider、URL/redirect、Email/SMTP/template、MFA、session、rate limits、attack protection 与 hooks。精确目标的组织/项目/Free 标签可见；Auth 页面未显示区域，区域沿用既有 EU non-production 资源记录。
- 未点击 Save、Enable、Create、Reveal 或 Copy；未读取 API Keys、SQL/Table Editor、数据库/Storage 数据、用户、Audit Logs、secret、service_role、DB password 或真实 PII；未发送邮件、启用 OAuth、配置 MFA、写入 DB/Storage 或修改 Production。
- （历史状态）当前结论仅为 B1 配置/能力只读预检完成，不能写成 Auth/B1 技术通过。B2 专项风险 Gate 草案与三入口前提见[B1 配置/能力预检证据](./evidence/G2-A1/2026-08-28-b1-capability-preflight/README.md)，当时 B2 与完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续 CLOSED。
- connector 当前无法再次列出精确目标，未访问其他项目或执行外部写入；该管理面漂移和 ignored local env cleanup 仍是残余风险。
- 依据 [Supabase Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)、[Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits) 与 [Free 邮件模板变更](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier)，hosted 默认 SMTP 仅向项目团队预授权邮箱发送，当前基线每小时 2 封且可能变化、无 SLA，仅用于非生产探索；`.invalid` 只用于 no-send/负向/反枚举，成功 OTP/Magic Link 必须使用专用 synthetic test mailbox/domain、隔离 catcher 或另行批准的 custom SMTP。
- custom SMTP credential/secret、费用、持久连接及浏览器/控制台配置动作继续 CLOSED；每次实际动作需要 action-time Owner Gate，不能以总体批准替代。当前 capability-preflight worktree 不包含 `prototype/.env.local`，B2 执行前必须重新验证 ignored、untracked 和 mode `600`，不能沿用旧连接 worktree 权限结论。
- 本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开 B2 或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge。

## 9. 2026-08-28｜G2-A1-B2 本地 callback 安全基础实现（本地候选历史；当前外部入口 Gate 见第 11 节）

- 本批复用既有 `prototype/lib/supabase/config.ts`、`client.ts`、`server.ts`、登录演示和 health route；新增最小 safe-next/callback decision 纯函数、可注入 callback handler、仅绑定 SSR client 的 `/auth/callback` route、有限登录错误映射、Node 内置契约测试与一次性 workflow 测试步骤。未新建第二套 client、env、health 或业务 Auth handler。
- callback 只接受同源相对 `next`，provider error/缺 code 不执行 exchange；空/全空白 code 为 `missing_code`，边界空白、控制/格式字符或超过 `4096` 字符为 `invalid_code`，有效 code 的 exchange 最多执行一次，异常或空结果归一到有限错误码；safe-next 总长度上限 `2048` 且最多 `3` 次稳定解码；route 使用同源 `303`、`no-store`/`no-referrer`，并做最终 origin 二次校验，不回显 callback 原始参数或 provider error。该结论来自源码和契约测试，不是成功 Auth exchange 证据。
- `install --frozen-lockfile`、`test:auth`（12 项）、`typecheck`、`lint`、`build` 已通过。首轮独立安全复审为 REVIEW NO-GO，1 项 P1 与 2 项 P2 已在当前 checkpoint 修正，待独立定向复审；隔离端口 `3102` 首页按 agent-browser-verify 完成 open/networkidle、截图、非空、无错误覆盖层、console `[]` 和交互快照，server 已关闭；因无有效 Auth 凭据或授权 code，未执行 callback 缺 code/假 code HTTP 或 Auth 运行证据，详见[B2 本地安全基础证据](./evidence/G2-A1/2026-08-28-b2-local-foundation/README.md)。
- 当前仅为 B2 本地 callback 基础完成候选，待独立安全复审与 action-time Owner/主代理 Gate；真实 Auth/OAuth/provider、email/OTP/Magic Link、session/user、MFA、DB/Storage、SMTP、真实 PII、部署和 Production Gate 均继续 CLOSED。

## 10. 2026-08-28｜G2-A1-B2 本地安全基础远端闭环（历史快照；当前外部入口 Gate 见第 11 节）

- B2 本地安全基础已合并 main/远端闭环通过：PR #12 已以 merge commit 合并到远端 `main`，head=`55b7497953bc22e002e4c75a4b039c5b08fd98e7`，merge=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`，parents=`689d9679293f255c44feb314428a2678b9fe4d06` + `55b7497953bc22e002e4c75a4b039c5b08fd98e7`；来源分支 `codex/g2-a1-b2-local-foundation` 保留。
- 远端 `main` exact head=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`；main Actions run=`33209420614` / job=`98978680399` success，`test:auth` 12/12 且仅运行一次；exact merge 的 GitHub deployments=`0`。Vercel 仍为 `3` 个既有 deployments，Production 仍为 `READY`，aliases=`2`，本次无新增 Preview/Production deployment。
- 该 closeout 仅关闭本地安全基础的远端 source/CI 交付记录；完整 B2、real Auth/OAuth/SMTP/session/DB/Storage/Production 与外部 action-time Owner Gate 继续 CLOSED。下一步仅可进入 B2 外部入口 Gate 设计/资源检查，不预写 external Auth success；不自动打开 B3、P2 或 Production。
- 本次仅更新文档记录，不运行本地 build/tests/browser，不执行 Supabase/Auth/DB/Storage/SMTP、secret、部署或 Production 操作。

## 11. 2026-08-28｜G2-A1-B2 外部入口 Gate 设计与资源 preflight（当前）

- 当前 `main` 为 PR #13 docs-only closeout merge=`b3e53a71ca40729b139724a492e8d20afd02f341`；main Actions run=`33212054195`/job=`98987321203` success，`test:auth` 12 项且仅运行一次；exact merge 的 GitHub deployments=`0`；Vercel 仍有 3 个既有 READY deployments，本批无新增部署。
- 本批只更新本记录与相关权威 Markdown，完成 B2 external entry Gate design/preflight；没有修改源码、workflow、package、lockfile、env、配置或生成物，没有 push/PR/hosted Auth/OAuth/SMTP/DB/Storage 写入，没有部署。
- connector 当前只显示另一账号资源，无法列出目标；已登录 Chrome 控制台的只读观察曾确认独立 Free、EU Central/Frankfurt、`ACTIVE_HEALTHY` 且未暂停。Email/signup/confirm 状态、provider、redirect、TOTP、Phone MFA 与 Free session 限制仅作脱敏配置事实记录，不作当前持续健康或 Auth 通过结论；临时浏览器标签已关闭且无配置写入。
- 本地 preflight 记录 Supabase CLI `2.101.0`、Docker client/server `29.5.2`/`29.2.1` 可达、running `14`/total `19` 计数、Mailpit PATH 缺失但缓存可见（兼容性待确认）、Node 20 默认且 Node `22.12.0` 已安装、55320–55329 空闲；54321–54324 现有 SSH 监听不触碰；现有 SSR/callback/tests 可复用，env/temp ignore 仍需在 E1 实际 worktree 重验。
- E1 local bootstrap 可在本 Gate 独立审查并合并 main 后按条件打开，仅限新 Rebuy local config、合成数据、55320–55329 和缓存复用；E2 local OTP/invite、E3 Google、E4 Apple、E5 hosted callback/linking/invite、custom SMTP、hosted Auth writes、DB/Storage/Production/deploy 继续 CLOSED。拉新镜像、非零费用、端口冲突、修改现有容器或无法清理均 STOP 并另开 Gate。
- hosted 默认 SMTP 仅预授权团队地址、限额动态且无 SLA；早期每小时 2 封只作历史基线。`.invalid` 只用于 no-send/负向/反枚举，成功路径使用专用 synthetic mailbox/domain 或 local catcher；不得用真实个人/客户邮箱。Google/Apple 需各自的 action-time Gate，Apple 继续 disabled/PAID-BLOCKED。
- 细节与官方链接见[B2 外部入口 Gate 证据](./evidence/G2-A1/2026-08-28-b2-external-entry-gate/README.md)。本批不把设计、资源观察、本地 preflight 或远端 docs/CI 事实写成 B2/Auth/G2-A1 技术通过。

## 12. 2026-08-30｜Git/Vercel/Supabase 只读 refresh（当前纠正）

- GitHub 只读核对：`git ls-remote origin refs/heads/main` 仍精确为 `de6a3203e20a1a4cea1106baef7bee1b4173d38f`；候选基线 `ea458ff6b97a9f16617fc2a8eec40013792672e5` 为 `origin/main +11`，worktree clean，远端 `codex/rebuy-v1-local-complete` 不存在。本候选 diff 为 `38` files、约 `+3709/-142`；`git diff --check origin/main...HEAD` PASS。tracked env 仅 env example/next-env/历史文档类别；private key、`sb_secret`、`service_role` 赋值及 JWT 字面量扫描 `NO_MATCH`。
- `d60c058` 的未变源码证据仍为 `test:auth 37/37`、typecheck、lint、build 通过；`ea458ff` 为 docs-only。本批未重跑这些命令。结论是 GitHub source push candidate，不是 deploy/production candidate；本批仍未 push。
- Vercel 只读事实：项目 `rebuy-share` 存在且为 Next.js，`link=null`（无 Git integration），project setting 为 Node `24.x`，仓库 engines 为 Node `22.x`；历史部署的 resolved Node 22 证据保留，但属于设置漂移。inventory 仍精确 `3` 个 READY deployments（2 Preview、1 Production），无新增。latest good Preview 为 `dpl_D2oNMJhvQsvbbyszgApm24aGLYnZ`，source=CLI、Target=Preview/null target、Next `16.3.2`，route inventory 含 `/api/health/app` 与 `/api/health/supabase`。
- Production `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` 仍 READY/production 且有 `2` 个 aliases；公开根页 HTTP `200`，但 `/api/health/app` 与 `/api/health/supabase` 均 `404`，`x-matched-path=/404`。根因是旧 Production artifact 不含健康路由，不是已证明的函数或 Supabase outage。Preview 受 Vercel Authentication 保护，普通/临时只读访问均停在 `302` SSO cookie handshake；本批无新的 Preview runtime health 结论。未保存 share URL、token、cookie、alias URL 或 creator email；不创建 deployment，不改 Protection、aliases、settings、env 或 Git link。
- Supabase 只读事实：当前已认证 connector 不列出 Rebuy 目标，仅列其他项目；立即停止，未访问其他项目详情、未写任何资源。Rebuy hosted target 当前状态不可复验，历史 `ACTIVE_HEALTHY` 仅作旧快照。worktree 没有 `prototype/.env.local`。
- 当前 candidate `.env.example` 使用 server-only `SUPABASE_URL`、`SUPABASE_PUBLISHABLE_KEY`；`config.ts` 只允许 local `http://127.0.0.1:55321/`。因此即便 Vercel 设置 hosted URL，当前候选也会 config fail/503；这是 local-only Gate 设计，不在本批绕过。该 hosted/Preview 结论是源码与配置推断/访问阻塞，不是本次 Supabase endpoint 响应。
- Remaining：独立 hosted-ready 配置设计、Git integration/link、Preview runtime 验证、环境变量 name/target 只读核对、Node 设置对齐、正式 push/PR/CI。Blocked：hosted Supabase target 不在当前 connector；Preview runtime 受保护且当前工具无法完成 cookie handshake；hosted/Preview/Production Gate 未授权。Next：由用户决定是否仅 push 候选分支；另行决定是否打开“Git link + isolated Preview + hosted Supabase read-only health” Gate，不预写批准。

## 13. 2026-09-01｜UI-only Preview release preflight（历史 preflight；execution result 见第14节）

- 绑定：code candidate=`0e5084b62c76275a781ec08edea287a06d442209`；base remote main=`de6a3203e20a1a4cea1106baef7bee1b4173d38f`；本地分支为 `codex/rebuy-v1-ui-preview-release`，从 exact candidate 创建。Owner 本次授权原话为 `将已完成可推送并部署的进行推送部署`；本条只记录授权边界，不预写 push、PR、Actions、merge 或 deployment 结果。
- 本地 preflight 在 clean release worktree 完成，使用 Node `22.12.0`、Corepack 驱动 pnpm `10.33.3`；`install --frozen-lockfile`、`typecheck`、`test:auth` `37/37`、`lint`、`build`、`git diff --check` 均 PASS。build 产生的 tracked `prototype/next-env.d.ts` generated import 漂移已恢复，最终 worktree clean。
- sensitive scan=`SCAN GO`：私钥/认证 header filename-only scan 无文件命中；basic-auth URL 仅为 `prototype/tests/auth/contract.test.ts:1215` 测试假阳性；provider token/JWT 复用既有 0 结果，未重复扫描。未记录匹配值。
- 发布边界：GitHub 仅非强制 release branch/PR；Vercel 仅受保护、无 `SUPABASE_*` 的 UI-only Preview。Production、alias、promote、hosted Supabase/Auth、Google、Apple、P2-L migration 继续 `NO-GO / CLOSED`。本批不 push、不开 PR、不 deploy。
- 证据见 [2026-09-01 UI-only Preview release preflight](./evidence/releases/2026-09-01-ui-preview-release/README.md)。本批不修改 `prototype/`、`supabase/` 或其他文件，不运行 build/tests，不记录邮箱、token、team/project/deployment ID 或 secret。

## 14. 2026-09-01｜UI-only Preview execution result（历史执行记录；当前补充收口见第15节）

- code candidate=`0e5084b62c76275a781ec08edea287a06d442209`；release/docs head=`bf10563663b91b3c0270aaf7acc68d6f3d63c526`；remote main=`de6a3203e20a1a4cea1106baef7bee1b4173d38f`。`codex/rebuy-v1-ui-preview-release` 已非强制推送成功；PR [#17](https://github.com/kyox215/REBUY_SHARE/pull/17) 已创建；Actions run `33461861676` success；未 merge、未 auto-merge。
- 唯一预期 Preview artifact=`dpl_6RCPeszdr4BBtp52oHM6i8iBf9XK`，project=`rebuy-share`，source=`CLI`，`READY`、`target=null`/Preview、`aliases=[]`。Next `16.3.2`；build log 两次明确记录 `engines.node=22.x` 覆盖 project setting `24.x`，实际 Node `22.x`；pnpm `10.33.3`，build success。官方参考：[Vercel Node.js versions](https://vercel.com/docs/functions/runtimes/node-js/node-js-versions)。Preview 无 `SUPABASE_*`；Production、alias、promote 未执行，既有 Production 不变。
- build route inventory 已记录 `/`、`/account`、`/account-mindmap`、`/account/login`、`/account/provider/[provider]`、`/api/auth/email-otp`、`/api/auth/session`、`/api/health/app`、`/api/health/supabase`、`/auth/callback`。Preview 受 Vercel Authentication 保护，connector health 得到 `302` SSO；GET/HEAD runtime matrix 未完成，未执行 POST、OTP、callback query、form 或 cookie 检查，不把 inventory 写成 runtime pass。
- 空项目清理时间序列：从未链接 source worktree 运行 `vercel curl` 曾误创建 project=`rebuy-release-0e5084b`；删除前 `latestDeployment=null`、`domains=[]`、deployment count=`0`。Owner 在知情后明确回复 `批准`；删除前 `project inspect` 精确命中该 name、ID=`prj_JvyS0Zb8woXqdBqi2pSejTRsuoVj` 且 team 匹配。首次 non-interactive rm 停在确认提示且未确认；随后同一精确命令以交互 `y` 确认，CLI 返回 `Success! Project rebuy-release-0e5084b removed`；删除后 inspect 返回 `There is no project for "rebuy-release-0e5084b"`。正式 `rebuy-share` 仍精确存在，ID=`prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL`、Root=`prototype`；目标 Preview `dpl_6RCPeszdr4BBtp52oHM6i8iBf9XK` 仍为 `Ready`、target=`preview`、URL 未变；本地 `.vercel`/`.gitignore` 副作用已清理。Supabase/hosted Auth/env 无写入；Google/Apple 仍 page-only placeholder；P2-L migration、merge、Production 继续 `NO-GO`。
- 本批不重跑 install/typecheck/`test:auth` `37/37`/lint/build，复用相同源码、lockfile、配置和工具链证据；未做 hash，因普通源码/文档与非确定性部署证据不需要 hash。当前结论：GitHub source branch `GO`；受保护 UI-only Preview artifact `READY`，runtime matrix 未完成；PR merge 与 Production `NO-GO`。

## 15. 2026-09-01｜UI-only Preview runtime matrix 与独立审查收口（当前）

- release worktree exact HEAD=`fba8ff30e78b5bb66e87a1e3e4e939bdf364cd60`；9 条 route GET 均针对同一受保护 Preview deployment。
- 新 exact-head archive 的 link 断言通过：project=`rebuy-share`，`projectId=prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL`，`orgId=team_AOJDnrjov0QDLqpvMyhwA1yc`。临时 archive、workspace 与 link state 已清理，source clean。

| Route | HTTP | Content-Type | Body evidence | Location | Cache-Control |
|---|---:|---|---|---|---|
| `/` | 200 | `text/html; charset=utf-8` | non-empty, 30622 bytes | none | not recorded |
| `/account` | 200 | `text/html; charset=utf-8` | non-empty, 16878 bytes | none | not recorded |
| `/account-mindmap` | 200 | `text/html; charset=utf-8` | non-empty, 46516 bytes | none | not recorded |
| `/account/login` | 200 | `text/html; charset=utf-8` | non-empty, 10545 bytes | none | not recorded |
| `/account/provider/google` | 200 | `text/html; charset=utf-8` | non-empty, 15170 bytes | none | not recorded |
| `/account/provider/apple` | 200 | `text/html; charset=utf-8` | non-empty, 15162 bytes | none | not recorded |
| `/api/health/app` | 200 | `application/json` | `{"status":"healthy"}` | none | not recorded |
| `/api/health/supabase` | 503 | `application/json` | `{"configured":false,"reachable":false,"status":503}` | none | `no-store` |
| `/api/auth/session` | 500 | `application/json` | `{"status":"error","code":"session_error"}` | none | `no-store` |

- 9 条均为只读 GET；未执行 POST、callback query、form、cookie、share、deploy、alias、env 或 Production 操作。session 500 是 production blocker evidence，不判为通过。
- 同一 Preview 的 `vercel inspect` 确认 deployment ID=`dpl_6RCPeszdr4BBtp52oHM6i8iBf9XK`、status=`READY`、target=`preview`。
- PR exact head=`fba8ff30e78b5bb66e87a1e3e4e939bdf364cd60` 为 `MERGEABLE`；required check `prototype-quality` run=`33484635052` 为 `SUCCESS`。source merge to main 为 static `GO`，受保护 UI-only Preview 为 `GO`，直接 Production 仍 `NO-GO`。

### Independent Sol review

- 专用 Sol role 不可用，使用 default Sol / max fallback；结论 P0=0、P1=3、P2=2。
- P1：生产页面可提交但 local-only OTP/session 必败；hosted callback 路径可能指向 localhost；缺少明确 hosted ui-only mode，且 `secure=false` local cookie/app health 语义不清。
- 最小修复：显式 server-only local-auth/ui-only mode；ui-only 登录禁用 OTP；OTP/session/callback 返回 `no-store` 503 `auth_unavailable` 且无 localhost Location/Set-Cookie；`secure=false` 仅限 local reachable；health 报告 `mode=ui-only`；补充 production-like Host contract tests 与 `test:auth`/typecheck/lint/build/runtime matrix。
- source merge 可以继续但不能自动 Production；Production/alias/promote 继续 `NO-GO`。

- 本批为 docs-only release evidence closeout；不重跑测试，复用 GitHub exact-head CI；不做 hash，未修改 `prototype/` 或 `supabase/`。

## 16. 2026-09-01｜UI-only Production hardening candidate closeout（当前）

- 绑定：base/main=`68bebaebebec66cedd8dcda9ab5ff5576ec8d6c9`；branch=`codex/ui-only-production-hardening`；worktree=`.worktrees/rebuy-ui-only-production-hardening`。证据见[UI-only Production hardening candidate](./evidence/releases/2026-09-01-ui-only-production-hardening/README.md)。
- runtime mode 显式区分 `ui-only`/`local-auth`：仅 canonical local origin=`http://127.0.0.1:3000`、Host=`127.0.0.1:3000` 且现有 local Supabase config 有效时为 `local-auth`；production-like Host 即使 config 合法仍为 `ui-only`。`resolveAuthRuntimeMode` 只捕获 `SupabaseConfigError`，其他异常继续抛出。
- `ui-only` 登录页不渲染 OTP form、不发 fetch；Google/Apple 保持 page-only 内链。email/session/callback 在 adapter、cookie、exchange 与 body 读取前返回 503 `auth_unavailable`、`no-store`，无 Set-Cookie/Location/localhost；app health 200 报告 mode；canonical local-auth 行为保留。
- Node=`22.12.0`、pnpm=`10.33.3`；`test:auth`=`43/43`、typecheck、lint、build、`git diff --check` 均 PASS。desktop=`1440x1000`、mobile=`390x844` login smoke 均非空、无 overlay、无 OTP form/request、provider 内链；server/browser/临时截图已清理。
- 首轮 Sol review 为 P0=0/P1=2/P2=1，本批完成定向修复；follow-up exact review 为 P0/P1/P2=`0/0/0`。专用 roles 不可用，Luna/Sol 均使用 default fallback max。
- candidate-level Source、受保护 Preview candidate、Production candidate 均 `GO`；尚未 commit、push、创建 Preview 或执行 Production。无 hosted Supabase/Google/Apple/env/secret/DB/Production 写入；普通源码不做 hash。

## 17. 2026-09-01｜Protected Preview runtime execution closeout（当前）

- exact Preview deployment=`dpl_HHPp2g6hGPDgD6HnYn2YcXtfDkYt`，project=`rebuy-share`，`READY`/`preview`/`aliases=[]`；整体 deploy_count=`1`，本次 continuation 不创建 deployment。Preview URL 不写入仓库；Preview env names 为空，无 `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY`。
- Vercel build 有限日志：CLI=`59.3.0`、pnpm=`10.33.3`、Next=`16.3.2`、build success；route inventory 已包含首页、账号页、provider page-only 页、三 auth route、两 health route 与 callback。当前 log 未单独打印 Node 版本；源码 engines=`22.x` 与前一 Preview resolved Node=`22.x` 仅保留为背景证据。
- runtime total=`9`：root 200；login 200 且有界面预览/登录未开放文案、无 form/email/OTP；Google/Apple 200 且无 Location；app health 200 healthy + `mode=ui-only`；Supabase health 503 configured=false；session 503；callback 无 query 503；空体 email OTP POST 503。三条 auth 路径均 `no-store`、无 Set-Cookie/Location/localhost，POST 未带 email/body 且 no-send。
- 首包第二 route 的解析命令在请求前失败并停止，未重试；continuation 未重复 root，完成余 8 条。最终 inspect 仍 READY/preview/aliases=[]；临时 archive、`.vercel` 与响应文件已清理，source clean。
- 结论为 exact Protected Preview runtime `GO`；Production execution 仍未发生。下一步为 PR exact CI 后 merge main，再单独进行 Production Gate。未执行 Production/alias/promote/share/env/provider/DB 写入。

## 18. 2026-09-01｜UI-only Production execution closeout（当前）

- PR #18 exact merge=`3c6ebf20b56f7ab37956a4ad9c543389a5636e65`，Actions run=`33497321436` `SUCCESS`。Production preflight 使用该 exact main 的 `git archive` 临时根并链接既有 `rebuy-share`：`projectId=prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL`、`orgId=team_AOJDnrjov0QDLqpvMyhwA1yc`；Production env names 为空，无 `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY`。
- previous Production=`dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH`，`READY`/`production`/aliases=`2`；rollback syntax=`vercel rollback url|deploymentId -y`，未触发。唯一 `deploy_count=1`；new Production=`dpl_F8ontC7D4cMip2jtcmDoRDY1XxJh`，`READY`/`production`。最终 inspect 确认 aliases=`2`，其中公共主域名为 `https://rebuy-share.vercel.app`，另 1 个为团队默认 alias；唯一 deployment URL 不写入仓库。
- Vercel CLI=`59.3.0`、pnpm=`10.33.3`、Next=`16.3.2`，build success，route inventory 覆盖页面、provider page-only、auth、health 与 callback。runtime total=`9` 全部 PASS：root/login/Google/Apple 200；login 为 ui-only、无 form/email/OTP；app health 200 `healthy`/`ui-only`；Supabase health 503 unconfigured；session、无 query callback、空体 email OTP POST 均 503 `auth_unavailable`、no-store、无 Set-Cookie/Location/localhost，POST no-send。
- 公共主域名 root 200 `text/html`，app-health 200 no-store JSON ui-only。未 rollback、未重试、未写 hosted Supabase/provider/env/DB/secret；临时资源清理、source clean。该 Production 仅证明 UI-only 已发布，不等于 P2-L/P3-P8、真实 Auth、支付或运营完成。本 docs-only 批次不重跑测试/build/network，复用 main CI/runtime 证据，不做 hash。
