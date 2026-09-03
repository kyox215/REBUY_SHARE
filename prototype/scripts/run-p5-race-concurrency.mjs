import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'

const DB_CONTAINER = 'supabase_db_rebuy-g2-a1-e2a-local-email-otp-exec'
const IDS = {
  oversellA: '51000000-0000-4000-8000-000000000001',
  oversellB: '51000000-0000-4000-8000-000000000002',
  priceBuyer: '51000000-0000-4000-8000-000000000003',
  wholesaleBuyer: '51000000-0000-4000-8000-000000000004',
  cancelBuyer: '51000000-0000-4000-8000-000000000005',
  merchant: '51000000-0000-4000-8000-000000000006',
  reviewer: '51000000-0000-4000-8000-000000000007',
  merchantOrg: '51000000-0000-4000-8000-000000000101',
  wholesaleOrg: '51000000-0000-4000-8000-000000000102',
  platformOrg: '51000000-0000-4000-8000-000000000103',
  store: '51000000-0000-4000-8000-000000000111',
  wholesaleMembership: '51000000-0000-4000-8000-000000000121',
  reviewerMembership: '51000000-0000-4000-8000-000000000122',
  merchantMembership: '51000000-0000-4000-8000-000000000123',
  wholesaleScope: '51000000-0000-4000-8000-000000000131',
  merchantScope: '51000000-0000-4000-8000-000000000132',
  wholesaleApplication: '51000000-0000-4000-8000-000000000141',
  qualification: '51000000-0000-4000-8000-000000000142',
  oversellProduct: '51000000-0000-4000-8000-000000000201',
  oversellVariant: '51000000-0000-4000-8000-000000000202',
  oversellListing: '51000000-0000-4000-8000-000000000203',
  oversellInventory: '51000000-0000-4000-8000-000000000204',
  priceProduct: '51000000-0000-4000-8000-000000000211',
  priceVariant: '51000000-0000-4000-8000-000000000212',
  priceListing: '51000000-0000-4000-8000-000000000213',
  priceInventory: '51000000-0000-4000-8000-000000000214',
  wholesaleProduct: '51000000-0000-4000-8000-000000000221',
  wholesaleVariant: '51000000-0000-4000-8000-000000000222',
  wholesaleListing: '51000000-0000-4000-8000-000000000223',
  wholesaleInventory: '51000000-0000-4000-8000-000000000224',
  cancelProductA: '51000000-0000-4000-8000-000000000231',
  cancelVariantA: '51000000-0000-4000-8000-000000000232',
  cancelListingA: '51000000-0000-4000-8000-000000000233',
  cancelInventoryA: '51000000-0000-4000-8000-000000000234',
  cancelProductB: '51000000-0000-4000-8000-000000000241',
  cancelVariantB: '51000000-0000-4000-8000-000000000242',
  cancelListingB: '51000000-0000-4000-8000-000000000243',
  cancelInventoryB: '51000000-0000-4000-8000-000000000244',
  oversellCartA: '51000000-0000-4000-8000-000000000301',
  oversellCartB: '51000000-0000-4000-8000-000000000302',
  priceCart: '51000000-0000-4000-8000-000000000303',
  wholesaleCart: '51000000-0000-4000-8000-000000000304',
  cancelCart: '51000000-0000-4000-8000-000000000305',
  collisionCart: '51000000-0000-4000-8000-000000000306',
  oversellKeyA: '51000000-0000-4000-8000-000000000401',
  oversellKeyB: '51000000-0000-4000-8000-000000000402',
  priceKey: '51000000-0000-4000-8000-000000000403',
  wholesaleKey: '51000000-0000-4000-8000-000000000404',
  cancelCheckoutKey: '51000000-0000-4000-8000-000000000405',
  cancelKey: '51000000-0000-4000-8000-000000000406',
  collisionCheckoutKey: '51000000-0000-4000-8000-000000000407',
  collisionCancelKey: '51000000-0000-4000-8000-000000000408',
}

const users = [
  IDS.oversellA, IDS.oversellB, IDS.priceBuyer, IDS.wholesaleBuyer,
  IDS.cancelBuyer, IDS.merchant, IDS.reviewer,
]
const carts = [
  IDS.oversellCartA, IDS.oversellCartB, IDS.priceCart,
  IDS.wholesaleCart, IDS.cancelCart, IDS.collisionCart,
]
const listings = [
  IDS.oversellListing, IDS.priceListing, IDS.wholesaleListing,
  IDS.cancelListingA, IDS.cancelListingB,
]
const products = [
  IDS.oversellProduct, IDS.priceProduct, IDS.wholesaleProduct,
  IDS.cancelProductA, IDS.cancelProductB,
]
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
  let settled = false
  const raw = new Promise((resolve, reject) => {
    child.on('error', reject)
    child.on('close', (code, signal) => resolve({ code, signal, stdout, stderr }))
  }).finally(() => { settled = true })
  const result = raw.finally(() => active.delete(result))
  active.add(result)
  return {
    result,
    readStdout: () => stdout,
    readStderr: () => stderr,
    isSettled: () => settled,
  }
}

