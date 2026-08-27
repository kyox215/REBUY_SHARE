# G1.3-2 Preview 执行高风险独立审查

阶段：G1 工程底座与环境隔离
批次：G1.3-2 Preview 执行方案、环境保护与 bad→good 回退独立审查
状态：`G1.3 technical closeout=GO；G1-19=satisfied；G1 Exit=GO（Owner signed，日期=2026-08-27，验收 ref=d51f1c7cb47e2fe2932b29bd39420f5d092a8160）；本记录审查阶段的 NO-GO/未执行内容均为历史快照；PR #5 merge 双 parent、main Actions run/job 与既有 Preview/Production/provider 不变量已由 final closeout evidence 记录；G2-A0 已授权并打开准备入口但未实施，G2-A1 保持关闭；本 docs-only closeout 后继 SHA/PR/Actions/独立复审/merge 仍为 N/A，待实时门`
证据级别：文档审查 + provider 只读事实复用 + Owner Gate 授权记录 + 后续 G1.3-3 脱敏执行证据；本审查阶段未执行 Preview/PR/Actions/deploy，后续 good Preview、bad→good 技术恢复与 bad Draft closeout 已由后续记录完成；G1-19/G1 Exit 已由 Owner 签署为 `GO`（日期=`2026-08-27`，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`）。当前仅待 docs-only closeout 后 current-head exact-head Actions、独立复审与条件非强制 merge 的实时门。
记录日期：2026-08-27（Europe/Rome）
审查输入 ref：`main@af6d7419956ce6640c0b4af5df4db0369e793f77`（只作为未来精确 archive 输入）
deploy/environment ref：`f4225397dc6c6b99e315d5ca4a7ecbc8695fb529`（当时 PR#5 current head；exact-head Actions run 33078824609 / job 98540116896 的 install/typecheck/lint/build 已成功）→ `dpl_D2oNMJhvQsvbbyszgApm24aGLYnZ`（Target=Preview、READY、project=rebuy-share；provider-resolved Node22；root/health 200、healthy/no-store）

> 本记录属于高风险独立审查，不是 Preview 执行结果。原执行草案因 Node 版本、`rootDirectory`、变量存在性、Deployment Protection、Production aliases 和回退 PR 边界不充分而判定 `NO-GO`；以下修正后曾形成条件 `GO` 候选。Owner 于 2026-08-27 10:33:59 CEST 回复 `我批准 ，下次无需我批准`，语义承接主线程上一条完整 G1.3 修正版授权语句；该授权在审查阶段不代表任何 login、push、PR、Actions 或 deploy 结果，属于历史快照。当前 G1-19/G1 Exit 状态以本文件顶部 final closeout 状态为准。

> 最新收口覆盖（2026-08-27）：Owner 已在 [G1 final closeout evidence](../2026-08-27-g1-final-closeout/README.md) 签署 G1-19，G1 Exit 为 `GO`，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`。本文件前述“审查时 NO-GO/未执行”均为审查阶段历史事实；PR #5 merge 双 parent 与 main Actions 已由 final closeout 记录，docs-only 后续 SHA/run/merge 仍不得预写。

## 1. 审查范围与安全边界

- 审查 Preview 的 project、Node、root、ref、变量、访问保护、Production 不变量和 bad→good 回退，不修改代码、workflow、package、lockfile、环境文件或 provider 设置。
- 仅允许在本记录 §8 明列的已批准范围内进行必要 link/deploy/PR/Actions；超出该范围必须另行 Owner Gate。本记录不授予 Supabase、Auth、DB、Staging、Production 或真实业务数据权限。
- §8 的“下次无需我批准”只覆盖该已批准范围内的常规可回退步骤和必要重试；不扩展任何未来新付费资源、Supabase project/cost、secret/env 值、Auth/DB/PII、支付、Staging/Production 或真实业务数据。
- 不读取或记录环境变量值、token、cookie、保护 secret、host、真实 URL、PII 或原始 provider 日志；变量只允许记录名称和 target。
- 审查阶段的历史结论为 `NO-GO`；final closeout 后 Owner 已签署 G1-19、G1 Exit=`GO`。G2-A0 仅获授权打开准备入口但未实施，G2-A1/P2–P8 不打开。

## 2. 审查输入的最小只读事实

