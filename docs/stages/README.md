# 阶段记录索引

本目录只索引阶段事实记录，不复制 [全局执行总计划](../14-全局执行总计划.md) 的路线细节，也不替代唯一当前状态源 [项目状态与阶段台账](../15-项目状态与阶段台账.md)。记录中的本地预览、静态检查、合成数据和浏览器证据不能表示 Staging、受控生产或生产验收。

## 1. 当前记录

| 阶段 | 状态 | 证据级别 | 记录 |
|---|---|---|---|
| GOV-1 治理文档与状态台账 | 已通过 | 本地静态 | [GOV-1-治理文档与状态台账](./GOV-1-治理文档与状态台账.md) |
| G0/P1 买家端视觉验收与 UI 冻结 | 已通过并冻结 | 本地交互 | [G0-P1 事实记录](./G0-P1-视觉验收与UI冻结.md)；[Owner 视觉验收清单](./G0-P1-Owner视觉验收清单.md)；[分类目录 IA 复验证据](../evidence/G0-P1/2026-08-25-category-directory-ia/README.md)；[全流程验收证据](../evidence/G0-P1/2026-08-25-full-experience-acceptance/README.md) |
| G1 工程底座与环境隔离 | 已通过 | 本地静态 + 本地等价 + archive 预检 + 远端只读 + 远端 Actions + main merge closeout + Owner Gate | [G1 Owner 验收清单](./G1-Owner验收清单.md)；[G1 final closeout](../evidence/G1/2026-08-27-g1-final-closeout/README.md)；[G1.2b main merge closeout](../evidence/G1/2026-08-27-g1-2b-main-merge/README.md)；[G1.3-0 本地环境预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md)；[G1 阶段合同](./G1-工程底座与环境隔离.md) |
| G2-A0 账号安全合同与威胁模型 | 已通过（Exit GO；远端 docs-only reconciliation 已完成） | 本地静态 + 远端 merge/Actions + 独立复审 | [G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)；[G2-A0 Owner 验收清单](./G2-A0-Owner验收清单.md)；[G2-A1 Entry preparation 证据](../evidence/G2-A1/2026-08-28-entry-preparation/README.md)；[A0 ADR 与威胁模型](../09-A0-账号架构ADR与威胁模型.md) |
| G2-A1 独立 Auth spike | 执行中（B1 最小连接及配置/能力只读预检已完成；B2 本地安全基础已合并 main/远端闭环通过） | 本地静态 + Node 契约测试 + 构建 + 隔离首页 browser smoke + 远端 main merge/Actions；callback/Auth 运行未开始 | [G2-A1 准备与资源门禁](./G2-A1-Auth-Spike准备与资源门禁.md)；[B2 本地安全基础证据](../evidence/G2-A1/2026-08-28-b2-local-foundation/README.md)；[B1 配置/能力预检证据](../evidence/G2-A1/2026-08-28-b1-capability-preflight/README.md)；[B1 风险 Gate 证据](../evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)；[Entry preparation 证据](../evidence/G2-A1/2026-08-28-entry-preparation/README.md)；[资源成本与密钥 Gate 模板](../templates/G2-A1-资源成本与密钥Gate模板.md)；[Auth 实测矩阵模板](../templates/G2-A1-Auth实测矩阵模板.md) |

