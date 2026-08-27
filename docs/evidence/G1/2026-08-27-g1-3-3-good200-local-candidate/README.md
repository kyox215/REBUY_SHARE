# G1.3-3 good200 Preview 验收、在线恢复技术 GO 与证据

阶段：G1 工程底座与环境隔离
批次：G1.3-3 good200 本地 health 候选实现、PR#5/Actions 验证、bad503 Preview 结果收口与文档同步
状态：`G1.3 technical closeout=GO；good200 本地候选、good Preview 与 bad→good 在线恢复技术验收已完成；G1-19=satisfied；G1 Exit=GO（Owner signed，日期=2026-08-27，验收 ref=d51f1c7cb47e2fe2932b29bd39420f5d092a8160）；本记录原始候选阶段的 NO-GO/未签署内容均为历史快照；既有 Preview/Production/provider 不变量保持；G2-A0 已授权并打开准备入口但未实施，G2-A1 保持关闭；本 docs-only closeout 后继 SHA/PR/Actions/独立复审/merge 仍为 N/A，待实时门`
证据级别：本地静态 + 本地 production server + provider good/bad Preview 脱敏结果 + GitHub PR/Actions 远端
记录日期：2026-08-27（Europe/Rome）
code candidate snapshot ref：`5ce3723b73edcd7284f88b26d6faa0e31ed01b40`（当时为 PR#5 exact head；首轮 Actions run=`33074662873` / job=`98525606734` 已成功；本次 docs-only closeout 会生成后继 head，其 SHA/run 不预写、不递归回写）
lineage：`origin/main@af6d7419956ce6640c0b4af5df4db0369e793f77` 为 base 祖先；bad503 ref 不在该 base 历史中

> 本记录覆盖一个最小 good200 本地候选、首轮 PR#5/Actions 成功结果、bad503 Preview、good Preview 脱敏结果及 bad→good 在线恢复技术 GO；其中原始候选证据阶段不代表 Production 或 G1 Exit 通过，属于历史快照。当前有效 G1-19/G1 Exit 状态为 Owner signed `GO`（日期=`2026-08-27`，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`）；本次 docs-only closeout 为 docs-only，code/config/lock 未变化，final Preview 默认不重复且 Preview 上限为非强制上限；后继 SHA/PR/Actions/独立复审/merge 仍为 `N/A`，待实时门。任何 merge 前必须实时确认当前 PR head 及其新 Actions 的 install/typecheck/lint/build 全部成功，否则 STOP。

## 1. good200 本地候选实现

- 仅新增 `prototype/app/api/health/app/route.ts`，使用 Next.js App Router Route Handler。
- 固定 `runtime="nodejs"`、`dynamic="force-dynamic"`；`GET` 返回 HTTP `200` 和 JSON `{ "status": "healthy" }`。
- 响应包含 `Cache-Control: no-store`；路由不读取 env、不联网、不调用 Supabase/Auth/DB、不写日志、不返回版本、ref、路径或 secret。
- 未修改 `package.json`、`pnpm-lock.yaml`、workflow、Next 配置、UI 或业务逻辑。

## 2. 本地工具链与验证

| 项目 | 结果 |
|---|---|
| Node | 实际：`v22.12.0` |
| Corepack | 实际：`0.34.6` |
| pnpm | 实际：`10.33.3` |
| 安装 | `pnpm install --frozen-lockfile`：退出 `0`（351 个包，复用 351、下载 0） |
| TypeScript | `pnpm typecheck`：退出 `0` |
| ESLint | `pnpm lint`：退出 `0` |
| Production build | `pnpm build`：退出 `0`（Next.js `16.3.2` / Turbopack） |

本批实际使用 Node22 下的 exact Corepack bootstrap，并在 `prototype/` 执行 frozen install。pnpm 报告 `unrs-resolver@1.12.2` ignored build script warning，作为非阻塞 warning 保留，未执行 approve-builds/allowlist。

## 3. 本地 production server 验证

在未占用的本地 `3104` 端口启动 `next start`，验证完成后安全停止进程：

| 请求 | 预期/结果 |
|---|---|
| `/` | 实际：HTTP `200` |
| `/api/health/app` | 实际：HTTP `200` |
| health body | 实际仅 `{ "status": "healthy" }` |
| health cache | 实际 `Cache-Control: no-store` |
| 外部连接 | route scope 静态扫描 `0`；路由不读取 env 或调用外部服务 |
| 进程 | `next start -p 3104` 已安全停止，不把 PID/session 当长期证据 |

## 4. 已提供的 bad503 Preview 结果

以下结果来自本批之前已真实完成的受控 bad503 Preview 证据，用于与 good200 保持独立：

