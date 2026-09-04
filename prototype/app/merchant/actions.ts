'use server'

import { headers } from 'next/headers'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { getAuthRuntimeModeForHost } from '@/lib/auth/runtime-mode'
import { isAuthRuntimeEnabled } from '@/lib/auth/runtime-mode-core'
import { resolveSessionStatus } from '@/lib/auth/session'
import { createClient } from '@/lib/supabase/server'

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const slugPattern = /^[a-z0-9][a-z0-9-]{1,63}$/
const skuPattern = /^SYN-SKU-[A-Z0-9-]{2,40}$/
const shipmentPattern = /^synthetic:\/\/shipment\/[a-z0-9][a-z0-9/_-]{2,120}$/
const orderNoticeByAction: Record<string, string> = {
  accept: 'order-accepted',
  reject: 'order-rejected',
  ship: 'order-shipped',
  complete: 'order-completed',
}

function text(formData: FormData, key: string) {
  const value = formData.get(key)
  return typeof value === 'string' ? value.trim() : ''
}

function uuid(formData: FormData, key: string, optional = false) {
  const value = text(formData, key)
  if (optional && value === '') return null
  return uuidPattern.test(value) ? value : null
}

function integer(formData: FormData, key: string): number
function integer(formData: FormData, key: string, optional: false, signed?: boolean): number
function integer(formData: FormData, key: string, optional: true, signed?: boolean): number | null
function integer(formData: FormData, key: string, optional = false, signed = false): number | null {
  const value = text(formData, key)
  if (optional && value === '') return null
  const pattern = signed ? /^-?[0-9]+$/ : /^[0-9]+$/
  return pattern.test(value) ? Number(value) : Number.NaN
}

function noticePath(path: string, storeId: string, notice: string) {
  const separator = path.includes('?') ? '&' : '?'
  return `${path}${separator}store=${encodeURIComponent(storeId)}&notice=${encodeURIComponent(notice)}`
}

function mapMerchantError(message: string) {
  if (message.includes('recent_otp_required')) return 'login-expired'
  if (message.includes('scope_forbidden')) return 'forbidden'
  if (message.includes('version_conflict')) return 'changed'
  if (message.includes('state_conflict')) return 'state-changed'
  if (message.includes('idempotency_conflict')) return 'request-conflict'
  if (message.includes('already_exists')) return 'already-exists'
  if (message.includes('not_available')) return 'unavailable'
  if (message.includes('invalid')) return 'invalid-request'
  return 'try-again'
}

async function requireMerchantAction(nextPath: string) {
  const requestHeaders = await headers()
  if (!isAuthRuntimeEnabled(getAuthRuntimeModeForHost(requestHeaders.get('host')))) {
    redirect(`/account/login?next=${encodeURIComponent(nextPath)}`)
  }
  const supabase = await createClient()
  const session = await resolveSessionStatus({ getClaims: () => supabase.auth.getClaims() })
  if (session.status !== 'authenticated') {
    redirect(`/account/login?next=${encodeURIComponent(nextPath)}`)
  }
  return supabase
}

