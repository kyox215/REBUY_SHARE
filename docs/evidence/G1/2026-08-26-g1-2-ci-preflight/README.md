# G1.2 最小 CI 预检与 Owner Gate

阶段：G1 工程底座与环境隔离
批次：G1.2 最小 CI 预检（G1.2a 候选准备 / G1.2b 远端真实运行拆分）
状态：`preflight` / 规划证据，待 Owner Gate
证据级别：本地静态
记录日期：2026-08-26（Europe/Rome）
代码 ref：`8e09571`（当前本地 `main`，仅作为预检上下文；本批不修改 prototype）
远端 / CI / Preview ref：`N/A`

> 本记录不是 CI 已创建、已运行或已通过的证明。当前项目没有 remote，也没有 `.github/` workflow；本批只把最小 CI 候选、证据矩阵、失败策略、安全边界和 Owner 决策点写成可审查的 G1.2 入口。

## 1. 目标与边界

G1.2 的目标是在保持 G1.1 本地基线可回退的前提下，建立只验证工程质量门的最小自动化合同。它不实现业务功能，不创建环境，不连接 Supabase/Auth，不部署 Preview，也不打开 G2-A0。

本批明确不做：

- 不创建 `.github/`、workflow、remote、分支、tag、Preview、Staging 或 Production。
- 不修改 `prototype/` 源码、`package.json`、lockfile、依赖、配置或生成物。
- 不读取 `.env` 值、CI secrets、个人 shell 配置、真实 URL、PII 或生产日志。
- 不执行 `curl` health 探针，不上传 artifact，不部署，不把本地脚本结果写成远端 CI 通过。

## 2. G1.2a / G1.2b 拆分

| 子批次 | 内容 | 当前状态 | 通过含义 |
|---|---|---|---|
| G1.2a 本地 workflow 配置 / 本地等价验证 | Owner 授权后，在本地创建最小 workflow 文件候选，并用相同 Node/pnpm、工作目录和命令进行本地等价验证 | 本记录仅完成 preflight；尚未创建 workflow，未执行本批专属等价验证 | 只证明候选文件和本地复现合同，不证明 GitHub runner 或远端 CI 通过 |
| G1.2b 远端真实 CI run | Owner 另行批准 remote/平台后，在真实 GitHub Actions runner 上触发 pull request / `main` push，并保存最小脱敏运行证据 | 未开始；当前无 remote | 只有真实 run 的 job、runner、ref、日志摘要和失败/成功结果才能证明远端 CI 运行 |

G1.1 已有的 Node `v22.12.0`、pnpm `10.33.3`、`pnpm install --frozen-lockfile`、`pnpm typecheck`、`pnpm lint` 与 `pnpm build` 隔离副本证据可以作为候选命令的输入参考，但不能替代 G1.2a workflow 等价验证或 G1.2b 真实 CI run。

## 3. 推荐候选（待 Owner 决定）

### 3.1 Runner、工具链和工作目录

| 项目 | 候选约束 |
|---|---|
| 平台 | GitHub Actions |
| Runner | 固定 `ubuntu-24.04` |
| Node | 固定 `22.12.0`，与 `prototype/.node-version` 的 Node 22 意图和 `package.json.engines` 一致 |
| pnpm | 固定 `10.33.3`，通过 Corepack 启用项目声明的 package manager |
| working-directory | `prototype`；仓库根只承载 workflow 与文档，应用命令不在根目录运行 |
| 安装 | `pnpm install --frozen-lockfile`，输入为 `prototype/pnpm-lock.yaml` |
| 定向命令 | `pnpm typecheck` → `pnpm lint` → `pnpm build` |
| 超时 | job 总体 `15` 分钟；单命令不应绕过 job timeout |
| 首次缓存 | 显式关闭 package-manager cache；缓存需另行记录命中、失效和污染风险后再决定 |

pnpm 安装曾提示忽略 `unrs-resolver@1.12.2` 的 build scripts；当前候选保留该 warning，不执行 `pnpm approve-builds` 或放宽 allowlist。未来若依赖确实需要构建脚本，必须另开供应链审查，记录依赖、脚本、来源、最小 allowlist 和回退，不在本批静默放行。

### 3.2 触发、权限和动作边界

候选触发器为 `pull_request` 与推送到 `main`。明确禁止 `pull_request_target`，因为本阶段不需要让不可信 PR 代码在目标分支权限上下文中运行。

