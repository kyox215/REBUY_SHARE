import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'

const DB_CONTAINER = 'supabase_db_rebuy-g2-a1-e2a-local-email-otp-exec'
const IDS = {
  actorA: '50000000-0000-4000-8000-000000000001',
  actorB: '50000000-0000-4000-8000-000000000002',
  actorC: '50000000-0000-4000-8000-000000000003',
  actorD: '50000000-0000-4000-8000-000000000004',
  actorE: '50000000-0000-4000-8000-000000000005',
  merchant: '50000000-0000-4000-8000-000000000006',
  organization: '50000000-0000-4000-8000-000000000101',
  store: '50000000-0000-4000-8000-000000000102',
  sameProduct: '50000000-0000-4000-8000-000000000201',
  sameVariant: '50000000-0000-4000-8000-000000000202',
  sameListing: '50000000-0000-4000-8000-000000000203',
  sameInventory: '50000000-0000-4000-8000-000000000204',
  differentProduct: '50000000-0000-4000-8000-000000000211',
  differentVariant: '50000000-0000-4000-8000-000000000212',
  differentListing: '50000000-0000-4000-8000-000000000213',
  differentInventory: '50000000-0000-4000-8000-000000000214',
  usedProduct: '50000000-0000-4000-8000-000000000221',
  usedVariant: '50000000-0000-4000-8000-000000000222',
  usedListing: '50000000-0000-4000-8000-000000000223',
  usedUnit: '50000000-0000-4000-8000-000000000224',
  rollbackProductA: '50000000-0000-4000-8000-000000000231',
  rollbackVariantA: '50000000-0000-4000-8000-000000000232',
  rollbackListingA: '50000000-0000-4000-8000-000000000233',
  rollbackInventoryA: '50000000-0000-4000-8000-000000000234',
  rollbackProductB: '50000000-0000-4000-8000-000000000241',
  rollbackVariantB: '50000000-0000-4000-8000-000000000242',
  rollbackListingB: '50000000-0000-4000-8000-000000000243',
  rollbackInventoryB: '50000000-0000-4000-8000-000000000244',
  cartA: '50000000-0000-4000-8000-000000000301',
  cartB: '50000000-0000-4000-8000-000000000302',
  cartC: '50000000-0000-4000-8000-000000000303',
  cartD: '50000000-0000-4000-8000-000000000304',
  cartE: '50000000-0000-4000-8000-000000000305',
  sameKey: '50000000-0000-4000-8000-000000000401',
  differentKeyA: '50000000-0000-4000-8000-000000000402',
  differentKeyB: '50000000-0000-4000-8000-000000000403',
  usedKeyA: '50000000-0000-4000-8000-000000000404',
  usedKeyB: '50000000-0000-4000-8000-000000000405',
  rollbackKey: '50000000-0000-4000-8000-000000000406',
}

const users = [IDS.actorA, IDS.actorB, IDS.actorC, IDS.actorD, IDS.actorE, IDS.merchant]
const carts = [IDS.cartA, IDS.cartB, IDS.cartC, IDS.cartD, IDS.cartE]
const listings = [
  IDS.sameListing,
  IDS.differentListing,
  IDS.usedListing,
  IDS.rollbackListingA,
  IDS.rollbackListingB,
]
const products = [
  IDS.sameProduct,
  IDS.differentProduct,
  IDS.usedProduct,
  IDS.rollbackProductA,
  IDS.rollbackProductB,
]
const sqlList = (values) => values.map((value) => `'${value}'`).join(', ')
const active = new Set()

function startPsql(sql) {
  const child = spawn(
    'docker',
    [
      'exec', '-i', DB_CONTAINER, 'psql', '-X', '-q', '-v',
      'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres', '-A', '-t',
    ],
    { stdio: ['pipe', 'pipe', 'pipe'] },
  )
  let stdout = ''
  let stderr = ''
  child.stdout.setEncoding('utf8')
  child.stderr.setEncoding('utf8')
  child.stdout.on('data', (chunk) => {
    stdout += chunk
    if (stdout.length > 131_072) child.kill('SIGTERM')
  })
  child.stderr.on('data', (chunk) => {
    stderr += chunk
    if (stderr.length > 131_072) child.kill('SIGTERM')
  })
  child.stdin.end(sql)
  const raw = new Promise((resolve, reject) => {
    child.on('error', reject)
    child.on('close', (code, signal) => resolve({ code, signal, stdout, stderr }))
  })
  const result = raw.finally(() => active.delete(result))
  active.add(result)
  return { result, readStdout: () => stdout }
}

