# 多商家批发与零售购物平台 V1 规划文档

文档状态：规划文档导航入口；当前状态以 15 为唯一来源  
当前范围：本 README 只作导航；阶段状态和授权以[项目状态与阶段台账](./15-项目状态与阶段台账.md)为唯一来源，本地设计/原型证据不代表生产系统实现
维护原则：本目录只保存规划、设计基线、架构合同和验证门槛，不保存生产凭据、真实业务数据或外部服务连接。

## 1. 先读什么

按 00 → 15 的顺序阅读。00 说明产品范围，01/02 约束买家客户端视觉和页面行为，03/04 说明平台角色与技术边界，05 规定实施阶段和验证门，06 是当前本地视觉原型执行合同，07/08 是账号规划与结构图，09 是 A0 ADR/威胁模型，10 是 A1 Auth spike 执行合同，11 记录独立测试连接骨架与发布边界，12 固化买家端与未来商家后台共享 UI 系统，13 固化页面、响应式和组件映射，14 固化全局执行路线，15 是唯一当前状态源；阶段事实记录见 `stages/`，模板见 `templates/`。

本目录不是生产系统，也不是已经部署的网站。任何本地预览、静态截图、虚构数据或浏览器检查都只能证明相应的本地视觉/交互状态，不能等同于数据库、RLS、隐私、支付、部署、生产数据或业务验收。

## 2. 文档目录

