# UI-only Preview release preflight

日期：2026-09-01（Europe/Rome）

状态：本地 docs-only release candidate；本批未 push、未创建 PR、未部署。

## 绑定

- code candidate：`0e5084b62c76275a781ec08edea287a06d442209`
- base remote main：`de6a3203e20a1a4cea1106baef7bee1b4173d38f`
- 本地 release branch：`codex/rebuy-v1-ui-preview-release`，从 exact candidate 创建。
- Owner 本次授权原话：`将已完成可推送并部署的进行推送部署`。
- 该授权作为后续 action-time 发布边界输入；本批只建立本地文档记录，不把授权写成已 push、已建 PR 或已部署。

> 历史标记：以下 `Local preflight`、`Release boundary` 与 `Non-actions` 为 action-time 执行前的 preflight 快照，原文保留；当前执行事实见下方 `Execution result`。

## Local preflight

- exact candidate release worktree 在验证开始时为 clean；验证生成的 tracked `prototype/next-env.d.ts` 漂移已恢复，之后状态再次为 clean。
- Node `22.12.0`、Corepack 驱动 pnpm `10.33.3`。
- `pnpm install --frozen-lockfile`：PASS。
- `pnpm typecheck`：PASS。
- `pnpm test:auth`：`37/37` PASS。
- `pnpm lint`：PASS。
- `pnpm build`：PASS。
- `git diff --check`：PASS。
- sensitive scan：`SCAN GO`。私钥/认证 header filename-only scan 为 0 个文件；basic-auth URL 仅命中测试文件 `prototype/tests/auth/contract.test.ts:1215`，判定为测试假阳性；provider token/JWT 复用既有 0 结果，未重复扫描。未保存或输出匹配值。

## Release boundary

- GitHub 仅允许非强制 release branch/PR 路径；本批不执行，也不预写 push、PR、Actions 或 merge 结果。
- Vercel 仅允许受保护、无 `SUPABASE_*` 的 UI-only Preview；本批不执行，也不预写 deployment 结果。
- Production、alias、promote、hosted Supabase/Auth、Google、Apple、P2-L migration 继续 `NO-GO / CLOSED`。

## Non-actions

- 本批仅写入本 README、发布记录和项目状态台账；不修改 `prototype/`、`supabase/` 或其他文件。
- 本批不运行 build/tests，不 push、不开 PR、不 deploy。
- 不记录邮箱、token、team/project/deployment ID 或 secret。

## 2026-09-01 Execution result

- Source binding：code candidate=`0e5084b62c76275a781ec08edea287a06d442209`；release/docs head=`bf10563663b91b3c0270aaf7acc68d6f3d63c526`；remote main 仍为 `de6a3203e20a1a4cea1106baef7bee1b4173d38f`。
- GitHub source release：`codex/rebuy-v1-ui-preview-release` 已以非强制方式推送成功；PR [#17](https://github.com/kyox215/REBUY_SHARE/pull/17) 已创建；Actions run `33461861676` 为 `success`。未 merge、未启用 auto-merge。
- Vercel artifact：唯一预期 Preview deployment=`dpl_6RCPeszdr4BBtp52oHM6i8iBf9XK`，project=`rebuy-share`，source=`CLI`，`READY`，`target=null`（Preview），`aliases=[]`。Next.js `16.3.2`；build log 两次明确提示 package `engines.node=22.x` 覆盖 project setting `24.x`，实际使用 Node `22.x`；pnpm=`10.33.3`，build success。参考：[Vercel Node.js versions](https://vercel.com/docs/functions/runtimes/node-js/node-js-versions)。
- Preview 未包含 `SUPABASE_*`；Production、alias、promote 均未执行，既有 Production 保持不变。未执行或修改 hosted Supabase/Auth；Google/Apple 仍为 page-only placeholder，P2-L migration 继续 `NO-GO`。
- Build route inventory：`/`、`/account`、`/account-mindmap`、`/account/login`、`/account/provider/[provider]`、`/api/auth/email-otp`、`/api/auth/session`、`/api/health/app`、`/api/health/supabase`、`/auth/callback`。
- 访问边界：Preview 受 Vercel Authentication 保护；connector 对 health 请求得到 `302` SSO。GET/HEAD runtime route matrix 未完成；未执行 POST、OTP、callback query、form 或 cookie 检查，不能把 build route inventory 写成运行时通过。
- 空项目清理时间序列：`vercel curl` 曾从未链接的 source worktree 运行，误创建空 Vercel project=`rebuy-release-0e5084b`；删除前该项目 `latestDeployment=null`、`domains=[]`、deployment count=`0`。Owner 在知情后明确回复 `批准`；删除前 `project inspect` 精确命中 name=`rebuy-release-0e5084b`、ID=`prj_JvyS0Zb8woXqdBqi2pSejTRsuoVj`，team 匹配既定目标。首次 non-interactive rm 停在确认提示且未确认；随后对同一精确命令交互输入 `y`，CLI 返回 `Success! Project rebuy-release-0e5084b removed`；删除后 inspect 返回 `There is no project for "rebuy-release-0e5084b"`。正式 project=`rebuy-share` 仍存在，ID=`prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL`、Root=`prototype`；目标 Preview `dpl_6RCPeszdr4BBtp52oHM6i8iBf9XK` 仍为 `Ready`、target=`preview`、URL 未变。本地 `.vercel` 与 `.gitignore` 副作用已清理。
- 本批未重跑已通过的 local install/typecheck/`test:auth` `37/37`/lint/build；复用相同源码、lockfile、配置和工具链证据。未做 hash，因为普通源码/文档与非确定性部署证据不需要 hash。
- 当前结论：GitHub source branch `GO`；受保护 UI-only Preview artifact `READY`，但 runtime matrix 未完成；PR merge 与 Production `NO-GO`。
