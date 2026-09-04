# P6 final independent review

日期：2026-09-04（Europe/Rome）  
审查边界：只读；已提交、哈希绑定的脱敏本地证据  
源码候选：`09f69e6d9830a374b34bdd69ea675b2b027b7521`  
证据提交：`0b43b6e3c0df0ec0ad4862d04129db1c599c8a82`

## 结论

`FINAL GO`

`P0=0 / P1=0 / P2=0 / P3=1`

## 已核验事实

- clean evidence HEAD 的直接父提交是冻结源码候选；证据提交仅新增 final runtime packet 的 16 个文件。
- `candidate-sha256.txt` 为 `33/33 OK`，路径集合与 `git diff --name-only 90744a1 09f69e6` 完全一致；`evidence-sha256.txt` 为 `15/15 OK`，覆盖 manifest 自身以外的全部证据文件。
- entry、start、AMR、reset、pgTAP、concurrency、lint/advisors、migration、app quality、browser、recovery、commands 与 cleanup 输出均已提交并受 manifest 约束；敏感值扫描未发现邮箱、UUID、JWT、cookie、连接串、密钥或 OTP 值。
- 全部 12 个 private implementation 均有 authenticated-only effective EXECUTE ACL 验证，并排除 anon/service_role；store-scoped employee 正负向、权限撤销、retired-role drift、public/private read/write parity 与 private direct cross-store deny 均有 pgTAP 和结构防回归覆盖。
- invitation accepted replay 在取得 invitation 行锁后使用 `clock_timestamp()` 重验 membership 有效期，关闭旧 statement timestamp 在并发等待期间产生的假阴性；failure cleanup 改为解析后的 JSONB 结构比较。
- 最终证据为 fresh reset PASS、十文件 pgTAP `502/502`、六套 concurrency 全 PASS；entry 与 cleanup 均显示目标 containers、volumes、network、listeners 为空，stop/no-backup 成功，临时 Chrome profile 已删除。

## 残余非阻塞项

- `P3-A01`：P6 audit RPC 先把 merchant/catalog/inventory events 聚合进 JSONB，最后才 `LIMIT`。大数据量时可能增加内存与延迟；最小后续优化是关系式 `UNION ALL` 合并、过滤和排序后再限流。

本结论只支持关闭 P6 synthetic-only local Exit，不证明 hosted/Production、真实 PII、push、merge 或部署；这些由 P7 独立验证。