GOV-1 的阶段事实见其[独立记录](./GOV-1-治理文档与状态台账.md)，当前状态已由 Owner 于 2026-08-25 18:58:57 CEST 确认为“已通过”；G0/P1 的路径/装饰标题、统一选择器和分类目录 IA 修订已完成，当前 G0/P1 为“已通过并冻结”。G1 已于 2026-08-27 完成 G1-19/G1 Exit=GO，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`；merge main 与 exact-head Actions 证据见[G1 final closeout](../evidence/G1/2026-08-27-g1-final-closeout/README.md)。G2-A0 当前为 `Exit GO；远端 docs-only reconciliation 已完成`，验收 ref=`140ea15d9c3f178a326709d35ad1750a156df0d1`，merge=`fd9b712c7b07bf34399f9838eebb75846425c1d1`；G2-A1 执行中，B1 最小连接及配置/能力只读预检已完成，B2 本地安全基础已合并 main/远端闭环通过；PR #12 merge=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`，main Actions run=`33209420614`/job=`98978680399` success，`test:auth` 12/12 且仅运行一次，exact merge 的 GitHub deployments=`0`，来源分支保留；该闭环仅关闭本地基础交付，不等于 B2/Auth/G2-A1 整体通过；真实 Auth/OAuth/SMTP/session/DB/Storage/Production 与外部 action-time Owner Gate 继续 CLOSED。当前状态必须与 [15 台账](../15-项目状态与阶段台账.md) 一致；本索引只做导航，不复制记录细节。

## 1.1 2026-08-28 当前纠正与 G2-A1 B1 最小连接状态（历史快照；当前 B2 见 1.4）

G2-A0 远端 docs-only reconciliation 已完成：PR #7 merge=`fd9b712c7b07bf34399f9838eebb75846425c1d1`；main Actions run=`33122238997` / job=`98691703085` 全绿；merge SHA 的 GitHub deployments=`0`；来源分支保留。G2-A1 执行中，B1 最小连接及配置/能力只读预检已完成，B2 本地 callback 安全基础完成候选，待独立安全复审与 Owner/主代理 Gate；既有文档治理复审首轮 finding 已关闭，本次独立运行时复审首次结论为 REVIEW NO-GO，本批 findings 由 `c15b11c` 修复；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，无未关闭 P0/P1/P2；该 GO 只关闭 B1 capability preflight 审查，不打开完整 B2 运行验证或任何 Auth/DB/Storage/OAuth/SMTP/费用/部署/Production Gate；不预写 push、PR、Actions 或 merge；完整 resource/cost/secret Gate 关闭。详见[G2-A1 准备与资源门禁](./G2-A1-Auth-Spike准备与资源门禁.md)、[B2 本地安全基础证据](../evidence/G2-A1/2026-08-28-b2-local-foundation/README.md)、[B1 风险 Gate 证据](../evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)、[Entry preparation 证据](../evidence/G2-A1/2026-08-28-entry-preparation/README.md)、[资源成本与密钥 Gate 模板](../templates/G2-A1-资源成本与密钥Gate模板.md)和[Auth 实测矩阵模板](../templates/G2-A1-Auth实测矩阵模板.md)。

## 1.2 其他阶段计划记录（历史快照；当前 B2 见 1.4）

以下记录是旧时点对 G1/G2-A0 合同及其证据，以及 G2-A1 Entry preparation、资源预检和 B1 最小连接的历史快照；G1 已通过并关闭，G2-A0 已完成远端 docs-only reconciliation；当前 G2-A1/B2 状态见 1.4：

