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

## 2026-09-01 Runtime matrix and independent review closeout

- exact-head binding：release worktree exact HEAD=`fba8ff30e78b5bb66e87a1e3e4e939bdf364cd60`。本次 9 条 route GET 均针对同一受保护 Preview deployment。
- temporary archive 由 exact HEAD 的 `git archive` 产生；临时目录内显式 link 的 project=`rebuy-share`，`projectId=prj_g1W3AWm3hkbZib9zDgm6YQfGEyHL`、`orgId=team_AOJDnrjov0QDLqpvMyhwA1yc` 均断言通过。archive、解压 workspace、`.vercel` link state 已清理；source worktree 保持 clean。

| Route | HTTP | Content-Type | Body evidence | Location | Cache-Control |
|---|---:|---|---|---|---|
| `/` | 200 | `text/html; charset=utf-8` | non-empty, 30622 bytes | none | not recorded |
| `/account` | 200 | `text/html; charset=utf-8` | non-empty, 16878 bytes | none | not recorded |
| `/account-mindmap` | 200 | `text/html; charset=utf-8` | non-empty, 46516 bytes | none | not recorded |
| `/account/login` | 200 | `text/html; charset=utf-8` | non-empty, 10545 bytes | none | not recorded |
| `/account/provider/google` | 200 | `text/html; charset=utf-8` | non-empty, 15170 bytes | none | not recorded |
| `/account/provider/apple` | 200 | `text/html; charset=utf-8` | non-empty, 15162 bytes | none | not recorded |
| `/api/health/app` | 200 | `application/json` | `{"status":"healthy"}` | none | not recorded |
| `/api/health/supabase` | 503 | `application/json` | `{"configured":false,"reachable":false,"status":503}` | none | `no-store` |
| `/api/auth/session` | 500 | `application/json` | `{"status":"error","code":"session_error"}` | none | `no-store` |

- Request boundary：9 条均为只读 GET；未执行 POST、OTP、callback query、form、cookie、share link、deploy、alias、env 或 Production 操作。session 的 HTTP 500 是当前 production blocker evidence，不判为通过。
- `vercel inspect` 同一 Preview 返回 deployment ID=`dpl_6RCPeszdr4BBtp52oHM6i8iBf9XK`，ID 匹配，status=`READY`，target=`preview`。
- GitHub gate：PR exact head=`fba8ff30e78b5bb66e87a1e3e4e939bdf364cd60` 为 `MERGEABLE`；required check `prototype-quality` 的 run=`33484635052` 为 `SUCCESS`。source merge to main 为 static `GO`，受保护 UI-only Preview 为 `GO`，直接 Production 仍 `NO-GO`。这些结论不代表已 merge 或已进入 Production。

### Independent Sol review

- 专用 Sol role 当前不可用，使用 default Sol / max fallback；结论为 P0=0、P1=3、P2=2。
- P1 findings：
  1. 生产页面可提交，但 local-only OTP/session 在生产环境必败。
  2. callback 的 hosted 路径可能指向 localhost。
  3. 没有明确 hosted ui-only mode，且 `secure=false` 的 local cookie 与 app health 语义不清。
- 最小修复要求：
  1. 显式 server-only local-auth/ui-only mode。
  2. ui-only 登录禁用 OTP。
  3. OTP/session/callback 返回 `no-store` 503 `auth_unavailable`，且不返回 localhost Location 或 Set-Cookie。
  4. `secure=false` 仅允许 local reachable 场景。
  5. health 明确报告 `mode=ui-only`。
  6. 增加 production-like Host contract tests，并运行 `test:auth`、typecheck、lint、build 与 runtime matrix。
- source merge 可以继续，但不能自动 Production；Production/alias/promote 继续 `NO-GO`。

### Environment fact correction

- 当前 tracked `prototype/.env.example` 使用 server-only `SUPABASE_URL` 与 `SUPABASE_PUBLISHABLE_KEY`。
- 早期文档中的 `NEXT_PUBLIC_SUPABASE_URL` 与 `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` 明确保留为历史 browser-facing skeleton 名称；它们不是当前 tracked `.env.example` 或当前 release runtime 的事实，不静默抹除历史。

- 本批为 docs-only evidence closeout；不重跑测试，复用 GitHub exact-head CI。未做 hash；普通文档和非确定性 Preview 运行证据不需要 hash。
