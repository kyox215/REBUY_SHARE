# G2-A0 Owner 验收清单

文档状态：Entry 已授权 / G2-A0 执行中；Exit 待独立安全审查与 Owner 验收
当前前置：G1 Exit 已由 Owner 于 2026-08-27 签署 GO；本清单只打开 docs-only A0 合同执行，不打开 G2-A1 实测或外部资源。
证据边界：本清单是合同、审查和 Owner Gate 入口，不代表 Supabase/Auth、数据库、Storage、RLS 或任何外部环境已连接或实现。
当前状态源：[项目状态与阶段台账](../15-项目状态与阶段台账.md)
配套记录：[G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)；[G2-A0 Entry preflight](../evidence/G2-A0/2026-08-26-entry-preflight/README.md)

## 1. 当前结论与 Entry / Exit 边界

- G2-A0 当前状态为“执行中”。本批只整理安全合同、威胁模型一致性、阶段证据和 Owner 验收准备；不创建或连接 provider/project。
- G1 Exit 前置已满足：Owner 已签署 G1-19，G1 Exit=GO，日期=`2026-08-27`，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`。
- G2-A0 Entry 已授权，但授权仅覆盖本地 docs-only 候选；不能解释为 Auth、数据库、Storage、真实账号、真实 PII、生产或外部资源授权。
- G2-A0 Exit 尚未发生。独立安全审查、Owner 待决矩阵和 Owner 明确 Exit 签署完成前，不得把本阶段标为“已通过”。
- G2-A1 当前仍为“未开始”。A0 Exit 将来至多打开 A1 准备门；Supabase project/plan/region、费用、OAuth、SMTP、secret 和任何连接仍需新的 non-production resource/cost/secret 授权。

## 2. G1 Exit 前置（已满足；不替代 A0 Exit）

| 前置条件 | 当前状态 | 已有证据 | 对 G2-A0 的影响 |
|---|---|---|---|
| G1.2b 真实 CI 与 main merge | 已满足 | PR #5 merge=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`；main Actions run=`33089108238` / job=`98576781415`，install/typecheck/lint/build success | 允许继续 G2-A0 Entry；不替代 A0 安全审查 |
| G1.3 technical closeout | 已满足 | Owner 验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`；G1-19/G1 Exit GO | 允许打开 A0 docs-only 入口；不授权 Auth/DB/部署 |
| G1 Exit Owner 决定 | 已满足 | Owner 原话、日期、签署和 ref 已记入 [15 台账](../15-项目状态与阶段台账.md) | Entry 通过；A0 Exit 仍待独立审查与 Owner |
| A0 文档权威输入 | 已满足 | [07](../07-完整账号系统规划.md)、[08](../08-账号系统思维导图.md)、[09](../09-A0-账号架构ADR与威胁模型.md) | 本批复用并做状态/术语一致性同步 |

## 3. Requirement-to-evidence 矩阵

状态含义固定使用：`既有合同已覆盖` 只表示 07/08/09 已有设计不变量；`A0 执行中待审查` 表示本批已整理但尚未独立审查或 Owner 签署；`A1 实测（未开始）` 与 `A3/A4 实测（未开始）` 不表示已有运行证据。

| 要求 | 当前状态 | 证据/归属 | G2-A0 Exit 前的缺口 |
|---|---|---|---|
| identity、membership、authorization、verification 四层分离；默认拒绝；职责分离 | 既有合同已覆盖 | [07](../07-完整账号系统规划.md)、[08](../08-账号系统思维导图.md)、[09](../09-A0-账号架构ADR与威胁模型.md) | 独立审查与 Owner Exit |
| 用户删除/暂停/成员撤销后的 session、access token、refresh token 窗口；高风险实时检查 `session_id` | A0 执行中待审查 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A1 观察窗口；A3/A4 负向证据 |
| Data API grants 与 RLS 两层；exposed object allowlist；不以 publishable key 代替授权 | A0 执行中待审查 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | 独立审查原则确认；A1/A3/A4 实测 |
| RLS `UPDATE` 先有 `SELECT`，同时具备 `USING` 与 `WITH CHECK` | A0 执行中待审查 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A3/A4 policy 与跨租户负向 |
| 暴露 view 使用 `security_invoker`，或非暴露 schema 等价保护 | A0 执行中待审查 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A3/A4 view/RLS 实测 |
| `SECURITY DEFINER` 最小化；固定 `search_path`、schema-qualified 引用、撤销 `PUBLIC EXECUTE`、显式角色 allowlist | A0 执行中待审查 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A3/A4 function 权限和越权负向 |
| Storage `upsert` 同时具备 `INSERT`、`SELECT`、`UPDATE`；桶私有、对象归属可审计 | A0 执行中待审查 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A4 Storage policy、签名 URL 与替换文件负向 |
| 不在 managed `auth`/`storage`/`realtime` schema 创建或破坏自定义对象 | A0 执行中待审查 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | A1/A3/A4 实施时核验 |
| SSR 每请求新 client；Proxy 负责 cookie refresh；并发请求、过期 session 不互相串用户 | A0 执行中待审查 | [10 A1 合同](../10-A1-Auth-Spike执行合同.md#114-a1a3a4-验证责任分配)、[11 连接记录](../11-发布与Supabase连接记录.md#6-ssr-与发布前安全边界) | A1 独立环境运行 |
| provider、plan、region、session lifetime、single-session、refresh delay 矩阵 | A1 实测（未开始） | [10 A1 合同](../10-A1-Auth-Spike执行合同.md) | Owner 选择候选；A1 记录实际版本/日期/结果 |
| phone/SMS MFA 边界 | A0 执行中待审查 | 本清单第 5 节；[09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | Owner 决定；采纳后 A1 才可不测试 |
| publishable key 非授权边界；service role 只在受信服务端 | A0 执行中待审查 | [09](../09-A0-账号架构ADR与威胁模型.md)、[11 连接记录](../11-发布与Supabase连接记录.md#3-环境变量密钥与授权边界) | A1/A3/A4 bundle、grants/RLS 和服务端检查 |
| 静态恢复码边界 | A0 执行中待审查 | 本清单第 5 节；[09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充待-g2-a0-owner-gate) | Owner 决定；A1 验证供应商能力 |
| 完整业务 RLS、Storage、view/function、申请三元组、原子审批与跨租户负向 | A3/A4 实测（未开始） | [07 A3/A4 合同](../07-完整账号系统规划.md#15-分阶段路线-a0a6) | 不以 A0 文档或 A1 基础测试代替 |
| Apple/Google/邮箱 OTP、linking、MFA、signOut 和 token 窗口 | A1 实测（未开始） | [10 A1 合同](../10-A1-Auth-Spike执行合同.md)、[11 连接记录](../11-发布与Supabase连接记录.md) | 不在 A0 写成已实现 |

## 4. G2-A0 Exit 审查清单

以下清单区分“已完成的 Entry/文档整理”和“尚待完成的 Exit”。

### 4.1 已完成或已满足

- [x] G1-19/G1 Exit GO、日期和验收 ref 已归档。
- [x] 复用 07/08/09 权威内容，不重复创建 ADR/PRD/完整权限矩阵/威胁模型。
- [x] 形成 A0-01～A0-15 及日期化 Entry 补充的统一引用。
- [x] 形成覆盖账号枚举、撞库、接管、会话、CSRF/XSS、权限提升、跨租户、邀请滥用和停用/删除残余访问的威胁矩阵。
- [x] 保留 Auth/DB/Storage/Realtime、secret/env、真实账号/PII、部署和远端写入禁止边界。
- [x] 明确 A0 Exit 只打开 G2-A1 准备门，A1 资源/费用/secret/连接需独立授权。

### 4.2 待独立审查与 Owner Exit

- [ ] 独立安全审查人逐项复核 07/08/09、03 高层角色摘要、10 A1 资源边界和本清单威胁矩阵。
- [ ] 独立审查人确认 grants/RLS/exposed allowlist、UPDATE 三条件、view/function 权限、Storage 规则和默认拒绝边界的一致性；不把文档当成运行证据。
- [ ] Owner 决定 phone/SMS MFA、静态恢复码、AAL2 范围/时点、双人复核和 A1 provider 候选。
- [ ] Owner 确认 GDPR/税务留存、legal hold、跨境和处理者合同交由 A5/法律顾问，不在 A0 代替法律结论。
- [ ] Owner 明确签署 G2-A0 Exit；通过后只将 G2-A1 改为“准备中/待资源授权”，不直接开始 Auth 实测。

## 5. Owner 决策矩阵

以下“建议”只供 Owner 选择，当前不视为已采纳。

| 决策项 | 建议/候选 | 当前决定 | 后续约束 |
|---|---|---|---|
| phone/SMS MFA | 建议 V1 不使用 phone/SMS MFA | 待 Owner 决定 | 采纳后 A1 可不测试；不采纳则修订 A1 合同并重新评审 |
| 静态恢复码 | 建议 V1 不使用静态恢复码；采用不同设备/安全位置备用 TOTP + 受审计人工恢复 | 待 Owner 决定；供应商能力待 A1 验证 | 恢复必须身份核验、职责分离、AAL/会话重置、通知和审计 |
| AAL2 强制范围/时点 | 平台 owner/admin/reviewer 从上线前强制；商家 owner/admin 最迟 Beta 前强制；普通买家按风险提升；高风险动作重新认证 | 待 Owner 决定 | 影响 A1 矩阵和 P2/P6 高风险动作 |
| 双人复核 | MFA 人工恢复、owner 转移、角色/权限策略变更、敏感导出、隐私删除/导出、证明文件高风险访问 | 待 Owner 决定 | 指定第二责任人、AAL、通知、审计、拒绝和回退证据 |
| A1 provider | Supabase 优先；Clerk/Auth0 只作比较 | 待 Owner 决定；A0 不锁 provider | A1 记录能力、限制、版本、数据/区域边界 |
| A1 plan/region/session | A0 不锁 provider、plan、region、session lifetime、single-session、refresh delay | 待 Owner 决定 | 需 A1 实测并记录观察窗口；不得凭默认值承诺 |
| A1 资源/费用/secret | 需要新的 non-production resource/cost/secret 授权；本次 A0 不授权 | 未授权 | 不得创建项目、产生费用、配置 secret 或连接任何环境 |
| GDPR/税务与删除 | GDPR/税务留存、legal hold、跨境/处理者合同留给 A5 与法律/税务顾问 | 待 Owner/顾问决定 | 未有意见前不处理真实 PII、不把规划期限当法律结论 |

已确定且不重复询问：支持多店铺；批发手动切换是产品交互事实但不是授权依据；`wholesale application` 与 `wholesale qualification` 分离；identity/membership/authorization/verification 分层；浏览器不得持 service role。

## 6. Owner 决定栏

| 决定 | 当前值 |
|---|---|
| G1 Exit | GO；2026-08-27；ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160` |
| G2-A0 Entry | 已授权；2026-08-27；仅 docs-only 候选 |
| G2-A0 当前状态 | 执行中 |
| G2-A0 Exit | 待独立安全审查与 Owner 验收 |
| G2-A1 | 未开始 / 关闭 |
| 独立安全审查 | 待指定 / 未完成 |
| Owner 原话 | `确认 G1.3 technical closeout 通过；验收 ref=d51f1c7cb47e2fe2932b29bd39420f5d092a8160；签署 G1-19，G1 Exit GO，日期 2026-08-27，并授权打开 G2-A0。` |
| 签署人 / 日期 | Hexiang Huang / 2026-08-27（G1-19；G2-A0 Exit 尚未签署） |

## 7. 官方规划依据（2026-08-27 文档复核）

以下官方页面只作为控制设计依据，实施当天必须按实际 Supabase 版本、区域和项目重新核验；本清单没有读取或写入 provider/project：

- [Supabase securing your API](https://supabase.com/docs/guides/api/securing-your-api)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Database Functions](https://supabase.com/docs/guides/database/functions)
- [Supabase Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control)
- [Supabase SSR client](https://supabase.com/docs/guides/auth/server-side/creating-a-client)
- [Supabase sessions](https://supabase.com/docs/guides/auth/sessions)
- [Supabase MFA](https://supabase.com/docs/guides/auth/auth-mfa)
- [Supabase managed schema restrictions](https://supabase.com/changelog/34270-restricting-access-on-auth-storage-and-realtime-schemas-on-april-21-2025)
