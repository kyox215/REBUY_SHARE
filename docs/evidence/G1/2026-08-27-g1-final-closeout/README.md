# G1 final closeout：Owner 签署、main 谱系与 G2-A0 开门记录

阶段：G1 工程底座与环境隔离
批次：G1.3 technical closeout、G1 Exit 签署与 G2-A0 开门授权
状态：`G1.3 technical closeout GO；G1 Exit GO（Owner 已签署）；本 docs-only closeout 的 PR/Actions/merge 仍须实时门禁`
证据级别：远端 Git/Actions 事实 + Owner 决定记录 + 文档变更审计
记录日期：2026-08-27（Europe/Rome）

> 本记录只归档已发生的 main 谱系、Actions 和 Owner 决定；不预写本 docs-only 分支后继 SHA、PR 编号、Actions run/job 或 merge commit。所有这些值必须在实际 push、PR、Actions、独立复审和 merge 后实时回填；未发生时保持 `N/A`。

## 1. Owner 决定与签署

Owner 原话：

> `确认 G1.3 technical closeout 通过；验收 ref=d51f1c7cb47e2fe2932b29bd39420f5d092a8160；签署 G1-19，G1 Exit GO，日期 2026-08-27，并授权打开 G2-A0。授权从该 main 新建 codex/g1-final-closeout docs-only 分支，非强制 push、创建 PR 和运行 Actions；若差异仅为批准的文档、exact-head Actions 与独立复审通过，允许以 merge commit 合并 main。禁止 squash、rebase、force/direct push、删除分支或 deployment，以及 Production/promote/deploy/Supabase/Auth/DB 操作。`

该决定的可追溯解释：

- `G1-19` 已满足：Owner 明确签署 G1 Exit，日期为 `2026-08-27`，验收 ref 为 `d51f1c7cb47e2fe2932b29bd39420f5d092a8160`。
- `G1 Exit` 当前为 `GO`；这不是 Production 验收，也不把后续 G2-A0 实施写成已完成。
- `G2-A0` 已授权并打开准备入口，但本批未实施安全审查、Auth、数据库、Storage、RLS 或任何外部资源写入；`G2-A1` 未打开。

## 2. 已确认的 main 谱系与 Actions

| 项目 | 已确认事实 | 边界 |
|---|---|---|
| 验收 ref | `d51f1c7cb47e2fe2932b29bd39420f5d092a8160` | Owner 指定的 G1.3 technical closeout / G1 Exit 验收 ref |
| PR #5 merge | merge commit `d51f1c7cb47e2fe2932b29bd39420f5d092a8160`；parent 1=`af6d7419956ce6640c0b4af5df4db0369e793f77`；parent 2=`824dd27f37792b3f487ec7a9ab21270b4b97fb84` | 已发生的非 squash merge；不改写双方历史 |
| main Actions | run `33089108238` / job `98576781415`；install、typecheck、lint、build 四步均 `success` | 证明该 main merge ref 的工程质量门，不证明 Production 或 G2-A0 实施 |
| final closeout 分支 | `codex/g1-final-closeout`，从上述 main ref 建立 docs-only 工作范围 | 分支后继 SHA、PR、Actions 和 merge 均不预写；实时核验后才可记录 |

PR #5 的合并只作为 G1.3 technical closeout 的既有事实；本批 docs-only closeout 不重新创建功能代码、不改 workflow、不部署 Preview、不改变 Production。

## 3. 保持的分支、PR 与 provider 不变量

- bad503 演练 PR #4 仍按既有记录保持关闭的 Draft，bad 分支和 bad Preview evidence 保留；不 Ready、不 merge、不删除分支或 deployment。
- good Preview、bad Preview 与旧 Production asset 的既有脱敏证据保持；Preview Protection、Preview env 数量、provider `rootDirectory=prototype`、resolved Node22 和 Production aliases fingerprint 均不因本批文档变更而改变。
- `main` 的既有双 parent 谱系保持；本批只允许在 docs-only 差异、exact-head Actions 成功且独立复审 GO 后，通过非强制 merge commit 合并。
- 不读取或记录 alias 字符串、URL、token、cookie、secret、环境值、PII 或原始 provider 日志；仅保留 ref、run/job、target、状态、风险类别和脱敏 fingerprint。

## 4. 本批 docs-only 范围

本批只允许修改以下文档：

- [15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)
- [G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)
- [G1 工程底座与环境隔离合同](../../../stages/G1-工程底座与环境隔离.md)
- [G1.3-2 Preview 执行审查](../2026-08-27-g1-3-2-preview-execution-review/README.md)
- [G1.3-3 good200 与在线恢复证据](../2026-08-27-g1-3-3-good200-local-candidate/README.md)
- 本记录

禁止修改 `prototype/**`、`package.json`、`pnpm-lock.yaml`、`.github/workflows/**`、Next/Vercel 配置、环境文件、数据库/Auth/Storage 代码或任何 provider 设置。

## 5. docs-only PR 的实时门禁

以下字段在实际事件发生前统一为 `N/A`，不得从预期或本地 HEAD 推断：

| 门 | 当前记录 |
|---|---|
| docs-only 后继 commit SHA | `N/A`，需 push 后实时取得 |
| docs-only PR 编号、base/head | `N/A`，需创建后实时取得；base 必须为 `main`，head 必须为 `codex/g1-final-closeout` |
| exact-head Actions run/job | `N/A`，需确认该 PR 当前 head 的 install/typecheck/lint/build 全部 success |
| 独立复审 | `N/A`，需审查 changed-files 仅为批准文档、lineage、敏感扫描和 workflow/config/code diff=0 |
| merge commit | `N/A`，仅在上述门全部通过后允许非强制 merge commit；禁止 squash、rebase、force/direct push |

若任一门失败，保留失败 ref 和最小脱敏摘要，停止合并，不创建新的外部资源，不删除分支或 deployment。

## 6. 禁止事项与后续入口

- 本记录不授权 Production、promote、deploy、alias 切换、rollback、Supabase、Auth、DB、Storage、RLS、真实 PII、支付或其他外部资源写入。
- G2-A0 的“打开”仅表示下一阶段安全合同/威胁模型可以进入独立审查排程；实施前仍需按 [G2-A0 Owner 验收清单](../../../stages/G2-A0-Owner验收清单.md) 建立新的范围、证据和 Owner Gate。
- G2-A1 保持未打开；任何 Auth spike、provider project、secret/env 值或真实账号仍需新的专项授权。
- 本批不新增 Preview；既有 bad/good Preview 和 Production 不变量仅作脱敏回溯证据。

关联记录：[G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)、[G1.3-2](../2026-08-27-g1-3-2-preview-execution-review/README.md)、[G1.3-3](../2026-08-27-g1-3-3-good200-local-candidate/README.md)。
