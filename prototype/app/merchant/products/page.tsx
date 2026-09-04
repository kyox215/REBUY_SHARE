import { Plus, Save } from 'lucide-react'
import { redirect } from 'next/navigation'
import MerchantShell from '@/components/MerchantShell'
import SubmitButton from '@/components/SubmitButton'
import { upsertMerchantListingAction } from '@/app/merchant/actions'
import { loadMerchantProducts, requireMerchantContext } from '@/lib/merchant/server'
import { formatEuro } from '@/lib/shop/types'
import type { MerchantProduct } from '@/lib/merchant/types'
import styles from '../merchant.module.css'

export const dynamic = 'force-dynamic'

const noticeCopy: Record<string, string> = {
  'product-created': '商品已创建，库存与价格已在同一事务中写入。',
  'product-updated': '商品资料和定价已更新。',
  'invalid-request': '表单内容不完整或格式不正确。',
  changed: '商品版本已变化，请刷新后重试。',
  forbidden: '当前角色没有商品或定价写入权限。',
  'request-conflict': '重复请求的内容不一致，请刷新后重试。',
  'login-expired': '安全验证已过期，请重新登录。',
  'try-again': '保存失败，事务已回滚，请稍后重试。',
}

function oneParam(value: string | string[] | undefined) {
  return typeof value === 'string' ? value : undefined
}

function SharedFields({ product }: { product?: MerchantProduct }) {
  return (
    <div className={styles.formGrid}>
      <label className={styles.field}>分类
        <select name="category_slug" defaultValue={product?.category_slug ?? 'electronics'}>
          <option value="electronics">电子产品</option><option value="phone-accessories">手机配件</option>
          <option value="secondhand">二手交易</option><option value="computers">电脑与配件</option>
        </select>
      </label>
      <label className={styles.field}>内部名称<input name="internal_name" required minLength={2} maxLength={120} defaultValue={product?.internal_name} /></label>
      <label className={styles.field}>SKU<input name="sku" required pattern="SYN-SKU-(?:[A-Z0-9]|-){2,40}" defaultValue={product?.sku ?? 'SYN-SKU-'} /></label>
      <label className={styles.field}>商品链接标识<input name="listing_slug" required pattern="[a-z0-9](?:[a-z0-9]|-){1,63}" defaultValue={product?.listing_slug} /></label>
      <label className={`${styles.field} ${styles.fieldWide}`}>展示标题<input name="title" required minLength={2} maxLength={120} defaultValue={product?.title} /></label>
      <label className={`${styles.field} ${styles.fieldWide}`}>商品摘要<textarea name="summary" required minLength={2} maxLength={240} defaultValue={product?.summary} /></label>
      <label className={styles.field}>零售价（分）<input name="retail_cents" type="number" min="1" required defaultValue={product?.retail_cents} /></label>
      <label className={styles.field}>批发价（分，可空）<input name="wholesale_cents" type="number" min="1" defaultValue={product?.wholesale_cents ?? ''} /></label>
      <label className={styles.field}>批发起订量（可空）<input name="wholesale_minimum" type="number" min="2" defaultValue={product?.wholesale_minimum ?? ''} /></label>
      <label className={styles.field}>阶梯价 JSON<textarea name="wholesale_tiers" defaultValue={JSON.stringify(product?.wholesale_tiers ?? [])} /></label>
      <label className={`${styles.checkbox} ${styles.fieldWide}`}><input name="publish" type="checkbox" defaultChecked={product ? product.listing_status === 'active' : true} />立即公开上架</label>
    </div>
  )
}

function StandardCreateForm({ storeId }: { storeId: string }) {
  return (
    <form className={styles.form} action={upsertMerchantListingAction}>
      <input type="hidden" name="store_id" value={storeId} /><input type="hidden" name="product_kind" value="standard" />
      <input type="hidden" name="expected_version" value="0" /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} />
      <SharedFields />
      <label className={styles.field}>初始库存<input name="initial_stock" type="number" min="0" max="1000000" required defaultValue="1" /></label>
      <SubmitButton className={styles.primaryButton} pendingLabel="正在创建…"><Plus size={15} />创建标准商品</SubmitButton>
    </form>
  )
}

function SecondhandCreateForm({ storeId }: { storeId: string }) {
  return (
    <form className={styles.form} action={upsertMerchantListingAction}>
      <input type="hidden" name="store_id" value={storeId} /><input type="hidden" name="product_kind" value="secondhand" />
      <input type="hidden" name="expected_version" value="0" /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} />
      <SharedFields />
      <div className={styles.formGrid}>
        <label className={styles.field}>合成序列号<input name="synthetic_serial_reference" required pattern="SYN-UNIT-(?:[A-Z0-9]|-){4,40}" defaultValue="SYN-UNIT-" /></label>
        <label className={styles.field}>成色<select name="condition_code" defaultValue="good"><option value="like_new">近新</option><option value="good">良好</option><option value="fair">一般</option></select></label>
        <label className={styles.field}>瑕疵<select name="defect_code" defaultValue="none"><option value="none">无</option><option value="cosmetic_wear">外观磨损</option><option value="screen_mark">屏幕划痕</option><option value="housing_mark">外壳痕迹</option></select></label>
        <label className={styles.field}>电池健康度<input name="battery_health_percent" type="number" min="50" max="100" /></label>
        <label className={styles.field}>保修天数<input name="warranty_days" type="number" min="0" max="730" required defaultValue="30" /></label>
      </div>
      <SubmitButton className={styles.primaryButton} pendingLabel="正在创建…"><Plus size={15} />创建二手商品</SubmitButton>
    </form>
  )
}

