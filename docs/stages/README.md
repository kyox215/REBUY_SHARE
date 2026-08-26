# 阶段记录索引

本目录只索引阶段事实记录，不复制 [全局执行总计划](../14-全局执行总计划.md) 的路线细节，也不替代唯一当前状态源 [项目状态与阶段台账](../15-项目状态与阶段台账.md)。记录中的本地预览、静态检查、合成数据和浏览器证据不能表示 Staging、受控生产或生产验收。

## 1. 当前记录

| 阶段 | 状态 | 证据级别 | 记录 |
|---|---|---|---|
| GOV-1 治理文档与状态台账 | 已通过 | 本地静态 | [GOV-1-治理文档与状态台账](./GOV-1-治理文档与状态台账.md) |
| G0/P1 买家端视觉验收与 UI 冻结 | 已通过并冻结 | 本地交互 | [G0-P1 事实记录](./G0-P1-视觉验收与UI冻结.md)；[Owner 视觉验收清单](./G0-P1-Owner视觉验收清单.md)；[分类目录 IA 复验证据](../evidence/G0-P1/2026-08-25-category-directory-ia/README.md)；[全流程验收证据](../evidence/G0-P1/2026-08-25-full-experience-acceptance/README.md) |
| G1 工程底座与环境隔离 | 执行中（G1.1 已完成，G1.2a 已完成，G1.2b 待 Owner Gate） | 本地静态 + 本地等价 | [G1.2a 本地 workflow/等价证据](../evidence/G1/2026-08-26-g1-2a-local-workflow/README.md)；[G1.2 CI 预检证据](../evidence/G1/2026-08-26-g1-2-ci-preflight/README.md)；[G1.2b-0 远端目标审计](../evidence/G1/2026-08-26-g1-2b-0-remote-target-audit/README.md)；[G1.1 本地基线证据](../evidence/G1/2026-08-25-g1-1-local-baseline/README.md)；[G1 Entry 基线证据](../evidence/G1/2026-08-25-entry-baseline/README.md)；[G1 阶段合同](./G1-工程底座与环境隔离.md) |

GOV-1 的阶段事实见其[独立记录](./GOV-1-治理文档与状态台账.md)，当前状态已由 Owner 于 2026-08-25 18:58:57 CEST 确认为“已通过”；G0/P1 的路径/装饰标题、统一选择器和分类目录 IA 修订已完成，Owner 最新原话 `分类目录IA通过，G0重新冻结，未覆盖项进入后续专项，恢复G1授权`，当前 G0/P1 为“已通过并冻结”。点击搜索已通过；直接 Enter 键盘提交未验证成功，转入后续键盘/无障碍专项，不阻塞本次冻结或 G1 Entry。G1 当前为“执行中（G1.1 已完成，G1.2a 已完成，G1.2b 待 Owner Gate）”：根仓库 `main` 和初始 SHA 已建立，Node `v22.12.0`/Corepack `0.34.6`/pnpm `10.33.3` fresh exact bootstrap 后隔离 frozen install、typecheck、lint、build 均通过；当前 workflow ref `b0681d58`，本地 workflow 已创建并完成等价验证，但无 remote/远端 CI/Preview 或 Supabase/生产连接。当前状态必须与 [15 台账](../15-项目状态与阶段台账.md) 一致；本索引只做导航，不复制记录细节。

## 1.1 后续计划记录（未打开）

以下记录只描述 G1.2/G1.3 等后续工程合同；G1.1 已完成，但不改变“Exit 未通过”的边界：

| 阶段 | 状态 | 证据级别 | 计划合同 |
|---|---|---|---|
| G1.2/G1.3 后续工程门 | G1.2a 已完成；G1.2b 待 Owner Gate；G1.3 未开始 | 本地静态/本地等价/规划 | [G1-工程底座与环境隔离](./G1-工程底座与环境隔离.md)；[G1.2a 本地 workflow/等价证据](../evidence/G1/2026-08-26-g1-2a-local-workflow/README.md)；[G1.2 CI 预检证据](../evidence/G1/2026-08-26-g1-2-ci-preflight/README.md)；[G1.1 本地基线证据](../evidence/G1/2026-08-25-g1-1-local-baseline/README.md) |

## 2. 命名与追加规则

1. 文件名使用 `<阶段ID>-<短名称>.md`，阶段 ID 与 [14 全局路线](../14-全局执行总计划.md#4-阶段依赖链) 一致；示例：`G0-P1-视觉验收与UI冻结.md`。
2. 新阶段记录用新文件，不覆盖已有事实；同一阶段的后续批次在原记录末尾按 `YYYY-MM-DD｜标题` 追加，或由 Owner 指示建立带批次后缀的新记录并在此索引。
3. 每条记录必须注明状态、证据级别、Owner/执行/审查角色、Europe/Rome 时间、环境、代码/提交引用、验证结果、回退、风险和 Owner Gate。没有 ref 写 `N/A`。
4. 事实纠错使用新的日期条目，说明旧结论为何不准确、影响哪些状态、采用什么新证据；不得静默删除历史。
5. 只记录最小化合成数据摘要。不得写入密码、token、API secret、客户 PII、真实商家资料、原始敏感附件、生产 cookie 或未脱敏日志。
6. 阶段记录的状态必须与 15 一致；发现漂移时先修正 15 并在记录中追加纠正，再同步本索引。

## 3. 证据和状态速查

状态枚举、证据枚举、Owner Gate 规则和生产边界以 [15 台账](../15-项目状态与阶段台账.md) 为准。GOV-1 已通过；G0/P1 当前为“已通过并冻结”，checkpoint 16 为通过；点击搜索已通过，直接 Enter 键盘提交未在本轮验证成功，转入后续专项。G1 当前为“执行中（G1.1 已完成，G1.2a 已完成，G1.2b 待 Owner Gate）”；G1.2a 以 Corepack `0.34.6` exact bootstrap 的 workflow/等价验证已完成（当前 ref `b0681d58`），仍无 remote/远端 CI/Preview，G1.3 未开始；Exit Gate 未通过前不可进入 G2-A0。
