# G2-A0 Owner 验收清单

文档状态：Entry preflight / G2-A0 未开始
当前前置：G1 Exit 为 NO-GO；只有 G1 Exit 明确通过后，才能授权正式 G2-A0 安全审查
证据边界：本清单是合同、预检和 Owner Gate 入口，不代表 Supabase/Auth、数据库、Storage、RLS 或任何外部环境已连接或实现。
当前状态源：[项目状态与阶段台账](../15-项目状态与阶段台账.md)
配套证据：[G2-A0 Entry preflight](../evidence/G2-A0/2026-08-26-entry-preflight/README.md)

## 1. 当前结论与 Entry 边界

- G2-A0 当前状态仍为“未开始”。本批只补充安全合同、证据索引和 Owner 验收准备，不打开 G2-A0，不创建或连接 provider/project。
- G1 Exit 当前为 NO-GO。G1.2b 真实 GitHub Actions run、canonical repo/Actions 权限确认、Preview 实际部署、在线 bad ref→good ref 回退和 G1 Exit Owner 签署仍缺失或为 `unknown`。
- G1 Exit 通过前只能维护文档、接口草图、测试用例和合成 fixture；不得以本清单授权 Auth、数据库、Storage、真实账号、真实 PII 或生产连接。
- G2-A0 正式审查的入口是 G1 Exit 通过、当前 A0 合同和本清单经 Owner 明确签署；本地静态/规划证据不能替代独立安全审查。

## 2. G1 Exit 前置（当前缺失）

| 前置条件 | 当前状态 | 必须补齐的证据 | 未满足时的动作 |
|---|---|---|---|
| G1.2b 真实 CI | 缺失 | canonical repo、一次真实 Actions run、脱敏日志和权限结论 | 不打开 G2-A0 |
| G1.3 Preview 与在线回退 | 缺失 | 已过 CI 的 ref、Preview 部署、健康边界、bad ref→good ref 在线回退 | 不打开 G2-A0 |
| G1 Exit Owner 决定 | 缺失 | Owner 明确通过原话、日期、签署人和完整 requirement-to-evidence 记录 | 不打开 G2-A0 |
| 外部 provider 资产只读盘点 | `unknown` | 在选择 Preview/provider 前，以授权账户完成只读盘点；不读取 secrets | unknown 不得写成不存在，不授权创建资源 |

## 3. Requirement-to-evidence 矩阵

状态含义在本表中固定使用：`既有合同已覆盖` 只表示 07/08/09 已有设计不变量；`预检已补但待 Owner` 只表示本批补充合同尚未获 G2-A0 签署；`A1 实测（未开始）` 与 `A3/A4 实测（未开始）` 不表示已有运行证据。

