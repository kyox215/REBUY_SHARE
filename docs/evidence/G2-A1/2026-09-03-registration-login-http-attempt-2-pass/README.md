# G2-A1 注册/登录同源 HTTP runtime attempt #2 PASS

## 结论

- 日期：2026-09-03，Europe/Rome。
- 状态：**LOCAL BACKEND RUNTIME PASS / BROWSER UI PENDING**。
- 在与 attempt #1 完全相同的候选 hashes 上，仅为 exact harness 父进程授予访问本机 loopback 所需的受控执行权限；harness 只运行一次并到达终态 `E2A_RUNTIME_PASS`。该对比确认 attempt #1 的 `anonymous_session` STOP 是运行权限边界，不是 Auth 业务失败。
- 范围仅为 local Supabase GoTrue/Mailpit、`@rebuy.test` 合成身份和 same-origin Next routes；不代表 hosted、Production、真实邮件、OAuth、商家权限或完整 V1 上线。

## Entry 与完整性

- Worktree/branch/base HEAD：`.worktrees/rebuy-v1-local-complete-exec` / `codex/rebuy-v1-local-complete` / `0e5084b62c76275a781ec08edea287a06d442209`。
- Node=`22.12.0`；pnpm=`10.33.3`；Next=`16.3.2`；local project id=`rebuy-g2-a1-e2a-local-email-otp-exec`。
- actual 前 `3000`、`55320–55329` listeners 为空，目标 project containers 为空；`git diff --check` 通过。
- actual 前后 hashes 一致：dev helper=`e082c0589be0b29a26671ea0c6077e5ad7ebfdce`；local Auth harness=`9a5466b14fa5b2dc6fbf7402dcaef45ada300efb`。

## Runtime assertions

一次脱敏运行依次通过：

1. anonymous session=`401`；错误项目 cookie 仍为 anonymous。
2. 未注册邮箱使用 login intent 被有限 `502/request_failed` 拒绝，Mailpit 无邮件。
3. 同一邮箱使用 signup intent 成功请求 OTP；Mailpit 捕获邮件。
4. 错误 OTP=`422/verify_failed`；正确 OTP=`200/verified` 并建立 Rebuy 专属 cookie；session=`200/authenticated`。
5. 已使用 OTP replay=`422/verify_failed`。
6. same-origin logout=`200/signed_out`；清理后的 session=`401/anonymous`。
7. 同一既有账号使用 login intent 再次获取 OTP、验证并得到 authenticated session。
8. 独立 signup/resend 语义中，新 OTP 与旧 OTP 不同，旧 OTP 被拒，重发 OTP 可验证。
9. `.invalid` 邮箱在应用门禁被 `400/invalid_request` 拒绝且 Mailpit 无邮件。

Next 有限路由日志与上面状态序列一致，无 framework error overlay 或服务端异常日志；所有敏感值仅在进程内存中使用。

## Cleanup 与隐私

- Next dev session 已停止。
- exact `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` exit `0`；目标 containers、volumes、network 为空，`3000` 与 `55320–55329` listeners 为零。
- 临时 start/stop 输出已删除；`prototype/.env.local` 不存在且未跟踪。
- 未保存 key、OTP、合成邮箱、token、JWT、cookie、DB password、provider response 或真实 PII。

## 完整离线质量门

- 指定 Node `22.12.0`：Auth contract `40/40` PASS、typecheck PASS、全量 ESLint PASS、Next `16.3.2` production build PASS、`git diff --check` PASS。
- production build 包含 `/account`、`/account/login`、`/api/auth/email-otp`、`/api/auth/session` 与 `/api/auth/logout`；build 生成的 `next-env.d.ts` 模式漂移已恢复，没有混入候选差异。

## Remaining

- 注册/登录后端 local runtime 已闭合；active Auth 浏览器 UI（登录/注册切换、OTP 输入、受保护 `/account` 与点击退出）仍因可用浏览器实例为零待补验。
- P2-L 继续为 `RUNTIME PASS / REVIEW PENDING`；独立审查未完成前不能打开 P3。P3–P7、hosted/Production、main push/deploy 继续关闭。