- deployment `dpl_J9E3WThCmtqxAndfjQDKAW1G49EU` 为 `Target=Preview`、`READY`。
- deployment resolved config 为 `builds[0].config.nodeVersion=22.x`；provider build log 未打印 Node 版本行，不能把日志输出误写成 Node 证据，也不能用 project 默认 Node24 替代该 resolved 配置。
- 根页 HTTP `200`；`/api/health/app` HTTP `503`，body 仅 `{ "status": "unhealthy" }`，`Cache-Control` 含 `no-store`。
- Deployment Protection 保持 `Standard` + `Require Log In`，未关闭或降级。
- 旧 Production deployment 与 aliases 不变量保持：Production asset/target/READY 未变，alias count=`2`，排序后的 normalized mapping SHA-256=`c06eeb6c408c562d7d6906cf1ccd71776beea381afae47e94547c696133f79aa`。本记录不保存 alias 字符串、URL、token、cookie 或环境值。

## 5. good200 外部状态、Preview 验收与后续边界

- 历史代码候选快照 ref=`5ce3723b73edcd7284f88b26d6faa0e31ed01b40` 曾为 PR#5 head（当时为 OPEN 普通非 Draft、base=`main`）；本次 docs-only closeout 后继 head 的 SHA/run 不预写、不递归回写；good Preview 已按独立门禁完成，任何 merge 前必须实时确认 PR 当前 head 及其新 Actions 的 install/typecheck/lint/build 全部成功，否则 STOP。
- bad503 演练分支/ Draft PR 与 good200 路径保持分离；bad PR 永不 Ready/merge，分支按审计要求保留。
- good Preview 已沿独立普通 PR 路径完成；provider `rootDirectory=prototype` 保持不变，从 archive 仓库根执行 Preview，禁止从 archive/prototype 执行。
- 本批不 promote、不切换 Production alias、不 rollback Production、不接 Supabase/Auth/DB/Staging/Production，不读取或写入任何 env/secret/PII。

## 6. 变更与验收摘要

