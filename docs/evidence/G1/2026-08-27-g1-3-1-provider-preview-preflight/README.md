# G1.3-1 Provider、CLI 与 Preview 部署前隔离预检

阶段：G1 工程底座与环境隔离
批次：G1.3-1 provider 只读盘点、CLI 语法核对与 Preview 部署前隔离预检
状态：`G1.3-1 provider/CLI/隔离预检完成；G1.3 preflight GO；G1.3 rehearsal Entry GO；Preview 实施尚未完成；G1 Exit NO-GO；G2-A0 不打开`
证据级别：远端 provider 只读 + 本地静态 + Git archive 临时隔离
记录日期：2026-08-27（Europe/Rome）
执行分支：`codex/g1-3-preview`（仅本地，未 push、未创建 PR）
验证 ref：`main@af6d7419956ce6640c0b4af5df4db0369e793f77`
deploy/environment ref：`N/A`（本批未部署）

> 本记录只证明在不写入 provider、不建立 Preview、不连接 Supabase/Auth/DB 的前提下完成了部署前盘点、CLI 语法核对和临时归档验证。没有读取、记录或输出 host、key、token、cookie、secret、环境变量值、PII 或原始 provider 日志。外部状态仅记录认证只读得到的最小事实，不从本地未绑定推断不存在。

