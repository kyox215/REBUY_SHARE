# G2-A1 E2a local email OTP evidence

## 结论与范围

- 日期：2026-08-30，Europe/Rome。
- 执行范围是 G2-A1 E2a local email OTP only：本地 Supabase Auth/GoTrue、合成邮箱 OTP request/verify/resend、Mailpit 捕获、同源服务端协调和 session cookie。
- 历史执行记录曾记为 E2a 条件 GO；对精确 head=`98a3f0d4739eb835fa068b4736347285b7d23193` 的独立安全审查结论为历史 **NO-GO**，并保留上一提交 `2083656f6a1eb888f0db06339bc2b30151f31c43` 的 **REVIEW GO/P2=5**。当前 exact head=`30131c0cfad69a6df7c0e0c61268029890c7dce1` 已获独立 Sol E2a **REVIEW GO，P0=0、P1=0、P2 open=0**，本地 slice 标为完成/通过；E2b invite 当前仍 NO-GO。provider invite 不等于 Rebuy membership invite；本证据不代表 G2-A1 整体通过。
- 成功路径只使用专用 `@rebuy.test` 合成域名；`.invalid` 只用于 no-send、负向和反枚举。具体邮箱原值、验证码、token、cookie、key 和 PII 不写入本记录。

## 隔离与配置

- Canonical root：`/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划`。
- Branch：`codex/rebuy-v1-local-complete`；worktree：`.worktrees/rebuy-v1-local-complete-exec`。
- 起点只读核对为 `origin/main=de6a3203e20a1a4cea1106baef7bee1b4173d38f`。
- 唯一 local project id：`rebuy-g2-a1-e2a-local-email-otp-exec`；端口范围：`55320–55329`；监听绑定为 loopback。
- 实际启动服务：db、Kong、REST、Auth/GoTrue、Mailpit、Studio、pg-meta。realtime、storage、vector、logflare、imgproxy、edge-runtime/functions、supavisor 未启动。
- `supabase/config.toml` 完全省略 `[auth.email.smtp]`；按当前 CLI local 语义使用默认 Inbucket/Mailpit catcher。仅保留最小 magic-link OTP 模板并渲染 `{{ .Token }}`；未配置 custom SMTP、hosted SMTP 或真实邮箱。

## 实现与合同

- `POST /api/auth/email-otp` 使用 Node.js runtime、同源 Origin 门禁、JSON Content-Type 门禁、请求体大小门禁和 JSON/字段校验，响应 `no-store`。
- Route Handler 复用现有 Supabase server client，服务端调用 `signInWithOtp`/`verifyOtp` 并写 cookie；客户端只接收有限状态，不显示 raw provider error。
- `GET /api/auth/session` 只返回 `authenticated` 或 `anonymous` 有限状态，不回传 user/session/token。
- 纯 Auth 合同覆盖 invalid input 不调用、valid request/resend 单次调用、verify wrong/replay、抛错映射、原始错误不泄露和 route 门禁。

## 正向与负向证据

一次性内存脚本在本地运行并只打印阶段结果，未输出敏感值，阶段均通过：

1. 合成 `@rebuy.test` 邮箱 request 成功。
2. Mailpit API 确认邮件捕获。
3. 错误 OTP 被拒绝。
4. 正确 OTP 验证成功，随后 session endpoint 返回 authenticated，响应 cookie 在内存中建立。
5. 同一 OTP 重放被拒绝。
6. resend 成功并再次捕获邮件。
7. `.invalid` 邮箱在服务端字段门禁阶段被拒绝且不调用 provider、不发信。

页面 HTTP smoke 返回 200，并包含本地测试认证元数据/状态标记；未在页面、日志或证据中显示邮箱原值、OTP、cookie 或 key。

## 独立验证

- 环境：Node `22.12.0`、Corepack pnpm `10.33.3`。
- `corepack pnpm install --frozen-lockfile`：通过；lockfile 未变化。pnpm 仅提示 `unrs-resolver` build script 被忽略，未启用 approve-builds。
- `corepack pnpm test:auth`：19/19 通过。
- `corepack pnpm typecheck`：通过。
- `corepack pnpm lint`：通过。
- `corepack pnpm build`：通过；包含 email OTP、session route 和 login 页面。
- 浏览器专用 `agent-browser` CLI 及现有 Playwright/Puppeteer runtime 不可用；未安装额外依赖，未伪造桌面/移动截图证据。桌面/移动 browser smoke 是已知缺口。
- 未做源码哈希：本批没有确定性制品传输或异常不一致调查需求；以 Git diff、测试、构建和 commit 为完整性证据。

