# G1.1 本地工程基线证据

文档状态：G1.1 Node 22 可复现基线已完成；G1 Exit、CI/Preview/环境隔离和 G2-A0 仍未通过或打开。
日期：2026-08-25（Europe/Rome）  
执行范围：项目根 Git、repo-local 配置、Node 22/pnpm 工具链核对和本地静态验证  
环境：local-only；未连接远端、CI、Preview、Supabase、Staging 或 Production  
Owner 原话：`继续下一步`  
解释范围：按此前已批准的范围执行项目根为唯一 Git 根、`prototype/` 为 app 目录；复用既有 Node 22.12.0/pnpm 10.33.3；不创建远端、CI、Preview、Supabase 或生产连接。

## 1. Git 基线

- Git 根：`/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划`。
- `prototype/` 未建立独立仓库；项目根是唯一 Git 根。
- 分支：`main`。
- repo-local identity：`Hexiang Huang <kyox120@gmail.com>`；未修改 global identity。
- remote：空；本批没有 `git remote add`、push 或其他远端写入。
- 初始基线提交：`0d6bb3f621019e3c8ad4b81e6614cd8c6bea5bcb`，message `chore: establish Rebuy local project baseline`。
- 初始提交包含 79 个受审查文件；只允许 `prototype/.env.example` 作为环境示例文件。
- 预定稳定 ref：`g1.1-local-baseline-2026-08-25`。该 tag 只标记本地 Git/文档基线，不代表 Node 依赖安装、G1 Exit 或生产通过。

## 2. 暂存集与敏感边界

初始暂存集检查结果：

- 未跟踪 `node_modules/`、`.next/`、`.pnpm-store/`、`.vercel/`、`.supabase/`、`*.tsbuildinfo` 或临时目录。
- 未跟踪 `.env`、`.env.local` 或其他环境值文件；仅保留 `prototype/.env.example`。
- staged sensitive-content scan 无命中；未读取任何 `.env` 值、密码、token、客户 PII、真实商家资料或生产凭据。
- staged 大文件检查无超过 10 MiB 文件；既有 `prototype/public/product-sprite.png` 属于本地产品资产。
- `git diff --cached --check` 报告既有 Markdown 硬换行使用的尾随空格；未为本批清理文档格式，也未改变内容。

## 3. 工具链与安装验证

本批明确 PATH：`/Users/kyox215/.nvm/versions/node/v22.12.0/bin:/Users/kyox215/.nvm/versions/node/v20.20.2/bin:/usr/bin:/bin`。

| 命令 | 实际结果 | 证据边界 |
|---|---|---|
| `node --version` | `v22.12.0` | 本次 shell 已切换到 Node 22；不代表依赖安装成功 |
| `pnpm --version` | `10.33.3` | 与 packageManager 声明一致 |
| `TMPDIR=/private/tmp pnpm install --frozen-lockfile --offline` | 首次非交互运行：`ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY` | 不是缓存缺包结论；仅说明非 TTY 不允许清理 modules |
| `CI=true TMPDIR=/private/tmp pnpm install --frozen-lockfile --offline` | 重建 `node_modules` 后退出 `ERR_PNPM_NO_OFFLINE_TARBALL`，缺少 `@swc/helpers@0.5.23` tarball | 离线缓存不完整；未联网、未改 lockfile；按要求停止后续验证 |
| `pnpm typecheck` / `pnpm lint` | 首次非交互 install 被拒绝、modules 尚未重建前，既有 node_modules 上均通过 | 这是 install 阻塞前的局部证据，不是失败 install 后的复验；不得升级为本批完整通过 |

离线 install 失败后不再运行依赖相关命令，不执行网络安装，不修改 `prototype/package.json` 或 lockfile。当前 `node_modules/` 为被 pnpm 重建后未完成的本地依赖状态，属于 ignored 可恢复工作区状态；tracked source tree 未被修改。

### 3.1 2026-08-25｜隔离副本 frozen install 补验

