# P7 hosted-runtime 本地候选

日期：2026-09-04（Europe/Rome）  
源码候选：`856d5ee60d0540cefe47bf947e41a80c78c6b8a4`  
环境：local synthetic-only；Node `22.12.0`；Supabase CLI `2.101.0`；Next.js `16.3.2`

## 交付范围

- Auth runtime 新增严格 `hosted-auth`，只接受规范 hosted Supabase URL、现代 publishable key、精确 HTTPS primary origin 与当前 Vercel immutable deployment origin；配置/Host/origin 不一致时 fail closed 为 `ui-only`。
- hosted session cookie 使用 `Secure` + `SameSite=Lax`；callback、email OTP、logout 继续实行同源/Host/forwarded-header、有限错误、no-store 与安全重定向约束。
- hosted 注册/登录只向 server-only `REBUY_AUTH_ALLOWED_EMAILS` 受控名单发送邮件；拒绝名单的 request/resend 保持相同有限成功响应，避免账号枚举。邮件 callback 绑定当前已验证 deployment origin。
- 新增全站 CSP、HSTS、frame、MIME、referrer 与 permissions 安全头；Vercel function region 固定 `fra1`。未新增客户端 secret 或 `NEXT_PUBLIC_*` 配置。
- 关闭 P6 `P3-A01`：商家 audit 改为关系式 `UNION ALL`、过滤/排序后 `LIMIT`；catalog/inventory event 的 P6 读取分支合并进原单一 permissive policy，保持 organization/store scope 与 P4-only write check。

## 实际验证

- 固定 Node 22 Auth contract `50/50 PASS`；P2-L preflight/migration 与 P3/P4/P5/P6 全部 structure PASS。
- TypeScript、全量 ESLint、Next `16.3.2` production build PASS；构建覆盖 Auth、buyer、merchant 与 health 全部动态路由。
- 空资源 start、AMR preflight、fresh reset PASS；五条 migration 与三份 synthetic seed 重放成功。
- 首轮 pgTAP 为 `502/503`：新增两条独立 permissive SELECT policy 触发 P4“每表每动作最多一条 permissive policy”门。按首个失败停止，未继续并发或 hosted 操作。
- 定向修复把 P6 audit read 分支合并进既有 P4 event policy，write `WITH CHECK` 保持 P4-only；P6 structure PASS 后唯一相关复验为 `503/503 PASS`。
- strict public/private schema lint、security info advisor 与 performance warn advisor 均零问题；五条 local/database migration history 对齐。
- exact stop/no-backup 成功；目标 containers、volumes、network 与 `55320–55329` listeners 均为空，共享 Colima 未修改。

## 验证复用与边界

- P7 未改变库存/订单/履约/售后的 mutation、锁顺序或幂等逻辑，因此不重复 P6 已通过的六套 concurrency；其哈希绑定证据继续作为回归基线。
- 本记录只证明 hosted-runtime 发布候选在本地成立；未证明 hosted Supabase、真实邮件、Vercel Preview/Production、`main`、远端 CI 或生产业务路径。
- Supabase connector 当前只显示两个与 Rebuy 无关的项目；没有读取或修改它们。创建独立项目仍等待 Owner 对唯一可见组织的明确确认和 provider 成本确认。

## 发布配置预检

- 唯一 Vercel 目标继续为 `rebuy-share`；项目运行时已从历史 `24.x` 校准并回读为 `22.x`，与 `package.json`、本地验证和 GitHub Actions 的 Node `22.12.0` 基线一致。
- Production 环境变量列表仍为空，线上健康检查仍为 `mode=ui-only`；在独立 Supabase、迁移、受控邮箱和生产变量闭环前不发布 hosted-auth 候选。
- `origin/main` 新增的两笔 UI-only Production docs-only 提交已刷新并通过 merge commit `8918735` 吸收；源码候选未变化，当前分支相对 `origin/main` 为零落后。
- GitHub CLI 的现有登录令牌无效；该状态尚未影响 Git fetch，但 PR/CI/merge 必须在推送前恢复认证或使用经验证的等价入口。本段只记录 preflight，不把远端 CI、push 或 Production 表述为已完成。
