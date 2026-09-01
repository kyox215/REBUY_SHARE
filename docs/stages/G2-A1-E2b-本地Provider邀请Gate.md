# G2-A1 E2b 本地 Provider 邀请 Gate

文档状态：**CLOSED / 待 exact action-time Owner 批准**
记录日期：2026-08-30（Europe/Rome）
适用分支：`codex/rebuy-v1-local-complete`；本文件只准备 Gate，不打开执行授权。

## 1. 目的与边界

E2b 只准备本地 Supabase Auth/GoTrue provider invitation primitive 的一次性验证门。`inviteUserByEmail` 属于 admin API，需要受信任的 local secret/admin key；本批当前未获授权读取、加载、使用或保存任何 secret、service_role、admin key 或 DB password。E2a 的 local email OTP REVIEW GO 不会打开 E2b，E2b 也不等于 Rebuy membership invite。

当前必须保持以下边界：

- 不在浏览器、`NEXT_PUBLIC_*` 环境变量、客户端 bundle、公开 Route Handler 或日志中放置或调用 admin 方法。
- 不创建通用 admin client；若未来获批，只能由一次性、server-only、最小作用域的 local harness 在进程内注入受信任配置，且不得把原值写入仓库、Git ignored 以外的持久文件、日志、截图、测试报告或 evidence。
- 不把 provider invite 暗示成组织、员工、membership、role、store scope 或权限授予；Rebuy membership invite 必须由后续 P2-L 的 RLS 保护 invitation record 与接受事务实现。
- 成功路径只允许获批后的 local GoTrue、固定 loopback、Mailpit 和 `@rebuy.test` synthetic-only；不使用 hosted Supabase/Auth、真实邮箱、真实账号、真实 PII、custom SMTP 或外部 provider。

## 2. 当前状态与允许范围

| 项目 | 当前状态 |
|---|---|
| E2b Gate | **CLOSED / 待 exact action-time Owner 批准** |
| 当前动作 | 只允许文档、审批字段、测试矩阵、STOP/回退设计；不执行 invite、不读取 admin key |
| 目标环境 | 仅获批的本地 Supabase/GoTrue、固定 loopback、Mailpit；候选端口范围 `55320–55329` |
| 成功邮箱 | 专用 `@rebuy.test` synthetic-only；`.invalid` 只可用于 no-send/负向/反枚举 |
| 证明范围 | 仅证明 provider invite primitive 的受限本地行为，不证明 Rebuy membership invite |
| 依赖关系 | E2a 当前 REVIEW GO；E3 Google、E4 Apple、E5 hosted 与完整 G2-A1 继续冻结 |

## 3. Exact action-time Owner 字段

Owner 批准前以下字段必须逐项明确；空值、历史记录或“默认批准”均无效：

| 字段 | 必须记录的内容 |
|---|---|
| Owner 决定 | 明确的批准/拒绝、Owner 身份、Europe/Rome 时间、过期时间和停止权限；当前为未批准 |
| 精确代码范围 | branch、exact HEAD、唯一 worktree、一次性 harness 路径；不得把其他 worktree 或根 checkout 作为运行目录 |
| local project | exact local project id、固定 loopback network、`55320–55329` 端口映射、仅允许的服务集合；不得枚举或复用其他项目 |
| secret custody | 仅记录 secret 名称/来源/生命周期和最小注入方式，不记录或回显原值；明确不进入 `NEXT_PUBLIC_*`、浏览器、仓库、日志或 evidence |
| provider 调用 | 明确仅一次 `inviteUserByEmail`，调用方为 server-only harness；禁止公开 route、通用 admin client 和客户端调用 |
| 邮件捕获 | Mailpit endpoint、预期单封捕获、脱敏检索规则和不保存原始邮件正文/地址的方式 |
| synthetic 数据 | `@rebuy.test` 地址生成规则、唯一性、生命周期和销毁责任；不使用真实邮箱或真实 PII |
| 观察与审查 | provider 返回状态的有限映射、独立审查人、脱敏 evidence 路径；不记录 raw provider error 或 admin response |
| cleanup | exact project id 的 user/data/containers/volumes/network/listeners 清理负责人、命令前置 help、完成判据和失败联系人 |
| 回退 | 任一 STOP 后的冻结、cleanup、证据标记和恢复 CLOSED 方式；禁止用 fake replay 补齐缺失证据 |

