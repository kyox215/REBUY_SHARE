# G1 Exit 本地预检证据包

阶段：G1 工程底座与环境隔离
批次：G1 Exit requirement-to-evidence 矩阵与 Owner 验收清单预检
状态：`G1 Exit NO-GO；G1.2b 与 G1.3 实施证据缺失，Owner 决定待明确`
证据级别：本地静态 + 本地等价 + archive 预检；无远端 CI/Preview/在线回退证据
记录日期：2026-08-26（Europe/Rome）
预检输入 HEAD：`9ba0f8e0f56c5711dc04ac83daf7051e863b2ecc`（`main`；开始时 clean）
远端 / deploy / environment ref：`N/A`

> 本记录只审计 G1 Exit 的证据完整性，不把 G1.2a 本地验证、G1.3-0 archive 或规划合同写成真实 CI、Preview、在线回退或 G1 通过。当前结论是 `NO-GO / G1 Exit 未通过`，G2-A0 不打开。

## 1. Owner 边界与审计输入

当前 Owner 已明确的授权只覆盖 G1.2a：

> `批准进入G1.2a：采用GitHub Actions候选，在本地创建只读最小CI工作流并做本地等价验证；暂不添加remote、不push、不运行远端CI、不部署Preview、不接Supabase或生产。`

本批核对了以下权威输入：

- [15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)：唯一当前状态源。
- [14 全局执行总计划](../../../14-全局执行总计划.md) 与 [05 V1 实施路线与验证计划](../../../05-V1实施路线与验证计划.md)：G1 目标、依赖、产物、最小验证、Owner Gate 和回退合同。
- [G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)：当前 G1 状态、G1.1–G1.3 边界、工具链、环境和回退要求。
- [G1.1 基线](../2026-08-25-g1-1-local-baseline/README.md)、[G1.2 preflight](../2026-08-26-g1-2-ci-preflight/README.md)、[G1.2a 等价验证](../2026-08-26-g1-2a-local-workflow/README.md)、[G1.2b-0 远端目标审计](../2026-08-26-g1-2b-0-remote-target-audit/README.md)、[G1.2b-1 历史演练](../2026-08-26-g1-2b-1-local-integration-rehearsal/README.md)、[G1.3-0 本地环境预检](../2026-08-26-g1-3-0-local-environment-preflight/README.md)。
- [G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)与当前 `.github/workflows/prototype-quality.yml`。

“设置目标并根据规划完成全部目标”这类一般性请求不能解释为解除前述 remote、push、Preview、Supabase/Auth、数据库或 Production 禁令；任何越界动作仍需对应的明确 Owner Gate。

## 2. 当前本地 Git 与 ref 事实

- `git rev-parse HEAD`：`9ba0f8e0f56c5711dc04ac83daf7051e863b2ecc`；分支 `main`；预检开始时 `git status --short --branch` 为 clean。
- `git remote -v`：无输出，当前项目未配置 remote；这不能证明外部仓库或部署资源不存在。
- 初始基线：`0d6bb3f621019e3c8ad4b81e6614cd8c6bea5bcb`。
- 稳定 tag：`g1.1-local-baseline-2026-08-25` 指向 tag object `595976fa537df5f18c2cd7abe83c14cfa6fbaac0`，其提交为 `47e0d15a3f3078e79bd653c3ec6f06488e4b4aa8`；`g1.1-complete-2026-08-25` 指向 tag object `33e302b65fccfe8a4020a3abf025a07438b4e988`，其提交为 `5b730ff195c017d976da6ad3844995b687a3a10f`。
- 当前 G1.2a workflow ref 为 `b0681d585cabe2f5f293779fc3627e2782be9fa2`；当前工作流由本地文件提供，不代表远端已安装或运行。
- 当前 checkout 与稳定 tag 的保护原则：回退优先使用可验证 ref 或隔离 archive；不使用 `git reset --hard`、force push、删除 audit ref/tag 或复用 Production 变量。

## 3. G1 Exit requirement-to-evidence 审计

状态枚举与 [Owner 验收清单](../../../stages/G1-Owner验收清单.md)一致：`已满足（本地）`、`预检完成/实施缺失`、`缺失`、`unknown`、`不适用`。本表的“已满足（本地）”只表示本地合同/本地等价证据成立。