async function runAdmin(sql, label) {
  const result = await startPsql(sql).result
  assert.equal(result.signal, null, `${label}:signal`)
  assert.equal(result.code, 0, `${label}:exit\n${result.stderr}`)
  return result.stdout.trim()
}

const cleanupSql = `
DROP TRIGGER IF EXISTS p5_test_fail_second_release ON public.inventory_events;
DROP FUNCTION IF EXISTS private.p5_test_fail_second_release();
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
UPDATE public.wholesale_applications
  SET status = 'rejected', organization_id = NULL, owner_membership_id = NULL,
    qualification_id = NULL, decided_at = pg_catalog.statement_timestamp()
  WHERE id = '${IDS.wholesaleApplication}';
DELETE FROM public.wholesale_qualifications WHERE id = '${IDS.qualification}';
DELETE FROM public.wholesale_applications WHERE id = '${IDS.wholesaleApplication}';
DELETE FROM public.membership_store_scopes
  WHERE id IN ('${IDS.wholesaleScope}', '${IDS.merchantScope}');
DELETE FROM public.memberships
  WHERE id IN ('${IDS.wholesaleMembership}', '${IDS.reviewerMembership}',
    '${IDS.merchantMembership}');
DELETE FROM public.organizations
  WHERE id IN ('${IDS.merchantOrg}', '${IDS.wholesaleOrg}', '${IDS.platformOrg}');
DELETE FROM public.profiles WHERE user_id IN (${sqlList(users)});
DELETE FROM auth.users WHERE id IN (${sqlList(users)});
COMMIT;
`

