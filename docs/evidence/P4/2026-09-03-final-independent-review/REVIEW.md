# P4 final independent review

日期：2026-09-03（Europe/Rome）

结论：**FINAL GO**

Finding：`P0=0 / P1=0 / P2=0`，无开放项。

## Candidate binding

- source commit=`abf4dfa0367c60310fcb29a932cd99d559c55a17`。
- evidence HEAD=`313754aa82ffa5b945f6aec398ccb6b26e768988`，worktree clean；两提交之间只新增 attempt #5 的 15 个证据文件。
- candidate manifest `19/19 OK`；evidence manifest `14/14 OK`。
- 核心 SHA-256：migration=`a5c7ae913070c153b99ca89093c980346087df0440cbfbc09b56576887126866`；seed=`ffbb4aee7aea289ac0c04ab57ae1c9a39f72f6b3beafc11092b1ebca0767e094`；schema=`e599af6fde0fc4eb659d2b8914914f009e12d91a14002371b8eaeb1cdba923dd`；workflow=`d71edd6d03017ae567028045d048d23e18b90cc99a41b0530558b288abb212b5`；concurrency=`1340ccb09b7e8ad619e8e55891e7fbbae7df3cb9461c25981b682efdf2139052`；structure=`ec8c519f40e6580e9bf444efffb10043ac89199d46e6ee3ba1f1b313bd94c644`。

## Independent findings

- 15 张 P4 表均 FORCE RLS；public SECURITY INVOKER wrapper、private empty-search-path SECURITY DEFINER、精细 ACL、executor owner handoff 与 P5-only reservation primitive 非公开边界成立。
- actor-global 幂等、历史重试权限重验、批发批准零部分对象回滚、实时资格降级、EUR/MOQ/阶梯约束、standard/secondhand 锁与版本、有限审计均有实现与正负向覆盖。
- 六文件 pgTAP `364/364`；并发覆盖同键稳定结果、standard 不超卖、secondhand 唯一 winner、真实 lock barrier、有限 loser 错误和角色/fixture cleanup。
- strict lint、security/performance advisors、FK 索引、migration history、Auth `46/46`、structure、typecheck、ESLint、build、diff 与最终资源清理全部满足 P4 Gate。41 条 info 全为 fresh DB `unused_index`，不是阻断 finding。
- 证据目录敏感模式扫描未发现 key、password、OTP 值、JWT/token/cookie、邮箱值、连接串、provider response 或真实业务 PII。

## Boundary

- 结论只证明 exact candidate 的 synthetic-only local P4 Gate；脱敏有限工件不是第三方签名或完整原始日志。
- 允许关闭 P4 synthetic-only local Exit 并打开 P5 synthetic-only local Entry；不外推 hosted/Production，不授权真实 PII、main push 或部署。
