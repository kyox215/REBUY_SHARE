'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { headers } from 'next/headers'
import { getAuthRuntimeModeForHost } from '@/lib/auth/runtime-mode'
import { isAuthRuntimeEnabled } from '@/lib/auth/runtime-mode-core'
import { resolveSessionStatus } from '@/lib/auth/session'
import { createClient } from '@/lib/supabase/server'

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const deliveryPattern = /^synthetic:\/\/delivery\/[a-z0-9][a-z0-9/_-]{2,120}$/

function readString(formData: FormData, key: string) {
  const value = formData.get(key)
  return typeof value === 'string' ? value : ''
}

function readUuid(formData: FormData, key: string) {
  const value = readString(formData, key)
  return uuidPattern.test(value) ? value : null
}

function readInteger(formData: FormData, key: string): number
function readInteger(formData: FormData, key: string, nullable: false): number
function readInteger(formData: FormData, key: string, nullable: true): number | null
function readInteger(formData: FormData, key: string, nullable = false): number | null {
  const value = readString(formData, key)
  if (nullable && value === '') return null
  if (!/^[0-9]+$/.test(value)) return Number.NaN
  return Number(value)
}

function safeReturnTo(value: string) {
  return value === '/' || value === '/cart' ? value : '/cart'
}

function mapRpcError(message: string) {
  if (message.includes('recent_otp_required')) return 'login-expired'
  if (message.includes('version_conflict')) return 'changed'
  if (message.includes('not_purchasable') || message.includes('not_available')) return 'unavailable'
  if (message.includes('empty')) return 'empty'
  if (message.includes('cancel_not_allowed')) return 'cancel-not-allowed'
  if (message.includes('idempotency_conflict')) return 'request-conflict'
  return 'try-again'
}

async function requireActionClient(nextPath: string) {
  const requestHeaders = await headers()
  if (!isAuthRuntimeEnabled(getAuthRuntimeModeForHost(requestHeaders.get('host')))) {
    redirect(`/account/login?next=${encodeURIComponent(nextPath)}`)
  }
  const supabase = await createClient()
  const session = await resolveSessionStatus({
    getClaims: () => supabase.auth.getClaims(),
  })
  if (session.status !== 'authenticated') {
    redirect(`/account/login?next=${encodeURIComponent(nextPath)}`)
  }
  return supabase
}

export async function putCartItemAction(formData: FormData) {
  const returnTo = safeReturnTo(readString(formData, 'return_to'))
  const supabase = await requireActionClient(returnTo)
  const listingId = readUuid(formData, 'listing_id')
  const idempotencyKey = readUuid(formData, 'idempotency_key')
  const quantity = readInteger(formData, 'quantity')
  const cartVersion = readInteger(formData, 'cart_version', true)
  const itemVersion = readInteger(formData, 'item_version', true)
  if (!listingId || !idempotencyKey || !Number.isInteger(quantity)
      || quantity < 1 || quantity > 1_000_000
      || (cartVersion !== null && (!Number.isInteger(cartVersion) || cartVersion < 1))
      || (itemVersion !== null && (!Number.isInteger(itemVersion) || itemVersion < 1))) {
    redirect(`${returnTo}?notice=invalid-request`)
  }
  const { error } = await supabase.rpc('put_cart_item', {
    p_listing_id: listingId,
    p_quantity: quantity,
    p_expected_cart_version: cartVersion,
    p_expected_item_version: itemVersion,
    p_idempotency_key: idempotencyKey,
  })
  if (error) redirect(`${returnTo}?notice=${mapRpcError(error.message)}`)
  revalidatePath('/')
  revalidatePath('/cart')
  redirect(`${returnTo}?notice=cart-updated`)
}

export async function removeCartItemAction(formData: FormData) {
  const supabase = await requireActionClient('/cart')
  const listingId = readUuid(formData, 'listing_id')
  const idempotencyKey = readUuid(formData, 'idempotency_key')
  const cartVersion = readInteger(formData, 'cart_version')
  const itemVersion = readInteger(formData, 'item_version')
  if (!listingId || !idempotencyKey || !Number.isInteger(cartVersion)
      || !Number.isInteger(itemVersion) || cartVersion < 1 || itemVersion < 1) {
    redirect('/cart?notice=invalid-request')
  }
  const { error } = await supabase.rpc('remove_cart_item', {
    p_listing_id: listingId,
    p_expected_cart_version: cartVersion,
    p_expected_item_version: itemVersion,
    p_idempotency_key: idempotencyKey,
  })
  if (error) redirect(`/cart?notice=${mapRpcError(error.message)}`)
  revalidatePath('/')
  revalidatePath('/cart')
  redirect('/cart?notice=item-removed')
}

export async function checkoutCartAction(formData: FormData) {
  const supabase = await requireActionClient('/checkout')
  const idempotencyKey = readUuid(formData, 'idempotency_key')
  const cartVersion = readInteger(formData, 'cart_version')
  const deliveryReference = readString(formData, 'delivery_reference').trim().toLowerCase()
  if (!idempotencyKey || !Number.isInteger(cartVersion) || cartVersion < 1
      || !deliveryPattern.test(deliveryReference)) {
    redirect('/checkout?notice=invalid-delivery')
  }
  const { data, error } = await supabase.rpc('checkout_cart', {
    p_expected_cart_version: cartVersion,
    p_synthetic_delivery_reference: deliveryReference,
    p_idempotency_key: idempotencyKey,
  })
  if (error) redirect(`/checkout?notice=${mapRpcError(error.message)}`)
  const batchId = data?.[0]?.batch_id
  if (typeof batchId !== 'string' || !uuidPattern.test(batchId)) {
    redirect('/checkout?notice=try-again')
  }
  revalidatePath('/')
  revalidatePath('/cart')
  revalidatePath('/account/orders')
  redirect(`/account/orders/${batchId}?notice=order-created`)
}

export async function cancelOrderAction(formData: FormData) {
  const batchId = readUuid(formData, 'batch_id')
  const nextPath = batchId ? `/account/orders/${batchId}` : '/account/orders'
  const supabase = await requireActionClient(nextPath)
  const idempotencyKey = readUuid(formData, 'idempotency_key')
  const orderVersion = readInteger(formData, 'order_version')
  const confirmation = readString(formData, 'confirm_cancel')
  if (!batchId || !idempotencyKey || !Number.isInteger(orderVersion)
      || orderVersion < 1 || confirmation !== 'cancel-entire-order') {
    redirect(`${nextPath}?notice=invalid-request`)
  }
  const { error } = await supabase.rpc('cancel_my_order_batch', {
    p_batch_id: batchId,
    p_expected_version: orderVersion,
    p_idempotency_key: idempotencyKey,
  })
  if (error) redirect(`${nextPath}?notice=${mapRpcError(error.message)}`)
  revalidatePath('/account/orders')
  revalidatePath(nextPath)
  redirect(`${nextPath}?notice=order-cancelled`)
}