- 验证源：从初始源码提交 `0d6bb3f621019e3c8ad4b81e6614cd8c6bea5bcb` 使用 `git archive` 解出到 `/private/tmp/rebuy-g1.ml6qyC/prototype`；该隔离副本未复制当前工作区 `node_modules`。
- 工具链：明确 PATH 下 `node --version=v22.12.0`、`pnpm --version=10.33.3`。
- 命令：`TMPDIR=/private/tmp pnpm install --frozen-lockfile`。结果退出 0；lockfile resolution skipped，`351` 个包完成安装（`reused=351`、`downloaded=0`、`added=351`）。本次允许隔离目录使用 npm registry 依赖来源，但实际输出未下载 tarball。
- 安装 warning：pnpm 忽略 `unrs-resolver@1.12.2` build scripts；未执行 `pnpm approve-builds`，不为此声明生产或 CI 通过。
- `prototype/` 源码、package/lockfile、当前 Node22 dev session 和项目 Git 工作树均未修改。

## 4. Build 复用与跳过项

- 可复用 build 证据：此前相同 prototype 源码、配置和 lockfile 在隔离 `/tmp/rebuy-g0-build.RKda6l/prototype`、Node `v22.12.0`、pnpm `10.33.3` 下 `pnpm build` 退出 0。
- 本批只写入 `.git` 和文档，未修改 prototype 源码、配置、package 或 lockfile，因此该 build 证据在输入条件上仍可复用。
- 本批不把复用 build 写成当前 `node_modules` 的新鲜验证；Node22 frozen install 阻塞解除后仍需按 G1.1/G1.2 合同补跑 typecheck、lint、build。
- 未运行 Browser/E2E、CI、Preview、Staging、Production、Supabase/Auth、数据库、部署或外部写入。
- 未做 hash；Git commit/ref 已提供本批基线完整性，且没有新的确定性传输生成物。
- 未启动额外独立审查代理；本批为受控本地工程基线，风险集中在版本/依赖验证阻塞。

## 5. 当前状态、风险、回退与 Owner Gate

- 当前 G0/P1 保持“已通过并冻结”；G1 为“执行中（G1.1 已完成，G1.2 待开始）”。
- G1.1：Git root、`main`、repo-local identity 和初始 SHA 已建立；隔离副本 Node22/pnpm frozen install、typecheck、lint、build 均通过。
- G1.2 最小 CI、G1.3 四环境/Preview 回退仍未开始；G1 Exit Gate 未通过，不打开 G2-A0。
- 主要风险：离线 pnpm store 缺少 `@swc/helpers@0.5.23` 的历史问题已由隔离依赖来源补验解除；CI、Preview、四环境隔离与回退证据仍未建立。
- 安全回退：保留初始提交和后续文档提交；恢复时使用已记录 tag/ref 建分支或追加 `git revert`，不建议 destructive reset；完成依赖补齐后重新验证并追加记录。
- 无外部写入、无远端、无生产数据变化。下一动作是按合同进入 G1.2 CI 和 G1.3 四环境/Preview 回退门。

本证据不代表 G1 Exit 通过、CI/Preview/Staging/Production 已建立、Auth/数据库已连接、真实登录已实施或生产已批准。

## 6. 2026-08-25｜G1.1 可复现验证完成

在同一隔离目录 `/private/tmp/rebuy-g1.ml6qyC/prototype`、Node `v22.12.0`、pnpm `10.33.3` 下，安装成功后重新运行：

| 命令 | 结果 | 证据边界 |
|---|---|---|
| `pnpm typecheck` | 退出 0 | 隔离本地静态 |
| `pnpm lint` | 退出 0 | 隔离本地静态 |
| `pnpm build` | 退出 0；Next `16.3.2` 编译、TypeScript、静态页面生成和路由优化完成 | 隔离本地静态；不代表部署/生产 |

- Build 输入来自源码 SHA `0d6bb3f621019e3c8ad4b81e6614cd8c6bea5bcb`；当前工作区预览继续由 Node22 session `16417` 提供，未在工作区 build。
- 未运行 CI、Preview、Staging、Production、Browser/E2E、Supabase/Auth、数据库、部署或外部业务写入；未读取 secrets/PII；未做 hash。
- 本条解除“offline store 缺包/Node22 脚本复验未完成”风险，但不改变 G1 Exit 未通过、G1.2/G1.3 未开始和 G2-A0 未打开。