## Cleanup

- `SUPABASE_TELEMETRY_DISABLED=1 SUPABASE_HOME=/private/tmp/rebuy-v1-supabase-home supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`：退出码 0；CLI 用户态目录随后删除。
- 本批唯一 Docker network 已移除；按精确 project 过滤核对，容器为空、volume 为空、network 为空。
- `55320–55329` listener 核对为 0。
- `prototype/.env.local` 已删除且 `git ls-files` 为空；独立 `prototype/node_modules` 保留为 worktree 内真实 Directory，不是旧 checkout symlink，且被 Git Ignore。
- Next dev server 保留在 `http://127.0.0.1:3000` 供主线程做无敏感值页面预览；Supabase/Auth stack 已清理，因此该 URL 仅是 UI 预览，不宣称仍有可用认证后端。

## 仍关闭的 Gate 与风险

- E2b provider/admin invite、`inviteUserByEmail`、service_role/secret/db password、Rebuy membership invite、Google、Apple、custom SMTP、hosted Supabase/Auth、真实邮件/账号/PII、业务 DB/schema/RLS、Storage、Realtime、MFA、linking、push/PR/merge、Vercel deployment、Staging/Production 均 CLOSED。
- 已知风险：精确 head=`98a3f0d4739eb835fa068b4736347285b7d23193` 的历史审查 NO-GO 与 `2083656f6a1eb888f0db06339bc2b30151f31c43` 的 REVIEW GO/P2=5 均保留；当前 exact head=`30131c0cfad69a6df7c0e0c61268029890c7dce1` 已 REVIEW GO，P0/P1=0、P2 open=0。active Supabase 下 OTP 输入态仍未用浏览器截图；桌面/移动初始与错误态缺口已由主代理 In-app Browser 关闭，且未存档截图文件；本批未主动触发真实 provider HTTP 429，refresh/revoke 未证明。这些不阻塞 E2a local slice，但不得外推为 hosted、Production 或更广能力。Next 预览按用户要求故意保留，不是 cleanup 遗漏。

## 官方语义依据

