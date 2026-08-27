# 阶段记录索引

本目录只索引阶段事实记录，不复制 [全局执行总计划](../14-全局执行总计划.md) 的路线细节，也不替代唯一当前状态源 [项目状态与阶段台账](../15-项目状态与阶段台账.md)。记录中的本地预览、静态检查、合成数据和浏览器证据不能表示 Staging、受控生产或生产验收。

## 1. 当前记录

| 阶段 | 状态 | 证据级别 | 记录 |
|---|---|---|---|
| GOV-1 治理文档与状态台账 | 已通过 | 本地静态 | [GOV-1-治理文档与状态台账](./GOV-1-治理文档与状态台账.md) |
| G0/P1 买家端视觉验收与 UI 冻结 | 已通过并冻结 | 本地交互 | [G0-P1 事实记录](./G0-P1-视觉验收与UI冻结.md)；[Owner 视觉验收清单](./G0-P1-Owner视觉验收清单.md)；[分类目录 IA 复验证据](../evidence/G0-P1/2026-08-25-category-directory-ia/README.md)；[全流程验收证据](../evidence/G0-P1/2026-08-25-full-experience-acceptance/README.md) |
| G1 工程底座与环境隔离 | 已通过 | 本地静态 + 本地等价 + archive 预检 + 远端只读 + 远端 Actions + main merge closeout + Owner Gate | [G1 Owner 验收清单](./G1-Owner验收清单.md)；[G1 final closeout](../evidence/G1/2026-08-27-g1-final-closeout/README.md)；[G1.2b main merge closeout](../evidence/G1/2026-08-27-g1-2b-main-merge/README.md)；[G1.3-0 本地环境预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md)；[G1 阶段合同](./G1-工程底座与环境隔离.md) |
| G2-A0 账号安全合同与威胁模型 | 执行中 | 本地静态（docs-only） | [G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)；[G2-A0 Owner 验收清单](./G2-A0-Owner验收清单.md)；[A0 ADR 与威胁模型](../09-A0-账号架构ADR与威胁模型.md) |

GOV-1 的阶段事实见其[独立记录](./GOV-1-治理文档与状态台账.md)，当前状态已由 Owner 于 2026-08-25 18:58:57 CEST 确认为“已通过”；G0/P1 的路径/装饰标题、统一选择器和分类目录 IA 修订已完成，当前 G0/P1 为“已通过并冻结”。G1 已于 2026-08-27 完成 G1-19/G1 Exit=GO，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`；merge main 与 exact-head Actions 证据见[G1 final closeout](../evidence/G1/2026-08-27-g1-final-closeout/README.md)。G2-A0 已获 Entry 授权，当前仅执行 docs-only 安全合同候选；独立安全审查与 Owner Exit 尚未完成，G2-A1 保持“未开始”。当前状态必须与 [15 台账](../15-项目状态与阶段台账.md) 一致；本索引只做导航，不复制记录细节。

## 1.1 其他阶段计划记录（G2-A1 及后续未打开）

以下记录只描述 G1/G2-A0 等合同及其证据；G1 已通过并关闭，G2-A0 当前执行中，G2-A1 及后续阶段仍未开始：

| 阶段 | 状态 | 证据级别 | 计划合同 |
|---|---|---|---|
| G1.2/G1.3 工程门（已归档） | G1.2a/G1.2b/G1.3 已按证据完成，G1 Exit 已于 2026-08-27 通过 | 本地静态/本地等价/archive 预检/远端只读/远端 Actions/main merge closeout/Owner Gate | [G1-工程底座与环境隔离](./G1-工程底座与环境隔离.md)；[G1 Owner 验收清单](./G1-Owner验收清单.md)；[G1 final closeout](../evidence/G1/2026-08-27-g1-final-closeout/README.md)；[G1.2b main merge closeout](../evidence/G1/2026-08-27-g1-2b-main-merge/README.md)；[G1.3-0 本地环境预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) |
| G2-A0 账号安全合同与威胁模型 | 执行中；Entry 已授权，Exit 待独立审查与 Owner | 本地静态（docs-only） | [G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)；[G2-A0 Owner 验收清单](./G2-A0-Owner验收清单.md)；[G2-A0 Entry preflight 证据](../evidence/G2-A0/2026-08-26-entry-preflight/README.md)；[A0 ADR 与威胁模型](../09-A0-账号架构ADR与威胁模型.md) |

## 2. 命名与追加规则

1. 文件名使用 `<阶段ID>-<短名称>.md`，阶段 ID 与 [14 全局路线](../14-全局执行总计划.md#4-阶段依赖链) 一致；示例：`G0-P1-视觉验收与UI冻结.md`。
2. 新阶段记录用新文件，不覆盖已有事实；同一阶段的后续批次在原记录末尾按 `YYYY-MM-DD｜标题` 追加，或由 Owner 指示建立带批次后缀的新记录并在此索引。
3. 每条记录必须注明状态、证据级别、Owner/执行/审查角色、Europe/Rome 时间、环境、代码/提交引用、验证结果、回退、风险和 Owner Gate。没有 ref 写 `N/A`。
4. 事实纠错使用新的日期条目，说明旧结论为何不准确、影响哪些状态、采用什么新证据；不得静默删除历史。
5. 只记录最小化合成数据摘要。不得写入密码、token、API secret、客户 PII、真实商家资料、原始敏感附件、生产 cookie 或未脱敏日志。
6. 阶段记录的状态必须与 15 一致；发现漂移时先修正 15 并在记录中追加纠正，再同步本索引。

## 3. 证据和状态速查

状态枚举、证据枚举、Owner Gate 规则和生产边界以 [15 台账](../15-项目状态与阶段台账.md) 为准。GOV-1 已通过；G0/P1 当前为“已通过并冻结”；G1 已于 2026-08-27 以 G1-19/G1 Exit=GO 完成，ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`。G2-A0 当前为“执行中”，仅执行 docs-only 安全合同、威胁模型一致性和 Owner Gate 准备；独立安全审查尚未完成，G2-A1 保持“未开始”。详见[G1 final closeout](../evidence/G1/2026-08-27-g1-final-closeout/README.md)、[G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)和[G2-A0 Owner 验收清单](./G2-A0-Owner验收清单.md)。

