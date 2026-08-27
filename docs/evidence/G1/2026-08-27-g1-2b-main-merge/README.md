# G1.2b main merge closeout 证据

阶段：G1 工程底座与环境隔离
批次：G1.2b canonical integration/PR/真实 CI/main merge closeout
状态：`G1.2b 真实 PR/CI 已完成并合并 main；G1.3-0 仅预检；G1.3 待 Owner Gate；G1 Exit NO-GO；G2-A0 不打开`
证据级别：远端 GitHub PR/Actions + 本地 Git fetch/谱系核验 + 文档质量门
记录日期：2026-08-27（Europe/Rome）

> 本记录只证明经独立复审 GO 后，通过 PR #1 以 merge commit 完成的 main 写入和 main push 质量检查。它不证明 Preview、Staging、Production、Supabase/Auth/DB、G1 Exit 或任何真实业务数据能力已实施。

## 1. Owner 授权与执行边界

Owner 已授权当前 Rebuy 仓库源码、项目文档、Git 历史和图片公开上传到 `kyox215/REBUY_SHARE`，推送 `integration/g1-2b`、创建 PR、运行 GitHub Actions，并在验证通过、独立复审 GO 后以非强制方式合并到远端 `main`。授权明确禁止 force-push、删除或改写远端历史，并禁止 Preview、Supabase/Auth/DB、Staging、Production 和真实业务数据写入；Workflow scope 仅限该仓库本次 workflow。

Owner 授权原话：

> `我确认允许将当前 Rebuy 本地仓库的源码、项目文档、Git 历史和图片公开上传到公开仓库 kyox215/REBUY_SHARE；允许推送 integration/g1-2b、创建 PR、运行 GitHub Actions，验证通过后以非强制方式合并到远端 main；禁止 force-push、删除远端历史、部署 Preview、连接 Supabase/Auth/DB 或生产。`

本次 Workflow scope 原话：

> `允许本次 GitHub CLI 为 kyox215 获取 Workflow scope，仅用于向 kyox215/REBUY_SHARE 推送 .github/workflows/prototype-quality.yml 并运行本次 Actions；不得用于其他仓库或修改其他工作流。`

本次执行严格限定为：

- 合并前只读确认 `origin/main=366ad7f287a00f795c742d7f2df10a531fa42e7c`、PR #1 为 `OPEN/CLEAN`、base=`main`、head=`integration/g1-2b`、head=`0bb5fb527d51a304b95b05794345bd23128e1534`，以及 head 对应的 PR run 成功。
- 由独立 merge reviewer 对上述 head 正式给出 GO 后，仅通过 GitHub PR #1 使用 merge commit 合并；未直接 push main，未使用 squash、rebase 或 force 操作。
- 保留远端 `integration/g1-2b` 分支，未删除分支、未关闭或创建第二个用于替代本 PR 的合并入口。
- 等待 main push 触发 `Prototype quality` workflow，并在完成后 fetch 远端 main；不部署、不连接外部业务服务、不读取 secrets。

## 2. PR 与 Git 谱系