| ID | G1 Exit 要求 | 状态 | 当前证据 | 缺口或边界 |
|---|---|---|---|---|
| G1-01 | Git root、`main`、初始 SHA、稳定 tag、当前 HEAD 可追溯 | 已满足（本地） | [G1.1 基线](../2026-08-25-g1-1-local-baseline/README.md)；本次 ref 核对 | 不等于远端发布 ref；Owner 签署前仍需复核 HEAD/tag |
| G1-02 | 非破坏性回退基线与隔离版本取回 | 已满足（本地） | [G1.3-0 archive 预检](../2026-08-26-g1-3-0-local-environment-preflight/README.md) | 未进行在线 Preview 回退 |
| G1-03 | Node `22.12.0`、Corepack `0.34.6`、pnpm `10.33.3` | 已满足（本地） | [G1.2a 等价验证](../2026-08-26-g1-2a-local-workflow/README.md) | 真实 CI/Preview runner 未复验 |
| G1-04 | lockfile frozen install 可复现 | 已满足（本地） | [G1.1 基线](../2026-08-25-g1-1-local-baseline/README.md)；[G1.2a 证据](../2026-08-26-g1-2a-local-workflow/README.md) | 远端 CI run 缺失；ignored build-script warning 保持记录 |
| G1-05 | 本地 typecheck/lint/build 通过 | 已满足（本地） | [G1.2a 等价验证](../2026-08-26-g1-2a-local-workflow/README.md) | 不等于远端 CI/Preview 构建通过 |
| G1-06 | 最小 workflow、失败停止、`contents: read`、action 完整 SHA | 已满足（本地） | [本地 workflow](../../../../.github/workflows/prototype-quality.yml)；[G1.2a 证据](../2026-08-26-g1-2a-local-workflow/README.md) | 远端设置和真实 run 未验证 |
| G1-07 | G1.2b 真实 GitHub Actions run | 缺失 | [G1.2b-0 目标审计](../2026-08-26-g1-2b-0-remote-target-audit/README.md) | 无有效认证/无 Owner 授权/无远端 run；不能写成通过 |
| G1-08 | canonical repo、无共同祖先历史策略、分支/PR 入口 | unknown | [G1.2b-0](../2026-08-26-g1-2b-0-remote-target-audit/README.md)；[G1.2b-1](../2026-08-26-g1-2b-1-local-integration-rehearsal/README.md) | `kyox215/REBUY_SHARE` 仍为候选；Owner 未确认历史策略 |
| G1-09 | Actions enabled、默认 workflow 权限、selected-actions | unknown | [G1.2b-0 权限审计](../2026-08-26-g1-2b-0-remote-target-audit/README.md) | 权限 GET 因 gh 认证无效为 401；不读取 secrets |
| G1-10 | Local 边界、`.gitignore`、`.env.example`、secret/log 规则 | 已满足（本地） | [G1.3-0 预检](../2026-08-26-g1-3-0-local-environment-preflight/README.md)；[11 连接边界](../../../11-发布与Supabase连接记录.md) | 只证明本地规则和变量名；不证明外部环境 |
| G1-11 | Preview 项目/owner/ref/Node/root/访问/变量/health/日志/停止入口 | 缺失 | [G1.3-0 四环境合同](../2026-08-26-g1-3-0-local-environment-preflight/README.md) | 未建立 provider/project；不得造 URL/project id |
| G1-12 | Staging 资源、账号、数据、Storage、变量、角色隔离 | 缺失 | [G1.3-0 四环境合同](../2026-08-26-g1-3-0-local-environment-preflight/README.md) | 未打开；不得与 Production 共用 |
| G1-13 | Production 资产盘点、专用 secret、访问、监控、备份、恢复 | unknown | [G1.3-0 四环境合同](../2026-08-26-g1-3-0-local-environment-preflight/README.md) | 本地未连接不等于外部不存在；需独立资产盘点和书面 Gate |
| G1-14 | Preview 实际部署来自 CI 通过的可追溯 ref | 缺失 | G1.3-0 只做 archive 预检 | 当前无 Preview 部署；不能把本地预览写成部署 |
| G1-15 | bad ref → good ref 在线 Preview 回退与恢复 | 缺失 | G1.3-0 回退手册；无在线证据 | 需隔离 Preview 和 Owner 授权后演练 |
| G1-16 | 脱敏证据、维护责任、回退/恢复记录 | 预检完成/实施缺失 | [G1.2b-1](../2026-08-26-g1-2b-1-local-integration-rehearsal/README.md)；[G1.3-0](../2026-08-26-g1-3-0-local-environment-preflight/README.md) | 真实 CI/Preview/Staging/Production 证据缺失 |
| G1-17 | Owner 明确 G1 Exit 决定并签署日期/ref | 缺失 | [G1 Owner 清单](../../../stages/G1-Owner验收清单.md) | 当前未签署，不生成虚假日期 |

## 4. 当前结论：NO-GO

G1.1、G1.2a 的本地项目底座、工具链、workflow 和等价命令证据已具备；G1.3-0 的本地隔离合同、忽略规则和 archive 取回预检已具备。但以下 Exit 必要项仍未满足：

