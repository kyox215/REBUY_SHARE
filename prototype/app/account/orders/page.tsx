import { ChevronRight, ClipboardList } from 'lucide-react'
import Link from 'next/link'
import StorefrontHeader from '@/components/StorefrontHeader'
import { loadOrders, requireBuyerPage } from '@/lib/shop/server'
import { formatEuro } from '@/lib/shop/types'
import styles from '@/app/shop.module.css'

export const dynamic = 'force-dynamic'

const orderStatusCopy: Record<string, string> = {
  confirmed: '已确认 / 已预留',
  processing: '商家处理中',
  completed: '已完成 / 已核销',
  cancelled: '已取消 / 已释放',
}

export default async function OrdersPage() {
  await requireBuyerPage('/account/orders')
  const orders = await loadOrders()

  return (
    <div className={styles.page}>
      <StorefrontHeader authenticated />
      <main className={styles.main}>
        <div className={styles.sectionHeading}>
          <div><p className={styles.eyebrow}>当前账号私有数据</p><h1>我的订单</h1></div>
          <Link href="/" className={styles.secondaryButton}>继续购物</Link>
        </div>
        {orders.length === 0 ? (
          <div className={styles.empty}><ClipboardList size={30} aria-hidden="true" /><h3>还没有订单</h3><p>成功提交的订单批次会显示在这里。</p><Link href="/" className={styles.primaryButton}>浏览商品</Link></div>
        ) : (
          <section className={`${styles.panel} ${styles.orderList}`} aria-label="订单列表">
            {orders.map((order) => (
              <Link className={styles.orderCard} href={`/account/orders/${order.batch_id}`} key={order.batch_id}>
                <div>
                  <p>{new Intl.DateTimeFormat('zh-CN', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(order.created_at))}</p>
                  <h3>{order.synthetic_order_reference}</h3>
                  <p>{order.merchant_count} 个商家子订单 · {order.item_count} 件商品 · {order.payment_status === 'not_required' ? '无需支付' : order.payment_status}</p>
                </div>
                <div className={styles.orderCardMeta}>
                  <strong>{formatEuro(order.total_cents)}</strong>
                  <span className={`${styles.statusPill} ${order.order_status === 'cancelled' ? styles.statusCancelled : ''}`}>{orderStatusCopy[order.order_status]}</span>
                  <ChevronRight size={18} aria-hidden="true" />
                </div>
              </Link>
            ))}
          </section>
        )}
      </main>
    </div>
  )
}
