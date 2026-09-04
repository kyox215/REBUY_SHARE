import 'server-only'

import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { requireBuyerPage } from '@/lib/shop/server'
import type {
  MerchantAfterSale,
  MerchantAuditEvent,
  MerchantContext,
  MerchantDashboard,
  MerchantInventory,
  MerchantOrderDetail,
  MerchantOrderSummary,
  MerchantProduct,
} from './types'

export async function requireMerchantPage(nextPath: string) {
  return requireBuyerPage(nextPath)
}

export async function loadMerchantContexts() {
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('get_my_merchant_context')
  if (error) throw new Error('merchant_context_unavailable')
  return (data ?? []) as MerchantContext[]
}

export function selectMerchantContext(
  contexts: MerchantContext[],
  requestedStoreId?: string,
) {
  if (contexts.length === 0) return null
  return contexts.find((context) => context.store_id === requestedStoreId) ?? contexts[0]
}

export async function requireMerchantContext(nextPath: string, requestedStoreId?: string) {
  await requireMerchantPage(nextPath)
  const contexts = await loadMerchantContexts()
  const context = selectMerchantContext(contexts, requestedStoreId)
  if (!context) redirect('/merchant/no-access')
  return { context, contexts }
}

async function merchantRpc<T>(name: string, args: Record<string, unknown>) {
  const supabase = await createClient()
  const { data, error } = await supabase.rpc(name, args)
  if (error) throw new Error('merchant_data_unavailable')
  return (data ?? []) as T[]
}

export function loadMerchantDashboard(storeId: string) {
  return merchantRpc<MerchantDashboard>('get_my_merchant_dashboard', { p_store_id: storeId })
    .then((rows) => rows[0] ?? null)
}

export function loadMerchantProducts(storeId: string) {
  return merchantRpc<MerchantProduct>('list_my_merchant_products', { p_store_id: storeId })
}

export function loadMerchantInventory(storeId: string) {
  return merchantRpc<MerchantInventory>('list_my_merchant_inventory', { p_store_id: storeId })
}

export function loadMerchantOrders(storeId: string) {
  return merchantRpc<MerchantOrderSummary>('list_my_merchant_orders', { p_store_id: storeId })
}

export function loadMerchantOrder(storeId: string, merchantOrderId: string) {
  return merchantRpc<MerchantOrderDetail>('get_my_merchant_order', {
    p_store_id: storeId,
    p_merchant_order_id: merchantOrderId,
  })
}

export function loadMerchantAfterSales(storeId: string) {
  return merchantRpc<MerchantAfterSale>('list_my_merchant_after_sales', { p_store_id: storeId })
}

export function loadMerchantAudit(storeId: string, eventPrefix = '') {
  return merchantRpc<MerchantAuditEvent>('list_my_merchant_audit', {
    p_store_id: storeId,
    p_event_prefix: eventPrefix || null,
    p_limit: 80,
  })
}
