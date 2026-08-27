# G1 Owner 验收清单：工程底座与环境隔离

清单性质：稳定 Owner Gate checklist；不替代唯一当前状态源 [15 项目状态与阶段台账](../15-项目状态与阶段台账.md)
适用阶段：G1 工程底座与环境隔离
当前结论：`NO-GO / G1 Exit 未通过`
当前清单证据：本地静态、G1.2a 本地 workflow/等价验证、G1.3-0 本地预检、G1.3-1 provider/CLI/隔离预检、G1.3-2 高风险 Preview 执行独立审查与 2026-08-27 10:33:59 CEST Owner Gate 授权记录、G1.2b 真实 PR/Actions、PR #1 main merge 与远端只读设置核验；不包含 Preview 或在线回退证据
记录日期：2026-08-27（Europe/Rome）

> 本清单只提供 Owner 验收所需的 requirement-to-evidence 入口和签署栏。任何本地静态、Git archive、合成数据或规划证据都不能写成真实 GitHub Actions、Preview、Staging、Production 或 G1 Exit 通过。

## 1. 使用规则与当前边界

- 状态只使用：`已满足（本地）`、`已满足（远端）`、`已满足（远端只读）`、`预检完成/实施缺失`、`缺失`、`unknown`、`不适用`。
- “已满足（本地）”只表示对应本地合同或本地等价证据成立，不扩大为远端、外部环境或生产批准。
- 当前 Owner 已明确的 G1.2a 授权原话为：`批准进入G1.2a：采用GitHub Actions候选，在本地创建只读最小CI工作流并做本地等价验证；暂不添加remote、不push、不运行远端CI、不部署Preview、不接Supabase或生产。`
- 随后 Owner 已明确授权一次受限 G1.2b：允许将当前仓库公开上传至 `kyox215/REBUY_SHARE`、推送 `integration/g1-2b`、创建 PR、运行 Actions 并在通过后非强制合并；本次仍禁止 force-push、删除远端历史、Preview、Supabase/Auth/DB 和生产。另有 Workflow scope 仅限该仓库本次工作流。
- 当前 G1 状态必须以 15 为准：G1.1 已完成，G1.2a 已完成，G1.2b 真实 PR/CI 已完成并通过 PR #1 merge commit 合并 `main`；main push 的 install/typecheck/lint/build 已成功，`integration/g1-2b` 仍保留；G1.3-0 本地预检与 G1.3-1 provider/CLI/部署前隔离预检已完成，G1.3-2 高风险独立审查已完成（原方案 NO-GO，修正后条件 GO 候选），Owner 于 2026-08-27 10:33:59 CEST 已批准修正版 G1.3 受控范围，G1.3 implementation 已授权/执行中但尚无实际 Preview/PR/Actions/deploy 结果；G1 Exit 未通过，G2-A0 不打开。

## 2. G1 Exit requirement-to-evidence 矩阵

