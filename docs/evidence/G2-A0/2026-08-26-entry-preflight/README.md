# G2-A0 Entry preflight 安全补充证据

阶段：G2-A0 账号安全合同与威胁模型
批次：Entry preflight 安全补充
状态：`Entry preflight / G2-A0 未开始`
证据级别：本地静态 + 官方页面只读规划依据
记录日期：2026-08-26（Europe/Rome）
当前状态源：[项目状态与阶段台账](../../../15-项目状态与阶段台账.md)
配套清单：[G2-A0 Owner 验收清单](../../../stages/G2-A0-Owner验收清单.md)

## 1. 目标、范围与 Owner 边界

### 目标

- 把独立只读安全审查发现的 Supabase/Auth、RLS、Storage、SSR、会话和 MFA 控制补入 A0 合同。
- 建立“既有合同 / 本次 Entry preflight / A1 实测 / A3-A4 实测”的证据分层，防止规划内容被误读为已实现。
- 为未来 G2-A0 Owner 审查准备可追溯清单，同时保持 G1 Exit 与 G2-A0 的阶段顺序。

### 本批范围

- 新增[G2-A0 Owner 验收清单](../../../stages/G2-A0-Owner验收清单.md)。
- 在[09 A0 ADR 与威胁模型](../../../09-A0-账号架构ADR与威胁模型.md)新增日期化 Entry preflight 安全补充。
- 同步[07 账号规划](../../../07-完整账号系统规划.md)、[08 思维导图](../../../08-账号系统思维导图.md)、[10 A1 合同](../../../10-A1-Auth-Spike执行合同.md)、[11 连接记录](../../../11-发布与Supabase连接记录.md)、15 台账和导航。

### 排除与停止边界

- G1 Exit 当前为 NO-GO；G2-A0 仍为“未开始”。本批不打开正式 G2-A0，不授权 G2-A1。
- 不创建、连接、登录或修改 Supabase/Auth/DB/Storage/Realtime 项目；不读取 env、secret、token、PII 或外部 provider 资产。
- 不写 SQL、migration、fixture 值或产品代码；不修改 `prototype/**`、依赖、package/lockfile、workflow、配置、Git refs/remote。
- 官方页面读取只用于规划和风险核对，不构成 Rebuy 项目能力、供应商合同或运行证据。

## 2. 当前 Gate 与证据分层

- 15 台账仍是唯一当前状态源：G0/P1 已通过并冻结；G1 执行中，G1.1/G1.2a 已完成，G1.2b 待 Owner Gate；G1.3-0 本地预检完成但 G1.3 实施未开始；G1 Exit 未通过；G2-A0/G2-A1/P2–P8 不打开。
- 本批没有新的 Owner 开门原话；Owner 签署栏保持空白/N/A。只有 G1 Exit 明确通过，并由 Owner 明确批准正式 G2-A0 安全审查后，才能把 A0 合同送入正式审查。
- 既有 07/08/09 已覆盖四层模型、租户边界、职责分离和默认拒绝；本批只补容易被平台默认行为或客户端便利误读的控制。
- A1 只验证候选 provider/Auth/session/SSR/MFA 能力；A3/A4 才验证完整业务 RLS、view/function、Storage、申请三元组、原子事务和跨租户负向。任何一层未验证都不能写成“已具备”。

## 3. 独立只读安全审查发现

### 高风险

