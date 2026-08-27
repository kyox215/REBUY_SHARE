# G2-A0 Owner 验收清单

文档状态：G2-A0 Exit GO；远端 docs-only reconciliation 已获批、尚未执行（本地修复 closeout 待独立复审）；Entry 已授权，七项政策已由 Owner 采纳
当前前置：G1 Exit 已由 Owner 于 2026-08-27 签署 GO；本清单只打开 docs-only A0 合同执行，不打开 G2-A1 实测或外部资源。
证据边界：本清单是合同、审查和 Owner Gate 入口，不代表 Supabase/Auth、数据库、Storage、RLS 或任何外部环境已连接或实现。
当前状态源：[项目状态与阶段台账](../15-项目状态与阶段台账.md)
配套记录：[G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)；[G2-A0 Entry preflight](../evidence/G2-A0/2026-08-26-entry-preflight/README.md)

## 1. 当前结论与 Entry / Exit 边界

- G2-A0 当前状态为“执行中”（Exit GO；远端 docs-only reconciliation 已获批、尚未执行）。本批只整理安全合同、威胁模型一致性、阶段证据和 Owner 验收/closeout；不创建或连接 provider/project。
- G1 Exit 前置已满足：Owner 已签署 G1-19，G1 Exit=GO，日期=`2026-08-27`，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`。
- G2-A0 Entry 已授权，但授权仅覆盖本地 docs-only 候选；不能解释为 Auth、数据库、Storage、真实账号、真实 PII、生产或外部资源授权。
- G2-A0 Exit 已由 Owner 于 2026-08-27 明确签署 GO，验收 ref=`140ea15d9c3f178a326709d35ad1750a156df0d1`；前一 exact-head 的独立文档治理审查 findings=`none/GO`。本次修复 closeout 新 head 仍须独立复审；远端 docs-only reconciliation 已获批但尚未执行，在复审和 exact-head Actions 条件满足前不得预写 PR、Actions run 或 merge 结果。
- G2-A1 当前仍为“未开始”。A0 Exit 只打开 A1 准备门；Supabase project/plan/region、费用、OAuth、SMTP、secret 和任何连接仍需新的 non-production resource/cost/secret 授权。

## 2. G1 Exit 前置（已满足；不替代 A0 Exit）

| 前置条件 | 当前状态 | 已有证据 | 对 G2-A0 的影响 |
|---|---|---|---|
| G1 final technical main merge / exact-head CI | 已满足 | PR #5 merge=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`；main Actions run=`33089108238` / job=`98576781415`，install/typecheck/lint/build success | 允许继续 G2-A0 Entry；不替代 A0 安全审查 |
| G1.3 technical closeout | 已满足 | Owner 验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`；G1-19/G1 Exit GO | 允许打开 A0 docs-only 入口；不授权 Auth/DB/部署 |
| G1 Exit Owner 决定 | 已满足 | Owner 原话、日期、签署和 ref 已记入 [15 台账](../15-项目状态与阶段台账.md) | Entry 通过；A0 Exit 已 GO；本次 closeout 新 head 仍待独立复审与远端 reconciliation |
| A0 文档权威输入 | 已满足 | [07](../07-完整账号系统规划.md)、[08](../08-账号系统思维导图.md)、[09](../09-A0-账号架构ADR与威胁模型.md) | 本批复用并做状态/术语一致性同步 |

## 3. Requirement-to-evidence 矩阵

状态含义固定使用：`既有合同已覆盖` 只表示 07/08/09 已有设计不变量；`A0 文档审查已完成` 仅表示 decision-ready 文档治理审查通过，不是运行时或 Auth/安全测试证据；`A0 Exit 待签署（历史快照）` 表示仍缺新的 exact-head 复审/Owner 签署；当前 A0 Exit 已 GO，但 closeout 新 head 仍待独立复审与远端 reconciliation；`A1 实测（未开始）` 与 `A3/A4 实测（未开始）` 不表示已有运行证据。

| 要求 | 当前状态 | 证据/归属 | G2-A0 Exit 后的后续验证/closeout |
|---|---|---|---|
| identity、membership、authorization、verification 四层分离；默认拒绝；职责分离 | 既有合同已覆盖 | [07](../07-完整账号系统规划.md)、[08](../08-账号系统思维导图.md)、[09](../09-A0-账号架构ADR与威胁模型.md) | closeout 新 head 独立复审；运行时验证留待 A1/A3/A4 |
| 用户删除/暂停/成员撤销后的 session、access token、refresh token 窗口；高风险实时检查 `session_id` | A0 文档审查已完成 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充历史预检2026-08-27-政策已采纳) | A1 观察窗口；A3/A4 负向证据；不以文档审查替代运行证据 |
| Data API grants 与 RLS 两层；exposed object allowlist；不以 publishable key 代替授权 | A0 文档审查已完成 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充历史预检2026-08-27-政策已采纳) | A1/A3/A4 实测；不以文档审查替代运行证据 |
| RLS `UPDATE` 先有 `SELECT`，同时具备 `USING` 与 `WITH CHECK` | A0 文档审查已完成 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充历史预检2026-08-27-政策已采纳) | A3/A4 policy 与跨租户负向 |
| 暴露 view 使用 `security_invoker`，或非暴露 schema 等价保护 | A0 文档审查已完成 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充历史预检2026-08-27-政策已采纳) | A3/A4 view/RLS 实测 |
| `SECURITY DEFINER` 最小化；固定 `search_path`、schema-qualified 引用、撤销 `PUBLIC EXECUTE`、显式角色 allowlist | A0 文档审查已完成 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充历史预检2026-08-27-政策已采纳) | A3/A4 function 权限和越权负向 |
| Storage `upsert` 同时具备 `INSERT`、`SELECT`、`UPDATE`；桶私有、对象归属可审计 | A0 文档审查已完成 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充历史预检2026-08-27-政策已采纳) | A4 Storage policy、签名 URL 与替换文件负向 |
| 不在 managed `auth`/`storage`/`realtime` schema 创建或破坏自定义对象 | A0 文档审查已完成 | [09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充历史预检2026-08-27-政策已采纳) | A1/A3/A4 实施时核验 |
| SSR 每请求新 client；Proxy 负责 cookie refresh；并发请求、过期 session 不互相串用户 | A0 文档审查已完成 | [10 A1 合同](../10-A1-Auth-Spike执行合同.md#114-a1a3a4-验证责任分配)、[11 连接记录](../11-发布与Supabase连接记录.md#6-ssr-与发布前安全边界) | A1 独立环境运行 |
| provider、plan、region、session lifetime、single-session、refresh delay 矩阵 | A1 实测（未开始） | [10 A1 合同](../10-A1-Auth-Spike执行合同.md) | A1 按已采纳的 Supabase 优先、Clerk/Auth0 仅比较范围执行；plan/region/session 依 EU non-production 实测记录，最终 provider 仍由证据与 Owner 决策 |
| phone/SMS MFA 边界 | A0 文档审查已完成；Owner 已采纳 V1 排除 | 本清单第 5 节；[09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充历史预检2026-08-27-政策已采纳) | A1 按已采纳范围不测试该路径；运行验证尚未开始 |
| publishable key 非授权边界；service role 只在受信服务端 | A0 文档审查已完成 | [09](../09-A0-账号架构ADR与威胁模型.md)、[11 连接记录](../11-发布与Supabase连接记录.md#3-环境变量密钥与授权边界) | A1/A3/A4 bundle、grants/RLS 和服务端检查 |
| 静态恢复码边界 | A0 文档审查已完成；Owner 已采纳排除静态恢复码 | 本清单第 5 节；[09 Entry 补充](../09-A0-账号架构ADR与威胁模型.md#31-2026-08-26-entry-preflight-安全补充历史预检2026-08-27-政策已采纳) | A1 验证备用 TOTP（不同设备/安全位置）、受审计人工恢复与供应商能力 |
| 完整业务 RLS、Storage、view/function、申请三元组、原子审批与跨租户负向 | A3/A4 实测（未开始） | [07 A3/A4 合同](../07-完整账号系统规划.md#15-分阶段路线-a0a6) | 不以 A0 文档或 A1 基础测试代替 |
| Apple/Google/邮箱 OTP、linking、MFA、signOut 和 token 窗口 | A1 实测（未开始） | [10 A1 合同](../10-A1-Auth-Spike执行合同.md)、[11 连接记录](../11-发布与Supabase连接记录.md) | 不在 A0 写成已实现 |

## 4. G2-A0 Exit 审查清单

以下清单区分“已完成的 Entry/文档整理与 Exit GO”和“仍待完成的 closeout”。

### 4.1 已完成或已满足

- [x] G1-19/G1 Exit GO、日期和验收 ref 已归档。
- [x] 复用 07/08/09 权威内容，不重复创建 ADR/PRD/完整权限矩阵/威胁模型。
- [x] 形成 A0-01～A0-15 及日期化 Entry 补充的统一引用。
- [x] 形成覆盖账号枚举、撞库、接管、会话、CSRF/XSS、权限提升、跨租户、邀请滥用和停用/删除残余访问的威胁矩阵。
- [x] 保留 Auth/DB/Storage/Realtime、secret/env、真实账号/PII、部署和远端写入禁止边界。
- [x] 已明确分离未来独立资源授权 Gate 与 A0 Exit；A0 Exit 只打开 G2-A1 准备门，本次未授权项目/资源、费用、secret、OAuth、SMTP 或任何连接。

### 4.2 已完成的文档审查与 Owner 政策决定；Exit GO，远端 reconciliation 已获批但尚未执行

- [x] 独立安全审查人已对前一 exact-head `140ea15d9c3f178a326709d35ad1750a156df0d1` 逐项复核 07/08/09、03 高层角色摘要、10 A1 资源边界和本清单威胁矩阵；findings `none/GO`（decision-ready baseline `9b11f375080db68353dd6952774bcd5e75c4153c` 为此前历史复核）。
- [x] 独立审查人已确认 grants/RLS/exposed allowlist、UPDATE 三条件、view/function 权限、Storage 规则和默认拒绝边界的文档一致性；这是文档治理审查，不是运行时或 Auth/安全测试证据。
- [x] (a) Owner 于 2026-08-27 采纳 V1 排除 phone/SMS MFA。
- [x] (b) Owner 于 2026-08-27 采纳排除静态恢复码，改用不同设备/安全位置备用 TOTP 与受审计人工恢复。
- [x] (c) Owner 于 2026-08-27 采纳 AAL2 强制角色范围与时点：平台 owner/admin/reviewer 上线前，商家 owner/admin 最迟 Beta 前，普通买家按风险提升，高风险动作重新认证。
- [x] (d) Owner 于 2026-08-27 采纳六类高风险动作双人复核，禁止自审：MFA 人工恢复、owner 转移、角色/权限策略变更、敏感导出、隐私删除/导出、证明文件高风险访问；第二责任人由对应阶段细化。
- [x] (e) Owner 于 2026-08-27 采纳 A1 spike 优先验证 Supabase，Clerk/Auth0 仅比较；A0 不锁最终 provider。
- [x] (f) Owner 于 2026-08-27 采纳 plan/region/session 留待 A1 按 EU non-production 实测决定；不预承诺具体 plan、session lifetime、single-session 或 refresh delay。
- [x] (g) Owner 于 2026-08-27 确认 GDPR/税务留存、删除、legal hold、跨境和处理者合同转交 A5 与专业顾问；本项不构成最终法律意见。
- [x] Owner 已以验收 ref=`140ea15d9c3f178a326709d35ad1750a156df0d1` 明确签署 G2-A0 Exit GO（2026-08-27）；仅将 G2-A1 保持“未开始/关闭”，不直接开始 Auth 实测。
- [ ] 本次本地 closeout 新 head 完成独立复审，并在 exact-head Actions 成功后按条件执行远端 docs-only reconciliation；不得预写 PR、run 或 merge。

## 5. Owner 决策矩阵

以下七项与[G2-A0 阶段记录](./G2-A0-账号安全合同与威胁模型验收.md)第 8 节逐项一致，均已由 Owner 于 2026-08-27 采纳；G2-A0 Exit 已签署 GO，但不授予资源、运行时或外部环境权限。

| 决策项 | 建议/候选 | 当前决定 | 后续约束 |
|---|---|---|---|
| (a) phone/SMS MFA | V1 排除 phone/SMS MFA | Owner 已采纳（2026-08-27） | A1 按范围不测试该路径；运行验证尚未开始 |
| (b) 静态恢复码与备用 TOTP/人工恢复 | 排除静态恢复码；备用 TOTP 必须位于不同设备/安全位置，并以受审计人工恢复为后备 | Owner 已采纳（2026-08-27） | A1 验证因子语义、恢复、AAL/会话重置、通知与审计；不得把供应商能力当作政策 |
| (c) AAL2 强制角色范围与时点 | 平台 owner/admin/reviewer 上线前强制；商家 owner/admin 最迟 Beta 前强制；普通买家按风险提升；高风险动作重新认证 | Owner 已采纳（2026-08-27） | 影响 A1 测试矩阵、业务高风险动作和 P2/P6 入口 |
| (d) 高风险动作双人复核与第二责任人 | 六类动作禁止自审并实行双人复核：MFA 人工恢复、owner 转移、角色/权限策略变更、敏感导出、隐私删除/导出、证明文件高风险访问 | Owner 已采纳（2026-08-27） | 第二责任人、AAL、通知、审计、拒绝和回退证据由对应阶段细化 |
| (e) A1 spike provider 候选 | Supabase 优先验证；Clerk、Auth0 仅作比较；A0 不锁最终 provider | Owner 已采纳（2026-08-27） | A1 实测 provider 能力、限制、版本和数据/区域边界；资源 Gate 另行授权 |
| (f) A1 plan/region/session 配置与决策规则 | plan/region/session 在 EU non-production 由 A1 实测决定；A0 不锁具体 plan、session lifetime、single-session 或 refresh delay | Owner 已采纳（2026-08-27） | A1 实测并记录观察窗口；不得凭默认值承诺；资源/费用/secret/连接另行授权 |
| (g) GDPR/税务留存、删除、legal hold、跨境与处理者合同边界 | GDPR/税务问题转交 A5 与专业顾问，覆盖留存、删除、legal hold、跨境和处理者合同 | Owner 已采纳（2026-08-27） | 本项是确认/转交边界，不是最终法律意见；未授权处理真实 PII |

### 5.1 未来独立资源授权 Gate（不属于七项政策决定）

non-production project/resource、cost、secret、OAuth、SMTP 和任何连接必须另行取得独立资源授权。该 Gate 不属于上述七项政策决定，不属于 G2-A0 Exit 条件，也不会因 A0 签署而获批；当前 A0 不授权创建项目、产生费用、配置 secret 或连接任何环境。

已确定且不重复询问：支持多店铺；批发价格、起订量和阶梯价由有效批发资格、组织状态、商品规则和服务端实时判断自动决定，不提供手动切换零售/批发模式的开关；`wholesale application` 与 `wholesale qualification` 分离；identity/membership/authorization/verification 分层；浏览器不得持 service role。

## 6. Owner 决定栏

| 决定 | 当前值 |
|---|---|
| G1 Exit | GO；2026-08-27；ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160` |
| G2-A0 Entry | 已授权；2026-08-27；仅 docs-only 候选 |
| G2-A0 当前状态 | 执行中（Exit GO；远端 docs-only reconciliation 已获批、尚未执行） |
| G2-A0 Exit | GO；2026-08-27；验收 ref=`140ea15d9c3f178a326709d35ad1750a156df0d1`；修复 closeout 新 head 待独立复审 |
| G2-A1 | 未开始 / 关闭 |
| 独立安全审查 | 前一 exact-head `140ea15d9c3f178a326709d35ad1750a156df0d1` 文档治理审查 findings `none/GO`；修复 closeout 新 head 待复审（非运行时测试） |
| Owner 原话 | `确认 G1.3 technical closeout 通过；验收 ref=d51f1c7cb47e2fe2932b29bd39420f5d092a8160；签署 G1-19，G1 Exit GO，日期 2026-08-27，并授权打开 G2-A0。` |
| Owner 七项政策原话 | `G2-A0 七项政策全部采用推荐方案：排除 phone/SMS MFA；排除静态恢复码并采用异地备用 TOTP＋受审计人工恢复；高权限角色按推荐时点强制 AAL2；六类高风险操作实行双人复核；A1 优先验证 Supabase、Clerk/Auth0 仅比较；plan/region/session 留待 A1 按 EU 非生产环境实测决定；GDPR及税务法律问题转交 A5 和专业顾问。授权写入最终文档；G2-A1 的资源、费用、secret、Auth、DB、Storage、OAuth、SMTP、部署和 Production Gate 继续关闭。`（2026-08-27） |
| 签署人 / 日期 | Hexiang Huang / 2026-08-27（G1-19、七项政策、G2-A0 Exit GO） |

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

