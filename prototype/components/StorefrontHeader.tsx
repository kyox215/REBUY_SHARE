import { ClipboardList, ShoppingCart, UserRound } from 'lucide-react'
import Link from 'next/link'
import BrandMark from '@/components/BrandMark'
import styles from '@/app/shop.module.css'

export default function StorefrontHeader({
  cartCount = 0,
  authenticated = false,
}: {
  cartCount?: number
  authenticated?: boolean
}) {
  return (
    <header className={styles.header}>
      <div className={styles.headerInner}>
        <Link href="/" className={styles.brandLink} aria-label="Rebuy 首页">
          <BrandMark />
        </Link>
        <nav className={styles.headerNav} aria-label="买家导航">
          <Link href="/account/orders">
            <ClipboardList size={18} aria-hidden="true" />
            <span>订单</span>
          </Link>
          <Link href="/cart" className={styles.cartLink}>
            <ShoppingCart size={18} aria-hidden="true" />
            <span>购物车</span>
            {cartCount > 0 ? <strong>{cartCount > 99 ? '99+' : cartCount}</strong> : null}
          </Link>
          <Link href={authenticated ? '/account' : '/account/login?next=%2F'}>
            <UserRound size={18} aria-hidden="true" />
            <span>{authenticated ? '账号' : '登录'}</span>
          </Link>
        </nav>
      </div>
    </header>
  )
}