| 顺序 | 文档 | 状态 | 用途 | Owner 审批关系 | 当前下一步 |
|---:|---|---|---|---|---|
| 00 | [项目总览与 V1 范围](./00-项目总览与V1范围.md) | 已批准范围的整合基线 | 定义产品定位、V1 包含/不包含、成功指标、风险和待定决策 | Owner 对范围和后续变更负责；新决定优先于历史窄 B2B 方案 | 作为所有设计、架构和实现任务的范围入口 |
| 01 | [客户端苹果风格设计规范](./01-客户端苹果风格设计规范.md) | Owner 已批准设计基线（2026-08-25；视觉原型历史入口） | 定义买家客户端的视觉 token、信息层级、导航、状态、响应式和无障碍基线 | 设计基线约束 P1 本地视觉原型；视觉原型确认后才进入真实产品/后端实现；本文件不覆盖商家后台 | 作为设计基线；当前 Gate 以[15 台账](./15-项目状态与阶段台账.md)为准 |
| 02 | [客户端 V1 页面线框图](./02-客户端V1页面线框图.md) | Owner 已批准低保真基线（2026-08-25；视觉原型历史入口） | 定义买家页面、购买流程、线框、边界状态、可用性任务和通过标准 | 设计基线约束 P1 本地视觉原型；视觉原型确认后才进入真实产品/后端实现；本文件不等同于生产实现 | 作为页面基线；当前 Gate 以[15 台账](./15-项目状态与阶段台账.md)为准 |
| 03 | [平台角色与业务模块](./03-平台角色与业务模块.md) | 规划执行稿；G2-A0 高层角色摘要 | 定义平台、商家和客户端的高层职责、模块树、业务状态和客户资料边界 | 07/09 是账号安全与权限权威；Owner 审批角色、权限和状态变更；高风险权限后续需专项审查 | 进入 P2/P3/P4/P6 前作为模块映射合同 |
| 04 | [技术架构与核心数据模型](./04-技术架构与核心数据模型.md) | 技术规划稿，未连接环境 | 定义模块化单体、边界、数据实体、RLS、审计、幂等、存储和环境隔离 | Owner 审批架构方向；数据库、隐私、生产写入需专项审查 | 仅作为后续实现设计输入，不执行数据库连接 |
| 05 | [V1 实施路线与验证计划](./05-V1实施路线与验证计划.md) | 里程碑与验证合同 | 将工作拆成 P0–P8，并纳入 G1 工程底座、G2-A0/G2-A1 账号门，规定依赖、风险、最小验证、Owner Gate 和回退 | Owner 在每个里程碑门口决定继续、修订或暂停 | G0/P1 已通过并冻结；G1 已完成且 Exit=GO；G2-A0 Exit GO，远端 docs-only reconciliation 已完成；G2-A1 执行中，B1 最小连接及配置/能力只读预检已完成，B2 CLOSED/待独立复审和专项 Gate，完整 resource/cost/secret Gate 关闭 |
| 06 | [本地视觉原型执行合同](./06-本地视觉原型执行合同.md) | P1 原型已创建；分类目录 IA 已通过并冻结 | 限定本地无后端视觉原型的页面、数据、交互、资产、预览和验收 | Owner 已批准 P1 范围；本地证据不等于 Owner 或生产通过 | [G0 阶段记录](./stages/G0-P1-视觉验收与UI冻结.md)与[分类目录 IA 证据](./evidence/G0-P1/2026-08-25-category-directory-ia/README.md)记录本批复验；[G1.1 本地基线](./evidence/G1/2026-08-25-g1-1-local-baseline/README.md)记录 Git 基线及 Node22 可复现验证 |
| 07 | [完整账号系统规划](./07-完整账号系统规划.md) | G2-A0 账号安全合同输入；G2-A0 Exit GO，远端 docs-only reconciliation 已完成；七项 Owner 政策已采纳 | 定义 identity、组织/店铺 membership、角色权限、商家/批发申请与资格、状态机、安全、隐私、页面、API 和 A0–A6 门禁 | 作为 G2-A0 权威输入；已同步采纳政策与 A1 资源边界；生产实现需另行审查，不等同于运行时证明 | G2-A1 执行中，B1 最小连接及配置/能力只读预检已完成，B2 CLOSED/待独立复审和专项 Gate；继续保持 A1/完整 resource/cost/secret Gate 关闭 |
| 08 | [账号系统思维导图](./08-账号系统思维导图.md) | G2-A0 账号安全合同输入；G2-A0 Exit GO，远端 docs-only reconciliation 已完成；七项 Owner 政策已采纳 | 以独立 Mermaid 思维导图、流程图和状态图呈现账号角色、邮箱邀请、批发申请/资格拆分、数据、安全、隐私和阶段 | 与 07/09 保持一致；已同步采纳政策状态；图示不等同于实现或生产验收 | G2-A1 执行中，B1 最小连接及配置/能力只读预检已完成，B2 CLOSED/待独立复审和专项 Gate；继续保持 A1/完整 resource/cost/secret Gate 关闭 |
| 09 | [A0 账号架构 ADR 与威胁模型](./09-A0-账号架构ADR与威胁模型.md) | G2-A0 Exit GO；远端 docs-only reconciliation 已完成 | 固化 A0-01～A0-15、日期化 Entry 补充、数据流、资产、信任边界、STRIDE/滥用场景、风险登记、G2-A0 验收和 Owner Gate | A0 Exit 只打开 G2-A1 准备门；文档和本地原型不是安全证明；A1 资源/费用/secret 需独立授权 | 当前指向 G2-A1 B1 配置/能力预检证据；G2-A1 执行中，B2 CLOSED/待独立复审和专项 Gate |
| 10 | [A1 Auth spike 执行合同](./10-A1-Auth-Spike执行合同.md) | G2-A1 执行中；B1 最小连接及配置/能力只读预检已完成；B2 CLOSED/待独立复审和专项 Gate；完整 resource/cost/secret Gate 关闭；G2-A0 Exit GO，远端 docs-only reconciliation 已完成 | 定义 local/preview-staging Auth spike 的三入口、callback、linking、邀请邮箱验证、TOTP、会话、测试矩阵、停止条件和证据清单 | 资源存在性与 B1 预检不等于 Auth 授权；provider/secret/DB/OAuth/SMTP/连接仍受独立 Gate；绝不连接 production/真实 PII | 当前仅可维护[G2-A1 准备与资源门禁](./stages/G2-A1-Auth-Spike准备与资源门禁.md)、B2 风险 Gate 草案、接口草图、测试用例和合成 fixture 字段；不改变已冻结 G0/P1 UI |
| 11 | [发布与 Supabase 连接记录](./11-发布与Supabase连接记录.md) | 本地连接骨架与依赖检查、B1 最小连接及配置/能力只读预检已有证据；Auth spike 未实施 | 记录独立测试连接骨架、资源预检、依赖检查、健康探针和停止条件 | 不配置 Vercel env、不启用真实登录/OAuth/SMTP、不触碰 production/真实 PII；骨架/资源健康与 B1 预检不等于 Auth、DB、Staging 或生产 | 作为 G2-A1 输入，保持独立测试边界；B2 CLOSED/待独立复审和专项 Gate |
| 12 | [Rebuy 统一 UI 设计系统](./12-Rebuy统一UI设计系统.md) | Owner 已批准统一 UI 设计文档并选定配色 D，配色已同步至本地 P1 视觉原型（2026-08-25） | 固化循环翡翠青品牌 token、浅深色、两套 Shell、组件规则、动效、三语和无障碍边界 | 仅是设计合同；不授权代码、后台、数据库或生产实现 | 作为买家端原型调整和未来商家后台设计映射的共享视觉基线 |
| 13 | [买家端与商家后台页面及组件映射](./13-买家端与商家后台页面及组件映射.md) | Owner 已批准统一 UI 设计文档与配色 D；设计映射基线 | 映射买家页面、未来后台页面、PC/APP 响应关系、Prototype 组件复用、状态和验收矩阵 | 商家后台仍是未来设计映射，不是当前代码/后端授权；实现需单独 Owner Gate | 作为买家/后台映射基线；当前 Gate 以[15 台账](./15-项目状态与阶段台账.md)为准，P6 前另行进行权限/安全/后台审查 |
| 14 | [全局执行总计划](./14-全局执行总计划.md) | 稳定权威路线 | 固化 GOV-1、G0、G1 工程底座、G2-A0/G2-A1、P2–P8 依赖链、产物、验证、Owner Gate 和回退 | 任何路线变化需 Owner 决策并追加记录 | 以 15 为唯一当前状态源，不在此维护每日状态；当前 G2-A0 Exit GO、docs-only reconciliation 已完成；G2-A1 执行中，B1 最小连接及配置/能力只读预检已完成，B2 CLOSED/待独立复审和专项 Gate，完整 resource/cost/secret Gate 关闭 |
| 15 | [项目状态与阶段台账](./15-项目状态与阶段台账.md) | 唯一当前状态源（2026-08-28） | 记录阶段、状态、证据级别、依赖、Owner 决策、记录链接和下一动作 | 状态枚举与证据枚举固定；待验收不得写成已通过 | GOV-1 已通过；G0/P1 已通过并冻结；G1 已完成且 G1 Exit=GO；G2-A0 Exit GO、远端 docs-only reconciliation 已完成；G2-A1 执行中，B1 最小连接及配置/能力只读预检已完成，B2 CLOSED/待独立复审和专项 Gate，完整 resource/cost/secret Gate 关闭；以本台账为唯一当前状态 |

