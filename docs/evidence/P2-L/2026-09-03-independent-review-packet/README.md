# P2-L independent review packet

复审结论见 [REVIEW NO-GO / P0=0, P1=2, P2=2](./REVIEW.md)。

日期：2026-09-03（Europe/Rome）
状态：**ORIGINAL REVIEW COMPLETE / REMEDIATION FINAL REVIEW PENDING**

本文件固定 attempt #16 的原始复审输入；对应结论是上方 `REVIEW NO-GO`。整改后的 exact runtime 证据见 [attempt #20 PASS](../2026-09-03-schema-runtime-attempt-20-pass/README.md)，其最终复审必须另行绑定新的 exact commit/hashes，不改写本文件第 2 节的历史候选。

## 1. Reviewer independence and decision format

- Reviewer 必须独立于本候选的实现与第 16 次 runtime 执行；本文件不能由主执行者自签为 GO。
- 复审只读绑定本节 exact hashes；任何受审文件改变都使结论失效，必须重新绑定。
- 结论格式必须包含：`REVIEW GO` 或 `REVIEW NO-GO`、P0/P1/P2 数量、每个 finding 的文件/位置/风险/建议，以及核对过的 exact hashes。
- GO 最低条件：P0=`0`、P1=`0`；P2 必须明确说明是否阻塞 P2-L Exit。不得用 runtime 全绿代替源码安全审查。

## 2. Exact candidate

- branch=`codex/rebuy-v1-local-complete`
- base HEAD=`0e5084b62c76275a781ec08edea287a06d442209`
- roles=`5cfae70ee397399f1a35ea379b5b119a19928c23`
- migration=`11a7ffc7daf34833a81f7eec78138e5055b876f2`
- seed=`9134ed7b8ec00f2bb713a3f1ffcd1e57983c0422`
- schema pgTAP=`27b981bc83b488d39bb025838541157603d28dd2`
- invitation pgTAP=`9c68465b8ae0f48afad0ae3fff6d63985549c8c0`
- structure verifier=`7a2e43343c7bba4e08a06d56c989f15e66430785`

受审实现与验证入口：

- `supabase/roles.sql`
- `supabase/migrations/20260831183358_p2l_local_schema_rls_invites.sql`
- `supabase/seed.sql`
- `supabase/tests/p2l_schema_security.test.sql`
- `supabase/tests/p2l_invitation_flows.test.sql`
- `prototype/scripts/test-p2l-migration-structure.mjs`
- `docs/stages/P2-L-本地Schema与RLS纵切Gate.md`
- `docs/evidence/P2-L/2026-09-03-schema-runtime-attempt-16/README.md`

## 3. Required review questions

1. Scope 是否严格为首批十张 public 业务表，且没有后置 wholesale/qualification/security-event、Storage、payment 或 `auth.users` trigger。
2. `rebuy_invite_executor` 七项危险属性是否 fail closed；PostgreSQL 17 bootstrap membership 是否只能为获批的唯一行；owner-transfer 的第二 membership/schema CREATE 是否限定在同一原子 `DO` 内并在最终断言前撤销。
3. public wrappers 是否为 `SECURITY INVOKER`，private implementations 是否为 empty-search-path、fully-qualified、正确 owner 的 `SECURITY DEFINER`；ACL 顺序是否先于 owner handoff 且没有 `PUBLIC`、`anon`、service-role 或 direct protected-table DML 泄露。
4. 十表是否全部 `ENABLE`+`FORCE RLS`；executor policy 是否 narrow permissive allow + restrictive guards，authenticated self policies 是否包含行级 ownership，而不是只依赖 `TO authenticated`。
5. 身份/授权是否只使用 Data API 已验签 request claims、`auth.uid` 等价 project helper、规范化 `@rebuy.test` email 与最前 `amr[0]`；是否完全排除 user metadata、客户端 role/scope/time/boolean、JWT `iat` 与 service role。
6. create/accept invitation 是否重验 active membership、`member.invite`、role status/version/assignability、organization/store scope、target email、expiry/revocation/consumption；行锁、advisory transaction lock、idempotency 和 conflict retry 是否不会产生重复 membership/scope/audit 或跨身份重放。
7. organization 与 exactly-one-store scope 是否都写显式 scope row，empty scope 是否 deny，multi-store JSONB/array 是否不存在。
8. audit 是否仅记录最小事件绑定且不可由调用者伪造；失败路径是否不泄露 token、OTP、cookie、secret、真实 PII 或内部权限结构。
9. 179 处 policy GUC 读取包装 scalar SELECT 是否只改变 init-plan 性能而不改变 transaction-local context 语义；四个复合 FK index 的 leading columns 是否与对应 constraint 完全一致。
10. pgTAP `87/87` 与静态 verifier 是否真实覆盖合同的关键正负向；attempt #16 的 strict lint、security/performance advisors、all/info 分类、migration list 与 exact cleanup 是否足以支持 runtime PASS，是否存在测试空白或被错误解释的 `unused_index` INFO。

## 4. Non-goals and boundary

- 本复审不评估 hosted Supabase、真实 PII、OAuth/custom SMTP、Production 数据或部署；也不把 P2-L local slice 外推为完整 P2/G2-A1。
- 不要求再次启动数据库即可完成源码审查；若 reviewer 选择运行验证，必须遵循 exact local project/port/cleanup 合同，且不能使用 privileged secret/service-role 路径。
- Review GO 后仍需在权威台账追加 exact verdict；只有 P2-L Gate 判据全部满足后才能打开下一阶段。Review packet 本身不改变任何 Gate。
