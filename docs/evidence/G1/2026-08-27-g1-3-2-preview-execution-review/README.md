# G1.3-2 Preview 执行高风险独立审查

阶段：G1 工程底座与环境隔离
批次：G1.3-2 Preview 执行方案、环境保护与 bad→good 回退独立审查
状态：`独立审查完成；原方案 NO-GO；修正后条件 GO 候选；Owner Gate 已批准（2026-08-27 10:33:59 CEST）；本审查阶段未执行外部动作；后续 bad503 结果由 G1.3-3 独立记录，good200 尚未运行 Actions 或部署 Preview；G1 Exit NO-GO`
证据级别：文档审查 + provider 只读事实复用 + Owner Gate 授权记录；未执行 Preview/PR/Actions/deploy
记录日期：2026-08-27（Europe/Rome）
审查输入 ref：`main@af6d7419956ce6640c0b4af5df4db0369e793f77`（只作为未来精确 archive 输入）
deploy/environment ref：`N/A`（本批未部署）

> 本记录属于高风险独立审查，不是 Preview 执行结果。原执行草案因 Node 版本、`rootDirectory`、变量存在性、Deployment Protection、Production aliases 和回退 PR 边界不充分而判定 `NO-GO`；以下修正后仅形成条件 `GO` 候选。Owner 于 2026-08-27 10:33:59 CEST 回复 `我批准 ，下次无需我批准`，语义承接主线程上一条完整 G1.3 修正版授权语句；该授权已记录但不代表任何 login、push、PR、Actions 或 deploy 结果，G1 Exit 仍为 `NO-GO`。

## 1. 审查范围与安全边界

- 审查 Preview 的 project、Node、root、ref、变量、访问保护、Production 不变量和 bad→good 回退，不修改代码、workflow、package、lockfile、环境文件或 provider 设置。
- 仅允许在本记录 §8 明列的已批准范围内进行必要 link/deploy/PR/Actions；超出该范围必须另行 Owner Gate。本记录不授予 Supabase、Auth、DB、Staging、Production 或真实业务数据权限。
- §8 的“下次无需我批准”只覆盖该已批准范围内的常规可回退步骤和必要重试；不扩展任何未来新付费资源、Supabase project/cost、secret/env 值、Auth/DB/PII、支付、Staging/Production 或真实业务数据。
- 不读取或记录环境变量值、token、cookie、保护 secret、host、真实 URL、PII 或原始 provider 日志；变量只允许记录名称和 target。
- G1 Exit 保持 `NO-GO`，G2-A0/G2-A1/P2–P8 不打开。

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
| Node 版本 | `NO-GO`：把 project Node24 当成必须先改的阻塞 | 按 Vercel 官方规则，`package.json` `engines.node=22.x` 覆盖 project Node24；默认不 PATCH project。新 Preview deployment 的 provider-resolved config `builds[0].config.nodeVersion=22.x` 必须存在且为 22.x；build log 仅作补强；resolved 缺失或非 22 立即 STOP并另开 Owner 决策 | 无新 Preview build log，尚未实证 |
| Root Directory | `NO-GO`：把执行 cwd 与 project 设置混写（历史快照） | 当前合同：provider `rootDirectory=prototype` 保持不变；从精确 archive SHA 的仓库根执行 `link/deploy`，禁止从 archive/prototype 执行，避免 `prototype/prototype` | 后续 preflight 已固定 provider 设置与 archive-root 入口 |
| 环境变量 | `NO-GO`：未定义存在性停止门 | Preview 前只核对变量名称与 target，不读值；任一应用变量在 team/project/Preview target 中存在即停止，不删除、不修改、不继续 deploy | 只保留 `.env.example` 名称，未读值 |
| Deployment Protection | `NO-GO`：没有安全访问入口 | 不关闭、不改弱 Deployment Protection；用 `vercel curl` 访问 Preview 根页和无外部依赖路径 | 未执行 `vercel curl` |
| Production 不变量 | `NO-GO`：只写“alias 不变”不够可审计 | 部署前后只读检查旧 deployment 与 aliases，计算不暴露 alias/URL 值的 normalized mapping fingerprint；不一致即停止 | 前后 fingerprint 均 `N/A`，未执行 |
| 回退 PR | `NO-GO`：bad/good 与长期路径混在一起 | `bad503` 使用独立演练分支和 `DO NOT MERGE` Draft PR，永不 Ready/merge，关闭 PR 但保留分支；`good200` 另从干净 main/最终集成分支进入普通 PR | 未创建分支或 PR |

结论：原方案为 `NO-GO`；以上修正后为条件 `GO` 候选，仍须 Owner 逐字授权、实时 provider 证据和部署后脱敏证据，不能写成 G1.3 已通过。

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
| exact archive/ref | 输入固定为 `main@af6d741...`；未执行部署 | archive SHA、CI 成功、`prototype/` tree 可追溯 |
| provider project rootDirectory | `prototype` 保持不变；未修改 | 从精确 archive 仓库根执行 CLI；禁止从 archive/prototype；link/deploy 前后只读核对 provider 设置 |
| Node | 本地/CI Node22 已有证据；bad503 Preview 的 provider-resolved Node22 已由后续证据记录，good Preview 未验证 | deployment provider-resolved config `builds[0].config.nodeVersion=22.x` 为主证据，build log 仅作补强；resolved 缺失或非 22 立即 STOP |
| Preview | 未部署 | Target=Preview、无应用变量、Protection 不变、根页/关键路径可访问 |
| Production asset/aliases | 旧 deployment 只读事实已记录；fingerprint 未执行 | before/after fingerprint 相等 |
| bad503/good200 | 未演练 | Draft PR 永不 Ready/merge、关闭保留分支、good 另走普通 PR |
| G1 Exit | `NO-GO` | Preview、在线回退、Owner Exit 等后续证据完成并另行验收 |

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
- 后续 implementation 事实由独立 G1.3-3 evidence 追加：bad503 Preview 已有脱敏 READY/health 结果；good200 仅完成本地候选实现与验证，尚未运行 good200 Actions 或部署 good200 Preview。本审查记录仍是历史合同与风险边界，不改写为 G1 Exit 通过。

关联记录：[G1.3-1 provider/Preview preflight](../2026-08-27-g1-3-1-provider-preview-preflight/README.md)、[G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)、[Prototype quality workflow](../../../../.github/workflows/prototype-quality.yml)。
