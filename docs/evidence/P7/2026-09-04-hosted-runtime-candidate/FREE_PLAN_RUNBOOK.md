# P7 Free Plan 受控试运营运行手册

状态：**候选；尚未创建 hosted 项目，以下步骤未执行**  
适用范围：独立 Supabase Free 组织/项目、受控 team-member 身份、Rebuy V1 小流量验证

## 1. 免费额度运行边界

| 指标 | 官方 Free 额度 | 预警线 | 停止新增写入线 |
|---|---:|---:|---:|
| Database size | 500 MB/项目 | 400 MB | 450 MB |
| Storage size | 1 GB/组织 | 800 MB | 900 MB |
| Uncached egress | 5 GB/月 | 4 GB | 4.5 GB |
| Cached egress | 5 GB/月 | 4 GB | 4.5 GB |
| MAU | 50,000/月 | 40,000 | 45,000 |
| Edge Function invocations | 500,000/月 | 400,000 | 450,000 |
| Realtime messages | 2,000,000/月 | 1,600,000 | 1,800,000 |
| Realtime peak connections | 200 | 160 | 180 |

- 预警线是 Rebuy 自定的 80% 运营门，不代表 Supabase 承诺；停止线为 90% 安全余量。
- 当前 V1 不依赖 Storage、Realtime 或 Edge Functions；对应额度应保持接近零。出现非预期使用时先暂停相关入口并查明来源。
- Database 达到 500 MB 可能转为只读。停止线触发后关闭注册、下单、库存、履约和审核 mutation，保留健康检查与必要只读查询。

## 2. Auth containment

- 未配置自有 SMTP 时，只允许组织 team 的预授权邮箱；应用侧 `REBUY_AUTH_ALLOWED_EMAILS` 必须是同一最小名单。
- 不开放任意公网邮箱注册，不把默认 SMTP 当作生产邮件服务；OTP/magic-link 投递仅用于 Owner 控制的受控验证。
- 邮件、callback、session、cookie、origin 与错误脱敏继续使用 P7 已验证合同；任何账号枚举、开放重定向或跨 origin cookie finding 均为发布阻塞。

## 3. 免费项目暂停边界

- Free 项目在连续 7 天低活跃时可能自动暂停。只依赖真实受控试运营流量，不创建人为 keepalive 绕过平台策略。
- 收到暂停预警后由 Owner 决定恢复或停止试运营；项目暂停后最多在 90 天窗口内从 Dashboard 恢复。
- 健康检查应观察 `/api/health/app` 与 `/api/health/supabase`；后者不可达时停止所有 mutation，不执行自动迁移或重试风暴。

## 4. 备份与恢复

Supabase Free 不提供可下载的托管日备份。正式写入前必须由 Owner 提供一个**仓库外、加密、访问受控**的备份目的地；数据库 URL/密码不得写入 Git、命令证据或聊天输出。

当前 CLI `2.101.0` 已通过 `supabase db dump --help` 确认以下入口：

```text
supabase db dump --linked --role-only --file <encrypted-off-repo>/roles.sql
supabase db dump --linked --file <encrypted-off-repo>/schema.sql
supabase db dump --linked --data-only --use-copy --file <encrypted-off-repo>/data.sql
```

- 首次基线：hosted migration 与受控 seed 完成、业务写入开放前执行。
- 试运营期间：每日一次；每次部署或 schema 变更前再执行一次。
- 保留：至少最近 7 份每日备份与每次发布前备份；备份文件不得提交到本仓库或 GitHub artifact。
- 每份备份记录 UTC 时间、source project ref、migration list、三个文件摘要和加密目的地标识；不记录数据库密码或用户数据内容。
- 恢复演练只对隔离的本地 Supabase 或新的空 Free 项目执行，禁止覆盖生产项目。角色 → schema → data 顺序恢复，随后运行 migration list、RLS/ACL、Auth、买家和商家核心冒烟。

## 5. 发布与回退

- 应用只部署与 hosted migration history 匹配的 exact Git commit；上一 READY 且 schema-compatible 的 Vercel deployment 作为应用回退候选。
- 数据库不执行破坏性 down migration；失败优先依赖事务回滚或前向修复。Free Plan 无 PITR，不能承诺秒级/分钟级 RPO。
- hosted 项目创建、首次备份、迁移、受控 Auth、跨租户负向、核心 E2E、日志与 advisor 任一项未通过时，Production 保持 `ui-only`。

## 6. 当前未满足项

- 尚未获得创建独立 Supabase Free 组织的 action-time 确认。
- 尚无 hosted project、project cost `$0` 证据、数据库备份目的地或 Owner 指定 team-member 登录邮箱。
- 本文件是上线保障候选，不是已执行备份、恢复演练或 hosted Production 的证明。

参考：[Supabase billing](https://supabase.com/docs/guides/platform/billing-on-supabase)、[project pausing](https://supabase.com/docs/guides/platform/free-project-pausing)、[database backups](https://supabase.com/docs/guides/platform/backups)、[default SMTP](https://supabase.com/docs/guides/auth/auth-smtp)。