- G1.2b 真实 GitHub Actions run 缺失；canonical repo、无共同祖先历史策略和 Actions permissions 仍未由 Owner/有效认证确认。
- Preview 尚未建立或部署；Staging/Production 资源、数据、Storage、secret、访问、日志、监控、备份和回退均无实施证据。
- bad ref → good ref 的在线 Preview 回退未演练；Owner 尚未对 G1 Exit 作出明确原话和签署日期/ref。

因此当前必须保持：`G1 执行中（G1.1 已完成，G1.2a 已完成，G1.2b 待 Owner Gate）；G1.3-0 preflight 已完成，G1.3 实施未开始；G1 Exit 未通过；G2-A0 不打开。`

`/api/health/supabase` 在未配置变量时预期返回 HTTP `503`（`configured: false`）；该响应只能证明未配置处理路径，不能作为 G1 Preview 成功 health。Preview 健康门应使用根页面和关键无外部依赖页面，并在授权环境记录访问、日志和停止入口。

## 5. 下一 Owner Gate 与执行顺序

### 5.1 G1.2b

1. 确认 canonical repository 与无共同祖先的历史策略。
2. 恢复 gh 登录后只读核验 repo/default branch/Actions permissions/workflow/run；不得读取 secrets。
3. 仅创建 integration 新分支和 PR，禁止 force push、删除远端分支或直推远端 `main`。
4. 仅在明确授权下运行一次真实 Actions，保存 job/ref/runner/退出结果的脱敏证据。

推荐授权语句：

> `批准进入G1.2b：在确认 canonical repository 与无共同祖先历史策略后，恢复 gh 只读认证；仅创建 integration 分支/PR（禁止 force push/直推 main），运行一次真实 GitHub Actions 并保存脱敏证据；暂不部署 Preview、接 Supabase/Auth/数据库或生产。`

### 5.2 G1.3

1. 单独确认 provider/project/owner/cost/access、停止入口和实时官方命令/URL。
2. 仅使用已通过 CI 的可追溯 ref 建立隔离 Preview，Root Directory 为 `prototype`，Node 22；G2-A1 前不得注入 Supabase/Auth/DB 值。
3. 验证根页面与关键无外部依赖页面 health、访问、日志脱敏和停止入口；未配置 Supabase 的 503 不算成功 health。
4. 在隔离 Preview 演练 bad ref → 已验证 good ref 在线回退，保存脱敏结果。
5. 记录恢复结果、ref、负责人和观察窗口，失败即停止晋级。

推荐授权语句：

> `批准进入G1.3：在 provider/project/owner/cost/access 书面确认后，仅使用已通过 CI 的可追溯 ref 建立隔离 Preview；Root Directory 为 prototype、Node 22、不得注入 Supabase/Auth/DB 值；完成根页和关键无外部依赖页面 health、bad ref→good ref 在线回退与脱敏证据；暂不接 Staging、Production 或真实 PII。`

## 6. 回退、维护与签署边界

- 触发构建/health/权限/日志/环境串线或 secret 风险时，立即停止晋级、push、部署和数据写入；保留时间、环境、ref、退出码和错误类别的脱敏摘要。
- 以 `git cat-file`、隔离 archive、Node/packageManager/lockfile/workflow 复验确认 bad/good ref；不使用 `git reset --hard`、force push、删除 audit tag/ref 或 Production 变量。
- 当前只可在隔离目录取回本地 good ref；未来 Preview 切换必须基于已通过 CI 的 ref，并复验 Node 22、frozen lockfile、CI、health、访问、数据/Storage、日志/PII 和回退入口。
- Owner 最终决定栏必须保留“待明确原话”；不得生成虚假日期、commit、部署 ref 或“G1 已通过”语句。
- 维护责任由 15 台账、G1 阶段合同和本清单共同约束：15 保存当前状态，阶段证据保存事实，Owner 清单保存验收要求；外部 provider/资源变化时先做只读盘点并追加证据。

## 7. 本批验证与跳过项

- 已只读核对当前 HEAD/branch/tags/remote、G1 输入文件和全部既有 G1 evidence 路径；Owner 清单与本证据文件作为本批新增记录。
- 本批不重跑 typecheck、lint、build、E2E：prototype、package/lockfile、workflow 和配置未变，复用 G1.2a 同状态证据。
- 不做 hash：无生成物或文件传输交付，已有 Git ref/tree/blob 证据足够。
- 不启动独立审查：本批为 Owner 清单与本地预检证据；主代理后续可按里程碑要求进行独立只读审查。

关联记录：[G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[15 台账](../../../15-项目状态与阶段台账.md)、[阶段索引](../../../stages/README.md)。
