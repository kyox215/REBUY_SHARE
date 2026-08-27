# G1.2b-0 远端目标只读审计

阶段：G1 工程底座与环境隔离
批次：G1.2b-0 远端目标仓库、Actions 元数据与历史关系只读审计
状态：`G1.2b-0 只读审计已完成；G1.2b 仍待 Owner Gate`
证据级别：本地静态 + 远端公开元数据只读 + 临时仓库历史/文件树比较
记录日期：2026-08-26（Europe/Rome）
本地代码 ref：`099439c460584a9fda3bb7b216639181786b3fa9`（审计开始时 HEAD；当前本地仓库未写入 remote）
远端候选 tip：`366ad7f287a00f795c742d7f2df10a531fa42e7c`（`kyox215/REBUY_SHARE` `main`）
远端 CI / deploy / environment ref：`N/A`

> 本记录只证明公开/只读元数据和临时比较结果，不证明远端 CI 已运行、Actions 已启用、仓库已获 Owner 选定、G1.2b 已通过或 G1 Exit 已通过。审计期间没有添加 remote、push、创建分支/PR/tag/release、触发 Actions、读取 secrets、部署 Preview、连接 Supabase/数据库/Auth/生产。

## 1. Owner 边界与审计目标

现有 Owner 授权原话仍是 G1.2a 范围，不是 G1.2b 授权：

> `批准进入G1.2a：采用GitHub Actions候选，在本地创建只读最小CI工作流并做本地等价验证；暂不添加remote、不push、不运行远端CI、不部署Preview、不接Supabase或生产。`

本批在该边界内只做目标审计：

- 读取当前 `gh` 登录账户的登录名和认证可用性，不记录 token、secret 或 scope 细节。
- 从账户公开仓库列表发现候选，并核验候选仓库的归属、可见性、默认分支、URL、归档/禁用状态。
- 只读检查 Actions 权限端点、公开 workflow/run 列表；权限端点若因认证不足不可读，记录 `unknown`，不推断启用或禁用。
- 读取默认分支 tip，并在临时目录比较远端与本地 `main` 的提交关系和文件树；不把结果用于自动合并或覆盖。

## 2. 执行环境与命令摘要

- 本地仓库：`/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划`；shell：zsh；审计开始时 `git status --short --branch` 为 `## main`，HEAD 为 `099439c`，`git remote -v` 为空。
- 项目规则：已完整读取 `prototype/AGENTS.md`；本批不修改 `prototype/**`、workflow、package、lockfile 或产品代码。
- 账户检查：`gh auth status --hostname github.com` 显示活动账户 `kyox215`，但 token 无效；`gh api user` 不可用。因此只记录“登录名可识别、认证不可用”，不记录 token 或 scope。
- 公开发现：`GET https://api.github.com/users/kyox215/repos?per_page=100&sort=updated`；公开列表包括 `PartsPro-V4`、`REBUY_SHARE`、`Chinatech-codex`、`PartsPro-Italia`、`ChinatechOS-2026`、`Chinatech`、`MagiskOnWSA`。列表不证明不可见的 private/internal 仓库不存在。
- 候选核验：使用 GitHub 公开 REST GET、`git ls-remote --symref`；在 `/private/tmp` 临时比较仓库 fetch 本地 HEAD 和候选 `main`，比较完成后删除临时目录。当前项目 `.git` 未写入 remote 或远端跟踪 ref。

## 3. 候选发现与仓库元数据

### 3.1 最可能候选

`kyox215/REBUY_SHARE` 只是当前最可能候选，不是未经 Owner 确认即可使用的 canonical repository。判断依据是仓库名与 Rebuy 项目一致，公开 description 为“意大利本地化交易app”，且在账户公开仓库列表中最近更新时间/推送时间靠前；其他公开仓库名称更贴近 PartsPro、Chinatech 或历史项目。

