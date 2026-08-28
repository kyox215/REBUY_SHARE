# G2-A1-B2 本地安全基础实现

状态：**G2-A1 执行中；B2 本地安全基础已合并 main/远端闭环通过**（仅关闭本批本地安全基础的远端交付闭环，不等于完整 B2/Auth/G2-A1 整体通过）
记录日期：2026-08-28（Europe/Rome）
证据级别：本地源码、契约测试、依赖/构建检查、隔离本地首页浏览器复核；不代表 Auth 运行时通过
执行风险：关键；执行代理 `luna_worker / max`，单一写入代理；Owner 保留最终责任、停止权和后续 Gate 决定

## 1. 范围与结论

本批在隔离的本地 Next.js 原型中实现最小 callback 安全基础，仅覆盖同源相对 `next` 规范化、受控 callback decision、服务端 callback route 的错误/成功重定向边界，以及登录页对有限错误码的通用提示。本地实现阶段结论是 **B2 本地安全基础通过/可进入远端 PR 候选**；该阶段结论随后由第 7 节的远端闭环记录承接，不等于 B2/Auth/G2-A1 整体或 Auth 运行时技术通过。

当前状态统一为：G2-A1 执行中；B1 最小连接与配置/能力只读预检已完成；B2 本地安全基础已合并 main/远端闭环通过。PR #12 的 merge commit、main exact head 与 Actions 结果见第 7 节。该远端闭环仅关闭本批本地安全基础的交付与 CI 记录，不等于完整 B2/Auth/G2-A1 整体或 Auth 运行时技术通过。下一步仅可进入 B2 外部入口 Gate 设计/资源检查；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续 CLOSED，不预写外部 Auth 成功，不自动进入 B3、P2 或 Production。

## 2. 复用优先结论

- **复用**现有 `prototype/lib/supabase/config.ts`、`client.ts`、`server.ts`、既有登录演示和 `/api/health/supabase`；没有新建第二套 client、config、env 或 health route。
- **定向扩展**登录 page/演示组件，仅传入受控、有限的 callback 错误提示；Apple、Google 和邮箱入口仍是未启用的本地演示，不发送邮件、不调用 Auth。
- **新建最小纯函数与契约层**：`lib/auth/redirect.ts`、`lib/auth/callback.ts`、`lib/auth/callback-route.ts`、仅绑定 SSR client 的 `app/auth/callback/route.ts`、Node 内置 `node:test` 契约测试及其临时 TypeScript runner；没有引入第三方测试依赖。
- 现有 SSR client 仅在 callback route 的有效 code 路径按请求创建并调用 `exchangeCodeForSession`；本批未接入 proxy/session refresh、identity linking、invite、MFA、DB、Storage 或业务权限。

## 3. 实现边界

### 3.1 安全 redirect 与 callback decision

- `normalizeSafeNext` 只接受同源相对路径，默认 `/`；设置总长度上限并只允许有限次稳定解码，拒绝 absolute、protocol-relative、反斜杠、控制字符、dot-segment、编码/深层编码绕过、非法百分号编码和其他 origin。
- callback decision 先处理 provider error，再处理缺失/空 code；这两类均不调用 exchange。
- callback code 拒绝空值、首尾/内部空白、控制/格式字符及超过 `4096` 字符的输入；无效 code 在 exchange 前映射为有限 `invalid_code`，有效 code 最多调用注入的 exchange 一次；exchange 抛错、返回有限错误对象、`null` 或 `undefined` 均归一为有限错误码。
- route 通过独立可注入 handler 只产生同源 `303` redirect，并设置 `Cache-Control: no-store` 与 `Referrer-Policy: no-referrer`；失败只带有限 `auth_error`，不会把 callback 原始参数或 provider 错误写回失败 URL；route 本身仅绑定既有 Supabase SSR client。
- 登录页只接受 callback 模块导出的有限错误码与映射；未知值不显示状态，避免页面另维护一套枚举。

### 3.2 明确非目标

本批不实现 email/OTP verify、Magic Link 或任何 email 发送，OAuth initiation/provider enable，密码登录，session refresh/proxy，cookie/session/user 创建验证，identity linking，invite，MFA，数据库 schema/RLS，Storage，SMTP，真实账号/PII，Preview/Production 部署或 Supabase 控制台写入。

## 4. 本地验证