## 8. 2026-08-27 G2-A0 Exit closeout 与远端 reconciliation 边界

- Owner 最新原话（逐字）：`不在需要我批准  你自己决定 我都同意`。该原话承接紧前已明确的完整授权文本，表示在既定、可回退的 G2-A0 docs-only reconciliation 范围内不再重复请求批准；不扩大为未来付费资源、真实 PII、Auth/DB 或 Production 的永久豁免。
- Owner 已确认：验收 ref=`140ea15d9c3f178a326709d35ad1750a156df0d1`，G2-A0 Exit GO，日期 `2026-08-27`。授权公开本阶段 12 个 Markdown、相关 Git 历史、Owner 姓名、账号安全架构、威胁模型、角色权限和阶段治理信息到公开仓库 `kyox215/REBUY_SHARE`；允许非强制 branch push、创建 PR、运行 `prototype-quality` Actions；仅当差异为批准 docs-only 内容、exact-head Actions 成功且独立复审通过，才允许 merge commit 合并 `main`。
- 公开外发 preflight（140ea 历史）：12 个 Markdown、`351437` bytes；无 binary/image/secret/phone/address/customer PII，且新增内容审计未发现新增邮箱但漏计继承内容。base/public main 及既有 Git author metadata 已含同一 Owner 邮箱，G2-A0 未引入不同邮箱；当前 G2-A0 12 路径候选中 docs/15 的 Owner 邮箱正文已脱敏；未改动的既有历史/evidence 文档及 Git author 历史可能仍含同一邮箱；不可声称 Git 历史无 email。Owner 此前明确授权公开仓库 Git 历史且最新消息同意当前闭环；此前 push 审批被拒，远端写入为零；本次文档不保存敏感值。提交后由外部复审重新计算最终字节数，本提交不自引用最终字节数。
- 当前状态：`G2-A0 Exit GO；远端 docs-only reconciliation 已获批、尚未执行`。本次修复 closeout head 尚待独立复审；不得预写目标 PR、Actions run/job、merge commit 或远端分支结论。
- 保持关闭：G2-A1、P2+、resource/cost/secret、Supabase/Auth/DB/Storage/OAuth/SMTP、真实账号/真实 PII、Preview/Production deploy、promote、alias、rollback 和生产写入。A0 Exit 至多打开 A1 准备门，资源 Gate 仍独立。
