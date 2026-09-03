# P2-L schema runtime attempt #19

日期：2026-09-03（Europe/Rome）

结果：**STOP / FAIL AT CONCURRENCY STABLE-RETRY INTERVAL**

## Entry and exact candidate

- worktree=`/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划/.worktrees/rebuy-v1-local-complete-exec`；branch=`codex/rebuy-v1-local-complete`；base HEAD=`36b0b34a6696baa658e4c39b9ffb20a94bbbb9b6`；origin/main=`3c6ebf20b56f7ab37956a4ad9c543389a5636e65`。
- local project id=`rebuy-g2-a1-e2a-local-email-otp-exec`；CLI=`2.101.0`；Node=`22.12.0`；pnpm=`10.33.3`；端口=`55320–55329`。actual 前目标 containers、volumes、network 与 listeners 均为空。
- SHA-256：roles=`a27c5368ce87df265237ea9dc59bb460bb222d4da6a2bff66d5b352b656bc7fd`；migration=`13af3f60d2e665efaf3ae228cad2ffdee04d55c0a3969f55bbe65e4599ce28ba`；seed=`e4e2890b878076ac9779117362705415a8d03ae1e039f48327c604e133b95ad1`；schema pgTAP=`b68f0dfd3a13b5e29bf811b073e78ab62a99876a037230a109357efb200f24cc`；invitation pgTAP=`4c2a8a5bdea09f207f92dc76a5bd103c44634a5413ca1e07dcd25b05fe979041`；AMR config=`691d8a174e82ffe283a70d249f8fbe900000e41da61b8eb1d7a1265426d4f0d6`；AMR harness=`b2174165fde080a82cb1e45228ce2fc21e666706a4c31660fcd8af607ecf4104`；AMR structure=`403d9a87ca72d148f89f2945c249191f0bccba1915691be33b0e081df63038a7`；migration structure=`685fbac3533699256f62fcbe425a533046dd7ce193f716ca0cc243dea8fc6685`；concurrency=`2792dd7a1e5b580b0b33da133689e1e8f26b28e2bff8125457390710a4052f82`。
- 针对 attempt #18 修复，Node syntax、migration structure、目标 ESLint 与 diff check 通过；Auth/typecheck/build 复用同一 Node 22 应用源码未变的 attempt #18 entry 证据。

## Runtime progress and STOP

- 唯一 start exit `0`；固定 Node 22 的完整 AMR preflight PASS；fresh db reset 对 roles、migration、seed 与容器重启全部 PASS。
- 两份 pgTAP 全部通过：`Files=2, Tests=110, Failed=0, Result=PASS`。这包含 `service_role` effective ACL、accept negative/revalidation、organization-scoped creator 的 store accept，以及 creator exact-store scope 路径。
- 双连接 harness 已进入并越过 `same_invitation_concurrency`、`multi_invitation_concurrency` 与 `final_state`；随后只输出有限 `P2L_INVITATION_CONCURRENCY_FAIL:stable_retry`。旧 harness 的 `stable_retry` stage 同时覆盖 accepted-invitation lookup/parse、accepted retry、result equality、unavailable retry 和最后 cleanup，因此当前证据不能诚实定位其中哪一断言失败。
- 按 one-shot Gate 立即停止。本批 `database_actual_count=1`，未运行 strict lint、security/performance/all advisors 或 migration list，也未重试。

## Independent offline diagnosis boundary

- 这是本轮 attempt #17–#19 的第 3 次实际失败；按 Supabase 与 long-running guard 停止更多数据库尝试，先完成只读专项审查。
- 已排除把 `profiles` 简单判断为阻塞 auth user cleanup 的结论：`profiles.user_id` 明确为 `REFERENCES auth.users(id) ON DELETE CASCADE`。cleanup 仍可能因其他权限、触发器或顺序失败，但必须有证据，不能预写根因。
- 同一已批准独立 reviewer 已收到只读复审任务，要求逐项审计 stable-retry interval。下一候选至少要给 lookup、parse、accepted RPC exit/result、unavailable RPC exit/error 和 cleanup 各自有限 stage marker；不得输出 UUID、email、SQL、stderr 原值或其他数据。

## Cleanup and status

- exact stop/no-backup exit `0`；敏感 start raw 与 AMR telemetry temp 删除；目标 containers、volumes、network 与 `55320–55329` listeners 均为空。
- 本目录保存脱敏 entry、AMR、reset、pgTAP、concurrency category、cleanup、commands 与 SHA-256；不保存 key、password、OTP、token、cookie、JWT、邮箱值或真实 PII。
- P2-L 为 **PGTAP PASS / CONCURRENCY REVIEW BLOCKED**。独立专项审查与离线 harness 修复完成前不得新开 runtime；完整 Gate 和独立 reviewer GO 前 P3–P7、hosted/Production、main push/deploy 保持 CLOSED。
