# G2-A1 E1 local bootstrap 证据

## 1. 结论

- 日期：2026-08-29（Europe/Rome）。
- 当前状态：**E1 local bootstrap 已以 PR #15 merge commit 完成 main/远端交付闭环；仅代表 E1 本地隔离骨架；独立安全审查 GO（P0=0/P1=0，唯一 P2 已修）；本地 start/status/health 已通过，并已完成项目限定 stop/cleanup**。
- 本批完成 Supabase CLI 生成、E1 窄范围本地配置、comments-only seed scaffold、image-download Gate、loopback network Gate、两次项目限定 start/status/health 复验和 cleanup；独立安全审查 GO（P0=0/P1=0，唯一 P2 已修）；不代表 E2 或 hosted/Production 能力已打开。
- E1 仅验证 API、DB、Meta、Studio、Inbucket/Mailpit 的本地运行骨架；`auth.enabled=false`，不执行任何 Auth 流程。
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
  | `inbucket.port` | `55324` | local web catcher；E1 Mailpit |
  | `analytics.vector_port` | `55326` | generated field；`analytics.enabled=false` |
  | `analytics.port` | `55327` | generated field；`analytics.enabled=false` |
  | `edge_runtime.inspector_port` | `55328` | generated field；`edge_runtime.enabled=false` |
  | `db.pooler.port` | `55329` | generated field；pooler `enabled=false` |

- `55325` 未分配；`realtime`、`storage`、`storage.s3_protocol`、`edge_runtime`、`analytics` 和 `auth` 均 disabled。SMTP/POP3 未启用或发布；Google/Apple 保持 disabled 且无 secret 字段；未启用 custom SMTP，未写 hosted link、secret 或 env secret 值。`site_url` 精确保留为 `http://127.0.0.1:3000`，`additional_redirect_urls` 精确保留为 `["http://127.0.0.1:3000/auth/callback"]`，仅作未来 Auth 边界；未启用 Auth、Storage、业务 schema 或 provider。

## 4. Exact image cache、image-download Gate 与启动结果

### 4.1 解析依据

- 先通过 CLI `--help`、`supabase services -o json` 和 binary 当前模板解析当前 CLI 版本的服务与默认 image ref；binary-derived refs 仅为首次诊断候选，非权威运行时 image 事实；没有凭猜测补写 destructive flag 或版本。
- `supabase start --help` 的逻辑排除名为 `analytics,db,edge-runtime,functions,imgproxy,inbucket,kong,meta,realtime,rest,storage,studio,vector`；实际启动 warning 列出的有效 Docker 容器名为 `edge-runtime,gotrue,imgproxy,kong,logflare,mailpit,postgres-meta,postgrest,realtime,storage-api,studio,supavisor,vector`。因此 `analytics→logflare`、`storage→storage-api`、`functions→edge-runtime`；另显式排除 E1 不需要的 `gotrue` 与 `supavisor`。未使用 `--ignore-health-check`。
- CLI catalog 还显示当期服务版本：Postgres `17.6.1.106`、GoTrue `v2.188.1`、PostgREST `v14.10`、Realtime `v2.86.3`、Storage `v1.54.1`、Edge Runtime `v1.73.13`、Studio `2026.04.28-sha-89d08a2`、Meta `v0.96.4`、Logflare `1.39.1`、Supavisor `2.7.4`。这些 catalog 值与 binary 默认 pull 模板均只作诊断参考；实际 `supabase start` 的 Pull 结果和运行时容器集合是本批权威事实。
- Docker 只读版本检查：client/server=`29.5.2/29.2.1`，Linux arm64。

### 4.2 初始 binary-derived candidate 诊断（非权威）

先执行 generic Supabase/Mailpit image cache 的 `docker image inspect`；以下 refs 是 binary 模板解析出的首次候选，仅作 Gate 诊断，不作为本次实际运行时的权威 refs。候选缺失因此触发并获批一次 image-download Gate；获批后只运行本地 Rebuy `supabase start`，不执行 hosted 登录/link、费用或 Production 操作；不执行未限定的 `docker ps`，不读取其他项目容器详情。

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

