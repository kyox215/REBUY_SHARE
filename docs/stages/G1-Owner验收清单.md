# G1 Owner 验收清单：工程底座与环境隔离

清单性质：稳定 Owner Gate checklist；不替代唯一当前状态源 [15 项目状态与阶段台账](../15-项目状态与阶段台账.md)
适用阶段：G1 工程底座与环境隔离
当前结论：`NO-GO / G1 Exit 未通过`
当前清单证据：本地静态、G1.2a 本地 workflow/等价验证、G1.3-0 本地预检；不包含真实远端 CI、Preview 或在线回退证据
记录日期：2026-08-26（Europe/Rome）

> 本清单只提供 Owner 验收所需的 requirement-to-evidence 入口和签署栏。任何本地静态、Git archive、合成数据或规划证据都不能写成真实 GitHub Actions、Preview、Staging、Production 或 G1 Exit 通过。

## 1. 使用规则与当前边界

- 状态只使用：`已满足（本地）`、`预检完成/实施缺失`、`缺失`、`unknown`、`不适用`。
- “已满足（本地）”只表示对应本地合同或本地等价证据成立，不扩大为远端、外部环境或生产批准。
- 当前 Owner 已明确的 G1.2a 授权原话为：`批准进入G1.2a：采用GitHub Actions候选，在本地创建只读最小CI工作流并做本地等价验证；暂不添加remote、不push、不运行远端CI、不部署Preview、不接Supabase或生产。`
- 上述授权当前不包含 G1.2b、G1.3、remote、push、PR、真实 Actions run、Preview、Supabase/Auth、数据库或生产。用户此前“设置目标并根据规划完成全部目标”的一般要求，也不能自动解除当前边界；第 4.1 节的精确授权语句只有在 Owner 明确采纳后，才会对一次受限 G1.2b integration/PR/Actions 流程解除相应 remote/push 禁止。
- 当前 G1 状态必须以 15 为准：G1.1 已完成，G1.2a 已完成，G1.2b 待 Owner Gate；G1.3-0 仅为本地预检，G1.3 实施未开始；G1 Exit 未通过，G2-A0 不打开。

## 2. G1 Exit requirement-to-evidence 矩阵

