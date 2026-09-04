# P6 商家运营闭环 — 最终本地运行门禁

日期：2026-09-04（Europe/Rome）

结果：**FINAL LOCAL RUNTIME PASS / INDEPENDENT RE-REVIEW PENDING**

## 精确候选与范围

- candidate commit：`09f69e6d9830a374b34bdd69ea675b2b027b7521`；branch：`codex/rebuy-v1-local-complete`；P6 base：`90744a1`。
- `candidate-sha256.txt` 覆盖 `90744a1..09f69e6` 的全部 `33/33` 个变更文件，不只覆盖核心文件。
- 环境仅为 synthetic-only local：project=`rebuy-g2-a1-e2a-local-email-otp-exec`、Node=`22.12.0`、Supabase CLI=`2.101.0`、Next.js=`16.3.2`。
- 未连接 hosted Supabase，未使用真实 PII，未执行 push、merge、Vercel deploy 或 Production 写入。

## 本轮最终结果

- clean entry：Git 工作树为空；目标 containers、volumes、network 与 `3000/9225/55320–55329` listeners 均为空。
- start 与 fresh reset 均 exit `0`；五条 migration 和三份合成 seed 从空库重放。
- AMR/recent-OTP preflight 到达 `P2L_PREFLIGHT_PASS`。
- 完整 pgTAP 一次通过：十个文件全部 `ok`，`Files=10, Tests=502, Result=PASS`。
- 六套并发/竞态全部通过：P2-L invitation、P3 approval、P4 inventory、P5 checkout、P5 race、P6 operations。
- schema strict lint、security strict、performance warning strict 均零问题；all/info 只有 fresh DB `unused_index` INFO，WARN/ERROR 为零。
- local/remote migration history 对齐：`20260831183358, 20260903120000, 20260903170000, 20260904120000, 20260904170000`。
- Auth contract `46/46`；P2-L preflight/migration 与 P3/P4/P5/P6 structure、TypeScript、全量 ESLint、Next production build、`git diff --check` 全部通过。
- 浏览器真实链路到达 `P6_BROWSER_E2E_PASS`，覆盖注册/登录、无权限页、商家成员授予、商品、库存、订单、售后、审计、键盘与 390/430/768/1024/1440 响应式。
- stop/no-backup exit `0`；最终目标资源、listeners 与临时 Chrome profile 均为空；共享 Colima 保留。

## 独立 NO-GO 后的修正

- 第一轮独立终审对 `eabbe90` 给出 `P0=0/P1=0/P2=2/P3=1`：源码安全与事务设计成立，但证据文件和动态授权矩阵不足。
- `9a5d09e` 增加 private implementation effective ACL、public/private read/write parity、private cross-store deny、store-scoped employee 正负向、permission drift 与 retired-role drift；结构门锁定新增覆盖。
- 在 `9a5d09e` 首次完整 pgTAP 502/502 通过后，P2-L invitation concurrency 发现一次真实微秒级竞态；后五套并发按规则未运行。
- 根因是并发 replay 在等待 invitation 行锁前保存的 `statement_timestamp` 可能早于胜者刚创建的 membership `valid_from`。`09f69e6` 改为 accepted replay 获锁后的 wall-time 有效期重验，并把 failure cleanup 的 JSONB 比较改为结构比较。
- 最终候选 `09f69e6` 随后重新 fresh reset、完整 pgTAP 和六套并发，全部通过。详细有限记录见 `recovery-history.txt`。

## 边界与登记项

- 本证据只证明 P6 local Exit 候选；同一独立审查者给出 FINAL GO 前不关闭 P6、不打开 P7。
- P3：`list_my_merchant_audit` 当前先聚合再 limit，数据规模增大时可能放大内存/延迟；登记至 P7，以关系式 `UNION ALL` 后统一排序限流处理。
- fresh DB 未使用索引 INFO 只登记观察，不在无生产查询样本时删除索引。
- 所有工件均为脱敏有限输出，不保存 local secret/key、OTP、cookie、JWT、合成邮箱值、订单 UUID 或连接串。