| 阶段 | 状态 | 证据级别 | 计划合同 |
|---|---|---|---|
| G1.2/G1.3 工程门（已归档） | G1.2a/G1.2b/G1.3 已按证据完成，G1 Exit 已于 2026-08-27 通过 | 本地静态/本地等价/archive 预检/远端只读/远端 Actions/main merge closeout/Owner Gate | [G1-工程底座与环境隔离](./G1-工程底座与环境隔离.md)；[G1 Owner 验收清单](./G1-Owner验收清单.md)；[G1 final closeout](../evidence/G1/2026-08-27-g1-final-closeout/README.md)；[G1.2b main merge closeout](../evidence/G1/2026-08-27-g1-2b-main-merge/README.md)；[G1.3-0 本地环境预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) |
| G2-A0 账号安全合同与威胁模型 | 已通过；Exit GO；远端 docs-only reconciliation 已完成 | 本地静态 + 远端 merge/Actions + 独立复审 | [G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)；[G2-A0 Owner 验收清单](./G2-A0-Owner验收清单.md)；[G2-A0 Entry preflight 证据](../evidence/G2-A0/2026-08-26-entry-preflight/README.md)；[G2-A1 Entry preparation 证据](../evidence/G2-A1/2026-08-28-entry-preparation/README.md)；[A0 ADR 与威胁模型](../09-A0-账号架构ADR与威胁模型.md) |
| G2-A1 独立 Auth spike（历史快照） | 当时执行中；B1 最小连接及配置/能力只读预检已完成；下一步曾为 B2 专项风险 Gate 草案复审；本次独立运行时复审首次结论为 REVIEW NO-GO，本批 findings 由 `c15b11c` 修复；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，仅关闭 B1 capability preflight 审查；完整 resource/cost/secret Gate 关闭 | 历史本地静态 + 本地交互 + 外部资源只读核验 | [G2-A1 准备与资源门禁](./G2-A1-Auth-Spike准备与资源门禁.md)；[B2 本地安全基础证据](../evidence/G2-A1/2026-08-28-b2-local-foundation/README.md)；[B1 配置/能力预检证据](../evidence/G2-A1/2026-08-28-b1-capability-preflight/README.md)；[B1 风险 Gate 证据](../evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)；[Entry preparation 证据](../evidence/G2-A1/2026-08-28-entry-preparation/README.md)；[资源成本与密钥 Gate 模板](../templates/G2-A1-资源成本与密钥Gate模板.md)；[Auth 实测矩阵模板](../templates/G2-A1-Auth实测矩阵模板.md) |

## 1.3 2026-08-28 G2-A1 B1 配置/能力只读预检（历史快照；当前 B2 见 1.4）

以 [15 台账](../15-项目状态与阶段台账.md) 为唯一当前状态源：B1 配置/能力只读预检已完成，范围仅为指定 Supabase Auth 配置页的脱敏能力分类；没有配置变更、Auth 运行、真实账号/邮件、数据库/Storage/OAuth 操作或 Production 操作。B2 专项风险 Gate 草案、三入口前提、Free 限制和 STOP 条件见[B1 配置/能力预检证据](../evidence/G2-A1/2026-08-28-b1-capability-preflight/README.md)。

（历史状态）G2-A1 仍为执行中，B2 实施保持 CLOSED；完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续关闭。connector 精确目标当前不可复验的残余风险保持记录。本索引只做导航，不复制 dashboard 详细观察。

## 1.4 2026-08-28 G2-A1-B2 本地安全基础实现（本地 closeout 历史；当前远端见 1.5）

G2-A1 当时执行中；B1 最小连接与配置/能力只读预检已完成；B2 本地安全基础通过/可进入远端 PR 候选。candidate exact-head `761de2b3a8ce22247501cddbad2da6e2cfc3ae59` 的独立定向复审为 REVIEW GO，P0/P1/P2=0；该 GO 仅关闭本地基础 review，不等于 B2/Auth/G2-A1 整体通过。范围与验证见[B2 本地安全基础证据](../evidence/G2-A1/2026-08-28-b2-local-foundation/README.md)。真实 Auth/OAuth/SMTP/session/DB/Storage/Production 与 B2 full Gate 继续 CLOSED；隔离首页 browser smoke 已通过，callback/Auth 运行未开始。该段记录的是本地 closeout 时点，远端闭环见下节。

## 1.5 2026-08-28 G2-A1-B2 本地安全基础远端闭环（当前）