| 项目 | 当前事实 | 边界 |
|---|---|---|
| Vercel team | `kyox120-9295's projects` / `team_AOJDnrjov0QDLqpvMyhwA1yc` / Pro | 本批未改 team、权限、计费或设置 |
| Vercel project | `rebuy-share` / `prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL` | 本批未 link、deploy 或修改 project |
| 旧 Production asset | `READY`、`target=production` deployment `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` | 仅已认证只读发现；不 promote、不 rollback、不切 alias |
| Project Node/Git link | UI 当前显示 Node `24.x`；无 Git link | `engines.node=22.x` 的构建覆盖结论须以新 deployment 的 provider-resolved config `builds[0].config.nodeVersion=22.x` 为主证据；build log 仅作补强；resolved 缺失或非 22 立即 STOP；默认不 PATCH project |
| Supabase | 只读确认无 Rebuy 项目；现有其他项目未触碰 | 不连接、不创建、不读取值 |
| G1.3 当前动作 | 审查输入时无外部执行授权；本审查未登录、未 push、未创建 PR、未 deploy；后续授权与 bad503 结果另由 G1.3-3 记录 | 不把本审查写成 Actions、Preview 或 deploy 结果 |

## 3. 独立审查结论与修正合同

| 风险点 | 原方案结论 | 修正后的强制合同 | 当前证据 |
|---|---|---|---|
| Node 版本 | `NO-GO`：把 project Node24 当成必须先改的阻塞 | 按 Vercel 官方规则，`package.json` `engines.node=22.x` 覆盖 project Node24；默认不 PATCH project。新 Preview deployment 的 provider-resolved config `builds[0].config.nodeVersion=22.x` 必须存在且为 22.x；build log 仅作补强；resolved 缺失或非 22 立即 STOP并另开 Owner 决策 | 本审查阶段无新 Preview build log；后续 good deployment provider-resolved Node22 已记录，good source ref=f4225397dc6c6b99e315d5ca4a7ecbc8695fb529、exact-head run 33078824609 / job 98540116896 四步成功后部署 |
| Root Directory | `NO-GO`：把执行 cwd 与 project 设置混写（历史快照） | 当前合同：provider `rootDirectory=prototype` 保持不变；从精确 archive SHA 的仓库根执行 `link/deploy`，禁止从 archive/prototype 执行，避免 `prototype/prototype` | 后续 preflight 已固定 provider 设置与 archive-root 入口 |
| 环境变量 | `NO-GO`：未定义存在性停止门 | Preview 前只核对变量名称与 target，不读值；任一应用变量在 team/project/Preview target 中存在即停止，不删除、不修改、不继续 deploy | 只保留 `.env.example` 名称，未读值 |
| Deployment Protection | `NO-GO`：没有安全访问入口 | 不关闭、不改弱 Deployment Protection；用 `vercel curl` 访问 Preview 根页和无外部依赖路径 | 本审查阶段未执行 `vercel curl`；后续 good Preview 保护为 `all_except_custom_domains`，Preview env=0；good recovery 技术 GO，bad Draft closeout 与 Owner G1-19/G1 Exit 签署已完成；当前仅待 docs-only closeout 后 current-head exact-head Actions、独立复审与条件非强制 merge |
| Production 不变量 | `NO-GO`：只写“alias 不变”不够可审计 | 部署前后只读检查旧 deployment 与 aliases，计算不暴露 alias/URL 值的 normalized mapping fingerprint；不一致即停止 | 本审查阶段未执行；后续 bad→good 证据确认旧 Production、main 与保护/alias 不变量未变 |
| 回退 PR | `NO-GO`：bad/good 与长期路径混在一起 | `bad503` 使用独立演练分支和 `DO NOT MERGE` Draft PR，永不 Ready/merge，关闭 PR 但保留分支；`good200` 另从干净 main/最终集成分支进入普通 PR | 本审查阶段未创建；后续 bad PR #4 已 CLOSED 且保留 Draft，good source 曾经由 PR #5 普通路径完成；Owner G1-19/G1 Exit 已签署；当前仅待 docs-only closeout 后 current-head exact-head Actions、独立复审与条件非强制 merge |

