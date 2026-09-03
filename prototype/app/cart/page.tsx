import { ArrowRight, Package, Trash2 } from 'lucide-react'
import Link from 'next/link'
import StorefrontHeader from '@/components/StorefrontHeader'
import SubmitButton from '@/components/SubmitButton'
import { putCartItemAction, removeCartItemAction } from '@/app/shop-actions'
import { loadCart, requireBuyerPage } from '@/lib/shop/server'
import { formatEuro, itemCount } from '@/lib/shop/types'
import styles from '@/app/shop.module.css'

export const dynamic = 'force-dynamic'

const noticeCopy: Record<string, string> = {
  'cart-updated': '购物车已更新，价格与可购数量已重新获取。',
  'item-removed': '商品已从购物车移除。',
  changed: '购物车已在其他页面更新，请基于当前版本重试。',
  unavailable: '商品或库存已发生变化，请调整购物车。',
  'login-expired': '安全验证已过期，请重新登录。',
  'invalid-request': '请求无效，请刷新后重试。',
  'request-conflict': '重复请求内容不一致，请刷新后重试。',
  'try-again': '操作暂时失败，请稍后重试。',
}

function oneParam(value: string | string[] | undefined) {
  return typeof value === 'string' ? value : ''
}

export default async function CartPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>
}) {
  await requireBuyerPage('/cart')
  const [rows, params] = await Promise.all([loadCart(), searchParams])
  const items = rows.filter((row) => row.listing_id && row.item_id)
  const cartVersion = rows[0]?.cart_version
  const valid = items.length > 0 && items.every((row) => row.purchasable && !row.invalid_reason)
  const total = items.reduce((sum, row) => sum + (row.unit_amount_cents ?? 0) * (row.quantity ?? 0), 0)
  const notice = oneParam(params.notice)

  return (
    <div className={styles.page}>
      <StorefrontHeader cartCount={itemCount(rows)} authenticated />
      <main className={styles.main}>
        <div className={styles.sectionHeading}>
          <div><p className={styles.eyebrow}>实时重新报价</p><h1>购物车</h1></div>
          <Link href="/" className={styles.secondaryButton}>继续购物</Link>
        </div>
        {noticeCopy[notice] ? <p className={styles.notice} role="status">{noticeCopy[notice]}</p> : null}
        {items.length === 0 ? (
          <div className={styles.empty}>
            <Package size={30} aria-hidden="true" />
            <h3>购物车还是空的</h3>
            <p>先从公开目录选择商品。</p>
            <Link href="/" className={styles.primaryButton}>去浏览商品</Link>
          </div>
        ) : (
          <div className={styles.contentGrid}>
            <section className={`${styles.panel} ${styles.stack}`} aria-label="购物车商品">
              {items.map((row) => {
                const max = Math.min(1_000_000, row.available_quantity ?? 1)
                const minimum = row.minimum_quantity ?? 1
                const recoverable = row.unit_amount_cents !== null
                  && row.available_quantity !== null
                  && max >= minimum
                const suggestedQuantity = Math.min(max, Math.max(minimum, row.quantity ?? minimum))
                return (
                  <article className={styles.cartItem} key={row.listing_id}>
                    <div>
                      <p>{row.store_name ?? '商品暂不可用'}</p>
                      <h3>{row.title ?? row.listing_id}</h3>
                      <p>{row.audience === 'wholesale' ? '已认证批发价' : '零售价'} · {row.unit_amount_cents ? formatEuro(row.unit_amount_cents) : '等待重新报价'}</p>
                      <div className={styles.cartFacts}>
                        <span>{row.product_kind === 'secondhand' ? '单件二手' : '标准商品'}</span>
                        <span>可购 {row.available_quantity ?? 0}</span>
                        <span>起订 {row.minimum_quantity ?? 1}</span>
                      </div>
                      {row.invalid_reason ? <p className={styles.invalid}>当前不可结算：商品、价格或库存已变化。</p> : null}
                    </div>
                    <div className={styles.cartActions}>
                      <form action={putCartItemAction}>
                        <input type="hidden" name="listing_id" value={row.listing_id ?? ''} />
                        <input type="hidden" name="cart_version" value={cartVersion ?? ''} />
                        <input type="hidden" name="item_version" value={row.item_version ?? ''} />
                        <input type="hidden" name="idempotency_key" value={crypto.randomUUID()} />
                        <input type="hidden" name="return_to" value="/cart" />
                        <label>数量<input className={styles.quantityInput} type="number" name="quantity" min={minimum} max={max} defaultValue={suggestedQuantity} readOnly={row.product_kind === 'secondhand'} disabled={!recoverable} /></label>
                        <SubmitButton className={styles.secondaryButton} pendingLabel="更新中…" disabled={!recoverable}>更新</SubmitButton>
                      </form>
                      <form action={removeCartItemAction}>
                        <input type="hidden" name="listing_id" value={row.listing_id ?? ''} />
                        <input type="hidden" name="cart_version" value={cartVersion ?? ''} />
                        <input type="hidden" name="item_version" value={row.item_version ?? ''} />
                        <input type="hidden" name="idempotency_key" value={crypto.randomUUID()} />
                        <SubmitButton className={styles.dangerButton} pendingLabel="移除中…"><Trash2 size={16} aria-hidden="true" />移除</SubmitButton>
                      </form>
                    </div>
                  </article>
                )
              })}
            </section>
            <aside className={`${styles.panel} ${styles.summary}`}>
              <h2>订单摘要</h2>
              <div className={styles.summaryRows}>
                <div className={styles.summaryRow}><span>商品数量</span><strong>{itemCount(rows)}</strong></div>
                <div className={styles.summaryRow}><span>配送 / 税费 / 优惠</span><strong>€0.00</strong></div>
                <div className={`${styles.summaryRow} ${styles.summaryTotal}`}><span>服务端当前合计</span><strong>{formatEuro(total)}</strong></div>
              </div>
              {valid && cartVersion ? <Link href="/checkout" className={styles.primaryButton}>继续结算<ArrowRight size={17} aria-hidden="true" /></Link> : <button className={styles.primaryButton} disabled>请先处理失效商品</button>}
            </aside>
          </div>
        )}
      </main>
    </div>
  )
}