| 检查项 | 本批结果 |
|---|---|
| 源码范围 | 仅新增 good200 health route |
| 文档范围 | 更新 15 台账、G1 Owner 清单、G1 工程合同、G1.3-2 历史快照说明；新增本 evidence |
| good200 本地运行 | Node22 exact toolchain 下 frozen install/typecheck/lint/build 均退出 `0`；root/health 均 HTTP `200`，body 仅 healthy，Cache-Control 含 `no-store` |
| changed-files 敏感扫描 | changed-files sensitive scan=`0`；route scope scan=`0`；docs 中历史 503/unhealthy 证据不纳入路由 scope 结论 |
| GitHub Actions / good Preview | 旧 5ce 首轮代码候选快照 Actions run=`33074662873`、job=`98525606734` 成功（install/typecheck/lint/build 均成功）；source ref=`f4225397dc6c6b99e315d5ca4a7ecbc8695fb529`（当时 PR#5 current head）的 exact-head Actions run=`33078824609`、job=`98540116896` install/typecheck/lint/build 已成功，随后部署 good deployment `dpl_D2oNMJhvQsvbbyszgApm24aGLYnZ`，为 project `rebuy-share` 的唯一 READY Preview；resolved Node22、root/health 200、healthy/no-store、Protection all_except_custom_domains、Preview env=0；bad→good 在线恢复技术 GO；本次 closeout 后继 head/run 不预写、不递归回写；merge 前必须实时确认当前 PR head 及新 Actions 全部成功 |
| Production 写入 | 未执行；既有 Production fingerprint 仅作为 bad503 结果不变量复用 |
| G1 Exit | `GO（Owner signed）`；G1-19 已满足，日期=`2026-08-27`，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`；docs-only closeout 后继 SHA/PR/Actions/独立复审/merge 仍为 `N/A`，待实时门 |

## 7. good Preview 执行、部署清单与恢复验收

- source ref：`f4225397dc6c6b99e315d5ca4a7ecbc8695fb529`；该部署时 PR#5 current head 为同一 SHA。good deployment：`dpl_D2oNMJhvQsvbbyszgApm24aGLYnZ`，project `rebuy-share`，Target=Preview，状态 `READY`。
- deployment resolved config：`builds[0].config.nodeVersion=22.x`；根页 HTTP `200`；`/api/health/app` HTTP `200`；body 仅 `{ "status": "healthy" }`；Cache-Control 含 `no-store`。
- Preview Protection：`all_except_custom_domains`；Preview env 数量=`0`；未读取、记录或注入任何环境值。
- deployment inventory（只读）仅包含 good Preview `dpl_D2oNMJhvQsvbbyszgApm24aGLYnZ`、bad Preview `dpl_J9E3WThCmtqxAndfjQDKAW1G49EU` 与旧 Production `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH`；未发现其他本批 deployment。
- Production 不变量保持：旧 Production target/READY 未变，alias count=`2`，normalized mapping SHA-256=`c06eeb6c408c562d7d6906cf1ccd71776beea381afae47e94547c696133f79aa`；不记录 alias 字符串、URL、token 或 cookie。
- PR/main 不变量保持：bad PR#4 仍为 Draft、永不 Ready/merge；good deployment 当时 PR#5 current head/source ref=`f4225397dc6c6b99e315d5ca4a7ecbc8695fb529`；docs-only closeout 后继 head/run 不预写、不递归回写；`main` 未改变；未 promote、切换 alias、rollback 或写入 Production。
- bad→good online recovery technical GO：good Preview 已 READY 且 root/health 均返回 200、health body 仅 healthy/no-store；该 GO 仅覆盖本次受控技术恢复，不代表 G1 Exit 或 Production 验收。
- final Preview 默认不重复：本次为 docs-only closeout，code/config/lock 未变化；Preview 上限为非强制上限，不新增 final deployment。
- closeout lineage：本次 closeout 后继 SHA/run 不预写、不递归回写；任何 merge 前必须实时确认 PR 当前 head 及其新 Actions 的 install/typecheck/lint/build 全部成功，否则 STOP。

## 8. 2026-08-27｜bad503 Draft PR closeout 与当前门禁

- PR#4 closeout 已完成：状态为 `CLOSED`，仍为 `Draft`；head=`059c936c5ecdf4152141ed685fa64151b22e3326`，merge commit=`null`，comments=`0`；远端 bad 分支保留该 head。本条只关闭 bad 独立 Draft PR，不 Ready、不 merge、不删除分支。
- provider closeout 不变量保持：deployment inventory（只读）仅包含 bad Preview `dpl_J9E3WThCmtqxAndfjQDKAW1G49EU`、good Preview `dpl_D2oNMJhvQsvbbyszgApm24aGLYnZ` 与旧 Production `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH`，共 `3` 项；三者均为各自目标的 `READY`，Production alias count=`2`，normalized mapping SHA-256=`c06eeb6c408c562d7d6906cf1ccd71776beea381afae47e94547c696133f79aa`；good Preview Protection=`all_except_custom_domains`、Preview env=`0`；不记录 alias 字符串、URL、token、cookie 或环境值。
- PR#5 代码候选快照当时以 head=`b02715be` 保持 `OPEN`、非 Draft、`mergeable`；该 exact-head Actions run=`33084137265` / job=`98559030766` 的 install/typecheck/lint/build 已成功；`main=af6d7419956ce6640c0b4af5df4db0369e793f77` 未改变。该事实仅作为当时快照，不预写 docs-only closeout 后继 head/run。
- 当时 Gate：close-bad 门已完成；当时仅待 docs-only closeout 后新 current-head Actions、independent merge review、Owner G1-19 与明确的 main merge 授权。不得预写 merge；本 closeout 后继 SHA/run 不预写、不递归回写。该条为 final closeout 前的历史快照。

关联记录：[G1.3-2 Preview execution review](../2026-08-27-g1-3-2-preview-execution-review/README.md)、[G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)。

## 9. 2026-08-27｜G1 final closeout Owner 签署同步

- Owner 原话：`确认 G1.3 technical closeout 通过；验收 ref=d51f1c7cb47e2fe2932b29bd39420f5d092a8160；签署 G1-19，G1 Exit GO，日期 2026-08-27，并授权打开 G2-A0。授权从该 main 新建 codex/g1-final-closeout docs-only 分支，非强制 push、创建 PR 和运行 Actions；若差异仅为批准的文档、exact-head Actions 与独立复审通过，允许以 merge commit 合并 main。禁止 squash、rebase、force/direct push、删除分支或 deployment，以及 Production/promote/deploy/Supabase/Auth/DB 操作。`
- G1-19 已满足，G1 Exit=`GO`，日期=`2026-08-27`，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`。main merge 双 parent 为 `af6d7419956ce6640c0b4af5df4db0369e793f77` + `824dd27f37792b3f487ec7a9ab21270b4b97fb84`；main Actions run=`33089108238` / job=`98576781415` 的 install/typecheck/lint/build 四步均 success。
- G2-A0 已授权/打开准备入口但未实施；G2-A1 保持关闭。既有 bad PR #4、good/bad Preview、Production asset/aliases fingerprint、Protection、provider `rootDirectory=prototype` 与 Preview env 不变量保持。
- 本 docs-only closeout 不改 code/config/workflow/package/lock/env，不新增 Preview、不 promote、不 deploy、不连接 Supabase/Auth/DB；后继 SHA、PR、Actions、独立复审和 merge 在实时事件前不预写。
