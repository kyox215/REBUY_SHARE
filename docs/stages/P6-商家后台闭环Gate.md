# P6 商家后台闭环 Gate

文档状态：**执行中 / synthetic-only local Entry 已打开**
记录日期：2026-09-03（Europe/Rome）
适用分支：`codex/rebuy-v1-local-complete`

## 1. 目标与范围

本阶段建立与买家端分离的 Merchant Shell，让已通过审核且会员资格有效的商家在自己的 organization/store scope 内查看运营摘要，维护商品、listing、零售/批发价格与库存，处理自己的商家子订单，记录有限售后案件并查看可追溯操作日志。

仅使用 `@rebuy.test` 合成身份、虚构商品/订单和有限原因码。不开启 hosted Supabase、Production、真实商家或客户 PII、Storage、支付、退款、真实物流、税务、发票、外部通知、ERP 或微信同步。

## 2. 已批准的最小业务决定

- Merchant Shell 使用 `/merchant` 独立路由、侧栏和店铺上下文；不得进入买家五项导航，也不得把 Buyer Shell 改成按角色切换的巨型组件。
- P6 使用 P2 的 membership、store scope 与 permission catalog 作服务端授权；客户端隐藏菜单不是安全边界。owner 可在其 organization 下操作授权 store；employee 只在明确 store scope 和获授权限内操作。
- P4 的 product/variant/listing/price/inventory 是唯一目录与库存事实源。所有商家写入继续走受控 RPC，不开放 direct table DML；价格仍为 EUR 整数分，批发定价继续由 P4 自动规则决定。
- 子订单只能由对应 merchant organization/store 读取和推进；买家 batch 不得被商家跨店读取。最小履约状态为 `pending → accepted → shipped → completed`，另允许未接单时 `pending → rejected` 并原子释放库存。
- `shipped` 只保存 `synthetic://shipment/...` 引用；`completed` 原子把 reserved inventory 转为 sold。P6 不表示真实承运、支付结算或客户签收。
- 售后只实现有限 case：`opened → reviewing → resolved|rejected`，原因码和 resolution code 均为白名单；不存聊天自由文本、附件、银行卡或退款凭据，不执行资金动作。
- 所有高风险 mutation 使用 recent email-OTP identity、actor-global UUID idempotency key、expected version 与确定锁顺序；重试返回原结果，冲突返回有限错误码。

## 3. 权限与数据合同

- 新增最小权限：`merchant.dashboard.read`、`merchant.order.fulfill`、`merchant.after_sale.manage`、`merchant.audit.read`；目录、listing、pricing、inventory 继续复用 P4 权限。
- `owner` 获得上述 P6 权限；`employee` 只获得 dashboard/order/after-sale 的 store-scoped 权限，不自动获得 catalog/pricing/inventory/audit 或组织级成员权限。
- `merchant_after_sale_cases`：merchant_order、organization/store、buyer、reason/status/resolution、version、created/updated/resolved；不得有自由文本或真实联系资料。
- `merchant_operation_events`：organization/store、actor membership/user、entity/type、有限 event/reason、from/to state、version、idempotency key、created；append-only。
- `p6_idempotency_keys`：actor-global key、operation/fingerprint、target/result/version；同 actor/key 跨操作冲突 fail closed。
- P4/P5 表只做最小兼容扩展；不可删除或改写既有 append-only inventory/order evidence。

## 4. RPC、RLS 与 DTO

- read RPC：`get_my_merchant_context`、`get_my_merchant_dashboard`、`list_my_merchant_products`、`list_my_merchant_inventory`、`list_my_merchant_orders`、`get_my_merchant_order`、`list_my_merchant_after_sales`、`list_my_merchant_audit`。
- write RPC：复用或包装 P4 catalog/listing/pricing/inventory primitives，并新增 `advance_my_merchant_order`、`open_my_merchant_after_sale`、`review_my_merchant_after_sale`。
- public wrapper 保持 SECURITY INVOKER；private implementation 保持 SECURITY DEFINER、空 search path、全限定对象、`rebuy_business_executor` owner 和最小 function ACL。每次调用双向清理 P2/P3/P4/P5/P6 request context。
- 所有新表 ENABLE + FORCE RLS；anon/authenticated/service_role 无 direct internal table DML。DTO 不返回买家 email、配送引用、内部库存实现、其他商家金额/商品、role catalog 内部字段或审查备注。
- organization/store/membership/status/validity/role version/permission 必须在每次读写实时重验；membership 撤销、store inactive、scope 漂移或权限回收立即 fail closed。

