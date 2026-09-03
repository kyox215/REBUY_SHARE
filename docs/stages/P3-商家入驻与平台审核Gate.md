# P3 商家入驻与平台审核 Gate

文档状态：**执行中 / synthetic-only local bounded Gate 已打开**
记录日期：2026-09-03（Europe/Rome）
适用分支：`codex/rebuy-v1-local-complete`

## 1. 目标与边界

本阶段只建立“申请人提交商家申请 → 平台分配审核人 → 审核人处理 → 批准后原子建立商家组织、私有店铺和 owner membership”的本地纵切。P2-L 已独立 REVIEW GO；Owner 的 `批准全部` 与随后 `批准` 已绑定本清单的顺序执行授权。

本阶段只使用 `@rebuy.test` 合成身份和 `synthetic://` 资料引用，不上传或保留真实证件、地址、税号、银行资料、电话、自由文本审核备注或其他 PII。不开启 Supabase Storage、hosted Supabase、Preview、Production 或外部通知。生产仍需 AAL2、真实隐私/保留期、法务资料、Storage 隔离和人工责任人专项 Gate。

## 2. 最小数据合同

- `merchant_applications`：申请人、展示名、国家、店铺 slug、状态、当前分配、幂等键，以及获批后组织/店铺引用。
- `merchant_application_private`：合成登记引用和合成资料引用；只能由申请人本人或当前分配且仍有效的审核人通过受控入口读取。
- `merchant_application_events`：append-only 状态/分配/决定事件；只保存有限事件码、原因码、actor 和对象引用，不保存资料正文。
- 状态枚举：`draft`、`submitted`、`under_review`、`needs_info`、`approved`、`rejected`、`suspended`、`withdrawn`。
- 本阶段允许迁移：`draft → submitted`、`needs_info → submitted`、`submitted → under_review`、`under_review → needs_info|approved|rejected`、`approved → suspended`、`draft|submitted|needs_info → withdrawn`；其他迁移 fail closed。
- 同一申请人最多一个非终态申请；写入和审核都使用 UUID 幂等键，重复请求返回同一业务结果且不重复事件或组织对象。

## 3. 身份与权限合同

- 公开 RPC 均为 `SECURITY INVOKER` wrapper；真实实现位于未 exposed 的 `private` schema，`SECURITY DEFINER`、空 `search_path`、对象全限定。为保持 invoker wrapper 可组合性，`authenticated` 仅获得这七个 implementation 的直接 `EXECUTE`；每个 implementation 都必须自行执行与 wrapper 完全相同的身份、OTP、membership、permission、状态和幂等重验证。`anon` 与 `service_role` 不得获得执行权。
- 新建 `rebuy_business_executor`，固定为 `NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS`。它不拥有 schema/table，只拥有触达列的最小权限，并继续受 `ENABLE + FORCE RLS` 约束。
- PostgreSQL 17/Supabase local bootstrap 仅允许与 P2-L 相同的一条系统创建关系：授予角色为 executor、member=`postgres`、grantor=`supabase_admin`、`ADMIN=true/INHERIT=false/SET=false`。函数 owner handoff 的临时 `SET` 和 schema `CREATE` 必须在同一事务块撤销并复验。
- 申请入口重新验证签名 JWT：`auth.uid()` 非空、非匿名、规范化 `@rebuy.test` email，最前 `amr[0]` 为 10 分钟内 OTP，未来偏差最多 60 秒。本地 AAL1 例外不外推生产。
- 平台分配者必须是 active platform membership 且拥有 `merchant_application.assign`；审核者必须是当前 assigned active platform membership，拥有 `merchant_application.read_assigned` 与 `merchant_application.review`，且不得审核自己的申请。
- support 角色不在本阶段；没有对应 permission 的成员看不到私有资料、不能分配或作出决定。页面可见性、客户端 role、客户端状态和请求 payload 都不是授权依据。

## 4. 审核与批准事务

1. 申请人保存 draft 或提交，服务端规范化字段并验证 `synthetic://` 引用。
2. 平台管理员只能给 active、非申请人的 reviewer membership 分配 `submitted` 案件。
3. 被分配审核人才能开始审核、补件、批准或拒绝；每次操作重新验证 assignment、membership 与 permission。
4. 批准时锁定申请并获取 application advisory transaction lock；创建 active merchant organization、`public_visibility=false` 的 active store、申请人的 active owner membership和显式 organization scope。
5. 组织、店铺、membership、scope、application 状态和 event 必须在同一事务完成；任何一步失败全部回滚。批准重试返回相同 organization/store/membership，不创建重复对象。
6. 暂停只把已批准商家组织、店铺、owner membership/scope 置为 suspended，并记录有限事件；本地 Gate 不执行自动恢复或物理删除。

## 5. 资料、责任、SLA 与隐私决定

