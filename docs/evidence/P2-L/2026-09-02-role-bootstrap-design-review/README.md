# P2-L executor role bootstrap design review

日期：2026-09-02（Europe/Rome）
结果：**ROOT CAUSE CONFIRMED / CONTRACT DECISION REQUIRED**
本工作包：离线只读审查，`actual_count=0`；未启动 Supabase/Docker，未修改 SQL、migration、seed 或 tests。

## Confirmed execution path

失败现场使用 Supabase CLI `2.101.0` 与 `supabase/postgres:17.6.1.106`：

1. CLI `ConnectLocalPostgres` 默认以 `postgres` 连接。
2. `SetupDatabase` 把 `supabase/roles.sql` 交给 `SeedGlobals`。
3. `SeedGlobals` 在同一连接上直接 `ExecBatch`，没有切换到 `supabase_admin` 的受支持钩子。
4. 精确镜像的官方角色期望证明 `postgres` 不是 `supabase_admin` 成员；Supabase 托管文档也明确不给项目 `postgres` 超级用户访问。

官方源码：

- [CLI local connection and setup](https://github.com/supabase/cli/blob/v2.101.0/apps/cli-go/internal/db/start/start.go)
- [CLI `SeedGlobals`](https://github.com/supabase/cli/blob/v2.101.0/apps/cli-go/pkg/migration/seed.go)
- [CLI `ConnectLocalPostgres`](https://github.com/supabase/cli/blob/v2.101.0/apps/cli-go/internal/utils/connect.go)
- [CLI v2.101.0 image manifest](https://github.com/supabase/cli/blob/v2.101.0/apps/cli-go/pkg/config/templates/Dockerfile)
- [Postgres image 17 role-membership expectation](https://github.com/supabase/postgres/blob/17.6.1.106/nix/tests/expected/z_17_roles.out)
- [Supabase superuser boundary](https://supabase.com/docs/guides/database/postgres/roles-superuser)

## PostgreSQL 17 invariant

PostgreSQL 17 的 `CreateRole` 实现对任何非 SUPERUSER `CREATEROLE` 创建者强制建立一条 membership：

- granted role：新创建的 `rebuy_invite_executor`
- member：创建者 `postgres`
- `ADMIN=true`
- `INHERIT=false`
- `SET=false`
- grantor：bootstrap superuser

源码注释明确说明 bootstrap-superuser grant 不能由该 `CREATEROLE` 创建者撤销。`createrole_self_grant=''` 只阻止额外的 `SET/INHERIT` 自授予，不会取消上述强制 `ADMIN` 行。

官方依据：

- [PostgreSQL 17 `CreateRole` implementation](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/commands/user.c)
- [PostgreSQL 17 `createrole_self_grant`](https://www.postgresql.org/docs/17/runtime-config-client.html#GUC-CREATEROLE-SELF-GRANT)
- [PostgreSQL 17 role GRANT options](https://www.postgresql.org/docs/17/sql-grant.html)
- [PostgreSQL 17 REVOKE grantor rules](https://www.postgresql.org/docs/17/sql-revoke.html)

## Rejected alternatives

- `SET createrole_self_grant = ''`：不会移除强制 `ADMIN` membership。
- 创建后 `REVOKE ... FROM CURRENT_USER`：该行的 grantor 是 bootstrap superuser，创建者不能撤销。
- `SET ROLE supabase_admin`：精确镜像没有 `postgres → supabase_admin` membership，且托管项目不开放 superuser。
- 在 `roles.sql` 中嵌入 `supabase_admin` 密码、dblink、容器 init 注入或平台内部管理通道：不可移植、会引入 secret/超出项目授权，不接受。
- 删除 membership guard 或改用 `service_role`/table owner：扩大权限，不接受。

## Recommended minimal contract revision

保持 dedicated `rebuy_invite_executor`、七项安全属性、FORCE RLS、最小列权限、两个 public invoker wrappers/private definer implementations、无 login/API role grants 等全部合同，只把 `pg_auth_members` 从“双向零行”改为以下精确白名单：

- executor 作为 member：必须零行；
- executor 作为 granted role：必须恰好一行；
- 唯一 member 必须是 `postgres`；
- 唯一 grantor 必须是 bootstrap superuser（当前精确镜像为 `supabase_admin`）；
- 必须 `admin_option=true`、`inherit_option=false`、`set_option=false`；
- 不允许 `anon`、`authenticated`、`authenticator`、`service_role` 或任何其他角色 membership；
- pgTAP 必须验证 `postgres` 不能通过该行继承 executor 权限或 `SET ROLE`；任何额外行或选项变化立即 fail closed。

这条记录只给数据库管理员保留管理能力，不给 `postgres` 自动执行或切换到 executor 的能力；它是 PostgreSQL 17 对非超级用户角色创建的强制平台事实，不是应用授权路径。该修订仍需 Owner 对 Gate 精确例外作 action-time 批准，批准前不得修改候选或再次运行 runtime。

## Boundary

- 当前候选 hashes 保持 attempt #3 入口状态：roles=`7f1d81955b78f0879e2ea3870689079db239e0d3`、migration=`eb44217e56c1c16a7eb1edb9ca43f9ed2eb9ff84`、structure=`0540f3117db0874fa6e0c38d750e16d5576b13ea`。
- 未连接 hosted/Production，未使用 secret、真实数据或付费资源。
- P2-L runtime、P3–P7、commit/push/deploy 继续关闭。
