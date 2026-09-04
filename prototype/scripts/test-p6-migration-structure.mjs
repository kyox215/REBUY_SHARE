import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

const read = (relative) => readFile(fileURLToPath(new URL(relative, import.meta.url)), 'utf8')

const [migration, gate, schemaTest, workflowTest, concurrencyTest, browserTest,
  actions, shell, productPage,
  inventoryPage, orderPage, afterSalePage, auditPage] = await Promise.all([
  read('../../supabase/migrations/20260904170000_p6_merchant_operations.sql'),
  read('../../docs/stages/P6-商家后台闭环Gate.md'),
  read('../../supabase/tests/p6_schema_security.test.sql'),
  read('../../supabase/tests/p6_workflow.test.sql'),
  read('./run-p6-concurrency.mjs'),
  read('./run-p6-browser-e2e.mjs'),
  read('../app/merchant/actions.ts'),
  read('../components/MerchantShell.tsx'),
  read('../app/merchant/products/page.tsx'),
  read('../app/merchant/inventory/page.tsx'),
  read('../app/merchant/orders/[merchantOrderId]/page.tsx'),
  read('../app/merchant/after-sales/page.tsx'),
  read('../app/merchant/audit/page.tsx'),
])

for (const table of ['merchant_after_sale_cases', 'merchant_operation_events', 'p6_idempotency_keys']) {
  assert.match(migration, new RegExp(`CREATE TABLE public[.]${table} \\(`))
  assert.match(migration, new RegExp(`ALTER TABLE public[.]${table} ENABLE ROW LEVEL SECURITY;`))
  assert.match(migration, new RegExp(`ALTER TABLE public[.]${table} FORCE ROW LEVEL SECURITY;`))
}

for (const wrapper of ['get_my_merchant_context', 'get_my_merchant_dashboard',
  'list_my_merchant_products', 'list_my_merchant_inventory',
  'list_my_merchant_orders', 'get_my_merchant_order',
  'list_my_merchant_after_sales', 'list_my_merchant_audit',
  'adjust_my_merchant_inventory',
  'advance_my_merchant_order', 'open_my_merchant_after_sale',
  'review_my_merchant_after_sale']) {
  assert.match(migration, new RegExp(`CREATE OR REPLACE FUNCTION public[.]${wrapper}\\([\\s\\S]*?SECURITY INVOKER`), `${wrapper} must be an invoker wrapper`)
  assert.match(migration, new RegExp(`CREATE OR REPLACE FUNCTION private[.]${wrapper}_impl\\([\\s\\S]*?SECURITY DEFINER SET search_path = ''`), `${wrapper}_impl must be an empty-path definer`)
  assert.match(migration, new RegExp(`ALTER FUNCTION private[.]${wrapper}_impl\\([^;]*\\) OWNER TO rebuy_business_executor`), `${wrapper}_impl must use the isolated owner`)
}