export default async function MerchantProductsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const query = await searchParams
  const { context, contexts } = await requireMerchantContext('/merchant/products', oneParam(query.store))
  if (!context.can_catalog || !context.can_pricing) redirect(`/merchant?store=${context.store_id}`)
  const allProducts = await loadMerchantProducts(context.store_id)
  const search = (oneParam(query.q) ?? '').slice(0, 80)
  const normalizedSearch = search.toLocaleLowerCase('zh-CN')
  const products = normalizedSearch
    ? allProducts.filter((product) => [product.title, product.sku, product.internal_name]
      .some((value) => value.toLocaleLowerCase('zh-CN').includes(normalizedSearch)))
    : allProducts
  const notice = oneParam(query.notice) ?? ''

  return (
    <MerchantShell context={context} contexts={contexts} currentPath="/merchant/products" eyebrow="Catalog & pricing" title="商品管理" description="创建标准或二手商品，并在同一写入中维护零售、批发价格与发布状态。">
      {noticeCopy[notice] ? <p className={styles.notice} role="status">{noticeCopy[notice]}</p> : null}
      <form className={`${styles.panel} ${styles.inlineForm}`} method="get">
        <input type="hidden" name="store" value={context.store_id} />
        <label className={styles.field}>搜索商品<input name="q" maxLength={80} placeholder="标题、内部名称或 SKU" defaultValue={search} /></label>
        <button className={styles.secondaryButton} type="submit">搜索</button>
      </form>
      <div className={styles.sectionBar}><div><h2>商品列表</h2><p>{search ? `找到 ${products.length} 件匹配商品` : `共 ${products.length} 件商品`}</p></div></div>
      <div className={styles.twoColumn}>
        <section className={styles.stack} aria-label="现有商品">
          {products.length === 0 ? <div className={`${styles.panel} ${styles.empty}`}><h2>{search ? '没有匹配商品' : '暂无商品'}</h2><p>{search ? '更换关键词或清空搜索。' : '从右侧创建第一件商品。'}</p></div> : products.map((product) => (
            <details className={styles.panel} key={product.listing_id}>
              <summary className={styles.panelHeader}>
                <div><h2>{product.title}</h2><p>{product.sku} · {product.product_kind === 'standard' ? '标准商品' : '一物一码二手商品'}</p></div>
                <div><span className={`${styles.status} ${product.listing_status === 'active' ? styles.statusGood : styles.statusWarn}`}>{product.listing_status}</span><p>{formatEuro(product.retail_cents)} · 可售 {product.available_quantity}</p></div>
              </summary>
              <form className={styles.form} action={upsertMerchantListingAction}>
                <input type="hidden" name="store_id" value={context.store_id} /><input type="hidden" name="listing_id" value={product.listing_id} />
                <input type="hidden" name="product_kind" value={product.product_kind} /><input type="hidden" name="expected_version" value={product.listing_version} />
                <input type="hidden" name="idempotency_key" value={crypto.randomUUID()} />
                <SharedFields product={product} />
                {product.product_kind === 'secondhand' ? <div className={styles.formGrid}>
                  <label className={styles.field}>合成序列号<input name="synthetic_serial_reference" required defaultValue={product.synthetic_serial_reference ?? ''} /></label>
                  <label className={styles.field}>成色<select name="condition_code" defaultValue={product.condition_code ?? 'good'}><option value="like_new">近新</option><option value="good">良好</option><option value="fair">一般</option></select></label>
                  <label className={styles.field}>瑕疵<select name="defect_code" defaultValue={product.defect_code ?? 'none'}><option value="none">无</option><option value="cosmetic_wear">外观磨损</option><option value="screen_mark">屏幕划痕</option><option value="housing_mark">外壳痕迹</option></select></label>
                  <label className={styles.field}>电池健康度<input name="battery_health_percent" type="number" min="50" max="100" defaultValue={product.battery_health_percent ?? ''} /></label>
                  <label className={styles.field}>保修天数<input name="warranty_days" type="number" min="0" max="730" required defaultValue={product.warranty_days ?? 0} /></label>
                </div> : null}
                <SubmitButton className={styles.secondaryButton} pendingLabel="正在保存…"><Save size={15} />保存商品</SubmitButton>
              </form>
            </details>
          ))}
        </section>
        <aside className={styles.stack}>
          <details className={styles.panel} open><summary className={styles.panelHeader}><div><h2>新增标准商品</h2><p>同款多库存商品</p></div></summary><StandardCreateForm storeId={context.store_id} /></details>
          <details className={styles.panel}><summary className={styles.panelHeader}><div><h2>新增二手商品</h2><p>一物一码、成色与瑕疵披露</p></div></summary><SecondhandCreateForm storeId={context.store_id} /></details>
        </aside>
      </div>
    </MerchantShell>
  )
}
