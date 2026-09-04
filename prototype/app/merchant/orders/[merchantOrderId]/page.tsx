import { ArrowLeft, Check, PackageCheck, RotateCcw, Truck, X } from 'lucide-react'
import Link from 'next/link'
import { notFound, redirect } from 'next/navigation'
import MerchantShell from '@/components/MerchantShell'
import SubmitButton from '@/components/SubmitButton'
import { advanceMerchantOrderAction, openMerchantAfterSaleAction } from '@/app/merchant/actions'
import { loadMerchantOrder, requireMerchantContext } from '@/lib/merchant/server'
import { formatEuro } from '@/lib/shop/types'
import styles from '../../merchant.module.css'

export const dynamic = 'force-dynamic'
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const statusCopy: Record<string, string> = { pending: '待接单', accepted: '待发货', shipped: '运输中', completed: '已完成', rejected: '已拒绝', cancelled: '已取消' }
const eventCopy: Record<string, string> = { 'order.confirmed': '买家已提交并预留库存', 'merchant_order.accepted': '商家已接单', 'merchant_order.rejected': '商家已拒单并释放库存', 'merchant_order.shipped': '商家已登记发货', 'merchant_order.completed': '商家已确认完成并核销库存', 'order.cancelled': '买家已取消订单' }
const noticeCopy: Record<string, string> = {
  'order-accepted': '已接单，订单进入待发货状态。', 'order-rejected': '已拒单并原子释放库存。', 'order-shipped': '已记录合成物流编号。', 'order-completed': '订单已完成，预留库存已核销。',
  'after-sale-opened': '售后记录已创建。', 'invalid-request': '操作参数不完整。', changed: '订单版本已变化，请刷新后重试。', 'state-changed': '订单状态已变化，当前操作不再适用。', 'request-conflict': '重复请求内容不一致。', 'try-again': '操作失败，事务已回滚。',
}
function oneParam(value: string | string[] | undefined) { return typeof value === 'string' ? value : undefined }
function dateTime(value: string) { return new Intl.DateTimeFormat('zh-CN', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)) }