工具链固定为 Node `22.12.0`、Corepack pnpm `10.33.3`；依赖使用现有 lockfile，未增加测试依赖或修改 lockfile。执行结果：

| 验证 | 结果 | 说明 |
|---|---|---|
| `corepack pnpm@10.33.3 install --frozen-lockfile` | 通过 | 依赖与 lockfile 一致 |
| `corepack pnpm@10.33.3 test:auth` | 通过 | Node 内置 `node:test`，12 个契约测试通过；覆盖 safe-next 长度/稳定解码/深层编码/dot-segment/Unicode 空白与非法百分号、callback code 输入边界、route 303/headers/origin 二次校验及 exchange 0/1 次 |
| `corepack pnpm@10.33.3 typecheck` | 通过 | 包含 Next 16 route/page 类型检查 |
| `corepack pnpm@10.33.3 lint` | 通过 | 无新增 lint 错误 |
| `corepack pnpm@10.33.3 build` | 通过 | Next 16.3.2 编译 callback route 与登录页；build 生成物未作为证据提交 |
| 独立定向 review | REVIEW GO | 针对 candidate exact-head `761de2b3a8ce22247501cddbad2da6e2cfc3ae59`，P0/P1/P2=0；复审 shell Node `20.20.2` 运行 `test:auth` 12/12 与 typecheck，并出现 engine warning；复用该 exact-head 的 Node `22.12.0` build/lint/browser smoke 证据 |
| `.github/workflows/prototype-quality.yml` | 已更新 | `test:auth` 仅在 typecheck 后、lint 前运行一次；没有重复 post-build 测试 |
| 浏览器/开发服务器 | 首页复核通过（callback 未运行） | 隔离端口 `3102` 按 agent-browser-verify 完成 open/networkidle、截图、非空、无错误覆盖层、console errors `[]` 和交互快照；浏览器与 server 已关闭；未执行真实 callback/Auth exchange |

本次隔离首页浏览器复核已完成：agent-browser `open` 与 `networkidle` 成功，截图已保存至 `/private/tmp`，页面有内容、无 Next 错误覆盖层、console errors 为空，交互快照包含搜索、分类、推荐商品和底部导航；浏览器与 server 已关闭。由于本批没有有效 Auth 凭据或授权 code，未执行 callback 缺 code/假 code 的浏览器 HTTP 路径，也没有创建用户、session 或真实业务数据；不得把首页/契约测试写成 Auth 运行时通过。未访问 Supabase dashboard，也未执行外部资源管理动作。

## 4.1 独立复审发现与本批修正

首轮独立安全复审发现 1 项 P1 与 2 项 P2，结论为 **REVIEW NO-GO**：callback code 缺少明确的长度/边界/控制字符门禁；safe-next 缺少总长度与稳定解码终止条件，深层编码、dot-segment 与 Unicode 空白覆盖不足；route 的实际响应行为没有独立的可注入 handler 契约覆盖。

本批已在当前 checkpoint 修正：callback code 上限固定为 `4096`，空值/全空白仍为 `missing_code`，首尾或内部空白、控制/格式字符和超长值为 `invalid_code`，均在 exchange 前拒绝；safe-next 总长度固定为 `2048`，最多执行 `3` 次解码且必须稳定，拒绝深层非稳定编码、dot-segment、Unicode 空白/格式字符和非法百分号；生产 route 仅绑定既有 SSR client，决策逻辑由可注入 handler 承载，契约测试覆盖 `303`、同源 Location、`no-store`、`no-referrer`、最终 origin 二次校验以及 exchange `0/1` 次。

首轮独立安全复审结论为 **REVIEW NO-GO**；本批 checkpoint 已修正上述 finding。随后独立定向复审针对 candidate exact-head `761de2b3a8ce22247501cddbad2da6e2cfc3ae59` 给出 **REVIEW GO**，P0/P1/P2=0。复审 shell Node `20.20.2` 运行 `test:auth` 12/12 与 typecheck，并出现 engine warning；候选 exact-head 的 Node `22.12.0` build/lint/browser smoke 证据予以复用。该 GO 仅关闭 B2 本地安全基础 review，不等于 B2/Auth/G2-A1 整体通过；不预写 PR、Actions 或 merge，不打开任何真实 Auth 运行、OAuth、SMTP、DB/Storage、session/user、MFA、部署或 Production Gate。

