# P5 浏览、购物车与订单 Gate

文档状态：**已通过 / synthetic-only local Exit 已关闭**
记录日期：2026-09-03（Europe/Rome）
适用分支：`codex/rebuy-v1-local-complete`

## 1. 目标与范围

本阶段完成零售/批发买家的下单闭环：匿名或登录用户浏览和搜索公开商品；登录用户按服务端当前适用价格维护购物车；提交时原子复核价格与库存、建立一个订单批次及按商家拆分的子订单；买家查看自己的订单并在尚未履约前取消、释放库存。

仅使用 `@rebuy.test` 合成身份、虚构商品和 `synthetic://delivery/...` 配送引用。不开启 hosted Supabase、Production、真实姓名/电话/地址、支付、税务、发票、物流商、优惠券、退款或外部通知。

## 2. 已批准的最小订单决定

- 币种固定 `EUR`，金额为非负整数分；P5 的 shipping/tax/discount 均固定 `0`，订单总额等于商品小计，不表示已支付。
- 匿名用户可浏览/搜索和获取零售价；购物车、结算、订单列表/详情/取消必须登录。批发价格继续完全由 P4 服务端资格规则判定，客户端不得选择身份或价格模式。
- 每个用户最多一个 active cart；cart 可跨多个 merchant/store。standard 数量为 `1..1,000,000`，与 P4 报价/库存上限一致；secondhand 数量固定 `1`；加入购物车不预留库存。
- 购物车展示每次读取时的 current quote；任何旧价格、客户端金额、客户端库存或客户端商家分组都不作为结算输入。
- checkout 以 actor-global UUID 幂等键、cart version 和确定性 listing 顺序执行；再次读取 current quote/availability/version，并通过 P4 private reservation primitive 在同一事务预留全部商品。
- 任一商品无效、库存/版本变化、价格不再可用或写入失败时，整个 checkout 回滚：零订单、零子订单、零残留预留、购物车不清空；返回有限错误码。
- 成功 checkout 建立一个 `order_batch`，按 exact merchant organization/store 建立 `merchant_orders`，保存不可变 `order_items` 价格/商品快照和 append-only events，然后清空 active cart items。
- P5 成功订单状态为 `confirmed`、库存状态为 `reserved`、支付状态为 `not_required`。商家接单/发货/完成及库存 sell 属于 P6；P5 不伪造履约完成。
- 买家只可取消所有子订单仍为 `pending` 的完整 batch；取消按确定性顺序调用 P4 release primitive，原子变更 batch/suborders 并写事件。同键重试稳定；已取消不可重复改变，已进入履约的 batch 不可由买家取消。
- P5 只保存合成配送引用，不建立真实地址簿。真实收件资料、留存期限和隐私流程必须在 P7 发布 Gate 单独批准。

## 3. 最小数据合同

- `carts`：owner、status、version、created/updated；用户唯一 active cart。
- `cart_items`：cart/listing、quantity、version；不存权威价格或库存，不重复保存商品正文。
- `order_batches`：buyer、currency、subtotal/total、status、synthetic delivery reference、cart/version 与 created/cancelled 时间。
- `merchant_orders`：batch、merchant organization/store、金额、status/version；每个 batch/store 唯一。
- `order_items`：batch/suborder/listing、product/variant、product kind、数量、audience、unit/line amount、price/listing/inventory version，以及有限 title/SKU 快照。
- `order_events`：batch/suborder、actor、有限 event/reason、from/to status、version、idempotency key；append-only，无自由文本。
- `p5_idempotency_keys`：actor-global key、operation/fingerprint、cart/order 引用及原始稳定结果；同 actor/key 跨操作冲突 fail closed。

## 4. RPC、身份与 RLS

- 公开读 RPC：扩展 P4 catalog 为有限 search/category/page DTO，并对当前调用者返回适用 quote；不得暴露 wholesale 规则、内部库存或商家私有字段。
- 登录 RPC：`get_my_cart`、`put_cart_item`、`remove_cart_item`、`checkout_cart`、`list_my_orders`、`get_my_order`、`cancel_my_order_batch`。写操作使用 recent email-OTP identity 与 UUID idempotency key。
- public wrapper 保持 SECURITY INVOKER；private implementation 保持 SECURITY DEFINER、空 search path、全限定对象和 `rebuy_business_executor` owner。每次调用双向清理 P2/P3/P4/P5 request context。
- 所有新表 ENABLE + FORCE RLS；anon/authenticated/service_role 无直接内部表 DML。买家只能通过受控 DTO/RPC 读取自己的 cart/order；其他买家、商家和 platform support 在 P5 均无订单私有读取权限。
- P5 private checkout/cancel 可获得调用 P4 private reservation primitive 的最小内部能力，但不向外部角色公开该 primitive，也不扩大 shared table ACL。

