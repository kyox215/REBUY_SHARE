# P4 商品、定价、库存与批发资格 Gate

文档状态：**已通过 / synthetic-only local Exit 已关闭**
记录日期：2026-09-03（Europe/Rome）
适用分支：`codex/rebuy-v1-local-complete`

## 1. 目标与范围

本阶段建立两条相互依赖的本地纵切：

1. 零售买家提交批发申请，平台分配审核并原子建立批发 organization、owner membership 与当前 qualification；资格失效后价格实时回退。
2. 已批准商家在自己的 organization/store scope 内维护分类、商品、listing、零售/批发价格、MOQ/阶梯价、普通数量库存和二手唯一单件；服务端只返回调用者当前适用价格。

仅使用 `@rebuy.test` 身份、`synthetic://` 资料引用和虚构商品。不开启 hosted Supabase、Storage、Production、外部通知、支付、配送、税务、促销、跨币种或真实商家/客户资料。

## 2. 已批准的最小商业决定

- 币种固定 `EUR`，金额使用非负整数分；V1 不处理汇率、含税拆分、优惠券、动态促销或议价。
- 每个 active listing 必须有一个 active retail price；wholesale price 可选，但存在时必须大于 `0` 且不高于 retail price。
- 批发 MOQ 最小为 `2`；阶梯数量严格递增，阶梯单价不得高于基础批发价且随数量不得上升。所有价格规则通过版本和事件追溯，不能静默覆盖历史。
- 只有 current qualification=`active`、`valid_from <= now < valid_until`、wholesale organization=`active`、调用者 active owner membership 与商品 wholesale rule 同时成立时，服务端返回 wholesale quote；否则只返回 retail quote。客户端角色、JWT metadata 或手动模式开关无效。
- 普通商品按整数数量管理，`available = on_hand - reserved`，任何调整或预留都以原子锁和幂等键执行；禁止负库存。
- 二手商品以单独 unit 表表达，一条 listing 在本地 V1 只能关联一个 unit，购买数量固定 `1`；状态只允许 `available`、`reserved`、`sold`、`inactive`，不能通过数量编辑复制单件。
- 加入购物车不预留库存；P4 提供受控原子预留/释放 primitive，P5 仅在提交订单事务中调用。超时自动释放不在 P4，P5 必须明确结算失败与回收策略。
- listing 只有在 merchant organization/store/product/listing 全部 active、retail price 有效且存在可售库存时才可公开 quote；问题 listing 通过下架/冻结恢复，不物理删除审计历史。

## 3. 最小数据合同

### 3.1 批发审核

- `wholesale_applications`：申请人、合成公司名/国家、状态、当前分配、幂等键、批准后 organization/qualification 引用。
- `wholesale_application_private`：只保存 `synthetic://` 登记/资料引用；仅申请人和当前 assigned reviewer 通过受控 RPC 读取。
- `wholesale_application_events`：append-only 申请/分配/决定事件；有限原因码，无自由文本。
- `wholesale_qualifications`：当前资格，绑定 approved source application 和 wholesale organization；状态 `active|suspended|expired|revoked`，带有效期和递增 version。
- application 终态 `approved|rejected|withdrawn` 不可原地改写；qualification 变更不回写 application 历史。

### 3.2 商品与库存

- `categories`：平台维护的有限分类树；公开只读 active 类目。
- `products`：merchant organization 内部商品主记录，类型 `standard|secondhand`。
- `product_variants`：SKU/单位与最小公开规格；不保存采购成本或供应商机密。
- `listings`：商品变体在 exact store 的上架状态、slug、公开标题/摘要与 version。
- `listing_prices`：retail/wholesale 基础价、MOQ、有效窗口与 version。
- `listing_price_tiers`：wholesale 阶梯数量与单位分价。
- `inventory_levels`：普通商品 on-hand/reserved/version；secondhand listing 不使用数量库存。
- `secondhand_units`：二手唯一 unit、有限成色/缺陷/电池/保修事实和状态；只允许合成序列引用。
- `catalog_events`、`inventory_events`：append-only 有限动作码、actor、对象、版本和数量差值，不保存自由文本或敏感正文。

## 4. 身份、权限与 RLS

- 复用受限 `rebuy_business_executor`；保持 `NOLOGIN/NOSUPERUSER/NOINHERIT/NOBYPASSRLS`，所有新表 `ENABLE + FORCE RLS`。
- 公开 wrapper 为 `SECURITY INVOKER`；private implementation 为 `SECURITY DEFINER`、空 `search_path`、全限定对象名，并在每次调用重新验证 signed JWT、recent OTP、active membership、active role/version、permission 和 exact organization/store context。
- merchant owner 在批准创建的 exact organization/store scope 内获得 catalog/pricing/inventory 权限；不得跨 merchant 读取或写入。
- platform admin 负责分配 wholesale review；current assigned wholesale reviewer 才能读取私有资料和作决定，禁止自审。support 不拥有审核、价格或库存写入权限。
- anon/authenticated/service_role 对内部表无直接 DML；公开目录与适用 quote 只通过最小 DTO/RPC 输出。任何 wholesale 内部规则、qualification 资料、on-hand/reserved 明细或审计内部字段不得因公开浏览泄露。

