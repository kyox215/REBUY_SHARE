# G1.2b 远端 PR 与 GitHub Actions 证据

阶段：G1 工程底座与环境隔离
批次：G1.2b 受限 integration/PR/真实 CI 运行
状态：`G1.2b 真实 PR/CI 已完成；PR 保持 OPEN；G1.3 未开始；G1 Exit 仍 NO-GO`
证据级别：远端 GitHub Actions + 远端只读设置 + 本地 Git/质量/发布前审计
记录日期：2026-08-27（Europe/Rome）
记录角色：远端执行代理整理；主代理独立复审
canonical repo：`kyox215/REBUY_SHARE`（public）
当前环境：公开 GitHub PR；无 Preview、Supabase/Auth/DB、Staging、Production 连接

> 本记录只证明一次受限的公开 integration 分支、PR 和真实 GitHub Actions run。它不证明 PR 已合并、G1 Exit 已通过、Preview/生产可用或任何 Supabase/Auth/DB 能力已实施。

## 1. Owner 授权与实际边界

本批依据 Owner 的公开上传与 PR/CI 授权原话：

> `我确认允许将当前 Rebuy 本地仓库的源码、项目文档、Git 历史和图片公开上传到公开仓库 kyox215/REBUY_SHARE；允许推送 integration/g1-2b、创建 PR、运行 GitHub Actions，验证通过后以非强制方式合并到远端 main；禁止 force-push、删除远端历史、部署 Preview、连接 Supabase/Auth/DB 或生产。`

CLI Workflow scope 授权原话：

> `允许本次 GitHub CLI 为 kyox215 获取 Workflow scope，仅用于向 kyox215/REBUY_SHARE 推送 .github/workflows/prototype-quality.yml 并运行本次 Actions；不得用于其他仓库或修改其他工作流。`

实际执行进一步保持复审边界：本批未合并 `main`，PR 仍保持 OPEN；不 force-push、不删除或改写远端历史，不读取 secrets，不部署 Preview，不连接 Supabase/Auth/DB、Staging 或 Production。公开源码、文档和图片已按上述授权进入 public repository。

## 2. 实时远端核对与历史保全

本批开始前重新只读核对远端 refs、PR、初始 Actions run 和 Actions settings，结果未漂移：

| 项目 | 结果 |
|---|---|
| canonical repository | `kyox215/REBUY_SHARE`；public；默认分支 `main` |
| 远端 `main` | `366ad7f287a00f795c742d7f2df10a531fa42e7c`；未被本批改变 |
| 本地 `main` | `e914e146d571d1258dd314599e1b868f5852e30d` |
| integration 候选（初始 PR head） | `f746dcacc0afc2d45b847346f20078a159c2e032` |
| integration parent 1 | 远端 `main`：`366ad7f287a00f795c742d7f2df10a531fa42e7c` |
| integration parent 2 | 本地 `main`：`e914e146d571d1258dd314599e1b868f5852e30d` |
| integration tree（初始 PR head） | `10e4f674159490ec9a474de40bc81231c324a311` |
| 历史策略 | 双 parent 保留远端与本地历史；未使用 force-push 或覆盖远端 `main` |

