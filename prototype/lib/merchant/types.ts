export type MerchantContext = {
  store_id: string
  organization_id: string
  store_name: string
  role_key: string
  membership_id: string
  can_catalog: boolean
  can_pricing: boolean
  can_inventory: boolean
  can_fulfill: boolean
  can_after_sale: boolean
  can_audit: boolean
}

export type MerchantDashboard = {
  store_id: string
  store_name: string
  active_listing_count: number
  low_stock_count: number
  pending_order_count: number
  active_after_sale_count: number
  recent_operation_count: number
}

export type MerchantProduct = {
  listing_id: string
  product_id: string
  variant_id: string
  category_slug: string
  product_kind: 'standard' | 'secondhand'
  internal_name: string
  sku: string
  listing_slug: string
  title: string
  summary: string
  listing_status: 'draft' | 'active' | 'inactive'
  listing_version: number
  retail_cents: number
  wholesale_cents: number | null
  wholesale_minimum: number | null
  wholesale_tiers: Array<{ minimum_quantity: number; unit_amount_cents: number }>
  available_quantity: number
  inventory_version: number
  synthetic_serial_reference: string | null
  condition_code: 'like_new' | 'good' | 'fair' | null
  defect_code: 'none' | 'cosmetic_wear' | 'screen_mark' | 'housing_mark' | null
  battery_health_percent: number | null
  warranty_days: number | null
}

export type MerchantInventory = {
  listing_id: string
  title: string
  sku: string
  inventory_kind: 'standard' | 'secondhand'
  on_hand: number
  reserved: number
  available: number
  unit_status: 'available' | 'reserved' | 'sold' | 'inactive' | null
  inventory_version: number
  updated_at: string
}

export type MerchantOrderSummary = {
  merchant_order_id: string
  batch_id: string
  synthetic_order_reference: string
  order_status: 'pending' | 'accepted' | 'shipped' | 'completed' | 'rejected' | 'cancelled'
  inventory_status: 'reserved' | 'sold' | 'released'
  currency_code: 'EUR'
  total_cents: number
  order_version: number
  item_count: number
  created_at: string
  updated_at: string
}

export type MerchantOrderDetail = MerchantOrderSummary & {
  synthetic_shipment_reference: string | null
  listing_id: string
  title_snapshot: string
  sku_snapshot: string
  product_kind: 'standard' | 'secondhand'
  quantity: number
  audience: 'retail' | 'wholesale'
  unit_amount_cents: number
  line_amount_cents: number
  item_inventory_status: 'reserved' | 'sold' | 'released'
  event_codes: Array<{ event: string; status: string; created_at: string }>
  accepted_at: string | null
  shipped_at: string | null
  completed_at: string | null
}

export type MerchantAfterSale = {
  case_id: string
  merchant_order_id: string
  synthetic_order_reference: string
  reason_code: 'return_request' | 'damaged' | 'wrong_item'
  case_status: 'opened' | 'reviewing' | 'resolved' | 'rejected'
  resolution_code: string | null
  case_version: number
  created_at: string
  updated_at: string
  resolved_at: string | null
}

export type MerchantAuditEvent = {
  event_code: string
  entity_type: string
  entity_id: string
  reason_code: string
  from_status: string | null
  to_status: string
  from_version: number | null
  to_version: number
  created_at: string
}