## 5. 事务、幂等与并发

- 所有写 RPC 使用 actor-global UUID 幂等键；同 actor/key 不同操作或对象 fail closed，成功重试返回相同业务引用和版本。
- wholesale 批准锁 application 与 actor/key，原子建立 organization、owner membership、organization scope、qualification 和 event；注入任一步失败必须零部分对象。
- price publish 锁 listing，验证 retail/wholesale/tier 全矩阵后一次写入新版本；旧 quote 不能冒充新版本。
- standard inventory 调整/预留/释放锁 exact inventory row，核对 expected version；并发预留总量不得超过 available。
- secondhand reserve 使用 unit row lock 和 expected status/version；并发请求最多一个成功，同键重试稳定返回原结果。
- 所有事务失败仅返回有限错误码，不返回 SQL、内部对象、原始 provider error 或资料内容。

## 6. 验收矩阵

- wholesale：申请/补件/撤回、分配、自审/越权、批准/拒绝、重复批准、历史重试、资格暂停/到期/撤销、权限或 membership 失效、mid-approval rollback。
- price：guest/retail/active wholesale/suspended/expired/revoked/失效 organization/membership 的 quote 矩阵；MOQ、阶梯边界、版本变化和不泄露 wholesale 规则。
- catalog：跨 tenant/store 负向；merchant owner 合法建商品/listing；inactive store/org/product/listing 不公开；非法 slug/SKU/合成引用拒绝。
- inventory：普通调整、负库存拒绝、同键重试、不同键并发不超卖、预留/释放守恒；二手 exactly-one、quantity=1、并发唯一 winner、sold 不可恢复为 available。
- security：effective table/column/function ACL、direct implementation parity、FORCE RLS、executor 属性/ownership/membership、空 search path、request-context reset。
- audit/privacy：成功事件 exactly once，有限原因码和版本完整；无 secret/token/OTP/cookie/真实 PII/自由文本。
- quality：fresh reset、P2/P3 全回归、P4 pgTAP/双连接 concurrency、strict lint、security/performance advisors、migration list、Auth/structure/typecheck/ESLint/Next build/diff check，以及完整脱敏工件和 manifests。

## 7. 运行与审查合同

- 唯一本地 project=`rebuy-g2-a1-e2a-local-email-otp-exec`，端口=`127.0.0.1:55320–55329`；每个 bounded packet 从空资源开始，结束 exact stop/no-backup。
- 任一失败立即停止后续步骤，删除 start/reset raw，核对目标 containers/volumes/network/listeners 为空；不停止共享 Colima 或其他项目资源。
- runtime 前先通过静态 structure/syntax/quality 与独立只读审查；最多三次实质失败，达到上限转专项审查，不盲目重跑。
- 完整 runtime 必须在 cleanup 前保存有限脱敏工件和 candidate manifest，cleanup 后生成 cleanup 工件与 evidence manifest；final independent GO 前不得关闭 P4 或打开 P5。

## 8. 回退与阶段边界

- listing/price/inventory 问题：下架 exact listing、冻结其写入并按事件/version 修复；不得删除价格、库存或资格历史。
- local migration 只验证向前重建，不在真实数据环境做 rollback；hosted 迁移、备份恢复、真实资料和 Production 均属于后续 P7/发布 Gate。
- 本 Gate 不实现购物车、订单、商家 UI 或真实平台 UI；对应 P5/P6。P4 final GO 前 P5–P7、main push、合并和部署继续关闭。

## 9. Final independent review

- exact source commit=`abf4dfa0367c60310fcb29a932cd99d559c55a17`；evidence HEAD=`313754aa82ffa5b945f6aec398ccb6b26e768988`。
- attempt #5 从空资源完成 AMR、fresh reset、六文件 pgTAP `364/364`、三场景双连接库存并发、strict lint、security/performance advisors、migration list、Auth/structure/typecheck/ESLint/Next build/diff check，并完成 exact cleanup。
- independent final verdict=`FINAL GO / P0=0 / P1=0 / P2=0`；P4 synthetic-only local Exit 关闭，允许打开 P5 synthetic-only local Entry。
- 该结论不证明 hosted/Production，不授权真实 PII、支付、物流、税务、main push 或部署。完整证据见 [attempt #5](../evidence/P4/2026-09-03-runtime-attempt-5-pass/README.md) 与 [final review](../evidence/P4/2026-09-03-final-independent-review/REVIEW.md)。