export async function upsertMerchantListingAction(formData: FormData) {
  const storeId = uuid(formData, 'store_id')
  const basePath = '/merchant/products'
  if (!storeId) redirect(`${basePath}?notice=invalid-request`)
  const destination = `${basePath}?store=${encodeURIComponent(storeId)}`
  const supabase = await requireMerchantAction(destination)
  const listingId = uuid(formData, 'listing_id', true)
  const idempotencyKey = uuid(formData, 'idempotency_key')
  const expectedVersion = integer(formData, 'expected_version')
  const productKind = text(formData, 'product_kind')
  const categorySlug = text(formData, 'category_slug').toLowerCase()
  const internalName = text(formData, 'internal_name')
  const sku = text(formData, 'sku').toUpperCase()
  const listingSlug = text(formData, 'listing_slug').toLowerCase()
  const title = text(formData, 'title')
  const summary = text(formData, 'summary')
  const retailCents = integer(formData, 'retail_cents')
  const wholesaleCents = integer(formData, 'wholesale_cents', true)
  const wholesaleMinimum = integer(formData, 'wholesale_minimum', true)
  const initialStock = integer(formData, 'initial_stock', true)
  const publish = formData.get('publish') === 'on'
  const serialReference = text(formData, 'synthetic_serial_reference').toUpperCase() || null
  const conditionCode = text(formData, 'condition_code') || null
  const defectCode = text(formData, 'defect_code') || null
  const batteryHealth = integer(formData, 'battery_health_percent', true)
  const warrantyDays = integer(formData, 'warranty_days', true)
  let wholesaleTiers: Array<{ minimum_quantity: number; unit_amount_cents: number }> = []
  try {
    const parsed: unknown = JSON.parse(text(formData, 'wholesale_tiers') || '[]')
    if (!Array.isArray(parsed) || parsed.length > 8) throw new Error('invalid')
    wholesaleTiers = parsed.map((tier) => {
      if (!tier || typeof tier !== 'object') throw new Error('invalid')
      const record = tier as Record<string, unknown>
      if (!Number.isInteger(record.minimum_quantity)
          || !Number.isInteger(record.unit_amount_cents)) throw new Error('invalid')
      return {
        minimum_quantity: Number(record.minimum_quantity),
        unit_amount_cents: Number(record.unit_amount_cents),
      }
    })
  } catch {
    redirect(noticePath(basePath, storeId, 'invalid-request'))
  }
  const invalid = !idempotencyKey || !Number.isInteger(expectedVersion)
    || expectedVersion < 0 || !['standard', 'secondhand'].includes(productKind)
    || !slugPattern.test(categorySlug) || !slugPattern.test(listingSlug)
    || !skuPattern.test(sku) || internalName.length < 2 || internalName.length > 120
    || title.length < 2 || title.length > 120 || summary.length < 2 || summary.length > 240
    || !Number.isInteger(retailCents) || retailCents <= 0
    || (wholesaleCents !== null && (!Number.isInteger(wholesaleCents) || wholesaleCents <= 0))
    || (wholesaleMinimum !== null && (!Number.isInteger(wholesaleMinimum) || wholesaleMinimum < 2))
    || (productKind === 'standard' && listingId === null
      && (!Number.isInteger(initialStock) || initialStock === null || initialStock < 0))
  if (invalid) redirect(noticePath(basePath, storeId, 'invalid-request'))
  const { error } = await supabase.rpc('upsert_catalog_listing', {
    p_listing_id: listingId,
    p_store_id: storeId,
    p_category_slug: categorySlug,
    p_product_kind: productKind,
    p_internal_name: internalName,
    p_sku: sku,
    p_listing_slug: listingSlug,
    p_title: title,
    p_summary: summary,
    p_retail_cents: retailCents,
    p_wholesale_cents: wholesaleCents,
    p_wholesale_minimum: wholesaleMinimum,
    p_wholesale_tiers: wholesaleTiers,
    p_initial_stock: productKind === 'standard' ? initialStock : null,
    p_synthetic_serial_reference: productKind === 'secondhand' ? serialReference : null,
    p_condition_code: productKind === 'secondhand' ? conditionCode : null,
    p_defect_code: productKind === 'secondhand' ? defectCode : null,
    p_battery_health_percent: productKind === 'secondhand' ? batteryHealth : null,
    p_warranty_days: productKind === 'secondhand' ? warrantyDays : null,
    p_publish: publish,
    p_expected_version: expectedVersion,
    p_idempotency_key: idempotencyKey,
  })
  if (error) redirect(noticePath(basePath, storeId, mapMerchantError(error.message)))
  revalidatePath('/merchant')
  revalidatePath('/merchant/products')
  revalidatePath('/merchant/inventory')
  redirect(noticePath(basePath, storeId, listingId ? 'product-updated' : 'product-created'))
}

export async function adjustMerchantInventoryAction(formData: FormData) {
  const storeId = uuid(formData, 'store_id')
  const listingId = uuid(formData, 'listing_id')
  const idempotencyKey = uuid(formData, 'idempotency_key')
  const expectedVersion = integer(formData, 'expected_version')
  const quantityDelta = integer(formData, 'quantity_delta', false, true)
  const reasonCode = text(formData, 'reason_code')
  const basePath = '/merchant/inventory'
  if (!storeId || !listingId || !idempotencyKey
      || !Number.isInteger(expectedVersion) || expectedVersion < 1
      || !Number.isInteger(quantityDelta) || quantityDelta === 0
      || !['stock_received', 'stock_correction', 'cycle_count'].includes(reasonCode)) {
    redirect(storeId ? noticePath(basePath, storeId, 'invalid-request') : `${basePath}?notice=invalid-request`)
  }
  const supabase = await requireMerchantAction(`${basePath}?store=${storeId}`)
  const { error } = await supabase.rpc('adjust_my_merchant_inventory', {
    p_store_id: storeId,
    p_listing_id: listingId,
    p_quantity_delta: quantityDelta,
    p_reason_code: reasonCode,
    p_expected_version: expectedVersion,
    p_idempotency_key: idempotencyKey,
  })
  if (error) redirect(noticePath(basePath, storeId, mapMerchantError(error.message)))
  revalidatePath('/merchant')
  revalidatePath('/merchant/inventory')
  redirect(noticePath(basePath, storeId, 'inventory-updated'))
}

