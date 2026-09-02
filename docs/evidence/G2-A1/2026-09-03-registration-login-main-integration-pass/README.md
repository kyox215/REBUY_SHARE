# G2-A1 注册/登录 main integration PASS

## 结论

- 日期：2026-09-03，Europe/Rome。
- exact merge commit=`6896d8011e49ca03f083d3098a55e1ee225198ba`；parents=`87476067822ba8891065cc4283a64ff43e2e47e4` + `3c6ebf20b56f7ab37956a4ad9c543389a5636e65`。
- 状态：**LOCAL AUTH INTEGRATION PASS / BROWSER UI AND P2-L INDEPENDENT REVIEW PENDING**。
- 最新 `origin/main` 的 UI-only/production hardening 已与注册/登录、受保护账号页、same-origin logout 和 P2-L 候选合并；功能分支已不落后 `origin/main`，未 push、未建 PR、未部署。

## 冲突与安全决策

- 登录页同时保留 `ui-only` 与 `local-auth`：production-like Host 或无有效 local config 时不渲染邮箱/OTP 表单；local-auth 才显示登录/注册意图并提交带 `intent` 的请求。
- local-auth 验证成功只跳转经 `normalizeSafeNext` 收敛的站内路径；ui-only 不建立 session。
- 新 logout route 已纳入 runtime-mode composition：ui-only 在 Auth client/cookie 前返回 `503/auth_unavailable`；local-auth 才执行 same-origin、空 body、`scope=local` signout。
- `/account` 在 ui-only 保留不读取 Auth 的 200 预览；local-auth 才读取 verified claims，匿名跳转登录，成功时显示账号中心与退出入口。
- 状态台账同时保留 P2-L 第 42–71 节与 main 的 2026-09-01 UI-only Preview 历史时间线；后者以第 72–77 节追加，不静默覆盖。

## 完整离线质量门

- Node `22.12.0` / pnpm `10.33.3`。
- Auth contract=`46/46` PASS；新增覆盖 ui-only logout no-adapter/no-cookie、local-auth logout、账号页双模式与登录页双模式组合。
- typecheck PASS；全量 ESLint PASS；`P2L_PREFLIGHT_STRUCTURE_PASS`；`P2L_MIGRATION_STRUCTURE_PASS`；Next `16.3.2` production build PASS；`git diff --check` PASS。
- build route inventory 包含 `/account`、`/account/login`、email OTP/session/logout/health/callback；build 生成的 `next-env.d.ts` 漂移已恢复，4 个重复 ignored type artifacts 已精确删除。

## 合并后 local runtime

- exact merge commit 上的脱敏 harness 仅运行一次并到达 `E2A_RUNTIME_PASS`。
- anonymous/wrong-cookie、未注册 login intent no-mail 拒绝、signup OTP、wrong/correct OTP、authenticated session、replay rejection、same-origin logout、anonymous-after-logout、既有账号 login intent 再登录、resend 旧码拒绝/新码验证和 `.invalid` no-send 全部通过。
- 候选 hashes：dev helper=`e082c0589be0b29a26671ea0c6077e5ad7ebfdce`；harness=`9a5466b14fa5b2dc6fbf7402dcaef45ada300efb`；email route=`b6b20c64837403b4a2847964e4b7c821064e298c`；logout route=`5df2ce73a268dd8b9fa795d881ba87a50d6202b4`；account page=`6a1da8f8407276c8f76d3419dd13a27d2f4a6443`；AccountClient=`8fef6c1269e90ef5c550fe707c83bf3bc5f0166b`；login page=`e25466f3339705212fc0dc6b4707b581959a558e`；LoginPrototype=`497bc32ba18cd57ba10f1a3bac3611b198d57af2`。

## Cleanup 与 Remaining

- Next 已停止；exact Supabase stop/no-backup exit `0`；目标 containers、volumes、network、`3000` 与 `55320–55329` listeners 为空；临时输出已删除，`.env.local` 不存在。
- 未保存 key、合成邮箱、OTP、token/JWT/cookie、DB password、provider response 或真实 PII。
- 浏览器 UI Gate 仍因可用浏览器实例为零待补。P2-L 仍为 `RUNTIME PASS / REVIEW PENDING`；独立安全/数据库审查未完成前不能打开 P3。P3–P7、hosted/Production、main push/deploy 继续关闭。