| 编号 | 发现 | 本批处理 | 未关闭证据 |
|---|---|---|---|
| H-01 | 删除/暂停用户、membership 或资格后，旧 access token 的 `exp` 窗口和 session 撤销语义容易被写成即时失效 | 09/07/08 明确高风险实时检查 `session_id`、user、membership、scope 和资格；不承诺即时踢出 | A1 观察 session/token 时间窗口与并发时间线；A3/A4 验证业务拒绝与跨租户负向 |
| H-02 | Data API grants 与 RLS 是两层控制；exposed object allowlist、view/function 权限不能只靠 RLS 或 key | 09/07/08/10 增加 grants、RLS、allowlist 和客户端边界 | A1 基础 reachability；A3/A4 完整对象与跨租户负向 |
| H-03 | UPDATE、view、SECURITY DEFINER、Storage upsert 的默认权限可能产生静默越权或失败 | 09 增加 SELECT + USING + WITH CHECK、`security_invoker`、固定 `search_path`、撤销 `PUBLIC EXECUTE`、角色 allowlist、Storage 三权限合同 | A3/A4 policy/function/view/Storage 实测 |
| H-04 | managed `auth`/`storage`/`realtime` schema 的平台限制可能被错误迁移或自定义对象破坏 | 09/10 增加禁止写 managed schema、自有对象使用受控 schema 的边界 | A1/A3/A4 按实施版本核对迁移 |
| H-05 | publishable key、静态恢复码和 phone/SMS MFA 的产品/供应商语义容易被混写 | 07/08/09/10 明确 key 非授权边界；Entry preflight 仅提出 phone/SMS MFA 与静态恢复码候选建议，待 G2-A0 Owner 确认；供应商能力仍待 A1 | Owner 确认候选产品边界；A1 验证供应商实际能力 |

### 中风险

| 编号 | 发现 | 本批处理 | 未关闭证据 |
|---|---|---|---|
| M-01 | SSR client 复用、Proxy cookie refresh 和并发刷新可能造成跨用户串线或过期会话误判 | 10/11 增加每请求新 client、未来 Proxy、request/response cookie、并发/过期测试边界 | A1 独立环境运行证据 |
| M-02 | provider、plan、region、session lifetime、single-session、refresh delay 若不成矩阵，默认值会被误当承诺 | 10 与 Owner 清单明确统一矩阵和版本/日期/观察窗口 | A1 实测及 Owner 选择 |
| M-03 | A1 基础安全核验与 A3/A4 完整业务 RLS/Storage 责任混淆 | 10 增加 A1/A3/A4 责任分配和停止条件 | A3/A4 业务对象、租户和权限负向 |

### 低风险但必须纠正

| 编号 | 发现 | 本批处理 | 未关闭证据 |
|---|---|---|---|
| L-01 | “供应商不支持静态恢复码”是未经 A1 验证的能力断言 | 07/08/09 统一改为 Entry preflight 候选建议，待 G2-A0 Owner 确认；供应商能力仍待 A1 验证 | Owner 产品边界确认、A1 能力记录 |
| L-02 | A0 Entry 文档缺少稳定的 Owner checklist 与正式审查前置说明 | 新增清单、证据和 15/阶段索引入口 | G1 Exit 通过与 Owner Gate |

## 4. 本批控制补充摘要

| 控制 | 当前证据 | 后续阶段 |
|---|---|---|
| 删除/暂停/撤销后的 token/session 窗口 | 规划补充，未运行；A1 观察 session/token 时间窗口 | A1 观察窗口 + A3/A4 业务拒绝/跨租户负向 |
| Data API grants、RLS、exposed allowlist | 规划补充，未连接 | A1 基础 + A3/A4 完整 |
| UPDATE 的 SELECT、USING、WITH CHECK | 规划补充，未实现 | A3/A4 |
| view `security_invoker` | 规划补充，未实现 | A3/A4 |
| SECURITY DEFINER 固定 search_path、撤销 PUBLIC EXECUTE、角色 allowlist | 规划补充，未实现 | A3/A4 |
| Storage upsert 的 INSERT、SELECT、UPDATE | 规划补充，未连接 | A4 |
| managed schema 限制 | 官方规划依据，未连接项目 | A1/A3/A4 |
| SSR 每请求新 client、Proxy/cookie refresh、并发/过期 session | 本地骨架边界，未运行 | A1 |
| provider/plan/region/session lifetime/single-session/refresh delay | 矩阵合同，未选择/实测 | A1 + Owner |
| phone/SMS MFA 边界 | Entry preflight 候选建议，待 G2-A0 Owner 确认 | Owner 采纳后 A1 才可不测试；不采纳则修订 A1 合同并重新评审 |
| publishable key 非授权边界 | 规划补充，未连接 | A1/A3/A4 |
| 静态恢复码边界 | Entry preflight 候选建议，待 G2-A0 Owner 确认；供应商能力未知 | Owner 先确认产品边界，A1 验证供应商能力 |

