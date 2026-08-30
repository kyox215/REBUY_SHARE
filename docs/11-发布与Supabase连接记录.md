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