> 2026-08-27 高风险独立审查纠正：原 Preview 执行草案因 Node 版本、`rootDirectory`、变量存在性、Deployment Protection 和 bad→good 回退入口表述不严密，审查结论为 `NO-GO`；修正后的执行合同见 [G1.3-2 Preview execution review](../2026-08-27-g1-3-2-preview-execution-review/README.md)。修正后为条件 `GO`，并由 Owner Gate 批准进入受限 implementation；本批只读预检结论为 `GO`、rehearsal Entry 门为 `GO`，不等于 Preview 已部署或 G1 Exit 已通过。

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
| Node / root / Git link | 项目设置 Node `24.x`；provider `rootDirectory=prototype`；无 Git link | 未改 Node、Git link、Root Directory 或项目设置 |
| Preview env / Protection | Preview env 只读脱敏计数为 `0`；Deployment Protection=`Standard` + `Require Log In` | 未读取 value；未关闭或改弱 Protection |
| Production / aliases | 旧 `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` 为 `target=production`、`READY`；latest production ID 相同；aliases 数量 `2`，排序后 SHA-256=`c06eeb6c408c562d7d6906cf1ccd71776beea381afae47e94547c696133f79aa` | 仅只读核对；未输出 alias 字符串/URL，未替换或推广 alias |

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
- GitHub 只读证据：`origin/main=af6d7419956ce6640c0b4af5df4db0369e793f77`，与预检批准基线无漂移；main push run [33034314565](https://github.com/kyox215/REBUY_SHARE/actions/runs/33034314565)，job [98393579170](https://github.com/kyox215/REBUY_SHARE/actions/runs/33034314565/job/98393579170)，latest main Actions `head_sha` 与该 SHA 相符、状态 `success`，install、typecheck、lint、build 均 `SUCCESS`。

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
| `vercel whoami` | 默认既有全局配置已认证，用户精确为 `kyox120-9295`；未创建新的 OAuth token，device UI 未获授权且无凭据记录；未读取 auth 文件/token/cookie，仅使用既有认证做只读核对 |
| `vercel deploy --help` | 已核对 `--cwd`、`--scope`、`--target`、`--yes`、`--prod` 等实际语法；未执行部署 |
| `vercel link --help` | 已核对 `--cwd`、`--team`、`--project`、`--scope`、`--yes` 等实际语法；未执行 link |
| `vercel inspect --help` | 已核对 deployment id/URL、`--scope`、`--wait`、`--timeout`、`--format=json`；未执行 inspect |

CLI help 期间后台更新器尝试写用户缓存并产生 `EPERM`，不影响 help 语法输出；本批未登录、未写 `.vercel`、未读取 token/cookie/password。`--prod` 仅作为禁止项记录，后续 Preview 草案不得使用。

## 6. Node 设置结论

按 Vercel 官方 Node 版本规则，`package.json` 的 `engines.node=22.x` 覆盖 project 层面当前显示的 Node `24.x`，因此默认不 PATCH project Node 设置。Preview 执行仍必须在新的 build log 中核对实际 Node 主版本为 `22`；若 build log 显示非 Node 22，立即停止，不自动修改 project 设置，另开 Owner 决策。

这一区分的是“部署构建时的应用版本请求”与“project UI 当前默认值”：当前 project 的 Node `24.x` 只读事实保留，但不再作为必须先改成 22 的前置条件。当前没有新的 Vercel build log，不能把 Node 22 写成 Preview 已实证。

## 7. 可执行 Preview 命令草案（本批未执行）

只有 Owner Gate 明确批准 Node 策略、费用、访问和停止入口后，才可在现有 project 上运行：

```bash
ARCHIVE_REF=af6d7419956ce6640c0b4af5df4db0369e793f77
ARCHIVE_DIR="$(mktemp -d /private/tmp/rebuy-g13-2-archive.XXXXXX)"
git archive --format=tar "$ARCHIVE_REF" | tar -xf - -C "$ARCHIVE_DIR"
cd "$ARCHIVE_DIR"

vercel link \
  --scope team_AOJDnrjov0QDLqpvMyhwA1yc \
  --project prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL \
  --yes

vercel deploy \
  --scope team_AOJDnrjov0QDLqpvMyhwA1yc \
  --target=preview \
  --yes
```

该草案必须从精确 `git archive` SHA 的临时副本的仓库根执行 CLI：使用 `cd "$ARCHIVE_DIR"`，禁止从 `"$ARCHIVE_DIR/prototype"` 执行，以免 provider `rootDirectory=prototype` 造成 `prototype/prototype`。provider project 的 `rootDirectory=prototype` 保持不变，不做 PATCH；`vercel link` 产生的 `.vercel/` 只能存在于临时副本并在结束后清理。部署只使用既有 project、`Target=preview` 和 `main@af6d741`，不得使用 `--prod`、promote 或 rollback。

Preview 前只读核对应用变量的名称与 target，不读取任何变量值；任一应用变量在 team/project/Preview target 中存在即停止，不删除、不修改、不绕过后继续 deploy。当前只允许登记 `.env.example` 已观察到的变量名 `NEXT_PUBLIC_SUPABASE_URL`、`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` 及 target，不写值。

部署后仅对已返回的 Preview deployment id/URL 做只读检查：

```bash
vercel inspect <preview-url-or-deployment-id> \
  --scope team_AOJDnrjov0QDLqpvMyhwA1yc \
  --wait --timeout 90s --format=json

vercel curl / \
  --deployment <preview-url-or-deployment-id> \
  --scope team_AOJDnrjov0QDLqpvMyhwA1yc \
  --yes
```

Deployment Protection 不得关闭或改弱；部署后使用 `vercel curl` 访问根页面及必要的无外部依赖路径，不把保护绕过 secret 写入文档。若 CLI 不能在不读取/记录凭据的前提下访问，停止并回到 Owner Gate。

## 8. Preview 部署前后检查清单

### 部署前

1. Owner 书面确认 team、project、Pro 用量、访问角色和停止入口；project Node `24.x` 默认不 PATCH，由 build log 实证 `engines.node=22.x` 实际生效。
2. 从精确 `main@af6d741` 建立临时 archive，重新核对 main Actions run/job、工作树 clean、仓库根执行 cwd 和 lockfile/toolchain 合同；provider `rootDirectory=prototype` 保持不变，禁止从 archive 的 `prototype/` 子目录执行 CLI。
3. 只读核对变量名称与 target；本次预检结果为 Preview env `0`；未来任一应用变量存在即停止，不读取值、不删除变量、不继续 deploy。
4. 确认 Target 只能是 `preview`；不使用 `--prod`、不推广 alias、不改旧 Production deployment，也不关闭 Deployment Protection。
5. 部署前后对旧 production deployment `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` 和 aliases 做只读核对，保存不含 alias/URL 值的映射 fingerprint；前后不一致即停止。
6. 明确使用 `vercel curl` 的 Preview 访问、日志脱敏、停止入口与 bad/good ref 记录方式。

### 部署后

1. `inspect --wait --format=json` 核对 deployment target、project、ref/commit、Node/build 状态和错误摘要；必须从 build log 摘要确认 Node `22`，不复制完整日志或环境值。
2. 不关闭 Deployment Protection，使用 `vercel curl` 访问根页面和关键无外部依赖页面，检查 HTTP、静态资源、浏览器控制台和基本交互；不以未配置 Supabase 的 503 health 响应宣称部署成功。
3. 再次只读核对旧 production deployment/aliases fingerprint 与部署前一致，Preview URL 未成为 Production alias，未产生外部数据写入。
4. 保存最小脱敏证据：deployment id、ref、target、时间、Node/build 结论和风险；不保存 URL 中的敏感 query、cookie、token、保护 secret 或 PII。

## 9. bad → good Preview 回退演练方案

本批未执行在线演练。未来在单独 Owner Gate 下只在隔离 Preview 中进行，且必须把演练 PR 与长期 good route 分开：

1. 从明确标注的 `g1-3-preview-bad503` 演练分支建立 `DO NOT MERGE` Draft PR；PR 永不转 Ready、永不 merge，bad Preview 只记录预期 `503` 故障类别和最小脱敏证据。
2. 一旦出现构建、页面、越界、变量泄露或日志风险，立即停止晋级，保留脱敏失败摘要，不复制完整日志或 secret；关闭该 Draft PR 但保留演练分支和审计证据，不删除历史。
3. 从干净 `main@af6d741` 或最终集成分支另行建立 `good200` 的独立普通 PR，使用精确 archive/ref 建立独立 Preview，先 inspect，再以 `vercel curl` 检查根页面、关键无外部依赖页面、访问边界和日志脱敏；后续永久 good route 仍沿这条独立干净 PR 路径，不复用 bad503 PR。
4. good Preview 通过后保留 bad/good ref 与观察窗口记录；不执行 `promote`、Production alias 切换或生产回滚。长期 good route 不携带 bad 演练分支提交。
5. 若 good 验证失败，维持停止状态并升级 Owner Gate；不得 force、delete、reset 或改写 Git 历史。

该演练是“bad503 Preview → good200 Preview”的受控恢复，不证明 Production rollback；旧 production deployment/aliases fingerprint 在整个流程前后必须不变。

## 10. 当前 Gate 与剩余风险

- G1.3-1 provider、CLI、Node 结论和临时隔离预检完成；G1.3-2 高风险独立审查原方案为 `NO-GO`，修正后为条件 `GO`；本次 G1.3 external preflight 与 rehearsal Entry 门均为 `GO`，但不等于 Preview 已部署或 G1 Exit 已通过。
- G1 Exit 保持 `NO-GO`；G2-A0/G2-A1/P2–P8 不打开。
- 主要未决项是新 Preview build log 是否实证 Node `22`、实际 Preview/PR/Actions/deploy、在线 bad→good 证据与持续费用/访问/停止记录；project Node `24.x` 默认不 PATCH。
- G1.3 修正版 Owner Gate 已批准；本批使用默认既有 Vercel auth 做只读核对，未创建新 OAuth token，device UI 未获授权且无凭据记录；未 push、未创建 PR、未 deploy；没有 Preview、Staging 或 Production 写入；没有 Supabase/Auth/DB 连接；没有环境值、PII 或 secret 证据。临时 env 读目录为 `/private/tmp/rebuy-g13-preview-env-read-20260827-1050`，仅保存项目绑定文件，不记录敏感值。
- 本批未修改 `prototype/**`、workflow、package、lockfile、`.env.example`、`.gitignore`、Git remote 或 provider 设置。

推荐 Owner Gate 语句（历史候选原文；实际批准记录见 G1.3-2 与 Owner Gate 条目）：

> `批准进入G1.3-2 Preview执行：确认 Vercel team kyox120-9295's projects（team_AOJDnrjov0QDLqpvMyhwA1yc）与 project rebuy-share（prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL）；project Node24.x 默认不 PATCH，依据 package.json engines.node=22.x 请求 Node22，并以新的 build log 实证实际 Node22；仅从已通过 CI 的精确 archive main@af6d7419956ce6640c0b4af5df4db0369e793f77 的仓库根执行 link/deploy，provider rootDirectory=prototype，禁止从 archive/prototype 执行以免 prototype/prototype，Target=Preview；Preview前只核对变量名与target、不读取值，任一应用变量存在即停止；不关闭 Deployment Protection，使用 vercel curl；按 Pro 正常 build/compute 用量执行；部署前后核对旧 production deployment dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH 与 aliases fingerprint 不变；bad503 使用 DO NOT MERGE Draft PR，永不Ready/merge，关闭PR但保留分支，good200 及后续永久 good route 另从干净 main/最终集成分支进入独立普通PR；不得改变 Production alias，不注入 Supabase/Auth/DB/PII 或任何环境值，不接 Staging、Production 或真实业务数据。`

关联记录：[G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[G1.3-0 本地环境预检](../2026-08-26-g1-3-0-local-environment-preflight/README.md)、[G1.3-2 Preview execution review](../2026-08-27-g1-3-2-preview-execution-review/README.md)、[15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)、[Prototype quality workflow](../../../../.github/workflows/prototype-quality.yml)。
