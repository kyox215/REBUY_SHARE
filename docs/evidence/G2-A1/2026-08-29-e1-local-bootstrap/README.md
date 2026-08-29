# G2-A1 E1 local bootstrap 证据

## 1. 结论

- 日期：2026-08-29（Europe/Rome）。
- 当前状态：**E1 local bootstrap 本地候选；获批 image-download Gate 后 start 因 Docker/Colima socket mount 失败；已完成项目限定 stop/cleanup**。
- 本批完成 Supabase CLI 生成、最小本地配置、comments-only seed scaffold、image-download Gate、start attempt 和项目限定 cleanup；未形成 API、DB、Studio、Mailpit 或 Auth 健康证据，不代表 E1 完成验收。
- E2–E5、hosted Auth/DB/Storage/OAuth/SMTP、真实 Auth/OTP/invite、业务 schema、deploy、Production 继续 **CLOSED**。

## 2. 隔离与基线

- Canonical root：`/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划`。
- 唯一 worktree：`/Users/kyox215/Documents/codex应用文件夹/rebuy购物交易计划/.worktrees/rebuy-g2-a1-e1-local-bootstrap-exec`。
- 分支：`codex/g2-a1-e1-local-bootstrap-exec`。
- 创建基线：实时 `origin/main`=`b3240577026a0f390ae634f2119426842827805e`；执行时 worktree HEAD 为该 ref。最终提交 SHA 以交付时 `git rev-parse HEAD` 复核，本记录不预写未来 ref。
- `origin/main` 预检未发现 `supabase/` local config；只新增本批 E1 骨架。未修改 `prototype/`、package、lockfile、workflow、其他 worktree 或 `.worktrees/rebuy-private-merchant-access`。

## 3. 配置结果

- CLI：`/opt/homebrew/bin/supabase`，版本 `2.101.0`。使用临时 `SUPABASE_TELEMETRY_DISABLED=1`，避免 telemetry 写入用户 home；未持久化环境变量。
- `supabase init` 成功生成当期 `supabase/config.toml` 与 `supabase/.gitignore`；本批新增 `supabase/seed.sql`，内容只有注释，无 SQL 语句、数据行、用户、业务表或 fixture。
- `project_id`=`rebuy-g2-a1-e1-local-bootstrap-exec`，仅作为 Rebuy local bootstrap 标识，不用于 hosted project/link。
- 端口映射均在 `55320–55329`：

  | CLI config 字段 | 本批值 | 备注 |
  |---|---:|---|
  | `db.shadow_port` | `55320` | active local mapping |
  | `api.port` | `55321` | active local mapping |
  | `db.port` | `55322` | active local mapping |
  | `studio.port` | `55323` | `api_url` 为 `http://127.0.0.1:55321` |
  | `inbucket.port` | `55324` | local web catcher；未启动 |
  | `analytics.vector_port` | `55326` | active config field |
  | `analytics.port` | `55327` | active config field |
  | `edge_runtime.inspector_port` | `55328` | active config field |
  | `db.pooler.port` | `55329` | pooler `enabled=false` |

- `55325` 未分配；SMTP/POP3 未启用或发布。Auth signup、email signup、Google、Apple、OAuth server 均 disabled；未启用 custom SMTP，未写 hosted link、secret 或 env secret 值。

## 4. Exact image cache、image-download Gate 与启动结果

### 4.1 解析依据

- 先通过 CLI `--help`、`supabase services -o json` 和 binary 当前模板解析当前 CLI 版本的服务与默认 image ref；没有凭猜测补写 destructive flag 或版本。
- CLI catalog 还显示当期服务版本：Postgres `17.6.1.106`、GoTrue `v2.188.1`、PostgREST `v14.10`、Realtime `v2.86.3`、Storage `v1.54.1`、Edge Runtime `v1.73.13`、Studio `2026.04.28-sha-89d08a2`、Meta `v0.96.4`、Logflare `1.39.1`、Supavisor `2.7.4`。这些 catalog 值与 binary 默认 pull 模板分开记录；Gate 以 binary 解析的 exact refs 为准。
- Docker 只读版本检查：client/server=`29.5.2/29.2.1`，Linux arm64。

### 4.2 Exact inspect 结果

先执行 generic Supabase/Mailpit image cache 的 `docker image inspect`；初始 binary-derived exact candidate 检查发现若干 tag 缺失，因此按 STOP 条件请求并获得一次明确 image-download Gate 批准。获批后只运行本地 Rebuy `supabase start`，不执行 hosted 登录/link、费用或 Production 操作；不执行未限定的 `docker ps`，不读取其他项目容器详情。

