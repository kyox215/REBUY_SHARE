# G2-A1 注册/登录同源 HTTP runtime attempt #1

## 结论

- 日期：2026-09-03，Europe/Rome。
- 状态：**STOP at anonymous_session / no Auth mutation**。
- exact local Supabase 与 Next.js 均启动成功；脱敏 harness 仅运行一次，在第一项 anonymous session fetch 返回 `E2A_RUNTIME_FAILED:anonymous_session`，耗时约 `0.24s`。Next session 没有收到该请求的路由日志；执行工具的默认沙箱明确限制网络访问，因此当前根因候选为 harness 父进程缺少 loopback 网络权限。
- 失败发生在任何合成账号、邮件、OTP、cookie 或数据库 Auth 写入之前；不构成 session 业务断言失败，也不构成注册/登录 runtime PASS。

## Entry 与完整性

- Worktree/branch/base HEAD：`.worktrees/rebuy-v1-local-complete-exec` / `codex/rebuy-v1-local-complete` / `0e5084b62c76275a781ec08edea287a06d442209`。
- actual 前 `3000`、`55320–55329` listeners 为空，目标 project containers 为空。
- 候选 hashes 与 browser attempt #1 相同：dev helper=`e082c0589be0b29a26671ea0c6077e5ad7ebfdce`，local Auth harness=`9a5466b14fa5b2dc6fbf7402dcaef45ada300efb`。
- 指定 Node `22.12.0` 下 Auth contract `40/40`、typecheck、helper/harness syntax、目标 ESLint 与 `git diff --check` 已通过；本包未修改候选源码。

## Cleanup 与边界

- 首个失败后未重跑 harness；Next 已停止。
- exact `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` exit `0`；目标 containers、volumes、network 为空，`3000` 与 `55320–55329` listeners 为零；临时 start/stop 输出已删除。
- 未读取或保留 key、OTP、合成邮箱、token、JWT、cookie、DB password、provider response 或真实 PII。

## 下一工作包

- 从空资源和相同候选 hashes 重新预检；只给 exact harness 父进程 loopback 所需的受控执行权限并运行一次。该受控对比若越过 anonymous session，可确认本次失败为运行权限边界；若仍失败，则在新的首个业务边界停止并记录。
- 浏览器 UI Gate 仍因浏览器实例不可用待补；P2-L 保持 `RUNTIME PASS / REVIEW PENDING`，P3–P7、hosted/Production、main push/deploy 继续关闭。