以上只记录批准前的非权威 candidate 诊断，不能推断实际运行时缺失镜像。早期未排除 Vector 的 CLI `2.101.0` 尝试曾触发已知的 Docker/Colima Vector socket-mount 风险：创建 `supabase_vector_rebuy-g2-a1-e1-local-bootstrap-exec` 时返回 `operation not supported`；本批未修改全局 Colima、Docker socket、symlink 或 host runtime。

### 4.3 实际启动、健康与 network Gate

- 通过 `require_escalated` 获批创建唯一精确 network `supabase_network_rebuy-g2-a1-e1-local-bootstrap-exec`，driver=`bridge`，`com.docker.network.bridge.host_binding_ipv4=127.0.0.1`；使用 CLI `--network-id` 复用该名称，不创建候选 network。每轮完成后只删除该精确 network。
- 首轮修正配置的启动按 help 逻辑名传入排除项；CLI 明确警告 `analytics/storage/functions` 不是当前有效容器名。该轮仍仅 Pull `6/6` 且全部 `Skipped - Image is already present locally`，健康与 cleanup 通过，随后停止并清理，仅作为排除名映射诊断保留。
- 第二轮使用实际有效名 `--exclude logflare --exclude vector --exclude realtime --exclude storage-api --exclude imgproxy --exclude edge-runtime --exclude gotrue --exclude supavisor`，Pull `6/6` 全部 `Skipped - Image is already present locally`；无 image pull/download/tag、无版本漂移、无额外服务。
- 两轮实际项目容器名称仅为 `supabase_db_rebuy-g2-a1-e1-local-bootstrap-exec`、`supabase_kong_rebuy-g2-a1-e1-local-bootstrap-exec`、`supabase_rest_rebuy-g2-a1-e1-local-bootstrap-exec`、`supabase_pg_meta_rebuy-g2-a1-e1-local-bootstrap-exec`、`supabase_studio_rebuy-g2-a1-e1-local-bootstrap-exec`、`supabase_inbucket_rebuy-g2-a1-e1-local-bootstrap-exec`，对应 DB、API gateway/API、REST/API、Meta、Studio、Inbucket/Mailpit。published HostIP 全部为 `127.0.0.1`：API=`55321`、DB=`55322`、Studio=`55323`、Mailpit=`55324`；Meta/REST 仅内部端口。未出现 Auth、Realtime、Storage、Vector、Analytics、Imgproxy、Edge Runtime、Functions 或 Supavisor 容器。
- 脱敏 `supabase status -o json` 仅输出 host/port：API/REST/GraphQL/MCP=`127.0.0.1:55321`、DB=`127.0.0.1:55322`、Studio=`127.0.0.1:55323`、Inbucket/Mailpit=`127.0.0.1:55324`；原始 URL、key、password、secret、token 未进入聊天或证据。
- 无数据健康探针：API REST HTTP=`200`；DB `pg_isready` accepting；Studio HTTP=`307`；Mailpit HTTP=`200`；容器 health 为 DB/Meta/Studio/Inbucket/Kong=`healthy`，REST=`running`（无独立 health 状态）。CLI 的通用 `0.0.0.0` notice 与实际 publish 不同，项目限定 inspect 证明 published HostIP 为 loopback。

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
| exact `docker image inspect` | 初始 binary candidate 仅作非权威诊断；若干候选显示 missing，未据此断定实际运行时缺失 |
| `supabase start --network-id ...`（help 逻辑排除名） | 已执行；CLI 警告 `analytics/storage/functions` 无效；Pull `6/6` 全部 local/skipped；健康和 cleanup 通过，随后停止清理 |
| `supabase start --network-id ...`（实际有效排除名） | 已执行；Pull `6/6` 全部 local/skipped；无 pull/download/tag、无版本漂移；stack ready |
| `supabase status -o json`（脱敏管道） | pass；仅保留 loopback host/port，原始 URL/key/password/secret/token 未记录 |
| API/DB/Studio/Mailpit health | pass；REST=`200`、DB accepting、Studio=`307`、Mailpit=`200`；目标容器 health/运行态已核验 |
| `supabase stop --project-id rebuy-g2-a1-e1-local-bootstrap-exec --no-backup` | 两轮均 exit=`0`；输出 `Stopped supabase local development setup.`；未使用 `--all` |
| `docker network rm supabase_network_rebuy-g2-a1-e1-local-bootstrap-exec` | 两轮均成功；只删除本批精确 network |
| project-scoped container/volume/network cleanup | pass；最终项目容器、项目 volume、精确 network 均无输出 |
| 55320–55329 runtime 监听 | 最终 `lsof -nP -iTCP:55320-55329 -sTCP:LISTEN` 无输出（`NO_LISTENERS`） |
| 54321–54324 既有端口不变量 | 仅核对端口存在性，四端口仍为 `LISTENING`；未读取所属进程/容器/network 详情 |