### 治理资料

| 资料 | 用途 |
|---|---|
| [阶段执行记录模板](./templates/阶段执行记录模板.md) | 新阶段/批次的元数据、影响、验证、回退、风险和 Owner Gate 模板 |
| [阶段记录索引](./stages/README.md) | 阶段事实记录的索引、命名、追加和证据边界 |
| [G1 Owner 验收清单](./stages/G1-Owner验收清单.md) | G1 Exit requirement-to-evidence 矩阵、NO-GO 缺口和 Owner Gate 执行顺序 |
| [G1.2b main merge closeout](./evidence/G1/2026-08-27-g1-2b-main-merge/README.md) | PR #1 merge commit、main push Actions、双历史保留、分支与回退/维护边界 |
| [G1.2b 远端 PR/CI 证据](./evidence/G1/2026-08-27-g1-2b-remote-ci/README.md) | canonical repo、PR #1、Actions run/job、远端只读设置、历史/敏感审计和边界记录 |
| [G2-A0 Owner 验收清单](./stages/G2-A0-Owner验收清单.md) | G1 Exit 通过后的 A0 安全审查入口；G2-A0 Exit GO，远端 docs-only reconciliation 已完成；后续资源 Gate 仍关闭 |
| [G2-A0 阶段记录](./stages/G2-A0-账号安全合同与威胁模型验收.md) | 记录本批 docs-only 执行、威胁矩阵、Owner 政策决定、验证、风险、回退、Exit GO 和远端 reconciliation 前置条件 |
| [G2-A0 Entry preflight 证据](./evidence/G2-A0/2026-08-26-entry-preflight/README.md) | 只读官方依据与安全控制补充；不代表 provider/project 已连接 |
| [G2-A1 准备与资源门禁](./stages/G2-A1-Auth-Spike准备与资源门禁.md) | G2-A1 执行中；B1 最小连接及配置/能力只读预检已完成；B2 CLOSED/待独立复审和专项 Gate；四批 Auth spike 合同、资源责任、停止/回退、官方来源刷新；完整 resource/cost/secret Gate 关闭 |
| [G2-A1 Entry preparation 证据](./evidence/G2-A1/2026-08-28-entry-preparation/README.md) | 记录 G2-A0 远端闭环、Vercel/Production 不变量、资源存在性/基础预检、公开边界、静态验证与本批边界 |
| [G2-A1 资源成本与密钥 Gate 模板](./templates/G2-A1-资源成本与密钥Gate模板.md) | provider/project/plan/region/environment、provider amount/recurrence、另行核对的税费与 organization-level Spend Cap、密钥责任、回退和清理字段 |
| [G2-A1 Auth 实测矩阵模板](./templates/G2-A1-Auth实测矩阵模板.md) | Apple/Google/email OTP/Magic Link、callback、linking、MFA/TOTP、session、恢复、限流、SSR 和 secret scan 字段 |