## 4. 2026-08-26 当前状态去漂移维护

本批对非权威文档的陈旧当前时态做了最小纠正，并保留带日期的历史决定；GOV-1/G0/P1/G1 当前状态与 [15 台账](../15-项目状态与阶段台账.md) 一致。完整范围、发现、验证与回退边界见[GOV-1 当前状态去漂移审计](../evidence/GOV-1/2026-08-26-current-state-drift-audit/README.md)。本批不改变 G1/G2 Gate，不修改代码、依赖、workflow 或外部状态。

## 5. 2026-08-27 G1.2b 远端 PR/CI 同步（合并前历史快照）

本次阶段索引同步 G1.2b 真实 PR/Actions、远端只读权限设置和公开仓库 lineage；PR #1 保持 OPEN/CLEAN，未合并 `main`。本批文档更新不代表 G1.3/Preview/在线回退已开始，G1 Exit 继续 NO-GO，G2-A0 不打开。文档提交后新的 PR head check 需以远端当前状态独立复核，不递归回写初始 Actions run ID。完整记录见[G1.2b 远端 PR/CI 证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md)。

## 6. 2026-08-27 G1.2b main merge closeout（历史快照）

独立 merge reviewer 已对 PR #1 head 正式给出 GO；PR #1 随后通过 GitHub merge commit 合并 main，merge 后 main push 的 `Prototype quality` run/job 已成功，`integration/g1-2b` 仍保留。G1.2b main merge 不打开 G1.3、Preview、Supabase/Auth/DB 或 Production；G1 Exit 继续 NO-GO，G2-A0 不打开。完整事实见[G1.2b main merge closeout](../evidence/G1/2026-08-27-g1-2b-main-merge/README.md)。

## 7. 2026-08-27 G2-A0 docs-only 执行启动

G1-19/G1 Exit=GO 后，Owner 已授权打开 G2-A0。当前阶段仅更新账号安全合同、ADR/威胁模型一致性、Owner 待决矩阵、阶段台账和导航；独立安全审查与 G2-A0 Exit 尚未完成。G2-A1 保持“未开始”，不创建或连接 Supabase/Auth/DB/Storage/Realtime，不读取 secret/env/PII，不修改代码、依赖、lockfile、workflow、环境配置，不执行 push、PR、远端 Actions、Preview、部署、promote、alias 或 Production 操作。详细记录见[G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)。