## 5. 来源与安全控制

实现前已完整读取本 worktree 的 `prototype/AGENTS.md`、Next 16 本地 route handler、authentication、proxy、server actions、cookies、redirect 文档，以及 Supabase SSR/PKCE callback 官方资料。使用的官方资料：

- [Supabase SSR 创建 server client](https://supabase.com/docs/guides/auth/server-side/creating-a-client)
- [Supabase SSR advanced guide](https://supabase.com/docs/guides/auth/server-side/advanced-guide)
- [Supabase `exchangeCodeForSession` reference](https://supabase.com/docs/reference/javascript/auth-exchangecodeforsession)
- [Supabase social login callback guide](https://supabase.com/docs/guides/auth/social-login)

本批没有创建 `prototype/.env.local`，因此没有可复用的 env 权限结论；后续任何真实连接批次必须重新确认 `.gitignore`、untracked 和 mode `600`。不得读取或使用 `service_role`、secret key、数据库密码或其他管理凭据；公开 publishable 配置只允许在受控的 gitignored local env / action-time Preview env 中处理，不能进入仓库、证据、聊天、日志、截图或客户端 bundle。

## 6. Gate、复审与下一步

- 外部 OAuth client/redirect/secret、SMTP credential/secret、邮件投递、费用、持久连接、Auth provider enable、DB/Storage、真实用户/PII、部署和 Production Gate 继续 **CLOSED**。
- B2 本地安全基础已通过独立定向 review，并已完成 PR #12 → `main` 的远端 merge/Actions closeout；该闭环仅关闭本批本地基础交付记录，不自动打开下一项运行验证。不得以用户的 broad approval 绕过 secret、Auth、DB、SMTP 或 Production 门禁。
- 真实 Auth callback/session refresh/replay/rate-limit/OAuth/SMTP/DB/Storage/Production 仍 CLOSED；任何后续动作仍需其自身的 action-time Owner Gate 和专项证据。
- 当前仅完成隔离首页的 browser smoke；callback 缺 code/假 code 的浏览器 HTTP 路径仍未运行，后续如具备 action-time Gate 和受控运行条件，仍只能在隔离本地环境执行；成功 Auth、邮件投递、OAuth、session/user、DB/Storage 结果需另立专项证据和 Gate。
- 回退方式：撤销本批新增 route/pure modules/tests/workflow step 与登录页提示，保留历史证据，不触碰现有 B1 骨架、Supabase 资源或 Production。

当前阶段事实与路线入口：[G2-A1 准备与资源门禁](../../../stages/G2-A1-Auth-Spike准备与资源门禁.md)、[A1 执行合同](../../../10-A1-Auth-Spike执行合同.md)、[发布与 Supabase 连接记录](../../../11-发布与Supabase连接记录.md)、[项目状态与阶段台账](../../../15-项目状态与阶段台账.md)。本 README 是本批脱敏证据，不替代 15 的唯一当前状态源。

## 7. 2026-08-28｜B2 本地安全基础远端闭环（当前）

- PR #12 已以 merge commit 合并到远端 `main`：head=`55b7497953bc22e002e4c75a4b039c5b08fd98e7`，merge=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`，parents=`689d9679293f255c44feb314428a2678b9fe4d06` + `55b7497953bc22e002e4c75a4b039c5b08fd98e7`；来源分支 `codex/g2-a1-b2-local-foundation` 保留。
- 远端 `main` exact head=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`；main Actions run=`33209420614` / job=`98978680399` 为 success，`test:auth` 12/12 且仅运行一次。该 exact merge commit 的 GitHub deployments=`0`。
- Vercel 仍为 `3` 个既有 deployments；Production 仍为 `READY`，aliases=`2`；本次没有新增 Preview/Production deployment。
- 当前结论为 **B2 本地安全基础已合并 main/远端闭环通过**。该结论仅关闭本地安全基础的远端 source/CI 交付闭环；完整 B2、real Auth/OAuth/SMTP/session/DB/Storage/Production 与外部 action-time Owner Gate 继续 **CLOSED**。下一步仅可进行 B2 外部入口 Gate 设计/资源检查，不预写 external Auth success。
- 本次仅提交文档 closeout；未运行本地 build、tests 或 browser，未执行 Supabase/Auth/DB/Storage/SMTP、secret、部署或 Production 操作。