async function runAdmin(sql, label) {
  const result = await startPsql(sql).result
  assert.equal(result.signal, null, `${label}:signal`)
  assert.equal(result.code, 0, `${label}:exit\n${result.stderr}`)
  return result.stdout.trim()
}

const cleanupSql = `
REVOKE rebuy_business_executor FROM postgres GRANTED BY CURRENT_USER;
DO $cleanup_role$
BEGIN
  IF (
    SELECT count(*) FROM pg_catalog.pg_auth_members AS am
    JOIN pg_catalog.pg_roles AS granted_role ON granted_role.oid = am.roleid
    JOIN pg_catalog.pg_roles AS member_role ON member_role.oid = am.member
    WHERE granted_role.rolname = 'rebuy_business_executor'
      AND member_role.rolname = 'postgres'
  ) <> 1
     OR NOT EXISTS (
       SELECT 1 FROM pg_catalog.pg_auth_members AS am
       JOIN pg_catalog.pg_roles AS granted_role ON granted_role.oid = am.roleid
       JOIN pg_catalog.pg_roles AS member_role ON member_role.oid = am.member
       JOIN pg_catalog.pg_roles AS grantor_role ON grantor_role.oid = am.grantor
       WHERE granted_role.rolname = 'rebuy_business_executor'
         AND member_role.rolname = 'postgres'
         AND grantor_role.rolname = 'supabase_admin'
         AND am.admin_option AND NOT am.inherit_option AND NOT am.set_option
     )
     OR EXISTS (
       SELECT 1 FROM pg_catalog.pg_auth_members AS am
       JOIN pg_catalog.pg_roles AS granted_role ON granted_role.oid = am.roleid
       JOIN pg_catalog.pg_roles AS member_role ON member_role.oid = am.member
       JOIN pg_catalog.pg_roles AS grantor_role ON grantor_role.oid = am.grantor
       WHERE granted_role.rolname = 'rebuy_business_executor'
         AND member_role.rolname = 'postgres'
         AND grantor_role.rolname = 'postgres'
     )
     OR pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
  THEN RAISE EXCEPTION 'test_role_cleanup_failed'; END IF;
END
$cleanup_role$;
BEGIN;
UPDATE public.carts SET status = 'abandoned', checkout_batch_id = NULL
  WHERE id IN (${sqlList(carts)}) AND status = 'checked_out';
DELETE FROM public.p5_idempotency_keys WHERE actor_user_id IN (${sqlList(users)});
DELETE FROM public.order_events WHERE buyer_user_id IN (${sqlList(users)});
DELETE FROM public.order_items WHERE buyer_user_id IN (${sqlList(users)});
DELETE FROM public.merchant_orders WHERE buyer_user_id IN (${sqlList(users)});
DELETE FROM public.order_batches WHERE buyer_user_id IN (${sqlList(users)});
DELETE FROM public.cart_items WHERE cart_id IN (${sqlList(carts)});
DELETE FROM public.carts WHERE id IN (${sqlList(carts)});
DELETE FROM public.p4_idempotency_keys WHERE actor_user_id IN (${sqlList(users)});
DELETE FROM public.inventory_events WHERE listing_id IN (${sqlList(listings)});
DELETE FROM public.catalog_events WHERE listing_id IN (${sqlList(listings)});
DELETE FROM public.listing_price_tiers WHERE listing_id IN (${sqlList(listings)});
DELETE FROM public.listing_prices WHERE listing_id IN (${sqlList(listings)});
DELETE FROM public.inventory_levels WHERE listing_id IN (${sqlList(listings)});
DELETE FROM public.secondhand_units WHERE listing_id IN (${sqlList(listings)});
DELETE FROM public.listings WHERE id IN (${sqlList(listings)});
DELETE FROM public.product_variants WHERE product_id IN (${sqlList(products)});
DELETE FROM public.products WHERE id IN (${sqlList(products)});
DELETE FROM public.stores WHERE id = '${IDS.store}';
DELETE FROM public.organizations WHERE id = '${IDS.organization}';
DELETE FROM public.profiles WHERE user_id IN (${sqlList(users)});
DELETE FROM auth.users WHERE id IN (${sqlList(users)});
COMMIT;
`

