# UI-only Production hardening candidate

日期：2026-09-01（Europe/Rome）

状态：候选实现与验证完成；尚未 commit、push、创建 Preview 或执行 Production 操作。

## 绑定

- base/main：`68bebaebebec66cedd8dcda9ab5ff5576ec8d6c9`
- branch：`codex/ui-only-production-hardening`
- worktree：`.worktrees/rebuy-ui-only-production-hardening`
- 执行代理：单一 Luna/max 写入者；专用 role 不可用，使用 default Luna / max fallback。

## Runtime contract

- 显式支持 `ui-only` 与 `local-auth` 两种 server-only runtime mode。
- 只有请求 URL origin 精确为 `http://127.0.0.1:3000`、Host 精确为 `127.0.0.1:3000`，且现有 local Supabase config 校验通过时才进入 `local-auth`；其他请求为 `ui-only`。production-like Host 即使带有合法 local config 也保持 `ui-only`。
- `resolveAuthRuntimeMode` 只将 `SupabaseConfigError` 归类为 `ui-only`；其他程序异常继续抛出。
- `/account/login` 在 `ui-only` 下不渲染 OTP form、不发 OTP fetch；页面明确显示账号入口/界面预览边界。Google/Apple 继续为内部 page-only link。
- `ui-only` 下 email OTP、session、callback 在 adapter、cookie、exchange 与 request body 读取前返回有限 JSON `503 auth_unavailable`，带 `no-store`，无 Set-Cookie、Location 或 localhost；app health 保持 `200` 并报告 `mode`。Supabase health 合同保持不变。
- canonical local request 下保留既有 local-auth delegation 与 42 项原有合同；tracked env 仍为 server-only `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY`，未增加凭证或 secret。

## Verification

- Node `22.12.0`、pnpm `10.33.3`。
- `pnpm test:auth`：`43/43` PASS。
- `pnpm typecheck`：PASS。
- `pnpm lint`：PASS。
- `pnpm build`：PASS。
- `git diff --check`：PASS。
- 首轮 Sol review：P0=0、P1=2、P2=1；本批完成定向修复。follow-up exact review：P0=0、P1=0、P2=0。

## Browser evidence

- 隔离本地 server 上完成 desktop `1440x1000` 与 mobile `390x844` login smoke；页面非空、无 error overlay、无 OTP form/control/request，Google/Apple provider link 均为内部 page-only path。
- 未填写、点击或提交表单；server、browser session 与临时截图均已清理。

## Candidate gate

- candidate-level 结论：Source `GO`、受保护 Preview candidate `GO`、Production candidate `GO`；均不是已 commit、已 push、已创建 Preview 或已执行 Production 的事实。
- 未执行 hosted Supabase、Google、Apple、env/secret、DB、Production、deploy、alias、share link 或其他外部写入。
- 普通源码不做 hash；本证据仅保存有限结果，不保存凭证、token、cookie 或完整运行输出。
