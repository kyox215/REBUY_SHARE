import {
  Boxes,
  ClipboardList,
  FileClock,
  Gauge,
  PackageSearch,
  RotateCcw,
  ShoppingBag,
} from 'lucide-react'
import Link from 'next/link'
import type { ReactNode } from 'react'
import type { MerchantContext } from '@/lib/merchant/types'
import styles from '@/app/merchant/merchant.module.css'

type MerchantShellProps = {
  children: ReactNode
  context: MerchantContext
  contexts: MerchantContext[]
  currentPath: string
  eyebrow: string
  title: string
  description: string
}

const navigation = [
  { href: '/merchant', label: '经营概览', icon: Gauge, allowed: () => true },
  { href: '/merchant/products', label: '商品管理', icon: PackageSearch, allowed: (c: MerchantContext) => c.can_catalog },
  { href: '/merchant/inventory', label: '库存管理', icon: Boxes, allowed: (c: MerchantContext) => c.can_inventory },
  { href: '/merchant/orders', label: '订单履约', icon: ClipboardList, allowed: (c: MerchantContext) => c.can_fulfill },
  { href: '/merchant/after-sales', label: '售后处理', icon: RotateCcw, allowed: (c: MerchantContext) => c.can_after_sale },
  { href: '/merchant/audit', label: '操作审计', icon: FileClock, allowed: (c: MerchantContext) => c.can_audit },
]

export default function MerchantShell({
  children,
  context,
  contexts,
  currentPath,
  eyebrow,
  title,
  description,
}: MerchantShellProps) {
  const storeQuery = `store=${encodeURIComponent(context.store_id)}`

  return (
    <div className={`${styles.page} theme-light`}>
      <aside className={styles.sidebar}>
        <Link className={styles.brand} href={`/merchant?${storeQuery}`}>
          <span className={styles.brandMark}><ShoppingBag size={19} aria-hidden="true" /></span>
          <span><strong>Rebuy</strong><small>商家工作台</small></span>
        </Link>
        <div className={styles.storeCard}>
          <span>当前门店</span>
          <strong>{context.store_name}</strong>
          <small>{context.role_key}</small>
        </div>
        {contexts.length > 1 ? (
          <details className={styles.storeSwitch}>
            <summary>切换门店</summary>
            <div>
              {contexts.map((item) => (
                <Link href={`${currentPath}?store=${encodeURIComponent(item.store_id)}`} key={item.store_id}>
                  {item.store_name}
                </Link>
              ))}
            </div>
          </details>
        ) : null}
        <nav className={styles.nav} aria-label="商家工作台导航">
          {navigation.filter((item) => item.allowed(context)).map((item) => {
            const Icon = item.icon
            const active = item.href === '/merchant'
              ? currentPath === item.href
              : currentPath.startsWith(item.href)
            return (
              <Link
                className={active ? styles.navActive : undefined}
                href={`${item.href}?${storeQuery}`}
                key={item.href}
                aria-current={active ? 'page' : undefined}
              >
                <Icon size={17} aria-hidden="true" />{item.label}
              </Link>
            )
          })}
        </nav>
        <Link className={styles.backLink} href="/account">返回买家账户</Link>
      </aside>
      <main className={styles.main}>
        <header className={styles.pageHeader}>
          <div><p className={styles.eyebrow}>{eyebrow}</p><h1>{title}</h1><p>{description}</p></div>
          <span className={styles.securityBadge}>权限已校验</span>
        </header>
        {children}
      </main>
    </div>
  )
}