历史审查结论：原方案为 `NO-GO`；以上修正后曾为条件 `GO` 候选，后续 G1.3-3 已补充 good Preview READY 与 bad→good online recovery 技术 GO 的脱敏证据。当前有效结论为 G1.3 technical closeout、G1-19、G1 Exit=`GO`（Owner 日期=`2026-08-27`，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`）；G2-A0 已授权并打开准备入口但未实施，G2-A1 保持关闭；docs-only closeout 后继 SHA/PR/Actions/独立复审/merge 仍为 `N/A`，待实时门。

## 4. 精确 archive、link/deploy 与访问草案（均未执行）

仅按 §8 已批准范围，从已通过 CI 的精确 ref 建立一次性归档副本：

> 历史快照（已废止）：原草案曾要求从 `archive/prototype` 子目录执行并将 provider `rootDirectory` 视为 unset；这只保留用于审计，不是当前执行入口。

```bash
ARCHIVE_REF=af6d7419956ce6640c0b4af5df4db0369e793f77
ARCHIVE_DIR="$(mktemp -d /private/tmp/rebuy-g13-2-archive.XXXXXX)"
git archive --format=tar "$ARCHIVE_REF" | tar -xf - -C "$ARCHIVE_DIR"
cd "$ARCHIVE_DIR"
# provider rootDirectory=prototype 保持不变；CLI 从 archive 仓库根执行

vercel link \
  --scope team_AOJDnrjov0QDLqpvMyhwA1yc \
  --project prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL \
  --yes

vercel deploy \
  --scope team_AOJDnrjov0QDLqpvMyhwA1yc \
  --target=preview \
  --yes

vercel inspect <preview-deployment-id-or-url> \
  --scope team_AOJDnrjov0QDLqpvMyhwA1yc \
  --wait --timeout 90s --format=json

vercel curl / \
  --deployment <preview-deployment-id-or-url> \
  --scope team_AOJDnrjov0QDLqpvMyhwA1yc \
  --yes
