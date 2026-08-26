# G1.3-0 本地环境隔离、忽略规则与回退预检

阶段：G1 工程底座与环境隔离
批次：G1.3-0 Local / Preview / Staging / Production 隔离合同、忽略规则、版本取回与回退手册预检
状态：`G1.3-0 preflight 已完成；G1.3 实施、G1 Exit 与 G2-A0 均未打开`
证据级别：本地静态 + Git archive 临时取回
记录日期：2026-08-26（Europe/Rome）
本地基线：`bfef29656f4537d16d5913ba53e20e5eb49010e1`（`main`；预检开始时 clean）
已验证 workflow ref：`b0681d585cabe2f5f293779fc3627e2782be9fa2`
远端 / deploy / environment ref：`N/A`

> 本记录证明当前本地工程边界、忽略规则和不改 checkout 的版本取回方法，不证明 Preview 已部署、回退已在线演练、外部 Vercel/Supabase/GitHub 资源不存在或 G1.3/G1 Exit 已通过。任何外部环境清单在取得认证实时证据前均保持 `unknown`。

## 1. Owner 边界与本批目标

当前 Owner 授权覆盖 G1.2a 本地 workflow/等价验证，不覆盖远端、Preview、Supabase、Auth、数据库或生产：

> `批准进入G1.2a：采用GitHub Actions候选，在本地创建只读最小CI工作流并做本地等价验证；暂不添加remote、不push、不运行远端CI、不部署Preview、不接Supabase或生产。`

本批只执行本地只读审计、`git check-ignore`、Git archive 和临时目录取回；不修改 `prototype/**`、workflow、package/lockfile、`.gitignore`、`.env.example`、Git 配置、产品源码或已有 ref/tag，不添加 remote，不登录或写入外部服务。

目标是将四环境“目标合同 vs 当前可证明事实”、版本取回证据和可维护回退运行手册落档。当前批次不打开 G1.3 实施，也不把本地未绑定写成外部不存在。

## 2. 输入与当前本地事实

### 2.1 基线与受保护输入

- 预检开始时 `git rev-parse HEAD` 为 `bfef29656f4537d16d5913ba53e20e5eb49010e1`，分支为 `main`，`git status --short --branch` 为 clean，`git remote -v` 为空。
- 已复用完整读取的 `prototype/AGENTS.md`；其中要求涉及 Next.js 代码时读取 node_modules 指南，本批不写 Next.js 代码。
- 根 `.gitignore` 当前合同：依赖状态 `node_modules/`、`.pnpm-store/`；Next 输出 `.next/`、`out/`、`*.tsbuildinfo`；环境文件 `.env*` 但保留 `!**/.env.example`；Vercel `.vercel/`；Supabase `.supabase/` 及其临时状态；`.DS_Store`。
- `prototype/.env.example` 只读取变量名和空值合同：`NEXT_PUBLIC_SUPABASE_URL`、`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`。未读取任何 `.env`、shell secret、CI secret、真实 URL、token、PII 或外部凭据。
- `prototype/.node-version` 为 `22`；`prototype/package.json` 声明 Node `22.x`、pnpm `10.33.3`、`packageManager: pnpm@10.33.3`，scripts 包含 `dev`、`build`、`start`、`lint`、`typecheck` 等项目命令；当前 workflow 固定 Corepack `0.34.6`、pnpm `10.33.3`。
- `docs/11-发布与Supabase连接记录.md` 的边界仍是 A1 独立测试连接骨架：未创建 Supabase 项目、未配置 Vercel 环境变量、未启用真实登录/OAuth/SMTP，不接 production，不使用真实 PII；本批不修改该文件。
- G1 合同要求四环境先隔离，Preview 只能来自已通过 CI 的可追溯 ref，变量只记录名称/来源而不记录值；G1.2a 已完成，G1.2b 仍待 Owner Gate。

### 2.2 忽略规则与当前树扫描

使用 `git check-ignore -v --stdin` 验证以下 8 个假设路径全部被忽略：`.env`、`prototype/.env.local`、`.vercel/project.json`、`.supabase/config.toml`、`prototype/node_modules/example.js`、`prototype/.next/build-manifest.json`、`prototype/.pnpm-store/v3/files`、`prototype/build.tsbuildinfo`。`prototype/.env.example` 的 `git check-ignore -q` 退出 1，确认可跟踪。

当前 Git index/tree 的风险路径扫描只输出类别计数，不列敏感路径内容：

| 类别 | 当前可跟踪路径计数 |
|---|---:|
| 非 example `.env*` | 0 |
| `node_modules` / `.next` / `.pnpm-store` | 0 |
| `.vercel` / `.supabase` | 0 |
| `*.tsbuildinfo` | 0 |
| private key / certificate | 0 |
| database dump | 0 |
| raw attachment / obvious temp | 0 |