- 资料最小集：国家码、展示名、店铺 slug、合成登记引用、合成资料引用；不收集真实证件内容。
- 决策责任：分配由 platform admin；审核决定由当前 assigned reviewer；两者都从数据库关系推导。审核人不能自审。
- SLA：本地阶段采用人工队列，不自动批准、不配置倒计时或升级通知；未处理申请保持当前状态。
- 保留/删除：测试结束删除所有合成身份与业务 fixture；event 只用于本地审计。生产保留期未决，不能据本 Gate 推断。
- 审核原因只允许 `information_incomplete`、`eligibility_not_met`、`policy_violation`、`approved_checks_complete`、`risk_suspension`，禁止自由文本。

## 6. 验收矩阵

- schema/RLS/ACL：三张表 `ENABLE + FORCE RLS`，anon/authenticated/service_role 无直接 DML；七个 public wrapper 与七个 private implementation 仅 `authenticated` 可执行，direct implementation 必须通过正反向 parity 用例证明不能绕过重验证；其余 helper 对外不可执行，executor 不绕过 RLS。
- 申请：draft/save、首次 submit、补件后重提、同幂等键重试、重复 active application、无 OTP、错误域、匿名和非法资料引用。
- 分配/审核：无权限、inactive membership、非 platform org、自审、非 assigned reviewer、assignment 被替换、非法迁移和陈旧状态全部拒绝。
- 私有资料：本人可读自己的；当前 assigned reviewer 可读；平台 admin 未分配时、其他 reviewer、support、其他申请人不可读。
- 批准：组织/店铺/owner/scope 原子创建；重试无重复；冲突并发最多一次生效；注入失败后零部分对象。
- 暂停：商家对象、membership 和 scope 一致暂停；未批准申请不能暂停。
- 审计：成功事件 exactly once、actor 不可伪造、有限原因码、无 token/OTP/cookie/secret/真实 PII。
- 质量：fresh local reset、P2-L 全回归、P3 pgTAP/并发、strict db lint、security/performance advisors、migration list、Auth contract、typecheck、ESLint、Next build、diff check。

## 7. 运行与停止合同

- 唯一 local project：`rebuy-g2-a1-e2a-local-email-otp-exec`；唯一端口范围 `127.0.0.1:55320–55329`。
- 顺序：空资源预检 → pinned local start → AMR preflight → fresh reset/seed → P2-L 回归 → P3 tests/concurrency → lint/advisors/list → app quality → exact cleanup。
- start/status 原始输出不得进入 evidence；不得保存 key、DB 密码、OTP、session、cookie、JWT 或合成邮箱值。
- 任一阶段失败立即停止后续步骤，执行 `supabase stop --project-id rebuy-g2-a1-e2a-local-email-otp-exec --no-backup`，核对目标 containers/volumes/network/listeners 为空并删除临时原始日志。
- 首次完整 runtime PASS 后生成脱敏 evidence 与候选 SHA-256，再进行独立审查。审查 GO 前不得将 P3 标为已通过或打开 P4。

## 8. 回退

- 本地失败回退为精确 stop/no-backup 和重建空库；不删除共享 Colima 或其他项目资源。
- 迁移回退不在带真实数据环境执行；当前只能通过 fresh reset 验证向前迁移。任何 hosted rollback 另开 Gate。
- 未通过独立审查的候选不得 push、合并或部署。

## 9. 2026-09-03｜Runtime attempt #1 STOP

