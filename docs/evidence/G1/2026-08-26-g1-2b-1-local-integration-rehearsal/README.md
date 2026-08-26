# G1.2b-1 本地历史保全与发布前敏感审计演练

阶段：G1 工程底座与环境隔离
批次：G1.2b-1 本地历史保全 / integration rehearsal / 发布前敏感审计
状态：`本地演练已完成；G1.2b 仍待 Owner Gate`
证据级别：本地只读 Git 检查 + GitHub 公开仓库只读 clone + `/private/tmp` 临时 object store
记录日期：2026-08-26（Europe/Rome）
本地基线：`82e1090feeefb6717f8e972a0e889312f2167910`（`main`；演练开始时工作树 clean）
候选仓库：`kyox215/REBUY_SHARE`（仍是待 Owner 确认的候选，不是已授权 canonical repository）
远端候选基线：`366ad7f287a00f795c742d7f2df10a531fa42e7c`（`main`）
远端 CI / deploy / environment ref：`N/A`

> 本记录只证明临时 object store 中的历史保全构造、完整可达历史审计和静态 workflow 检查，不证明远端已接收任何提交、真实 CI 已运行、G1.2b 已通过或 G1 Exit 已通过。没有向 GitHub 或其他外部系统写入。

## 1. Owner 边界与本批目标

现有 Owner 授权只覆盖 G1.2a，不覆盖本批真实远端集成：

> `批准进入G1.2a：采用GitHub Actions候选，在本地创建只读最小CI工作流并做本地等价验证；暂不添加remote、不push、不运行远端CI、不部署Preview、不接Supabase或生产。`

本批在该边界内只执行本地/临时目录审计：

- 在 `/private/tmp` clone 候选公开仓库，并把当前本地 `main` fetch 到临时仓库的独立 ref；不向当前项目写入 remote 或远端跟踪 ref。
- 用远端 tip 作为 parent 1、本地 tip 作为 parent 2，使用当前本地 tree 构造一次临时 merge commit，验证未来可在独立 integration 分支/PR 中保全双方历史；该 SHA 不得未来复用。
- 对本地与候选远端两侧全部可达 commit/tree/blob 做路径、内容和 blob 大小审计；命中只输出 commit/path/category/count，不复制命中值。
- 验证候选 tree 中已有 workflow、触发器覆盖未来 PR 且只读权限约束仍在；不修改 workflow、不运行 CI。

## 2. 执行环境与历史保全演练

- 当前仓库核对：`git rev-parse HEAD` 为 `82e1090feeefb6717f8e972a0e889312f2167910`；分支为 `main`；`git status --short --branch` 为 clean；`git remote -v` 为空。
- 规则核对：已复用完整读取的 `prototype/AGENTS.md`；本批没有修改 `prototype/**`、`.github/workflows/prototype-quality.yml`、package/lockfile、Git 配置或产品源码。
- 临时 clone：`git clone --no-tags --origin audit-target https://github.com/kyox215/REBUY_SHARE.git <temporary>/remote`；这是公开只读 clone，临时目录已在本批结束时删除。
- 本地 fetch：在临时仓库执行 `git fetch --no-tags <local-repository> main:refs/audit/local-main`，没有向当前项目写入 ref。
- 两侧可达提交数：local `16`、remote `3`；`git merge-base` 无共同祖先，保留此前 G1.2b-0 的 `no_common_ancestor` 结论。

### 2.1 临时候选提交

在临时 object store 执行 `git commit-tree <local-tip^{tree}> -p <remote-tip> -p <local-tip>`，并使用仅用于演练的身份 `Rebuy Audit Rehearsal <audit-rehearsal@example.invalid>`。结果如下：

| 项目 | 结果 |
|---|---|
| 临时 rehearsal SHA | `134b7396758792806e0e9016c924c632cd4eedea` |
| parent 1（远端 `main`） | `366ad7f287a00f795c742d7f2df10a531fa42e7c` |
| parent 2（本地 `main`） | `82e1090feeefb6717f8e972a0e889312f2167910` |
| rehearsal tree | `c6e69cbeb2709e3c2a7d595ba8ce5595efa99d2f` |
| local tree | `c6e69cbeb2709e3c2a7d595ba8ce5595efa99d2f` |
| 远端 tip 是 rehearsal 祖先 | 是 |
| 本地 tip 是 rehearsal 祖先 | 是 |
| rehearsal tree 与本地 tree diff | 0 |