| 项目 | 结果 |
|---|---|
| Canonical repo | [`kyox215/REBUY_SHARE`](https://github.com/kyox215/REBUY_SHARE)（public） |
| PR | [#1](https://github.com/kyox215/REBUY_SHARE/pull/1)，base=`main`，head=`integration/g1-2b` |
| 合并方式 | GitHub PR `merge commit`；非 squash、非 rebase、非 direct push |
| 合并前 remote main | `366ad7f287a00f795c742d7f2df10a531fa42e7c` |
| 合并前 PR head | `0bb5fb527d51a304b95b05794345bd23128e1534` |
| Merge commit | `cba97eb4e7c93e5c42ba496e4d2ddeac5b476c7c` |
| Merge parents | parent 1=`366ad7f287a00f795c742d7f2df10a531fa42e7c`；parent 2=`0bb5fb527d51a304b95b05794345bd23128e1534` |
| 合并后 remote main | `cba97eb4e7c93e5c42ba496e4d2ddeac5b476c7c` |
| integration 分支 | `integration/g1-2b` 仍保留，未删除；合并前远端 head 为 `0bb5fb527d51a304b95b05794345bd23128e1534` |

该双 parent merge 保留远端 `main` 与 integration 历史，未覆盖、重写或删除任一侧历史。旧的初始 run、更新 docs head run 和 G1.2b 远端 evidence 均作为日期化事实保留；本记录只追加 main merge closeout，不回写旧证据。

## 3. main push 的真实 GitHub Actions

Workflow：[`.github/workflows/prototype-quality.yml`](../../../../.github/workflows/prototype-quality.yml)
Event：`push`
Head：`cba97eb4e7c93e5c42ba496e4d2ddeac5b476c7c`
Run：[33031297793](https://github.com/kyox215/REBUY_SHARE/actions/runs/33031297793)
Job：[prototype-quality / 98384190584](https://github.com/kyox215/REBUY_SHARE/actions/runs/33031297793/job/98384190584)
Result：`SUCCESS`
执行时间：2026-08-27 01:48:56–01:49:29 UTC（远端记录）

| 顺序 | Runner step | 结果 |
|---:|---|---|
| 1 | Set up job | SUCCESS |
| 2 | Checkout | SUCCESS |
| 3 | Setup Node.js | SUCCESS |
| 4 | Bootstrap compatible Corepack | SUCCESS |
| 5 | Verify Corepack and pnpm | SUCCESS |
| 6 | Install dependencies | SUCCESS |
| 7 | Typecheck | SUCCESS |
| 8 | Lint | SUCCESS |
| 9 | Build | SUCCESS |
| 10 | Post Setup Node.js / Post Checkout / Complete job | SUCCESS |

该 run 证明 merge commit 在真实 GitHub runner 上完成 Node/Corepack/pnpm bootstrap、frozen install、typecheck、lint 和 build；不扩展为 Preview 构建、在线健康检查或 G1 Exit 通过。

### 3.1 本地质量门复用

在本次 docs-only closeout 前，既有 G1.2a fresh exact bootstrap 已在隔离副本以 Node `v22.12.0`、Corepack `0.34.6`、pnpm `10.33.3` 完成 frozen install、`typecheck`、`lint`、`build`，均退出 0；本次未修改 prototype、依赖、lockfile 或 workflow，因此复用该有效本地证据。[G1.2a 本地 workflow/等价证据](../2026-08-26-g1-2a-local-workflow/README.md)

## 4. 当前阶段结论

当前唯一状态源为[15 项目状态与阶段台账](../../../15-项目状态与阶段台账.md)，其当前 G1 行已同步本次 closeout。当前结论为：

- G1.2b 的 canonical public repo、integration/PR、真实 PR Actions 和 main merge 已完成；PR #1 已 `MERGED`，merge commit 为 `cba97eb4...`，main push run/job 均 SUCCESS。
- G1.3-0 仍仅完成本地环境隔离、archive 取回和回退预检；G1.3 实施等待新的 Owner Gate，不能由本次 main merge 自动打开。
- Preview 项目/部署、在线 bad ref → good ref 回退、Staging/Production 资源和 Owner G1 Exit 签署仍缺失；G1 Exit 保持 `NO-GO`，G2-A0/G2-A1/P2–P8 不打开。

关联记录：[G1 Owner 验收清单](../../../stages/G1-Owner验收清单.md)、[G1 阶段合同](../../../stages/G1-工程底座与环境隔离.md)、[G1 Exit 本地预检](../2026-08-26-g1-exit-preflight/README.md)、[G1.2b 远端 PR/CI](../2026-08-27-g1-2b-remote-ci/README.md)、[阶段索引](../../../stages/README.md)。

## 5. Actions 设置与公开范围风险

- 既有只读设置仍为 Actions enabled=`true`、default workflow permissions=`read`、`allowed_actions=all`、SHA enforcement=`false`、PR approval=`false`；selected-actions 在 all 策略下返回 409。仓库级允许范围较宽、未强制 SHA 是后续治理债务；workflow 自身仍使用完整 action SHA 和 `contents: read`。
- 本仓库公开可见源码、项目文档、Git 历史和图片；既有发布前敏感/大文件审计未发现真实 secret value、禁止路径或超大 blob。该审计不替代未来 GitHub secret scanning 或实际环境变量审查。
- 本次没有读取、记录或输出 GitHub token、一次性设备验证码、Workflow scope 内容以外的权限信息、环境 secret 或 PII。

## 6. 回退与维护

- main 的可验证 good ref 为 merge commit `cba97eb4e7c93e5c42ba496e4d2ddeac5b476c7c`；integration 的上游候选 ref 为 `0bb5fb527d51a304b95b05794345bd23128e1534`。如需撤回，只能由 Owner 另行批准并通过可追溯的普通 revert/后续 PR 完成，不使用 reset、force-push、删除分支或改写历史。
- `integration/g1-2b` 保留作为谱系与审计入口；不要把分支删除当作回退，不要直接 push main。若未来 main workflow 失败，应停止晋级、保留失败 run/ref 的最小脱敏摘要，再由 Owner 决定修复或回退 PR。
- 15 台账保存唯一当前状态；本 closeout 保存 PR merge 与 main Actions 事实；旧 G1.2b evidence 保存初始 run/历史审计事实。版本、工具链、workflow 或外部设置变化时，应追加新日期记录并重新验证，不静默修改历史快照。

## 7. 明确未执行事项

本批未部署 Preview 或 Staging，未连接 Supabase/Auth/DB，未触碰 Production，未写入真实业务数据，未读取 secrets，未修改 `prototype/**`、package、lockfile 或 workflow。PR #1 merge 执行阶段未创建替代合并入口；本 closeout 已通过 docs-only PR #2 以 merge commit `e0be39caeea27b7daebadf43794ed9222a45c120` 合并到 main，main push 的 Prototype quality run `33033439072` / job `98390866073` 成功；`integration/g1-2b` 未删除。G1.3 及 G1 Exit 仍需独立 Owner Gate 和对应证据。

## 8. 本次 docs-only closeout 质量门

本次 closeout 只新增/同步 Markdown 文档，未重复运行已由 main push run 覆盖的源码质量命令。当前 `docs/**/*.md` 共 43 个文件；Markdown 链接总数 647 个，其中本地相对目标 550 个，fragment 17 个，目标和 fragment 均可解析；围栏标记 56 个且全部成对；敏感模式命中 0；当前变更的 protected paths（`prototype/**`、`.github/workflows/**`、package、lockfile）命中 0；`git diff --check` 通过。未做哈希检查，因为本批没有生成或传输物，也无异常覆盖疑点。
