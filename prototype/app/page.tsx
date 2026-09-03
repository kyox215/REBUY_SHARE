import { Package, Search, ShieldCheck, ShoppingCart, Store } from 'lucide-react'
import PrototypeApp from '@/components/PrototypeApp'
import StorefrontHeader from '@/components/StorefrontHeader'
import SubmitButton from '@/components/SubmitButton'
import { putCartItemAction } from '@/app/shop-actions'
import {
  getBuyerSessionStatus,
  getShopRuntimeMode,
  loadCatalog,
  loadCart,
} from '@/lib/shop/server'
import { formatEuro, itemCount, type CartRow } from '@/lib/shop/types'
import styles from './shop.module.css'

export const dynamic = 'force-dynamic'

const categories = [
  ['electronics', '电子产品'],
  ['phone-accessories', '手机配件'],
  ['secondhand', '二手交易'],
  ['computers', '电脑与配件'],
] as const

const noticeCopy: Record<string, string> = {
  'cart-updated': '购物车已按服务端当前价格更新。',
  changed: '购物车刚刚发生变化，请重新操作。',
  unavailable: '该商品当前不可购买或库存不足。',
  'login-expired': '登录验证已过期，请重新登录后再修改购物车。',
  'invalid-request': '请求参数无效，请刷新页面重试。',
  'request-conflict': '重复请求内容不一致，请刷新页面重试。',
  'try-again': '操作暂时失败，请稍后重试。',
}

function oneParam(value: string | string[] | undefined) {
  return typeof value === 'string' ? value : ''
}

export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>
}) {
  const mode = await getShopRuntimeMode()
  if (mode === 'ui-only') return <PrototypeApp />

  const params = await searchParams
  const query = oneParam(params.q).slice(0, 80)
  const category = oneParam(params.category).slice(0, 48)
  const notice = oneParam(params.notice)
  const session = await getBuyerSessionStatus()
  const authenticated = session.status === 'authenticated'
  const [catalog, cartRows] = await Promise.all([
    loadCatalog(query, category),
    authenticated ? loadCart() : Promise.resolve([] as CartRow[]),
  ])
  const cartVersion = cartRows[0]?.cart_version ?? null
  const cartByListing = new Map(
    cartRows.filter((row) => row.listing_id).map((row) => [row.listing_id, row]),
  )

  return (
    <div className={styles.page}>
      <StorefrontHeader cartCount={itemCount(cartRows)} authenticated={authenticated} />
      <main className={styles.main}>
        <section className={styles.hero}>
          <div>
            <p className={styles.eyebrow}>可验证的本地交易闭环</p>
            <h1>从多家店铺找到合适的商品</h1>
            <p>价格、批发资格与库存都由服务端实时判定；客户端不能切换身份或覆盖金额。</p>
          </div>
          <div className={styles.trustCard}>
            <ShieldCheck size={24} aria-hidden="true" />
            <div><strong>当前为合成数据环境</strong><span>不触发真实支付、配送或外部通知</span></div>
          </div>
        </section>

        <form className={styles.searchBar} action="/" role="search">
          <Search size={19} aria-hidden="true" />
          <input name="q" defaultValue={query} maxLength={80} placeholder="搜索商品、型号或店铺" aria-label="搜索商品" />
          {category ? <input type="hidden" name="category" value={category} /> : null}
          <button type="submit">搜索</button>
        </form>

        <nav className={styles.categories} aria-label="商品分类">
          <a href={query ? `/?q=${encodeURIComponent(query)}` : '/'} className={!category ? styles.activeCategory : undefined}>全部</a>
          {categories.map(([slug, label]) => (
            <a key={slug} href={`/?category=${slug}${query ? `&q=${encodeURIComponent(query)}` : ''}`} className={category === slug ? styles.activeCategory : undefined}>{label}</a>
          ))}
        </nav>

        {noticeCopy[notice] ? <p className={styles.notice} role="status">{noticeCopy[notice]}</p> : null}

        <section className={styles.catalog} aria-labelledby="catalog-title">
          <div className={styles.sectionHeading}>
            <div><p className={styles.eyebrow}>公开目录</p><h2 id="catalog-title">{query ? `“${query}”的结果` : '当前可购买商品'}</h2></div>
            <span>{catalog.length} 件</span>
          </div>
          {catalog.length === 0 ? (
            <div className={styles.empty}><Package size={30} aria-hidden="true" /><h3>没有匹配的可购买商品</h3><p>清除筛选或换一个关键词试试。</p></div>
          ) : (
            <div className={styles.productGrid}>
              {catalog.map((listing) => {
                const cartItem = cartByListing.get(listing.listing_id)
                const max = Math.min(1_000_000, listing.available_quantity)
                const initialQuantity = cartItem?.quantity ?? listing.minimum_quantity
                return (
                  <article className={styles.productCard} key={listing.listing_id}>
                    <div className={`${styles.productVisual} ${listing.product_kind === 'secondhand' ? styles.usedVisual : ''}`}>
                      <Package size={38} aria-hidden="true" />
                      <span>{listing.product_kind === 'secondhand' ? '单件二手' : '全新商品'}</span>
                    </div>
                    <div className={styles.productBody}>
                      <div className={styles.productMeta}><span>{listing.category_slug}</span><span>{listing.available_quantity} 件可购</span></div>
                      <h3>{listing.title}</h3>
                      <p>{listing.summary}</p>
                      <div className={styles.storeLine}><Store size={15} aria-hidden="true" />{listing.store_name}</div>
                      <div className={styles.priceLine}>
                        <strong>{formatEuro(listing.unit_amount_cents)}</strong>
                        <span>{listing.audience === 'wholesale' ? '已认证批发价' : '零售价'}</span>
                      </div>
                      {listing.minimum_quantity > 1 ? <p className={styles.minimum}>起订 {listing.minimum_quantity} 件，数量变化时服务端重算阶梯价</p> : null}
                      <form action={putCartItemAction} className={styles.addForm}>
                        <input type="hidden" name="listing_id" value={listing.listing_id} />
                        <input type="hidden" name="cart_version" value={cartVersion ?? ''} />
                        <input type="hidden" name="item_version" value={cartItem?.item_version ?? ''} />
                        <input type="hidden" name="idempotency_key" value={crypto.randomUUID()} />
                        <input type="hidden" name="return_to" value="/" />
                        <label>
                          <span className={styles.srOnly}>购买数量</span>
                          <input type="number" name="quantity" min={listing.minimum_quantity} max={max} defaultValue={initialQuantity ?? 1} readOnly={listing.product_kind === 'secondhand'} />
                        </label>
                        <SubmitButton className={styles.primaryButton} pendingLabel="正在加入…" disabled={!listing.purchasable || max < listing.minimum_quantity}>
                          <ShoppingCart size={17} aria-hidden="true" />{cartItem ? '更新购物车' : '加入购物车'}
                        </SubmitButton>
                      </form>
                    </div>
                  </article>
                )
              })}
            </div>
          )}
        </section>
      </main>
    </div>
  )
}