## 3. 当前权威关系

1. 本 README 负责导航；具体产品范围以 00 为准，路线以 14 为准，当前状态以 15 为准，阶段事实以 `stages/` 记录为准。
2. 买家客户端视觉和页面行为以已经批准的 01/02 为准；03/04/05/06 不会把客户端规范扩展为商家后台视觉规范；07/08/09/10 只定义账号安全与验证门禁，不改变 P1 原型的无后端边界。
3. 本轮新决定明确这是多商家批发与零售平台。过去较窄的供应商到零售商方案、旧原型或历史讨论只能作参考；若与 00 或已批准的 01/02 冲突，以当前权威决定为准。
4. 任何改变角色、权限、数据归属、价格规则、支付责任、隐私风险、外部连接、生产写入、验收标准或回退方式的新增需求，都必须形成新的 Owner 决定，不能在执行中悄悄扩大范围。

## 4. 当前下一步

**2026-08-28 当前纠正：** G2-A0 Exit GO 的远端 docs-only reconciliation 已完成（merge=`fd9b712c7b07bf34399f9838eebb75846425c1d1`）。当前 G2-A1 执行中；B1 最小连接及配置/能力只读预检已完成；B2 CLOSED，待独立复审和专项 Gate；完整 resource/cost/secret Gate 仍关闭。下一步是完成 B2 专项风险 Gate 草案的独立复审与 Owner/主代理 Gate，并维护[G2-A1 准备与资源门禁](./stages/G2-A1-Auth-Spike准备与资源门禁.md)、[B1 配置/能力预检证据](./evidence/G2-A1/2026-08-28-b1-capability-preflight/README.md)及两份模板。

历史批准（2026-08-25）：Owner 当时作出分类目录 IA 决定，原话为 `分类目录IA通过，G0重新冻结，未覆盖项进入后续专项，恢复G1授权`，并据此将 G0/P1 更新为“已通过并冻结”。当前状态为：G1 已于 2026-08-27 完成 G1-19/G1 Exit=GO，验收 ref=`d51f1c7cb47e2fe2932b29bd39420f5d092a8160`；main merge 与 exact-head Actions 证据见[G1 final closeout](./evidence/G1/2026-08-27-g1-final-closeout/README.md)。G2-A0 当前为 `Exit GO；远端 docs-only reconciliation 已完成`，验收 ref=`140ea15d9c3f178a326709d35ad1750a156df0d1`，merge=`fd9b712c7b07bf34399f9838eebb75846425c1d1`；G2-A1 执行中，B1 最小连接及配置/能力只读预检已完成；B2 CLOSED，待独立复审和专项 Gate；完整 resource/cost/secret Gate 仍关闭。当前资源事实见[G2-A1 B1 配置/能力预检证据](./evidence/G2-A1/2026-08-28-b1-capability-preflight/README.md) 和 [G2-A1 Entry preparation 证据](./evidence/G2-A1/2026-08-28-entry-preparation/README.md)。执行顺序是：

1. 按 [15 台账](./15-项目状态与阶段台账.md)和 [G0 阶段记录](./stages/G0-P1-视觉验收与UI冻结.md)保留 G0 冻结基线；未覆盖的键盘/无障碍事项进入后续专项。
2. G1 已关闭并保留其 merge、Actions、Preview/Production 不变量及回退证据；后续文档不得把 G1 历史证据扩大为 Auth、DB 或生产能力。
3. [G2-A0 阶段记录](./stages/G2-A0-账号安全合同与威胁模型验收.md)中的 docs-only closeout、独立安全审查和远端 reconciliation 已完成；A0 Exit 仅打开 G2-A1 准备门，A1 资源/费用/secret/连接仍需新授权。

