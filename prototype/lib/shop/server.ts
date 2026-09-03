import 'server-only'

import { headers } from 'next/headers'
import { redirect } from 'next/navigation'
import { getAuthRuntimeModeForHost } from '@/lib/auth/runtime-mode'
import { resolveSessionStatus } from '@/lib/auth/session'
import { createClient } from '@/lib/supabase/server'
import type { CatalogListing, CartRow, OrderDetailRow, OrderSummary } from './types'

export async function getShopRuntimeMode() {
  const requestHeaders = await headers()
  return getAuthRuntimeModeForHost(requestHeaders.get('host'))
}

export async function getBuyerSessionStatus() {
  return resolveSessionStatus({
    getClaims: async () => {
      const supabase = await createClient()
      return supabase.auth.getClaims()
    },
  })
}

export async function requireBuyerPage(nextPath: string) {
  const mode = await getShopRuntimeMode()
  if (mode !== 'local-auth') {
    redirect(`/account/login?next=${encodeURIComponent(nextPath)}`)
  }
  const session = await getBuyerSessionStatus()
  if (session.status !== 'authenticated') {
    redirect(`/account/login?next=${encodeURIComponent(nextPath)}`)
  }
  return session
}

export async function loadCatalog(query = '', category = '') {
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('search_catalog', {
    p_query: query || null,
    p_category_slug: category || null,
    p_limit: 48,
    p_offset: 0,
  })
  if (error) throw new Error('catalog_unavailable')
  return (data ?? []) as CatalogListing[]
}

export async function loadCart() {
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('get_my_cart')
  if (error) throw new Error('cart_unavailable')
  return (data ?? []) as CartRow[]
}

export async function loadOrders() {
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('list_my_orders')
  if (error) throw new Error('orders_unavailable')
  return (data ?? []) as OrderSummary[]
}

export async function loadOrder(batchId: string) {
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('get_my_order', {
    p_batch_id: batchId,
  })
  if (error) throw new Error('order_unavailable')
  return (data ?? []) as OrderDetailRow[]
}
