import { LockKeyhole, Store } from 'lucide-react'
import Link from 'next/link'
import StorefrontHeader from '@/components/StorefrontHeader'
import SubmitButton from '@/components/SubmitButton'
import { checkoutCartAction } from '@/app/shop-actions'
import { loadCart, requireBuyerPage } from '@/lib/shop/server'
import { formatEuro, itemCount } from '@/lib/shop/types'
import styles from '@/app/shop.module.css'

export const dynamic = 'force-dynamic'

const noticeCopy: Record<string, string> = {
  'invalid-delivery': '只能填写 synthetic://delivery/... 格式的合成配送引用。',
  changed: '购物车版本已变化，请返回购物车重新确认。',
  unavailable: '商品价格或库存已变化，本次没有创建订单或预留库存。',
  empty: '购物车为空，无法结算。',
  'login-expired': '安全验证已过期，请重新登录后提交。',
  'request-conflict': '重复提交内容不一致，请返回购物车重试。',
  'try-again': '结算暂时失败；本次事务已回滚，请稍后重试。',
}

function oneParam(value: string | string[] | undefined) {
  return typeof value === 'string' ? value : ''
}

export default async function CheckoutPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>
}) {
  await requireBuyerPage('/checkout')
  const [rows, params] = await Promise.all([loadCart(), searchParams])
  const items = rows.filter((row) => row.listing_id && row.item_id)
  const cartVersion = rows[0]?.cart_version
  const valid = items.length > 0 && items.every((row) => row.purchasable && !row.invalid_reason)
  const total = items.reduce((sum, row) => sum + (row.unit_amount_cents ?? 0) * (row.quantity ?? 0), 0)
  const groups = Map.groupBy(items, (row) => row.store_name ?? '商品暂不可用')
  const notice = oneParam(params.notice)

  return (
    <div className={styles.page}>
      <StorefrontHeader cartCount={itemCount(rows)} authenticated />
      <main className={styles.main}>
        <div className={styles.sectionHeading}>
          <div><p className={styles.eyebrow}>最后一次确认</p><h1>结算</h1></div>
          <Link href="/cart" className={styles.secondaryButton}>返回购物车</Link>
        </div>
        {noticeCopy[notice] ? <p className={styles.notice} role="alert">{noticeCopy[notice]}</p> : null}
        <div className={styles.contentGrid}>
          <section className={styles.stack} aria-label="按商家拆分的订单">
            {[...groups.entries()].map(([storeName, storeItems]) => (
              <article className={styles.panel} key={storeName}>
                <div className={styles.orderHeader}><div><p><Store size={14} aria-hidden="true" /> 商家子订单</p><h2>{storeName}</h2></div><strong>{formatEuro(storeItems.reduce((sum, row) => sum + (row.unit_amount_cents ?? 0) * (row.quantity ?? 0), 0))}</strong></div>
                {storeItems.map((row) => <div className={styles.orderItem} key={row.listing_id}><div><h3>{row.title}</h3><p>{row.audience === 'wholesale' ? '批发价' : '零售价'} · {row.quantity} 件</p></div><strong>{formatEuro((row.unit_amount_cents ?? 0) * (row.quantity ?? 0))}</strong></div>)}
              </article>
            ))}
          </section>
          <aside className={`${styles.panel} ${styles.summary}`}>
            <h2>提交订单</h2>
            <div className={styles.summaryRows}>
              <div className={styles.summaryRow}><span>商家</span><strong>{groups.size}</strong></div>
              <div className={styles.summaryRow}><span>支付状态</span><strong>无需支付</strong></div>
              <div className={`${styles.summaryRow} ${styles.summaryTotal}`}><span>合计</span><strong>{formatEuro(total)}</strong></div>
            </div>
            <form action={checkoutCartAction} className={styles.checkoutForm}>
              <input type="hidden" name="cart_version" value={cartVersion ?? ''} />
              <input type="hidden" name="idempotency_key" value={crypto.randomUUID()} />
              <label>合成配送引用<input className={styles.deliveryInput} name="delivery_reference" required pattern={'synthetic://delivery/[a-z0-9][a-z0-9_\\/\\-]{2,120}'} defaultValue="synthetic://delivery/local-pickup" /></label>
              <small><LockKeyhole size={13} aria-hidden="true" /> 仅接受合成引用。提交时会重新核价并原子预留全部库存；任一商品失败则整单回滚。</small>
              <SubmitButton className={styles.primaryButton} pendingLabel="正在核价并预留库存…" disabled={!valid || !cartVersion}>确认提交订单</SubmitButton>
            </form>
          </aside>
        </div>
      </main>
    </div>
  )
}