assert.match(migration, /status IN \('pending', 'accepted', 'shipped', 'completed', 'rejected', 'cancelled'\)/)
assert.match(migration, /status IN \('opened', 'reviewing', 'resolved', 'rejected'\)/)
assert.match(migration, /synthetic_shipment_reference ~ '\^synthetic:\/\/shipment\//)
assert.match(migration, /PRIMARY KEY \(actor_user_id, idempotency_key\)/)
assert.match(migration, /CONSTRAINT merchant_operation_actor_key UNIQUE \([\s\S]*?actor_user_id, idempotency_key/)
assert.match(migration, /ORDER BY mo[.]id FOR UPDATE/)
assert.match(migration, /ORDER BY oi[.]listing_id FOR UPDATE/)
assert.match(migration, /private[.]rebuy_p6_change_order_inventory_impl\([\s\S]*?CASE p_action WHEN 'reject' THEN 'release' ELSE 'sell' END/)
assert.match(migration, /CREATE OR REPLACE FUNCTION private[.]rebuy_p6_change_order_inventory_impl\([\s\S]*?p_action NOT IN \('release', 'sell'\)/)
assert.match(migration, /CREATE OR REPLACE FUNCTION private[.]cancel_my_order_batch_p6_impl\([\s\S]*?rebuy_p6_change_order_inventory_impl/)
assert.match(migration, /CREATE OR REPLACE FUNCTION public[.]cancel_my_order_batch\([\s\S]*?cancel_my_order_batch_p6_impl/)
assert.match(migration, /REVOKE ALL PRIVILEGES ON FUNCTION private[.]cancel_my_order_batch_impl\(uuid, integer, uuid\) FROM PUBLIC, anon, authenticated, service_role/)
assert.match(migration, /private[.]rebuy_p6_refresh_batch\(v_batch_id\)/)
assert.match(migration, /PERFORM private[.]rebuy_p5_reset_context\(\)/)
assert.match(migration, /PERFORM private[.]rebuy_p6_clear_context\(\)/)
assert.match(migration, /p_require_recent_identity/)
assert.match(migration, /CREATE OR REPLACE FUNCTION private[.]rebuy_p6_lock_actor_key\([\s\S]*?pg_advisory_xact_lock/)
assert.match(migration, /CREATE OR REPLACE FUNCTION private[.]rebuy_p6_lock_actor_key\([\s\S]*?:p4-idempotency[\s\S]*?:p6-idempotency/)
assert.match(migration, /private[.]rebuy_p6_lock_actor_key\(uuid\)[\s\S]*?TO rebuy_business_executor/)
assert.match(migration, /ALTER FUNCTION private[.]rebuy_p6_lock_actor_key\(uuid\) OWNER TO rebuy_business_executor/)
assert.match(migration, /IF p_require_recent_identity THEN[\s\S]*?FROM public[.]organizations AS o[\s\S]*?FOR SHARE;[\s\S]*?FROM public[.]stores AS s[\s\S]*?FOR SHARE;/)
assert.doesNotMatch(migration, /CREATE POLICY (?:stores|organizations|memberships|role_definitions|membership_store_scopes)_p6_authorization_lock/)
for (const policy of ['stores_business_p4_update',
  'organizations_business_update_merchant', 'memberships_business_update_owner',
  'role_definitions_p5_pricing_lock',
  'membership_store_scopes_business_update_owner',
  'permissions_p6_authorization_lock', 'role_permissions_p6_authorization_lock']) {
  assert.match(migration, new RegExp(`CREATE POLICY ${policy}[\\s\\S]*?rebuy[.]p6[.]op`),
    `${policy} must include the P6 authorization lock branch`)
}
for (const functionName of ['adjust_my_merchant_inventory_impl',
  'advance_my_merchant_order_impl', 'open_my_merchant_after_sale_impl',
  'review_my_merchant_after_sale_impl']) {
  const functionMatch = migration.match(new RegExp(
    `CREATE OR REPLACE FUNCTION private[.]${functionName}\\([\\s\\S]*?\\n\\$function\\$;`))
  assert.ok(functionMatch, `${functionName} source must exist`)
  assert.ok(functionMatch[0].indexOf('rebuy_p6_lock_actor_key')
    < functionMatch[0].indexOf('rebuy_p6_authorize_store'),
    `${functionName} must serialize actor/key before authorization locks`)
}
assert.match(migration, /CREATE OR REPLACE FUNCTION private[.]adjust_my_merchant_inventory_impl\([\s\S]*?l[.]organization_id = v_auth[.]organization_id[\s\S]*?l[.]store_id = v_auth[.]store_id[\s\S]*?merchant_inventory_scope_forbidden/)
assert.equal((migration.match(/synthetic_serial_reference text,/g) ?? []).length, 2,
  'secondhand serial reference must remain aligned across table and product DTOs')
assert.match(migration, /merchant[.]order[.]fulfill/)
assert.match(migration, /merchant[.]after_sale[.]manage/)
assert.match(migration, /merchant[.]audit[.]read/)
assert.doesNotMatch(migration, /GRANT (?:SELECT|INSERT|UPDATE|DELETE|ALL)[^;]*ON TABLE[^;]*TO (?:anon|authenticated|service_role)/is)
assert.doesNotMatch(migration, /GRANT EXECUTE[^;]*TO service_role/is)
assert.doesNotMatch(migration, /\b(?:address|phone|payment_token|card_number|tax_id|refund_token)\b/i)
assert.doesNotMatch(migration, /\b(?:DELETE|UPDATE) FROM public[.]merchant_operation_events\b/i)

const authGate = actions.indexOf("getAuthRuntimeModeForHost(requestHeaders.get('host'))")
const clientCreation = actions.indexOf('const supabase = await createClient()')
assert.ok(authGate >= 0 && clientCreation > authGate, 'merchant actions must enforce runtime mode before client creation')
assert.match(actions, /p_expected_version: expectedVersion/)
assert.match(actions, /p_idempotency_key: idempotencyKey/)
assert.match(actions, /p_reason_code: reasonCode/)
assert.match(actions, /adjust_my_merchant_inventory/)
assert.match(actions, /shipmentPattern/)
assert.match(shell, /item[.]allowed\(context\)/)
assert.match(shell, /当前门店/)
assert.match(productPage, /upsertMerchantListingAction/)
assert.match(inventoryPage, /name="reason_code"/)
assert.match(inventoryPage, /stock_received/)
assert.match(orderPage, /advanceMerchantOrderAction/)
assert.match(afterSalePage, /reviewMerchantAfterSaleAction/)
assert.match(auditPage, /loadMerchantAudit/)
assert.match(schemaTest, /external roles have no P6 table privileges/)
assert.match(schemaTest, /P6 private implementations have effective authenticated-only ACLs/)
assert.match(workflowTest, /full merchant fulfillment reaches completed and sold/)
assert.match(workflowTest, /same order action key replays the original result/)
assert.match(workflowTest, /cross-store merchant order access fails closed/)
assert.match(workflowTest, /after-sale reaches a recorded terminal resolution/)
for (const phrase of ['store-scoped employee sees exactly one authorized merchant context',
  'private read implementation preserves employee authorization parity',
  'private direct read rejects an employee cross-store target',
  'employee without inventory permission cannot use the private write implementation',
  'permission drift immediately invalidates employee dashboard access',
  'retired role drift immediately invalidates private direct access',
  'public and private dashboard reads return the same authorized DTO',
  'private direct inventory write applies the same guarded workflow',
  'public wrapper replays the private write result without duplication',
  'private direct inventory write rejects a cross-store listing']) {
  assert.match(workflowTest, new RegExp(phrase))
}
assert.match(workflowTest, /CREATE TRIGGER p6_mid_operation_rollback/)
assert.match(workflowTest, /p6_injected_operation_event_failure/)
for (const rollbackCategory of ['inventory', 'merchant order', 'batch', 'order items',
  'order events', 'inventory events', 'P4 keys', 'P6 keys', 'merchant events']) {
  assert.match(workflowTest, new RegExp(
    `mid-operation rollback leaves ${rollbackCategory} unchanged`),
  `mid-operation rollback must assert ${rollbackCategory}`)
}
for (const phrase of ['same_key_order_transition', 'different_key_reject_transition',
  'downlisted_complete_and_cancel', 'after_sale_open_and_review_races',
  'same_key_inventory_adjustment', 'cross_store_inventory_scope',
  'cross_surface_actor_key_order',
  'suspend_authorization_race', 'revoke_authorization_race',
  'P6_CONCURRENCY_PASS']) {
  assert.match(concurrencyTest, new RegExp(phrase))
}
for (const phrase of ['unauthenticated_merchant_guard', 'merchant_signup_and_no_access',
  'product_create_and_search', 'inventory_adjustment_reason',
  'merchant_order_fulfillment', 'merchant_after_sale',
  'merchant_audit_and_responsive_keyboard', 'P6_BROWSER_E2E_PASS']) {
  assert.match(browserTest, new RegExp(phrase))
}

for (const phrase of ['synthetic-only', 'FORCE RLS', 'expected version', 'main push/merge/deploy 继续关闭']) {
  assert.match(gate, new RegExp(phrase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
}

console.log('P6 migration structure checks passed')
