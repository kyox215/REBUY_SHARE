# G1.2a 本地最小 workflow 与等价验证

阶段：G1 工程底座与环境隔离
批次：G1.2a 本地 workflow 配置 / 本地等价验证
状态：`G1.2a 本地 workflow/等价验证已完成；G1.2b 待 Owner Gate`
证据级别：本地静态 + 本地等价
记录日期：2026-08-26（Europe/Rome）
workflow commit：`b0681d585cabe2f5f293779fc3627e2782be9fa2`
初版 workflow（历史）：`a388348b81300ca00f669d0bd62b0748b9f191a5`
前一可回退基线：`f05c5f8375143909ae8e01d87b4267a321b590ad`
远端 / CI / Preview / environment ref：`N/A`

> 本记录证明本地 workflow 文件和相同命令合同的隔离复现，不是 GitHub Actions 远端 CI 通过。没有添加 remote、push、真实远端 run、Preview、Supabase、数据库或生产连接；G1 Exit 未通过，G2-A0 不打开。

## 1. Owner Gate、目标与范围

Owner 已批准以下范围：

> `批准进入G1.2a：采用GitHub Actions候选，在本地创建只读最小CI工作流并做本地等价验证；暂不添加remote、不push、不运行远端CI、不部署Preview、不接Supabase或生产。`

本批目标是把已批准的最小质量门落成一个本地可审查的 GitHub Actions workflow，并在不触碰原工作区依赖/生成物的隔离副本中复现相同的 Node、Corepack、pnpm、working-directory 和命令顺序。范围仅包括：

- 新建 `.github/workflows/prototype-quality.yml`，这是本项目当前唯一 workflow。
- 使用 `pull_request` 与推送到 `main` 触发；固定只读权限和 action 完整 SHA。
- 在 `prototype/` 依次执行 frozen install、typecheck、lint、build。
- 记录静态策略检查、Corepack 诊断、隔离等价结果、失败停止策略和回退边界。

本批不创建 remote、branch、tag、Preview、Staging、Production、Supabase、Auth、数据库、artifact、health 探针或部署，不修改 `prototype/**`、package、lockfile、源码或生成物。

## 2. Workflow 合同与实际变更

文件：[prototype-quality.yml](../../../../.github/workflows/prototype-quality.yml)

| 约束 | 实际结果 |
|---|---|
| 平台/触发器 | GitHub Actions；`pull_request` + `push` 到 `main`；无 `pull_request_target`、`workflow_run`、`workflow_dispatch` |
| 权限 | 顶层 `permissions: contents: read`；未声明 secrets、env、environment 或 artifact |
| Job | 单 job；`runs-on: ubuntu-24.04`；`timeout-minutes: 15` |
| Action | checkout 与 setup-node 均使用核验过的 40 位 SHA；`persist-credentials: false` |
| Node/pnpm | Node `22.12.0`；先以 npm 精确引导 Corepack `0.34.6`，再驱动 pnpm `10.33.3`；`package-manager-cache: false` |
| 工作目录 | `defaults.run.working-directory: prototype`；所有应用命令在 `prototype` 执行 |
| 顺序 | 临时 prefix 引导 Corepack `0.34.6` → Corepack/pnpm 版本检查 → `install --frozen-lockfile` → `typecheck` → `lint` → `build` |
| 失败策略 | 未声明 `continue-on-error`；命令非零即停止，不生成晋级信号 |
| 外部边界 | 无 secrets、health/curl、Supabase、数据库、Preview、生产、artifact 或部署步骤 |

### 2.1 Action pin 快照

核验日期：2026-08-26。实施当天仍须从官方 release → commit 链路再次核验；tag/release/最新稳定候选漂移时，先更新证据和 Owner 决策，不静默替换。