PR：[kyox215/REBUY_SHARE#1](https://github.com/kyox215/REBUY_SHARE/pull/1)

| PR 字段 | 实时结果 |
|---|---|
| number / state | `1` / `OPEN` |
| base | `main` @ `366ad7f287a00f795c742d7f2df10a531fa42e7c` |
| head（初始 CI run） | `integration/g1-2b` @ `f746dcacc0afc2d45b847346f20078a159c2e032` |
| merge state | `CLEAN`；本批不合并 |

本证据提交会使 PR head 前进并触发后续 PR 检查。为避免“把最新 run ID 写回文档→再次触发 run”的递归，本记录固定保留初始 CI run 与其验证的 `f746dca`；更新后 head 的 PR 检查结果作为独立实时状态报告，不回写本文件。

## 3. 初始真实 Actions run

Run：[33027593355](https://github.com/kyox215/REBUY_SHARE/actions/runs/33027593355)
Job：[prototype-quality / 98372467897](https://github.com/kyox215/REBUY_SHARE/actions/runs/33027593355/job/98372467897)

| 字段 | 结果 |
|---|---|
| workflow | `Prototype quality` |
| event | `pull_request` |
| branch | `integration/g1-2b` |
| head SHA | `f746dcacc0afc2d45b847346f20078a159c2e032` |
| run status/conclusion | `completed` / `success` |
| job status/conclusion | `completed` / `success` |
| 运行窗口 | 2026-08-27 00:39:54Z–00:40:37Z；约 37 秒 |
| steps | Set up job、Checkout、Setup Node.js、Bootstrap compatible Corepack、Verify Corepack and pnpm、Install dependencies、Typecheck、Lint、Build、post steps 全部 success |

该 run 证明真实 GitHub-hosted runner 在 `f746dca` 上完成 install → typecheck → lint → build；不证明后续新文档 head 的检查已通过，后者必须以 PR 当前 check 为准。

## 4. Actions 权限与工作流边界

通过已认证 CLI 的只读 GET 核对：

| 设置 | 实时结果 |
|---|---|
| Actions enabled | `true` |
| allowed actions | `all` |
| SHA enforcement | `false` |
| default workflow permissions | `read` |
| can approve pull request reviews | `false` |
| selected-actions endpoint | 返回 `409 Conflict: All actions and workflows are allowed on this repository`；按仓库状态记录为 all，不推断 allowlist |

仓库级 `allowed_actions=all` 和 `sha_pinning_required=false` 是治理风险；本项目 workflow 当前仍把 `actions/checkout` 与 `actions/setup-node` 固定为完整 40 位 SHA，且顶层仅声明 `contents: read`。本记录不修改仓库 Actions 设置。

工作流静态边界复核：

- 触发器为 `pull_request` 与推送到 `main`；无 `pull_request_target`、`workflow_run` 或手工越界触发器。
- runner 为 `ubuntu-24.04`，job timeout 为 15 分钟，working-directory 为 `prototype`。
- Corepack `0.34.6`、pnpm `10.33.3`、frozen install、typecheck、lint、build 顺序与本地合同一致。
- 无 secrets、environment、artifact、health probe、Preview、Supabase/Auth/DB、Production 或部署步骤；`persist-credentials: false` 保持。

## 5. 发布前敏感与大文件审计

审计对象为当前 integration 候选及其双 parent 可达历史；只输出计数和人工分类，不复制命中值：

| 历史侧 | 可达 commit 数 | unique blob 数 | 禁止路径风险（排除允许的 `prototype/.env.example`） | literal secret pattern | 最大 blob | >20 MiB |
|---|---:|---:|---:|---:|---|---:|
| 本地 `main` | 26 | 206 | 0 | 0 | 1,275,681 bytes；`prototype/public/product-sprite.png` | 0 |
| 远端 `main` | 3 | 51 | 0 | 0 | 1,275,681 bytes；`prototype/public/product-sprite.png` | 0 |
| integration 候选 | 30 | 227 | 0 | 0 | 1,275,681 bytes；`prototype/public/product-sprite.png` | 0 |

扫描范围包括 `.env*`（仅允许 `prototype/.env.example`）、`node_modules`、`.next`、`.pnpm-store`、`.vercel`、`.supabase`、私钥/证书、数据库 dump、明显临时路径，以及 GitHub/Supabase/OpenAI token、JWT、private-key block 等字面模式。未发现真实 secret value、PII、禁止路径或需要大文件处置的对象。此前审计中两处 `runtime_field_reference` 仍是运行时配置字段引用，不是 secret value；详见[G1.2b-1 历史审计](../2026-08-26-g1-2b-1-local-integration-rehearsal/README.md)。

## 6. 本地质量门与证据复用

在代码、依赖、lockfile、workflow 和工具链未因本批改变的前提下，复用并核对既有本地质量证据：

| 检查 | 结果 |
|---|---|
| Node / npm | `v22.12.0` / `10.9.0` |
| Corepack / pnpm | `0.34.6` / `10.33.3` |
| `pnpm install --frozen-lockfile` | 退出 0 |
| `pnpm typecheck` | 退出 0 |
| `pnpm lint` | 退出 0 |
| `pnpm build` | 退出 0 |

本地详细证据见[G1.2a workflow/等价验证](../2026-08-26-g1-2a-local-workflow/README.md)。初始真实 run 另行证明了 GitHub runner 的相同质量顺序；本批文档提交后不重复执行本地代码门，也不把初始 run 冒充更新 head 的 run。

## 7. 风险、回退与维护

### 风险

- PR 尚未合并，远端 `main` 仍保持 `366ad7f...`；G1.2b 已有初始真实 CI 成功，但 G1 Exit 仍缺 Preview 实际部署、在线 bad ref → good ref 回退和 Owner Exit 签署。
- `allowed_actions=all`、SHA enforcement 为 `false`；仓库设置比项目 workflow 自身更宽，后续应由 Owner/治理专项决定是否收紧。
- 公开上传已发生；本仓库源码、文档、Git 历史和图片按 Owner 授权公开可见。敏感审计不替代 GitHub secret scanning 或未来真实环境变量审查。
- 本证据固定的是 run `33027593355` 对 `f746dca` 的结果；更新后的 docs head 必须单独确认 PR check，不能由本条预填成功。

### 回退

- 本批不修改、不删除远端 `main`；若文档提交需撤回，只在 integration 分支通过后续普通 revert 形成可追溯回退，不 force-push、不改写历史。
- PR 保持 OPEN，等待独立审查；不以关闭、删除分支或覆盖 `main` 作为默认回退。
- 若未来 Actions 失败，停止晋级并保留失败 run/ref 的最小脱敏摘要；先修复或回退 workflow/docs，再另开 Owner Gate。

### 维护

- 15 台账继续作为唯一当前状态源；后续状态更新先改 15，再同步 G1 清单、阶段合同和导航摘要。
- action、Node、pnpm、runner、lockfile、package scripts 或 Actions 设置变化时，重新做官方 pin、权限、敏感和大文件审计；不静默替换版本或放宽权限。
- 新 PR head 的 check 只作为本次文档提交的独立验证记录，不反复改写本文件；如出现新的实质风险，新增日期记录并关联新 run。

## 8. 当前阶段结论与边界

当前结论：`G1.2b 真实 PR/CI 已完成；PR #1 OPEN；G1.3 未开始；G1 Exit NO-GO；G2-A0 不打开`。

- G1.2b 仅完成一次受限的 canonical public repo integration/PR/Actions 验证。
- G1.3 Preview、环境资源、health、访问、日志和在线回退仍未开始，需新的 Owner Gate。
- G1 Exit 尚未通过，G2-A0、G2-A1、P2–P8 不因本 run 自动打开。
- 本批没有合并 `main`、部署 Preview、连接 Supabase/Auth/DB、读取 secrets、触碰 Staging/Production 或写入真实业务数据。

关联记录：[G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[G1 Exit 本地预检](../2026-08-26-g1-exit-preflight/README.md)、[15 台账](../../../15-项目状态与阶段台账.md)、[阶段索引](../../../stages/README.md)。