- B2 本地安全基础已合并 main/远端闭环通过：PR #12 已以 merge commit 合并到 `main`，head=`55b7497953bc22e002e4c75a4b039c5b08fd98e7`，merge=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`，parents=`689d9679293f255c44feb314428a2678b9fe4d06` + `55b7497953bc22e002e4c75a4b039c5b08fd98e7`；来源分支 `codex/g2-a1-b2-local-foundation` 保留。
- 远端 `main` exact head=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`；main Actions run=`33209420614` / job=`98978680399` success，`test:auth` 12/12 且仅运行一次；exact merge 的 GitHub deployments=`0`。Vercel 仍为 `3` 个既有 deployments，Production 仍为 `READY`，aliases=`2`，本次无新增 Preview/Production deployment。
- 该 closeout 只关闭本地安全基础的远端 source/CI 交付记录；完整 B2、real Auth/OAuth/SMTP/session/DB/Storage/Production 与外部 action-time Owner Gate 继续 CLOSED。下一步仅可进入 B2 外部入口 Gate 设计/资源检查，不预写 external Auth success；不自动打开 B3、P2 或 Production。

## 2. 命名与追加规则

1. 文件名使用 `<阶段ID>-<短名称>.md`，阶段 ID 与 [14 全局路线](../14-全局执行总计划.md#4-阶段依赖链) 一致；示例：`G0-P1-视觉验收与UI冻结.md`。
2. 新阶段记录用新文件，不覆盖已有事实；同一阶段的后续批次在原记录末尾按 `YYYY-MM-DD｜标题` 追加，或由 Owner 指示建立带批次后缀的新记录并在此索引。
3. 每条记录必须注明状态、证据级别、Owner/执行/审查角色、Europe/Rome 时间、环境、代码/提交引用、验证结果、回退、风险和 Owner Gate。没有 ref 写 `N/A`。
4. 事实纠错使用新的日期条目，说明旧结论为何不准确、影响哪些状态、采用什么新证据；不得静默删除历史。
5. 只记录最小化合成数据摘要。不得写入密码、token、API secret、客户 PII、真实商家资料、原始敏感附件、生产 cookie 或未脱敏日志。
6. 阶段记录的状态必须与 15 一致；发现漂移时先修正 15 并在记录中追加纠正，再同步本索引。

## 3. 证据和状态速查

状态枚举、证据枚举、Owner Gate 规则和生产边界以 [15 台账](../15-项目状态与阶段台账.md) 为准。GOV-1 已通过；G0/P1 当前为“已通过并冻结”；G1 已于 2026-08-27 以 G1-19/G1 Exit=GO 完成，ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`。G2-A0 已通过（Exit GO；远端 docs-only reconciliation 已完成，merge=`fd9b712c7b07bf34399f9838eebb75846425c1d1`），七项 Owner 政策已采纳；G2-A1 执行中，B1 最小连接及配置/能力只读预检已完成，B2 本地安全基础已合并 main/远端闭环通过；PR #12 merge=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`，main Actions run=`33209420614`/job=`98978680399` success，`test:auth` 12/12 且仅运行一次，exact merge 的 GitHub deployments=`0`，来源分支保留；该闭环仅关闭本地基础远端交付，不等于 B2/Auth/G2-A1 整体通过；真实 Auth/OAuth/SMTP/session/DB/Storage/Production 与外部 action-time Owner Gate 继续 CLOSED；下一步仅可进入 B2 外部入口 Gate 设计/资源检查，不预写 external Auth success；完整 resource/cost/secret Gate 关闭。详见[G1 final closeout](../evidence/G1/2026-08-27-g1-final-closeout/README.md)、[G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)、[G2-A1 B2 本地安全基础证据](../evidence/G2-A1/2026-08-28-b2-local-foundation/README.md)、[G2-A1 B1 风险 Gate 证据](../evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)。

## 3.1 2026-08-28 当前状态纠正