export default async function MerchantOrderDetailPage({ params, searchParams }: { params: Promise<{ merchantOrderId: string }>, searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const [{ merchantOrderId }, query] = await Promise.all([params, searchParams])
  if (!uuidPattern.test(merchantOrderId)) notFound()
  const requestedStore = oneParam(query.store)
  const { context, contexts } = await requireMerchantContext(`/merchant/orders/${merchantOrderId}`, requestedStore)
  if (!context.can_fulfill) redirect(`/merchant?store=${context.store_id}`)
  const rows = await loadMerchantOrder(context.store_id, merchantOrderId)
  if (rows.length === 0) notFound()
  const order = rows[0]
  const events = Array.isArray(order.event_codes) ? order.event_codes : []
  const notice = oneParam(query.notice) ?? ''

  return (
    <MerchantShell context={context} contexts={contexts} currentPath="/merchant/orders" eyebrow="Merchant order" title={order.synthetic_order_reference} description="状态只能沿允许路径推进；拒单、完成会同步释放或核销库存。">
      <div className={styles.sectionBar}><Link className={styles.secondaryButton} href={`/merchant/orders?store=${context.store_id}`}><ArrowLeft size={15} />返回订单</Link><span className={`${styles.status} ${['completed', 'shipped'].includes(order.order_status) ? styles.statusGood : styles.statusWarn}`}>{statusCopy[order.order_status]}</span></div>
      {noticeCopy[notice] ? <p className={styles.notice} role="status">{noticeCopy[notice]}</p> : null}
      <div className={styles.twoColumn}>
        <section className={styles.stack}>
          <article className={styles.panel}>
            <div className={styles.panelHeader}><div><h2>商品明细</h2><p>商家子订单 {order.merchant_order_id}</p></div><strong className={styles.orderTotal}>{formatEuro(order.total_cents)}</strong></div>
            <div className={styles.stack}>{rows.map((item) => <div className={styles.panelHeader} key={item.listing_id}><div><h3>{item.title_snapshot}</h3><p>{item.sku_snapshot} · {item.quantity} 件 · {item.audience === 'wholesale' ? '批发价' : '零售价'}</p></div><div><strong>{formatEuro(item.line_amount_cents)}</strong><p>库存 {item.item_inventory_status}</p></div></div>)}</div>
            <div className={styles.orderMeta}><span>状态：{statusCopy[order.order_status]}</span><span>库存：{order.inventory_status}</span><span>版本：v{order.order_version}</span>{order.synthetic_shipment_reference ? <span className={styles.code}>{order.synthetic_shipment_reference}</span> : null}</div>
          </article>
          <article className={styles.panel}>
            <div className={styles.panelHeader}><div><h2>履约操作</h2><p>每次提交都带独立幂等键与预期版本。</p></div></div>
            <div className={styles.actions}>
              {order.order_status === 'pending' ? <>
                <form action={advanceMerchantOrderAction}><input type="hidden" name="store_id" value={context.store_id} /><input type="hidden" name="merchant_order_id" value={order.merchant_order_id} /><input type="hidden" name="expected_version" value={order.order_version} /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} /><input type="hidden" name="order_action" value="accept" /><SubmitButton className={styles.primaryButton} pendingLabel="接单中…"><Check size={15} />接单</SubmitButton></form>
                <form className={styles.inlineForm} action={advanceMerchantOrderAction}><input type="hidden" name="store_id" value={context.store_id} /><input type="hidden" name="merchant_order_id" value={order.merchant_order_id} /><input type="hidden" name="expected_version" value={order.order_version} /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} /><input type="hidden" name="order_action" value="reject" /><label className={styles.field}>拒单原因<select name="reason_code" defaultValue="out_of_stock"><option value="out_of_stock">缺货</option><option value="listing_issue">商品信息异常</option></select></label><SubmitButton className={styles.dangerButton} pendingLabel="拒单中…"><X size={15} />拒单</SubmitButton></form>
              </> : null}
              {order.order_status === 'accepted' ? <form className={styles.inlineForm} action={advanceMerchantOrderAction}><input type="hidden" name="store_id" value={context.store_id} /><input type="hidden" name="merchant_order_id" value={order.merchant_order_id} /><input type="hidden" name="expected_version" value={order.order_version} /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} /><input type="hidden" name="order_action" value="ship" /><label className={styles.field}>合成物流编号<input name="synthetic_shipment_reference" required pattern="synthetic://shipment/[a-z0-9](?:[a-z0-9]|_|/|-){2,120}" defaultValue={`synthetic://shipment/${order.merchant_order_id.slice(0, 8)}`} /></label><SubmitButton className={styles.primaryButton} pendingLabel="登记中…"><Truck size={15} />登记发货</SubmitButton></form> : null}
              {order.order_status === 'shipped' ? <form action={advanceMerchantOrderAction}><input type="hidden" name="store_id" value={context.store_id} /><input type="hidden" name="merchant_order_id" value={order.merchant_order_id} /><input type="hidden" name="expected_version" value={order.order_version} /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} /><input type="hidden" name="order_action" value="complete" /><SubmitButton className={styles.primaryButton} pendingLabel="核销中…"><PackageCheck size={15} />确认完成</SubmitButton></form> : null}
              {order.order_status === 'completed' && context.can_after_sale ? <form className={styles.inlineForm} action={openMerchantAfterSaleAction}><input type="hidden" name="store_id" value={context.store_id} /><input type="hidden" name="merchant_order_id" value={order.merchant_order_id} /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} /><label className={styles.field}>售后原因<select name="reason_code"><option value="return_request">退货请求</option><option value="damaged">商品损坏</option><option value="wrong_item">错发商品</option></select></label><SubmitButton className={styles.secondaryButton} pendingLabel="创建中…"><RotateCcw size={15} />创建售后</SubmitButton></form> : null}
              {['rejected', 'cancelled', 'completed'].includes(order.order_status) ? <p className={styles.muted}>当前履约状态没有后续操作。</p> : null}
            </div>
          </article>
        </section>
        <aside className={`${styles.panel} ${styles.timeline}`}>
          <div><h2>订单时间线</h2><p className={styles.muted}>不可变事件记录</p></div>
          {events.map((event) => <div className={styles.timelineItem} key={`${event.event}-${event.created_at}`}><span className={styles.timelineDot} /><div><strong>{eventCopy[event.event] ?? event.event}</strong><br />{dateTime(event.created_at)} · {event.status}</div></div>)}
        </aside>
      </div>
    </MerchantShell>
  )
}
