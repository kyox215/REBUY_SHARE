# G2-A1 注册/登录浏览器闭环 attempt #1

## 结论

- 日期：2026-09-03，Europe/Rome。
- 状态：**STOP at browser availability / business flow not run**。
- 本地 Supabase 与 Next.js 均成功启动，但 Codex In-app Browser 运行时返回 `No browser is available`，按 bootstrap troubleshooting 只读列举后的可用浏览器集合为空。未发生页面导航、邮箱提交、OTP 请求、账号创建、session 或 logout 调用，因此本记录既不是 Auth 业务失败，也不构成注册/登录浏览器 PASS。
- 按 one-shot 合同在首个失效边界停止；未改用无关浏览器后端，未在同一工作包重试，随后立即完成精确 cleanup。

## Entry 与候选完整性

- Worktree：`.worktrees/rebuy-v1-local-complete-exec`；branch=`codex/rebuy-v1-local-complete`；base HEAD=`0e5084b62c76275a781ec08edea287a06d442209`。
- Node=`22.12.0`；pnpm=`10.33.3`；Next=`16.3.2`；本地 Supabase project id=`rebuy-g2-a1-e2a-local-email-otp-exec`；端口仅为 `3000` 与 loopback `55320–55329`。
- actual 前 `3000`、`55320–55329` 无监听，目标 project containers 为空；helper/harness `node --check`、目标 ESLint 与 `git diff --check` 通过。
- 候选 hashes：dev helper=`e082c0589be0b29a26671ea0c6077e5ad7ebfdce`；local Auth harness=`9a5466b14fa5b2dc6fbf7402dcaef45ada300efb`；login UI=`518143baa9302ba4bff38f1bdf9275a35118b435`；email OTP route=`c992fa6ca541c46f83b7d29ff1fa81ef5fb99c49`；session route=`98d55ba862a6b0250f97cd32eba3e8f4f3c39e1b`；logout route=`a36dfa0ca850eb3dfa264aaeba2601baf12f41b6`；protected account page=`ec94902b305a19187b1aff68dc24e933a29fa9fd`。

## 已建立的静态证据

- 指定 Node 22 下 Auth contract `40/40` PASS、typecheck PASS。
- local Auth harness 已同步 login/signup `intent`：未注册登录拒绝、注册、错误 OTP、正确 OTP、authenticated session、OTP replay 拒绝、same-origin logout、anonymous session、既有账号再次登录，以及 resend/old OTP/invalid-domain 边界；本工作包只完成语法与 lint，不把未运行 harness 写成 runtime PASS。
- 新增 `dev:auth:local` 启动器：在内存中读取 exact local Supabase status，只接受固定 loopback URL 与 publishable/legacy anon public key，向 Next 子进程注入 public config；不打印或持久化 key。

## Cleanup

- Next dev session 已停止。
- `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` exit `0`；目标 containers、volumes、network 均为空，`3000` 与 `55320–55329` listeners 为零。
- start/stop 临时输出已删除；未保存 key、OTP、synthetic email、token、JWT、cookie、DB password、provider response 或真实 PII。

## 下一工作包

- 从空资源和相同候选 hashes 重新预检，仅运行一次脱敏同源 HTTP harness，先闭合注册/登录后端真实链路；浏览器可用性作为独立 UI Gate 保留，恢复后再完成 active OTP 输入态与受保护页面交互。
- P2-L 继续为 `RUNTIME PASS / REVIEW PENDING`；P3–P7、hosted/Production、main push/deploy 继续关闭。