## 5. 文件变更与本地验证边界

### 文件变更

- 新增：`docs/stages/G2-A0-Owner验收清单.md`、本文件。
- 修改：09、07、08、10、11、15、`docs/stages/README.md`、`docs/README.md`。
- 未修改：`prototype/**`、`.github/workflows/prototype-quality.yml`、package/lockfile、配置、Git refs、remote。

### 验证与跳过项

本批最终检查（2026-08-26）已覆盖 `docs/**/*.md` 的 41 个 Markdown 文件、480 个本地相对链接/fragment；文件与 fragment 全部可解析。围栏共 56 个标记并全部成对，敏感模式扫描为 0，G1/G2 状态与本批控制术语扫描通过，`git diff --check` 通过。检查只证明文档边界，不证明 provider、Auth、数据库、Storage、SSR、CI、Preview 或生产能力。

- 只做文档级静态检查和受保护路径核对；不重跑 typecheck、lint、build、E2E，因为本批不改变产品代码、依赖、workflow 或生成物，相关证据可复用。
- 不做 hash：没有生成物、传输物或异常覆盖疑点。
- 不进行 provider/project 连接；官方页面只读访问不等于任何外部项目状态。

## 6. 风险、回退与维护

- 风险：Supabase 文档、默认权限、Auth/SSR API 和套餐能力会变化；实施当天必须重新核验版本、区域、计划和官方页面，不把本次日期化依据当成永久承诺。
- 风险：A1 的 Auth/session 证据不能覆盖 A3/A4 业务 RLS、view/function、Storage 和跨租户安全；Owner 需按本清单分阶段验收。
- 回退：若 Owner 或安全审查认为补充措辞改变了既有 ADR，只回退本批文档提交或追加日期化纠正，不回退 G0/G1 证据，不使用覆盖性 Git 操作，不连接外部资源。
- 维护：每次 provider/SDK/SSR/数据库平台升级复核 source links、grants/RLS、managed schema、Storage、session、MFA 和文档状态；变更必须追加证据和 Owner 决定。
- 敏感边界：证据只记录控制、版本、结果分类和脱敏摘要，不记录 token、cookie、OTP、key、secret、邮箱、真实 PII 或生产对象。

## 7. Owner Gate

- 当前决定：未签署；G2-A0 仍未开始；G1 Exit NO-GO；G2-A1/A3/A4 实测均未开始。
- 正式入口：G1 Exit 通过 → Owner 明确批准 G2-A0 正式安全审查 → 独立审查 07/08/09 与本 Entry 补充 → 再决定是否打开 G2-A1。任何 A1/A3/A4 能力未验证，都不得回写成现行实现事实。
- Owner 决定栏：

| 项目 | 值 |
|---|---|
| Owner 是否批准正式 G2-A0 | 待明确 / N/A |
| Owner 原话 | ______________________________ |
| 签署人 / 日期 | ______________________________ |

推荐未来授权语句（当前未授权）：

> `G1 Exit 已明确通过；我确认 07/08/09 与 G2-A0 Entry preflight 已完成独立安全审查，批准启动 G2-A0 正式审查；A1、A3、A4 仍须在隔离环境提供各自证据，暂不连接生产或真实 PII。`

## 8. 官方规划依据（2026-08-26 只读复核）

本批通过官方公开页面进行只读规划核对，没有登录、读取项目配置或连接 provider。实施当天需重新检查页面版本和适用范围：

- [Supabase breaking change：managed auth/storage/realtime schema](https://supabase.com/changelog/34270-restricting-access-on-auth-storage-and-realtime-schemas-on-april-21-2025)
- [Supabase securing your API](https://supabase.com/docs/guides/api/securing-your-api)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Database Functions](https://supabase.com/docs/guides/database/functions)
- [Supabase Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control)
- [Supabase SSR client](https://supabase.com/docs/guides/auth/server-side/creating-a-client)
- [Supabase sessions](https://supabase.com/docs/guides/auth/sessions)
- [Supabase MFA](https://supabase.com/docs/guides/auth/auth-mfa)
- [Supabase user management/deletion](https://supabase.com/docs/guides/auth/managing-user-data)