## 6. 安全、外部状态与残余风险

- 本批未创建用户、发送邮件、执行 OTP/invite、登录或 link hosted project，未写 Auth/DB/Storage 数据，未建业务 schema，未读取 secret/PII。文档和 config 中没有 secret 值。
- 未执行未限定的 `docker ps`；没有读取其他项目容器详情。两轮获批 start 的 Pull 阶段均为 `6/6` skipped/local present，没有 image pull 或新下载；两轮项目限定 stop 与精确 network 删除均成功，最终项目容器/volume/network 已无输出，55320–55329 TCP 无监听；54321–54324 仅保持端口存在性核对为 `LISTENING`。
- 本批实际 E1 stack health 已通过并完成清理；残余风险为 CLI `2.101.0` 已知 Vector/Colima socket-mount 风险、binary candidate refs 可能随 CLI 漂移；独立安全审查 GO（P0=0/P1=0，唯一 P2 已修），PR #15 已用 merge commit 完成 main/远端交付闭环；E2 action-time Gate 尚未打开。任何端口冲突、实际 pull/版本漂移、额外服务、0.0.0.0 published binding、现有资源变化、费用、secret/PII 或无法清理都必须 STOP。
- 未运行 prototype 全量 build/test/lint/E2E：本批未改 prototype、package、lockfile 或 workflow；本批风险由 config/TOML、secret/PII、diff 和 Gate 证据覆盖。
- （本地执行证据时点）未做独立审查；本 README 仅为执行证据，不是 Owner Gate。未做哈希检查；本批没有确定性构建物、传输物或异常输出需要 hash。

## 7. 官方当日资料

以下官方页面于 2026-08-29 复核，作为 CLI/config/changelog 的执行依据：

- [Supabase CLI getting started](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [Supabase CLI reference](https://supabase.com/docs/reference/cli)
- [Supabase local config.toml reference](https://supabase.com/docs/guides/local-development/cli/config)
- [Supabase changelog](https://supabase.com/changelog)

## 8. 2026-08-29 远端交付闭环（当前）

- E1 local bootstrap 已以 PR #15 用 merge commit 合并 `main`，完成远端 docs-only 交付闭环；该结果仅代表 E1 本地隔离骨架，不代表 E2 或 hosted/Production 能力已打开。
- PR head=`fc6153b60872328b55b525730f3c653579ac2ea2`，merge=`a5e7fd1ae2ca7468610c0aab936121a27d124c02`，parents=`b3240577026a0f390ae634f2119426842827805e` + `fc6153b60872328b55b525730f3c653579ac2ea2`；PR head CI run=`33256006999`/job=`99109715930` success；main exact merge CI run=`33256185497`/job=`99110205068` success；精确 merge的 GitHub deployments=`0`；来源分支保留。
- 刚刚只读核对的 Vercel 事实为 3 个既有 READY deployments，其中 2 个 Preview、1 个 Production；本批没有新增 deployment。不记录 creator email 或其他 PII。
- 独立安全审查 GO，P0=0、P1=0，唯一 P2 已修。E2–E5、hosted Supabase/Auth/DB/Storage/OAuth/SMTP、真实账号/邮件、业务 schema、新 Vercel deployment、promote/alias/rollback、Production 操作继续 CLOSED；下一步仅可进入 E2 action-time Gate 评估，不代表 E2 已打开或可执行。