- [Supabase CLI config reference](https://supabase.com/docs/guides/local-development/cli/config)
- [Supabase local email templates](https://supabase.com/docs/guides/local-development/customizing-email-templates)
- [Supabase local testing and Mailpit](https://supabase.com/docs/guides/local-development/cli/testing-and-linting)
- [Supabase changelog](https://supabase.com/changelog)

## 主代理浏览器补充验收（纠正，2026-08-30）

- 主代理使用 Codex In-app Browser 对 `http://127.0.0.1:3000/account/login` 完成默认桌面与临时 `390x844` 移动 viewport 验收，最后已 reset 为默认 viewport；浏览器 tab 保留为 deliverable。
- 初始 DOM/截图确认 Apple/Google disabled、合成邮箱状态和无布局重叠；Supabase 已 cleanup 时提交 `@rebuy.test` 合成邮箱只显示有限发送失败；随后非法邮箱复验只显示单一 `@rebuy.test` 格式错误，旧服务错误已清除；placeholder 精确为 `name@rebuy.test`；移动错误态无重叠。
- 页面 title/URL 正确，console `warn/error=[]`。本补充关闭桌面/移动初始态与错误态 browser 缺口；不声称存档截图文件。历史 `agent-browser` CLI 不可用仍保留为工具事实，不覆盖本次 In-app Browser 证据。
- active Supabase 下 OTP 输入态仍未用浏览器截图；真实 OTP request→Mailpit→verify→session→replay/resend 链路仍以已记录的本地 harness 证据为准。

## 历史安全修复候选与复审状态（2026-08-30；当前见末节）

- 独立安全审查针对 `98a3f0d4739eb835fa068b4736347285b7d23193` 为 **NO-GO**；截至该精确 head，本次 worktree 中的实现与证据是待复审修复候选。当前状态见末节，不覆盖该历史结论。
- P0/P1 修复候选覆盖：严格 canonical local URL 与 public-key allowlist；Rebuy 专属 Auth cookie 及 strict Route Handler cookie writer；固定 `127.0.0.1:3000` request URL/Origin/Host 三重匹配；streaming 1024-byte body gate、无 Content-Length 超限取消、UTF-8/JSON 拒绝；有限 provider 错误/限速状态；合同测试与真实 local runtime harness。
- P2 候选覆盖：可清除 callback 状态、客户端错误与服务错误分离、local `max_frequency=1s` 对应 resend cooldown，以及匿名/错误项目 cookie/验证成功的 session 检查。刷新/撤销在本批未作稳定证明，保留为残余风险。
- 本批实际状态仍拆分 E2a 与 E2b：E2a 只限 local GoTrue/Mailpit、`@rebuy.test` 成功邮箱和 `.invalid` 负向；E2b invite 继续 NO-GO，provider invite 不等于 Rebuy membership invite。用户仅授权本地计划执行，不授权特权密钥或外部动作。

## 上一精确提交复审记录与预览保留纠正（2026-08-30）

- 追加记录上一精确提交 `2083656f6a1eb888f0db06339bc2b30151f31c43` 的独立审查结果：**REVIEW GO，P0=0、P1=0、P2=5**。该记录不覆盖历史精确 head=`98a3f0d4739eb835fa068b4736347285b7d23193` 的 **NO-GO**，不把当前 follow-up 或 E2a/G2-A1 整体预写成 GO。
- `http://127.0.0.1:3000` Next 预览是用户明确要求保留的无敏感值本地预览，不是 local Supabase/Mailpit cleanup 遗漏。预览只代表 UI 可查看，不能代表 Auth 后端仍在运行或生产能力已打开。
- 历史 `agent-browser` CLI 不可用、主代理 In-app Browser 补充验收和 active Supabase 下 OTP 输入态未存档截图的事实均保留；真实 request→Mailpit→verify→session→replay/resend 仍以脱敏 runtime harness 为证据。

## 当前验证补充（2026-08-30）

- Node `22.12.0`、Corepack pnpm `10.33.3`、worktree 独立依赖：`corepack pnpm test:auth` 为 `29/29`；`typecheck`、`lint`、含固定假 sentinel 的 `build` 均退出 0。sentinel 未进入 `.next/static`、tracked tree 或 env；无 lockfile 变更。
- 脱敏 runtime harness `test:auth:local` 阶段均通过：anonymous session、wrong project cookie、request、Mailpit capture、wrong OTP、verify、authenticated session、replay、resend、old OTP rejection、resend verify、`.invalid` no-send，最终 `E2A_RUNTIME_PASS`。所有 app/Mailpit fetch 使用 manual redirect 并校验固定 origin；重发 token 不同，旧 OTP 被拒且新 OTP 可验证；未把 fake replay 当真实 Supabase 证据。
- 当前收口只做必要的无敏感页面 HTTP/DOM smoke：登录页返回 200，`name@rebuy.test` placeholder 和本地测试认证状态文案存在；未填入邮箱或 OTP，未生成或保存新截图。此前主代理的桌面/移动 In-app Browser 证据与 active OTP 截图缺口事实继续保留。
- 浏览器与 Next 兼容性：Next 16 的 URL normalization 会把 loopback request URL 归一为 `localhost`；当前配置使用官方现有 `skipProxyUrlNormalize` 以保留原始 request URL，确保固定 loopback origin gate 在实际 runtime 与代码合同一致。该设置仅为本地同源边界兼容控制，不放宽 allowlist。

## 当前 follow-up 精确提交复审（2026-08-30）

- 独立 Sol 对 exact code head=`30131c0cfad69a6df7c0e0c61268029890c7dce1` 给出 E2a **REVIEW GO**，P0=0、P1=0、P2 open=0。历史 `98a3f0d4739eb835fa068b4736347285b7d23193` **NO-GO** 与 `2083656f6a1eb888f0db06339bc2b30151f31c43` **REVIEW GO/P2=5** 均保留，不静默覆盖。
- E2a local email OTP slice 标为**完成/通过**，仅限 local GoTrue/Mailpit、`@rebuy.test` synthetic-only、OTP request/verify/resend、session 和有限错误；不等于 G2-A1 整体、E2b/E3-E5、P2、hosted 或 Production 打开。E2b invite 仍 NO-GO，provider invite 不等于 Rebuy membership invite。
- 残余范围：未主动触发真实 provider HTTP 429、refresh/revoke 未证明、active Auth OTP UI 未保存截图。均不阻塞 E2a local slice，但不得外推。push/deploy/hosted/admin key/真实 PII/custom SMTP 继续冻结；Supabase local stack 已清理；`http://127.0.0.1:3000` Next preview 按用户要求故意保留，不是 cleanup 遗漏。