| Exact image ref | cache 结果 |
|---|---|
| `public.ecr.aws/supabase/postgres:17.6.1.107` | missing |
| `public.ecr.aws/supabase/postgrest:v14.5` | present |
| `public.ecr.aws/supabase/gotrue:v2.188.0-rc.15` | missing |
| `public.ecr.aws/supabase/edge-runtime:v1.73.13` | present |
| `public.ecr.aws/supabase/realtime:v2.78.10` | missing |
| `public.ecr.aws/supabase/storage-api:v1.41.8` | missing |
| `public.ecr.aws/supabase/postgres-meta:v0.96.1` | missing |
| `public.ecr.aws/supabase/studio:2026.03.04-sha-0043607` | missing |
| `public.ecr.aws/supabase/logflare:1.34.7` | missing |
| `public.ecr.aws/supabase/kong:2.8.1` | present |
| `axllent/mailpit:v1.22.3` | missing |
| `timberio/vector:0.28.1-alpine` | missing |
| `darthsim/imgproxy:v3.8.0` | missing |

以上是批准前 binary-derived candidate 检查结果。批准后的 `supabase start` 输出 `Pulling 13/13`，13 项均为 `Skipped - Image is already present locally`；没有实际网络 pull/download/tag，也没有新增镜像下载。随后输出 `Starting database...`、`Initialising schema...`、`Seeding globals from roles.sql...`、`Seeding data from supabase/seed.sql...`、`Starting containers...`、`Stopping containers...`，最终因创建 `supabase_vector_rebuy-g2-a1-e1-local-bootstrap-exec` 时 Docker mount source `/Users/kyox215/.colima/default/docker.sock` 返回 `operation not supported` 而退出，exit=`1`。

## 5. 命令结果摘要

| 命令/动作 | 结果 |
|---|---|
| `git rev-parse origin/main` | pass；exact=`b3240577026a0f390ae634f2119426842827805e` |
| `git worktree add -b codex/g2-a1-e1-local-bootstrap-exec ...` | 首次受本机 git lock 权限限制未改变状态；同一命令经窄范围批准后 pass，目标 worktree 从 exact origin/main 创建 |
| `git ls-tree -r --name-only origin/main` local-config 预检 | pass；未发现 Supabase local config；prototype client 文件不属于本批范围 |
| `SUPABASE_TELEMETRY_DISABLED=1 supabase --version` | pass；`2.101.0` |
| `supabase init` | pass；生成当期 config/ignore |
| `supabase --help`、`init --help`、`start --help`、`status --help`、`stop --help`、`config --help` | pass；按 help 发现命令和 flag；未猜测 destructive flag |
| `supabase services -o json` | pass；取得当前 CLI 服务 catalog |
| `docker version` | pass；client/server=`29.5.2/29.2.1` |
| generic `docker image ls` | pass；只记录通用镜像名/tag，不记录容器详情 |
| exact `docker image inspect` | Gate STOP；3 个 exact refs present，其余所需 refs missing |
| `supabase start` | 已执行（经明确 Gate 批准）；13/13 image pull 项均 skipped/local present；随后因 Docker/Colima socket mount 失败，exit=`1` |
| `supabase status` | 启动失败前后均执行；返回 `No such container: supabase_db_rebuy-g2-a1-e1-local-bootstrap-exec`，未形成健康结论 |
| API/DB/Studio/Mailpit health | 未形成通过证据；stack 未达到 ready |
| `supabase stop --project-id rebuy-g2-a1-e1-local-bootstrap-exec` | 已执行；exit=`0`，输出 `Stopped supabase local development setup.` |
| project-scoped container/volume cleanup | 已核对；项目名容器和项目名 volume 均无输出 |
| 55320–55329 runtime 监听 | stop 后执行 `lsof -nP -iTCP:55320-55329 -sTCP:LISTEN`；无输出（`NO_LISTENERS`） |

## 6. 安全、外部状态与残余风险

- 本批未创建用户、发送邮件、执行 OTP/invite、登录或 link hosted project，未写 Auth/DB/Storage 数据，未建业务 schema，未读取 secret/PII。文档和 config 中没有 secret 值。
- 未执行未限定的 `docker ps`；没有读取其他项目容器详情。获批 start 的 Pull 阶段全部 skipped/local present，没有 image pull 或新下载；项目限定 stop 已成功，项目名容器/volume 已无输出，55320–55329 TCP 无监听。现有其他项目容器详情和 `54321–54324` 不在本批读取范围。
- Docker/Colima mount 失败导致 API/DB/Studio/Mailpit health 未通过，不能宣称本地栈健康。未来重新打开 E1 前必须重新检查完整十端口和 Docker/Colima 前提，并在任何冲突、pull、容器变化、费用、secret/PII 或无法清理时再次 STOP。
- 未运行 prototype 全量 build/test/lint/E2E：本批未改 prototype、package、lockfile 或 workflow；本批风险由 config/TOML、secret/PII、diff 和 Gate 证据覆盖。
- 未做独立审查；本 README 仅为执行证据，不是 Owner Gate。未做哈希检查；本批没有确定性构建物、传输物或异常输出需要 hash。

## 7. 官方当日资料

以下官方页面于 2026-08-29 复核，作为 CLI/config/changelog 的执行依据：

- [Supabase CLI getting started](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [Supabase CLI reference](https://supabase.com/docs/reference/cli)
- [Supabase local config.toml reference](https://supabase.com/docs/guides/local-development/cli/config)
- [Supabase changelog](https://supabase.com/changelog)
