import Link from 'next/link'
import { requireMerchantPage } from '@/lib/merchant/server'
import styles from '../merchant.module.css'

export const dynamic = 'force-dynamic'

export default async function MerchantNoAccessPage() {
  await requireMerchantPage('/merchant/no-access')
  return (
    <main className={`${styles.page} theme-light`}>
      <section className={styles.empty}>
        <h1>当前账号没有商家工作台权限</h1>
        <p>需要有效的商家成员身份和 merchant.dashboard.read 权限。</p>
        <Link className={styles.primaryButton} href="/account">返回账户</Link>
      </section>
    </main>
  )
}