| Action | 官方 release | 固定 `uses:` |
|---|---|---|
| checkout | [v7.0.1 release](https://github.com/actions/checkout/releases/tag/v7.0.1) / [commit](https://github.com/actions/checkout/commit/3d3c42e5aac5ba805825da76410c181273ba90b1) | `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` |
| setup-node | [v7.0.0 release](https://github.com/actions/setup-node/releases/tag/v7.0.0) / [commit](https://github.com/actions/setup-node/commit/820762786026740c76f36085b0efc47a31fe5020) | `actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0` |

GitHub 安全指南说明完整 commit SHA 是不可变引用方式：[secure use](https://docs.github.com/en/actions/reference/security/secure-use)。本地 workflow 的存在不等于 Owner 已批准 G1.2b，也不等于远端 CI 已运行。

## 3. 验证环境与结果

### 3.1 隔离输入

- 从 workflow 修正 commit `b0681d585cabe2f5f293779fc3627e2782be9fa2` 创建临时 archive 副本；`a388348b81300ca00f669d0bd62b0748b9f191a5` 仅作为初版 workflow 历史审计 ref。
- 删除副本中的 `prototype/.env.example`，避免把任何环境示例带入等价运行；未复制 `.env*`、`node_modules`、`.next` 或本机 pnpm store。
- 使用明确 Node22 PATH：Node `v22.12.0`；workflow 目标 runner 标签记录为 `ubuntu-24.04`，本地等价验证不冒充该 runner。
- 所有命令在临时副本的 `prototype/` 目录执行；原工作区 `prototype/**` 与 lockfile 无差异。

### 3.2 Corepack 诊断与修正

| 诊断 | 结果 | 边界 |
|---|---|---|
| Node22 自带版本（历史诊断） | Corepack `0.29.4` | 这是初版 workflow 使用的 bundled 版本；不再作为 fresh runner 获取 pnpm 的实现路径 |
| 0.29.4 无缓存探针（历史诊断） | 在 fresh 临时 `COREPACK_HOME` 解析 pnpm 时返回 registry DNS `ENOTFOUND registry.npmjs.org` | 该错误发生在签名检查前；只能说明沙箱网络不可达，不能排除 Corepack 新签名 key/签名链失败，也不能证明 0.29.4 可安全获取目标版本。原先“不是签名或兼容失败”的表述已纠正 |
| 0.29.4 warmed-cache 结果（历史诊断） | 复制既有 pnpm `10.33.3` 包缓存后，`corepack pnpm@10.33.3 --version` 曾输出 `10.33.3` | 覆盖不足，不作为 fresh runner 或签名链通过证据；保留仅用于解释为何主审要求重新验证 |
| 官方问题背景 | [Corepack issue #627](https://github.com/nodejs/corepack/issues/627)、[issue #612](https://github.com/nodejs/corepack/issues/612) 记录 Node LTS bundled Corepack 与 npm 新签名 key 的获取风险；[Corepack README](https://github.com/nodejs/corepack) 允许使用 npm 精确安装/更新 Corepack | 这些风险由 exact bootstrap 处理，不用签名绕过或浮动版本掩盖 |
| fresh exact bootstrap | 明确 Node `v22.12.0`、npm `10.9.0`；全新 npm cache、`COREPACK_HOME` 和临时 `${RUNNER_TEMP}/corepack` prefix 中，`npm install --global --prefix ... --ignore-scripts --no-audit --no-fund corepack@0.34.6` 退出 0 | package version `0.34.6`；engines `^20.10.0 || ^22.11.0 || >=24.0.0`，与 Node22.12.0 匹配；不覆盖 runner 自带 Node 目录 |
| fresh Corepack/pnpm | prefix Corepack `0.34.6` 和后续 PATH Corepack 均成功；`corepack pnpm@10.33.3 --version` 退出 0，输出 `10.33.3` | 使用 fresh `COREPACK_HOME`；没有 `COREPACK_INTEGRITY_KEYS=0`、签名跳过、`pnpm/action-setup` 或 `latest` |
| Corepack `0.35` / pnpm/action-setup | 未使用 | 0.35 的 Node 支持变化超出本批；workflow 固定 `0.34.6`，版本由 npm exact bootstrap + Corepack 驱动 |

实际 workflow 先在 `${RUNNER_TEMP}/corepack` 临时 prefix 安装 Corepack `0.34.6`，把 prefix `bin` 写入 `${GITHUB_PATH}`，后续步骤再调用 `corepack pnpm@10.33.3`。该 prefix 不覆盖 runner 自带 Node；fresh bootstrap 的 npm registry 读取与 pnpm 解析仍属于 runner 网络/供应链风险，必须保留失败停止策略。

### 3.3 本地等价矩阵

命令均从上述隔离 `prototype/` 副本执行，结果如下：

| 顺序 | 命令 | 结果 | 最小摘要 |
|---|---|---:|---|
| 0 | npm exact Corepack bootstrap + `node --version` / `corepack --version` / `corepack pnpm@10.33.3 --version` | 0 | Node `v22.12.0`；npm `10.9.0`；Corepack `0.34.6`；pnpm `10.33.3` |
| 1 | `corepack pnpm@10.33.3 install --frozen-lockfile` | 0 | 351 packages；复用 351、下载 0；保留 `unrs-resolver@1.12.2` ignored build-script warning |
| 2 | `corepack pnpm@10.33.3 typecheck` | 0 | 完成 |
| 3 | `corepack pnpm@10.33.3 lint` | 0 | 完成 |
| 4 | `corepack pnpm@10.33.3 build` | 0 | Next `16.3.2` 编译、TypeScript、静态页生成和优化完成 |

不执行 `pnpm approve-builds`，不新增 allowlist；ignored build-script warning 仍是非阻塞供应链风险，若未来依赖确需脚本，另开审查。

## 4. 静态策略、失败停止与回退验证

- Ruby Psych YAML 解析通过；现有 Node 策略断言通过：触发器、`contents: read`、单 job、runner、15 分钟、`prototype` cwd、cache off、命令顺序、两个 40 位 SHA 和禁止关键字均符合合同。
- `actionlint` 未安装，未为本批安装新工具；YAML 解析器和明确策略断言覆盖了本批静态风险。
- 临时 harness 使用 `set -e; false; sentinel`，退出码为 1，`sentinel` 未执行；证明 workflow 不用 `continue-on-error` 时失败会停止后续步骤。
- `git diff` 相对基线 `f05c5f8375143909ae8e01d87b4267a321b590ad` 仅包含初版/修正 workflow 与 docs；当前实现 ref 为 `b0681d585cabe2f5f293779fc3627e2782be9fa2`；`prototype/**` 无差异。
- G1.1 refs/tags 未改变：`g1.1-local-baseline-2026-08-25` 指向 `47e0d15a3f3078e79bd653c3ec6f06488e4b4aa8`，`g1.1-complete-2026-08-25` 指向 `5b730ff195c017d976da6ad3844995b687a3a10f`；无 remote、无 push、无 tag 新建。

### 回退

若 workflow pin、Corepack bootstrap、触发器、权限或命令合同有误，删除或回退当前 workflow 修正 commit `b0681d585cabe2f5f293779fc3627e2782be9fa2`，必要时连同初版 workflow commit `a388348b81300ca00f669d0bd62b0748b9f191a5` 一并回退，即可回到 `f05c5f8375143909ae8e01d87b4267a321b590ad`；不修改、不删除 G1.1 tag/ref。任何未来 G1.2b 远端失败只停止晋级并回退到上一可验证 ref，需另行 Owner 决策。

## 5. 维护、风险与跳过项

- 每次 action、Node、pnpm、runner、lockfile 或 package scripts 变化都要更新本证据；action 必须从官方 release → commit 链路核验并固定完整 SHA。
- 首次 package-manager cache 保持关闭；缓存、权限、失效和污染控制需另开变更记录。
- Corepack exact bootstrap 依赖 runner npm registry 网络读取；不得用签名绕过、warmed cache 或浮动版本解决。当前固定 `0.34.6`；若 npm registry、签名 key、Node engines 或 pnpm 获取失败，保留最小脱敏错误并停止晋级，不能静默切换 `latest`/`0.35`。
- 本批完成本地静态和 fresh exact bootstrap 等价证据；未运行真实 GitHub Actions、未验证 GitHub runner 触发/权限摘要、未配置 remote、未部署 Preview、未接 Supabase/Auth/数据库/生产。
- Browser/E2E、health、artifact、部署、环境隔离和 Preview 回退属于后续 G1.3/专项，未因本批 build 通过而跳过。
- 未运行 hash；本批无生成物交付、传输或异常覆盖疑点。

## 6. 当前 Gate 与下一 Owner 决策

当前结论：`G1.2a 本地 workflow/等价验证已完成；G1.2b 待 Owner Gate；不是远端 CI 通过；G1 Exit 未通过；G2-A0 不打开。`

下一步需 Owner 另行决定是否允许添加 remote、push 并运行一次真实 GitHub Actions（G1.2b）。即使 G1.2b 获批，仍需完成 G1.3 四环境/Preview 回退和 G1 Exit；本证据不授权 Supabase、Auth、数据库、生产或 G2-A0。
