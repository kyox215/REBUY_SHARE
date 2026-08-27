# G1.3-2 Preview 执行高风险独立审查

阶段：G1 工程底座与环境隔离
批次：G1.3-2 Preview 执行方案、环境保护与 bad→good 回退独立审查
状态：`独立审查完成；原方案 NO-GO；修正后条件 GO 候选；尚未获得 Owner 执行授权；G1 Exit NO-GO`
证据级别：文档审查 + provider 只读事实复用；未执行 Preview/PR/deploy
记录日期：2026-08-27（Europe/Rome）
审查输入 ref：`main@af6d7419956ce6640c0b4af5df4db0369e793f77`（只作为未来精确 archive 输入）
deploy/environment ref：`N/A`（本批未部署）

> 本记录属于高风险独立审查，不是 Preview 执行结果。原执行草案因 Node 版本、`rootDirectory`、变量存在性、Deployment Protection、Production aliases 和回退 PR 边界不充分而判定 `NO-GO`；以下修正后仅形成条件 `GO` 候选。当前 G1.3 仍无外部执行授权、未登录、未 push、未创建 PR、未 deploy。

## 1. 审查范围与安全边界

- 审查 Preview 的 project、Node、root、ref、变量、访问保护、Production 不变量和 bad→good 回退，不修改代码、workflow、package、lockfile、环境文件或 provider 设置。
- 任何后续 link/deploy/PR 都必须在新的 Owner Gate 后执行；本记录不授予 Vercel、GitHub、Supabase、Auth、DB、Staging 或 Production 权限。
- 不读取或记录环境变量值、token、cookie、保护 secret、host、真实 URL、PII 或原始 provider 日志；变量只允许记录名称和 target。
- G1 Exit 保持 `NO-GO`，G2-A0/G2-A1/P2–P8 不打开。

## 2. 审查输入的最小只读事实

| 项目 | 当前事实 | 边界 |
|---|---|---|
| Vercel team | `kyox120-9295's projects` / `team_AOJDnrjov0QDLqpvMyhwA1yc` / Pro | 本批未改 team、权限、计费或设置 |
| Vercel project | `rebuy-share` / `prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL` | 本批未 link、deploy 或修改 project |
| 旧 Production asset | `READY`、`target=production` deployment `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` | 仅已认证只读发现；不 promote、不 rollback、不切 alias |
| Project Node/Git link | UI 当前显示 Node `24.x`；无 Git link | `engines.node=22.x` 的构建覆盖结论须由新 build log 实证；默认不 PATCH project |
| Supabase | 只读确认无 Rebuy 项目；现有其他项目未触碰 | 不连接、不创建、不读取值 |
| G1.3 当前动作 | 无外部执行授权；未登录、未 push、未创建 PR、未 deploy | 所有执行证据均为 `N/A` |

## 3. 独立审查结论与修正合同

| 风险点 | 原方案结论 | 修正后的强制合同 | 当前证据 |
|---|---|---|---|
| Node 版本 | `NO-GO`：把 project Node24 当成必须先改的阻塞 | 按 Vercel 官方规则，`package.json` `engines.node=22.x` 覆盖 project Node24；默认不 PATCH project。新 Preview build log 必须显示 Node `22`，否则停止并另开 Owner 决策 | 无新 Preview build log，尚未实证 |
| Root Directory | `NO-GO`：把执行 cwd 与 project 设置混写 | 从精确 archive SHA 的 `prototype/` cwd 执行 `link/deploy`；project `rootDirectory` 保持未设置，禁止同时设置或写入 `rootDirectory=prototype` | 未 link/deploy |
| 环境变量 | `NO-GO`：未定义存在性停止门 | Preview 前只核对变量名称与 target，不读值；任一应用变量在 team/project/Preview target 中存在即停止，不删除、不修改、不继续 deploy | 只保留 `.env.example` 名称，未读值 |
| Deployment Protection | `NO-GO`：没有安全访问入口 | 不关闭、不改弱 Deployment Protection；用 `vercel curl` 访问 Preview 根页和无外部依赖路径 | 未执行 `vercel curl` |
| Production 不变量 | `NO-GO`：只写“alias 不变”不够可审计 | 部署前后只读检查旧 deployment 与 aliases，计算不暴露 alias/URL 值的 normalized mapping fingerprint；不一致即停止 | 前后 fingerprint 均 `N/A`，未执行 |
| 回退 PR | `NO-GO`：bad/good 与长期路径混在一起 | `bad503` 使用独立演练分支和 `DO NOT MERGE` Draft PR，永不 Ready/merge，关闭 PR 但保留分支；`good200` 另从干净 main/最终集成分支进入普通 PR | 未创建分支或 PR |

结论：原方案为 `NO-GO`；以上修正后为条件 `GO` 候选，仍须 Owner 逐字授权、实时 provider 证据和部署后脱敏证据，不能写成 G1.3 已通过。

## 4. 精确 archive、link/deploy 与访问草案（均未执行）

未来仅在 Owner Gate 明确批准后，从已通过 CI 的精确 ref 建立一次性归档副本：

