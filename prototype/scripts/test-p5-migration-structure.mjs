import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

const read = (relative) =>
  readFile(fileURLToPath(new URL(relative, import.meta.url)), 'utf8')

const [migration, gate, schemaTest, workflowTest, concurrencyTest, raceTest,
  browserTest, shopActions, storefront, cartPage] = await Promise.all([
  read('../../supabase/migrations/20260904120000_p5_cart_orders.sql'),
  read('../../docs/stages/P5-浏览购物车与订单Gate.md'),
  read('../../supabase/tests/p5_schema_security.test.sql'),
  read('../../supabase/tests/p5_workflow.test.sql'),
  read('./run-p5-checkout-concurrency.mjs'),
  read('./run-p5-race-concurrency.mjs'),
  read('./run-p5-browser-e2e.mjs'),
  read('../app/shop-actions.ts'),
  read('../app/page.tsx'),
  read('../app/cart/page.tsx'),
])

const tables = [
  'carts',
  'cart_items',
  'order_batches',
  'merchant_orders',
  'order_items',
  'order_events',
  'p5_idempotency_keys',
]

for (const table of tables) {
  assert.match(migration, new RegExp(`CREATE TABLE public[.]${table} \\(`))
  assert.match(migration, new RegExp(`ALTER TABLE public[.]${table} ENABLE ROW LEVEL SECURITY;`))
  assert.match(migration, new RegExp(`ALTER TABLE public[.]${table} FORCE ROW LEVEL SECURITY;`))
}

