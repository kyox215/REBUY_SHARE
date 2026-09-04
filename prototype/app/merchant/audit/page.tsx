import { Filter } from 'lucide-react'
import { redirect } from 'next/navigation'
import MerchantShell from '@/components/MerchantShell'
import { loadMerchantAudit, requireMerchantContext } from '@/lib/merchant/server'
import styles from '../merchant.module.css'

export const dynamic = 'force-dynamic'
function oneParam(value: string | string[] | undefined) { return typeof value === 'string' ? value : undefined }
function dateTime(value: string) { return new Intl.DateTimeFormat('zh-CN', { dateStyle: 'short', timeStyle: 'medium' }).format(new Date(value)) }

export default async function MerchantAuditPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const query = await searchParams
  const { context, contexts } = await requireMerchantContext('/merchant/audit', oneParam(query.store))
  if (!context.can_audit) redirect(`/merchant?store=${context.store_id}`)
  const requestedPrefix = oneParam(query.event) ?? ''
  const prefix = /^[a-z_]+(?:[.][a-z_]+)?$/.test(requestedPrefix) ? requestedPrefix : ''
  const requestedEntity = oneParam(query.entity) ?? ''
  const entity = ['merchant_order', 'after_sale', 'listing', 'inventory'].includes(requestedEntity) ? requestedEntity : ''
  const datePattern = /^\d{4}-\d{2}-\d{2}$/
  const from = datePattern.test(oneParam(query.from) ?? '') ? oneParam(query.from) ?? '' : ''
  const to = datePattern.test(oneParam(query.to) ?? '') ? oneParam(query.to) ?? '' : ''
  const allEvents = await loadMerchantAudit(context.store_id, prefix)
  const fromTime = from ? new Date(`${from}T00:00:00Z`).getTime() : Number.NEGATIVE_INFINITY
  const toTime = to ? new Date(`${to}T23:59:59.999Z`).getTime() : Number.POSITIVE_INFINITY
  const events = allEvents.filter((event) => (!entity || event.entity_type === entity)
    && new Date(event.created_at).getTime() >= fromTime
    && new Date(event.created_at).getTime() <= toTime)

  return <MerchantShell context={context} contexts={contexts} currentPath="/merchant/audit" eyebrow="Immutable audit" title="操作审计" description="统一查看商品、定价、库存、订单和售后操作；审计数据只读且按门店隔离。">
    <form className={`${styles.panel} ${styles.inlineForm}`} method="get">
      <input type="hidden" name="store" value={context.store_id} />
      <label className={styles.field}>事件前缀<input name="event" pattern="[a-z_]+([.][a-z_]+)?" placeholder="例如 merchant_order" defaultValue={prefix} /></label>
      <label className={styles.field}>实体<select name="entity" defaultValue={entity}><option value="">全部</option><option value="merchant_order">订单</option><option value="after_sale">售后</option><option value="listing">商品</option><option value="inventory">库存</option></select></label>
      <label className={styles.field}>开始日期<input name="from" type="date" defaultValue={from} /></label>
      <label className={styles.field}>结束日期<input name="to" type="date" defaultValue={to} /></label>
      <button className={styles.secondaryButton} type="submit"><Filter size={14} />筛选</button>
    </form>
    <div className={styles.sectionBar}><div><h2>最近事件</h2><p>最多显示 80 条 · 当前 {events.length} 条</p></div></div>
    <section className={`${styles.panel} ${styles.tableScroll}`}>
      {events.length === 0 ? <div className={styles.empty}><h2>没有匹配事件</h2><p>清空筛选条件后重试。</p></div> : <table className={styles.dataTable}>
        <thead><tr><th>时间</th><th>事件</th><th>实体</th><th>状态</th><th>版本</th><th>原因</th></tr></thead>
        <tbody>{events.map((event, index) => <tr key={`${event.event_code}-${event.entity_id}-${event.created_at}-${index}`}><td>{dateTime(event.created_at)}</td><td><strong>{event.event_code}</strong></td><td>{event.entity_type}<br /><span className={styles.code}>{event.entity_id}</span></td><td>{event.from_status ?? '—'} → {event.to_status}</td><td>{event.from_version ?? '—'} → {event.to_version}</td><td>{event.reason_code}</td></tr>)}</tbody>
      </table>}
    </section>
  </MerchantShell>
}