```bash
ARCHIVE_REF=af6d7419956ce6640c0b4af5df4db0369e793f77
ARCHIVE_DIR="$(mktemp -d /private/tmp/rebuy-g13-2-archive.XXXXXX)"
git archive --format=tar "$ARCHIVE_REF" | tar -xf - -C "$ARCHIVE_DIR"
cd "$ARCHIVE_DIR/prototype"

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

`cd "$ARCHIVE_DIR/prototype"` 是临时执行 cwd，不是 project 设置；project `rootDirectory` 保持 unset，禁止在设置、`vercel.json` 或其他配置中写入 `rootDirectory=prototype`。`vercel link` 生成的 `.vercel/` 只能留在临时副本并在结束后清理，不得写回当前 repo。禁止 `--prod`、promote、Production alias 切换或 Production rollback。

### 4.1 Preview 前变量与保护门

当前只允许登记以下名称和 target，不读取值：

| 变量名 | 允许记录 | target | 处置 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | 名称 | `preview` | 任一应用变量存在即停止；不读值、不删除、不修改 |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | 名称 | `preview` | 任一应用变量存在即停止；不读值、不删除、不修改 |

上述表只说明检查范围，不表示变量已存在或已注入。若 team/project/Preview target 发现任一应用变量、继承变量或非预期 target 绑定，立即停止，保留最小脱敏事实并回到 Owner Gate。Deployment Protection 不关闭；访问使用 `vercel curl`，不在文档或日志中写入 protection bypass secret。

### 4.2 Node 与 Production fingerprint 门

1. 部署前读取旧 production deployment `dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH` 的只读状态和 aliases mapping，规范化后计算 fingerprint；只保存 fingerprint、target 和检查时间，不保存 alias 字符串或 URL。当前 `before fingerprint=N/A`，因为未执行。
2. Preview build 完成后只取 build log 中的 Node 主版本摘要；必须是 `22`。若是 `24` 或其他值，停止，不 PATCH project Node，不把部署标成成功。
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
| Owner 外部执行授权 | `N/A`；当前未授权 | Owner 逐字批准本记录 §7 的授权语句 |
| CLI 登录与 provider access | `N/A`；未登录/不确认登录 | 只在授权后取得最小必要 access，不记录凭据 |
| exact archive/ref | 输入固定为 `main@af6d741...`；未执行部署 | archive SHA、CI 成功、`prototype/` tree 可追溯 |
| project rootDirectory | 未修改；当前要求 unset | link/deploy 前后均证明 project rootDirectory 未设置 |
| Node | 本地/CI Node22 已有证据；Preview 未验证 | build log 实证 Node22；否则停止 |
| Preview | 未部署 | Target=Preview、无应用变量、Protection 不变、根页/关键路径可访问 |
| Production asset/aliases | 旧 deployment 只读事实已记录；fingerprint 未执行 | before/after fingerprint 相等 |
| bad503/good200 | 未演练 | Draft PR 永不 Ready/merge、关闭保留分支、good 另走普通 PR |
| G1 Exit | `NO-GO` | Preview、在线回退、Owner Exit 等后续证据完成并另行验收 |

## 7. 推荐 Owner 授权语句

以下语句必须由 Owner 逐字批准后才可解除本批边界；当前仅为候选，不是已授权事实：

> `批准进入G1.3-2 Preview执行：确认 Vercel team kyox120-9295's projects（team_AOJDnrjov0QDLqpvMyhwA1yc）与 project rebuy-share（prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL）及 Pro 正常 build/compute 用量；project Node24.x 默认不 PATCH，依据 package.json engines.node=22.x 请求 Node22，并以新的 build log 实证实际 Node22；仅从已通过 CI 的精确 archive main@af6d7419956ce6640c0b4af5df4db0369e793f77 的 prototype/执行 link/deploy，project rootDirectory 保持未设置，Target=Preview；Preview前只核对变量名与target、不读取值，任一应用变量存在即停止；不关闭 Deployment Protection，使用 vercel curl；部署前后核对旧 production deployment dpl_DZSmbtizfp3z7x2X4itwdwyLGxrH 与 aliases fingerprint 不变；bad503 使用独立 DO NOT MERGE Draft PR，永不Ready/merge，关闭PR但保留分支，good200 及后续永久 good route 另从干净 main/最终集成分支进入独立普通PR；不得改变 Production alias，不注入 Supabase/Auth/DB/PII 或任何环境值，不接 Staging、Production 或真实业务数据。`

## 8. 回退、维护与关联记录

- 任一 Node、变量、保护、alias、访问或 ref 检查失败：停止 Preview 晋级和所有外部写入，保存最小脱敏摘要，回到 Owner Gate；不把失败写成通过。
- 归档副本、`.vercel/` 和临时缓存完成后清理；当前 repo、Git refs、remote、workflow、package、lockfile 和 provider 设置不得因本审查改变。
- 维护记录只保留 ref、target、时间、deployment id、步骤结论、fingerprint 和风险类别；不保存 secret、完整日志、alias/URL 值或 PII。
- 当前风险：Preview 尚未部署，在线 bad→good 尚未演练，Vercel Node24 project 显示与 Node22 应用合同尚未由 build log 证明，变量存在性和 aliases fingerprint 尚未实测。

关联记录：[G1.3-1 provider/Preview preflight](../2026-08-27-g1-3-1-provider-preview-preflight/README.md)、[G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)、[Prototype quality workflow](../../../../.github/workflows/prototype-quality.yml)。
