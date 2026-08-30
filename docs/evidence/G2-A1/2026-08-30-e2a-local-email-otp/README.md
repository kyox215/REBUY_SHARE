# G2-A1 E2a local email OTP evidence

## 结论与范围

- 日期：2026-08-30，Europe/Rome。
- 执行范围是 G2-A1 E2a local email OTP only：本地 Supabase Auth/GoTrue、合成邮箱 OTP request/verify/resend、Mailpit 捕获、同源服务端协调和 session cookie。
- 独立 Sol 审查结论为 E2a 条件 GO；E2b invite 当前 NO-GO。provider invite 不等于 Rebuy membership invite；本证据不代表 G2-A1 整体通过。
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
- 已知风险：active Supabase 下 OTP 输入态仍未用浏览器截图（真实 OTP 链路已有 harness 证据）；桌面/移动初始与错误态缺口已由主代理 In-app Browser 关闭，且未存档截图文件；本地条件 GO 不等于生产或 hosted 验收；OTP 限速、邮件投递和 cookie 行为仍需在后续授权 Gate 下复核。

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