## 4. 获批后的最小 local harness

只有在上节所有字段获 Owner 明确批准后，才可执行一次性 harness；本文件不构成该批准：

1. 仅在目标 worktree 读取 gitignored 的 local server-only 配置，不打印、持久化或上传任何 secret/admin key；harness 默认不输出邮箱原值、邀请 token、cookie 或 provider 原文。
2. 先确认固定 loopback 与 exact project 资源，再调用一次 local `inviteUserByEmail`；邮件只进入 local Mailpit，成功路径只使用 `@rebuy.test` synthetic-only。
3. 只验证 provider primitive 的有限结果、单封捕获、脱敏状态和一次性/重复边界；不得创建 membership、organization membership、role、store scope 或业务邀请记录。
4. 使用独立的受限负向输入验证有限错误与 no-send/反枚举边界；不得把 raw provider error 透传到 HTTP、UI、日志或 evidence。
5. 完成 exact project 的 local user/data/containers/volumes/network/listeners cleanup，并记录无敏感值的结果；任何一步不确定即停止并保持 CLOSED。

## 5. 最小测试与通过判据

- 静态边界：确认 admin API 仅存在于 server-only harness 设计，未出现在 `NEXT_PUBLIC_*`、browser client、客户端 bundle、公开 route、通用 admin client 或 tracked evidence。
- 调用边界：合成成功用例最多一次 `inviteUserByEmail`；invalid/no-send 用例不绕过服务端信任边界，不用 fake provider response 代替真实 local primitive。
- 捕获边界：Mailpit 只捕获目标 synthetic 邮件；报告只写有限 stage/status，禁止邮箱、邀请 token、cookie、key 和 raw provider text。
- 业务边界：provider invite 不能直接产生 Rebuy organization、membership、employee role、store scope 或业务权限；缺失这些结果不是失败，而是本 Gate 的明确非目标。
- cleanup 边界：仅核对本批 exact project 的资源与 `55320–55329` listeners 为空；不得读取、修改或终止其他项目资源。
- 证据判定：只有全部前置、调用、捕获、负向、cleanup 和独立复核通过，才可记录“provider primitive local evidence”；不得写成 E2b 通过、P2-L 通过、G2-A1 通过或 membership invite 通过。

## 6. STOP 条件

出现任一项立即停止，不猜字段、不改用伪凭据、不用 fake replay 补证据：

- 任何 secret、service_role、admin key、DB password、invite token、cookie、真实邮箱/账号/PII 或 raw provider error 出现在输出、日志、截图、仓库、bundle、数据库或 evidence。
- 需要 `NEXT_PUBLIC_*`、浏览器 admin 调用、公开 route、通用 admin client、custom SMTP、hosted login/link、外部网络或非固定 loopback。
- 目标 project、容器、volume、network、端口、监听器或 Mailpit 无法精确归属本批，或需要触碰其他项目、`54321–54324` 或既有运行状态。
- provider 行为诱发或要求创建 membership/组织权限，或测试人员无法证明邀请仅为 provider primitive。
- 真实邮件投递、非 `@rebuy.test` 成功地址、费用、镜像下载、未获批权限、无法 cleanup、泄露风险或工具输出无法可靠脱敏。

## 7. 回退与关闭

回退只允许冻结 E2b、清理本批获批的 local user/data/containers/volumes/network/listeners 和临时 server-only 配置，并追加无敏感值的 STOP/cleanup 记录。不得 reset/force、不得修改 E2a 代码或历史证据、不得回退到客户端 admin 调用、假 provider 响应或 hosted 资源。若 harness 未完整证明 primitive，结果写为未完成/NO-GO，E2b 继续 CLOSED，重新执行必须重新走 exact action-time Owner Gate。

## 8. 明确非目标

Provider/admin invite、`inviteUserByEmail`、Rebuy membership invite、组织/员工权限、Google、Apple、hosted Auth、custom SMTP、真实邮件/账号/PII、业务 DB/schema/RLS、Storage、Realtime、MFA、linking、push、PR、merge、Vercel、Staging、Production 和任何外部写入均不因本 Gate 文档而打开。