const setupSql = `
${cleanupSql}
GRANT rebuy_business_executor TO postgres WITH INHERIT FALSE GRANTED BY CURRENT_USER;
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, role, aud)
VALUES
  ('${IDS.oversellA}', 'p5-race-oversell-a@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.oversellB}', 'p5-race-oversell-b@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.priceBuyer}', 'p5-race-price@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.wholesaleBuyer}', 'p5-race-wholesale@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.cancelBuyer}', 'p5-race-cancel@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.merchant}', 'p5-race-merchant@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.reviewer}', 'p5-race-reviewer@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated');
INSERT INTO public.organizations (id, organization_type, display_name, status, created_by)
VALUES
  ('${IDS.merchantOrg}', 'merchant', 'P5 Race Merchant', 'active', '${IDS.merchant}'),
  ('${IDS.wholesaleOrg}', 'wholesale', 'P5 Race Wholesale', 'active', '${IDS.wholesaleBuyer}'),
  ('${IDS.platformOrg}', 'platform', 'P5 Race Platform', 'active', '${IDS.reviewer}');
INSERT INTO public.stores (id, organization_id, organization_type, display_name, slug, status, public_visibility)
VALUES ('${IDS.store}', '${IDS.merchantOrg}', 'merchant', 'P5 Race Store', 'p5-race-store', 'active', true);
INSERT INTO public.memberships (id, user_id, organization_id, organization_type,
  role_definition_id, role_version, status, valid_from)
VALUES
  ('${IDS.wholesaleMembership}', '${IDS.wholesaleBuyer}', '${IDS.wholesaleOrg}', 'wholesale',
    '00000000-0000-4000-8000-000000000201', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('${IDS.reviewerMembership}', '${IDS.reviewer}', '${IDS.platformOrg}', 'platform',
    '00000000-0000-4000-8000-000000000205', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('${IDS.merchantMembership}', '${IDS.merchant}', '${IDS.merchantOrg}', 'merchant',
    '00000000-0000-4000-8000-000000000201', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour');
INSERT INTO public.membership_store_scopes (id, membership_id, organization_id,
  organization_type, store_id, scope_type, status)
VALUES
  ('${IDS.wholesaleScope}', '${IDS.wholesaleMembership}', '${IDS.wholesaleOrg}',
    'wholesale', NULL, 'organization', 'active'),
  ('${IDS.merchantScope}', '${IDS.merchantMembership}', '${IDS.merchantOrg}',
    'merchant', '${IDS.store}', 'store', 'active');
INSERT INTO public.wholesale_applications (id, applicant_user_id, company_name,
  country_code, status, assigned_reviewer_membership_id, assigned_at, submitted_at)
VALUES ('${IDS.wholesaleApplication}', '${IDS.wholesaleBuyer}', 'P5 Race Wholesale',
  'IT', 'under_review', '${IDS.reviewerMembership}',
  pg_catalog.statement_timestamp() - INTERVAL '1 hour',
  pg_catalog.statement_timestamp() - INTERVAL '2 hours');
INSERT INTO public.wholesale_qualifications (id, source_application_id,
  organization_id, organization_type, status, valid_from, valid_until,
  reason_code, version)
VALUES ('${IDS.qualification}', '${IDS.wholesaleApplication}', '${IDS.wholesaleOrg}',
  'wholesale', 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour',
  pg_catalog.statement_timestamp() + INTERVAL '30 days',
  'approved_checks_complete', 1);
UPDATE public.wholesale_applications SET status = 'approved',
  organization_id = '${IDS.wholesaleOrg}', owner_membership_id = '${IDS.wholesaleMembership}',
  qualification_id = '${IDS.qualification}', decided_at = pg_catalog.statement_timestamp()
WHERE id = '${IDS.wholesaleApplication}';
INSERT INTO public.products (id, organization_id, organization_type, category_id,
  product_kind, internal_name, status, created_by)
VALUES
  ('${IDS.oversellProduct}', '${IDS.merchantOrg}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P5 Oversell', 'active', '${IDS.merchant}'),
  ('${IDS.priceProduct}', '${IDS.merchantOrg}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P5 Price Race', 'active', '${IDS.merchant}'),
  ('${IDS.wholesaleProduct}', '${IDS.merchantOrg}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P5 Qualification Race', 'active', '${IDS.merchant}'),
  ('${IDS.cancelProductA}', '${IDS.merchantOrg}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P5 Cancel A', 'active', '${IDS.merchant}'),
  ('${IDS.cancelProductB}', '${IDS.merchantOrg}', 'merchant', '00000000-0000-4000-8000-000000000301', 'standard', 'P5 Cancel B', 'active', '${IDS.merchant}');
INSERT INTO public.product_variants (id, product_id, organization_id,
  organization_type, sku, unit_code, status)
VALUES
  ('${IDS.oversellVariant}', '${IDS.oversellProduct}', '${IDS.merchantOrg}', 'merchant', 'SYN-SKU-P5-RACE-OVERSELL', 'unit', 'active'),
  ('${IDS.priceVariant}', '${IDS.priceProduct}', '${IDS.merchantOrg}', 'merchant', 'SYN-SKU-P5-RACE-PRICE', 'unit', 'active'),
  ('${IDS.wholesaleVariant}', '${IDS.wholesaleProduct}', '${IDS.merchantOrg}', 'merchant', 'SYN-SKU-P5-RACE-WHOLESALE', 'unit', 'active'),
  ('${IDS.cancelVariantA}', '${IDS.cancelProductA}', '${IDS.merchantOrg}', 'merchant', 'SYN-SKU-P5-RACE-CANCEL-A', 'unit', 'active'),
  ('${IDS.cancelVariantB}', '${IDS.cancelProductB}', '${IDS.merchantOrg}', 'merchant', 'SYN-SKU-P5-RACE-CANCEL-B', 'unit', 'active');
INSERT INTO public.listings (id, organization_id, organization_type, store_id,
  product_id, variant_id, product_kind, slug, title, summary, status, version,
  published_at, created_by)
VALUES
  ('${IDS.oversellListing}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', '${IDS.oversellProduct}', '${IDS.oversellVariant}', 'standard', 'p5-race-oversell', 'P5 Oversell', 'Synthetic oversell race', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.priceListing}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', '${IDS.priceProduct}', '${IDS.priceVariant}', 'standard', 'p5-race-price', 'P5 Price Race', 'Synthetic price race', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.wholesaleListing}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', '${IDS.wholesaleProduct}', '${IDS.wholesaleVariant}', 'standard', 'p5-race-wholesale', 'P5 Qualification Race', 'Synthetic qualification race', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.cancelListingA}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', '${IDS.cancelProductA}', '${IDS.cancelVariantA}', 'standard', 'p5-race-cancel-a', 'P5 Cancel A', 'Synthetic cancel rollback A', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}'),
  ('${IDS.cancelListingB}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', '${IDS.cancelProductB}', '${IDS.cancelVariantB}', 'standard', 'p5-race-cancel-b', 'P5 Cancel B', 'Synthetic cancel rollback B', 'active', 1, pg_catalog.statement_timestamp(), '${IDS.merchant}');
INSERT INTO public.listing_prices (listing_id, organization_id, organization_type,
  store_id, audience, currency_code, unit_amount_cents, minimum_quantity,
  version, status, created_by)
VALUES
  ('${IDS.oversellListing}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1000, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.priceListing}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1000, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.wholesaleListing}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1200, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.wholesaleListing}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 'wholesale', 'EUR', 800, 2, 1, 'active', '${IDS.merchant}'),
  ('${IDS.cancelListingA}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1300, 1, 1, 'active', '${IDS.merchant}'),
  ('${IDS.cancelListingB}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 'retail', 'EUR', 1400, 1, 1, 'active', '${IDS.merchant}');
INSERT INTO public.inventory_levels (id, listing_id, organization_id,
  organization_type, store_id, on_hand, reserved, version)
VALUES
  ('${IDS.oversellInventory}', '${IDS.oversellListing}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 5, 0, 1),
  ('${IDS.priceInventory}', '${IDS.priceListing}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 5, 0, 1),
  ('${IDS.wholesaleInventory}', '${IDS.wholesaleListing}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 10, 0, 1),
  ('${IDS.cancelInventoryA}', '${IDS.cancelListingA}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 5, 0, 1),
  ('${IDS.cancelInventoryB}', '${IDS.cancelListingB}', '${IDS.merchantOrg}', 'merchant', '${IDS.store}', 5, 0, 1);
INSERT INTO public.carts (id, owner_user_id, status, version)
VALUES
  ('${IDS.oversellCartA}', '${IDS.oversellA}', 'active', 1),
  ('${IDS.oversellCartB}', '${IDS.oversellB}', 'active', 1),
  ('${IDS.priceCart}', '${IDS.priceBuyer}', 'active', 1),
  ('${IDS.wholesaleCart}', '${IDS.wholesaleBuyer}', 'active', 1),
  ('${IDS.cancelCart}', '${IDS.cancelBuyer}', 'active', 1),
  ('${IDS.collisionCart}', '${IDS.merchant}', 'active', 1);
INSERT INTO public.cart_items (cart_id, owner_user_id, listing_id, quantity, version)
VALUES
  ('${IDS.oversellCartA}', '${IDS.oversellA}', '${IDS.oversellListing}', 4, 1),
  ('${IDS.oversellCartB}', '${IDS.oversellB}', '${IDS.oversellListing}', 4, 1),
  ('${IDS.priceCart}', '${IDS.priceBuyer}', '${IDS.priceListing}', 1, 1),
  ('${IDS.wholesaleCart}', '${IDS.wholesaleBuyer}', '${IDS.wholesaleListing}', 2, 1),
  ('${IDS.cancelCart}', '${IDS.cancelBuyer}', '${IDS.cancelListingA}', 1, 1),
  ('${IDS.cancelCart}', '${IDS.cancelBuyer}', '${IDS.cancelListingB}', 1, 1),
  ('${IDS.collisionCart}', '${IDS.merchant}', '${IDS.cancelListingA}', 1, 1),
  ('${IDS.collisionCart}', '${IDS.merchant}', '${IDS.cancelListingB}', 1, 1);
`

