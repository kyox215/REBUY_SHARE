# G1.3-1 Provider、CLI 与 Preview 部署前隔离预检

阶段：G1 工程底座与环境隔离
批次：G1.3-1 provider 只读盘点、CLI 语法核对与 Preview 部署前隔离预检
状态：`G1.3-1 provider/CLI/隔离预检完成；G1.3 Preview 实施待 Owner Gate；G1 Exit NO-GO；G2-A0 不打开`
证据级别：远端 provider 只读 + 本地静态 + Git archive 临时隔离
记录日期：2026-08-27（Europe/Rome）
执行分支：`codex/g1-3-preview`（仅本地，未 push、未创建 PR）
验证 ref：`main@af6d7419956ce6640c0b4af5df4db0369e793f77`
deploy/environment ref：`N/A`（本批未部署）

> 本记录只证明在不写入 provider、不建立 Preview、不连接 Supabase/Auth/DB 的前提下完成了部署前盘点、CLI 语法核对和临时归档验证。没有读取、记录或输出 host、key、token、cookie、secret、环境变量值、PII 或原始 provider 日志。外部状态仅记录认证只读得到的最小事实，不从本地未绑定推断不存在。

## 1. 本批范围与安全边界

- 从 clean `main@af6d741` 创建本地 `codex/g1-3-preview`，仅用于本地文档收口；未 push、未创建 PR、未修改远端 ref。
- 完整读取 `prototype/AGENTS.md` 及本地 Next.js 16 相关部署、项目结构和 Route Handler 指南；本批不写 Next.js 代码。
- 仅核对 Git ref、项目 root、Node/pnpm 合同、workflow 成功证据、忽略规则、健康路由和 provider 只读事实。
- 未执行 `vercel login`、`vercel link`、`vercel deploy`、`vercel promote`、`vercel rollback` 或项目设置修改；未写入 `.vercel/`。
- 未创建、连接或写入 Supabase、Auth、DB、Storage、Staging、Production；旧 Production alias 未被本批动作改变。

## 2. Provider 只读盘点

### 2.1 Vercel

| 项目 | 只读事实 | 本批动作 |
|---|---|---|
| Team | `kyox120-9295's projects`；ID `team_AOJDnrjov0QDLqpvMyhwA1yc`；Pro | 未改 team、成员、计费或权限 |
| Project | `rebuy-share`；ID `prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL` | 未改项目设置 |
| 已知 Deployment | 仅有旧 `READY`、`target=production` deployment：`dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` | 未 inspect、promote、rollback 或替换 alias |
| Node / Git link | 项目设置显示 Node `24.x`；无 Git link | 未改 Node、Git link 或 Root Directory |

以上为主代理已完成的实时只读核验结果。本批只把事实写入脱敏证据，不记录 deployment URL、环境变量、密钥或任何 provider 凭据。

### 2.2 Supabase

| 项目 | 只读事实 | 本批动作 |
|---|---|---|
| Organization | 唯一 org `kyox120-9295's projects`；Pro | 未创建或修改组织/项目 |
| 项目清单 | 仅有无关项目 `ChinaTech_date` 与 `PartsPro-V4`；没有 Rebuy 项目 | 未触碰任何项目 |

未读取或输出 Supabase host、key、token、环境值、Auth/DB/Storage 数据。以上事实不授权后续连接或写入。

## 3. Rebuy 本地 ref、目录与 CI 合同