```

`cd "$ARCHIVE_DIR"` 是当前临时执行 cwd（精确 archive 仓库根）；provider `rootDirectory=prototype` 保持不变，禁止从 `archive/prototype` 执行以免 `prototype/prototype`，也不得通过 `vercel.json` 或其他配置覆盖 provider 设置。`vercel link` 生成的 `.vercel/` 只能留在临时副本并在结束后清理，不得写回当前 repo。禁止 `--prod`、promote、Production alias 切换或 Production rollback。

### 4.1 Preview 前变量与保护门

当前只允许登记以下名称和 target，不读取值：

| 变量名 | 允许记录 | target | 处置 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | 名称 | `preview` | 任一应用变量存在即停止；不读值、不删除、不修改 |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | 名称 | `preview` | 任一应用变量存在即停止；不读值、不删除、不修改 |

上述表只说明检查范围，不表示变量已存在或已注入。若 team/project/Preview target 发现任一应用变量、继承变量或非预期 target 绑定，立即停止，保留最小脱敏事实并回到 Owner Gate。Deployment Protection 不关闭；访问使用 `vercel curl`，不在文档或日志中写入 protection bypass secret。

### 4.2 Node 与 Production fingerprint 门

1. 部署前读取旧 production deployment `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` 的只读状态和 aliases mapping，规范化后计算 fingerprint；只保存 fingerprint、target 和检查时间，不保存 alias 字符串或 URL。当前 `before fingerprint=N/A`，因为未执行。
2. Preview deployment 完成后先核对 provider-resolved config `builds[0].config.nodeVersion=22.x`；必须存在且为 22.x。build log 仅作补强；resolved 缺失或非 22 立即 STOP，不 PATCH project Node，不把部署标成成功。
3. 部署后以同一只读方法复核旧 deployment/aliases，计算 `after fingerprint`；必须与 before 相等。任何变化都停止，不 promote、不切换 alias、不 rollback Production。当前 `after fingerprint=N/A`，因为未执行。

## 5. bad503 → good200 受控演练

本批未创建分支、Draft PR 或 Preview。未来演练必须和长期 good route 分离：

1. 从明确的 bad ref 建立独立分支 `g1-3-preview-bad503`，创建标题含 `DO NOT MERGE` 的 Draft PR；PR 始终保持 Draft，永不 Ready、永不 merge。
2. 只在隔离 Preview 中验证标记为 `bad503` 的故障类别，立即停止晋级，不 promote、不写 Production、不接真实数据。保留时间、ref、target、Node/build/HTTP 类别和最小脱敏摘要。
3. 演练结束关闭该 Draft PR，但保留演练分支和审计证据；不删除历史、不 force-push、不 reset。
4. 从干净 `main@af6d741` 或最终集成分支另建 `good200` 的独立普通 PR，不能携带 bad 演练分支提交；仅在 Preview 中验证标记为 `good200` 的根页/关键无外部依赖路径、访问边界和日志脱敏。后续永久 good route 仍必须沿这条独立干净 PR 路径，不得复用 bad503 PR。
5. 若 `good200` 失败，保持停止状态并升级 Owner；若通过，保留 bad/good ref、观察窗口、build/health/访问/数据/Storage/日志摘要，但不 promote、不切 Production alias。

该流程只证明隔离 Preview 的受控恢复，不证明 Production rollback。旧 deployment/aliases fingerprint 在全过程前后必须相同。

## 6. 验收证据与当前状态

| 验收项 | 当前结果 | 通过条件 |
|---|---|---|
| Owner 外部执行授权 | `已批准（2026-08-27 10:33:59 CEST）`；仅限 §8 范围，不等于已执行 | 以实际执行证据核对 OAuth、分支/PR/Actions、最多三个 Target=Preview 及停止边界 |
| CLI 登录与 provider access | `N/A`；未登录/不确认登录 | 只在授权后取得最小必要 access，不记录凭据 |
| exact archive/ref | 输入固定为 `main@af6d741...`；后续 good source ref=`f4225397dc6c6b99e315d5ca4a7ecbc8695fb529`（当时 PR#5 current head），exact-head run 33078824609 / job 98540116896 四步成功后部署 | archive SHA、CI 成功、`prototype/` tree 可追溯 |
| provider project rootDirectory | `prototype` 保持不变；未修改 | 从精确 archive 仓库根执行 CLI；禁止从 archive/prototype；link/deploy 前后只读核对 provider 设置 |
| Node | 本地/CI Node22 已有证据；bad503 与 good Preview 的 provider-resolved Node22 均已由后续证据记录，good source ref=`f4225397dc6c6b99e315d5ca4a7ecbc8695fb529` 的 exact-head run 33078824609 / job 98540116896 四步成功后部署 `dpl_D2oNMJhvQsvbbyszgApm24aGLYnZ` 为 Target=Preview/READY | deployment provider-resolved config `builds[0].config.nodeVersion=22.x` 为主证据，build log 仅作补强；resolved 缺失或非 22 立即 STOP |
| Preview | bad503 与 good Preview 均已部署并 READY | good deployment `dpl_D2oNMJhvQsvbbyszgApm24aGLYnZ` 的 root/health 均 HTTP 200、body 仅 `{"status":"healthy"}`、Cache-Control 含 `no-store`；Protection=`all_except_custom_domains`、Preview env=0；bad PR #4 保持 Draft，bad ref、main 与 Production 不变量未变；PR current-head 及 docs-only closeout 后新 Actions 仍待实时核验；final Preview 默认不重复（docs-only 且 code/config/lock 未变，上限非强制） |
| Production asset/aliases | 旧 deployment 只读事实已记录；部署前后 fingerprint 相等 | 旧 Production deployment、aliases 与 main 不变量保持不变；不 promote、不切 alias、不 rollback Production |
| bad503/good200 | bad503 → good200 在线恢复技术 GO | bad PR #4 已 CLOSED、仍为 Draft 且保留分支；good Preview 已由独立路径完成，Owner G1-19/G1 Exit 已签署；当前仅待 docs-only closeout 后 current-head exact-head Actions、独立复审与条件非强制 merge；final Preview 默认不重复 |
| G1 Exit | `GO（Owner signed）` | Owner G1-19 已签署；验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`；docs-only closeout 自身仍须实时 Actions/独立复审/非强制 merge 门 |

## 7. 推荐 Owner 授权语句

以下语句是 Owner Gate 批准前的候选原文（历史快照，已废止，禁止执行，保留供审计）；实际批准记录见 §8。当前执行合同以 §4 的 archive 仓库根入口为准：provider `rootDirectory=prototype` 保持不变，禁止从 archive/prototype 执行。

> 历史候选原文（已废止、禁止执行）：`批准进入G1.3-2 Preview执行：确认 Vercel team kyox120-9295's projects（team_AOJDnrjov0QDLqpvMyhwA1yc）与 project rebuy-share（prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL）及 Pro 正常 build/compute 用量；project Node24.x 默认不 PATCH，依据 package.json engines.node=22.x 请求 Node22，并以新的 build log 实证实际 Node22；仅从已通过 CI 的精确 archive main@af6d7419956ce6640c0b4af5df4db0369e793f77 的 prototype/执行 link/deploy，project rootDirectory 保持未设置，Target=Preview；Preview前只核对变量名与target、不读取值，任一应用变量存在即停止；不关闭 Deployment Protection，使用 vercel curl；部署前后核对旧 production deployment dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH 与 aliases fingerprint 不变；bad503 使用独立 DO NOT MERGE Draft PR，永不Ready/merge，关闭PR但保留分支，good200 及后续永久 good route 另从干净 main/最终集成分支进入独立普通PR；不得改变 Production alias，不注入 Supabase/Auth/DB/PII 或任何环境值，不接 Staging、Production 或真实业务数据。`