## 5. 证据边界

- “文档已完成”只表示规划文档已经整理并通过文档级检查。
- “本地视觉原型已完成”只表示本地页面和交互达到 06 的门槛，并不表示认证、权限、库存、订单、售后、RLS、隐私或生产系统已经完成。
- “本地浏览器检查通过”只表示指定浏览器和视口下的可见行为通过，不能替代真实环境、迁移、备份恢复、权限隔离、监控、法律/税务和 Owner 生产批准。
- 本目录中的示例商品、商家、订单、客户和地址均应为虚构合成数据；不得把真实客户或商家资料复制进文档或原型。

## 6. 本轮明确不做

此前文档整理批次不创建产品代码、网站脚手架、数据库、Storage bucket、部署、支付账户、外部 API 连接、真实业务写入或真实数据迁移。G1 的本地/远端证据和 exact-head Actions 已按阶段记录归档；G2-A0 已完成批准范围内的 docs-only closeout、威胁模型、Owner Gate 和远端 reconciliation。本轮已完成 B1 最小连接及配置/能力只读预检；不修改 prototype 源码、package/lockfile、workflow 或环境配置；不执行 Auth/DB/Storage/Realtime 运行或配置写入，不读取 secret/env/PII。完整 resource/cost/secret、Auth、Storage、SMTP、部署和 Production 仍关闭；B2 CLOSED/待独立复审和专项 Gate；普通文档修改不做 hash；A0/A1 合同、G1 工程底座和后续高风险门槛见 [V1 实施路线与验证计划](./05-V1实施路线与验证计划.md)。

## 7. 当前发布状态

A1 独立测试连接骨架、B1 最小连接及配置/能力只读预检已有本地与管理面记录；Supabase 依赖的本地 typecheck、lint、build 与 health 证据仅属于本地静态/运行边界；G2-A1 Auth spike 尚未实施，未启用真实登录/OAuth/SMTP，也没有本工作范围内的生产或真实 PII 边界变更。G2-A0 Exit 已 GO 且远端 docs-only reconciliation 已完成；当前 B2 与完整 resource/cost/secret、Auth、DB、Storage、OAuth、SMTP 和 Production Gate 保持关闭，待独立复审与专项 Gate。

## 7.1 2026-08-28 当前纠正与 G2-A1 资源预检（无资源 Entry preparation 为历史前置）

G2-A0 远端 docs-only reconciliation 已完成：PR #7 merge=`fd9b712c7b07bf34399f9838eebb75846425c1d1`，main Actions run=`33122238997` / job=`98691703085` 全绿，merge SHA 的 GitHub deployments=`0`，来源分支保留。G2-A1 执行中；B1 最小连接及配置/能力只读预检已完成；B2 CLOSED/待独立复审和专项 Gate；完整 resource/cost/secret Gate 仍关闭。当前仅允许脱敏能力事实、文档、B2 风险 Gate 草案、模板、接口草图、测试矩阵和 `.invalid` 负向/反枚举字段，禁止 secret/env/PII、Auth/DB/Storage/OAuth/SMTP 配置或成功投递、真实数据、部署或 Production。详见[G2-A1 准备与资源门禁](./stages/G2-A1-Auth-Spike准备与资源门禁.md)、[B1 配置/能力预检证据](./evidence/G2-A1/2026-08-28-b1-capability-preflight/README.md)与[Entry preparation 证据](./evidence/G2-A1/2026-08-28-entry-preparation/README.md)。

## 8. 2026-08-27 G2-A0 Exit closeout 历史快照

在该日期的历史快照中，状态为 `G2-A0 Exit GO；远端 docs-only reconciliation 已获批，尚未执行`。公开外发范围限于原 12 个 Markdown 路径、相关 Git 历史、Owner 姓名、账号安全架构、威胁模型、角色权限和阶段治理信息；远端 preflight 为 `main=7ea1e45ad22ab29105910665baf4bbd7212241c5`、目标 branch/PR 无。140ea 历史 preflight 审计为 `351437` bytes，无 binary/image/secret/phone/address/customer PII；新增内容审计未发现新增邮箱但漏计继承内容，base/public main 及既有 Git author metadata 已含同一 Owner 邮箱，G2-A0 未引入不同邮箱。该段仅保留当时事实，不代表当前状态；当前事实见上方 2026-08-28 纠正。