以 [15 台账](../15-项目状态与阶段台账.md) 为唯一当前状态源：G2-A0 已通过且远端 docs-only reconciliation 已完成（merge=`fd9b712c7b07bf34399f9838eebb75846425c1d1`）；G2-A1 执行中，B1 最小连接及配置/能力只读预检已完成，B2 本地安全基础已合并 main/远端闭环通过；PR #12 merge=`96ee24a4e5ba7eaee684731eacf707d4da29c44b`，main Actions run=`33209420614`/job=`98978680399` success，`test:auth` 12/12 且仅运行一次，exact merge 的 GitHub deployments=`0`，来源分支保留；该闭环仅关闭本地基础远端交付，不等于 B2/Auth/G2-A1 整体通过；真实 Auth/OAuth/SMTP/session/DB/Storage/Production 与外部 action-time Owner Gate 继续 CLOSED；下一步仅可进入 B2 外部入口 Gate 设计/资源检查，不预写 external Auth success；完整 resource/cost/secret Gate 关闭。后续四批合同、官方来源刷新、复用预检与资源责任字段见[G2-A1 准备与资源门禁](./G2-A1-Auth-Spike准备与资源门禁.md)，静态摘要见[B2 本地安全基础证据](../evidence/G2-A1/2026-08-28-b2-local-foundation/README.md)和[B1 风险 Gate 证据](../evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)。本索引不复制运行时或生产结论。

## 4. 2026-08-26 当前状态去漂移维护

本批对非权威文档的陈旧当前时态做了最小纠正，并保留带日期的历史决定；GOV-1/G0/P1/G1 当前状态与 [15 台账](../15-项目状态与阶段台账.md) 一致。完整范围、发现、验证与回退边界见[GOV-1 当前状态去漂移审计](../evidence/GOV-1/2026-08-26-current-state-drift-audit/README.md)。本批不改变 G1/G2 Gate，不修改代码、依赖、workflow 或外部状态。

## 5. 2026-08-27 G1.2b 远端 PR/CI 同步（合并前历史快照）

本次阶段索引同步 G1.2b 真实 PR/Actions、远端只读权限设置和公开仓库 lineage；PR #1 保持 OPEN/CLEAN，未合并 `main`。本批文档更新不代表 G1.3/Preview/在线回退已开始，G1 Exit 继续 NO-GO，G2-A0 不打开。文档提交后新的 PR head check 需以远端当前状态独立复核，不递归回写初始 Actions run ID。完整记录见[G1.2b 远端 PR/CI 证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md)。

## 6. 2026-08-27 G1.2b main merge closeout（历史快照）

独立 merge reviewer 已对 PR #1 head 正式给出 GO；PR #1 随后通过 GitHub merge commit 合并 main，merge 后 main push 的 `Prototype quality` run/job 已成功，`integration/g1-2b` 仍保留。G1.2b main merge 不打开 G1.3、Preview、Supabase/Auth/DB 或 Production；G1 Exit 继续 NO-GO，G2-A0 不打开。完整事实见[G1.2b main merge closeout](../evidence/G1/2026-08-27-g1-2b-main-merge/README.md)。

## 7. 2026-08-28 G2-A0 远端闭环与 G2-A1 Entry preparation/资源预检（历史快照）

（历史快照）G2-A0 远端 docs-only reconciliation 已完成：PR #7 merge=`fd9b712c7b07bf34399f9838eebb75846425c1d1`，main Actions run=`33122238997` / job=`98691703085` 全绿，merge SHA 的 GitHub deployments=`0`，来源分支保留。该时点 G2-A1 技术阶段未开始；无资源 Entry preparation 已归档；最小资源存在性/基础预检已完成；独立安全复审已完成且首轮 finding 已关闭，A1-B1 最小技术范围已授权/待执行；完整 resource/cost/secret Gate 关闭。该时点只允许脱敏资源事实、文档、模板、接口草图、测试矩阵和 `.invalid` 合成字段，禁止 secret/env/PII、Auth/DB/Storage/OAuth/SMTP 配置、真实数据、部署或 Production。当前状态见本索引 1.1。详见[G2-A1 准备与资源门禁](./G2-A1-Auth-Spike准备与资源门禁.md)、[B1 风险 Gate 证据](../evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)与[Entry preparation 证据](../evidence/G2-A1/2026-08-28-entry-preparation/README.md)。