| ID | Exit 要求 | 状态 | 当前证据 | 仍需 Owner/实施确认 |
|---|---|---|---|---|
| G1-01 | Git root、`main`、初始 SHA、稳定 tag、当前 HEAD 可追溯 | 已满足（本地） | [G1.1 基线](../evidence/G1/2026-08-25-g1-1-local-baseline/README.md)；[G1.3-0 预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | 签署前重新核对当前 HEAD、tag 与工作树；不把本地 ref 写成远端发布 ref |
| G1-02 | 存在非破坏性回退基线，可在隔离目录取回 good ref | 已满足（本地） | [G1.3-0 预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | 真实 Preview 回退仍需独立 bad→good 在线演练 |
| G1-03 | Node `22.12.0`、Corepack `0.34.6`、pnpm `10.33.3` 固定 | 已满足（远端） | [G1.2a 本地 workflow/等价证据](../evidence/G1/2026-08-26-g1-2a-local-workflow/README.md)；[G1.2b 远端证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md) | GitHub runner 已验证 exact bootstrap；仅 Preview runner/部署环境仍缺 |
| G1-04 | `pnpm-lock.yaml` frozen install 可复现 | 已满足（远端） | [G1.1 基线](../evidence/G1/2026-08-25-g1-1-local-baseline/README.md)；[G1.2a 证据](../evidence/G1/2026-08-26-g1-2a-local-workflow/README.md)；[G1.2b 远端证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md) | GitHub runner 已验证 frozen install；仅 Preview runner/部署安装仍缺，ignored build-script warning 保持可追溯 |
| G1-05 | 本地 `typecheck`、`lint`、`build` 通过 | 已满足（远端） | [G1.2a 证据](../evidence/G1/2026-08-26-g1-2a-local-workflow/README.md)；[G1.2b 远端证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md) | GitHub runner 已验证三项命令；仅 Preview runner/部署构建仍缺 |
| G1-06 | 最小 workflow、失败停止、`contents: read`、action 完整 SHA 固定 | 已满足（远端） | `.github/workflows/prototype-quality.yml`；[G1.2a 证据](../evidence/G1/2026-08-26-g1-2a-local-workflow/README.md)；[G1.2b 远端证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md) | GitHub runner 已验证 workflow 静态边界与真实 PR check；仅 Preview runner/部署仍缺；仓库允许 actions all、SHA enforcement false 为治理风险 |
| G1-07 | G1.2b 真实 GitHub Actions run（install/typecheck/lint/build） | 已满足（远端） | [G1.2b 远端证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md)；初始 run `33027593355` / job `98372467897`；当前 head `cce03ac` run `33029927182` / job `98379847069`；merge head `cba97eb` main run `33031297793` / job `98384190584`；[main merge closeout](../evidence/G1/2026-08-27-g1-2b-main-merge/README.md) | PR head 与 merge 后 main 的 runner 检查均成功；不将 CI 或 merge 写成 G1 Exit 通过 |
| G1-08 | canonical repo、无共同祖先的历史策略、分支/PR 入口已确定 | 已满足（远端） | [G1.2b 远端证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md)；[main merge closeout](../evidence/G1/2026-08-27-g1-2b-main-merge/README.md)；PR #1 | `kyox215/REBUY_SHARE`、双 parent integration 策略与 merge commit 入口已确认；integration 分支仍保留；不能 direct push、force push 或改写远端 `main` |
| G1-09 | Actions enabled/default workflow permissions/selected-actions 已核验 | 已满足（远端只读） | [G1.2b 远端证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md) | enabled=true、default read、allowed all、SHA enforcement=false；selected-actions 在 all 策略下 409；不读取 secrets |
| G1-10 | Local 边界、`.gitignore`、`.env.example`、secret/log 规则 | 已满足（本地） | [G1.3-0 预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md)；[11 连接边界](../11-发布与Supabase连接记录.md) | 只记录变量名；真实环境值、日志和 provider 边界需后续 Owner Gate |
| G1-11 | Preview 项目/owner/ref/Node/root `prototype`/访问/变量/health/日志/停止入口 | 预检完成/实施缺失 | [G1.3-1 provider/Preview preflight](../evidence/G1/2026-08-27-g1-3-1-provider-preview-preflight/README.md)；[G1.3-2 execution review](../evidence/G1/2026-08-27-g1-3-2-preview-execution-review/README.md)；[G1.3-0 预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | provider/project/owner/access 已只读确认，G1.3 修正版 Owner Gate 已批准；`engines.node=22.x` 覆盖 project Node24，默认不 PATCH，build log 实证 Node22、cost、Preview、health、日志、停止入口仍待实施确认；project `rootDirectory` 保持未设置，执行 cwd 为 archive 的 `prototype/` |
| G1-12 | Staging 隔离边界合同（资源、secret、数据、Storage、角色和日志不得共用） | 已满足（本地） | [G1.3-0 四环境矩阵](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | G1 只验收边界合同；实际资源/账号/Auth/DB/RLS/PII 实施属于 G2-A1/P2 后续专项，不是 G1 Exit 前置 |
| G1-13 | Production 隔离边界合同（专用资源、secret、访问、监控、备份、恢复和回退不得与其他环境共用） | 已满足（本地） | [G1.3-0 四环境矩阵](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | G1 只验收边界合同；实际 Production 资产、监控、备份/恢复和 PII 实施属于 P7/Production 后续专项，不是 G1 Exit 前置 |
| G1-14 | Staging/Production 实际资源创建、Auth/DB/RLS/PII、监控、备份和恢复实施 | 不适用 | [G1.3-0 四环境矩阵](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | 标记为不适用（G1）；由 G2-A1/P2/P7/Production 专项另行授权和验收，不作为 G1 实施前置 |
| G1-15 | 外部 provider/资产认证只读盘点（选择 Preview provider 前） | 已满足（远端只读） | [G1.3-1 provider/Preview preflight](../evidence/G1/2026-08-27-g1-3-1-provider-preview-preflight/README.md) | Vercel team/project/旧 production deployment 与 Supabase 组织/项目已按最小事实只读确认；不得据此创建、连接、改 Node、改 alias 或推断后续资源不存在 |
| G1-16 | Preview 实际部署来自已通过 CI 的可追溯 ref | 缺失 | 当前无 Preview 部署；[G1.3-0 预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md)；[G1.3-2 execution review](../evidence/G1/2026-08-27-g1-3-2-preview-execution-review/README.md) | G1.2b 已完成，Owner Gate 已批准在受限范围内从精确 archive `main@af6d741` 的 `prototype/` cwd 建立隔离 Preview；project `rootDirectory` 不设置；必须以 build log 实证 Node22，不使用未通过 CI 的 ref |
| G1-17 | bad ref → good ref 的在线 Preview 回退与恢复结果 | 缺失 | [G1.3-2 execution review](../evidence/G1/2026-08-27-g1-3-2-preview-execution-review/README.md)；只有本地 archive/回退手册，无在线演练 | 在已批准范围内执行 `bad503` 独立 `DO NOT MERGE` Draft PR（永不 Ready/merge，关闭 PR 保留分支）→ `good200` 另从干净 main/最终集成分支普通 PR，并保存脱敏 health、访问、数据/Storage、日志结果 |
| G1-18 | 验证后脱敏证据、维护责任、回退/恢复记录可持续维护 | 预检完成/实施缺失 | [G1.2b 远端证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md)；[G1.2b main merge closeout](../evidence/G1/2026-08-27-g1-2b-main-merge/README.md)；[G1.3-0 回退手册](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md)；[G1.3-2 execution review](../evidence/G1/2026-08-27-g1-3-2-preview-execution-review/README.md) | PR/main 真实 CI 与脱敏证据已归档；Preview/在线回退仍缺；真实 secret 只记录 commit/path/category，不复制值；Staging/Production 由后续专项维护 |
| G1-19 | Owner 对 G1 Exit 作出明确原话并签署日期/ref | 缺失 | 当前没有 Owner Exit 签署 | 必须由 Owner 明确 NO-GO 或 GO；本清单不代签、不生成虚假日期 |

## 3. 当前结论与不得越级事项

当前结论固定为 `NO-GO / G1 Exit 未通过`。G1.2b 真实 PR/CI 已完成并通过 PR #1 merge commit 合并 main，merge 后 main push 的质量 workflow 也已成功；G1.3-1 provider/CLI 只读盘点与本地隔离预检、G1.3-2 高风险独立审查已完成，Owner 于 2026-08-27 10:33:59 CEST 批准修正版 G1.3 受控范围，G1.3 implementation 已授权/执行中，但 Preview 实际部署、在线回退和 Owner G1 Exit 签署仍缺失。G1.3-2 原方案为 `NO-GO`，修正后仅为条件 `GO` 候选：`engines.node=22.x` 覆盖 project Node24，默认不 PATCH，必须以 build log 实证 Node22；project `rootDirectory` 保持未设置，变量存在即停止，Deployment Protection 不关闭并用 `vercel curl`；bad503 Draft PR 永不 Ready/merge，good200 及后续永久 good route 另走独立普通 PR。该批准仅覆盖 Vercel OAuth 临时认证、指定的两个 `codex/*` 分支/PR/Actions、最多三个 Target=Preview（bad503/good200/final）、Pro 正常 build/compute 与受限取消构建中 Preview；不得扩展至新付费资源、Supabase project/cost、secret/env 值、Auth/DB/PII、支付、Staging/Production 或真实业务数据。Staging/Production 实际资源与高风险能力属于后续 G2-A1/P2/P7/Production 专项，不是 G1 Exit 前置。

在 G1 Exit 明确通过前：

- 不打开 G2-A0、G2-A1 或 P2，不把本地 prototype 身份样本当作 Auth/权限实现。
- 不从本地未绑定事实推断外部 GitHub、Vercel、Supabase、数据库、Storage 或 Production 资源不存在。
- G1.2b 的一次性 integration/PR/Actions 授权已执行并留存证据；独立复审 GO 后 PR #1 已以 merge commit 合并 `main`，不得据此扩展为 Preview、Supabase/Auth/数据库或生产变量授权。当前仍禁止直接 push main、force-push、删除远端历史或改写历史；`integration/g1-2b` 继续保留。
- `/api/health/supabase` 在未配置变量时预期为 HTTP `503`（`configured: false`），不能把该未配置响应当作 G1 Preview 成功 health；Preview 健康门应先验证根页面和关键无外部依赖页面。

## 4. G1.2b 执行记录与 G1.3 下一门

### 4.1 已执行的受限 G1.2b 流程（合并前执行期快照）

> 本节第 1–4 项保留 PR #1 合并前的授权边界和执行事实；当前 merge 状态以第 6 节及 [15 台账](../15-项目状态与阶段台账.md) 为准。

1. 确认 canonical repo 为 `kyox215/REBUY_SHARE`，并书面采用保留远端 `main` 与本地 `main` 双方历史的 `integration` 分支/PR 策略。
2. 允许通过浏览器恢复 gh 登录；先只读核对 repo、默认分支、Actions permissions、workflow/run，不读取 secrets。
3. 上述核验通过后，允许在当前本地仓库添加该 canonical remote、只读 fetch、构造并 push **一个新的** `integration/g1-2b` 分支、创建 **一个** PR，并让该 PR 触发 **一次**真实 GitHub Actions。
4. 旧授权边界禁止直接 push main、force-push、删除/覆盖远端分支或改写历史；最新 Owner override 仅允许在独立复审明确 GO 后进行非强制 PR merge，当前 PR 仍未合并；暂不部署 Preview、连接 Supabase/Auth/DB 或 Production。

历史推荐 G1.2b Owner 授权语句（执行前，保留原文）：

> `确认 canonical repo 为 kyox215/REBUY_SHARE，并采用保留远端 main 与本地 main 双方历史的 integration 分支/PR 策略；允许通过浏览器恢复 gh 登录，先只读核验 repo/default branch/Actions permissions/workflows/runs，不读取 secrets；核验通过后，允许在当前本地仓库添加该 canonical remote、只读 fetch、构造并 push 一个新的 integration/g1-2b 分支、创建一个 PR，并让该 PR 触发一次真实 GitHub Actions；禁止直接 push 或 merge main、force-push、删除/覆盖远端分支、改写历史；暂不部署 Preview、连接 Supabase/Auth/DB 或 Production。`

Owner 已明确采纳上述边界并完成一次受限流程；随后另行授权在独立复审明确 GO 后以非强制方式合并 PR，当前不允许直接 push main、force-push、删除远端历史或改写历史。初始 PR/Actions 事实、权限只读结果和审计数字见[2026-08-27 G1.2b 远端证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md)。当前 head `cce03ac` 的 check `33029927182` / job `98379847069` 已成功；不递归改写初始 run 记录。

### 4.2 G1.3 完成顺序

1. 单独确认 provider、project、owner、cost、访问角色和停止入口；provider 命令/URL 以授权时的实时官方文档为准。
2. 只允许已通过 CI 的可追溯 ref 建立 Preview；project `rootDirectory` 保持未设置，从精确 archive 的 `prototype/` cwd 执行，Node 22 必须由 build log 实证；G2-A1 前不得注入 Auth/DB 值或生产变量。
3. Preview 前只核对变量名与 target，不读取值；任一应用变量存在即停止；不关闭 Deployment Protection，使用 `vercel curl` 验证根页面和关键无外部依赖页面；未配置 Supabase 的 `/api/health/supabase` 返回 503 是预期缺失配置，不是 Preview 成功 health。
4. 在明确授权的隔离 Preview 中演练 `bad503` → `good200`：bad 使用独立 `DO NOT MERGE` Draft PR，永不 Ready/merge，关闭 PR 但保留分支；good200 及后续永久 good route 另从干净 main/最终集成分支进入独立普通 PR，保存脱敏构建/health/访问/数据/Storage/日志结果。
5. 部署前后只读核对旧 production deployment 与 aliases fingerprint 不变；记录恢复结果、bad/good ref、负责人、观察窗口和未覆盖项；失败即停止晋级并回退到维护手册。

推荐 G1.3 Owner 授权语句（G1.3-2 修正版；Owner Gate 批准前候选原文，实际批准记录见第 10 节）：

> `批准进入G1.3-2 Preview执行：确认 Vercel team/project 与 Pro 用量；project Node24.x 默认不 PATCH，依据 package.json engines.node=22.x 请求 Node22，并以新的 build log 实证实际 Node22；仅从已通过 CI 的精确 archive main@af6d7419956ce6640c0b4af5df4db0369e793f77 的 prototype/执行 link/deploy，project rootDirectory 保持未设置，Target=Preview；Preview前只核对变量名与target、不读取值，任一应用变量存在即停止；不关闭 Deployment Protection，使用 vercel curl；部署前后核对旧 production deployment dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH 与 aliases fingerprint 不变；bad503 使用 DO NOT MERGE Draft PR，永不Ready/merge，关闭PR但保留分支，good200 及后续永久 good route 另从干净 main/最终集成分支进入独立普通PR；不得改变 Production alias，不注入 Supabase/Auth/DB/PII 或任何环境值，不接 Staging、Production 或真实业务数据。`

## 5. Owner Exit 决定栏

| 项目 | Owner 填写 |
|---|---|
| G1 Exit 决定 | 待明确原话（当前 NO-GO） |
| 决定日期（Europe/Rome） | N/A；不得凭空填写 |
| 采用的 canonical repo / 历史策略 | `kyox215/REBUY_SHARE`；远端 `main` 与本地 `main` 双 parent 的 `integration/g1-2b` PR 策略 |
| G1.2b 真实 CI run ref/job | 初始 head `f746dcacc0afc2d45b847346f20078a159c2e032`：run `33027593355` / job `98372467897`（SUCCESS）；docs head `cce03acfdf7eb4da5ce1f8bb7b559d8705332b0e`：run `33029927182` / job `98379847069`（SUCCESS）；merge head `cba97eb4e7c93e5c42ba496e4d2ddeac5b476c7c`：main run `33031297793` / job `98384190584`（SUCCESS） |
| Preview / online rollback ref | N/A（当前缺失） |
| Owner 签名或可追溯批准消息 | G1 Exit 待明确；G1.3 修正版 Owner Gate 已于 2026-08-27 10:33:59 CEST 批准，见第 10 节 |
| 通过后可打开的下一门 | 仅在 Owner 明确 G1 Exit 通过后，按顺序准备 G2-A0；当前不打开 |

## 6. 2026-08-27｜G1.2b 真实 PR/CI 记录同步（合并前历史快照）

- 初始 remote/PR/Actions 已按 Owner 授权执行：canonical repo 为 `kyox215/REBUY_SHARE`，PR #1 保持 OPEN/CLEAN，远端 `main` 未漂移，初始 integration head `f746dca...` 的 run `33027593355` / job `98372467897` SUCCESS。
- 远端只读设置为 Actions enabled、default workflow permissions `read`、allowed actions `all`、SHA enforcement `false`；仓库级 all/未强制 SHA 风险已记录，workflow 自身仍使用完整 action SHA 与 `contents: read`。
- 当前本批只同步 docs/evidence；当前 head check 已独立确认成功，但不回写本证据的初始 run ID。非强制 PR merge 仍待独立复审明确 GO；G1.3 尚未开始，G1 Exit 仍 NO-GO，G2-A0 不打开。

关联记录：[G1 阶段合同](./G1-工程底座与环境隔离.md)、[G1 Exit preflight](../evidence/G1/2026-08-26-g1-exit-preflight/README.md)、[G1.2b 远端证据](../evidence/G1/2026-08-27-g1-2b-remote-ci/README.md)、[15 台账](../15-项目状态与阶段台账.md)、[阶段索引](./README.md)。

## 7. 2026-08-27｜G1.2b main merge closeout

- 独立 merge reviewer 已对 PR #1 head `0bb5fb527d51a304b95b05794345bd23128e1534` 正式给出 GO；随后仅通过 GitHub PR 以 merge commit 合并，未 direct push main、squash、rebase 或 force-push。
- PR #1 已 `MERGED`，merge commit 为 `cba97eb4e7c93e5c42ba496e4d2ddeac5b476c7c`，parents 为远端 main `366ad7f...` 与 integration head `0bb5fb5...`；`integration/g1-2b` 仍保留、未删除。
- merge 后 main push 的 [Actions run 33031297793](https://github.com/kyox215/REBUY_SHARE/actions/runs/33031297793) / [job 98384190584](https://github.com/kyox215/REBUY_SHARE/actions/runs/33031297793/job/98384190584) 已 SUCCESS，install、typecheck、lint、build 和收尾步骤全部通过；完整 closeout 见[G1.2b main merge evidence](../evidence/G1/2026-08-27-g1-2b-main-merge/README.md)。
- 当前仍为 `G1 Exit NO-GO`：G1.3-0 仅本地预检，G1.3 实施、Preview、在线回退与 Owner Exit 签署仍缺失；G2-A0 不打开。Actions `allowed_actions=all`、SHA enforcement=`false` 的治理债务继续保留，后续另行治理。

## 8. 2026-08-27｜G1.3-1 provider/CLI/部署前隔离预检同步

- G1.3-1 已完成 Vercel 与 Supabase 的最小认证只读盘点：Vercel team/project、旧 READY production deployment、Node `24.x` 与无 Git link 已记录；Supabase 仅确认组织下的无关项目，无 Rebuy 项目；未读取或记录 host、key、token、cookie、secret、环境值或 PII。
- `main@af6d7419956ce6640c0b4af5df4db0369e793f77` 的归档副本在 Node `22.12.0`、Corepack `0.34.6`、pnpm `10.33.3` 下完成 frozen install、typecheck、lint、build，均退出 0；临时目录已清理，仅保留 `unrs-resolver` ignored build-script warning。main Actions run/job `33034314565/98393579170` 已 SUCCESS。
- Vercel CLI `53.1.1` 的 `deploy/link/inspect --help` 语法已核对；`whoami` 无可确认身份输出；未执行 login、link、deploy、inspect、promote、rollback 或项目设置修改，也未写 `.vercel`。
- 当前结论（G1.3-2 审查前快照）仍为 `G1 Exit NO-GO`：G1.3 实施等待 Owner Gate，需先决定 project Node `24.x → 22.x` 候选变更、Pro build/compute 用量、访问/停止入口，再仅以 `main@af6d741`、Root `prototype`、Target Preview 建立隔离 Preview；不得改变 Production alias、注入 Supabase/Auth/DB/PII 或打开 Staging/Production。在线 bad ref → good ref 仍未执行。随后 G1.3-2 已将 Node 结论纠正为默认不 PATCH project Node，由 `engines.node=22.x` 请求 Node22 并以 build log 实证；当前执行仍待 Owner Gate。

关联证据：[G1.3-1 provider/Preview preflight](../evidence/G1/2026-08-27-g1-3-1-provider-preview-preflight/README.md)。

## 9. 2026-08-27｜G1.3-2 Preview 执行高风险独立审查

- 审查性质：独立 reviewer 针对 Preview 部署、Node 版本、project `rootDirectory`、变量存在性、Deployment Protection、Production aliases 和在线回退进行高风险审查；原执行草案结论为 `NO-GO`，按修正合同后为条件 `GO` 候选，未执行任何外部动作。
- 修正后的强制边界：`package.json` `engines.node=22.x` 覆盖 project Node24，默认不 PATCH，必须以 build log 实证 Node22；从精确 archive SHA 的 `prototype/` cwd 执行，project `rootDirectory` 保持未设置；Preview 前只列变量名/target，任一应用变量存在即停止；不关闭 Deployment Protection，使用 `vercel curl`；旧 production deployment/aliases fingerprint 前后必须不变。
- 回退演练边界：`bad503` 仅用独立 `DO NOT MERGE` Draft PR，永不 Ready/merge，关闭 PR 但保留分支；`good200` 及后续永久 good route 另从干净 main/最终集成分支进入独立普通 PR。该审查快照当时仍无外部授权、未登录、未 push、未创建 PR、未 deploy；G1 Exit 保持 `NO-GO`。

完整记录见 [G1.3-2 Preview execution review](../evidence/G1/2026-08-27-g1-3-2-preview-execution-review/README.md)。

## 10. 2026-08-27 10:33:59 CEST｜G1.3 修正版 Owner Gate 已批准

- Owner 原话：`我批准 ，下次无需我批准`。该回复语义明确承接主线程上一条完整 G1.3 修正版授权语句，批准的是受限 G1.3 implementation 范围，不是 G1 Exit 签署，也不把条件 GO 候选写成已完成。
- 授权范围：允许 Vercel OAuth 临时认证；仅限上一条完整授权语句指定的两个 `codex/*` 分支/PR/Actions 入口（本记录不臆补名称或编号）；最多三个 `Target=Preview`，角色仅为 `bad503`、`good200`、`final`；允许 Vercel Pro 正常 build/compute 用量；在该范围内风险触发时可受限取消构建中的 Preview。OAuth/login 是否发生、分支/PR/Actions 是否创建及 Preview 是否部署，均须由后续证据确认。
- 原修正合同保持不变：`engines.node=22.x` 覆盖 project Node24，Node 默认不 PATCH，必须由 build log 实证 Node22；project `rootDirectory` 保持未设置，从精确 archive 的 `prototype/` cwd 执行；Preview 前只列变量名/target，任一应用变量存在即停止；不关闭 Deployment Protection，使用 `vercel curl`；旧 production deployment `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` 与 aliases fingerprint 前后必须不变；bad503 使用永不 Ready/merge 的 `DO NOT MERGE` Draft PR，关闭 PR 但保留分支，good200 与后续永久 good route 另用独立干净普通 PR。
- `下次无需我批准` 仅表示上述已批准范围内的常规可回退步骤和必要重试不重复询问；不得扩展到未来新付费资源、Supabase project/cost、任何 secret/env 值、Auth/DB/PII、支付、Staging/Production、真实业务数据、Production alias/promote/rollback、项目删除或其他 team/project 设置。
- 当前状态：G1.3 implementation 从“待 Owner Gate”更新为“已授权/执行中”；本批仍未执行或不伪造任何 login、push、PR、Actions、Preview、deploy 结果，G1 Exit 保持 `NO-GO`，G2-A0 不打开。