const setupSql = `
${cleanupSql}
GRANT rebuy_business_executor TO postgres WITH INHERIT FALSE GRANTED BY CURRENT_USER;
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, role, aud)
VALUES
  ('${IDS.actorA}', 'p5-concurrency-a@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.actorB}', 'p5-concurrency-b@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.actorC}', 'p5-concurrency-c@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.actorD}', 'p5-concurrency-d@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.actorE}', 'p5-concurrency-e@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.merchant}', 'p5-concurrency-merchant@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated');
INSERT INTO public.organizations (id, organization_type, display_name, status, created_by)
VALUES ('${IDS.organization}', 'merchant', 'P5 Concurrency Merchant', 'active', '${IDS.merchant}');
INSERT INTO public.stores (id, organization_id, organization_type, display_name, slug, status, public_visibility)
VALUES ('${IDS.store}', '${IDS.organization}', 'merchant', 'P5 Concurrency Store', 'p5-concurrency-store', 'active', true);
INSERT INTO public.products (id, organization_id, organization_type, category_id, product_kind, internal_name, status, created_by)
VALUES
  ('${IDS.sameProduct}', '${IDS.organization}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P5 Same Key Item', 'active', '${IDS.merchant}'),
  ('${IDS.differentProduct}', '${IDS.organization}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P5 Double Submit Item', 'active', '${IDS.merchant}'),
  ('${IDS.usedProduct}', '${IDS.organization}', 'merchant', '00000000-0000-4000-8000-000000000303', 'secondhand', 'P5 Unique Used Item', 'active', '${IDS.merchant}'),
  ('${IDS.rollbackProductA}', '${IDS.organization}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P5 Rollback Available Item', 'active', '${IDS.merchant}'),
  ('${IDS.rollbackProductB}', '${IDS.organization}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P5 Rollback Unavailable Item', 'active', '${IDS.merchant}');
INSERT INTO public.product_variants (id, product_id, organization_id, organization_type, sku, unit_code, status)
VALUES
  ('${IDS.sameVariant}', '${IDS.sameProduct}', '${IDS.organization}', 'merchant', 'SYN-SKU-P5-SAME', 'unit', 'active'),
  ('${IDS.differentVariant}', '${IDS.differentProduct}', '${IDS.organization}', 'merchant', 'SYN-SKU-P5-DOUBLE', 'unit', 'active'),
  ('${IDS.usedVariant}', '${IDS.usedProduct}', '${IDS.organization}', 'merchant', 'SYN-SKU-P5-USED', 'unit', 'active'),
  ('${IDS.rollbackVariantA}', '${IDS.rollbackProductA}', '${IDS.organization}', 'merchant', 'SYN-SKU-P5-ROLLBACK-A', 'unit', 'active'),
  ('${IDS.rollbackVariantB}', '${IDS.rollbackProductB}', '${IDS.organization}', 'merchant', 'SYN-SKU-P5-ROLLBACK-B', 'unit', 'active');
INSERT INTO public.listings (id, organization_id, organization_type, store_id, product_id, variant_id, product_kind, slug, title, summary, status, version, published_at, created_by)
VALUES
  ('${IDS.sameListing}', '${IDS.organization}', 'merchant', '${IDS.store}', '${IDS.sameProduct}', '${IDS.sameVariant}', 'standard', 'p5-same-key-item', 'P5 Same Key Item', 'Synthetic same key checkout item', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.differentListing}', '${IDS.organization}', 'merchant', '${IDS.store}', '${IDS.differentProduct}', '${IDS.differentVariant}', 'standard', 'p5-double-submit-item', 'P5 Double Submit Item', 'Synthetic double-submit checkout item', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.usedListing}', '${IDS.organization}', 'merchant', '${IDS.store}', '${IDS.usedProduct}', '${IDS.usedVariant}', 'secondhand', 'p5-unique-used-item', 'P5 Unique Used Item', 'Synthetic unique used checkout item', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.rollbackListingA}', '${IDS.organization}', 'merchant', '${IDS.store}', '${IDS.rollbackProductA}', '${IDS.rollbackVariantA}', 'standard', 'p5-rollback-available-item', 'P5 Rollback Available Item', 'Synthetic rollback first item', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.rollbackListingB}', '${IDS.organization}', 'merchant', '${IDS.store}', '${IDS.rollbackProductB}', '${IDS.rollbackVariantB}', 'standard', 'p5-rollback-unavailable-item', 'P5 Rollback Unavailable Item', 'Synthetic rollback second item', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}');
INSERT INTO public.listing_prices (listing_id, organization_id, organization_type, store_id, audience, currency_code, unit_amount_cents, minimum_quantity, version, status, created_by)
VALUES
  ('${IDS.sameListing}', '${IDS.organization}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1000, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.differentListing}', '${IDS.organization}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1100, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.usedListing}', '${IDS.organization}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1200, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.rollbackListingA}', '${IDS.organization}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1300, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.rollbackListingB}', '${IDS.organization}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1400, 1, 1, 'active', '${IDS.merchant}');
INSERT INTO public.inventory_levels (id, listing_id, organization_id, organization_type, store_id, on_hand, reserved, version)
VALUES
  ('${IDS.sameInventory}', '${IDS.sameListing}', '${IDS.organization}', 'merchant', '${IDS.store}', 5, 0, 1),
  ('${IDS.differentInventory}', '${IDS.differentListing}', '${IDS.organization}', 'merchant', '${IDS.store}', 5, 0, 1),
  ('${IDS.rollbackInventoryA}', '${IDS.rollbackListingA}', '${IDS.organization}', 'merchant', '${IDS.store}', 5, 0, 1),
  ('${IDS.rollbackInventoryB}', '${IDS.rollbackListingB}', '${IDS.organization}', 'merchant', '${IDS.store}', 0, 0, 1);
INSERT INTO public.secondhand_units (id, listing_id, product_kind, synthetic_serial_reference, condition_code, defect_code, battery_health_percent, warranty_days, status, version)
VALUES ('${IDS.usedUnit}', '${IDS.usedListing}', 'secondhand', 'SYN-UNIT-P5-CONCURRENT', 'good', 'cosmetic_wear', 90, 30, 'available', 1);
INSERT INTO public.carts (id, owner_user_id, status, version)
VALUES
  ('${IDS.cartA}', '${IDS.actorA}', 'active', 1),
  ('${IDS.cartB}', '${IDS.actorB}', 'active', 1),
  ('${IDS.cartC}', '${IDS.actorC}', 'active', 1),
  ('${IDS.cartD}', '${IDS.actorD}', 'active', 1),
  ('${IDS.cartE}', '${IDS.actorE}', 'active', 1);
INSERT INTO public.cart_items (cart_id, owner_user_id, listing_id, quantity, version)
VALUES
  ('${IDS.cartA}', '${IDS.actorA}', '${IDS.sameListing}', 1, 1),
  ('${IDS.cartB}', '${IDS.actorB}', '${IDS.differentListing}', 1, 1),
  ('${IDS.cartC}', '${IDS.actorC}', '${IDS.usedListing}', 1, 1),
  ('${IDS.cartD}', '${IDS.actorD}', '${IDS.usedListing}', 1, 1),
  ('${IDS.cartE}', '${IDS.actorE}', '${IDS.rollbackListingA}', 1, 1),
  ('${IDS.cartE}', '${IDS.actorE}', '${IDS.rollbackListingB}', 1, 1);
`