候选相对远端 `main` 的可复核差异为 `A=38`、`M=16`、`D=0`、`R=0`；新增内容包含本地 workflow 与本地工程/文档树。演练说明未来可以把该类历史保全提交放在独立 integration 分支上开 PR，而无需 force push 或覆盖远端 `main`；它不等于已获 push/PR 授权，也不要求未来采用本 SHA。

### 2.2 Workflow 静态核对

从 rehearsal tree 读取 `.github/workflows/prototype-quality.yml`，并与本地基线对应路径比较一致。静态断言通过：

- `pull_request` 与 `push`（目标 `main`）均存在，未来 PR 会覆盖 `pull_request` 触发器。
- 顶层权限仍为 `contents: read`；`ubuntu-24.04`、15 分钟 timeout、`prototype` working-directory 和 Node/Corepack/pnpm 固定策略均存在。
- checkout/setup-node 的完整 commit SHA、Corepack `0.34.6`、pnpm `10.33.3`、cache off 和 install → typecheck → lint → build 顺序存在。
- 未发现 `pull_request_target`、`workflow_run`、`workflow_dispatch`、`continue-on-error`、secrets/environment/artifact/deploy/Preview/Supabase/production 等越界模式。

## 3. 双方完整可达历史审计

扫描范围是各自 ref 的完整 `git rev-list` 可达历史，不只是当前 tip 文件树：local `refs/audit/local-main` 的 16 个 commit，以及 remote `refs/remotes/audit-target/main` 的 3 个 commit。每个 commit 的递归 tree 都被枚举；每个唯一 reachable blob 使用 `git cat-file -s` 建立大小清单并扫描内容。没有重新哈希普通源码。

### 3.1 路径风险

核对 `.env*`（仅 `.env.example` 允许）、`node_modules`、`.next`、`.pnpm-store`、`.vercel`、`.supabase`、`*.tsbuildinfo`、私钥/证书、数据库 dump、raw attachment 和明显临时文件。

| 历史侧 | 路径风险计数 | 结论 |
|---|---:|---|
| local（16 commits） | 0 | 未发现禁止路径；允许的 `.env.example` 不计入风险 |
| remote（3 commits） | 0 | 未发现禁止路径 |

### 3.2 内容风险与人工分类

扫描 GitHub token、Supabase/OpenAI key、JWT、private-key block，以及 password/secret/token/API-key 等赋值模式。审计输出只保留 commit/path/category/count：

| 历史侧 | commit/path | category | count | 人工分类 |
|---|---|---|---:|---|
| local | `82e1090feeefb6717f8e972a0e889312f2167910` / `prototype/app/api/health/supabase/route.ts` | `runtime_field_reference` | 1 | 运行时配置对象字段引用；不是字面 token、JWT、密码或 secret value |
| remote | `366ad7f287a00f795c742d7f2df10a531fa42e7c` / `prototype/app/api/health/supabase/route.ts` | `runtime_field_reference` | 1 | 运行时配置对象字段引用；不是字面 token、JWT、密码或 secret value |

该唯一匹配来自运行时配置字段用法，未发现真实 secret。没有复制、打印或写入任何命中值；因此没有触发“发现真实秘密后停止发布准备”的阻断规则。后续真实 push 前仍需在授权范围内重新审计，并将任何真实命中按 commit/path 报告后停止。

### 3.3 Blob 大小清单

阈值固定为 `20 MiB = 20,971,520 bytes`；清单覆盖双方各自全部可达唯一 blob：

| 历史侧 | commit 数 | unique blob 数 | 清单状态 | 超阈值数 | 最大 blob |
|---|---:|---:|---|---:|---|
| local | 16 | 147 | complete | 0 | `1,275,681 bytes`；`82e1090feeefb6717f8e972a0e889312f2167910` / `prototype/public/product-sprite.png` |
| remote | 3 | 51 | complete | 0 | `1,275,681 bytes`；`366ad7f287a00f795c742d7f2df10a531fa42e7c` / `prototype/public/product-sprite.png` |

最大 blob 低于 20 MiB；未发现需要大文件处置的对象。图片等二进制证据只做大小审计，不复制原始内容。

## 4. 结果矩阵与边界

