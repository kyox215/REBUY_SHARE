# P2-L account page-only commit-bound milestone evidence

状态：**commit-bound local page-only milestone**

记录日期：2026-08-30（Europe/Rome）

## 1. 里程碑与证据绑定

- Milestone commit：`88a10d8f2a2c51fa241314f835367d81ae56ffc3`。
- Parent：`3d92b834ff5ce9a674316525bcfbf708e3b9480d`。
- Branch：`codex/rebuy-v1-local-complete`。
- 验证在提交前对与 milestone commit 完全相同的 prototype source tree 执行；提交后 `git diff 88a10d8 -- prototype` 与 `git diff 88a10d8 -- docs/stages/P2-L-本地Schema与RLS纵切Gate.md` 均为空，证明相关 source/Gate 没有提交后漂移。
- Commit-bound source set：
  - `prototype/app/account/login/LoginPrototype.tsx`
  - `prototype/app/account/login/login.module.css`
  - `prototype/app/globals.css`
  - `prototype/components/PrototypeApp.tsx`
  - `prototype/app/account/account.module.css`
  - `prototype/app/account/page.tsx`
  - `prototype/app/account/provider/[provider]/page.tsx`
  - `prototype/app/account/provider/[provider]/provider.module.css`
- Git commit identity 与上述零差异核对已提供本批所需源码绑定；普通源码无需额外 hash。后续若这些路径相对 milestone commit 发生变化，必须按风险复用或重跑相应门禁。

## 2. 本地命令证据

Package cwd：`prototype`。Node 固定为 `22.12.0`，pnpm 固定为 `10.33.3`。

```bash
PATH=/Users/kyox215/.nvm/versions/node/v22.12.0/bin:$PATH corepack pnpm@10.33.3 typecheck
PATH=/Users/kyox215/.nvm/versions/node/v22.12.0/bin:$PATH corepack pnpm@10.33.3 lint
PATH=/Users/kyox215/.nvm/versions/node/v22.12.0/bin:$PATH corepack pnpm@10.33.3 build
```

- `typecheck`：最终 PASS。首次运行遇到 `.next/types` 的重复生成类型文件；成功 `build` 清理该重复状态后，按同一精确命令定向重跑一次并 PASS，没有人工移动或删除文件。
- `lint`：PASS。
- `build`：PASS。
- Worktree root 执行 `git diff --check`：PASS。
- 以上结果现已绑定 milestone commit=`88a10d8f2a2c51fa241314f835367d81ae56ffc3` 的相同 prototype source tree；本次 docs-only 绑定未重跑服务、DB、测试、typecheck、lint 或 build。

## 3. 浏览器证据

- 路径：`/account`、`/account/login`、`/account/provider/google`、`/account/provider/apple`。
- 视口：`1440x900` 与 `390x844`；均无横向溢出。
- Google/Apple 等待页没有 external links、forms 或 OAuth/provider 调用，不创建账号。
- 未知路径 `/account/provider/facebook` 显示 404。
- 浏览器 console warn=`0`、error=`0`。
- 最终保留预览：`http://127.0.0.1:3000/account`。

## 4. 边界与残余风险

- 本记录未保存 secret、token、OTP、cookie、真实邮箱或其他真实 PII。
- 未生成 screenshot hash 或源码 hash；commit identity 与零差异检查已满足本地里程碑绑定，普通 UI 源码/文档没有额外 hash 需要。
- 未 push、未 deploy、未连接 hosted/DB/provider，未执行 OAuth 或外部写入。
- 残余风险：Google/Apple 仍只是 page-only placeholder，真实登录/OAuth/凭证/DB 接线暂缓；P2-L 数据库实现与 pinned GoTrue AMR/refresh preflight 均未执行，P2-L 继续 CLOSED。commit-bound 不等于已 push、已发布、Owner 已批准或 P2/P3+ 已打开。
