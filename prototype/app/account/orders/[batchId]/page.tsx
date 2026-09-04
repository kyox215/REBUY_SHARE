import { ArrowLeft, CheckCircle2, RotateCcw, Store } from 'lucide-react'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import StorefrontHeader from '@/components/StorefrontHeader'
import SubmitButton from '@/components/SubmitButton'
import { cancelOrderAction } from '@/app/shop-actions'
import { loadOrder, requireBuyerPage } from '@/lib/shop/server'
import { formatEuro } from '@/lib/shop/types'
import styles from '@/app/shop.module.css'

export const dynamic = 'force-dynamic'

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const batchStatusCopy: Record<string, string> = { confirmed: '已确认', processing: '商家处理中', completed: '已完成', cancelled: '已取消' }
const merchantStatusCopy: Record<string, string> = { pending: '待商家处理', accepted: '商家已接单', shipped: '运输中', completed: '已完成', rejected: '商家已拒绝', cancelled: '已取消' }
const inventoryStatusCopy: Record<string, string> = { reserved: '已预留', mixed: '部分核销或释放', sold: '已核销', released: '已释放' }
const eventCopy: Record<string, string> = { 'order.confirmed': '订单已确认并预留库存', 'merchant_order.accepted': '商家已接单', 'merchant_order.rejected': '商家已拒绝并释放库存', 'merchant_order.shipped': '商家已登记发货', 'merchant_order.completed': '订单已完成并核销库存', 'order.cancelled': '订单已取消并释放库存' }
const noticeCopy: Record<string, string> = {
  'order-created': '订单已创建，所有商品库存已在同一事务中预留。',
  'order-cancelled': '订单已取消，全部库存已原子释放。',
  changed: '订单状态已变化，请根据当前状态重试。',
  'cancel-not-allowed': '商家已开始处理或订单不在可取消状态。',
  'login-expired': '安全验证已过期，请重新登录。',
  'request-conflict': '重复请求内容不一致，请刷新后重试。',
  'try-again': '取消暂时失败；事务已回滚，请稍后重试。',
}

function oneParam(value: string | string[] | undefined) {
  return typeof value === 'string' ? value : ''
}

export default async function OrderDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ batchId: string }>
  searchParams: Promise<Record<string, string | string[] | undefined>>
}) {
  const { batchId } = await params
  if (!uuidPattern.test(batchId)) notFound()
  await requireBuyerPage(`/account/orders/${batchId}`)
  const [rows, query] = await Promise.all([loadOrder(batchId), searchParams])
  if (rows.length === 0) notFound()
  const order = rows[0]
  const events = Array.isArray(order.event_codes) ? order.event_codes : []
  const grouped = Map.groupBy(rows, (row) => row.merchant_order_id)
  const notice = oneParam(query.notice)

  return (
    <div className={styles.page}>
      <StorefrontHeader authenticated />
      <main className={styles.main}>
        <div className={styles.sectionHeading}>
          <div><p className={styles.eyebrow}>订单详情</p><h1>{order.synthetic_order_reference}</h1></div>
          <Link href="/account/orders" className={styles.secondaryButton}><ArrowLeft size={16} aria-hidden="true" />返回订单</Link>
        </div>
        {noticeCopy[notice] ? <p className={styles.notice} role="status">{noticeCopy[notice]}</p> : null}
        <div className={styles.contentGrid}>
          <section className={styles.stack} aria-label="商家子订单">
            {[...grouped.values()].map((items) => {
              const merchantOrder = items[0]
              return (
                <article className={styles.panel} key={merchantOrder.merchant_order_id}>
                  <div className={styles.orderHeader}>
                    <div><p><Store size={14} aria-hidden="true" /> 商家子订单</p><h2>{merchantOrder.store_name}</h2><p>{merchantStatusCopy[merchantOrder.merchant_order_status]}</p></div>
                    <strong>{formatEuro(merchantOrder.merchant_subtotal_cents)}</strong>
                  </div>
                  {items.map((item) => (
                    <div className={styles.orderItem} key={item.listing_id}>
                      <div><h3>{item.title_snapshot}</h3><p>{item.sku_snapshot} · {item.audience === 'wholesale' ? '批发价' : '零售价'} · {item.quantity} 件 · 库存{inventoryStatusCopy[item.item_inventory_status]}</p></div>
                      <strong>{formatEuro(item.line_amount_cents)}</strong>
                    </div>
                  ))}
                </article>
              )
            })}
          </section>
          <aside className={styles.stack}>
            <section className={`${styles.panel} ${styles.summary}`}>
              <h2>订单状态</h2>
              <div className={styles.summaryRows}>
                <div className={styles.summaryRow}><span>订单</span><strong>{batchStatusCopy[order.order_status]}</strong></div>
                <div className={styles.summaryRow}><span>库存</span><strong>{inventoryStatusCopy[order.inventory_status]}</strong></div>
                <div className={styles.summaryRow}><span>支付</span><strong>无需支付</strong></div>
                <div className={`${styles.summaryRow} ${styles.summaryTotal}`}><span>合计</span><strong>{formatEuro(order.total_cents)}</strong></div>
              </div>
              {order.order_status === 'confirmed' ? (
                <form action={cancelOrderAction}>
                  <input type="hidden" name="batch_id" value={order.batch_id} />
                  <input type="hidden" name="order_version" value={order.order_version} />
                  <input type="hidden" name="idempotency_key" value={crypto.randomUUID()} />
                  <label className={styles.confirmation}>
                    <input type="checkbox" name="confirm_cancel" value="cancel-entire-order" required />
                    我确认取消整个订单并释放所有商家的预留库存
                  </label>
                  <SubmitButton className={styles.dangerButton} pendingLabel="正在释放全部库存…"><RotateCcw size={16} aria-hidden="true" />取消整个订单</SubmitButton>
                </form>
              ) : null}
            </section>
            <section className={styles.panel}>
              <div className={styles.orderHeader}><div><p className={styles.eyebrow}>不可变事件</p><h2>订单时间线</h2></div><CheckCircle2 size={21} aria-hidden="true" /></div>
              <div className={styles.timeline}>
                {events.map((event) => (
                  <div className={styles.timelineItem} key={`${event.event}-${event.created_at}`}><span className={styles.timelineDot} /><div><strong>{eventCopy[event.event] ?? event.event}</strong><br />{new Intl.DateTimeFormat('zh-CN', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(event.created_at))}</div></div>
                ))}
              </div>
            </section>
          </aside>
        </div>
      </main>
    </div>
  )
}
