# P3 independent specialty review — NO-GO

日期：2026-09-03（Europe/Rome）
审查方式：既有获批 reviewer，只读静态/证据复核；未运行数据库、未修改源码

## 绑定快照

reviewer 报告的候选 hash 前缀：migration=`ac2ff397…`、schema test=`83d46e…`、workflow test=`26aa7d…`、concurrency=`47b119…`、structure verifier=`d3c93…`。本报告只把这些值作为 reviewer 当时返回的绑定前缀，不扩写未知后缀。

## Verdict

`REVIEW NO-GO / P0=0 / P1=6 / P2=2`

- P1-01：三个 read implementation/wrapper 的 volatility 与 context reset 不一致；queue 存在未使用局部变量。
- P1-02：缺失/null email 可能通过 SQL NULL 逻辑；缺少 missing AMR、anonymous 和 direct-call 负向覆盖。
- P1-03：幂等唯一域只按 application，历史重试读取当前状态/引用，且同 actor/key 不同操作或对象的冲突合同不足。
- P1-04：权限 helper 未完整绑定 active role definition/platform 适用性，review 未同时重验 read/review permissions。
- P1-05：save/withdraw 锁域不一致，存在旧读后把已撤回行写回的竞态风险。
- P1-06：effective table/column/function ACL、身份与角色失效、并发不同键和 direct parity 覆盖不足。
- P2-01：Gate 的 “private implementation 不可外部调用” 与 P2-L invoker composition 的 authenticated direct execute 架构不一致。
- P2-02：并发清理只核对部分 fixture，失败 stage 与返回引用验证不足。

## 处置

当前离线 hardening candidate 正在逐项关闭以上 finding；在 structure/workflow/concurrency tests 与 verifier 锁定、follow-up reviewer 明确允许前，不开启下一次 bounded runtime。本报告不是 P3 通过证据。

## Follow-up #1

`REVIEW NO-GO / P0=0 / P1=1 / P2=2`

- 旧 finding 大部分已关闭；唯一 P1 是 `needs_info` 历史重试仍先依赖当前 assignment，而申请人补件重提会清空 assignment。
- P2 为 canonical owner role 仍缺 `scope_type=organization`/global system 语义，以及不同 key 并发 loser 只判断非零退出、未精确限定为 state conflict。
- reviewer 绑定：HEAD=`2e59c700b18784b0174f6fb1fe1f2f8307f86af3`；migration=`1684935189dc9b734a7bcce159103f9e6158e92f051647f5dbaf201bca3346b1`；schema=`2257abd30e5b63b228c2f59f6a28d960a414f8bdbbeeddb6a8695f532f8d9a3d`；workflow=`3fa5b0846cd7b6496fac90c78be35118b6c129b3f5b56d5d6b2ca17455cfdcce`；concurrency=`f3dca089a63ae267ebd3c098bfd951abe31923724fa77d0970a37bbcd098f3c6`；verifier=`a246989bdd147266ce41ba02496c6f2e384f6e4f5d56cea3482bc6ca94af3149`。

当前候选已离线处理三项并增加对应 workflow/concurrency/verifier 锁定，正在进行 follow-up #2；明确 GO 前仍不得运行数据库。

## Follow-up #2

`REVIEW GO / P0=0 / P1=0 / P2=0`

- P1-01：review 已在 actor-key lock 后先查历史 event，再基于 event reviewer membership 重验 active role/read/review 和非自审；needs-info 重提历史路径完整覆盖。
- P2-01：canonical owner 同时绑定 organization scope、system/global 属性，scope drift fail closed。
- P2-02：不同 key concurrency loser 精确限定 `merchant_application_state_conflict`，明确排除 deadlock/timeout。
- reviewer 额外确认 mid-approval trigger rollback、七个 direct implementation parity、全类别 cleanup 通过静态复核。

绑定 hashes：migration=`8da9f930d0193c2dcdf5573fd81568d9ce749882127ed49a3805225b3b2e9457`；schema=`2257abd30e5b63b228c2f59f6a28d960a414f8bdbbeeddb6a8695f532f8d9a3d`；workflow=`8c95d05582d6b26ea14fc7aaef77b6378a316cb18283e6f5cd51d7fc1d87f033`；concurrency=`77454f74487ec0ce8c9fb8e85ce9c0c2b6ffe59ff589b80f12999bfc52476b87`；verifier=`669d6f01ae33b0de6de91ad3e868f4d1fa84e36179b7ff2cff576c26a1a2d356`。该 GO 只允许下一次 bounded local runtime，不等于 P3 Exit。

## Index-only follow-up after attempt #4

`REVIEW GO / P0=0 / P1=0 / P2=0`

- reviewer 确认新增 `(application_id, applicant_user_id)` composite index 精确覆盖 attempt #4 的 FK finding，且 schema pgTAP 与 structure verifier 同步锁定。
- 绑定 hashes：migration=`4eb494895efb52005fbe0e09e35f995b3bd62231a7691aba844f83776480a895`；schema=`ee27863ba99588424bc984003775babfea7bb7ea88cc529381868e1e51e7a520`；workflow=`8c95d05582d6b26ea14fc7aaef77b6378a316cb18283e6f5cd51d7fc1d87f033`；concurrency=`77454f74487ec0ce8c9fb8e85ce9c0c2b6ffe59ff589b80f12999bfc52476b87`；verifier=`38fbc5ebd94108f2a5511154974032819379d46efd40acae42c5a06769905e57`。
- 该 GO 只允许一次从空资源开始的 bounded rerun，不等于 P3 Exit。