| ID | Exit 要求 | 状态 | 当前证据 | 仍需 Owner/实施确认 |
|---|---|---|---|---|
| G1-01 | Git root、`main`、初始 SHA、稳定 tag、当前 HEAD 可追溯 | 已满足（本地） | [G1.1 基线](../evidence/G1/2026-08-25-g1-1-local-baseline/README.md)；[G1.3-0 预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | 签署前重新核对当前 HEAD、tag 与工作树；不把本地 ref 写成远端发布 ref |
| G1-02 | 存在非破坏性回退基线，可在隔离目录取回 good ref | 已满足（本地） | [G1.3-0 预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | 真实 Preview 回退仍需独立 bad→good 在线演练 |
| G1-03 | Node `22.12.0`、Corepack `0.34.6`、pnpm `10.33.3` 固定 | 已满足（本地） | [G1.2a 本地 workflow/等价证据](../evidence/G1/2026-08-26-g1-2a-local-workflow/README.md) | 真实 CI/Preview runner 仍需复验 exact bootstrap |
| G1-04 | `pnpm-lock.yaml` frozen install 可复现 | 已满足（本地） | [G1.1 基线](../evidence/G1/2026-08-25-g1-1-local-baseline/README.md)；[G1.2a 证据](../evidence/G1/2026-08-26-g1-2a-local-workflow/README.md) | 远端 CI run 尚缺；忽略 build-script warning 的供应链决策需保持可追溯 |
| G1-05 | 本地 `typecheck`、`lint`、`build` 通过 | 已满足（本地） | [G1.2a 证据](../evidence/G1/2026-08-26-g1-2a-local-workflow/README.md) | 不等于远端 CI 或 Preview 构建通过 |
| G1-06 | 最小 workflow、失败停止、`contents: read`、action 完整 SHA 固定 | 已满足（本地） | `.github/workflows/prototype-quality.yml`；[G1.2a 证据](../evidence/G1/2026-08-26-g1-2a-local-workflow/README.md) | 真实 Actions run 与权限设置仍缺失/unknown |
| G1-07 | G1.2b 真实 GitHub Actions run（install/typecheck/lint/build） | 缺失 | [G1.2b-0 目标审计](../evidence/G1/2026-08-26-g1-2b-0-remote-target-audit/README.md)仅证明公开元数据未发现 run | 需 Owner 单独授权、执行并保存 job/ref/runner/退出结果的脱敏证据 |
| G1-08 | canonical repo、无共同祖先的历史策略、分支/PR 入口已确定 | unknown | 候选 `kyox215/REBUY_SHARE` 只读审计；[G1.2b-1 演练](../evidence/G1/2026-08-26-g1-2b-1-local-integration-rehearsal/README.md) | Owner 必须书面确认仓库与历史策略；不能直接覆盖或 force push 远端 `main` |
| G1-09 | Actions enabled/default workflow permissions/selected-actions 已核验 | unknown | 权限 GET 曾因认证无效返回 401；[G1.2b-0 目标审计](../evidence/G1/2026-08-26-g1-2b-0-remote-target-audit/README.md) | 恢复 gh 登录后只读 GET；不读取 secrets |
| G1-10 | Local 边界、`.gitignore`、`.env.example`、secret/log 规则 | 已满足（本地） | [G1.3-0 预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md)；[11 连接边界](../11-发布与Supabase连接记录.md) | 只记录变量名；真实环境值、日志和 provider 边界需后续 Owner Gate |
| G1-11 | Preview 项目/owner/ref/Node/root `prototype`/访问/变量/health/日志/停止入口 | 缺失 | [G1.3-0 预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md)仅有目标合同 | 必须先确认 provider/project/owner/cost/access，再部署；当前不得造 URL/project id |
| G1-12 | Staging 隔离边界合同（资源、secret、数据、Storage、角色和日志不得共用） | 已满足（本地） | [G1.3-0 四环境矩阵](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | G1 只验收边界合同；实际资源/账号/Auth/DB/RLS/PII 实施属于 G2-A1/P2 后续专项，不是 G1 Exit 前置 |
| G1-13 | Production 隔离边界合同（专用资源、secret、访问、监控、备份、恢复和回退不得与其他环境共用） | 已满足（本地） | [G1.3-0 四环境矩阵](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | G1 只验收边界合同；实际 Production 资产、监控、备份/恢复和 PII 实施属于 P7/Production 后续专项，不是 G1 Exit 前置 |
| G1-14 | Staging/Production 实际资源创建、Auth/DB/RLS/PII、监控、备份和恢复实施 | 不适用 | [G1.3-0 四环境矩阵](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | 标记为不适用（G1）；由 G2-A1/P2/P7/Production 专项另行授权和验收，不作为 G1 实施前置 |
| G1-15 | 外部 provider/资产认证只读盘点（选择 Preview provider 前） | unknown | G1.3-0 仅记录本地未绑定事实，无认证外部资产清单 | 这是未来选择 Preview provider 的安全前置；不得据此创建、连接或推断外部资源不存在 |
| G1-16 | Preview 实际部署来自已通过 CI 的可追溯 ref | 缺失 | 当前无 Preview 部署；[G1.3-0 预检](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | 需先完成 G1.2b，再建立隔离 Preview；不使用未通过 CI 的 ref |
| G1-17 | bad ref → good ref 的在线 Preview 回退与恢复结果 | 缺失 | 只有本地 archive/回退手册，无在线演练 | 需 Owner 授权后执行并保存脱敏 health、访问、数据/Storage、日志结果 |
| G1-18 | 验证后脱敏证据、维护责任、回退/恢复记录可持续维护 | 预检完成/实施缺失 | [G1.2b-1 审计](../evidence/G1/2026-08-26-g1-2b-1-local-integration-rehearsal/README.md)；[G1.3-0 回退手册](../evidence/G1/2026-08-26-g1-3-0-local-environment-preflight/README.md) | 真实 CI/Preview 证据尚缺；真实 secret 只记录 commit/path/category，不复制值；Staging/Production 由后续专项维护 |
| G1-19 | Owner 对 G1 Exit 作出明确原话并签署日期/ref | 缺失 | 当前没有 Owner Exit 签署 | 必须由 Owner 明确 NO-GO 或 GO；本清单不代签、不生成虚假日期 |

## 3. 当前结论与不得越级事项

当前结论固定为 `NO-GO / G1 Exit 未通过`。本地已满足的 G1.1/G1.2a、G1.3-0 环境边界合同不能抵消 G1.2b、Preview 实际部署、在线回退和 Owner 签署缺口。Staging/Production 实际资源与高风险能力属于后续 G2-A1/P2/P7/Production 专项，不是 G1 Exit 前置。

在 G1 Exit 明确通过前：

- 不打开 G2-A0、G2-A1 或 P2，不把本地 prototype 身份样本当作 Auth/权限实现。
- 不从本地未绑定事实推断外部 GitHub、Vercel、Supabase、数据库、Storage 或 Production 资源不存在。
- 在新的 G1.2b Owner 精确授权生效且只读核验通过前，不添加 remote、push、创建 PR、触发真实 Actions、部署 Preview、连接 Supabase/Auth/数据库或读取/注入生产变量；后续授权也只允许 §4.1 明确的一次 integration/PR/Actions 流程。
- `/api/health/supabase` 在未配置变量时预期为 HTTP `503`（`configured: false`），不能把该未配置响应当作 G1 Preview 成功 health；Preview 健康门应先验证根页面和关键无外部依赖页面。

## 4. G1.2b 完成顺序与推荐授权

### 4.1 前置顺序

1. 确认 canonical repo 为 `kyox215/REBUY_SHARE`，并书面采用保留远端 `main` 与本地 `main` 双方历史的 `integration` 分支/PR 策略。
2. 允许通过浏览器恢复 gh 登录；先只读核对 repo、默认分支、Actions permissions、workflow/run，不读取 secrets。
3. 上述核验通过后，允许在当前本地仓库添加该 canonical remote、只读 fetch、构造并 push **一个新的** `integration/g1-2b` 分支、创建 **一个** PR，并让该 PR 触发 **一次**真实 GitHub Actions。
4. 禁止直接 push 或 merge `main`、force-push、删除/覆盖远端分支或改写历史；暂不部署 Preview、连接 Supabase/Auth/DB 或 Production。

推荐 G1.2b Owner 授权语句：

> `确认 canonical repo 为 kyox215/REBUY_SHARE，并采用保留远端 main 与本地 main 双方历史的 integration 分支/PR 策略；允许通过浏览器恢复 gh 登录，先只读核验 repo/default branch/Actions permissions/workflows/runs，不读取 secrets；核验通过后，允许在当前本地仓库添加该 canonical remote、只读 fetch、构造并 push 一个新的 integration/g1-2b 分支、创建一个 PR，并让该 PR 触发一次真实 GitHub Actions；禁止直接 push 或 merge main、force-push、删除/覆盖远端分支、改写历史；暂不部署 Preview、连接 Supabase/Auth/DB 或 Production。`

该语句只有在 Owner 明确采纳后才生效；当前 G1.2b 仍待 Owner Gate，不能把本清单的推荐语句视为已授权执行。

### 4.2 G1.3 完成顺序

1. 单独确认 provider、project、owner、cost、访问角色和停止入口；provider 命令/URL 以授权时的实时官方文档为准。
2. 只允许已通过 CI 的可追溯 ref 建立 Preview；Root Directory 固定 `prototype/`，Node 22；G2-A1 前不得注入 Auth/DB 值或生产变量。
3. 先验证根页面和关键无外部依赖页面 health、访问边界、日志脱敏与停止入口；未配置 Supabase 的 `/api/health/supabase` 返回 503 是预期缺失配置，不是 Preview 成功 health。
4. 在明确授权的隔离 Preview 中演练 bad ref → 已验证 good ref 的在线回退，保存脱敏构建/health/访问/数据/Storage/日志结果。
5. 记录恢复结果、bad/good ref、负责人、观察窗口和未覆盖项；失败即停止晋级并回退到维护手册。

推荐 G1.3 Owner 授权语句：

> `批准进入G1.3：在 provider/project/owner/cost/access 书面确认后，仅使用已通过 CI 的可追溯 ref 建立隔离 Preview；Root Directory 为 prototype、Node 22、不得注入 Supabase/Auth/DB 值；完成根页和关键无外部依赖页面 health、bad ref→good ref 在线回退与脱敏证据；暂不接 Staging、Production 或真实 PII。`

## 5. Owner Exit 决定栏

| 项目 | Owner 填写 |
|---|---|
| G1 Exit 决定 | 待明确原话（当前 NO-GO） |
| 决定日期（Europe/Rome） | N/A；不得凭空填写 |
| 采用的 canonical repo / 历史策略 | 待明确 |
| G1.2b 真实 CI run ref/job | N/A（当前缺失） |
| Preview / online rollback ref | N/A（当前缺失） |
| Owner 签名或可追溯批准消息 | 待明确 |
| 通过后可打开的下一门 | 仅在 Owner 明确 G1 Exit 通过后，按顺序准备 G2-A0；当前不打开 |

关联记录：[G1 阶段合同](./G1-工程底座与环境隔离.md)、[G1 Exit preflight](../evidence/G1/2026-08-26-g1-exit-preflight/README.md)、[15 台账](../15-项目状态与阶段台账.md)、[阶段索引](./README.md)。
