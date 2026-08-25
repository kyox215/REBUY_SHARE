# G1 Entry 基线只读证据

文档状态：G1 准备中（Entry 已恢复授权）；本文件不是 G1 完成证据
阶段：G1 工程底座与环境隔离
日期：2026-08-25 23:06:57 CEST（Europe/Rome）
执行范围：只读环境核实、路径/版本/配置存在性检查；未初始化 Git、未修改工程、未连接外部服务
环境：本地工作区；不代表 Preview、Staging、受控生产或生产
commit ref：N/A（当前项目根与 prototype 均无 `.git`）
deploy ref：N/A

## 1. Owner 决定与当前 Gate

Owner 最新正式决定原话：`分类目录IA通过，G0重新冻结，未覆盖项进入后续专项，恢复G1授权`。

- G0/P1：已通过并冻结。点击搜索提交已通过；直接 Enter 键盘提交未验证成功，转入后续键盘/无障碍专项，不阻塞本次 G0 冻结或 G1 Entry。
- G1：准备中（Entry 已恢复授权）。这只允许开始 G1 Entry 资料和工程基线准备，不表示 G1 已开工、已完成或 Exit Gate 已通过。
- G2-A0、G2-A1、P2 及后续阶段：未开始；不因本决定获得数据库、Auth、Supabase、支付、生产或真实 PII 授权。

## 2. 只读事实

| 检查项 | 实际观察 | 边界/解释 |
|---|---|---|
| 项目根 Git | 当前项目根无 `.git` 目录 | 尚无 commit、分支或回退 ref；本批不初始化 |
| `prototype/` Git | `prototype/` 无 `.git` 目录 | 不单独建立嵌套 Git；等待 G1.1 Owner 选择 |
| 推荐 Git 根 | 推荐项目根作为 Git 根，`prototype/` 作为应用目录 | 这是待 Owner 确认的工程选择，不是已执行动作 |
| 当前 Node | `v20.20.2`，来自 `/Users/kyox215/.nvm/versions/node/v20.20.2/bin/` | 不符合项目 Node `22.x` 合同；未切换本轮环境 |
| 可用 Node 22 | `/Users/kyox215/.nvm/versions/node/v22.12.0/` 已安装 | 下一步可复用既有本地 Node 22，不代表 G1 已完成 |
| 当前 pnpm | `10.33.3`，来自同一 Node 20 目录 | 与项目声明一致 |
| 当前 corepack | 来自 `/Users/kyox215/.nvm/versions/node/v20.20.2/bin/` | 仅记录路径，不执行切换或安装 |
| `prototype/.node-version` | `22` | 版本提示文件存在 |
| `prototype/package.json` | `engines.node=22.x`、`engines.pnpm=10.33.3`、`packageManager=pnpm@10.33.3`；脚本含 `dev/build/start/lint/typecheck` | 仅为工程基线输入 |
| lockfile | `prototype/pnpm-lock.yaml` 的 `lockfileVersion: '9.0'` | 未执行安装或重生成 |
| CI/部署配置 | 未发现 `.github/workflows`、`vercel.json`、`netlify.toml`、`Dockerfile`、`bitbucket-pipelines.yml` 等目标文件 | G1 尚未创建 CI、Preview 或部署配置 |
| `.env.example` | 仅观察到两个变量名：`NEXT_PUBLIC_SUPABASE_URL`、`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | 未读取任何值；不代表已连接 Supabase 或已创建环境 |
| 根 `.gitignore` | 已覆盖 `node_modules/`、`.next/`、`.env*`（保留 `**/.env.example`）、`.vercel/`、`.supabase/` 等 | 仅为版本/secret 边界输入，不构成 Git 基线 |

## 3. G1.1 推荐顺序与 Owner 决策点

推荐且待 Owner 确认的最小顺序：

1. 选择项目根为唯一 Git 根，`prototype/` 保持应用目录；由 Owner 明确是否建立本地 Git 基线。
2. 在获准的本地环境切换并固定 Node 22 与 pnpm `10.33.3`，记录可追溯版本和 lockfile 状态。
3. 仅在 G1 Entry 批次进一步获准后，设计最小 CI 的 `typecheck`/`lint`/`build` 检查；再单独决定 Preview、远端仓库可见性和部署边界。

本批不执行以上工程写入，不创建远端仓库、分支、CI、Preview、Staging、Production、数据库、Auth 或 Supabase 资源。

## 4. 命令与结果摘要

本批实际只读检查包括：

- `node --version` → `v20.20.2`。
- `pnpm --version` → `10.33.3`。
- `command -v node pnpm corepack` → 均来自 `/Users/kyox215/.nvm/versions/node/v20.20.2/bin/`。
- `find` 检查项目根与 `prototype/` 的 `.git` → 均不存在。
- `find` 检查 CI/部署候选配置 → 未发现目标文件。
- 读取 `prototype/.node-version`、`prototype/package.json` 的版本字段、`prototype/pnpm-lock.yaml` 首段和 `.env.example` 变量名 → 与第 2 节一致；未读 `.env` 或任何变量值。

未运行 build、lint、typecheck、E2E、浏览器、部署、远端连接或哈希；本批目标是 Entry 只读基线，不把旧证据重复写成 G1 产物。

## 5. 证据边界、风险与回退

- 这份记录证明的是当前本地工具链、目录和配置缺口，不证明 Git、Node 22、CI、Preview、Staging、Production 或回退演练已经建立。
- 主要风险是根目录 Git 基线缺失、当前 Node 20 与 Node 22 合同不一致，以及 CI/环境隔离尚未实施。G1.1 应先处理版本与回退基线，再讨论远端/Preview。
- 若 Owner 不选择项目根作为 Git 根，须追加新的根目录/版本策略和回退方案；不得自行初始化或建立嵌套仓库。
- 在 G1 工程批次出现问题时，停止晋级并保留本只读基线；未生成可回退 commit，因此不得声称已有版本可回退。
- 不记录密码、token、secret、客户 PII、真实商家资料或原始敏感附件；本文件只保留变量名和工具路径/版本。

## 6. 下一步与 Owner Gate

下一动作：Owner 确认 G1.1 Git 根选择和本地版本基线策略；随后按 G1 合同追加实际工程批次记录。G1 Entry 已恢复授权，但 G1 Exit Gate 仍未通过；只有 Git/ref、Node 22、pnpm、CI、四环境边界、secret 规则、Preview 回退证据完成并经 Owner 通过后，才可打开 G2-A0。

本证据不替代 [G1 工程底座与环境隔离合同](../../../stages/G1-工程底座与环境隔离.md)、[15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md) 或 G0 Owner 决定，也不授权数据库、Auth、支付、生产、远端仓库可见性或真实业务数据。
