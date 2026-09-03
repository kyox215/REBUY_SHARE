# P3 runtime attempt #2 — STOP

日期：2026-09-03（Europe/Rome）
范围：`synthetic-only local`；project=`rebuy-g2-a1-e2a-local-email-otp-exec`；loopback `55320–55329`

- 从 attempt #1 的空资源状态进入；唯一 start、Node `22.12.0` AMR preflight 与 fresh reset 均 PASS。
- P2-L 两份 pgTAP `113/113` PASS；P3 schema/security `18/18` PASS。
- P3 workflow `51` 项中 `24` PASS、`27` FAIL。唯一首个实质失败为 SQLSTATE `42702`：save implementation 的 private-row update 使用未限定 `application_id`，与 PL/pgSQL table-return output 变量同名；其后失败均由提交结果 id 为空级联。
- 同一运行包未运行 concurrency、db lint、advisors、migration list、app build 或数据库重试。
- 离线修复只给 `merchant_application_private` 加别名并使用 `ap.application_id`；无权限或业务状态放宽。修复后 migration SHA-256=`ac2ff39755785084a92dad26533af1f56133d9c04b066aa05171b4503bd41579`，P3 结构门与 diff check PASS。
- exact stop/no-backup exit `0`；两个精确 raw 临时日志已删除；目标 containers/volumes/network/listeners 均为空。

当前 P3 保持 `执行中 / runtime STOP`；下一工作包从空资源和新 migration hash 复验。
