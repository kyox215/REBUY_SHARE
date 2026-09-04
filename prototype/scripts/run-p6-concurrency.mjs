import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'

const DB_CONTAINER = 'supabase_db_rebuy-g2-a1-e2a-local-email-otp-exec'
const IDS = {
  merchant: '61000000-0000-4000-8000-000000000001',
  sameBuyer: '61000000-0000-4000-8000-000000000002',
  rejectBuyer: '61000000-0000-4000-8000-000000000003',
  completeBuyer: '61000000-0000-4000-8000-000000000004',
  cancelBuyer: '61000000-0000-4000-8000-000000000005',
  organization: '61000000-0000-4000-8000-000000000101',
  store: '61000000-0000-4000-8000-000000000102',
  membership: '61000000-0000-4000-8000-000000000103',
  scope: '61000000-0000-4000-8000-000000000104',
  secondStore: '61000000-0000-4000-8000-000000000105',
  product: '61000000-0000-4000-8000-000000000201',
  variant: '61000000-0000-4000-8000-000000000202',
  listing: '61000000-0000-4000-8000-000000000203',
  inventory: '61000000-0000-4000-8000-000000000204',
  secondProduct: '61000000-0000-4000-8000-000000000205',
  secondVariant: '61000000-0000-4000-8000-000000000206',
  secondListing: '61000000-0000-4000-8000-000000000207',
  secondInventory: '61000000-0000-4000-8000-000000000208',
  samePut: '61000000-0000-4000-8000-000000000301',
  sameCheckout: '61000000-0000-4000-8000-000000000302',
  rejectPut: '61000000-0000-4000-8000-000000000303',
  rejectCheckout: '61000000-0000-4000-8000-000000000304',
  completePut: '61000000-0000-4000-8000-000000000305',
  completeCheckout: '61000000-0000-4000-8000-000000000306',
  cancelPut: '61000000-0000-4000-8000-000000000307',
  cancelCheckout: '61000000-0000-4000-8000-000000000308',
  sameAccept: '61000000-0000-4000-8000-000000000401',
  sameShip: '61000000-0000-4000-8000-000000000402',
  sameComplete: '61000000-0000-4000-8000-000000000403',
  rejectA: '61000000-0000-4000-8000-000000000404',
  rejectB: '61000000-0000-4000-8000-000000000405',
  completeAccept: '61000000-0000-4000-8000-000000000406',
  completeShip: '61000000-0000-4000-8000-000000000407',
  completeComplete: '61000000-0000-4000-8000-000000000408',
  cancel: '61000000-0000-4000-8000-000000000409',
  afterSaleA: '61000000-0000-4000-8000-000000000410',
  afterSaleB: '61000000-0000-4000-8000-000000000411',
  reviewA: '61000000-0000-4000-8000-000000000412',
  reviewB: '61000000-0000-4000-8000-000000000413',
  adjust: '61000000-0000-4000-8000-000000000414',
  crossStoreAdjust: '61000000-0000-4000-8000-000000000415',
  crossSurfaceKey: '61000000-0000-4000-8000-000000000416',
  suspendAdjust: '61000000-0000-4000-8000-000000000417',
  suspendDenied: '61000000-0000-4000-8000-000000000418',
  revokeAdjust: '61000000-0000-4000-8000-000000000419',
  revokeDenied: '61000000-0000-4000-8000-000000000420',
}

const users = [IDS.merchant, IDS.sameBuyer, IDS.rejectBuyer,
  IDS.completeBuyer, IDS.cancelBuyer]
const sqlList = (values) => values.map((value) => `'${value}'`).join(', ')
const active = new Set()

