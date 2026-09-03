# P2-L schema runtime attempt #18

日期：2026-09-03（Europe/Rome）

结果：**STOP / FAIL AT STORE-INVITATION pgTAP**

## Entry and exact candidate

- worktree=`/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划/.worktrees/rebuy-v1-local-complete-exec`；branch=`codex/rebuy-v1-local-complete`；base HEAD=`36b0b34a6696baa658e4c39b9ffb20a94bbbb9b6`；origin/main=`3c6ebf20b56f7ab37956a4ad9c543389a5636e65`。
- local project id=`rebuy-g2-a1-e2a-local-email-otp-exec`；CLI=`2.101.0`；Node=`22.12.0`；pnpm=`10.33.3`；端口=`55320–55329`。actual 前目标 containers、volumes、network 与 listeners 均为空。
- 数据库与测试候选 SHA-256：roles=`a27c5368ce87df265237ea9dc59bb460bb222d4da6a2bff66d5b352b656bc7fd`；migration=`294b549bf94e01ad5cac514f3728d6b8efdd956cdf94f7fb30286f84028b5a9d`；seed=`e4e2890b878076ac9779117362705415a8d03ae1e039f48327c604e133b95ad1`；schema pgTAP=`b68f0dfd3a13b5e29bf811b073e78ab62a99876a037230a109357efb200f24cc`；invitation pgTAP=`b8d519733e91ecc3799eb1b158879d688e7320112d1037844a60e24bc6bddaf7`；AMR config=`691d8a174e82ffe283a70d249f8fbe900000e41da61b8eb1d7a1265426d4f0d6`；AMR harness=`b2174165fde080a82cb1e45228ce2fc21e666706a4c31660fcd8af607ecf4104`；AMR structure=`403d9a87ca72d148f89f2945c249191f0bccba1915691be33b0e081df63038a7`；migration structure=`1645a47edc5ff430b6f9ce9f59835e0140233451ea2bed5152929d57fe12e2a3`；concurrency=`2792dd7a1e5b580b0b33da133689e1e8f26b28e2bff8125457390710a4052f82`。
- Node 22 下 Auth `46/46`、AMR structure、migration structure、typecheck、全量 ESLint、Next `16.3.2` production build 与 diff check 通过；生成态已恢复。

## Runtime progress and STOP

- 唯一 `supabase start --yes` exit `0`，敏感输出仅进入 `/private/tmp/rebuy-p2l-attempt18-start.raw`。固定 Node 22 的 AMR preflight 从 `NODE_RUNTIME_PASS` 到 `P2L_PREFLIGHT_PASS` 全部通过；仅保存有限断言名，不保存 email、OTP、key、token、JWT 或 session。
- `supabase db reset --local` exit `0`：schema 初始化、roles、migration `20260831183358`、seed 与容器重启均成功。
- pgTAP：schema/security 文件 PASS；invitation `52` 项中 `48` PASS、`4` FAIL。失败精确为 `37 store invitation accept succeeds`、`38 store accept writes exactly one active store scope`、`50 store-state invitation accepts after the store is restored`、`51 restored store-state accept writes one store scope`，两条 accept 都只暴露有限 `P0001/invitation_not_available`。合计 `Files=2, Tests=109, Failed=4, Result=FAIL`。
- 按 one-shot Gate 立即停止，本批 `database_actual_count=1`，未运行 concurrency、strict lint、security/performance/all advisors 或 migration list，也未在本工作包重试。

## Offline diagnosis boundary

- cleanup 后只读映射 PL/pgSQL line 442 到 creator store-scope validation。accept 在验证 store invitation 时，RLS context 仍精确绑定被邀请者的 `scope_type=store/store_id`，因此 `membership_store_scopes_executor_context_select` 只允许看到创建者的 exact store scope，看不到同一创建者更高层的 organization scope。
- 当前 fixture 中创建者合法持有 active organization scope；create 允许组织管理员创建 store invitation，但 accept revalidation 被窄上下文误拒绝。这是实现的 context-switch 缺失，不是放宽 policy 或改变 fixture 即可关闭的问题。
- 下一候选只允许在 private implementation 内先用 invitation store context 验证 store 状态，再显式切换到 organization context 检查 creator organization scope；若不存在，再切回 exact store context 检查 creator store scope；完成后恢复 invitation context。RLS policy 保持不变，并补静态门及两种 creator scope 的成功测试。

## Cleanup and next

- exact stop/no-backup exit `0`；敏感 start raw 与 AMR telemetry temp 删除；目标 containers、volumes、network 与 `55320–55329` listeners 均为空。
- 本目录保存脱敏 entry、AMR、reset、pgTAP、cleanup、commands 与 SHA-256；不保存任何 secret 或 PII。
- P2-L 仍为 **RUNTIME FIX CANDIDATE / REVIEW BLOCKED**。下一工作包只能从空资源和新 hashes 完成一次完整 Gate；PASS 后由同一独立 reviewer 定向复审。P3–P7、hosted/Production、main push/deploy 继续 CLOSED。