## 5. 事务、幂等与并发

- cart mutation 锁 active cart、校验 expected cart/item version，并使用 actor-global key；旧 key 在当前权限和 listing 可见性重验后返回原结果。
- checkout 锁 actor/key 与 active cart；listing IDs 排序后逐项重新报价并锁库存。多商家拆分完全由服务端基于 listing 当前 organization/store 生成。
- 两个相同 checkout key 只能得到同一 batch/子订单集合；两个不同 key 针对同一 cart 只能一个成功，loser 为有限 cart/order state/version 错误，不能重复下单或预留。
- standard 多商品预留遵守总量和 expected version；secondhand 并发只有一个订单成功。所有失败不得留下部分 batch、子订单、item、event、key、cart clear 或 reservation。
- cancel 锁 batch、suborders 和 inventory targets，按 listing ID 排序释放；中途注入失败必须回滚全部状态与释放。

## 6. 买家 UI 合同

- 首页/目录提供真实公开 catalog 列表、搜索和分类过滤；商品卡展示服务端适用单价、MOQ/可购状态，不提供零售/批发切换按钮。
- `/cart` 展示当前重新报价、数量编辑、移除和失效原因；未登录操作跳转 `/account/login?next=/cart`。
- `/checkout` 仅收集合成配送引用并展示按商家拆分的小计；提交按钮具备 pending/重复点击保护和有限错误恢复。
- `/account/orders` 与订单详情只展示当前用户的 batch/suborders/items/events 最小 DTO；取消需明确确认，成功后显示库存已释放状态。
- 必须验证 desktop/mobile、键盘提交、刷新/后退、双击提交、登录回跳、空/失效购物车和订单越权路径。

## 7. 验收矩阵

- browse/price：guest、retail、active/suspended/expired/revoked wholesale；query/category/page 边界、inactive/zero-stock 不可购、无 wholesale/internal stock 泄露。
- cart：创建/读取/加减/删除、standard/secondhand 数量、跨商家、版本冲突、同键重试、失效 listing、跨用户不可见。
- checkout：单/多商家拆分、价格重算、资格变化、库存变化、同键/不同键并发、standard 不超卖、secondhand 唯一、mid-checkout rollback、cart clear exactly once、event exactly once。
- orders/cancel：own list/detail、cross-user deny、金额与快照、全 batch 原子取消/释放、重复取消、已履约拒绝、mid-release rollback。
- security/audit：FORCE RLS、effective table/column/function ACL、direct parity、executor membership/owner、request context reset、有限错误与无真实 PII。
- UI：真实 local Auth + catalog/cart/checkout/orders 浏览器路径、键盘/mobile/重复提交与 no-console-error；不以静态 mock 冒充后端成功。
- quality：fresh reset、P2–P4 全回归、P5 pgTAP/双连接 concurrency、strict lint/advisors/migration list、Auth/structure/typecheck/ESLint/Next build、浏览器 E2E、diff check、脱敏 manifests 与 final independent review。

## 8. 运行、停止与回退

- 唯一本地 project=`rebuy-g2-a1-e2a-local-email-otp-exec`，端口=`127.0.0.1:55320–55329`；每个 bounded packet 从空资源开始，以 exact stop/no-backup 和零 containers/volumes/network/listeners 结束。
- runtime 前先通过 structure/syntax/quality 与独立只读审查；任一失败立即停止并清理。最多三次实质失败，达到上限转专项审查。
- order 写入问题时关闭 checkout/cancel 写入口，保留只读 catalog/order 查询与 append-only 证据；不删除订单或库存历史，不手工伪造成功状态。
- 完整 runtime 与 final independent GO 前不得关闭 P5 或打开 P6；hosted/Production、真实 PII、支付/物流/税务、main push/merge/deploy 继续关闭。

## 9. Exit 决定（2026-09-03）

- source commit=`bc8195929c58caf68173c1b4e2b1231a066b117d`，evidence commit=`a0c449a2905b7f13c7c812baca3c3833cb27274d`。
- attempt #4 recovery 从空资源完成八份 pgTAP `446/446`、五套并发/竞态、strict lint/advisors、migration list、Auth/structure/typecheck/ESLint/Next build、十条浏览器业务路径与完整 cleanup；candidate/evidence manifests 分别 `25/25`、`15/15`。
- independent reviewer 给出 `FINAL GO / P0=0 / P1=0 / P2=0`。P5 synthetic-only local Exit 正式关闭，P6 synthetic-only local Entry 打开。
- 运行证据见 [attempt #4 recovery](../evidence/P5/2026-09-03-runtime-attempt-4-recovery-pass/README.md)，终审见 [final independent review](../evidence/P5/2026-09-03-final-independent-review/REVIEW.md)。本决定不证明 hosted/Production，也不开放真实 PII、支付/物流、main push/merge 或部署。