function claimsSql(userId, email) {
  return `
DO $claims$
BEGIN
  PERFORM pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', '${userId}', 'email', '${email}', 'is_anonymous', false,
      'amr', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'method', 'otp',
          'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
        )
      )
    )::text,
    true
  );
END
$claims$;
`
}

function checkoutSql({ applicationName, userId, email, key, delivery }) {
  return `
BEGIN;
SET LOCAL application_name = '${applicationName}';
SET LOCAL statement_timeout = '12s';
SET LOCAL lock_timeout = '8s';
${claimsSql(userId, email)}
SET LOCAL ROLE rebuy_business_executor;
SELECT batch_id::text || '|' || synthetic_order_reference || '|' || order_status
  || '|' || inventory_status || '|' || currency_code || '|' || total_cents::text
  || '|' || order_version::text
FROM private.checkout_cart_impl(1, '${delivery}', '${key}');
COMMIT;
`
}

function blockerSql(lockValue) {
  return `
BEGIN;
SET LOCAL statement_timeout = '12s';
SELECT pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('${lockValue}', 0));
SELECT 'LOCK_READY';
SELECT pg_catalog.pg_sleep(5);
COMMIT;
`
}

async function waitForBlocker(blocker) {
  const deadline = Date.now() + 10_000
  while (!blocker.readStdout().includes('LOCK_READY')) {
    if (Date.now() >= deadline) throw new Error('blocker_lock_timeout')
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
}

async function waitForBothDatabaseLocks(applicationNames) {
  const deadline = Date.now() + 3_500
  const names = sqlList(applicationNames)
  while (Date.now() < deadline) {
    const waiting = await runAdmin(
      `SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE application_name IN (${names}) AND wait_event_type = 'Lock';`,
      'wait_for_both_database_locks',
    )
    if (waiting === '2') return
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
  throw new Error('database_lock_barrier_timeout')
}

async function runContendedPair(lockValue, attempts) {
  const blocker = startPsql(blockerSql(lockValue))
  await waitForBlocker(blocker)
  const workers = attempts.map((attempt) => startPsql(checkoutSql(attempt)).result)
  await waitForBothDatabaseLocks(attempts.map((attempt) => attempt.applicationName))
  const [blockerResult, results] = await Promise.all([
    blocker.result,
    Promise.all(workers),
  ])
  assert.equal(blockerResult.signal, null, 'blocker:signal')
  assert.equal(blockerResult.code, 0, `blocker:exit\n${blockerResult.stderr}`)
  return results
}

function assertClean(state) {
  for (const [key, value] of Object.entries(state)) {
    assert.equal(value, 0, `cleanup:${key}`)
  }
}

let failureStage = 'setup'
let primaryError
let cleanupError
try {
  await runAdmin(setupSql, 'setup')

  failureStage = 'same_key_checkout'
  const sameAttempt = {
    applicationName: 'p5_same_key_worker_a',
    userId: IDS.actorA,
    email: 'p5-concurrency-a@rebuy.test',
    key: IDS.sameKey,
    delivery: 'synthetic://delivery/p5-same',
  }
  const sameResults = await runContendedPair(`${IDS.actorA}:active-cart`, [
    sameAttempt,
    { ...sameAttempt, applicationName: 'p5_same_key_worker_b' },
  ])
  for (const result of sameResults) {
    assert.equal(result.signal, null, 'same_key:signal')
    assert.equal(result.code, 0, `same_key:exit\n${result.stderr}`)
  }
  assert.equal(sameResults[0].stdout.trim(), sameResults[1].stdout.trim(), 'same_key:stable_result')
  const sameState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'batches', (SELECT count(*) FROM public.order_batches WHERE buyer_user_id = '${IDS.actorA}'),
      'suborders', (SELECT count(*) FROM public.merchant_orders WHERE buyer_user_id = '${IDS.actorA}'),
      'items', (SELECT count(*) FROM public.order_items WHERE buyer_user_id = '${IDS.actorA}'),
      'events', (SELECT count(*) FROM public.order_events WHERE buyer_user_id = '${IDS.actorA}'),
      'keys', (SELECT count(*) FROM public.p5_idempotency_keys WHERE actor_user_id = '${IDS.actorA}'),
      'reserved', (SELECT reserved FROM public.inventory_levels WHERE id = '${IDS.sameInventory}')
    )::text;
  `, 'same_key_state'))
  assert.deepEqual(sameState, { batches: 1, suborders: 1, items: 1, events: 1, keys: 1, reserved: 1 })

  failureStage = 'different_key_same_cart'
  const differentResults = await runContendedPair(`${IDS.actorB}:active-cart`, [
    { applicationName: 'p5_different_key_worker_a', userId: IDS.actorB, email: 'p5-concurrency-b@rebuy.test', key: IDS.differentKeyA, delivery: 'synthetic://delivery/p5-double' },
    { applicationName: 'p5_different_key_worker_b', userId: IDS.actorB, email: 'p5-concurrency-b@rebuy.test', key: IDS.differentKeyB, delivery: 'synthetic://delivery/p5-double' },
  ])
  assert.equal(differentResults.filter((result) => result.code === 0).length, 1, 'different_key:one_success')
  assert.equal(differentResults.filter((result) => result.code !== 0).length, 1, 'different_key:one_rejection')
  assert.match(differentResults.find((result) => result.code !== 0).stderr, /ERROR:\s+cart_version_conflict/, 'different_key:finite_conflict')
  assert.doesNotMatch(differentResults.find((result) => result.code !== 0).stderr, /deadlock detected|statement timeout|lock timeout/i, 'different_key:no_lock_failure')
  const differentState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'batches', (SELECT count(*) FROM public.order_batches WHERE buyer_user_id = '${IDS.actorB}'),
      'events', (SELECT count(*) FROM public.order_events WHERE buyer_user_id = '${IDS.actorB}'),
      'keys', (SELECT count(*) FROM public.p5_idempotency_keys WHERE actor_user_id = '${IDS.actorB}'),
      'reserved', (SELECT reserved FROM public.inventory_levels WHERE id = '${IDS.differentInventory}')
    )::text;
  `, 'different_key_state'))
  assert.deepEqual(differentState, { batches: 1, events: 1, keys: 1, reserved: 1 })

  failureStage = 'secondhand_unique_winner'
  const usedResults = await runContendedPair(IDS.usedListing, [
    { applicationName: 'p5_used_worker_a', userId: IDS.actorC, email: 'p5-concurrency-c@rebuy.test', key: IDS.usedKeyA, delivery: 'synthetic://delivery/p5-used-a' },
    { applicationName: 'p5_used_worker_b', userId: IDS.actorD, email: 'p5-concurrency-d@rebuy.test', key: IDS.usedKeyB, delivery: 'synthetic://delivery/p5-used-b' },
  ])
  assert.equal(usedResults.filter((result) => result.code === 0).length, 1, 'used:one_success')
  assert.equal(usedResults.filter((result) => result.code !== 0).length, 1, 'used:one_rejection')
  assert.match(
    usedResults.find((result) => result.code !== 0).stderr,
    /ERROR:\s+(?:inventory_version_conflict|checkout_item_not_purchasable|catalog_listing_not_available)/,
    'used:finite_inventory_conflict',
  )
  assert.doesNotMatch(usedResults.find((result) => result.code !== 0).stderr, /deadlock detected|statement timeout|lock timeout/i, 'used:no_lock_failure')
  const usedState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'status', (SELECT status FROM public.secondhand_units WHERE id = '${IDS.usedUnit}'),
      'batches', (SELECT count(*) FROM public.order_batches WHERE buyer_user_id IN ('${IDS.actorC}', '${IDS.actorD}')),
      'events', (SELECT count(*) FROM public.order_events WHERE buyer_user_id IN ('${IDS.actorC}', '${IDS.actorD}')),
      'keys', (SELECT count(*) FROM public.p5_idempotency_keys WHERE actor_user_id IN ('${IDS.actorC}', '${IDS.actorD}'))
    )::text;
  `, 'used_state'))
  assert.deepEqual(usedState, { status: 'reserved', batches: 1, events: 1, keys: 1 })

  failureStage = 'multi_item_atomic_rollback'
  const rollbackResult = await startPsql(checkoutSql({
    applicationName: 'p5_rollback_worker',
    userId: IDS.actorE,
    email: 'p5-concurrency-e@rebuy.test',
    key: IDS.rollbackKey,
    delivery: 'synthetic://delivery/p5-rollback',
  })).result
  assert.notEqual(rollbackResult.code, 0, 'rollback:rejected')
  assert.match(
    rollbackResult.stderr,
    /ERROR:\s+(?:checkout_item_not_purchasable|catalog_listing_not_available)/,
    `rollback:finite_failure\n${rollbackResult.stderr}`,
  )
  const rollbackState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'batches', (SELECT count(*) FROM public.order_batches WHERE buyer_user_id = '${IDS.actorE}'),
      'events', (SELECT count(*) FROM public.order_events WHERE buyer_user_id = '${IDS.actorE}'),
      'keys', (SELECT count(*) FROM public.p5_idempotency_keys WHERE actor_user_id = '${IDS.actorE}'),
      'cart_status', (SELECT status FROM public.carts WHERE id = '${IDS.cartE}'),
      'cart_items', (SELECT count(*) FROM public.cart_items WHERE cart_id = '${IDS.cartE}'),
      'first_reserved', (SELECT reserved FROM public.inventory_levels WHERE id = '${IDS.rollbackInventoryA}'),
      'first_events', (SELECT count(*) FROM public.inventory_events WHERE listing_id = '${IDS.rollbackListingA}')
    )::text;
  `, 'rollback_state'))
  assert.deepEqual(rollbackState, { batches: 0, events: 0, keys: 0, cart_status: 'active', cart_items: 2, first_reserved: 0, first_events: 0 })
} catch (error) {
  primaryError = new Error(`P5 concurrency failed at ${failureStage}: ${error.message}`, { cause: error })
} finally {
  await Promise.allSettled([...active])
  try {
    await runAdmin(cleanupSql, 'cleanup')
    const state = JSON.parse(await runAdmin(`
      SELECT pg_catalog.jsonb_build_object(
        'users', (SELECT count(*) FROM auth.users WHERE id IN (${sqlList(users)})),
        'profiles', (SELECT count(*) FROM public.profiles WHERE user_id IN (${sqlList(users)})),
        'organizations', (SELECT count(*) FROM public.organizations WHERE id = '${IDS.organization}'),
        'stores', (SELECT count(*) FROM public.stores WHERE id = '${IDS.store}'),
        'products', (SELECT count(*) FROM public.products WHERE id IN (${sqlList(products)})),
        'variants', (SELECT count(*) FROM public.product_variants WHERE product_id IN (${sqlList(products)})),
        'listings', (SELECT count(*) FROM public.listings WHERE id IN (${sqlList(listings)})),
        'prices', (SELECT count(*) FROM public.listing_prices WHERE listing_id IN (${sqlList(listings)})),
        'inventory_levels', (SELECT count(*) FROM public.inventory_levels WHERE listing_id IN (${sqlList(listings)})),
        'secondhand_units', (SELECT count(*) FROM public.secondhand_units WHERE listing_id IN (${sqlList(listings)})),
        'inventory_events', (SELECT count(*) FROM public.inventory_events WHERE listing_id IN (${sqlList(listings)})),
        'carts', (SELECT count(*) FROM public.carts WHERE id IN (${sqlList(carts)})),
        'batches', (SELECT count(*) FROM public.order_batches WHERE buyer_user_id IN (${sqlList(users)})),
        'p4_keys', (SELECT count(*) FROM public.p4_idempotency_keys WHERE actor_user_id IN (${sqlList(users)})),
        'p5_keys', (SELECT count(*) FROM public.p5_idempotency_keys WHERE actor_user_id IN (${sqlList(users)})),
        'postgres_executor_membership', (SELECT CASE WHEN pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET') THEN 1 ELSE 0 END),
        'executor_postgres_membership_total', (
          SELECT count(*) FROM pg_catalog.pg_auth_members AS am
          JOIN pg_catalog.pg_roles AS granted_role ON granted_role.oid = am.roleid
          JOIN pg_catalog.pg_roles AS member_role ON member_role.oid = am.member
          WHERE granted_role.rolname = 'rebuy_business_executor' AND member_role.rolname = 'postgres'
        ),
        'supabase_admin_executor_bootstrap', (
          SELECT count(*) FROM pg_catalog.pg_auth_members AS am
          JOIN pg_catalog.pg_roles AS granted_role ON granted_role.oid = am.roleid
          JOIN pg_catalog.pg_roles AS member_role ON member_role.oid = am.member
          JOIN pg_catalog.pg_roles AS grantor_role ON grantor_role.oid = am.grantor
          WHERE granted_role.rolname = 'rebuy_business_executor'
            AND member_role.rolname = 'postgres'
            AND grantor_role.rolname = 'supabase_admin'
            AND am.admin_option AND NOT am.inherit_option AND NOT am.set_option
        )
      )::text;
    `, 'cleanup_verification'))
    assert.equal(state.supabase_admin_executor_bootstrap, 1, 'cleanup:supabase_admin_executor_bootstrap')
    assert.equal(state.executor_postgres_membership_total, 1, 'cleanup:executor_postgres_membership_total')
    delete state.supabase_admin_executor_bootstrap
    delete state.executor_postgres_membership_total
    assertClean(state)
  } catch (error) {
    cleanupError = error
  }
}

if (primaryError || cleanupError) {
  console.error(`P5_CHECKOUT_CONCURRENCY_FAIL:${failureStage}:${cleanupError ? 'cleanup_fail' : 'cleanup_pass'}`)
  if (primaryError) console.error(primaryError.message)
  if (cleanupError) console.error(`P5 cleanup failed: ${cleanupError.message}`)
  process.exitCode = 1
} else {
  console.log('P5_CHECKOUT_CONCURRENCY_PASS')
}