- 唯一 start、AMR preflight 与 fresh reset 通过；P2-L `113/113` 回归继续 PASS。
- P3 首个实质失败定位为 `SELECT ... FOR UPDATE` 在 exact application id context 建立前触发 UPDATE RLS，隐藏既有申请并误走重复 INSERT；另发现 draft withdrawal 的 `submitted_at` 约束过严。schema/security 的两项失败是 `proconfig` 测试表示错误。
- 后续 Gate 在首个失败后停止；没有运行 concurrency、lint/advisors/list 或 app build。exact cleanup、临时 raw 删除及目标资源/端口清空全部通过。
- 当前已形成离线修复候选；下一次从空资源和新 hashes 开始，不复用本次 runtime 结论。详见 [attempt #1 evidence](../evidence/P3/2026-09-03-runtime-attempt-1/README.md)。

## 10. 2026-09-03｜Runtime attempt #2 STOP

- 唯一 start、AMR preflight、fresh reset、P2-L `113/113` 与 P3 schema/security `18/18` 均 PASS。
- P3 workflow 首个实质失败缩小为 `merchant_application_private` update 的未限定 `application_id` 与 table-return output 变量重名（SQLSTATE `42702`）；其后 26 项为 application id 为空造成的级联。
- 已离线改为 `ap.application_id`，未改变业务授权；结构门和 diff check PASS。同包没有热修重跑，exact cleanup 通过。详见 [attempt #2 evidence](../evidence/P3/2026-09-03-runtime-attempt-2/README.md)。

## 11. 2026-09-03｜Runtime attempt #3 STOP

- fresh reset 后 P2-L + P3 四份 pgTAP 全部通过（`182/182`），同键批准双连接 concurrency PASS。
- strict DB lint 以三个 read implementation/wrapper 的 volatility 与 request-context reset 不一致、queue 未使用变量停止；没有继续 advisors/list/app quality。
- exact cleanup 通过。三次实际失败上限触发后，不再盲目 runtime，改由既有获批 reviewer 做只读专项审查。详见 [attempt #3 evidence](../evidence/P3/2026-09-03-runtime-attempt-3/README.md)。

## 12. 2026-09-03｜Independent specialty review NO-GO

- reviewer 给出 `P0=0 / P1=6 / P2=2`，覆盖 volatility、NULL identity、actor-global 幂等与历史结果、active role/permission 重验证、save/withdraw 锁序、ACL/并发覆盖、Gate direct-execute 合同和 cleanup 完整性。
- 当前仅完成离线 hardening candidate；follow-up reviewer 允许新 runtime 前，P3 仍为执行中且 P4/推送/部署关闭。完整 finding 见 [special review](../evidence/P3/2026-09-03-special-review/REVIEW.md)。

## 13. 2026-09-03｜Follow-up #1 NO-GO 与定向修复

- 首轮整改后 reviewer 将未关闭项缩小为 `P1=1 / P2=2`：旧 `needs_info` key 在补件重提清空 assignment 后不稳定、owner role scope/global 语义不足、不同 key 并发 loser 原因不精确。
- 最新离线候选把 review 历史 event lookup 前移并基于 event membership 重验权限；增加 owner organization/system/global 约束；并发 loser 必须为 `merchant_application_state_conflict` 且不得为 deadlock/timeout。对应历史重试、scope drift、mid-approval rollback、direct parity 和 verifier 已补齐。
- follow-up #2 明确 GO 前仍暂停数据库 runtime；详见 [special review](../evidence/P3/2026-09-03-special-review/REVIEW.md)。

## 14. 2026-09-03｜Follow-up #2 REVIEW GO

- exact source hashes 的独立复审为 `P0=0 / P1=0 / P2=0`，允许一次从空资源开始的 bounded local runtime；不等于 P3 Exit。
- verdict 与绑定见 [special review](../evidence/P3/2026-09-03-special-review/REVIEW.md)。

## 15. 2026-09-03｜Runtime attempt #4 STOP at all/info advisor

- fresh reset 后 P2-L + P3 pgTAP `223/223`、三场景并发、strict lint、security strict、performance/warn strict 全部 PASS。
- all/info 发现 P3 private 复合 FK 缺 covering composite index；为保持 `unindexed_foreign_keys=0`，停止 migration list/app quality 并 exact cleanup。
- 离线候选已增加复合索引与 pgTAP/verifier 锁定；详见 [attempt #4](../evidence/P3/2026-09-03-runtime-attempt-4/README.md)。

## 16. 2026-09-03｜Runtime attempt #5 complete local PASS

- 空资源入口、唯一 start、固定 Node 22 AMR 与 fresh reset 全部通过；P2-L + P3 四份 pgTAP `224/224`，三场景并发 harness PASS。
- strict lint、security strict、performance/warn strict 均无问题；all/info 只有 10 条 fresh empty database `unused_index` INFO，`unindexed_foreign_keys=0`、`auth_rls_initplan=0`、WARN/ERROR=`0`。
- migration local/database history 为 `20260831183358`、`20260903120000`；Auth `46/46`、三项 structure、typecheck、全量 ESLint、Next build 与 diff check 全部 PASS。
- exact stop/no-backup、raw 删除与目标资源/端口清空通过。P3 当前为 `RUNTIME PASS / FINAL INDEPENDENT REVIEW PENDING`；reviewer GO 前不打开 P4。详见 [attempt #5](../evidence/P3/2026-09-03-runtime-attempt-5-pass/README.md)。

## 17. 2026-09-03｜Initial final review NO-GO on evidence only

- exact commit `6e3cd7b` 的源码审查无 P0/P1/P2；唯一 `P2-E01` 是 attempt #5 未保存有限 runtime 工件和 candidate/evidence manifests，reviewer 无法独立核对 README 叙述。
- verdict 为 `REVIEW NO-GO / P0=0 / P1=0 / P2=1`。允许从空资源运行一次 evidence-only bounded rerun；不得从已删除 raw 事后伪造输出。详见 [final review](../evidence/P3/2026-09-03-final-independent-review/REVIEW.md)。

## 18. 2026-09-03｜Runtime attempt #6 auditable PASS

- source commit 保持 `6e3cd7b` 不变；唯一 start 后 AMR、fresh reset、pgTAP `224/224`、三场景 concurrency、lint/advisors/migration list、Auth `46/46`、三项 structure、typecheck、ESLint、Next build、diff check 全部 PASS。
- 本次在 cleanup 前保存脱敏有限输出和 candidate manifest；cleanup 后保存 cleanup 工件及 evidence manifest。exact stop/no-backup、raw 删除、资源与端口清空通过。
- 当前仅待同一 reviewer 定向关闭 `P2-E01`；GO 前 P3 local Exit、P4、hosted/Production、push/deploy 仍关闭。详见 [attempt #6](../evidence/P3/2026-09-03-runtime-attempt-6-pass/README.md)。
