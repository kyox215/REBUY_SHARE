# UI-only Preview release preflight

日期：2026-09-01（Europe/Rome）

状态：本地 docs-only release candidate；本批未 push、未创建 PR、未部署。

## 绑定

- code candidate：`0e5084b62c76275a781ec08edea287a06d442209`
- base remote main：`de6a3203e20a1a4cea1106baef7bee1b4173d38f`
- 本地 release branch：`codex/rebuy-v1-ui-preview-release`，从 exact candidate 创建。
- Owner 本次授权原话：`将已完成可推送并部署的进行推送部署`。
- 该授权作为后续 action-time 发布边界输入；本批只建立本地文档记录，不把授权写成已 push、已建 PR 或已部署。

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