function startPsql(sql) {
  const child = spawn('docker', [
    'exec', '-i', DB_CONTAINER, 'psql', '-X', '-q', '-v',
    'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres', '-A', '-t',
  ], { stdio: ['pipe', 'pipe', 'pipe'] })
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

function claimsSql(userId, email) {
  return `
DO $claims$
BEGIN
  PERFORM pg_catalog.set_config('request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', '${userId}', 'email', '${email}', 'is_anonymous', false,
      'amr', pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      ))
    )::text, true);
END
$claims$;
`
}

function userSql({ userId, email, applicationName, statement }) {
  return `
BEGIN;
SET LOCAL application_name = '${applicationName}';
SET LOCAL statement_timeout = '12s';
SET LOCAL lock_timeout = '8s';
${claimsSql(userId, email)}
SET LOCAL ROLE authenticated;
${statement}
COMMIT;
`
}

const cleanupSql = `
BEGIN;
UPDATE public.carts SET status = 'abandoned', checkout_batch_id = NULL
WHERE owner_user_id IN (${sqlList(users)}) AND status = 'checked_out';
DELETE FROM public.merchant_after_sale_cases
WHERE created_by IN (${sqlList(users)}) OR buyer_user_id IN (${sqlList(users)});
DELETE FROM public.merchant_operation_events WHERE actor_user_id IN (${sqlList(users)});
DELETE FROM public.p6_idempotency_keys WHERE actor_user_id IN (${sqlList(users)});
DELETE FROM public.order_events WHERE buyer_user_id IN (${sqlList(users)});
DELETE FROM public.order_items WHERE buyer_user_id IN (${sqlList(users)});
DELETE FROM public.merchant_orders WHERE buyer_user_id IN (${sqlList(users)});
DELETE FROM public.order_batches WHERE buyer_user_id IN (${sqlList(users)});
DELETE FROM public.p5_idempotency_keys WHERE actor_user_id IN (${sqlList(users)});
DELETE FROM public.cart_items WHERE owner_user_id IN (${sqlList(users)});
DELETE FROM public.carts WHERE owner_user_id IN (${sqlList(users)});
DELETE FROM public.p4_idempotency_keys WHERE actor_user_id IN (${sqlList(users)});
DELETE FROM public.inventory_events WHERE listing_id IN ('${IDS.listing}', '${IDS.secondListing}');
DELETE FROM public.catalog_events WHERE listing_id IN ('${IDS.listing}', '${IDS.secondListing}');
DELETE FROM public.listing_price_tiers WHERE listing_id IN ('${IDS.listing}', '${IDS.secondListing}');
DELETE FROM public.listing_prices WHERE listing_id IN ('${IDS.listing}', '${IDS.secondListing}');
DELETE FROM public.inventory_levels WHERE listing_id IN ('${IDS.listing}', '${IDS.secondListing}');
DELETE FROM public.listings WHERE id IN ('${IDS.listing}', '${IDS.secondListing}');
DELETE FROM public.product_variants WHERE id IN ('${IDS.variant}', '${IDS.secondVariant}');
DELETE FROM public.products WHERE id IN ('${IDS.product}', '${IDS.secondProduct}');
DELETE FROM public.membership_store_scopes WHERE id = '${IDS.scope}';
DELETE FROM public.memberships WHERE id = '${IDS.membership}';
DELETE FROM public.stores WHERE id IN ('${IDS.store}', '${IDS.secondStore}');
DELETE FROM public.organizations WHERE id = '${IDS.organization}';
DELETE FROM public.profiles WHERE user_id IN (${sqlList(users)});
DELETE FROM auth.users WHERE id IN (${sqlList(users)});
COMMIT;
`

const setupSql = `
${cleanupSql}
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, role, aud)
VALUES
  ('${IDS.merchant}', 'p6-concurrency-merchant@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.sameBuyer}', 'p6-concurrency-same@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.rejectBuyer}', 'p6-concurrency-reject@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.completeBuyer}', 'p6-concurrency-complete@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.cancelBuyer}', 'p6-concurrency-cancel@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated');
INSERT INTO public.organizations (id, organization_type, display_name, status, created_by)
VALUES ('${IDS.organization}', 'merchant', 'P6 Concurrency Merchant', 'active', '${IDS.merchant}');
INSERT INTO public.stores (id, organization_id, organization_type,
  display_name, slug, status, public_visibility)
VALUES
  ('${IDS.store}', '${IDS.organization}', 'merchant',
    'P6 Concurrency Store', 'p6-concurrency-store', 'active', true),
  ('${IDS.secondStore}', '${IDS.organization}', 'merchant',
    'P6 Concurrency Second Store', 'p6-concurrency-second-store', 'active', true);
INSERT INTO public.memberships (id, user_id, organization_id, organization_type,
  role_definition_id, role_version, status, valid_from)
VALUES ('${IDS.membership}', '${IDS.merchant}', '${IDS.organization}', 'merchant',
  '00000000-0000-4000-8000-000000000201', 1, 'active',
  pg_catalog.statement_timestamp() - INTERVAL '1 hour');
INSERT INTO public.membership_store_scopes (id, membership_id, organization_id,
  organization_type, store_id, scope_type, status)
VALUES ('${IDS.scope}', '${IDS.membership}', '${IDS.organization}', 'merchant',
  NULL, 'organization', 'active');
INSERT INTO public.products (id, organization_id, organization_type, category_id,
  product_kind, internal_name, status, created_by)
VALUES
  ('${IDS.product}', '${IDS.organization}', 'merchant',
    '00000000-0000-4000-8000-000000000301', 'standard',
    'P6 Concurrency Product', 'active', '${IDS.merchant}'),
  ('${IDS.secondProduct}', '${IDS.organization}', 'merchant',
    '00000000-0000-4000-8000-000000000301', 'standard',
    'P6 Concurrency Second Product', 'active', '${IDS.merchant}');
INSERT INTO public.product_variants (id, product_id, organization_id,
  organization_type, sku, unit_code, status)
VALUES
  ('${IDS.variant}', '${IDS.product}', '${IDS.organization}', 'merchant',
    'SYN-SKU-P6-CONCURRENCY', 'unit', 'active'),
  ('${IDS.secondVariant}', '${IDS.secondProduct}', '${IDS.organization}', 'merchant',
    'SYN-SKU-P6-CONCURRENCY-SECOND', 'unit', 'active');
INSERT INTO public.listings (id, organization_id, organization_type, store_id,
  product_id, variant_id, product_kind, slug, title, summary, status, version,
  published_at, created_by)
VALUES
  ('${IDS.listing}', '${IDS.organization}', 'merchant', '${IDS.store}',
    '${IDS.product}', '${IDS.variant}', 'standard', 'p6-concurrency-product',
    'P6 Concurrency Product', 'Synthetic P6 concurrency fixture', 'active', 1,
    pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.secondListing}', '${IDS.organization}', 'merchant', '${IDS.secondStore}',
    '${IDS.secondProduct}', '${IDS.secondVariant}', 'standard',
    'p6-concurrency-second-product', 'P6 Concurrency Second Product',
    'Synthetic P6 cross-store fixture', 'active', 1,
    pg_catalog.statement_timestamp(), '${IDS.merchant}');
INSERT INTO public.listing_prices (listing_id, organization_id,
  organization_type, store_id, audience, currency_code, unit_amount_cents,
  minimum_quantity, version, status, created_by)
VALUES
  ('${IDS.listing}', '${IDS.organization}', 'merchant', '${IDS.store}',
    'retail', 'EUR', 1000, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.secondListing}', '${IDS.organization}', 'merchant', '${IDS.secondStore}',
    'retail', 'EUR', 1200, 1, 1, 'active', '${IDS.merchant}');
INSERT INTO public.inventory_levels (id, listing_id, organization_id,
  organization_type, store_id, on_hand, reserved, version)
VALUES
  ('${IDS.inventory}', '${IDS.listing}', '${IDS.organization}', 'merchant',
    '${IDS.store}', 20, 0, 1),
  ('${IDS.secondInventory}', '${IDS.secondListing}', '${IDS.organization}', 'merchant',
    '${IDS.secondStore}', 7, 0, 1);
`

async function checkout(userId, email, putKey, checkoutKey, delivery) {
  const output = await runAdmin(userSql({
    userId, email, applicationName: `p6_checkout_${userId.slice(-4)}`,
    statement: `
SELECT cart_id::text || '|' || cart_version::text
FROM public.put_cart_item('${IDS.listing}', 1, NULL, NULL, '${putKey}');
SELECT batch_id::text || '|' || synthetic_order_reference
FROM public.checkout_cart(1, '${delivery}', '${checkoutKey}');`,
  }), `checkout_${userId}`)
  const line = output.split('\n').at(-1)
  assert.match(line, /^[0-9a-f-]{36}\|SYN-ORDER-/i)
  return line.split('|')[0]
}

function advanceSql({ applicationName, orderId, action, version, key,
  reason = null, shipment = null }) {
  const nullable = (value) => value === null ? 'NULL' : `'${value}'`
  return userSql({
    userId: IDS.merchant, email: 'p6-concurrency-merchant@rebuy.test',
    applicationName,
    statement: `SELECT order_status || '|' || inventory_status || '|' ||
      order_version::text || '|' || batch_status || '|' || batch_version::text
      FROM public.advance_my_merchant_order('${IDS.store}', '${orderId}',
        '${action}', ${nullable(reason)}, ${nullable(shipment)}, ${version}, '${key}');`,
  })
}

function blockerSql(lockExpression) {
  return `
BEGIN;
SET LOCAL statement_timeout = '12s';
${lockExpression}
SELECT 'LOCK_READY';
SELECT pg_catalog.pg_sleep(4);
COMMIT;
`
}

async function waitForBlocker(blocker) {
  const deadline = Date.now() + 8_000
  while (!blocker.readStdout().includes('LOCK_READY')) {
    if (Date.now() >= deadline) throw new Error('blocker_lock_timeout')
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
}

async function waitForLocks(applicationNames, expected) {
  const deadline = Date.now() + 2_500
  while (Date.now() < deadline) {
    const count = await runAdmin(`SELECT count(*) FROM pg_catalog.pg_stat_activity
      WHERE application_name IN (${sqlList(applicationNames)})
        AND wait_event_type = 'Lock';`, 'wait_for_database_locks')
    if (count === String(expected)) return
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
  throw new Error('database_lock_barrier_timeout')
}

async function contendedPair(blockSql, attempts) {
  const blocker = startPsql(blockSql)
  await waitForBlocker(blocker)
  const workers = attempts.map(({ sql }) => startPsql(sql))
  await waitForLocks(attempts.map(({ applicationName }) => applicationName), 2)
  const [blockerResult, workerResults] = await Promise.all([
    blocker.result, Promise.all(workers.map((worker) => worker.result)),
  ])
  assert.equal(blockerResult.code, 0, `blocker:exit\n${blockerResult.stderr}`)
  return workerResults
}

async function authorizationControlRace({ workerName, controllerName,
  workerStatement, controllerStatement }) {
  const blocker = startPsql(blockerSql(`SELECT pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('${IDS.listing}', 0));`))
  await waitForBlocker(blocker)
  const worker = startPsql(userSql({ userId: IDS.merchant,
    email: 'p6-concurrency-merchant@rebuy.test', applicationName: workerName,
    statement: workerStatement }))
  await waitForLocks([workerName], 1)
  const controller = startPsql(`
BEGIN;
SET LOCAL application_name = '${controllerName}';
SET LOCAL statement_timeout = '12s';
SET LOCAL lock_timeout = '8s';
${controllerStatement}
COMMIT;
`)
  await waitForLocks([controllerName], 1)
  const [blockerResult, workerResult, controllerResult] = await Promise.all([
    blocker.result, worker.result, controller.result,
  ])
  for (const [label, result] of [['blocker', blockerResult], ['worker', workerResult],
    ['controller', controllerResult]]) {
    assert.equal(result.signal, null, `${label}:signal`)
    assert.equal(result.code, 0, `${label}:exit\n${result.stderr}`)
    assert.doesNotMatch(result.stderr, /deadlock detected|statement timeout|lock timeout/i)
  }
  return workerResult.stdout.trim()
}

async function expectMerchantFailure(statement, pattern, label) {
  const result = await startPsql(userSql({ userId: IDS.merchant,
    email: 'p6-concurrency-merchant@rebuy.test', applicationName: `p6_${label}`,
    statement })).result
  assert.notEqual(result.code, 0, `${label}:unexpected_success`)
  assert.match(result.stderr, pattern, `${label}:error`)
  assert.doesNotMatch(result.stderr, /deadlock detected|statement timeout|lock timeout/i)
}

async function merchantOrderId(batchId) {
  return runAdmin(`SELECT id FROM public.merchant_orders WHERE batch_id = '${batchId}';`,
    `merchant_order_${batchId}`)
}

async function runMerchant(statement, label) {
  return runAdmin(userSql({
    userId: IDS.merchant, email: 'p6-concurrency-merchant@rebuy.test',
    applicationName: `p6_${label}`, statement,
  }), label)
}

let stage = 'setup'
let primaryError
let cleanupError
try {
  await runAdmin(setupSql, 'setup')
  const sameBatch = await checkout(IDS.sameBuyer, 'p6-concurrency-same@rebuy.test',
    IDS.samePut, IDS.sameCheckout, 'synthetic://delivery/p6-same')
  const rejectBatch = await checkout(IDS.rejectBuyer, 'p6-concurrency-reject@rebuy.test',
    IDS.rejectPut, IDS.rejectCheckout, 'synthetic://delivery/p6-reject')
  const completeBatch = await checkout(IDS.completeBuyer, 'p6-concurrency-complete@rebuy.test',
    IDS.completePut, IDS.completeCheckout, 'synthetic://delivery/p6-complete')
  const cancelBatch = await checkout(IDS.cancelBuyer, 'p6-concurrency-cancel@rebuy.test',
    IDS.cancelPut, IDS.cancelCheckout, 'synthetic://delivery/p6-cancel')
  const sameOrder = await merchantOrderId(sameBatch)
  const rejectOrder = await merchantOrderId(rejectBatch)
  const completeOrder = await merchantOrderId(completeBatch)

  await runAdmin(`UPDATE public.listings SET status = 'inactive'
    WHERE id = '${IDS.listing}';
    UPDATE public.stores SET public_visibility = false WHERE id = '${IDS.store}';`,
  'withdraw_catalog_visibility')

  stage = 'same_key_order_transition'
  const sameNames = ['p6_same_key_order_a', 'p6_same_key_order_b']
  const sameResults = await contendedPair(blockerSql(`SELECT pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('${sameBatch}', 0));`), sameNames.map((applicationName) => ({
    applicationName,
    sql: advanceSql({ applicationName, orderId: sameOrder, action: 'accept',
      version: 1, key: IDS.sameAccept }),
  })))
  for (const result of sameResults) assert.equal(result.code, 0, `same_key\n${result.stderr}`)
  assert.equal(sameResults[0].stdout.trim(), sameResults[1].stdout.trim(),
    'same key must replay a stable order result')
  assert.match(sameResults[0].stdout, /accepted\|reserved\|2/)
  const sameState = JSON.parse(await runAdmin(`SELECT pg_catalog.jsonb_build_object(
    'version', (SELECT version FROM public.merchant_orders WHERE id = '${sameOrder}'),
    'events', (SELECT count(*) FROM public.merchant_operation_events
      WHERE entity_id = '${sameOrder}' AND event_code = 'merchant_order.accepted'),
    'keys', (SELECT count(*) FROM public.p6_idempotency_keys
      WHERE actor_user_id = '${IDS.merchant}' AND idempotency_key = '${IDS.sameAccept}')
  )::text;`, 'same_key_state'))
  assert.deepEqual(sameState, { version: 2, events: 1, keys: 1 })

  await runMerchant(`SELECT * FROM public.advance_my_merchant_order('${IDS.store}',
    '${sameOrder}', 'ship', NULL, 'synthetic://shipment/p6-same', 2,
    '${IDS.sameShip}');`, 'same_ship')
  await runMerchant(`SELECT * FROM public.advance_my_merchant_order('${IDS.store}',
    '${sameOrder}', 'complete', NULL, NULL, 3, '${IDS.sameComplete}');`,
  'same_complete')

  stage = 'different_key_reject_transition'
  const rejectNames = ['p6_reject_order_a', 'p6_reject_order_b']
  const rejectResults = await contendedPair(blockerSql(`SELECT pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('${rejectBatch}', 0));`), [
    { applicationName: rejectNames[0], sql: advanceSql({ applicationName: rejectNames[0],
      orderId: rejectOrder, action: 'reject', version: 1, key: IDS.rejectA,
      reason: 'out_of_stock' }) },
    { applicationName: rejectNames[1], sql: advanceSql({ applicationName: rejectNames[1],
      orderId: rejectOrder, action: 'reject', version: 1, key: IDS.rejectB,
      reason: 'out_of_stock' }) },
  ])
  assert.equal(rejectResults.filter((result) => result.code === 0).length, 1)
  assert.equal(rejectResults.filter((result) => result.code !== 0).length, 1)
  assert.match(rejectResults.find((result) => result.code !== 0).stderr,
    /merchant_order_(?:version|state)_conflict/)
  assert.doesNotMatch(rejectResults.map((result) => result.stderr).join('\n'),
    /deadlock detected|statement timeout|lock timeout/i)

  stage = 'downlisted_complete_and_cancel'
  await runMerchant(`SELECT * FROM public.advance_my_merchant_order('${IDS.store}',
    '${completeOrder}', 'accept', NULL, NULL, 1, '${IDS.completeAccept}');`, 'complete_accept')
  await runMerchant(`SELECT * FROM public.advance_my_merchant_order('${IDS.store}',
    '${completeOrder}', 'ship', NULL, 'synthetic://shipment/p6-complete', 2,
    '${IDS.completeShip}');`, 'complete_ship')
  await runMerchant(`SELECT * FROM public.advance_my_merchant_order('${IDS.store}',
    '${completeOrder}', 'complete', NULL, NULL, 3, '${IDS.completeComplete}');`,
  'complete_complete')
  const cancelResult = await runAdmin(userSql({
    userId: IDS.cancelBuyer, email: 'p6-concurrency-cancel@rebuy.test',
    applicationName: 'p6_buyer_cancel',
    statement: `SELECT order_status || '|' || inventory_status || '|' || order_version
      FROM public.cancel_my_order_batch('${cancelBatch}', 1, '${IDS.cancel}');`,
  }), 'buyer_cancel')
  assert.match(cancelResult, /cancelled\|released\|2/)

  stage = 'after_sale_open_and_review_races'
  const afterNames = ['p6_after_sale_a', 'p6_after_sale_b']
  const afterResults = await contendedPair(blockerSql(`SELECT 1 FROM public.merchant_orders
    WHERE id = '${completeOrder}' FOR UPDATE;`), [
    ...afterNames.map((applicationName, index) => ({
      applicationName,
      sql: userSql({ userId: IDS.merchant,
        email: 'p6-concurrency-merchant@rebuy.test', applicationName,
        statement: `SELECT case_id::text || '|' || case_status
          FROM public.open_my_merchant_after_sale('${IDS.store}', '${completeOrder}',
          'damaged', '${index === 0 ? IDS.afterSaleA : IDS.afterSaleB}');`,
      }),
    })),
  ])
  assert.equal(afterResults.filter((result) => result.code === 0).length, 1)
  assert.equal(afterResults.filter((result) => result.code !== 0).length, 1)
  assert.match(afterResults.find((result) => result.code !== 0).stderr,
    /after_sale_already_exists/)
  const caseId = afterResults.find((result) => result.code === 0).stdout.trim().split('|')[0]
  assert.match(caseId, /^[0-9a-f-]{36}$/i)
  const reviewNames = ['p6_after_review_a', 'p6_after_review_b']
  const reviewResults = await contendedPair(blockerSql(`SELECT 1
    FROM public.merchant_after_sale_cases WHERE id = '${caseId}' FOR UPDATE;`), [
    ...reviewNames.map((applicationName, index) => ({
      applicationName,
      sql: userSql({ userId: IDS.merchant,
        email: 'p6-concurrency-merchant@rebuy.test', applicationName,
        statement: `SELECT case_status || '|' || case_version
          FROM public.review_my_merchant_after_sale('${IDS.store}', '${caseId}',
          'start_review', NULL, 1, '${index === 0 ? IDS.reviewA : IDS.reviewB}');`,
      }),
    })),
  ])
  assert.equal(reviewResults.filter((result) => result.code === 0).length, 1)
  assert.equal(reviewResults.filter((result) => result.code !== 0).length, 1)
  assert.match(reviewResults.find((result) => result.code !== 0).stderr,
    /after_sale_(?:version|state)_conflict/)

  stage = 'same_key_inventory_adjustment'
  const inventoryVersion = Number(await runAdmin(`SELECT version
    FROM public.inventory_levels WHERE id = '${IDS.inventory}';`, 'inventory_version'))
  const adjustNames = ['p6_inventory_adjust_a', 'p6_inventory_adjust_b']
  const adjustStatement = `SELECT on_hand::text || '|' || available::text || '|' ||
    inventory_version::text FROM public.adjust_my_merchant_inventory('${IDS.store}',
    '${IDS.listing}', 2, 'stock_received', ${inventoryVersion}, '${IDS.adjust}');`
  const adjustResults = await contendedPair(blockerSql(`SELECT pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('${IDS.listing}', 0));`), adjustNames.map((applicationName) => ({
    applicationName,
    sql: userSql({ userId: IDS.merchant,
      email: 'p6-concurrency-merchant@rebuy.test', applicationName,
      statement: adjustStatement }),
  })))
  for (const result of adjustResults) assert.equal(result.code, 0,
    `inventory_same_key\n${result.stderr}`)
  assert.equal(adjustResults[0].stdout.trim(), adjustResults[1].stdout.trim())
  const adjustState = JSON.parse(await runAdmin(`SELECT pg_catalog.jsonb_build_object(
    'version', version,
    'p4_events', (SELECT count(*) FROM public.inventory_events
      WHERE listing_id = '${IDS.listing}' AND idempotency_key = '${IDS.adjust}'),
    'p6_events', (SELECT count(*) FROM public.merchant_operation_events
      WHERE entity_id = '${IDS.listing}' AND event_code = 'inventory.adjusted'
        AND reason_code = 'stock_received' AND idempotency_key = '${IDS.adjust}')
  )::text FROM public.inventory_levels WHERE id = '${IDS.inventory}';`, 'adjust_state'))
  assert.deepEqual(adjustState, { version: inventoryVersion + 1, p4_events: 1, p6_events: 1 })

  stage = 'cross_store_inventory_scope'
  await expectMerchantFailure(`SELECT * FROM public.adjust_my_merchant_inventory(
    '${IDS.store}', '${IDS.secondListing}', 1, 'stock_correction', 1,
    '${IDS.crossStoreAdjust}');`, /merchant_inventory_scope_forbidden/,
  'cross_store_inventory_scope')
  const crossStoreState = JSON.parse(await runAdmin(`SELECT pg_catalog.jsonb_build_object(
    'version', version,
    'on_hand', on_hand,
    'p4_events', (SELECT count(*) FROM public.inventory_events
      WHERE listing_id = '${IDS.secondListing}'),
    'p6_events', (SELECT count(*) FROM public.merchant_operation_events
      WHERE entity_id = '${IDS.secondListing}'),
    'p4_keys', (SELECT count(*) FROM public.p4_idempotency_keys
      WHERE actor_user_id = '${IDS.merchant}'
        AND idempotency_key = '${IDS.crossStoreAdjust}')
  )::text FROM public.inventory_levels WHERE id = '${IDS.secondInventory}';`,
  'cross_store_state'))
  assert.deepEqual(crossStoreState,
    { version: 1, on_hand: 7, p4_events: 0, p6_events: 0, p4_keys: 0 })

  stage = 'cross_surface_actor_key_order'
  const crossSurfaceInventoryVersion = Number(await runAdmin(`SELECT version
    FROM public.inventory_levels WHERE id = '${IDS.inventory}';`,
  'cross_surface_inventory_version'))
  const crossSurfaceNames = ['p6_cross_surface_adjust', 'p4_cross_surface_catalog']
  const crossSurfaceResults = await contendedPair(blockerSql(
    `SELECT pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('${IDS.listing}', 0));`), [
    {
      applicationName: crossSurfaceNames[0],
      sql: userSql({ userId: IDS.merchant,
        email: 'p6-concurrency-merchant@rebuy.test',
        applicationName: crossSurfaceNames[0],
        statement: `SELECT inventory_version
          FROM public.adjust_my_merchant_inventory('${IDS.store}', '${IDS.listing}',
          1, 'stock_correction', ${crossSurfaceInventoryVersion},
          '${IDS.crossSurfaceKey}');`,
      }),
    },
    {
      applicationName: crossSurfaceNames[1],
      sql: userSql({ userId: IDS.merchant,
        email: 'p6-concurrency-merchant@rebuy.test',
        applicationName: crossSurfaceNames[1],
        statement: `SELECT listing_version FROM public.upsert_catalog_listing(
          '${IDS.listing}', '${IDS.store}', 'electronics', 'standard',
          'P6 Concurrency Product', 'SYN-SKU-P6-CONCURRENCY',
          'p6-concurrency-product', 'P6 Concurrency Product',
          'Synthetic P6 concurrency fixture', 1000, NULL, NULL, '[]'::jsonb,
          NULL, NULL, NULL, NULL, NULL, NULL, false, 1,
          '${IDS.crossSurfaceKey}');`,
      }),
    },
  ])
  assert.equal(crossSurfaceResults.filter((result) => result.code === 0).length, 1)
  assert.equal(crossSurfaceResults.filter((result) => result.code !== 0).length, 1)
  assert.match(crossSurfaceResults.find((result) => result.code !== 0).stderr,
    /p4_idempotency_conflict/)
  assert.doesNotMatch(crossSurfaceResults.map((result) => result.stderr).join('\n'),
    /deadlock detected|statement timeout|lock timeout/i)

  stage = 'suspend_authorization_race'
  const suspendVersion = Number(await runAdmin(`SELECT version
    FROM public.inventory_levels WHERE id = '${IDS.inventory}';`, 'suspend_version'))
  const suspendOutput = await authorizationControlRace({
    workerName: 'p6_suspend_adjust_worker',
    controllerName: 'p6_suspend_controller',
    workerStatement: `SELECT inventory_version FROM public.adjust_my_merchant_inventory(
      '${IDS.store}', '${IDS.listing}', 1, 'cycle_count', ${suspendVersion},
      '${IDS.suspendAdjust}');`,
    controllerStatement: `UPDATE public.organizations SET status = 'suspended'
      WHERE id = '${IDS.organization}';
    UPDATE public.stores SET status = 'suspended', public_visibility = false
      WHERE id = '${IDS.store}';
    UPDATE public.memberships SET status = 'suspended'
      WHERE id = '${IDS.membership}';
    UPDATE public.membership_store_scopes SET status = 'suspended'
      WHERE id = '${IDS.scope}';`,
  })
  assert.equal(suspendOutput, String(suspendVersion + 1))
  await expectMerchantFailure(`SELECT * FROM public.adjust_my_merchant_inventory(
    '${IDS.store}', '${IDS.listing}', 1, 'cycle_count', ${suspendVersion + 1},
    '${IDS.suspendDenied}');`, /merchant_store_not_available/,
  'suspend_denied_after_commit')
  const suspendedState = JSON.parse(await runAdmin(`SELECT pg_catalog.jsonb_build_object(
    'version', (SELECT version FROM public.inventory_levels WHERE id = '${IDS.inventory}'),
    'denied_events', (SELECT count(*) FROM public.inventory_events
      WHERE idempotency_key = '${IDS.suspendDenied}'),
    'denied_p6_events', (SELECT count(*) FROM public.merchant_operation_events
      WHERE idempotency_key = '${IDS.suspendDenied}')
  )::text;`, 'suspended_state'))
  assert.deepEqual(suspendedState,
    { version: suspendVersion + 1, denied_events: 0, denied_p6_events: 0 })

  await runAdmin(`UPDATE public.organizations SET status = 'active'
      WHERE id = '${IDS.organization}';
    UPDATE public.stores SET status = 'active' WHERE id = '${IDS.store}';
    UPDATE public.memberships SET status = 'active' WHERE id = '${IDS.membership}';
    UPDATE public.membership_store_scopes SET status = 'active'
      WHERE id = '${IDS.scope}';`, 'restore_authorization_fixture')

  stage = 'revoke_authorization_race'
  const revokeVersion = suspendVersion + 1
  const revokeOutput = await authorizationControlRace({
    workerName: 'p6_revoke_adjust_worker',
    controllerName: 'p6_revoke_controller',
    workerStatement: `SELECT inventory_version FROM public.adjust_my_merchant_inventory(
      '${IDS.store}', '${IDS.listing}', 1, 'cycle_count', ${revokeVersion},
      '${IDS.revokeAdjust}');`,
    controllerStatement: `UPDATE public.memberships SET status = 'revoked'
      WHERE id = '${IDS.membership}';`,
  })
  assert.equal(revokeOutput, String(revokeVersion + 1))
  await expectMerchantFailure(`SELECT * FROM public.adjust_my_merchant_inventory(
    '${IDS.store}', '${IDS.listing}', 1, 'cycle_count', ${revokeVersion + 1},
    '${IDS.revokeDenied}');`, /merchant_scope_forbidden/,
  'revoke_denied_after_commit')
  const revokedState = JSON.parse(await runAdmin(`SELECT pg_catalog.jsonb_build_object(
    'version', (SELECT version FROM public.inventory_levels WHERE id = '${IDS.inventory}'),
    'denied_events', (SELECT count(*) FROM public.inventory_events
      WHERE idempotency_key = '${IDS.revokeDenied}'),
    'denied_p6_events', (SELECT count(*) FROM public.merchant_operation_events
      WHERE idempotency_key = '${IDS.revokeDenied}')
  )::text;`, 'revoked_state'))
  assert.deepEqual(revokedState,
    { version: revokeVersion + 1, denied_events: 0, denied_p6_events: 0 })
} catch (error) {
  primaryError = new Error(`P6 concurrency failed at ${stage}: ${error.message}`, { cause: error })
} finally {
  await Promise.allSettled([...active])
  try {
    await runAdmin(cleanupSql, 'cleanup')
    const state = JSON.parse(await runAdmin(`SELECT pg_catalog.jsonb_build_object(
      'users', (SELECT count(*) FROM auth.users WHERE id IN (${sqlList(users)})),
      'organization', (SELECT count(*) FROM public.organizations WHERE id = '${IDS.organization}'),
      'stores', (SELECT count(*) FROM public.stores
        WHERE id IN ('${IDS.store}', '${IDS.secondStore}')),
      'listings', (SELECT count(*) FROM public.listings
        WHERE id IN ('${IDS.listing}', '${IDS.secondListing}')),
      'orders', (SELECT count(*) FROM public.order_batches
        WHERE buyer_user_id IN (${sqlList(users)})),
      'p6_events', (SELECT count(*) FROM public.merchant_operation_events
        WHERE actor_user_id IN (${sqlList(users)}))
    )::text;`, 'cleanup_verification'))
    assert.deepEqual(state, { users: 0, organization: 0, stores: 0,
      listings: 0, orders: 0, p6_events: 0 })
  } catch (error) {
    cleanupError = error
  }
}

if (primaryError || cleanupError) {
  console.error(`P6_CONCURRENCY_FAIL:${stage}:${cleanupError ? 'cleanup_fail' : 'cleanup_pass'}`)
  if (primaryError) console.error(primaryError.message)
  if (cleanupError) console.error(`cleanup: ${cleanupError.message}`)
  process.exitCode = 1
} else {
  console.log('P6_CONCURRENCY_PASS')
}
