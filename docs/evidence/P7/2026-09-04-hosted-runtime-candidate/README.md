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

## 零新增付费约束与免费额度核对

- Owner 明确要求“不使用付费”。因此没有调用 Supabase `get_cost`/`confirm_cost`/`create_project`，没有创建项目、分支、插件或付费 add-on；既有两个非 Rebuy 项目保持未触碰。
- Supabase 官方 [billing overview](https://supabase.com/docs/guides/platform/billing-on-supabase) 当前规定：Free Plan 提供最多两个免费活跃项目，额度跨 Owner/Administrator 管理的 Free 组织计算，paused 项目不计入；同一组织不能混用 Free 与 Pro。账户实时只有一个组织，权威详情为 `plan=pro`，其中已有 `ChinaTech_date` 与 `PartsPro-V4` 两个 `ACTIVE_HEALTHY` 项目。因此不能在该组织内创建 Free Rebuy 项目；第三个 Pro 项目会新增 compute 成本。零新增付费路径必须先另建独立 Free 组织，再由 provider 确认仍可分配免费项目槽位。
- Free Plan 主要组织级/月度或逐项目额度为：数据库 `500 MB/项目`、MAU `50,000`、Storage `1 GB`、uncached/cached egress 各 `5 GB`、Edge Functions `500,000` 次、Realtime `2,000,000` 条与峰值 `200` 连接。超过 500 MB 数据库会进入只读；低活跃项目可能在 7 天后暂停，暂停后可在 90 天内恢复。Free Plan 不提供可下载的托管数据库备份，生产恢复必须自行定期 `db dump`。
- Supabase 默认 SMTP 只向项目组织 team 的预授权邮箱投递、没有 SLA 且明确不适合生产；它只足以做受控 team-member Auth 验证，不能据此开放公众注册。
- Vercel 当前唯一团队实时为 `Pro`，既有 `rebuy-share` 已在其中；这不是免费账户。官方 [Hobby plan](https://vercel.com/docs/plans/hobby) 虽含 100 GB Fast Data Transfer、100 万 Function invocations、4 CPU-hours、360 GB-hours memory 等免费额度，但只允许个人、非商业用途，不适合作为 Rebuy 交易试运营的合规替代。
- 结论：不触碰两个现有 Supabase 项目、不新增付费且保持 Supabase 架构时，可行候选是“新建独立 Free 组织 → 重新核验 $0 project cost → 创建一个 Free Rebuy 项目”。创建云端组织需要 Owner action-time 确认；在确认前，候选分支保留于 `origin/codex/rebuy-v1-local-complete`，PR、Supabase 创建、迁移和 hosted-auth 部署保持暂停。