| 检查 | 结果 | 证据摘要 |
|---|---|---|
| 临时公开 clone | 通过 | 候选 `main` 可 clone；临时 clone 已清理 |
| 双方历史关系 | 通过 | 无共同祖先；local `16` / remote `3` commits |
| 历史保全候选 | 通过（仅演练） | rehearsal `134b739...` 双 parent；两侧均为祖先；tree 与 local 一致 |
| 候选相对远端差异 | 可复核 | `A=38/M=16/D=0/R=0`；不执行 merge/force push |
| workflow 在候选 tree | 通过 | 路径存在、与本地一致，PR 触发器和只读权限静态满足 |
| local 完整历史路径审计 | 通过 | 16 commits / 147 blobs，path risk `0` |
| remote 完整历史路径审计 | 通过 | 3 commits / 51 blobs，path risk `0` |
| 内容风险 | 通过（人工分类） | 双方各 1 个 runtime field reference；未发现真实 secret value |
| blob 大小 | 通过 | 双方最大 1,275,681 bytes；20 MiB 超阈值均为 `0` |

## 5. 风险、回退与维护

### 5.1 风险

- `kyox215/REBUY_SHARE` 仍只是最可能候选，Owner 尚未书面确认 canonical repository；公开 clone 不代表 push 权限或授权。
- 本地与远端无共同祖先。临时双 parent 提交只证明可保全双方可达历史，不解决 Owner 对远端历史、分支和发布入口的决策。
- Actions permissions、默认 workflow 权限等仍需有效认证后的只读 GET 才能确认；此前 401 `unknown` 结论不因本地演练改变。
- 内容扫描是发布前审计证据，不代替 GitHub secret scanning、组织策略或 Owner 对真实环境变量的独立审批；重新 push 前需按新 tip 重跑。

### 5.2 回退

- 临时 clone、refs、object 和 rehearsal SHA 只存在于已清理的 `/private/tmp`，不得未来复用 `134b7396758792806e0e9016c924c632cd4eedea`。
- 本批当前仓库只新增/同步文档；若文档需要纠正，回退本批 docs commit 即可，不触碰 workflow、G1.1 refs/tags 或候选远端。
- 未来若 Owner 授权 integration 分支/PR，优先保留远端 `main`，在独立分支提交并审查；不使用 force push、删除远端分支或覆盖 `main` 作为回退手段。

### 5.3 维护

- 实际 push/PR 前重新核验候选 repo、默认分支、tip、Actions permissions、workflow/run，并重新扫描双方完整可达历史和 blob 大小。
- 若路径或内容审计出现真实 secret，立即停止发布准备，只记录 commit/path/category/count，按凭据撤销/轮换流程另行开高风险 Owner Gate；不得复制值。
- 若远端历史、仓库归属或分支策略漂移，先更新目标审计与 Owner 决策；不静默把本次 rehearsal 当作新基线。

## 6. 下一 Owner Gate

G1.2b 真实执行前，Owner 需要明确：

1. 是否确认 `kyox215/REBUY_SHARE` 为 canonical repository，或指定其他仓库。
2. 无共同祖先时采用保留远端历史、迁移到新仓库或重新建立共同基线中的哪一种。
3. 是否允许当前项目添加 remote；即使允许，也应先只读 fetch，不自动 push。
4. 是否允许创建独立 integration 分支并开 PR；是否允许向该分支 push；明确禁止 force push/覆盖远端 `main`。
5. 是否单独授权真实 GitHub Actions run；该授权不自动包含 Preview、Supabase、数据库、Auth 或生产。

推荐最小授权语句：`确认 canonical repository 与无共同祖先的历史策略；批准仅在独立 integration 分支进行一次只读复核和受审 PR，不覆盖远端 main；另行批准是否 push、是否运行真实 Actions；暂不连接 Preview、Supabase 或生产。`

当前 Gate：`G1.2b 待 Owner Gate；真实远端 CI 未运行；G1 Exit 未通过；G2-A0 不打开。`

关联记录：[G1.2b-0 远端目标审计](../2026-08-26-g1-2b-0-remote-target-audit/README.md)、[G1.2a 本地 workflow/等价证据](../2026-08-26-g1-2a-local-workflow/README.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[15 台账](../../../15-项目状态与阶段台账.md)。
