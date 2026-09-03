export type CatalogListing = {
  listing_id: string
  store_id: string
  store_name: string
  category_slug: string
  product_kind: 'standard' | 'secondhand'
  listing_slug: string
  title: string
  summary: string
  audience: 'retail' | 'wholesale'
  unit_amount_cents: number
  minimum_quantity: number
  currency_code: 'EUR'
  available_quantity: number
  price_version: number
  listing_version: number
  purchasable: boolean
}

export type CartRow = {
  cart_id: string
  cart_version: number
  listing_id: string | null
  item_id: string | null
  quantity: number | null
  item_version: number | null
  store_id: string | null
  store_name: string | null
  product_kind: 'standard' | 'secondhand' | null
  title: string | null
  sku: string | null
  audience: 'retail' | 'wholesale' | null
  unit_amount_cents: number | null
  minimum_quantity: number | null
  currency_code: 'EUR' | null
  available_quantity: number | null
  price_version: number | null
  listing_version: number | null
  purchasable: boolean
  invalid_reason: string | null
}

export type OrderSummary = {
  batch_id: string
  synthetic_order_reference: string
  order_status: 'confirmed' | 'cancelled'
  inventory_status: 'reserved' | 'released'
  payment_status: 'not_required'
  currency_code: 'EUR'
  total_cents: number
  order_version: number
  merchant_count: number
  item_count: number
  created_at: string
  cancelled_at: string | null
}

export type OrderDetailRow = {
  batch_id: string
  synthetic_order_reference: string
  synthetic_delivery_reference: string
  order_status: 'confirmed' | 'cancelled'
  inventory_status: 'reserved' | 'released'
  payment_status: 'not_required'
  currency_code: 'EUR'
  total_cents: number
  order_version: number
  merchant_order_id: string
  merchant_order_status: 'pending' | 'cancelled'
  store_id: string
  store_name: string
  merchant_subtotal_cents: number
  listing_id: string
  title_snapshot: string
  sku_snapshot: string
  product_kind: 'standard' | 'secondhand'
  quantity: number
  audience: 'retail' | 'wholesale'
  unit_amount_cents: number
  line_amount_cents: number
  item_inventory_status: 'reserved' | 'released'
  event_codes: Array<{ event: string; status: string; created_at: string }>
  created_at: string
  cancelled_at: string | null
}

export function formatEuro(cents: number) {
  return new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency: 'EUR',
  }).format(cents / 100)
}

export function itemCount(rows: CartRow[]) {
  return rows.reduce((sum, row) => sum + (row.quantity ?? 0), 0)
}