## 8. 2026-08-27 10:33:59 CEST｜G1.3 修正版 Owner Gate 已批准

- Owner 原话：`我批准 ，下次无需我批准`。该回复明确承接主线程上一条完整 G1.3 修正版授权语句，批准本批受控 Preview 执行范围，不是 G1 Exit 签署，也不把条件 GO 候选写成已完成。
- 授权范围：允许 Vercel OAuth 临时认证；仅限上一条完整授权语句指定的两个 `codex/*` 分支/PR/Actions 入口（本记录不臆补名称或编号）；最多三个 `Target=Preview`，角色仅为 `bad503`、`good200`、`final`；允许 Vercel Pro 正常 build/compute 用量；在该范围内风险触发时可受限取消构建中的 Preview。OAuth/login 是否发生、分支/PR/Actions 是否创建及 Preview 是否部署，均须由后续证据确认。
- 原批准记录历史快照（保留）：曾写作 project `rootDirectory` 保持未设置、从 archive/prototype cwd 执行；该表述已废止。当前执行合同为：`engines.node=22.x` 覆盖 project Node24，Node 默认不 PATCH，必须以 deployment provider-resolved config `builds[0].config.nodeVersion=22.x` 为主证据，build log 仅作补强；resolved 缺失或非 22 立即 STOP；provider `rootDirectory=prototype` 保持不变，从精确 archive 仓库根执行 CLI，禁止从 archive/prototype；Preview 前只列变量名/target，任一应用变量存在即停止；不关闭 Deployment Protection，使用 `vercel curl`；旧 production deployment `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` 与 aliases fingerprint 前后必须不变；bad503 使用永不 Ready/merge 的 `DO NOT MERGE` Draft PR，关闭 PR 但保留分支，good200 与后续永久 good route 另用独立干净普通 PR。
- `下次无需我批准` 仅表示上述已批准范围内的常规可回退步骤和必要重试不重复询问；不得扩展到未来新付费资源、Supabase project/cost、任何 secret/env 值、Auth/DB/PII、支付、Staging/Production、真实业务数据、Production alias/promote/rollback、项目删除或其他 team/project 设置。
- 当前状态：G1.3 implementation 从“待 Owner Gate”更新为“已授权/执行中”；本记录仍不伪造任何 login、push、PR、Actions、Preview 或 deploy 结果，G1 Exit 保持 `NO-GO`，G2-A0 不打开。

## 9. 回退、维护与关联记录

- 任一 Node、变量、保护、alias、访问或 ref 检查失败：停止 Preview 晋级和所有外部写入，保存最小脱敏摘要，回到 Owner Gate；不把失败写成通过。
- 归档副本、`.vercel/` 和临时缓存完成后清理；当前 repo、Git refs、remote、workflow、package、lockfile 和 provider 设置不得因本审查改变。
- 维护记录只保留 ref、target、时间、deployment id、步骤结论、fingerprint 和风险类别；不保存 secret、完整日志、alias/URL 值或 PII。
- 审查时风险（历史快照）：Owner Gate 已批准但 Preview 尚未部署，在线 bad→good 尚未演练，Vercel Node24 project 显示与 Node22 应用合同尚未由 build log 证明，变量存在性和 aliases fingerprint 尚未实测；后续 bad503 Preview 的脱敏结果与 resolved Node22 配置由 G1.3-3 独立记录。
- 后续 implementation 事实由独立 G1.3-3 evidence 追加：bad503 与 good Preview 均有脱敏 READY/health 结果；good Preview deployment `dpl_D2oNMJhvQsvbbyszgApm24aGLYnZ` 为 Target=Preview/READY，provider-resolved Node22，root/health 均 HTTP 200、body 仅 `{"status":"healthy"}`、Cache-Control 含 `no-store`；Protection=`all_except_custom_domains`、Preview env=0；bad→good online recovery 技术 GO，bad PR #4 保持 Draft，bad ref、main 与 Production 不变量未变；历史代码候选快照 ref 5ce3723b73edcd7284f88b26d6faa0e31ed01b40 曾为 PR#5 head（当时为 OPEN/普通非 Draft），首轮 Actions run 33074662873 / job 98525606734 的 install/typecheck/lint/build 已成功；本次 docs-only closeout 会生成后继 head，其 SHA/run 不预写、不递归回写；PR current-head 及 closeout 后新 Actions 仍待实时核验；final Preview 默认不重复（docs-only 且 code/config/lock 未变，上限非强制）。本审查记录仍是历史合同与风险边界，不改写为 G1 Exit 通过。