function claimsSql(userId, email) {
  return `
DO $claims$
BEGIN
  PERFORM pg_catalog.set_config('request.jwt.claims', pg_catalog.jsonb_build_object(
    'sub', '${userId}', 'email', '${email}', 'is_anonymous', false,
    'amr', pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'method', 'otp', 'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
    )))::text, true);
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
SELECT batch_id::text || '|' || total_cents::text || '|' || order_status
FROM private.checkout_cart_impl(1, '${delivery}', '${key}');
COMMIT;
`
}

function cancelSql(batchId) {
  return `
BEGIN;
SET LOCAL statement_timeout = '12s';
${claimsSql(IDS.cancelBuyer, 'p5-race-cancel@rebuy.test')}
SET LOCAL ROLE rebuy_business_executor;
SELECT order_status || '|' || inventory_status || '|' || order_version::text
FROM private.cancel_my_order_batch_impl(
  '${batchId}', 1, '${IDS.cancelKey}'
);
COMMIT;
`
}

function inventoryAdjustSql({ applicationName, userId, email, listingId,
  expectedVersion, key }) {
  return `
BEGIN;
SET LOCAL application_name = '${applicationName}';
SET LOCAL statement_timeout = '12s';
SET LOCAL lock_timeout = '8s';
${claimsSql(userId, email)}
SET LOCAL ROLE authenticated;
SELECT listing_id::text || '|' || inventory_version::text
FROM public.adjust_inventory(
  '${listingId}', 1, ${expectedVersion}, '${key}'
);
COMMIT;
`
}