| 字段 | 只读结果 |
|---|---|
| full name / owner | `kyox215/REBUY_SHARE` / `kyox215` |
| URL | [https://github.com/kyox215/REBUY_SHARE](https://github.com/kyox215/REBUY_SHARE) |
| visibility | `public`；`private=false` |
| description | `意大利本地化交易app` |
| default branch | `main` |
| archived / disabled | `false` / `false` |
| fork | `false` |
| updated / pushed | `2026-08-25T10:07:00Z` / `2026-08-25T10:06:12Z` |

候选核验结论：仓库存在、归属和公开状态可确认；是否为 Owner 要求的最终目标仍需书面确认。由于认证不可用，不能据此确认账户下未公开的其他候选。

### 3.2 默认分支 tip

- `git ls-remote --symref https://github.com/kyox215/REBUY_SHARE.git HEAD refs/heads/main refs/heads/master` 返回 `HEAD -> refs/heads/main` 和 `main` tip `366ad7f287a00f795c742d7f2df10a531fa42e7c`；未把 `master` 当作目标。
- 公开 commit GET 与上述 SHA 一致；subject 为 `fix: restore complete release artifacts`，公开验证状态为 unsigned。该信息只用于 ref 追踪，不构成代码或发布信任判断。

## 4. Actions 只读审计

### 4.1 权限端点

以下 GET 均不读取 secrets、不修改设置、不触发 run：

| Endpoint | HTTP | 结论 |
|---|---:|---|
| `/repos/kyox215/REBUY_SHARE/actions/permissions` | 401 | `unknown`；认证不可用，不能判断 Actions enabled/allowed policy |
| `/repos/kyox215/REBUY_SHARE/actions/permissions/workflow` | 401 | `unknown`；不能判断默认 workflow 权限或 PR approval 策略 |
| `/repos/kyox215/REBUY_SHARE/actions/permissions/selected-actions` | 401 | `unknown`；不能判断 selected-actions allowlist |

401 是当前认证不可用下的读取结果，不解释为 Actions disabled，也不允许用公开仓库状态猜测权限设置。没有列出或读取任何 secrets。

### 4.2 Workflow 与 run 列表

| Endpoint | HTTP | 脱敏结果 |
|---|---:|---|
| `/repos/kyox215/REBUY_SHARE/actions/workflows?per_page=100` | 200 | `total_count=0`，公开可见 workflow 列表为空 |
| `/repos/kyox215/REBUY_SHARE/actions/runs?per_page=10` | 200 | `total_count=0`，公开可见 run 列表为空 |

结合远端 `main` 文件树，未发现 `.github/workflows/` 路径。该结果只证明当前公开 GET/树快照未发现 workflow 或 run，不证明未来提交后会自动运行，也不替代 Actions 权限端点的认证读取。

## 5. 本地与候选远端历史/文件树比较

在临时比较仓库中只读 fetch：

- local ref：`099439c460584a9fda3bb7b216639181786b3fa9`
- target ref：`366ad7f287a00f795c742d7f2df10a531fa42e7c`
- `git merge-base`：无共同祖先
- 关系：`no_common_ancestor`；不可 fast-forward，不能直接判断为本地领先或远端领先
- `git rev-list --left-right --count local...target`：`15 3`，仅表示在无共同祖先前提下两侧各自可达提交数量
- 文件树文件数：local `83` / target `46`
- 以 `git diff local target` 方向统计：`A=0`、`D=37`、`M=16`、`R=0`；远端没有相对本地新增路径，远端相对本地少 37 条路径、16 个同路径内容不同
- local 顶层包含 `.github .gitignore docs prototype`；target 顶层为 `.gitignore docs prototype`，target 没有 `.github/workflows/`

结论：这是两个无共同祖先的本地/远端历史，不能安全执行 fast-forward、自动 merge、强制 push 或直接覆盖 `main`。该比较不改变本地仓库，也不授权任何集成动作。

## 6. 本批变更与验证

### 6.1 变更

- 新增本记录；按需同步 [15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md) 和[阶段索引](../../../stages/README.md)的当前记录链接。
- 没有修改 `prototype/**`、`.github/workflows/prototype-quality.yml`、package/lockfile、产品代码、Git 配置或远端设置。

### 6.2 结果矩阵

| 检查 | 结果 | 最小证据 |
|---|---|---|
| 本地基线 | 通过 | 审计开始时 HEAD `099439c`、分支 `main`、工作树 clean、remote 为空 |
| `gh` 账户 | 部分可用 | 活动登录名 `kyox215` 可识别；token 无效，认证不可用 |
| 候选仓库元数据 | 通过 | 公开 GET 返回 owner/visibility/default branch/archive/disabled/URL |
| Actions 权限 | unknown | 三个权限 GET 均 HTTP 401；未猜测 |
| Workflow/run | 通过（公开视图） | workflows `0`、runs `0`；未触发 run |
| 默认分支 tip | 通过 | `main` tip `366ad7f287a00f795c742d7f2df10a531fa42e7c`，ls-remote 与 GET 一致 |
| 历史关系/文件树 | 通过 | 临时仓库 `merge-base=none`、`15/3`、83/46 文件树、差异统计完成 |
| prototype/workflow 不变 | 通过 | 审计前后只读检查；工作树与 workflow 未修改 |
| 外部写入 | 未发生 | 无 remote add、push、分支/PR/tag/release、workflow run、Actions 设置、Secrets、部署或 Supabase/生产操作 |

### 6.3 跳过项

- 不运行 typecheck/lint/build/E2E：本批只做远端目标元数据和历史关系审计，prototype 与 workflow 未变，复用 G1.2a 证据。
- 不运行真实 Actions、Preview、health、artifact、部署或 Supabase/Auth：当前没有 G1.2b Owner Gate，且本批明确只读。
- 不做 hash：没有新生成物或传输交付，文件树比较已覆盖本批需要的关系风险。
- 不启动独立审查：本批为低风险只读文档审计，不涉及权限实现或生产写入。

## 7. 风险、回退与维护

### 7.1 风险

- 候选仓库虽最符合 Rebuy 名称/description，但尚未得到 Owner 对 canonical repo 的明确确认。
- `gh` 认证不可用，Actions permissions、默认 workflow 权限和 allowlist 只能标记 `unknown`；不能把公开仓库或空 run 列表解释为策略安全。
- 本地与候选远端无共同祖先、文件树不同；任何覆盖、强制 push、历史拼接或直接 main 推送都可能破坏远端历史或本地审计链。
- 远端当前没有公开 workflow/run；真实 G1.2b 运行条件、runner 权限、触发器和默认权限尚未验证。

### 7.2 回退

- 本批只新增/同步 Markdown；如记录文字有误，可回退本批 docs commit，不触碰本地 workflow、G1.1 refs/tags 或远端仓库。
- 在未来得到 Owner 授权前，不添加 remote、不 push、不创建 PR/run。授权后若目标或历史策略不符，停止晋级并保留最小脱敏审计摘要。
- 无论 Owner 选择保留远端历史、迁移到新仓库或重新建立共同基线，都必须先书面决定；禁止用 force push、删除远端分支或覆盖 `main` 代替决策。

### 7.3 维护

- G1.2b 执行前重新 GET 核验 owner、visibility、default branch、archive/disabled、Actions permissions、workflow/run 和 tip SHA；若 repo、branch 或策略漂移，先更新证据和 Owner 决策。
- 认证恢复时只记录登录名和认证是否可用；不把 token、scope、secret 或环境值写入文档/日志。
- 任何 remote、PR、push、Actions run、Preview 或生产连接都要有独立 Owner Gate、最小权限和可回退 ref；不得把本次公开审计当作授权。

## 8. 下一 Owner Gate 与推荐路径

G1.2b 真实执行前，Owner 至少需要明确：

1. canonical repository 是否确认为 `kyox215/REBUY_SHARE`，或指定其他仓库。
2. 目标默认分支和分支策略；推荐以独立分支/PR 评审，暂不直接推送 `main`。
3. 是否允许在当前本地仓库添加 remote；若允许，先只读 fetch/临时 ref，仍不 push。
4. 是否允许把本地 workflow 推到目标分支并运行一次真实 GitHub Actions；该决定必须单独写明，不包含 Preview、Supabase、数据库或生产。
5. 无共同祖先时采用保留远端历史、迁移到新仓库或重新建立共同基线中的哪一种；在该决定前禁止 merge/force push/覆盖 `main`。

推荐最安全顺序：Owner 先确认仓库和历史策略 → 授权只读 remote/fetch 复核 → 独立决定分支/PR 与 push 范围 → 再决定是否运行真实 Actions → 保存 job/runner/ref/权限的最小脱敏证据。若历史关系仍无共同祖先，应先完成仓库迁移/基线决策，不把本地等价验证冒充远端 CI。

当前 Gate：`G1.2b 待 Owner Gate；真实远端 CI 未运行；G1 Exit 未通过；G2-A0 不打开。`

关联记录：[G1.2a 本地 workflow/等价证据](../2026-08-26-g1-2a-local-workflow/README.md)、[G1.2 preflight](../2026-08-26-g1-2-ci-preflight/README.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[15 台账](../../../15-项目状态与阶段台账.md)。
