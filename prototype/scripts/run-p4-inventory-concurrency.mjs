import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'

const DB_CONTAINER = 'supabase_db_rebuy-g2-a1-e2a-local-email-otp-exec'
const IDS = {
  actorA: '40000000-0000-4000-8000-000000000001',
  actorB: '40000000-0000-4000-8000-000000000002',
  merchant: '40000000-0000-4000-8000-000000000003',
  organization: '40000000-0000-4000-8000-000000000101',
  store: '40000000-0000-4000-8000-000000000102',
  standardProductA: '40000000-0000-4000-8000-000000000201',
  standardVariantA: '40000000-0000-4000-8000-000000000202',
  standardListingA: '40000000-0000-4000-8000-000000000203',
  standardInventoryA: '40000000-0000-4000-8000-000000000204',
  standardProductB: '40000000-0000-4000-8000-000000000211',
  standardVariantB: '40000000-0000-4000-8000-000000000212',
  standardListingB: '40000000-0000-4000-8000-000000000213',
  standardInventoryB: '40000000-0000-4000-8000-000000000214',
  usedProduct: '40000000-0000-4000-8000-000000000221',
  usedVariant: '40000000-0000-4000-8000-000000000222',
  usedListing: '40000000-0000-4000-8000-000000000223',
  usedUnit: '40000000-0000-4000-8000-000000000224',
  sameKey: '40000000-0000-4000-8000-000000000301',
  standardKeyA: '40000000-0000-4000-8000-000000000302',
  standardKeyB: '40000000-0000-4000-8000-000000000303',
  usedKeyA: '40000000-0000-4000-8000-000000000304',
  usedKeyB: '40000000-0000-4000-8000-000000000305',
}

const users = [IDS.actorA, IDS.actorB, IDS.merchant]
const listings = [IDS.standardListingA, IDS.standardListingB, IDS.usedListing]
const products = [IDS.standardProductA, IDS.standardProductB, IDS.usedProduct]
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
  ('${IDS.actorA}', 'p4-concurrency-a@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.actorB}', 'p4-concurrency-b@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.merchant}', 'p4-concurrency-merchant@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated');
INSERT INTO public.organizations (id, organization_type, display_name, status, created_by)
VALUES ('${IDS.organization}', 'merchant', 'P4 Concurrency Merchant', 'active', '${IDS.merchant}');
INSERT INTO public.stores (id, organization_id, organization_type, display_name, slug, status, public_visibility)
VALUES ('${IDS.store}', '${IDS.organization}', 'merchant', 'P4 Concurrency Store', 'p4-concurrency-store', 'active', true);
INSERT INTO public.products (id, organization_id, organization_type, category_id, product_kind, internal_name, status, created_by)
VALUES
  ('${IDS.standardProductA}', '${IDS.organization}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P4 Same Key Item', 'active', '${IDS.merchant}'),
  ('${IDS.standardProductB}', '${IDS.organization}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P4 Oversell Item', 'active', '${IDS.merchant}'),
  ('${IDS.usedProduct}', '${IDS.organization}', 'merchant', '00000000-0000-4000-8000-000000000303', 'secondhand', 'P4 Unique Used Item', 'active', '${IDS.merchant}');
INSERT INTO public.product_variants (id, product_id, organization_id, organization_type, sku, unit_code, status)
VALUES
  ('${IDS.standardVariantA}', '${IDS.standardProductA}', '${IDS.organization}', 'merchant', 'SYN-SKU-CONCURRENT-A', 'unit', 'active'),
  ('${IDS.standardVariantB}', '${IDS.standardProductB}', '${IDS.organization}', 'merchant', 'SYN-SKU-CONCURRENT-B', 'unit', 'active'),
  ('${IDS.usedVariant}', '${IDS.usedProduct}', '${IDS.organization}', 'merchant', 'SYN-SKU-CONCURRENT-USED', 'unit', 'active');
INSERT INTO public.listings (id, organization_id, organization_type, store_id, product_id, variant_id, product_kind, slug, title, summary, status, version, published_at, created_by)
VALUES
  ('${IDS.standardListingA}', '${IDS.organization}', 'merchant', '${IDS.store}', '${IDS.standardProductA}', '${IDS.standardVariantA}', 'standard', 'p4-same-key-item', 'P4 Same Key Item', 'Synthetic same key concurrency item', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.standardListingB}', '${IDS.organization}', 'merchant', '${IDS.store}', '${IDS.standardProductB}', '${IDS.standardVariantB}', 'standard', 'p4-oversell-item', 'P4 Oversell Item', 'Synthetic oversell concurrency item', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.usedListing}', '${IDS.organization}', 'merchant', '${IDS.store}', '${IDS.usedProduct}', '${IDS.usedVariant}', 'secondhand', 'p4-unique-used-item', 'P4 Unique Used Item', 'Synthetic unique used concurrency item', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}');