- G1.3-1 预检输入时 `main`/`HEAD` 均为 `af6d7419956ce6640c0b4af5df4db0369e793f77`；文档收口分支/commit 另见本文头部与当前 Git 记录；本批工作树保持 clean。
- App Root 固定为 `prototype/`；存在 `prototype/app`、`prototype/package.json`、`prototype/pnpm-lock.yaml` 和 `prototype/next.config.ts`。
- `prototype/package.json` 声明 `engines.node=22.x`、`engines.pnpm=10.33.3`、`packageManager=pnpm@10.33.3`；`.node-version` 为 `22`。
- 健康路由为 `/api/health/supabase`。未注入 Supabase 变量时该路由按 fail-closed 合同返回未配置结果，不能替代根页面或关键无外部依赖页面的 Preview health。
- `.gitignore` 忽略 `.env*`（保留 `.env.example`）、`.vercel/`、`.supabase/`、依赖和 Next 构建输出；`.env.example` 只确认变量名 `NEXT_PUBLIC_SUPABASE_URL` 与 `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`，未读取值。
- GitHub Actions 成功证据：main push run [33034314565](https://github.com/kyox215/REBUY_SHARE/actions/runs/33034314565)，job [98393579170](https://github.com/kyox215/REBUY_SHARE/actions/runs/33034314565/job/98393579170)，install、typecheck、lint、build 均 `SUCCESS`。

## 4. main archive 临时隔离验证

使用 `git archive --format=tar main@af6d7419956ce6640c0b4af5df4db0369e793f77` 解包到一次性 `/private/tmp/rebuy-g13-preflight.XXXXXX` 目录，在归档副本的 `prototype/` 中执行 workflow 等价命令。临时工具、缓存和解包目录均已清理，当前仓库未产生文件变更。

| 检查 | 结果 |
|---|---|
| Node | `v22.12.0`，通过 |
| Corepack | `0.34.6`，通过 exact npm bootstrap |
| pnpm | `10.33.3`，通过 |
| `pnpm install --frozen-lockfile` | 退出 0，通过 |
| `pnpm typecheck` | 退出 0，通过 |
| `pnpm lint` | 退出 0，通过 |
| `pnpm build` | 退出 0，通过；Next `16.3.2` |
| warning | 仅保留 pnpm 忽略 `unrs-resolver` 构建脚本的 warning；未执行 `approve-builds` |

默认沙箱首次从 npm registry 获取 Corepack 时发生 DNS `ENOTFOUND`；仅进行一次受控临时目录重试后完成，未循环重试，未写入仓库或 provider。

## 5. Vercel CLI 只读语法核对

| 命令 | 结果 |
|---|---|
| `command -v vercel` | `/Users/kyox215/.nvm/versions/node/v20.20.2/bin/vercel` |
| `vercel --version` | `Vercel CLI 53.1.1`，退出 0 |
| `vercel whoami` | 退出 0 但无可确认身份输出；不据此宣称已登录 |
| `vercel deploy --help` | 已核对 `--cwd`、`--scope`、`--target`、`--yes`、`--prod` 等实际语法；未执行部署 |
| `vercel link --help` | 已核对 `--cwd`、`--team`、`--project`、`--scope`、`--yes` 等实际语法；未执行 link |
| `vercel inspect --help` | 已核对 deployment id/URL、`--scope`、`--wait`、`--timeout`、`--format=json`；未执行 inspect |

CLI help 期间后台更新器尝试写用户缓存并产生 `EPERM`，不影响 help 语法输出；本批未登录、未写 `.vercel`、未读取 token/cookie/password。`--prod` 仅作为禁止项记录，后续 Preview 草案不得使用。

## 6. Node 设置结论

前置审查引用的官方 Vercel 规则将 `package.json` 的 `engines.node` 作为项目 Node 版本合同来源之一；但本地 `engines.node=22.x` 不等于已经修改或覆盖 Vercel project setting。实时只读项目仍显示 Node `24.x`，因此不能假定 Preview 会按 Node 22 运行。

G1.3 实施前必须由 Owner 明确是否把现有 project 默认 Node 从 `24.x` 调整为 `22.x`；若保留 `24.x`，必须另有兼容性决定并以新的 Vercel build logs 实证。当前推荐路径为 Node 22 与本地/CI 合同一致，且只建立显式 Preview。

## 7. 可执行 Preview 命令草案（本批未执行）

只有 Owner Gate 明确批准 Node 策略、费用、访问和停止入口后，才可在现有 project 上运行：

```bash
vercel link \
  --cwd "/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划/prototype" \
  --yes \
  --team team_AOJDnrjov0QDLqpvMyhwA1yc \
  --project prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL

vercel deploy \
  --cwd "/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划/prototype" \
  --scope team_AOJDnrjov0QDLqpvMyhwA1yc \
  --target=preview \
  --yes
```

`vercel link` 会写入本地 `.vercel/`，因此它不属于本批授权；部署时必须使用既有 project、`Root=prototype`、`Target=preview` 和 `main@af6d741`，不得使用 `--prod`，不得注入任何 Supabase/Auth/DB/PII 环境值，旧 Production alias 必须保持不变。

部署后仅对已返回的 Preview deployment id/URL 做只读检查：

```bash
vercel inspect <preview-url-or-deployment-id> \
  --scope team_AOJDnrjov0QDLqpvMyhwA1yc \
  --wait --timeout 90s --format=json
```

## 8. Preview 部署前后检查清单

### 部署前

1. Owner 书面确认 team、project、Pro 用量、访问角色、停止入口和 Node `24.x → 22.x` 候选变更。
2. 重新核对 `main@af6d741`、main Actions run/job 成功、工作树 clean、`Root=prototype` 和 lockfile/toolchain 合同。
3. 确认 Target 只能是 `preview`；不使用 `--prod`，不推广 alias，不改旧 Production deployment。
4. 确认 Preview 不注入 Supabase/Auth/DB/PII 环境值；变量只登记名称/来源，不记录值。
5. 明确 Preview 访问、日志脱敏、停止入口与 bad/good ref 记录方式。

### 部署后

1. `inspect --wait --format=json` 核对 deployment target、project、ref/commit、Node/build 状态和错误摘要，不复制完整日志或环境值。
2. 只访问根页面和关键无外部依赖页面，检查 HTTP、静态资源、浏览器控制台和基本交互；不以未配置 Supabase 的 503 health 响应宣称部署成功。
3. 核对 Preview URL 未成为 Production alias，旧 Production deployment/alias 未变化，未产生外部数据写入。
4. 保存最小脱敏证据：deployment id、ref、target、时间、步骤结论和风险；不保存 URL 中的敏感 query、cookie、token 或 PII。

## 9. bad → good Preview 回退演练方案

本批未执行在线演练。未来在单独 Owner Gate 下只在隔离 Preview 中进行：

1. 先从明确标注的 bad ref 建立独立 Preview，不推广 alias、不接 Production 数据；记录 ref、target 和最小故障类别。
2. 一旦出现构建、页面、越界、变量泄露或日志风险，立即停止晋级，保留脱敏失败摘要，不复制完整日志或 secret。
3. 从已通过 CI 的 `main@af6d741` good ref 重新建立独立 Preview，先 inspect，再检查根页面、关键无外部依赖页面、访问边界和日志脱敏。
4. good Preview 通过后保留 bad/good ref 与观察窗口记录；不执行 `promote`、Production alias 切换或生产回滚。
5. 若 good 验证失败，维持停止状态并升级 Owner Gate；不得 force、delete、reset 或改写 Git 历史。

该演练是“bad Preview → good Preview”的受控恢复，不证明 Production rollback；旧 Production alias 在整个 G1.3-1 范围内保持不变。

## 10. 当前 Gate 与剩余风险

- G1.3-1 provider、CLI、Node 结论和临时隔离预检完成；G1.3 Preview 实施仍待 Owner Gate。
- G1 Exit 保持 `NO-GO`；G2-A0/G2-A1/P2–P8 不打开。
- 主要未决项是 Vercel project Node `24.x` 与项目/CI Node `22.x` 的策略一致性、Preview 费用/访问/停止入口和在线 bad→good 证据。
- 当前没有 Preview、Staging 或 Production 写入；没有 Supabase/Auth/DB 连接；没有环境值、PII 或 secret 证据。
- 本批未修改 `prototype/**`、workflow、package、lockfile、`.env.example`、`.gitignore`、Git remote 或 provider 设置。

推荐 Owner Gate 语句：

> `批准进入G1.3 Preview：确认 Vercel team kyox120-9295's projects（team_AOJDnrjov0QDLqpvMyhwA1yc）与 project rebuy-share（prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL）；确认当前 project Node24.x，并授权评估/执行 Node24.x→22.x 候选变更，要求以新的 build logs 实证；仅使用已通过 CI 的 main@af6d7419956ce6640c0b4af5df4db0369e793f77，Root Directory=prototype，Target=Preview；按 Pro 正常 build/compute 用量执行；不得改变 Production alias，不注入 Supabase/Auth/DB/PII 或任何环境值；完成受控 bad ref→good ref Preview 演练和脱敏证据；不接 Staging、Production 或真实业务数据。`

关联记录：[G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[G1.3-0 本地环境预检](../2026-08-26-g1-3-0-local-environment-preflight/README.md)、[15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)、[Prototype quality workflow](../../../../.github/workflows/prototype-quality.yml)。
