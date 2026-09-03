# P2-L final independent review

日期：2026-09-03（Europe/Rome）

结论：**REVIEW GO**

计数：`P0=0 / P1=0 / P2=1`

## Exact binding

- commit=`285c2361c6362e5be30e03ee445f2c4d5b6f7361`
- branch=`codex/rebuy-v1-local-complete`
- worktree=`clean`
- roles=`a27c5368ce87df265237ea9dc59bb460bb222d4da6a2bff66d5b352b656bc7fd`
- migration=`13af3f60d2e665efaf3ae228cad2ffdee04d55c0a3969f55bbe65e4599ce28ba`
- seed=`e4e2890b878076ac9779117362705415a8d03ae1e039f48327c604e133b95ad1`
- schema pgTAP=`b68f0dfd3a13b5e29bf811b073e78ab62a99876a037230a109357efb200f24cc`
- invitation pgTAP=`270a4ec2a682a29e6964b55b35d0fa679964f1639a1dae8ed9475b0eacd31016`
- migration verifier=`8f8df05ce02c3173d186aa116fda35a5252295e8129e3ccc7c9ad40b31885b79`
- concurrency harness=`7938ce267e1d0febfad746bb7dcc8b575321e04719595b9b95c1e9a7ff294feb`

Reviewer 对 candidate manifest 11 项 SHA-256 全部核验为 `OK`；两个离线结构门和 concurrency syntax 也通过。

## Original findings closeout

- P1-01 closed：migration 显式撤销 `service_role` 对 private schema、十表与六个函数的权限；pgTAP 验证 effective schema/table/column/function ACL；静态 verifier 固定 revoke。
- P1-02 closed：accept 的 AMR/iat、过期 OTP、email、creator/candidate/org/store 状态重验证、organization/store scope、stable retry 与真实双连接竞争矩阵均有覆盖；attempt #20 为 pgTAP `113/113` 和 concurrency PASS。
- P2-01 closed：public accept 只暴露 `invitation_not_available`；源码静态门和 pgTAP 都拒绝内部授权状态泄露。
- P2-02 closed：attempt #20 保存有限脱敏结果、命令、candidate/evidence manifests；evidence 13/13 hashes 全部核验通过。

## Concurrency special closeout

- cleanup 是单事务；先精确解除 `source_invitation_id` 回链，再按 audit → scopes → unlink → invitations → memberships → stores → organization → auth users 删除。
- profiles 依赖 migration 中的 `ON DELETE CASCADE`；正常路径验证八类资源全零。
- stable retry 对 exactly-one lookup、A/B invitation、membership/org/store/scope 完整返回、signal/exit、unavailable generic error 均有精确断言。
- 静态 verifier 固定事务、顺序、cascade、stage 与 retry 合同。

## Non-blocking P2 debt

- `prototype/scripts/run-p2l-invitation-concurrency.mjs` 失败清理路径使用两个 `JSON.stringify` 比较对象。PostgreSQL `jsonb` 不保证调用方插入键序，真实零残留时理论上可能错误报告 `cleanup_fail`。
- 该问题是 fail-closed 的诊断假阴性，不会产生 cleanup 假 PASS，也不影响 attempt #20 已通过的正常路径零残留验证，因此不阻塞 P2-L Exit。
- 后续最小修复：用 deep equality 比较解析后的 cleanup state，并让静态 verifier 拒绝双 `JSON.stringify` 比较。修复时需建立新的 hash/验证记录，不回写本次 exact review 绑定。

## Gate result

P2-L local Exit 可以关闭；允许按已批准顺序打开 P3 自身的 bounded Gate。该 GO 不等于 P3 PASS，也不开放 hosted/Production、main push 或部署。
