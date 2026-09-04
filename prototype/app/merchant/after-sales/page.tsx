import { CheckCircle2, SearchCheck, XCircle } from 'lucide-react'
import { redirect } from 'next/navigation'
import MerchantShell from '@/components/MerchantShell'
import SubmitButton from '@/components/SubmitButton'
import { reviewMerchantAfterSaleAction } from '@/app/merchant/actions'
import { loadMerchantAfterSales, requireMerchantContext } from '@/lib/merchant/server'
import styles from '../merchant.module.css'

export const dynamic = 'force-dynamic'
const statusCopy: Record<string, string> = { opened: '待复核', reviewing: '复核中', resolved: '已解决', rejected: '已驳回' }
const reasonCopy: Record<string, string> = { return_request: '退货请求', damaged: '商品损坏', wrong_item: '错发商品' }
const noticeCopy: Record<string, string> = { 'after-sale-start_review': '售后已进入复核。', 'after-sale-resolve': '售后已解决并记录处理结论。', 'after-sale-reject': '售后已驳回。', changed: '售后版本已变化，请刷新后重试。', 'state-changed': '售后状态已变化。', 'invalid-request': '操作参数不完整。', 'request-conflict': '重复请求内容不一致。', 'try-again': '操作失败，事务已回滚。' }
function oneParam(value: string | string[] | undefined) { return typeof value === 'string' ? value : undefined }

export default async function MerchantAfterSalesPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const query = await searchParams
  const { context, contexts } = await requireMerchantContext('/merchant/after-sales', oneParam(query.store))
  if (!context.can_after_sale) redirect(`/merchant?store=${context.store_id}`)
  const cases = await loadMerchantAfterSales(context.store_id)
  const notice = oneParam(query.notice) ?? ''

  return <MerchantShell context={context} contexts={contexts} currentPath="/merchant/after-sales" eyebrow="After-sale cases" title="售后处理" description="从创建、复核到解决或驳回，每次状态变化都保留原因、版本和操作者。">
    {noticeCopy[notice] ? <p className={styles.notice} role="status">{noticeCopy[notice]}</p> : null}
    <section className={styles.stack}>{cases.length === 0 ? <div className={`${styles.panel} ${styles.empty}`}><h2>暂无售后</h2><p>已完成订单可在订单详情中创建售后记录。</p></div> : cases.map((item) => <article className={styles.panel} key={item.case_id}>
      <div className={styles.panelHeader}><div><p className={styles.eyebrow}>{item.synthetic_order_reference}</p><h2>{reasonCopy[item.reason_code]}</h2><p className={styles.code}>{item.case_id}</p></div><span className={`${styles.status} ${['resolved'].includes(item.case_status) ? styles.statusGood : item.case_status === 'rejected' ? styles.statusDanger : styles.statusWarn}`}>{statusCopy[item.case_status]}</span></div>
      <div className={styles.orderMeta}><span>版本 v{item.case_version}</span><span>结论：{item.resolution_code ?? '尚未记录'}</span></div>
      <div className={styles.actions}>
        {item.case_status === 'opened' ? <form action={reviewMerchantAfterSaleAction}><input type="hidden" name="store_id" value={context.store_id} /><input type="hidden" name="case_id" value={item.case_id} /><input type="hidden" name="case_action" value="start_review" /><input type="hidden" name="expected_version" value={item.case_version} /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} /><SubmitButton className={styles.primaryButton} pendingLabel="开始复核…"><SearchCheck size={15} />开始复核</SubmitButton></form> : null}
        {item.case_status === 'reviewing' ? <>
          <form className={styles.inlineForm} action={reviewMerchantAfterSaleAction}><input type="hidden" name="store_id" value={context.store_id} /><input type="hidden" name="case_id" value={item.case_id} /><input type="hidden" name="case_action" value="resolve" /><input type="hidden" name="expected_version" value={item.case_version} /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} /><label className={styles.field}>处理结论<select name="resolution_code"><option value="replacement_recorded">已记录换货</option><option value="return_recorded">已记录退货</option><option value="no_action_recorded">无需进一步操作</option></select></label><SubmitButton className={styles.primaryButton} pendingLabel="结案中…"><CheckCircle2 size={15} />解决</SubmitButton></form>
          <form action={reviewMerchantAfterSaleAction}><input type="hidden" name="store_id" value={context.store_id} /><input type="hidden" name="case_id" value={item.case_id} /><input type="hidden" name="case_action" value="reject" /><input type="hidden" name="resolution_code" value="request_rejected" /><input type="hidden" name="expected_version" value={item.case_version} /><input type="hidden" name="idempotency_key" value={crypto.randomUUID()} /><SubmitButton className={styles.dangerButton} pendingLabel="驳回中…"><XCircle size={15} />驳回</SubmitButton></form>
        </> : null}
      </div>
    </article>)}</section>
  </MerchantShell>
}