assert.match(migration, /CREATE UNIQUE INDEX carts_one_active_per_owner/)
assert.match(migration, /PRIMARY KEY \(actor_user_id, idempotency_key\)/)
assert.match(migration, /listing_prices_minimum_upper_check[\s\S]*?minimum_quantity <= 1000000/)
assert.match(migration, /listing_price_tiers_quantity_upper_check[\s\S]*?minimum_quantity <= 1000000/)
assert.match(migration, /quantity BETWEEN 1 AND 1000000/)
assert.match(migration, /product_kind = 'standard' OR quantity = 1/)
assert.match(migration, /currency_code = 'EUR'/)
assert.match(migration, /payment_status = 'not_required'/)
assert.match(migration, /shipping_cents = 0 AND tax_cents = 0/)
assert.match(migration, /synthetic_delivery_reference ~ '\^synthetic:\/\/delivery\//)

const publicWrappers = [
  'search_catalog',
  'get_my_cart',
  'put_cart_item',
  'remove_cart_item',
  'checkout_cart',
  'list_my_orders',
  'get_my_order',
  'cancel_my_order_batch',
]
for (const wrapper of publicWrappers) {
  assert.match(
    migration,
    new RegExp(`CREATE OR REPLACE FUNCTION public[.]${wrapper}\\([\\s\\S]*?SECURITY INVOKER`),
    `${wrapper} must be an invoker wrapper`,
  )
}

const implementations = publicWrappers.map((name) => `${name}_impl`)
for (const implementation of implementations) {
  assert.match(
    migration,
    new RegExp(`CREATE OR REPLACE FUNCTION private[.]${implementation}\\([\\s\\S]*?SECURITY DEFINER SET search_path = ''`),
    `${implementation} must be an empty-path definer`,
  )
  assert.match(
    migration,
    new RegExp(`ALTER FUNCTION private[.]${implementation}\\([^;]*\\) OWNER TO rebuy_business_executor`),
    `${implementation} must use the isolated executor owner`,
  )
}

assert.match(migration, /PERFORM private[.]rebuy_p5_reset_context\(\)/)
assert.match(migration, /PERFORM private[.]rebuy_p4_reset_context\(\)/)
assert.match(migration, /private[.]rebuy_p5_clear_context\(\)/)
for (const p2ContextKey of ['authorized', 'op', 'uid', 'member_id', 'invitation_id',
  'scope_id', 'audit_id', 'organization_id', 'role_id', 'target_email',
  'idempotency_key', 'event_code', 'outcome']) {
  const actualKey = p2ContextKey === 'organization_id' ? 'org_id' : p2ContextKey
  assert.match(migration, new RegExp(`rebuy[.]invite[.]${actualKey}`),
    `P5 reset must clear P2 invitation context key ${actualKey}`)
}
assert.match(migration, /private[.]rebuy_p5_lock_pricing_context\(v_uid\)/)
assert.match(migration, /private[.]get_catalog_quote_impl\(v_item[.]listing_id, v_item[.]quantity\)/)
assert.match(migration, /private[.]change_inventory_reservation_impl\(v_item[.]listing_id,[\s\S]*?'reserve'/)
assert.match(migration, /private[.]change_inventory_reservation_impl\(v_item[.]listing_id,[\s\S]*?'release'/)
assert.match(migration, /ORDER BY ci[.]listing_id/)
assert.match(migration, /ORDER BY oi[.]listing_id FOR UPDATE/)
assert.match(migration, /DELETE FROM public[.]cart_items AS ci WHERE ci[.]cart_id = v_cart[.]id/)
assert.match(migration, /IF v_line < 1 OR v_total \+ v_line > 2147483647/)
assert.match(migration, /result_item_version integer/)
assert.match(migration, /result_reference text/)
assert.match(migration, /result_inventory_status text/)
assert.match(migration, /result_cancelled_at timestamptz/)
assert.match(migration, /v_key[.]result_reference/)
assert.match(migration, /v_key[.]result_cancelled_at/)

const checkoutStart = migration.indexOf('CREATE OR REPLACE FUNCTION private.checkout_cart_impl')
const p4ReservationKeyLock = migration.indexOf("':p4-idempotency'", checkoutStart)
const pricingContextLock = migration.indexOf(
  'PERFORM private.rebuy_p5_lock_pricing_context(v_uid)', checkoutStart,
)
const listingLock = migration.indexOf(
  'pg_catalog.hashtextextended(v_item.listing_id::text, 0)', checkoutStart,
)
const quoteAfterLock = migration.indexOf(
  'FROM private.get_catalog_quote_impl(v_item.listing_id, v_item.quantity)',
  checkoutStart,
)
const reserveAfterQuote = migration.indexOf(
  'FROM private.change_inventory_reservation_impl(v_item.listing_id,', checkoutStart,
)
assert.ok(checkoutStart >= 0
  && p4ReservationKeyLock > checkoutStart
  && pricingContextLock > p4ReservationKeyLock
  && listingLock > pricingContextLock
  && quoteAfterLock > listingLock
  && reserveAfterQuote > quoteAfterLock,
  'checkout lock order must be all P4 keys, pricing context, all listings, quote, reserve')

const putStart = migration.indexOf('CREATE OR REPLACE FUNCTION private.put_cart_item_impl')
const putReplayReturn = migration.indexOf(
  'RETURN QUERY SELECT v_key.cart_id, v_key.result_version', putStart,
)
const putReplayBranch = migration.slice(putStart, putReplayReturn)
assert.match(putReplayBranch, /JOIN public[.]organizations AS o/)
assert.doesNotMatch(putReplayBranch, /get_catalog_quote_impl/,
  'historical cart.put replay must not depend on current price, MOQ, or stock')

const cancelStart = migration.indexOf('CREATE OR REPLACE FUNCTION private.cancel_my_order_batch_impl')
const suborderLock = migration.indexOf(
  'WHERE mo.batch_id = p_batch_id ORDER BY mo.id FOR UPDATE', cancelStart,
)
const suborderStatusCheck = migration.indexOf(
  "WHERE mo.batch_id = p_batch_id AND mo.status <> 'pending'", cancelStart,
)
assert.ok(cancelStart >= 0 && suborderLock > cancelStart
  && suborderStatusCheck > suborderLock,
  'cancellation must lock suborders before validating fulfillment state')

for (const indexName of ['carts_checkout_batch_idx', 'order_events_merchant_batch_idx']) {
  assert.match(migration, new RegExp(`CREATE INDEX ${indexName}\\s+ON public[.]`))
  assert.doesNotMatch(
    migration,
    new RegExp(`CREATE INDEX ${indexName}[\\s\\S]{0,180}WHERE`),
    `${indexName} must cover nullable foreign keys without a partial predicate`,
  )
}

for (const operation of ['cart.put', 'cart.remove', 'order.checkout', 'order.cancel']) {
  assert.match(migration, new RegExp(`'${operation.replace('.', '[.]')}'`))
}

assert.doesNotMatch(
  migration,
  /GRANT (?:SELECT|INSERT|UPDATE|DELETE|ALL)[^;]*ON TABLE[^;]*TO (?:anon|authenticated|service_role)/is,
)
assert.doesNotMatch(migration, /GRANT EXECUTE[^;]*TO service_role/is)
assert.doesNotMatch(migration, /\b(?:address|phone|payment_token|card_number|tax_id)\b/i)
assert.doesNotMatch(migration, /\b(?:DELETE|UPDATE) FROM public[.]order_events\b/i)

assert.match(schemaTest, /every P5 foreign key has a valid non-partial full leading-column index/)
assert.match(schemaTest, /immutable snapshots/)
assert.match(workflowTest, /old checkout key remains confirmed\/reserved\/version one/)
assert.match(workflowTest, /old put key remains stable after later mutation, checkout, and stock exhaustion/)
assert.match(workflowTest, /direct remove parity returns the stable original result/)
assert.match(workflowTest, /old remove replay cannot delete the newly re-added cart item/)
assert.match(workflowTest, /clears stale P2 invitation authorization context/)
assert.match(workflowTest, /direct catalog implementation exactly matches the public wrapper DTO/)
assert.match(workflowTest, /direct order list implementation exactly matches the public wrapper DTO/)
assert.match(workflowTest, /direct order detail implementation exactly matches the public wrapper DTO/)
assert.match(workflowTest, /direct cancel implementation exactly replays the public wrapper DTO/)
assert.match(workflowTest, /direct order list implementation preserves cross-user denial/)
assert.match(workflowTest, /direct order detail implementation preserves cross-user denial/)
assert.match(workflowTest, /successful P5 reads clear their transaction-local P5 context/)
assert.match(workflowTest, /qualified wholesale catalog permits adding the legal MOQ quantity/)
assert.match(workflowTest, /wholesale MOQ above 99 remains purchasable end to end/)
assert.match(workflowTest, /cart quantity above the shared P4 upper bound is rejected/)

for (const phrase of [
  'same_key_checkout',
  'different_key_same_cart',
  'secondhand_unique_winner',
  'multi_item_atomic_rollback',
]) assert.match(concurrencyTest, new RegExp(phrase))

for (const phrase of [
  'standard_oversell_unique_winner',
  'price_update_requoted_after_lock',
  'qualification_revoke_falls_back_to_retail',
  'mid_cancel_atomic_rollback',
  'p4_derived_key_collision_lock_order',
  'P5_RACE_CONCURRENCY_PASS',
]) assert.match(raceTest, new RegExp(phrase))
assert.match(raceTest, /ERROR:\\s\+p4_idempotency_conflict/)

for (const phrase of [
  'P5_BROWSER_E2E_FAIL:',
  'unauthenticated_route_guard',
  'empty_cart',
  'invalid_cart_recovery',
  'checkout_double_submit',
  'cancel_confirmation',
  'cross_user_order_denied',
  'expected_cross_user_404_console',
  'wholesale_catalog_moq',
  'P5_BROWSER_EMPTY_CART_PASS',
  'P5_BROWSER_INVALID_CART_RECOVERY_PASS',
  'P5_BROWSER_CROSS_USER_ORDER_DENIED_PASS',
  'P5_BROWSER_WHOLESALE_MOQ_PASS',
]) assert.match(browserTest, new RegExp(phrase))

const runtimeGate = shopActions.indexOf("getAuthRuntimeModeForHost(requestHeaders.get('host'))")
const actionClientCreation = shopActions.indexOf('const supabase = await createClient()')
assert.ok(runtimeGate >= 0 && actionClientCreation > runtimeGate,
  'server actions must enforce local-auth host mode before creating a Supabase client')
assert.match(shopActions, /confirmation !== 'cancel-entire-order'/)
assert.match(shopActions, /quantity > 1_000_000/)
assert.match(storefront, /disabled={!listing[.]purchasable \|\| max < listing[.]minimum_quantity}/)
assert.match(storefront, /Math[.]min\(1_000_000, listing[.]available_quantity\)/)
assert.match(cartPage, /Math[.]min\(1_000_000, row[.]available_quantity \?\? 1\)/)

for (const phrase of [
  'synthetic-only',
  '任一商品无效',
  '整个 checkout 回滚',
  '完整 batch',
  'FORCE RLS',
  'main push/merge/deploy 继续关闭',
]) {
  assert.match(gate, new RegExp(phrase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
}

console.log('P5 migration structure checks passed')