## 10. 2026-08-27｜bad503 Draft PR closeout 当前事实

- close-bad 门已完成：PR#4 状态为 `CLOSED`，仍为 `Draft`；head=`059c936c5ecdf4152141ed685fa64151b22e3326`，merge commit=`null`，comments=`0`；远端 bad 分支保留该 head；bad deployment `dpl_J9E3WThCmtqxAndfjQDKAW1G49EU` 保留为 `Target=Preview/READY`。
- provider/Production 不变量保持：deployment inventory（只读）仅包含 bad Preview、good Preview `dpl_D2oNMJhvQsvbbyszgApm24aGLYnZ` 与旧 Production `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH`，共 `3` 项且各自 `READY`；good Preview Protection=`all_except_custom_domains`、Preview env=`0`；Production alias count=`2`，normalized mapping SHA-256=`c06eeb6c408c562d7d6906cf1ccd71776beea381afae47e94547c696133f79aa`；不记录 alias 字符串、URL、token、cookie 或环境值。
- PR#5 当时以 head=`b02715be` 保持 `OPEN`、非 Draft、`mergeable`；该 exact-head Actions run=`33084137265` / job=`98559030766` 的 install/typecheck/lint/build 已成功；`main=af6d7419956ce6640c0b4af5df4db0369e793f77` 未改变。该事实仅作为当时代码候选快照，不预写 docs-only closeout 后继 head/run。
- 当前 Gate：close-bad 已完成；当前仅待 docs-only closeout 后新 current-head Actions、independent merge review、Owner G1-19 与明确的 main merge 授权。不得预写 merge，G1 Exit 继续 `NO-GO`。

关联记录：[G1.3-1 provider/Preview preflight](../2026-08-27-g1-3-1-provider-preview-preflight/README.md)、[G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)、[Prototype quality workflow](../../../../.github/workflows/prototype-quality.yml)。

## 11. 2026-08-27｜G1 final closeout 状态同步

- Owner 原话：`确认 G1.3 technical closeout 通过；验收 ref=d51f1c7cb47e2fe2932b29bd39420f5d092a8160；签署 G1-19，G1 Exit GO，日期 2026-08-27，并授权打开 G2-A0。授权从该 main 新建 codex/g1-final-closeout docs-only 分支，非强制 push、创建 PR 和运行 Actions；若差异仅为批准的文档、exact-head Actions 与独立复审通过，允许以 merge commit 合并 main。禁止 squash、rebase、force/direct push、删除分支或 deployment，以及 Production/promote/deploy/Supabase/Auth/DB 操作。`
- 已确认 main 事实：PR #5 merge=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`，parent 1=`af6d7419956ce6640c0b4af5df4db0369e793f77`，parent 2=`824dd27f37792b3f487ec7a9ab21270b4b97fb84`；main Actions run=`33089108238` / job=`98576781415`，install、typecheck、lint、build 四步均 success。
- G1.3 technical closeout 与 G1-19 已签署；G1 Exit 为 `GO`。G2-A0 已授权/打开准备入口但未实施，G2-A1 未打开；本文件不把该授权解释为 Auth/DB/Storage/RLS、secret/env 值或真实数据实施。
- bad PR #4、good/bad Preview、Production asset/aliases fingerprint、Deployment Protection、provider `rootDirectory=prototype` 与 Preview env 等既有不变量保持；本 docs-only closeout 不新增 Preview、不 promote、不 deploy。
- `codex/g1-final-closeout` 后继 SHA、PR、exact-head Actions、独立复审和 merge commit 在实际事件发生前均为 `N/A`；仅批准文档差异、exact-head Actions 成功、独立复审 GO 后，才允许非强制 merge commit。禁止 squash、rebase、force/direct push、删除任何分支或 deployment。