## 5. 事务、状态与并发

- 目录、价格、库存写入沿用 P4 actor-global 幂等与 version gate；P6 UI 必须传 expected version，不做最后写入覆盖。
- 订单操作按 actor/key → organization/store → merchant_order → listing/inventory ID 排序锁定；拒单释放和完成售出必须与状态/event/idempotency 同事务。
- 同 key 重试只返回原状态；不同 key 并发推进只有一个成功，loser 为有限 state/version conflict，不得跳状态、重复释放/售出或写重复 event。
- 跨店/跨组织 target、买家账号、无权限 employee、过期 membership、已关闭状态、伪造 organization/store 均拒绝且零部分写入。
- 售后状态推进与 event/key 原子；重复提交稳定、不同 key 并发只有一个状态迁移成功。

## 6. Merchant UI 合同

- `/merchant` 工作台显示当前 organization/store、待处理子订单、低库存/无货、售后待办和最近操作；不显示平台全局或其他商家数据。
- `/merchant/products` 支持搜索、创建/编辑商品与 variant、listing 上下架、零售价/批发 MOQ/阶梯规则；表单显示字段级错误和保存版本冲突。
- `/merchant/inventory` 显示 standard available/reserved/sold 与 secondhand unique unit 状态，允许带白名单原因码的库存调整。
- `/merchant/orders` 与详情展示本店子订单、商品快照、金额和时间线，提供接单、拒单、标记合成发货、完成操作；不显示未授权买家资料。
- `/merchant/after-sales` 显示有限售后状态与处理动作；`/merchant/audit` 显示本店有限审计事件并支持 entity/event/date 筛选。
- desktop 采用 248px 侧栏和表格/分栏；mobile 只保留高频卡片任务。验证 390/430/768/1024/1440、键盘 Tab/Enter/Escape、焦点可见、44px 操作区、空/403/冲突/加载/成功状态及 no-console-error。

## 7. 验收矩阵

- authorization：owner/employee、organization/store scope、active/expired/revoked membership、role version/permission drift、跨租户/跨店正负向与 DTO 脱敏。
- catalog/inventory：创建/编辑/上下架、standard/secondhand、零售/批发/MOQ/tier、expected version、同/不同 key、库存不超卖及现有 P4/P5 回归。
- orders：own list/detail、跨店拒绝、合法/非法状态迁移、同/不同 key 并发、拒单释放、完成售出、mid-operation rollback、event exactly once。
- after-sales/audit：有限原因/状态、跨店拒绝、并发推进、append-only、无自由文本/PII、角色撤销后不可读写。
- security：FORCE RLS、effective ACL、direct wrapper/implementation parity、executor membership/owner、request context reset、FK indexes 和有限错误。
- UI：真实 local Auth + Merchant Shell 全路径、desktop/mobile/keyboard/重复提交/冲突恢复/no-console-error；不得用静态 mock 冒充后端。
- quality：fresh reset、P2–P5 全回归、P6 pgTAP/concurrency、strict lint/advisors/migration list、Auth/structure/typecheck/ESLint/Next build、浏览器 E2E、diff check、脱敏 manifests 与 final independent review。

## 8. 运行、停止与回退

- 唯一本地 project=`rebuy-g2-a1-e2a-local-email-otp-exec`，端口=`127.0.0.1:55320–55329`；每个 bounded packet 从空资源开始，以 exact stop/no-backup 和零 containers/volumes/network/listeners 结束。
- runtime 前先通过 structure/syntax/quality 与独立只读审查；任一失败立即停止并清理。最多三次实质失败，达到上限转专项审查。
- 模块失败时仅关闭对应 mutation，保留安全只读和 append-only evidence；不删除订单、库存、售后或审计历史，不手工伪造成功状态。
- 完整 runtime 与 final independent GO 前不得关闭 P6 或打开 P7；hosted/Production、真实 PII、支付/物流/税务、main push/merge/deploy 继续关闭。
