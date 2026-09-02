# P2-L private function owner-transfer design review

日期：2026-09-02（Europe/Rome）
结果：**OWNER APPROVED 2026-09-03；等待实现与 runtime 证明**

## Constraint

`ALTER FUNCTION ... OWNER TO rebuy_invite_executor` 需要 migration runner 能 `SET ROLE` 到 executor，且 executor 对 `private` schema 有 `CREATE`。这是 PostgreSQL 17 的强制 owner-transfer 安全条件。第 53 节批准的最终平台行只有 `ADMIN=true/INHERIT=false/SET=false`，executor 当前也不持有 schema CREATE，因此最终最小权限与迁移期 owner handoff 需要区分。

## Proposed exact transactional exception

仅在两个 private functions 的 owner transfer 周围建立一个显式事务：

1. runner 凭现有 bootstrap `ADMIN=true`，用 `GRANTED BY CURRENT_USER` 新增第二条 self-grant：`role=rebuy_invite_executor`、`member=postgres`、`grantor=postgres`、`ADMIN=false`、`INHERIT=false`、`SET=true`；
2. 由 private schema owner 临时 `GRANT CREATE ON SCHEMA private TO rebuy_invite_executor`；
3. 完成两个精确签名的 `ALTER FUNCTION ... OWNER TO rebuy_invite_executor`；
4. 在同一事务内按 `GRANTED BY CURRENT_USER` 完整撤销第二条 role grant，并撤销 executor 的 private schema CREATE；
5. `COMMIT` 前重复最终 fail-closed guard：与 executor 相关总行数恰好一，唯一行为第 53 节 bootstrap grant；executor 作为 member 零行；`postgres` 对 executor 的 `USAGE=false/SET=false`；executor 对 private schema `CREATE=false`；两个 function owner 正确。

任何步骤或最终断言失败都必须回滚整个事务，禁止依赖后续 cleanup 修复 catalog。该例外不授予 login、anon、authenticated、authenticator、service_role，不产生持久 SET/INHERIT/schema CREATE，也不改变应用请求权限。

## Why approval is required

虽然最终 catalog 不变，但 migration 事务中会短暂允许 runner `SET ROLE` 到 executor，并短暂给予 executor private schema CREATE；这超出了之前只批准“最终唯一 membership”的措辞，属于新的安全敏感能力，必须 action-time exact approval 后才可实现。

## Approval record

Owner 在 2026-09-03（Europe/Rome）看到上述完整例外后回复“批准全部”。该回复只把本文件的原子 owner-transfer 方案从待批转为可实施；runtime 是否通过仍由空库 migration、最终 catalog pgTAP、RLS/grant 矩阵和 cleanup 证据决定。

官方依据：

- [PostgreSQL 17 ALTER FUNCTION](https://www.postgresql.org/docs/17/sql-alterfunction.html)
- [PostgreSQL 17 GRANT](https://www.postgresql.org/docs/17/sql-grant.html)
- [PostgreSQL 17 SET ROLE](https://www.postgresql.org/docs/17/sql-set-role.html)
- [PostgreSQL 17 REVOKE](https://www.postgresql.org/docs/17/sql-revoke.html)