INSERT INTO public.listing_prices (listing_id, organization_id, organization_type, store_id, audience, currency_code, unit_amount_cents, minimum_quantity, version, status, created_by)
VALUES
  ('${IDS.standardListingA}', '${IDS.organization}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1000, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.standardListingB}', '${IDS.organization}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1000, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.usedListing}', '${IDS.organization}', 'merchant', '${IDS.store}', 'retail', 'EUR', 2000, 1, 1, 'active', '${IDS.merchant}');
INSERT INTO public.inventory_levels (id, listing_id, organization_id, organization_type, store_id, on_hand, reserved, version)
VALUES
  ('${IDS.standardInventoryA}', '${IDS.standardListingA}', '${IDS.organization}', 'merchant', '${IDS.store}', 5, 0, 1),
  ('${IDS.standardInventoryB}', '${IDS.standardListingB}', '${IDS.organization}', 'merchant', '${IDS.store}', 5, 0, 1);
INSERT INTO public.secondhand_units (id, listing_id, product_kind, synthetic_serial_reference, condition_code, defect_code, battery_health_percent, warranty_days, status, version)
VALUES ('${IDS.usedUnit}', '${IDS.usedListing}', 'secondhand', 'SYN-UNIT-CONCURRENT-USED', 'good', 'cosmetic_wear', 90, 30, 'available', 1);
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

function reserveSql({ applicationName, userId, email, listingId, key, orderRef }) {
  return `
BEGIN;
SET LOCAL application_name = '${applicationName}';
SET LOCAL statement_timeout = '12s';
SET LOCAL lock_timeout = '8s';
${claimsSql(userId, email)}
SET LOCAL ROLE rebuy_business_executor;
SELECT inventory_status || '|' || available_quantity::text || '|' || inventory_version::text
FROM private.change_inventory_reservation_impl(
  '${listingId}', ${listingId === IDS.usedListing ? 1 : 4}, 'reserve', 1,
  '${orderRef}', '${key}'
);
COMMIT;
`
}