本地确有 ignored 文件，但只记录类别/数量，不读取内容：node_modules `38,375`、`.next` `599`、`.pnpm-store` `1`、`*.tsbuildinfo` `1`、`.env*` `0`、`.vercel` `0`、`.supabase` `0`。这些 ignored 运行态不进入本次提交，也不证明任何外部资源状态。

## 3. 四环境目标合同 vs 当前可证明事实

| 环境 | 资源归属与当前状态 | 部署来源 ref / 变量名称与来源 | 数据、Storage、访问与日志边界 | 回退 ref 与 Owner Gate |
|---|---|---|---|---|
| Local | 当前项目本地 workspace；本地 Git `main`，当前 ref `bfef296...`；无外部连接 | 直接由本地 checkout；Node `v22.12.0`、Corepack `0.34.6`、pnpm `10.33.3`；变量名只来自 `prototype/.env.example`，值未读 | 仅合成数据/本地测试；当前无外部数据库或 Storage；开发者本地访问；不得使用 production secret/PII，日志不保存 secret | 当前已验证 ref 为 `bfef296...`；未来切换前须在隔离目录复验；Owner 已打开 G1.2a，未打开 G1.3 |
| Preview | 未从当前 repo 建立，provider/project/域名/归属均 `unknown`；本地未绑定不等于外部不存在 | 未来只能来自 CI 通过的可追溯 PR/ref，Root Directory 固定 `prototype/`，Node 22；变量仅可从独立 Preview 配置注入，G2-A1 前不得注入 Auth/DB 值 | 仅合成或明确脱敏数据；不得写 Production DB/Storage；访问角色、日志保留与 PII 策略须单独书面确定，当前 `unknown` | 未来使用已验证 good ref 与明确回退 ref；须 Owner 明确批准 Preview、访问边界、健康检查和停止入口 |
| Staging | 未打开；独立项目/账号/数据/变量/角色的归属均 `unknown`，不得推断为不存在 | 未来使用独立 CI 通过 ref；变量来源、项目和部署入口需单独登记，当前 `unknown` | 必须与 Production 完全分离，不共用写入、secret、数据库或 Storage；访问角色、日志/PII 管理待 G2-A1/P2 专项 | 回退 ref、恢复负责人和备份恢复策略待 Owner Gate；不得以 Local/Preview ref 直接代替 |
| Production | 当前关闭于本地工作范围；外部资产、账号、域名、数据库、Storage 是否存在均 `unknown` | 不从当前本地事实推断生产部署来源或变量；未来必须使用独立发布 ref、生产专用变量和书面批准 | 未来真实业务数据/PII、数据库、Storage、访问角色、审计日志、监控和备份均需独立资产盘点；当前未连接、未读取 | 未来必须有发布候选、监控/备份、可恢复回退 ref 和书面 Production Gate；本批不打开 |

每个环境实际开通前还必须登记：资源归属、部署来源 ref、变量名称/来源（不记录值）、数据库/Storage 边界、访问角色、日志/PII 策略、回退 ref、Owner Gate。provider 命令、URL、project id 和环境值留待授权后按实时官方文档核验，不在本批猜测。

## 4. 非破坏性版本取回演练

在 `/private/tmp` 创建临时目录，分别对当前 ref `bfef29656f4537d16d5913ba53e20e5eb49010e1` 和已验证 workflow ref `b0681d585cabe2f5f293779fc3627e2782be9fa2` 执行 `git archive --format=tar` 并解包；没有 checkout、reset、revert 或修改当前分支。

| 检查 | 结果 |
|---|---|
| 两个 ref 可解析为 commit | 通过，archive 读取退出 0 |
| current `prototype` tree | `48dd99bb1d58768bf5bc184915e4a4856f8f0f80` |
| workflow ref `prototype` tree | `48dd99bb1d58768bf5bc184915e4a4856f8f0f80` |
| current workflow blob | `7f2dbd030d5e38783bf58f277f0c36f78259c583` |
| workflow ref workflow blob | `7f2dbd030d5e38783bf58f277f0c36f78259c583` |
| 临时解包目录的 prototype 文件树比较 | 通过，`diff -qr` 无差异 |
| docs 差异 | 预期存在：相对 workflow ref 为 `A=2/M=9`；不影响 prototype/workflow |

临时目录已清理。该演练只证明版本可读和受保护 app/workflow tree/blob 一致，不证明 Preview 已使用任何 ref 或回退已在线完成。

## 5. 可维护回退运行手册

### 5.1 触发条件与停止晋级

出现构建/检查失败、健康检查失败、越界访问、变量泄露、错误 ref、环境串联、日志包含 PII/secret、部署来源不可追溯或权限超出合同时：

