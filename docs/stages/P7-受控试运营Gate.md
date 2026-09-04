# P7 受控试运营 Gate

文档状态：**执行中 / Entry 已打开**  
记录日期：2026-09-04（Europe/Rome）  
适用分支：`codex/rebuy-v1-local-complete`

## 1. 范围合同

### 范围

- 把已通过 P2–P6 的 V1 从 local-only 迁移到一个明确、隔离的 hosted Supabase 项目和一个明确的 Vercel Production 项目。
- 支持 HTTPS 下真实注册/登录、买家浏览/购物车/提交订单/查单、审核后的批发自动定价、商家入驻/商品/库存/子订单/售后，以及平台审核和关键操作追溯。
- 使用最小生产配置：精确站点 origin/callback allowlist、secure session cookie、最小 publishable client config、server-only 敏感配置、RLS/ACL、迁移历史与发布绑定。
- 建立受控试运营边界：明确测试/试运营身份、最小 PII、监控与告警、客服/异常处理、数据库备份与应用回滚步骤；先用合成或 Owner 控制身份验证，再决定是否开放更广注册。
- 修复 P6 `P3-A01` audit 查询限流顺序，并用性能/观测证据确认不会阻塞受控流量。
- 将审核通过的发布候选以非 force 方式合并/推送至 `main`，完成 Vercel Production 部署、生产冒烟与回滚可用性核验。

### 非目标

- 不实现在线支付、分账、退款执行、真实物流承运、税务/发票、Google/Apple OAuth、Storage 附件、ERP/微信同步或 P8 能力。
- 不采集证件、银行卡、聊天自由文本、真实客户批量数据或未经 Owner 明确指定的商家资料。
- 不删除历史 deployment、数据库事件、订单、库存或审计记录；不 force push、不重写远端历史。
- 不把本地 synthetic 证据当作 hosted/Production 证据，也不以 Preview 200 代替完整业务验证。

### 验收条件

- hosted 配置与代码：local/hosted runtime 明确分离；HTTPS origin、callback、cookie、CSP/安全 header、错误脱敏和 secret 边界成立。
- 数据库：五个 migration 以顺序、可审计方式应用；迁移前恢复点/备份状态已确认；hosted migration list 对齐；security/performance advisors 无当前范围 P0/P1；RLS/ACL/跨租户负向通过。
- Auth：受控身份可完成注册、邮件验证/登录、session、退出与未授权页；无账号枚举、open redirect、raw provider error 或不安全 cookie。
- 业务：至少一条买家与一条商家/平台核心路径在 Production HTTPS 上通过；库存/订单/履约/售后写入可追溯，测试数据可明确识别并按保留策略处理。
- 发布：Node/pnpm 与 CI/runtime 固定；发布候选 typecheck、ESLint、production build、核心 E2E 通过；`main` 精确提交、远端 CI、Production deployment/alias 可绑定；上一 READY deployment 可作为应用回滚点。
- 运维：健康检查、函数/应用错误、数据库可用性、Auth 失败和关键业务异常有可执行观察入口；客服/暂停写入/回滚责任与步骤写入证据。
- 独立复核：认证/权限/数据库/隐私/部署做一次最终专项审查，P0/P1/P2 阻塞项为 0。

### 可阻塞条件

- P0：凭据/PII 泄露、跨租户或越权生产写入、生产不可用、不可逆数据损坏。立即停止相关入口并汇报。
- P1：当前验收路径不可用、错误库存/订单写入、迁移不一致、Auth/callback/session 安全边界失败、无可用回滚点。暂停发布或写入，完成一次定向修复/复验。
- provider 目标无法唯一确认、将产生未经确认的费用、需要读取/提交未授权 secret、备份/恢复状态不可确认，或生产配置与候选提交无法绑定。
- P2/P3 体验、重构和历史技术债只登记；除非证实影响当前验收，不扩大范围或重复全量验证。

### 验证清单

- 目标/费用/region/项目绑定只读 preflight；备份、PITR/恢复能力与当前 migration 状态。
- hosted runtime 配置契约、Auth 安全测试、RLS/ACL/DTO/跨租户负向、migration dry/remote apply 证据。
- Node 22、pnpm lock、Auth/structure、typecheck、ESLint、production build、一次最终核心 E2E。
- Production HTTPS：注册/登录/退出、买家下单查单、商家履约售后、平台审核、审计追踪、响应式和 console/network 错误。
- Vercel deployment/alias、Git `main`、CI SHA 三方绑定；健康/日志观察；应用回滚验证和数据库前向恢复说明。
- 脱敏 commands/results/manifests、exact cleanup、独立 final review。

## 2. 发布与数据安全决定