function blockerSql(listingId) {
  return `
BEGIN;
SET LOCAL statement_timeout = '12s';
SELECT pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('${listingId}', 0)
);
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

async function runContendedPair(listingId, attempts) {
  const blocker = startPsql(blockerSql(listingId))
  await waitForBlocker(blocker)
  const workers = attempts.map((attempt) => startPsql(reserveSql(attempt)).result)
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

  failureStage = 'same_key_standard_reservation'
  const sameAttempt = {
    applicationName: 'p4_same_key_worker_a',
    userId: IDS.actorA,
    email: 'p4-concurrency-a@rebuy.test',
    listingId: IDS.standardListingA,
    key: IDS.sameKey,
    orderRef: 'SYN-ORDER-CONCURRENT-SAME',
  }
  const sameResults = await runContendedPair(IDS.standardListingA, [
    sameAttempt,
    { ...sameAttempt, applicationName: 'p4_same_key_worker_b' },
  ])
  for (const result of sameResults) {
    assert.equal(result.signal, null, 'same_key:signal')
    assert.equal(result.code, 0, `same_key:exit\n${result.stderr}`)
  }
  assert.equal(sameResults[0].stdout.trim(), sameResults[1].stdout.trim(), 'same_key:stable_result')
  assert.equal(sameResults[0].stdout.trim(), 'reserved|1|2', 'same_key:result')
  const sameState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'on_hand', on_hand, 'reserved', reserved, 'version', version,
      'events', (SELECT count(*) FROM public.inventory_events WHERE listing_id = '${IDS.standardListingA}'),
      'keys', (SELECT count(*) FROM public.p4_idempotency_keys WHERE actor_user_id = '${IDS.actorA}' AND idempotency_key = '${IDS.sameKey}')
    )::text FROM public.inventory_levels WHERE id = '${IDS.standardInventoryA}';
  `, 'same_key_state'))
  assert.deepEqual(sameState, { on_hand: 5, reserved: 4, version: 2, events: 1, keys: 1 })

  failureStage = 'different_key_standard_oversell'
  const standardResults = await runContendedPair(IDS.standardListingB, [
    { applicationName: 'p4_standard_worker_a', userId: IDS.actorA, email: 'p4-concurrency-a@rebuy.test', listingId: IDS.standardListingB, key: IDS.standardKeyA, orderRef: 'SYN-ORDER-CONCURRENT-A' },
    { applicationName: 'p4_standard_worker_b', userId: IDS.actorB, email: 'p4-concurrency-b@rebuy.test', listingId: IDS.standardListingB, key: IDS.standardKeyB, orderRef: 'SYN-ORDER-CONCURRENT-B' },
  ])
  assert.equal(standardResults.filter((result) => result.code === 0).length, 1, 'standard:one_success')
  assert.equal(standardResults.filter((result) => result.code !== 0).length, 1, 'standard:one_rejection')
  assert.match(
    standardResults.find((result) => result.code !== 0).stderr,
    /ERROR:\s+inventory_version_conflict/,
    'standard:stale_version_conflict',
  )
  assert.doesNotMatch(
    standardResults.find((result) => result.code !== 0).stderr,
    /deadlock detected|statement timeout|lock timeout/i,
    'standard:no_lock_failure',
  )
  const standardState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'on_hand', on_hand, 'reserved', reserved, 'available', on_hand - reserved,
      'version', version,
      'events', (SELECT count(*) FROM public.inventory_events WHERE listing_id = '${IDS.standardListingB}')
    )::text FROM public.inventory_levels WHERE id = '${IDS.standardInventoryB}';
  `, 'standard_state'))
  assert.deepEqual(standardState, { on_hand: 5, reserved: 4, available: 1, version: 2, events: 1 })

  failureStage = 'different_key_secondhand_unique_winner'
  const usedResults = await runContendedPair(IDS.usedListing, [
    { applicationName: 'p4_secondhand_worker_a', userId: IDS.actorA, email: 'p4-concurrency-a@rebuy.test', listingId: IDS.usedListing, key: IDS.usedKeyA, orderRef: 'SYN-ORDER-CONCURRENT-USED-A' },
    { applicationName: 'p4_secondhand_worker_b', userId: IDS.actorB, email: 'p4-concurrency-b@rebuy.test', listingId: IDS.usedListing, key: IDS.usedKeyB, orderRef: 'SYN-ORDER-CONCURRENT-USED-B' },
  ])
  assert.equal(usedResults.filter((result) => result.code === 0).length, 1, 'used:one_success')
  assert.equal(usedResults.filter((result) => result.code !== 0).length, 1, 'used:one_rejection')
  assert.match(
    usedResults.find((result) => result.code !== 0).stderr,
    /ERROR:\s+inventory_version_conflict/,
    'used:stale_version_conflict',
  )
  assert.doesNotMatch(
    usedResults.find((result) => result.code !== 0).stderr,
    /deadlock detected|statement timeout|lock timeout/i,
    'used:no_lock_failure',
  )
  const usedState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'status', status, 'version', version,
      'events', (SELECT count(*) FROM public.inventory_events WHERE listing_id = '${IDS.usedListing}')
    )::text FROM public.secondhand_units WHERE id = '${IDS.usedUnit}';
  `, 'used_state'))
  assert.deepEqual(usedState, { status: 'reserved', version: 2, events: 1 })

} catch (error) {
  primaryError = new Error(`P4 concurrency failed at ${failureStage}: ${error.message}`, { cause: error })
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
        'tiers', (SELECT count(*) FROM public.listing_price_tiers WHERE listing_id IN (${sqlList(listings)})),
        'inventory_levels', (SELECT count(*) FROM public.inventory_levels WHERE listing_id IN (${sqlList(listings)})),
        'secondhand_units', (SELECT count(*) FROM public.secondhand_units WHERE listing_id IN (${sqlList(listings)})),
        'catalog_events', (SELECT count(*) FROM public.catalog_events WHERE listing_id IN (${sqlList(listings)})),
        'inventory_events', (SELECT count(*) FROM public.inventory_events WHERE listing_id IN (${sqlList(listings)})),
        'keys', (SELECT count(*) FROM public.p4_idempotency_keys WHERE actor_user_id IN (${sqlList(users)})),
        'postgres_executor_membership', (SELECT CASE WHEN pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET') THEN 1 ELSE 0 END),
        'executor_postgres_membership_total', (
          SELECT count(*) FROM pg_catalog.pg_auth_members AS am
          JOIN pg_catalog.pg_roles AS granted_role ON granted_role.oid = am.roleid
          JOIN pg_catalog.pg_roles AS member_role ON member_role.oid = am.member
          WHERE granted_role.rolname = 'rebuy_business_executor'
            AND member_role.rolname = 'postgres'
        ),
        'postgres_grantor_executor_membership', (
          SELECT count(*) FROM pg_catalog.pg_auth_members AS am
          JOIN pg_catalog.pg_roles AS granted_role ON granted_role.oid = am.roleid
          JOIN pg_catalog.pg_roles AS member_role ON member_role.oid = am.member
          JOIN pg_catalog.pg_roles AS grantor_role ON grantor_role.oid = am.grantor
          WHERE granted_role.rolname = 'rebuy_business_executor'
            AND member_role.rolname = 'postgres'
            AND grantor_role.rolname = 'postgres'
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
    assert.equal(
      state.supabase_admin_executor_bootstrap,
      1,
      'cleanup:supabase_admin_executor_bootstrap',
    )
    assert.equal(
      state.executor_postgres_membership_total,
      1,
      'cleanup:executor_postgres_membership_total',
    )
    delete state.supabase_admin_executor_bootstrap
    delete state.executor_postgres_membership_total
    assertClean(state)
  } catch (error) {
    cleanupError = error
  }
}

if (primaryError || cleanupError) {
  console.error(
    `P4_INVENTORY_CONCURRENCY_FAIL:${failureStage}:${cleanupError ? 'cleanup_fail' : 'cleanup_pass'}`,
  )
  process.exitCode = 1
} else {
  console.log('P4_INVENTORY_CONCURRENCY_PASS')
}
