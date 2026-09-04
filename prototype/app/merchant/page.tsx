import { ArrowRight, Boxes, ClipboardList, PackageSearch, RotateCcw } from 'lucide-react'
import Link from 'next/link'
import MerchantShell from '@/components/MerchantShell'
import { loadMerchantDashboard, requireMerchantContext } from '@/lib/merchant/server'
import styles from './merchant.module.css'

export const dynamic = 'force-dynamic'

function oneParam(value: string | string[] | undefined) {
  return typeof value === 'string' ? value : undefined
}

export default async function MerchantDashboardPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>
}) {
  const query = await searchParams
  const requestedStore = oneParam(query.store)
  const { context, contexts } = await requireMerchantContext('/merchant', requestedStore)
  const dashboard = await loadMerchantDashboard(context.store_id)
  if (!dashboard) throw new Error('merchant_dashboard_unavailable')
  const store = encodeURIComponent(context.store_id)

  const metrics = [
    ['在售商品', dashboard.active_listing_count, '当前公开可售'],
    ['低库存', dashboard.low_stock_count, '可用量不超过 5'],
    ['待履约', dashboard.pending_order_count, '待接单或待发货'],
    ['进行中售后', dashboard.active_after_sale_count, '待复核或待结案'],
    ['近 7 日操作', dashboard.recent_operation_count, '可审计业务动作'],
  ] as const

  return (
    <MerchantShell context={context} contexts={contexts} currentPath="/merchant" eyebrow="Merchant operations" title="经营概览" description="从商品上架到订单履约、售后与审计的单店经营视图。">
      <section className={styles.metricGrid} aria-label="经营指标">
        {metrics.map(([label, value, hint]) => (
          <article className={styles.metric} key={label}><span>{label}</span><strong>{value}</strong><small>{hint}</small></article>
        ))}
      </section>
      <div className={styles.sectionBar}><div><h2>常用工作流</h2><p>仅显示当前角色已获授权的入口</p></div></div>
      <section className={styles.quickGrid}>
        {context.can_catalog ? <Link className={`${styles.panel} ${styles.quickLink}`} href={`/merchant/products?store=${store}`}><PackageSearch size={21} /><h2>维护商品</h2><p>新增、改价、发布或下架商品。</p><ArrowRight size={16} /></Link> : null}
        {context.can_inventory ? <Link className={`${styles.panel} ${styles.quickLink}`} href={`/merchant/inventory?store=${store}`}><Boxes size={21} /><h2>调整库存</h2><p>基于版本号安全增减现货。</p><ArrowRight size={16} /></Link> : null}
        {context.can_fulfill ? <Link className={`${styles.panel} ${styles.quickLink}`} href={`/merchant/orders?store=${store}`}><ClipboardList size={21} /><h2>处理订单</h2><p>接单、拒单、发货并确认完成。</p><ArrowRight size={16} /></Link> : null}
        {context.can_after_sale ? <Link className={`${styles.panel} ${styles.quickLink}`} href={`/merchant/after-sales?store=${store}`}><RotateCcw size={21} /><h2>处理售后</h2><p>复核并记录售后处理结论。</p><ArrowRight size={16} /></Link> : null}
      </section>
    </MerchantShell>
  )
}