- hosted Supabase 与 Vercel 必须通过只读发现唯一解析，不能凭历史名称猜测 target；若需新建付费资源，必须使用 provider 返回的成本确认流程。
- 浏览器只接收 publishable 配置；数据库密码、service role、secret key、SMTP/API token 不进入客户端、Git、证据或聊天输出。
- 初始 Production 采用受控身份与最小数据；是否开放任意公网邮箱注册，以 hosted 邮件交付能力、滥用防护和最终 Auth 复核为准。
- 数据库 schema 以 migration 为唯一来源；禁止通过 Dashboard 手工复制 SQL 造成漂移。生产 mutation 必须保留 idempotency、expected version、RLS/ACL 与审计事件。
- 应用回滚只能回到已知 READY 且 schema-compatible 的 deployment；数据库默认前向修复，不执行破坏性 down migration。

## 3. 当前执行顺序

1. 关闭 P6 文档与冻结 P7 范围；只读发现 Supabase/Vercel/GitHub 当前目标和费用/备份能力。
2. 实现 hosted runtime、secure Auth/callback/cookie、环境合同与 audit 限流修复；完成定向安全测试。
3. 生成发布候选并进行一次本地最终验证；建立 hosted migration/backup/rollback 证据后应用迁移。
4. 推送候选、合并/更新 `main`，等待精确 SHA CI 成功；部署 Production 并绑定 alias。
5. 运行 Production HTTPS 受控核心 E2E、监控/日志与回滚核验；独立最终复核后关闭 P7。

## 4. 停止与回退

- Auth 或跨租户边界失败：关闭对应入口，撤销/轮换暴露配置，保留脱敏审计并回到上一安全部署。
- 应用发布失败：不改变数据库数据，恢复上一 schema-compatible READY deployment/alias；失败候选保留供诊断。
- 数据库迁移失败：立即停止应用写入；使用事务回滚或前向修复，按 provider 可用恢复点处理，不删除订单/库存/事件。
- 生产验证失败：不把阶段标为已通过；暂停新注册/下单/商家 mutation 中受影响部分，保留只读与审计，报告精确影响和恢复条件。

## 5. 2026-09-04｜hosted-runtime 本地候选

- 源码候选 `856d5ee60d0540cefe47bf947e41a80c78c6b8a4` 已实现 hosted Auth/runtime、secure cookie、受控邮箱、精确 Vercel origin、安全 header、`fra1` region 与 audit 关系限流。
- Node 22 Auth `50/50`、全部 structure、typecheck、全量 ESLint、Next build 通过；fresh reset 后 pgTAP 最终 `503/503`，strict lint/security/performance advisors 与 migration list 通过，exact cleanup 完成。
- 首轮 policy 组合方式触发 P4 单一 permissive policy 门；已定向合并到原 policy 并在唯一复验关闭。库存/订单 mutation 未变化，P6 concurrency 证据复用。
- 当前仅为 local candidate。Vercel target 已唯一解析为既有 `rebuy-share` Pro 项目，当前 Production 为 READY/ui-only 且有 rollback candidate；Supabase 当前无 Rebuy 项目，外部创建仍等组织与费用确认。证据见 [hosted-runtime candidate](../evidence/P7/2026-09-04-hosted-runtime-candidate/README.md)。

## 6. 2026-09-04｜发布配置与 main 同步预检

- Vercel `rebuy-share` 的 Node 运行时已校准并回读为 `22.x`；Production env 仍为空、线上仍为 `ui-only`，尚未部署 hosted-auth。
- `origin/main` 的 UI-only Production docs-only closeout 已通过 merge commit `8918735` 合入；当前分支零落后，业务源码候选及其已通过验证未变化。
- GitHub CLI 当前凭据无效；push/PR/CI 尚未执行。Supabase 创建仍等待唯一组织的明确确认与 provider 成本确认，首轮真实 Auth 还需要 Owner 指定受控邮箱。

## 7. 2026-09-04｜零新增付费约束

- Owner 明确要求不使用付费。当前 Supabase 唯一组织实时为 `plan=pro`，同一组织不能混用 Free 与 Pro；在该组织创建第三个项目会新增 compute 成本。零新增付费候选必须另建独立 Free 组织，再核验 $0 project cost；现有两个非 Rebuy 项目不占用此方案的写入范围，也不得被暂停、迁移或复用。
- 不暂停、迁移、复用或修改两个现有项目；不创建付费 project/branch/add-on。免费默认 SMTP 仅适合 team-member 受控验证，Free Plan 又缺少可下载托管备份并可能因七天低活跃暂停，均已登记为生产能力边界。
- Vercel 当前项目位于既有 Pro 团队；Hobby 限个人非商业用途，不作为 Rebuy 交易试运营替代。新 Free Supabase 组织获确认前，P7 hosted database/真实 Auth/业务 Production 验收保持阻塞；local V1 证据与远端候选分支保留。
