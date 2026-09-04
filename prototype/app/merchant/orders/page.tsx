import { ChevronRight, ClipboardList } from 'lucide-react'
import Link from 'next/link'
import { redirect } from 'next/navigation'
import MerchantShell from '@/components/MerchantShell'
import { loadMerchantOrders, requireMerchantContext } from '@/lib/merchant/server'
import { formatEuro } from '@/lib/shop/types'
import styles from '../merchant.module.css'

export const dynamic = 'force-dynamic'

const statusCopy: Record<string, string> = { pending: '待接单', accepted: '待发货', shipped: '运输中', completed: '已完成', rejected: '已拒绝', cancelled: '已取消' }
const statusClass: Record<string, string> = { pending: styles.statusWarn, accepted: styles.statusWarn, shipped: styles.statusGood, completed: styles.statusGood, rejected: styles.statusDanger, cancelled: styles.statusDanger }
function oneParam(value: string | string[] | undefined) { return typeof value === 'string' ? value : undefined }
function dateTime(value: string) { return new Intl.DateTimeFormat('zh-CN', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)) }

export default async function MerchantOrdersPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const query = await searchParams
  const { context, contexts } = await requireMerchantContext('/merchant/orders', oneParam(query.store))
  if (!context.can_fulfill) redirect(`/merchant?store=${context.store_id}`)
  const orders = await loadMerchantOrders(context.store_id)

  return (
    <MerchantShell context={context} contexts={contexts} currentPath="/merchant/orders" eyebrow="Order fulfillment" title="订单履约" description="每个商家只处理自己的子订单；状态推进会同步聚合买家订单并更新库存。">
      {orders.length === 0 ? <section className={`${styles.panel} ${styles.empty}`}><ClipboardList size={28} /><h2>暂无订单</h2><p>买家提交包含本店商品的订单后会出现在这里。</p></section> : <section className={styles.stack}>
        {orders.map((order) => <Link className={`${styles.panel} ${styles.quickLink}`} href={`/merchant/orders/${order.merchant_order_id}?store=${encodeURIComponent(context.store_id)}`} key={order.merchant_order_id}>
          <div className={styles.panelHeader}>
            <div><p className={styles.eyebrow}>{dateTime(order.created_at)}</p><h2>{order.synthetic_order_reference}</h2><p>{order.item_count} 件商品 · 库存 {order.inventory_status}</p></div>
            <div><strong className={styles.orderTotal}>{formatEuro(order.total_cents)}</strong><br /><span className={`${styles.status} ${statusClass[order.order_status] ?? ''}`}>{statusCopy[order.order_status] ?? order.order_status}</span></div>
          </div>
          <span className={styles.muted}>子订单 v{order.order_version} <ChevronRight size={14} /></span>
        </Link>)}
      </section>}
    </MerchantShell>
  )
}
