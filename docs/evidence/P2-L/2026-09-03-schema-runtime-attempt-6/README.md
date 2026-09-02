# P2-L schema runtime attempt #6

日期：2026-09-03（Europe/Rome）
结果：**STOP / FAIL at pgTAP fixture；migration、owner handoff、seed、AMR preflight 与 repeat reset 已通过**

## Entry and candidate

- Branch / base HEAD：`codex/rebuy-v1-local-complete` / `0e5084b62c76275a781ec08edea287a06d442209`
- Worktree / local project：`.worktrees/rebuy-v1-local-complete-exec` / `rebuy-g2-a1-e2a-local-email-otp-exec`
- CLI / Node / ports：`2.101.0` / `22.12.0` / `55320–55329`
- Owner approval：2026-09-03 回复“批准全部”，绑定已展示的原子 owner-transfer 例外；见 Gate 第 22 节。
- Actual hashes：roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`；migration=`af8ac6b1c113201c9679b34b5336c767f1de2c58`；seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`；schema pgTAP=`b9252cbf6c932ed1b9899e3048de660673f35587`；invitation pgTAP=`b53c224b282b0cc5270ad1de999f2bc67f72924b`；structure=`8f375a6465dde3bf0ce59b485a3e7e361668b206`。
- Entry：结构门与 `git diff --check` 通过；目标 containers、volumes、network 与 `55320–55329` listeners 均为空。

## Actual sequence

- `supabase start --yes`：PASS。globals、migration、原子 owner handoff、seed 和服务健康检查均完成；两个 private functions 的 owner transfer 不再触发 SQLSTATE `42501`。
- 合成邮箱 AMR preflight：PASS。OTP request/capture/verify、初始签名 AMR、非匿名身份、规范化邮箱、刷新前时间分离、refresh token/session、access token 变化及 refresh 后 AMR timestamp 不变均输出有限 PASS category。
- `supabase db reset --local`：PASS。数据库被重新创建并再次完成 globals、同一 migration、owner handoff 与 seed，证明不是首次启动偶然通过。
- `supabase test db --local ...`：FAIL，两个文件均在业务断言前停止：
  - schema test 在把 `search_path` 收敛为 `pg_catalog, public` 后无法解析已安装在 `extensions` schema 的 `ok(boolean,text)`；
  - invitation test 用不同 UUID 重插 seed 已存在的 `member.invite`/`member.read` 自然键，触发 `permissions_permission_key_key` unique violation。
- 因 pgTAP Gate 失败，按一次性工作包停止；未运行 db lint、advisors 或 migration list，未把 P2-L 写成 PASS。

## Cleanup

- 精确执行 `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`，exit `0`；未使用 `--all`，未停止共享 Colima。
- Cleanup 后目标 containers、volumes、network 与 `55320–55329` listeners 均为空。
- 未保存 publishable/service-role key、DB URL/password、OTP、token、JWT、cookie、合成邮箱值、raw status 或真实 PII。

## Offline fixture fix candidate

- 两份 pgTAP 测试的事务内 search path 加入 Supabase `extensions` schema，使 `ok`、`lives_ok`、`throws_ok` 和 `finish` 解析到已安装扩展。
- invitation fixture 对 `member.invite` 与 `member.read` 复用 seed 的 canonical IDs，避免用不同主键撞同一 `permission_key`；所有 role-permission 和临时更新引用同步修改。
- 静态门新增回归断言，要求两份测试包含 `extensions`，且 seed/test 对上述两个权限使用同一 canonical ID。
- 修复候选 hashes：schema pgTAP=`6aacf9f84d0f1556411a7fb852010f57312e8a8e`；invitation pgTAP=`c2042230ad9867f08fe2ccd5062d111fc62fc368`；structure=`3fbbd16d9e65c486787ec205b246ac0993662a5d`。结构门与 `git diff --check` 通过。
- 本 evidence 包不重启 runtime、不重跑 pgTAP；修复候选须在下一独立 bounded Gate 从空资源验证。
