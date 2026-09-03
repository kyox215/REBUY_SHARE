# P2-L schema runtime attempt #17

日期：2026-09-03（Europe/Rome）

结果：**STOP / FAIL AT AMR RUNTIME PRECONDITION**

## Entry and candidate binding

- 唯一写入 worktree=`/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划/.worktrees/rebuy-v1-local-complete-exec`；branch=`codex/rebuy-v1-local-complete`；base HEAD=`36b0b34a6696baa658e4c39b9ffb20a94bbbb9b6`；origin/main=`3c6ebf20b56f7ab37956a4ad9c543389a5636e65`。
- local project id=`rebuy-g2-a1-e2a-local-email-otp-exec`；CLI=`2.101.0`；`55320–55329`。实际前目标 containers、volumes、network 与 listeners 均为空，CLI help、候选结构门、Node syntax、目标 ESLint、typecheck、全量 lint、Next build 与 diff check 已通过。
- 数据库候选 SHA-256：roles=`a27c5368ce87df265237ea9dc59bb460bb222d4da6a2bff66d5b352b656bc7fd`；migration=`294b549bf94e01ad5cac514f3728d6b8efdd956cdf94f7fb30286f84028b5a9d`；seed=`e4e2890b878076ac9779117362705415a8d03ae1e039f48327c604e133b95ad1`；schema pgTAP=`b68f0dfd3a13b5e29bf811b073e78ab62a99876a037230a109357efb200f24cc`；invitation pgTAP=`b8d519733e91ecc3799eb1b158879d688e7320112d1037844a60e24bc6bddaf7`；migration structure=`1645a47edc5ff430b6f9ce9f59835e0140233451ea2bed5152929d57fe12e2a3`；concurrency harness=`2792dd7a1e5b580b0b33da133689e1e8f26b28e2bff8125457390710a4052f82`。
- actual 使用的 AMR harness/config/structure Git blobs 分别为 `0bf3a6b102598b5291365d92defa825f4a1a91e8`、`f8d7e485abbbba0d430de075e2fa57b5674df83a`、`4f5a88b7b194494cfc9d7834041a3c43c001720a`。

## Actual result and stop boundary

- 唯一 `supabase start --yes` exit `0`，因此本次候选 migration 与 seed 已由 fresh local start 成功应用；可能包含 URL/key/password 的原始输出只进入 `/private/tmp/rebuy-p2l-attempt17-start.raw`，未进入聊天或仓库，cleanup 后已删除。
- AMR preflight 误由默认 Node `20.20.2` 启动。有限输出为 `STATUS_PASS`、`EMAIL_GENERATED_PASS`、`UNEXPECTED_FAIL`、`P2L_PREFLIGHT_FAIL`；在 `createClient()` 初始化期间停止，尚未发 OTP、读取 Mailpit OTP、验证身份或 refresh。
- 按 one-shot Gate 立即停止。本批 `database_actual_count=1`，没有执行 `db reset`、两份 pgTAP、双连接并发 harness、strict db lint、security/performance/all advisors 或 migration list；不得把 start 成功外推为这些门禁通过，也不得在本工作包重试。

## Root cause and offline-only fix

- 默认 Node 20 对相同 synthetic `createClient()` 的离线复现给出 `Node.js detected but native WebSocket not found`；项目声明 `engines.node=22.x` 且 `.node-version=22`。固定 `/Users/kyox215/.nvm/versions/node/v22.12.0/bin/node` 对同一离线构造返回 `NODE22_CREATE_CLIENT_PASS`，根因确定为 actual orchestration 没有固定项目 Node 22，而非数据库、Auth、邮箱或 RLS 失败。
- cleanup 后才修改 harness：新增 Node major 精确为 22 的前置检查，并在纯结构测试覆盖 `20=false`、`22=true`、`24=false`、invalid=false。Node 20 现在在任何 status、网络、OTP 或数据库动作前只输出 `NODE_RUNTIME_FAIL`、`P2L_PREFLIGHT_FAIL`；Node 22 syntax 与纯结构测试通过。
- 修正后的 AMR harness/config/structure Git blobs 分别为 `6b5ad61bdc350ef6399fba3d4d8c4c3f7512101e`、`73461e51f40db2d56a7024fdac543ed5d7923f01`、`230267c68030570d7cd1951d3b743bc95e7eeab3`。这些只是 offline candidate，不是新的 runtime PASS。

## Cleanup and status

- `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup` exit `0`。目标 containers、volumes、network 与 `55320–55329` listeners 全部为空；启动 raw 与专用 telemetry temp 已删除。
- 脱敏命令、入口、有限 AMR 输出和 cleanup 分别保存在本目录；不含 key、password、OTP、token、cookie、JWT、合成邮箱值或真实 PII。
- P2-L 恢复为 **RUNTIME FIX CANDIDATE / REVIEW BLOCKED**。下一工作包必须从空资源、固定 Node `22.12.0` 和新的 hashes 做完整单次 `start → AMR → reset → pgTAP → concurrency → strict lint/advisors → migration list → cleanup`；通过后再交同一独立 reviewer 复审。P3–P7、hosted/Production、main push/deploy 继续关闭。
