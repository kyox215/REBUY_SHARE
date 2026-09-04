import { ArrowDownUp } from 'lucide-react'
import { redirect } from 'next/navigation'
import MerchantShell from '@/components/MerchantShell'
import SubmitButton from '@/components/SubmitButton'
import { adjustMerchantInventoryAction } from '@/app/merchant/actions'
import { loadMerchantInventory, requireMerchantContext } from '@/lib/merchant/server'
import styles from '../merchant.module.css'

export const dynamic = 'force-dynamic'

const noticeCopy: Record<string, string> = {
  'inventory-updated': '库存已更新并写入不可变库存事件。',
  'invalid-request': '库存调整值必须是非零整数。',
  changed: '库存版本已变化，请刷新后重试。',
  forbidden: '当前角色没有库存调整权限。',
  'request-conflict': '重复请求内容不一致，请刷新后重试。',
  unavailable: '商品库存当前不可调整。',
  'try-again': '库存更新失败，事务已回滚。',
}

function oneParam(value: string | string[] | undefined) { return typeof value === 'string' ? value : undefined }

export default async function MerchantInventoryPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const query = await searchParams
  const { context, contexts } = await requireMerchantContext('/merchant/inventory', oneParam(query.store))
  if (!context.can_inventory) redirect(`/merchant?store=${context.store_id}`)
  const rows = await loadMerchantInventory(context.store_id)
  const notice = oneParam(query.notice) ?? ''

  return (
    <MerchantShell context={context} contexts={contexts} currentPath="/merchant/inventory" eyebrow="Inventory control" title="库存管理" description="所有调整均校验库存版本；预留库存不可被超卖或直接扣减。">
      {noticeCopy[notice] ? <p className={styles.notice} role="status">{noticeCopy[notice]}</p> : null}
      <section className={`${styles.panel} ${styles.tableScroll}`}>
        {rows.length === 0 ? <div className={styles.empty}><h2>暂无库存</h2><p>先创建商品再维护库存。</p></div> : <table className={styles.dataTable}>
          <thead><tr><th>商品</th><th>类型</th><th>在手</th><th>预留</th><th>可用</th><th>版本</th><th>调整</th></tr></thead>
          <tbody>{rows.map((row) => (
            <tr key={row.listing_id}>
              <td><strong>{row.title}</strong><br /><span className={styles.muted}>{row.sku}</span></td>
              <td>{row.inventory_kind === 'standard' ? '标准' : '二手单品'}</td><td>{row.on_hand}</td><td>{row.reserved}</td>
              <td><span className={`${styles.status} ${row.available <= 5 ? styles.statusWarn : styles.statusGood}`}>{row.available}</span></td><td>v{row.inventory_version}</td>
              <td>{row.inventory_kind === 'standard' ? <form className={styles.inlineForm} action={adjustMerchantInventoryAction}>
                <input type="hidden" name="store_id" value={context.store_id} /><input type="hidden" name="listing_id" value={row.listing_id} />
                <input type="hidden" name="expected_version" value={row.inventory_version} /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} />
                <label className={styles.field}><span className="sr-only">库存增减数量</span><input name="quantity_delta" type="number" required defaultValue="1" /></label>
                <label className={styles.field}><span className="sr-only">库存调整原因</span><select name="reason_code" defaultValue="stock_received" required>
                  <option value="stock_received">到货入库</option><option value="stock_correction">库存修正</option><option value="cycle_count">盘点调整</option>
                </select></label>
                <SubmitButton className={styles.secondaryButton} pendingLabel="更新中…"><ArrowDownUp size={14} />提交</SubmitButton>
              </form> : <span className={styles.muted}>随商品状态管理</span>}</td>
            </tr>
          ))}</tbody>
        </table>}
      </section>
    </MerchantShell>
  )
}