1. 立即停止 Preview/环境晋级、push、推广和数据写入；不把失败状态标记为通过。
2. 保存最小脱敏失败摘要（时间、环境、job/ref、退出码、错误类别）；不得复制 env、token、cookie、PII、完整日志或 provider secret。
3. 确认 bad ref 与最后一个可验证 good ref；通过 `git cat-file`、隔离 archive 和 workflow/lockfile 复验确认身份，不凭短名称或当前工作区猜测。
4. 若发现真实 secret，停止发布准备并按凭据撤销/轮换流程另开高风险 Owner Gate；只记录 commit/path/category/count，不复制命中值。

### 5.2 隔离取回与回退步骤

在需要核对 good ref 时，使用明确的临时目录和 `git archive <good-ref>` 取回；先比较 `prototype` tree、workflow blob、Node/packageManager/lockfile，再决定是否继续。不要 checkout/reset 当前工作分支，不使用 `git reset --hard`，不 force push，不删除 audit ref/tag，不复用 Production 变量。

未来 Preview 只有在 Owner 明确授权且 CI 已通过后，才可切换到已验证 good ref。切换后必须重新复验 Node 22、Corepack `0.34.6`、pnpm `10.33.3`、frozen lockfile、CI workflow、health、访问角色、数据/Storage 边界和日志/PII 边界；当前本地 archive 演练不替代这些验证。provider 的具体切换命令和 URL 必须以授权时的实时官方文档为准。

### 5.3 回退记录与恢复后检查

回退记录至少包含：bad/good ref、触发原因、停止时间、Owner/执行人、环境、构建/CI/health 结果、数据写入确认、访问恢复结果和后续观察窗口。恢复后保留脱敏摘要与 ref 证据；若不能证明数据、Storage、权限或日志边界已恢复，保持停止状态并升级 Owner Gate。

## 6. 验证矩阵与跳过项

| 检查 | 结果 | 说明 |
|---|---|---|
| `.gitignore` / `check-ignore` | 通过 | 8 个敏感/生成路径被忽略；`.env.example` 可跟踪 |
| 当前 Git tree/index 风险扫描 | 通过 | 非 example 环境、部署状态、密钥证书、dump、附件/临时路径均为 0 |
| ignored 运行态 | 已统计 | 只记录类别/数量，不读取值或列出敏感文件内容 |
| current/workflow ref archive | 通过 | refs 可解析、archive 可读，prototype tree/workflow blob 完全一致 |
| Markdown 相对链接/fragment | 待本批最终检查 | 只提交本批文档后运行 |
| Markdown fences / 敏感模式 / `git diff --check` | 待本批最终检查 | 只针对 docs 变更做最低限度验证 |
| protected paths diff | 待本批最终检查 | 确认 prototype、workflow、package、lockfile、`.gitignore`、`.env.example` 无变化 |
| typecheck/lint/build/E2E | 跳过 | 本批仅本地 docs/取回预检，代码、workflow、依赖和配置未变；复用 G1.2a 同状态验证 |
| hash | 跳过 | Git tree/blob identity 比较已覆盖本批，不做普通文件重复 hash |
| 独立审查 | 跳过 | 低风险本地文档与非破坏性取回预检，不涉及生产写入或公共接口 |

## 7. 风险、回退与维护

- 本地没有 remote 只能证明当前 repo 未配置链接，不能证明 GitHub/Vercel/Supabase/其他外部资源不存在；无认证实时证据的外部状态一律 `unknown`。
- 本地 `node_modules`、`.next`、pnpm store 和 tsbuildinfo 的 ignored 运行态数量较大，但未被 Git 跟踪；不得将其内容带入 archive、commit 或部署。
- Preview/Staging/Production 的 owner、project、domain、变量、数据、访问和日志状态尚未建立；任何 provider 连接都必须另开 Owner Gate。
- 取回演练的 good ref 只证明 app/workflow identity；不等于构建、health、访问、数据库或回退在线通过。
- 若本批文档需要纠正，可回退本批 docs commit；不触碰 G1.1 ref/tag、G1.2a workflow 或任何外部资源。未来环境回退按第 5 节执行。
- 维护者在任何 Preview/真实环境开通前重新执行 `check-ignore`、tracked-tree/path/content 审计、archive tree/blob 比较和 toolchain/lockfile/CI 复验；动作、Node、runner、provider 发生漂移时先更新证据与 Owner 决策。

当前 Gate：`G1.3-0 preflight 已完成；Preview 未部署；G1.3 实施未打开；G1 Exit 未通过；G2-A0 不打开。`

关联记录：[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[G1.2a 本地 workflow/等价证据](../2026-08-26-g1-2a-local-workflow/README.md)、[G1.2b-1 历史保全与敏感审计演练](../2026-08-26-g1-2b-1-local-integration-rehearsal/README.md)、[15 台账](../../../15-项目状态与阶段台账.md)。