候选顶层权限为：

```yaml
permissions:
  contents: read
```

GitHub 的 workflow 权限语义下，未列出的权限保持 none；实施时必须在真实 workflow 和运行摘要中核对，不得依赖仓库默认权限。候选不注入 env 或 secrets，不读取 `.env`，不请求 Supabase，不调用 health route，不上传 artifact，不部署 Preview。

### 3.3 动作版本固定策略

截至 2026-08-26，本批记录的 GitHub 官方仓库示例当前使用 `actions/checkout@v7` 与 `actions/setup-node@v7`。实施时必须先从官方仓库核对对应 v7 release，再把每个 action 固定到完整 40 位 commit SHA；不能凭空写 abbreviated SHA，也不能把可变 tag 当成不可变供应链引用。

官方参考：

- [actions/checkout](https://github.com/actions/checkout)
- [actions/setup-node](https://github.com/actions/setup-node)
- [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [Workflow syntax reference](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

实施记录必须同时保存 action 名称、release/tag、完整 SHA、核对日期和核对来源。若官方 v7 release 或 runner 标签发生变化，先更新候选和 Owner 决策，不在 workflow 中临时漂移。

## 4. 候选门的行为合同

候选 workflow 的行为顺序应等价于：

1. 在 `ubuntu-24.04` 上使用 Node `22.12.0`。
2. 通过 Corepack 使用 pnpm `10.33.3`。
3. 在 `prototype` 目录运行 `pnpm install --frozen-lockfile`。
4. 按顺序运行 `pnpm typecheck`、`pnpm lint`、`pnpm build`。
5. 任一命令非零即失败并停止；不创建成功标记、不上传 artifact、不生成 Preview 晋级信号。

构建输出只保留必要的检查摘要。日志不得出现 env 值、secret、token、`.env` 内容、真实 URL、客户/商家 PII、个人路径中的敏感片段或完整依赖凭据。没有健康探针、部署或数据库连接；即使 build 通过，也只能说明工程检查通过，不能说明应用健康、数据可用或生产可发布。

## 5. 证据矩阵

| 证据项 | G1.1 已有本地证据 | G1.2a 需补证据 | G1.2b 未来远端证据 | 当前结论 |
|---|---|---|---|---|
| Git root / ref | `main`、初始基线和本地完成记录 | workflow 变更的本地 commit | 真实 run 的 commit/ref | G1.1 已满足；CI ref 未产生 |
| Runner / Node | 隔离副本 `v22.12.0` | 本地等价环境声明与版本输出 | runner 名称、Node 输出、job 摘要 | 候选已定义，未运行 |
| pnpm / lockfile | pnpm `10.33.3`、frozen install 退出 0 | Corepack / pnpm 输出与安装结果 | runner 安装日志摘要和 lockfile 结果 | 候选已定义，未运行 |
| typecheck / lint / build | G1.1 隔离副本均退出 0 | 同一 workflow 候选顺序的本地等价结果 | 每个 job step 的 exit/result | 命令已有输入证据，G1.2 未通过 |
| 触发与权限 | 无 remote / 无 workflow | 文件静态检查 | PR 与 `main` push run、权限摘要 | 未创建 |
| secret / log 边界 | 未读取值 | 本地扫描和失败日志检查 | 真实 run 脱敏检查 | 规则已定义，未验证远端 |
| 失败与回退 | G1.1 ref/tag 可回退 | 本地失败停止/恢复演练 | 失败 run、上一 ref、回退记录 | 未开始 |

证据等级规则：`本地静态` 只能证明文件、候选和扫描；`本地等价` 只能证明相同命令合同在本地复现；只有真实 GitHub Actions run 才能填充远端 CI 证据。任一较弱证据不能升级为较强证据。

## 6. Failure policy

- `install`、`typecheck`、`lint` 或 `build` 任一步失败，整个 job 失败并停止后续门；不得用 `continue-on-error` 把失败伪装为通过。
- 依赖安装失败时，保留最小错误摘要和 ref，禁止在日志中复制 token、URL 或完整环境内容；先修复或回退，再重新运行。
- 若发现 action SHA 无法从官方 release 核对、Node/pnpm 漂移、workflow 权限超出 `contents: read`、出现 secret/PII、触发器使用 `pull_request_target`，立即阻止 G1.2b 晋级。
- `unrs-resolver@1.12.2` 的 ignored build-script warning 当前记录为非阻塞 warning；不得自动执行 approve-builds/allowlist。需要放行时，暂停该批并开供应链审查。
- CI 失败不得生成 Preview 部署入口、发布候选或业务验收结论；G1 Exit 仍保持未通过。

## 7. Secret、日志和数据边界

本批只记录变量名和规则，不读取或创建值。候选 workflow 不声明 secrets、不传递 `.env`、不连接 Supabase/Auth、不访问数据库、不上传 artifact。日志仅保留命令名称、版本、退出状态、runner/ref 和最小错误摘要；路径、依赖输出和 Next build 输出如包含本机信息，应在保存前脱敏。

如果预检或未来 run 发现 secret、PII、生产 URL 或真实业务资料进入日志、artifact、workflow 或文档：立即停止晋级，撤销可见入口，保存最小脱敏事件摘要，追加阶段记录并请求 Owner 决定恢复。不得用删除日志或重新运行掩盖暴露。

## 8. 回退与维护

### 回退

- G1.2a 若 Owner 通过后创建本地 workflow，错误 workflow 只通过删除或回退该本地 workflow commit 恢复；不修改、不删除、不重写 G1.1 已记录的 ref/tag。
- G1.2b 若未来 remote/CI 已获单独授权，失败 run 只停止晋级并回退到上一可验证 ref；不得在无 Owner 决定时删除 remote、覆盖分支或删除审计证据。
- 本批没有 workflow commit、remote、run 或 Preview，因此当前回退动作仅为保留本记录并等待 Owner 决定。

### 维护

- 每次 GitHub Actions、Node、pnpm、runner、lockfile 或 package scripts 变更，都要更新阶段记录和证据矩阵。
- 定期从官方仓库复核 action v7 release 对应完整 SHA、runner 可用性和安全公告；发现 release/tag 或 SHA 变化时先复核再更新。
- 首次 cache 仍关闭；只有形成缓存键、失效、污染、权限和回退记录后，才可另行提交 cache 方案。
- 依赖 build scripts 维持显式供应链审查，不把 warning 处理偷换成全局 approve-builds。

## 9. Owner 决策点与推荐授权语句

Owner 需要明确：

1. 是否接受 GitHub Actions 作为 G1.2 候选平台。
2. 是否接受 `ubuntu-24.04`、Node `22.12.0`、pnpm `10.33.3`/Corepack、`prototype` working-directory 和 15 分钟 timeout。
3. 是否接受 `pull_request` + `push main`，并明确禁止 `pull_request_target`。
4. 是否接受只读权限、不注入 secrets、首次关闭 cache、无 health/artifact/deploy 的最小边界。
5. 是否授权 G1.2a 在本地创建 workflow 并做本地等价验证；这项授权不包含 remote、push、远端 CI、Preview、Supabase 或生产。

推荐 Owner 授权语句：

> `批准进入G1.2a：采用GitHub Actions候选，在本地创建只读最小CI工作流并做本地等价验证；暂不添加remote、不push、不运行远端CI、不部署Preview、不接Supabase或生产。`

当前 Gate：`待 Owner Gate`。在获得上述明确授权前，不创建 `.github/` workflow，不执行 G1.2a；在 G1.2a 完成后，仍需另行决定 G1.2b 的 remote 和真实 CI 运行。

## 10. 本批验证与跳过项

| 检查 | 结果 | 说明 |
|---|---|---|
| 原型源码、package、lockfile | 未修改 | 复用 G1.1 证据；本批只写 Markdown |
| `.github/**` | 无结果 | 只读确认当前仍未创建 CI |
| remote / Preview / Supabase / Production | 未创建、未连接 | 本批禁止外部写入 |
| G1.1 install/typecheck/lint/build | 复用既有证据 | source/config/lockfile 未变化；不把复用写成 G1.2 CI 通过 |
| G1.2a workflow 等价验证 | 未运行 | 等 Owner 授权创建 workflow |
| G1.2b 真实 CI run | 未运行 | 当前无 remote 且本批未授权 |
| Markdown 链接、fragment、围栏、状态一致性和敏感模式 | 待本批提交后运行 | 仅覆盖文档变更；不得扩大为代码或 CI 验证 |

本证据记录完成后，G1 仍为“执行中（G1.1 已完成，G1.2 预检完成，待 Owner Gate）”；G1 Exit 未通过，G2-A0/G2-A1/P2–P8 仍未打开。