export async function advanceMerchantOrderAction(formData: FormData) {
  const storeId = uuid(formData, 'store_id')
  const merchantOrderId = uuid(formData, 'merchant_order_id')
  const idempotencyKey = uuid(formData, 'idempotency_key')
  const expectedVersion = integer(formData, 'expected_version')
  const action = text(formData, 'order_action')
  const reasonCode = text(formData, 'reason_code') || null
  const shipmentReference = text(formData, 'synthetic_shipment_reference').toLowerCase() || null
  const basePath = merchantOrderId ? `/merchant/orders/${merchantOrderId}` : '/merchant/orders'
  if (!storeId || !merchantOrderId || !idempotencyKey
      || !Number.isInteger(expectedVersion) || expectedVersion < 1
      || !['accept', 'reject', 'ship', 'complete'].includes(action)
      || (shipmentReference !== null && !shipmentPattern.test(shipmentReference))) {
    redirect(storeId ? noticePath(basePath, storeId, 'invalid-request') : `${basePath}?notice=invalid-request`)
  }
  const supabase = await requireMerchantAction(`${basePath}?store=${storeId}`)
  const { error } = await supabase.rpc('advance_my_merchant_order', {
    p_store_id: storeId,
    p_merchant_order_id: merchantOrderId,
    p_action: action,
    p_reason_code: reasonCode,
    p_synthetic_shipment_reference: shipmentReference,
    p_expected_version: expectedVersion,
    p_idempotency_key: idempotencyKey,
  })
  if (error) redirect(noticePath(basePath, storeId, mapMerchantError(error.message)))
  revalidatePath('/merchant')
  revalidatePath('/merchant/orders')
  revalidatePath(basePath)
  redirect(noticePath(basePath, storeId, orderNoticeByAction[action]))
}

export async function openMerchantAfterSaleAction(formData: FormData) {
  const storeId = uuid(formData, 'store_id')
  const merchantOrderId = uuid(formData, 'merchant_order_id')
  const idempotencyKey = uuid(formData, 'idempotency_key')
  const reasonCode = text(formData, 'reason_code')
  const basePath = merchantOrderId ? `/merchant/orders/${merchantOrderId}` : '/merchant/orders'
  if (!storeId || !merchantOrderId || !idempotencyKey
      || !['return_request', 'damaged', 'wrong_item'].includes(reasonCode)) {
    redirect(storeId ? noticePath(basePath, storeId, 'invalid-request') : `${basePath}?notice=invalid-request`)
  }
  const supabase = await requireMerchantAction(`${basePath}?store=${storeId}`)
  const { error } = await supabase.rpc('open_my_merchant_after_sale', {
    p_store_id: storeId,
    p_merchant_order_id: merchantOrderId,
    p_reason_code: reasonCode,
    p_idempotency_key: idempotencyKey,
  })
  if (error) redirect(noticePath(basePath, storeId, mapMerchantError(error.message)))
  revalidatePath('/merchant/after-sales')
  redirect(noticePath(basePath, storeId, 'after-sale-opened'))
}

export async function reviewMerchantAfterSaleAction(formData: FormData) {
  const storeId = uuid(formData, 'store_id')
  const caseId = uuid(formData, 'case_id')
  const idempotencyKey = uuid(formData, 'idempotency_key')
  const expectedVersion = integer(formData, 'expected_version')
  const action = text(formData, 'case_action')
  const resolutionCode = text(formData, 'resolution_code') || null
  const basePath = '/merchant/after-sales'
  if (!storeId || !caseId || !idempotencyKey
      || !Number.isInteger(expectedVersion) || expectedVersion < 1
      || !['start_review', 'resolve', 'reject'].includes(action)) {
    redirect(storeId ? noticePath(basePath, storeId, 'invalid-request') : `${basePath}?notice=invalid-request`)
  }
  const supabase = await requireMerchantAction(`${basePath}?store=${storeId}`)
  const { error } = await supabase.rpc('review_my_merchant_after_sale', {
    p_store_id: storeId,
    p_case_id: caseId,
    p_action: action,
    p_resolution_code: resolutionCode,
    p_expected_version: expectedVersion,
    p_idempotency_key: idempotencyKey,
  })
  if (error) redirect(noticePath(basePath, storeId, mapMerchantError(error.message)))
  revalidatePath('/merchant/after-sales')
  revalidatePath('/merchant/audit')
  redirect(noticePath(basePath, storeId, `after-sale-${action}`))
}