| 要求 | 当前状态 | 证据/归属 | 进入正式审查前的缺口 |
|---|---|---|---|
| identity、membership、authorization、verification 四层分离；默认拒绝；职责分离 | 既有合同已覆盖 | [07 账号规划](../07-完整账号系统规划.md)、[08 思维导图](../08-账号系统思维导图.md)、[09 ADR](../09-A0-账号架构ADR与威胁模型.md) | G2-A0 Owner 验收与独立安全审查 |
| 用户删除/暂停/成员撤销后的 session、access token、refresh token 窗口；高风险实时检查 `session_id` | 预检已补但待 Owner | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A1 实测窗口和业务拒绝证据 |
| Data API grants 与 RLS 两层；exposed object allowlist；不以 publishable key 代替授权 | 预检已补但待 Owner | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A1 基础配置核验、A3/A4 完整对象负向测试 |
| RLS `UPDATE` 先有 `SELECT`，同时具备 `USING` 与 `WITH CHECK` | 预检已补但待 Owner | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A3/A4 policy 与跨租户负向证据 |
| 暴露 view 使用 `security_invoker`，或放入非暴露 schema 并有等价保护 | 预检已补但待 Owner | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A3/A4 view/RLS 实测 |
| `SECURITY DEFINER` 最小化；固定 `search_path`、schema-qualified 引用、撤销 `PUBLIC EXECUTE`、显式角色 allowlist | 预检已补但待 Owner | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A3/A4 function 权限和越权负向测试 |
| Storage `upsert` 同时具备 `INSERT`、`SELECT`、`UPDATE`；桶私有、对象归属可审计 | 预检已补但待 Owner | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A4 Storage policy、签名 URL 与替换文件负向测试 |
| 不在 managed `auth`/`storage`/`realtime` schema 创建或破坏自定义对象；自有对象迁移到受控 schema | 预检已补但待 Owner | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A1/A3/A4 迁移与平台约束核验 |
| SSR 每请求新 client；Proxy 负责 cookie refresh；并发请求、过期 session 不互相串用户 | 预检已补但待 Owner | [10 A1 合同](../10-A1-Auth-Spike执行合同.md#114-a1a3a4-验证责任分配)、[11 连接记录](../11-发布与Supabase连接记录.md#6-ssr-与发布前安全边界) | A1 独立环境运行与并发/过期测试 |
| provider、plan、region、session lifetime、single-session、refresh delay 矩阵 | A1 实测（未开始） | [10 A1 合同](../10-A1-Auth-Spike执行合同.md#114-a1a3a4-验证责任分配) | Owner 先选候选，再由 A1 记录版本/日期/实测结果 |
| V1 不采用 phone/SMS MFA；除非新 Owner 决定 | 既有合同已覆盖 | [07 账号规划](../07-完整账号系统规划.md)、[08 思维导图](../08-账号系统思维导图.md) | A1 不测试该路径；新决定需重新评审 |
| publishable key 可出现在浏览器，但不是授权边界；service role 只在受信服务端 | 预检已补但待 Owner | [11 连接记录](../11-发布与Supabase连接记录.md#3-环境变量密钥与授权边界)、[09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A1/A3/A4 检查 grants、RLS、服务端授权和 bundle/日志 |
| Rebuy V1 不采用静态恢复码；供应商能力待 A1 验证 | 预检已补但待 Owner | [07 账号规划](../07-完整账号系统规划.md)、[08 思维导图](../08-账号系统思维导图.md)、[09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A1 验证供应商实际因子/恢复能力；产品政策变更需新 Owner 决定 |
| 完整业务 RLS、Storage、view/function、申请三元组、原子审批与跨租户负向 | A3/A4 实测（未开始） | [07 A3/A4 合同](../07-完整账号系统规划.md#15-分阶段路线-a0a6) | 不以本地合同或 A1 基础测试代替业务测试 |
| Apple/Google/邮箱 OTP、linking、MFA、signOut 和 token 窗口 | A1 实测（未开始） | [10 A1 合同](../10-A1-Auth-Spike执行合同.md)、[11 连接记录](../11-发布与Supabase连接记录.md) | 不在 G2-A0 Entry preflight 写成已实现 |

## 4. G2-A0 正式审查清单

只有第 2 节 G1 Exit 前置全部满足并由 Owner 明确通过后，以下清单才可作为正式 G2-A0 审查入口：

- [ ] Owner 审阅 07/08/09 与本 Entry 补充，确认四层模型、租户边界、职责分离、MFA 恢复和删除/撤销不变量。
- [ ] 安全审查确认 grants/RLS/exposed allowlist、UPDATE 三条件、view/function 权限和 Storage 规则不会被客户端或 publishable key 绕过。
- [ ] Owner 确认 A1、A3、A4 的责任分配、负向测试、脱敏证据、停止条件和回退入口。
- [ ] Owner 确认 provider/plan/region/会话策略与 V1 phone/SMS MFA 边界；未验证的供应商能力保持未知。
- [ ] Owner 确认正式 G2-A0 通过后，才可进入 G2-A1；本清单不能直接授权 Auth 或数据库实现。

## 5. Owner 决定栏

本栏刻意留空，当前不能生成签署日期或“已通过”结论：

| 决定 | 当前值 |
|---|---|
| G1 Exit | NO-GO / 未通过 |
| G2-A0 Entry | 未开始 / N/A |
| Owner 是否批准正式 G2-A0 | 待明确 |
| Owner 原话 | ______________________________ |
| 签署人 / 日期 | ______________________________ |

推荐未来授权语句（当前未授权）：

> `G1 Exit 已明确通过；我确认 07/08/09 与本清单的 Entry 补充已经过独立安全审查，批准启动 G2-A0 正式安全审查；仅使用隔离测试数据和最小权限，暂不打开 G2-A1、生产 Auth、真实 PII 或其他后续阶段。`

## 6. 官方规划依据（2026-08-26 只读复核）

以下官方页面只作为控制设计依据，实施当天必须按实际 Supabase 版本、区域和项目重新核验；本清单没有读取或写入 provider/project：

- [Supabase securing your API](https://supabase.com/docs/guides/api/securing-your-api)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Database Functions](https://supabase.com/docs/guides/database/functions)
- [Supabase Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control)
- [Supabase SSR client](https://supabase.com/docs/guides/auth/server-side/creating-a-client)
- [Supabase sessions](https://supabase.com/docs/guides/auth/sessions)
- [Supabase MFA](https://supabase.com/docs/guides/auth/auth-mfa)
- [Supabase managed schema restrictions](https://supabase.com/changelog/34270-restricting-access-on-auth-storage-and-realtime-schemas-on-april-21-2025)