function collisionCancelSql(batchId) {
  return `
BEGIN;
SET LOCAL statement_timeout = '12s';
${claimsSql(IDS.merchant, 'p5-race-merchant@rebuy.test')}
SET LOCAL ROLE authenticated;
SELECT order_status || '|' || inventory_status || '|' || order_version::text
FROM public.cancel_my_order_batch(
  '${batchId}', 1, '${IDS.collisionCancelKey}'
);
COMMIT;
`
}

function blockerSql(lockValue, mutationSql = '') {
  return `
BEGIN;
SET LOCAL statement_timeout = '12s';
SELECT pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('${lockValue}', 0));
${mutationSql}
SELECT 'LOCK_READY';
SELECT pg_catalog.pg_sleep(3);
COMMIT;
`
}

async function waitForBlocker(blocker) {
  const deadline = Date.now() + 10_000
  while (!blocker.readStdout().includes('LOCK_READY')) {
    if (blocker.isSettled()) {
      throw new Error(`blocker_early_exit:${blocker.readStderr().trim() || 'no_stderr'}`)
    }
    if (Date.now() >= deadline) throw new Error('blocker_lock_timeout')
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
}

async function waitForDatabaseLocks(applicationNames, expected, workers) {
  const deadline = Date.now() + 5_000
  while (Date.now() < deadline) {
    const waiting = await runAdmin(`
      SELECT count(*) FROM pg_catalog.pg_stat_activity
      WHERE application_name IN (${sqlList(applicationNames)})
        AND wait_event_type = 'Lock';
    `, 'wait_for_database_locks')
    if (waiting === String(expected)) return
    const earlyWorker = workers.find((worker) => worker.isSettled())
    if (earlyWorker) {
      throw new Error(`worker_early_exit:${earlyWorker.readStderr().trim() || 'no_stderr'}`)
    }
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
  throw new Error('database_lock_barrier_timeout')
}

async function runBlocked(lockValue, attempts, mutationSql = '') {
  const blocker = startPsql(blockerSql(lockValue, mutationSql))
  await waitForBlocker(blocker)
  const workers = attempts.map((attempt) => startPsql(checkoutSql(attempt)))
  await waitForDatabaseLocks(
    attempts.map((attempt) => attempt.applicationName), attempts.length, workers,
  )
  const [blockerResult, results] = await Promise.all([
    blocker.result, Promise.all(workers.map((worker) => worker.result)),
  ])
  assert.equal(blockerResult.signal, null, 'blocker:signal')
  assert.equal(blockerResult.code, 0, `blocker:exit\n${blockerResult.stderr}`)
  return results
}

function assertClean(state) {
  for (const [key, value] of Object.entries(state)) assert.equal(value, 0, `cleanup:${key}`)
}

let failureStage = 'setup'
let primaryError
let cleanupError
try {
  await runAdmin(setupSql, 'setup')
  const qualificationPrecondition = await runAdmin(`
    BEGIN;
    ${claimsSql(IDS.wholesaleBuyer, 'p5-race-wholesale@rebuy.test')}
    SET LOCAL ROLE rebuy_business_executor;
    DO $context$
    BEGIN
      PERFORM pg_catalog.set_config('rebuy.p5.op', 'order_checkout', true);
      PERFORM pg_catalog.set_config('rebuy.p5.actor_user_id', '${IDS.wholesaleBuyer}', true);
      PERFORM pg_catalog.set_config('rebuy.p5.authorized', 'true', true);
    END
    $context$;
    SELECT private.rebuy_p5_lock_pricing_context('${IDS.wholesaleBuyer}')::text;
    ROLLBACK;
  `, 'qualification_precondition')
  assert.equal(qualificationPrecondition, IDS.qualification, 'qualification:fixture_visible')

  failureStage = 'standard_oversell_unique_winner'
  const oversellResults = await runBlocked(IDS.oversellListing, [
    { applicationName: 'p5_race_oversell_a', userId: IDS.oversellA, email: 'p5-race-oversell-a@rebuy.test', key: IDS.oversellKeyA, delivery: 'synthetic://delivery/p5-race-oversell-a' },
    { applicationName: 'p5_race_oversell_b', userId: IDS.oversellB, email: 'p5-race-oversell-b@rebuy.test', key: IDS.oversellKeyB, delivery: 'synthetic://delivery/p5-race-oversell-b' },
  ])
  assert.equal(oversellResults.filter((result) => result.code === 0).length, 1, 'oversell:one_success')
  assert.equal(oversellResults.filter((result) => result.code !== 0).length, 1, 'oversell:one_rejection')
  const oversellFailure = oversellResults.find((result) => result.code !== 0)
  assert.match(oversellFailure.stderr, /ERROR:\s+(?:checkout_item_not_purchasable|inventory_version_conflict|inventory_quantity_conflict)/)
  assert.doesNotMatch(oversellFailure.stderr, /deadlock detected|statement timeout|lock timeout/i)
  const oversellState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'reserved', (SELECT reserved FROM public.inventory_levels WHERE id = '${IDS.oversellInventory}'),
      'batches', (SELECT count(*) FROM public.order_batches WHERE buyer_user_id IN ('${IDS.oversellA}', '${IDS.oversellB}')),
      'events', (SELECT count(*) FROM public.order_events WHERE buyer_user_id IN ('${IDS.oversellA}', '${IDS.oversellB}')),
      'keys', (SELECT count(*) FROM public.p5_idempotency_keys WHERE actor_user_id IN ('${IDS.oversellA}', '${IDS.oversellB}'))
    )::text;
  `, 'oversell_state'))
  assert.deepEqual(oversellState, { reserved: 4, batches: 1, events: 1, keys: 1 })

  failureStage = 'price_update_requoted_after_lock'
  const priceResults = await runBlocked(IDS.priceListing, [{
    applicationName: 'p5_race_price_checkout', userId: IDS.priceBuyer,
    email: 'p5-race-price@rebuy.test', key: IDS.priceKey,
    delivery: 'synthetic://delivery/p5-race-price',
  }], `
    UPDATE public.listing_prices SET unit_amount_cents = 1700, version = 2
    WHERE listing_id = '${IDS.priceListing}' AND audience = 'retail';
    UPDATE public.listings SET version = 2, updated_at = pg_catalog.statement_timestamp()
    WHERE id = '${IDS.priceListing}';
  `)
  assert.equal(priceResults[0].code, 0, `price:checkout\n${priceResults[0].stderr}`)
  const priceState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'total', (SELECT total_cents FROM public.order_batches WHERE buyer_user_id = '${IDS.priceBuyer}'),
      'unit_price', (SELECT unit_amount_cents FROM public.order_items WHERE buyer_user_id = '${IDS.priceBuyer}'),
      'price_version', (SELECT price_version FROM public.order_items WHERE buyer_user_id = '${IDS.priceBuyer}'),
      'listing_version', (SELECT listing_version FROM public.order_items WHERE buyer_user_id = '${IDS.priceBuyer}')
    )::text;
  `, 'price_state'))
  assert.deepEqual(priceState, { total: 1700, unit_price: 1700, price_version: 2, listing_version: 2 })

  failureStage = 'qualification_revoke_falls_back_to_retail'
  const wholesaleResults = await runBlocked(IDS.qualification, [{
    applicationName: 'p5_race_wholesale_checkout', userId: IDS.wholesaleBuyer,
    email: 'p5-race-wholesale@rebuy.test', key: IDS.wholesaleKey,
    delivery: 'synthetic://delivery/p5-race-wholesale',
  }], `
    UPDATE public.wholesale_qualifications SET status = 'revoked',
      reason_code = 'policy_revoked', version = 2,
      updated_at = pg_catalog.statement_timestamp()
    WHERE id = '${IDS.qualification}';
  `)
  assert.equal(wholesaleResults[0].code, 0, `qualification:checkout\n${wholesaleResults[0].stderr}`)
  const wholesaleState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'total', (SELECT total_cents FROM public.order_batches WHERE buyer_user_id = '${IDS.wholesaleBuyer}'),
      'audience', (SELECT audience FROM public.order_items WHERE buyer_user_id = '${IDS.wholesaleBuyer}'),
      'unit_price', (SELECT unit_amount_cents FROM public.order_items WHERE buyer_user_id = '${IDS.wholesaleBuyer}'),
      'qualification', (SELECT status FROM public.wholesale_qualifications WHERE id = '${IDS.qualification}')
    )::text;
  `, 'qualification_state'))
  assert.deepEqual(wholesaleState, { total: 2400, audience: 'retail', unit_price: 1200, qualification: 'revoked' })

  failureStage = 'p4_derived_key_collision_lock_order'
  const collisionDerivedKey = await runAdmin(`
    SELECT private.rebuy_p5_derived_uuid(
      '${IDS.collisionCheckoutKey}', 'reserve:${IDS.cancelListingA}'
    )::text;
  `, 'collision_derived_key')
  assert.match(collisionDerivedKey, /^[0-9a-f-]{36}$/i, 'collision:derived_key')
  const collisionBlocker = startPsql(blockerSql(IDS.cancelListingB))
  await waitForBlocker(collisionBlocker)
  const collisionCheckout = startPsql(checkoutSql({
    applicationName: 'p5_race_collision_checkout', userId: IDS.merchant,
    email: 'p5-race-merchant@rebuy.test', key: IDS.collisionCheckoutKey,
    delivery: 'synthetic://delivery/p5-race-collision',
  }))
  await waitForDatabaseLocks(
    ['p5_race_collision_checkout'], 1, [collisionCheckout],
  )
  const collisionAdjust = startPsql(inventoryAdjustSql({
    applicationName: 'p5_race_collision_adjust', userId: IDS.merchant,
    email: 'p5-race-merchant@rebuy.test', listingId: IDS.cancelListingA,
    expectedVersion: 1, key: collisionDerivedKey,
  }))
  await waitForDatabaseLocks(
    ['p5_race_collision_checkout', 'p5_race_collision_adjust'], 2,
    [collisionCheckout, collisionAdjust],
  )
  const [collisionBlockerResult, collisionCheckoutResult, collisionAdjustResult] =
    await Promise.all([
      collisionBlocker.result, collisionCheckout.result, collisionAdjust.result,
    ])
  assert.equal(collisionBlockerResult.code, 0,
    `collision:blocker\n${collisionBlockerResult.stderr}`)
  assert.equal(collisionCheckoutResult.code, 0,
    `collision:checkout\n${collisionCheckoutResult.stderr}`)
  assert.notEqual(collisionAdjustResult.code, 0, 'collision:adjust_key_conflict')
  assert.match(collisionAdjustResult.stderr, /ERROR:\s+p4_idempotency_conflict/)
  assert.doesNotMatch(
    `${collisionCheckoutResult.stderr}\n${collisionAdjustResult.stderr}`,
    /deadlock detected|statement timeout|lock timeout/i,
  )
  const collisionBatchId = await runAdmin(`
    SELECT id FROM public.order_batches WHERE buyer_user_id = '${IDS.merchant}';
  `, 'collision_batch_id')
  const collisionCancel = await startPsql(collisionCancelSql(collisionBatchId)).result
  assert.equal(collisionCancel.code, 0,
    `collision:cancel\n${collisionCancel.stderr}`)
  assert.match(collisionCancel.stdout, /cancelled\|released\|2/)
  const collisionReleased = await runAdmin(`
    SELECT count(*) FROM public.inventory_levels
    WHERE id IN ('${IDS.cancelInventoryA}', '${IDS.cancelInventoryB}')
      AND reserved = 0;
  `, 'collision_release_state')
  assert.equal(collisionReleased, '2', 'collision:reservations_released')

  failureStage = 'mid_cancel_atomic_rollback'
  const cancelCheckout = await startPsql(checkoutSql({
    applicationName: 'p5_race_cancel_checkout', userId: IDS.cancelBuyer,
    email: 'p5-race-cancel@rebuy.test', key: IDS.cancelCheckoutKey,
    delivery: 'synthetic://delivery/p5-race-cancel',
  })).result
  assert.equal(cancelCheckout.code, 0, `cancel:checkout\n${cancelCheckout.stderr}`)
  const cancelBatchId = await runAdmin(`
    SELECT id FROM public.order_batches WHERE buyer_user_id = '${IDS.cancelBuyer}';
  `, 'cancel_batch_id')
  await runAdmin(`
    CREATE OR REPLACE FUNCTION private.p5_test_fail_second_release()
    RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $function$
    BEGIN
      IF NEW.event_code = 'inventory.released'
         AND NEW.listing_id = '${IDS.cancelListingB}'::uuid
      THEN RAISE EXCEPTION 'synthetic_cancel_second_release_failure'; END IF;
      RETURN NEW;
    END
    $function$;
    CREATE TRIGGER p5_test_fail_second_release
      BEFORE INSERT ON public.inventory_events
      FOR EACH ROW EXECUTE FUNCTION private.p5_test_fail_second_release();
  `, 'install_cancel_failure')
  const cancelResult = await startPsql(cancelSql(cancelBatchId)).result
  assert.notEqual(cancelResult.code, 0, 'cancel:forced_failure')
  assert.match(cancelResult.stderr, /ERROR:\s+synthetic_cancel_second_release_failure/)
  await runAdmin(`
    DROP TRIGGER p5_test_fail_second_release ON public.inventory_events;
    DROP FUNCTION private.p5_test_fail_second_release();
  `, 'remove_cancel_failure')
  const cancelState = JSON.parse(await runAdmin(`
    SELECT pg_catalog.jsonb_build_object(
      'batch_state', (SELECT status || ':' || inventory_status || ':' || version::text FROM public.order_batches WHERE id = '${cancelBatchId}'),
      'cancelled_at', (SELECT cancelled_at IS NOT NULL FROM public.order_batches WHERE id = '${cancelBatchId}'),
      'suborders', (SELECT pg_catalog.string_agg(status || ':' || inventory_status || ':' || version::text, ',') FROM public.merchant_orders WHERE batch_id = '${cancelBatchId}'),
      'released_items', (SELECT count(*) FROM public.order_items WHERE batch_id = '${cancelBatchId}' AND inventory_status = 'released'),
      'reserved_a', (SELECT reserved FROM public.inventory_levels WHERE id = '${IDS.cancelInventoryA}'),
      'reserved_b', (SELECT reserved FROM public.inventory_levels WHERE id = '${IDS.cancelInventoryB}'),
      'order_events', (SELECT count(*) FROM public.order_events WHERE batch_id = '${cancelBatchId}'),
      'p5_keys', (SELECT count(*) FROM public.p5_idempotency_keys WHERE actor_user_id = '${IDS.cancelBuyer}'),
      'inventory_events', (SELECT count(*) FROM public.inventory_events WHERE listing_id IN ('${IDS.cancelListingA}', '${IDS.cancelListingB}'))
    )::text;
  `, 'cancel_state'))
  assert.deepEqual(cancelState, {
    batch_state: 'confirmed:reserved:1', cancelled_at: false,
    suborders: 'pending:reserved:1', released_items: 0,
    reserved_a: 1, reserved_b: 1, order_events: 1, p5_keys: 1,
    inventory_events: 2,
  })
} catch (error) {
  primaryError = new Error(`P5 race concurrency failed at ${failureStage}: ${error.message}`, { cause: error })
} finally {
  await Promise.allSettled([...active])
  try {
    await runAdmin(cleanupSql, 'cleanup')
    const state = JSON.parse(await runAdmin(`
      SELECT pg_catalog.jsonb_build_object(
        'users', (SELECT count(*) FROM auth.users WHERE id IN (${sqlList(users)})),
        'profiles', (SELECT count(*) FROM public.profiles WHERE user_id IN (${sqlList(users)})),
        'organizations', (SELECT count(*) FROM public.organizations WHERE id IN ('${IDS.merchantOrg}', '${IDS.wholesaleOrg}', '${IDS.platformOrg}')),
        'stores', (SELECT count(*) FROM public.stores WHERE id = '${IDS.store}'),
        'applications', (SELECT count(*) FROM public.wholesale_applications WHERE id = '${IDS.wholesaleApplication}'),
        'qualifications', (SELECT count(*) FROM public.wholesale_qualifications WHERE id = '${IDS.qualification}'),
        'memberships', (SELECT count(*) FROM public.memberships WHERE id IN ('${IDS.wholesaleMembership}', '${IDS.reviewerMembership}')),
        'products', (SELECT count(*) FROM public.products WHERE id IN (${sqlList(products)})),
        'listings', (SELECT count(*) FROM public.listings WHERE id IN (${sqlList(listings)})),
        'inventory', (SELECT count(*) FROM public.inventory_levels WHERE listing_id IN (${sqlList(listings)})),
        'carts', (SELECT count(*) FROM public.carts WHERE id IN (${sqlList(carts)})),
        'batches', (SELECT count(*) FROM public.order_batches WHERE buyer_user_id IN (${sqlList(users)})),
        'p4_keys', (SELECT count(*) FROM public.p4_idempotency_keys WHERE actor_user_id IN (${sqlList(users)})),
        'p5_keys', (SELECT count(*) FROM public.p5_idempotency_keys WHERE actor_user_id IN (${sqlList(users)})),
        'postgres_executor_membership', (SELECT CASE WHEN pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET') THEN 1 ELSE 0 END)
      )::text;
    `, 'cleanup_verification'))
    assertClean(state)
  } catch (error) {
    cleanupError = error
  }
}

if (primaryError || cleanupError) {
  console.error(`P5_RACE_CONCURRENCY_FAIL:${failureStage}:${cleanupError ? 'cleanup_fail' : 'cleanup_pass'}`)
  if (primaryError) console.error(primaryError.message)
  if (cleanupError) console.error(`P5 race cleanup failed: ${cleanupError.message}`)
  process.exitCode = 1
} else {
  console.log('P5_RACE_CONCURRENCY_PASS')
}