### 2026-08-28｜G2-A1 Free Supabase 资源存在性/基础预检（历史资源快照）

（历史资源快照）独立 Supabase 组织 `Rebuy Lab` 的 `plan=Free`、项目 `rebuy-auth-spike` 的 `eu-central-1` 区域与 `ACTIVE_HEALTHY` 管理面状态曾核验；provider quote 为 `amount=0`、`recurrence=monthly`（API 未返回 currency），并已完成 Owner quote 确认与 `confirm_cost`。该窄范围事实不等于 Auth/DB/运行时通过；完整 resource/cost/secret、secret/env、Auth、DB/schema/RLS、Storage、OAuth、SMTP、真实数据、部署和 Production Gate 继续关闭。后续独立运行时复审期间 connector 无法再次列出精确目标，当前管理面状态无法复验；此前本地 health `200` 仅为当时运行窗口的时间界定证据，不是当前持续健康保证。详情见[G2-A1 准备与资源门禁](./G2-A1-Auth-Spike准备与资源门禁.md)和[B1 风险 Gate 证据](../evidence/G2-A1/2026-08-28-b1-risk-gate/README.md)。

### 2026-08-28｜G2-A1 B1 最小连接验证当前状态

- （历史状态）G2-A1 当前执行中，B1 最小连接及配置/能力只读预检已完成；下一步曾为 B2 专项风险 Gate 草案独立复审与 Owner/主代理 Gate；B2 实施当时仍 CLOSED。既有文档治理复审首轮 finding 已关闭；本次独立运行时复审首次结论为 REVIEW NO-GO，本批 findings 由 `c15b11c` 修复；本批 findings 由 `7952d16` 修复；独立定向复审对该 exact head 给出 REVIEW GO，仅关闭 B1 capability preflight 审查，不代表 B2 实施或 Auth 通过；不预写 push、PR、Actions 或 merge。
- 初次 B1 运行前 connector 曾核对精确目标；独立运行时复审期间 connector 再次无法列出精确目标，当前管理面状态无法复验。未访问其他项目、未执行任何外部动作；此前本地 health `200` 仅为时间界定证据。当前 tracked tree/diff 未发现完整 active key、host、project ref 或 secret。
- Chrome DOM 与内部交接曾出现一个截断的 publishable 参数展示值，该值触发 `401` 后主动停止，且不是当前 active key；`prototype/.env.local` 仅记录为 ignored 且 owner-only 权限类别。完整 resource/cost/secret/Auth/DB/Storage/OAuth/SMTP/真实 PII/部署/Production Gate 继续关闭。

## 8. 2026-08-27 G2-A0 docs-only 执行启动（历史快照）

本节是 2026-08-27 G2-A0 closeout 前的历史快照，记录当时的启动边界，不代表当前 Gate。G1-19/G1 Exit=GO 后，Owner 已授权打开 G2-A0；当时阶段仅更新账号安全合同、ADR/威胁模型一致性、Owner 决策矩阵、阶段台账和导航；七项政策已采纳，07/08 同步其政策与状态，独立 decision-ready 文档治理审查已完成，但新的 exact-head 复审与 G2-A0 Exit 尚未完成。随后 Owner 已签署 G2-A0 Exit GO，并授权 docs-only 远端 reconciliation；该 reconciliation 在该历史快照时尚未执行。G2-A1 保持“未开始”，不创建或连接 Supabase/Auth/DB/Storage/Realtime，不读取 secret/env/PII，不修改代码、依赖、lockfile、workflow、环境配置。远端 branch push、PR、Actions 和条件式 merge commit 仅可在新 head 独立复审与 exact-head 条件满足后按既定授权执行；Production/Preview 操作仍关闭。详细记录见[G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)。
