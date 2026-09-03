BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL search_path = pg_catalog, public, extensions;
GRANT rebuy_business_executor TO postgres
  WITH INHERIT FALSE GRANTED BY CURRENT_USER;

CREATE OR REPLACE FUNCTION pg_temp.p5_set_claims(
  p_uid uuid,
  p_email text,
  p_anonymous boolean DEFAULT false,
  p_age_seconds integer DEFAULT 0
)
RETURNS void LANGUAGE plpgsql AS $function$
BEGIN
  PERFORM pg_catalog.set_config('request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', p_uid::text, 'email', p_email, 'is_anonymous', p_anonymous,
      'amr', pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp()) - p_age_seconds
      ))
    )::text, true);
END
$function$;

CREATE OR REPLACE FUNCTION pg_temp.p5_inventory_reserved(p_listing_id uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT il.reserved FROM public.inventory_levels AS il
  WHERE il.listing_id = p_listing_id
$function$;
CREATE OR REPLACE FUNCTION pg_temp.p5_secondhand_status(p_listing_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT su.status FROM public.secondhand_units AS su
  WHERE su.listing_id = p_listing_id
$function$;
CREATE OR REPLACE FUNCTION pg_temp.p5_order_event_count(p_batch_id uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT pg_catalog.count(*)::integer FROM public.order_events AS oe
  WHERE oe.batch_id = p_batch_id
$function$;

CREATE TEMP TABLE p5_put_result (
  cart_id uuid, cart_version integer, item_id uuid,
  item_version integer, quantity integer
);
CREATE TEMP TABLE p5_checkout_result (
  batch_id uuid, synthetic_order_reference text, order_status text,
  inventory_status text, currency_code text, total_cents integer,
  order_version integer
);
CREATE TEMP TABLE p5_cancel_result (
  batch_id uuid, order_status text, inventory_status text,
  order_version integer, cancelled_at timestamptz
);
GRANT ALL PRIVILEGES ON TABLE pg_temp.p5_put_result,
  pg_temp.p5_checkout_result, pg_temp.p5_cancel_result
  TO authenticated, rebuy_business_executor;

INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, role, aud)
VALUES
  ('00000000-0000-4000-8000-000000005101', 'p5-retail@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000005102', 'p5-other@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000005103', 'p5-wholesale@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000005104', 'p5-merchant@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000005105', 'p5-reviewer@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated');

INSERT INTO public.organizations (id, organization_type, display_name, status, created_by)
VALUES
  ('00000000-0000-4000-8000-000000005401', 'merchant', 'P5 Synthetic Merchant A', 'active', '00000000-0000-4000-8000-000000005104'),
  ('00000000-0000-4000-8000-000000005402', 'merchant', 'P5 Synthetic Merchant B', 'active', '00000000-0000-4000-8000-000000005104'),
  ('00000000-0000-4000-8000-000000005403', 'wholesale', 'P5 Synthetic Wholesale', 'active', '00000000-0000-4000-8000-000000005103'),
  ('00000000-0000-4000-8000-000000005404', 'platform', 'P5 Synthetic Platform', 'active', '00000000-0000-4000-8000-000000005105');

INSERT INTO public.stores (id, organization_id, organization_type,
  display_name, slug, status, public_visibility)
VALUES
  ('00000000-0000-4000-8000-000000005501', '00000000-0000-4000-8000-000000005401',
    'merchant', 'P5 Synthetic Store A', 'p5-store-a', 'active', true),
  ('00000000-0000-4000-8000-000000005502', '00000000-0000-4000-8000-000000005402',
    'merchant', 'P5 Synthetic Store B', 'p5-store-b', 'active', true);

INSERT INTO public.memberships (id, user_id, organization_id, organization_type,
  role_definition_id, role_version, status, valid_from)
VALUES
  ('00000000-0000-4000-8000-000000005801', '00000000-0000-4000-8000-000000005103',
    '00000000-0000-4000-8000-000000005403', 'wholesale',
    '00000000-0000-4000-8000-000000000201', 1, 'active',
    pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000005802', '00000000-0000-4000-8000-000000005105',
    '00000000-0000-4000-8000-000000005404', 'platform',
    '00000000-0000-4000-8000-000000000205', 1, 'active',
    pg_catalog.statement_timestamp() - INTERVAL '1 hour');

INSERT INTO public.membership_store_scopes (id, membership_id, organization_id,
  organization_type, store_id, scope_type, status)
VALUES ('00000000-0000-4000-8000-000000005901',
  '00000000-0000-4000-8000-000000005801',
  '00000000-0000-4000-8000-000000005403', 'wholesale', NULL,
  'organization', 'active');

INSERT INTO public.wholesale_applications (id, applicant_user_id, company_name,
  country_code, status, assigned_reviewer_membership_id, assigned_at, submitted_at)
VALUES ('00000000-0000-4000-8000-000000005601',
  '00000000-0000-4000-8000-000000005103', 'P5 Synthetic Wholesale', 'IT',
  'under_review', '00000000-0000-4000-8000-000000005802',
  pg_catalog.statement_timestamp() - INTERVAL '1 hour',
  pg_catalog.statement_timestamp() - INTERVAL '2 hours');
INSERT INTO public.wholesale_qualifications (id, source_application_id,
  organization_id, organization_type, status, valid_from, valid_until,
  reason_code, version)
VALUES ('00000000-0000-4000-8000-000000005701',
  '00000000-0000-4000-8000-000000005601',
  '00000000-0000-4000-8000-000000005403', 'wholesale', 'active',
  pg_catalog.statement_timestamp() - INTERVAL '1 hour',
  pg_catalog.statement_timestamp() + INTERVAL '30 days',
  'approved_checks_complete', 1);
UPDATE public.wholesale_applications SET status = 'approved',
  organization_id = '00000000-0000-4000-8000-000000005403',
  owner_membership_id = '00000000-0000-4000-8000-000000005801',
  qualification_id = '00000000-0000-4000-8000-000000005701',
  decided_at = pg_catalog.statement_timestamp()
WHERE id = '00000000-0000-4000-8000-000000005601';

INSERT INTO public.products (id, organization_id, organization_type, category_id,
  product_kind, internal_name, status, created_by)
VALUES
  ('00000000-0000-4000-8000-000000006201', '00000000-0000-4000-8000-000000005401',
    'merchant', '00000000-0000-4000-8000-000000000301', 'standard',
    'P5 Phone', 'active', '00000000-0000-4000-8000-000000005104'),
  ('00000000-0000-4000-8000-000000006202', '00000000-0000-4000-8000-000000005402',
    'merchant', '00000000-0000-4000-8000-000000000302', 'standard',
    'P5 Cable', 'active', '00000000-0000-4000-8000-000000005104'),
  ('00000000-0000-4000-8000-000000006203', '00000000-0000-4000-8000-000000005401',
    'merchant', '00000000-0000-4000-8000-000000000303', 'secondhand',
    'P5 Used Phone', 'active', '00000000-0000-4000-8000-000000005104');

INSERT INTO public.product_variants (id, product_id, organization_id,
  organization_type, sku, unit_code, status)
VALUES
  ('00000000-0000-4000-8000-000000006301', '00000000-0000-4000-8000-000000006201',
    '00000000-0000-4000-8000-000000005401', 'merchant', 'SYN-SKU-P5-PHONE', 'unit', 'active'),
  ('00000000-0000-4000-8000-000000006302', '00000000-0000-4000-8000-000000006202',
    '00000000-0000-4000-8000-000000005402', 'merchant', 'SYN-SKU-P5-CABLE', 'unit', 'active'),
  ('00000000-0000-4000-8000-000000006303', '00000000-0000-4000-8000-000000006203',
    '00000000-0000-4000-8000-000000005401', 'merchant', 'SYN-SKU-P5-USED', 'unit', 'active');

INSERT INTO public.listings (id, organization_id, organization_type, store_id,
  product_id, variant_id, product_kind, slug, title, summary, status, version,
  published_at, created_by)
VALUES
  ('00000000-0000-4000-8000-000000006101', '00000000-0000-4000-8000-000000005401',
    'merchant', '00000000-0000-4000-8000-000000005501',
    '00000000-0000-4000-8000-000000006201', '00000000-0000-4000-8000-000000006301',
    'standard', 'p5-phone', 'P5 Synthetic Phone', 'Synthetic standard phone',
    'active', 1, pg_catalog.statement_timestamp(), '00000000-0000-4000-8000-000000005104'),
  ('00000000-0000-4000-8000-000000006102', '00000000-0000-4000-8000-000000005402',
    'merchant', '00000000-0000-4000-8000-000000005502',
    '00000000-0000-4000-8000-000000006202', '00000000-0000-4000-8000-000000006302',
    'standard', 'p5-cable', 'P5 Synthetic Cable', 'Synthetic standard cable',
    'active', 1, pg_catalog.statement_timestamp(), '00000000-0000-4000-8000-000000005104'),
  ('00000000-0000-4000-8000-000000006103', '00000000-0000-4000-8000-000000005401',
    'merchant', '00000000-0000-4000-8000-000000005501',
    '00000000-0000-4000-8000-000000006203', '00000000-0000-4000-8000-000000006303',
    'secondhand', 'p5-used-phone', 'P5 Synthetic Used Phone', 'Synthetic secondhand phone',
    'active', 1, pg_catalog.statement_timestamp(), '00000000-0000-4000-8000-000000005104');

INSERT INTO public.listing_prices (id, listing_id, organization_id,
  organization_type, store_id, audience, currency_code, unit_amount_cents,
  minimum_quantity, version, status, created_by)
VALUES
  ('00000000-0000-4000-8000-000000006401', '00000000-0000-4000-8000-000000006101',
    '00000000-0000-4000-8000-000000005401', 'merchant',
    '00000000-0000-4000-8000-000000005501', 'retail', 'EUR', 12000, 1, 1, 'active',
    '00000000-0000-4000-8000-000000005104'),
  ('00000000-0000-4000-8000-000000006402', '00000000-0000-4000-8000-000000006101',
    '00000000-0000-4000-8000-000000005401', 'merchant',
    '00000000-0000-4000-8000-000000005501', 'wholesale', 'EUR', 10000, 2, 1, 'active',
    '00000000-0000-4000-8000-000000005104'),
  ('00000000-0000-4000-8000-000000006403', '00000000-0000-4000-8000-000000006102',
    '00000000-0000-4000-8000-000000005402', 'merchant',
    '00000000-0000-4000-8000-000000005502', 'retail', 'EUR', 500, 1, 1, 'active',
    '00000000-0000-4000-8000-000000005104'),
  ('00000000-0000-4000-8000-000000006404', '00000000-0000-4000-8000-000000006103',
    '00000000-0000-4000-8000-000000005401', 'merchant',
    '00000000-0000-4000-8000-000000005501', 'retail', 'EUR', 8000, 1, 1, 'active',
    '00000000-0000-4000-8000-000000005104');
INSERT INTO public.listing_price_tiers (price_id, listing_id,
  minimum_quantity, unit_amount_cents)
VALUES ('00000000-0000-4000-8000-000000006402',
  '00000000-0000-4000-8000-000000006101', 5, 9000);

INSERT INTO public.inventory_levels (id, listing_id, organization_id,
  organization_type, store_id, on_hand, reserved, version)
VALUES
  ('00000000-0000-4000-8000-000000006501', '00000000-0000-4000-8000-000000006101',
    '00000000-0000-4000-8000-000000005401', 'merchant',
    '00000000-0000-4000-8000-000000005501', 20, 0, 1),
  ('00000000-0000-4000-8000-000000006502', '00000000-0000-4000-8000-000000006102',
    '00000000-0000-4000-8000-000000005402', 'merchant',
    '00000000-0000-4000-8000-000000005502', 10, 0, 1);
INSERT INTO public.secondhand_units (id, listing_id, product_kind,
  synthetic_serial_reference, condition_code, defect_code,
  battery_health_percent, warranty_days, status, version)
VALUES ('00000000-0000-4000-8000-000000006601',
  '00000000-0000-4000-8000-000000006103', 'secondhand',
  'SYN-UNIT-P5-USED-001', 'good', 'cosmetic_wear', 88, 30, 'available', 1);

SET LOCAL ROLE anon;
SELECT pg_catalog.set_config('request.jwt.claims', '{}'::jsonb::text, true);
SELECT is((SELECT count(*)::integer FROM public.search_catalog(NULL, NULL, 24, 0)
  WHERE listing_id IN (
    '00000000-0000-4000-8000-000000006101',
    '00000000-0000-4000-8000-000000006102',
    '00000000-0000-4000-8000-000000006103'
  )),
  3, 'anonymous catalog shows all three purchasable fixtures');
SELECT is((SELECT count(*)::integer FROM public.search_catalog('cable', NULL, 24, 0)
  WHERE listing_id = '00000000-0000-4000-8000-000000006102'),
  1, 'catalog query filters case-insensitively');
SELECT is((SELECT audience FROM public.search_catalog(NULL, 'electronics', 24, 0)
  WHERE listing_id = '00000000-0000-4000-8000-000000006101'),
  'retail', 'anonymous catalog returns retail audience only');
SELECT is(
  COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(c)
      ORDER BY c.listing_id)
    FROM public.search_catalog(NULL, NULL, 24, 0) AS c), '[]'::jsonb)::text,
  COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(c)
      ORDER BY c.listing_id)
    FROM private.search_catalog_impl(NULL, NULL, 24, 0) AS c), '[]'::jsonb)::text,
  'direct catalog implementation exactly matches the public wrapper DTO');
SELECT throws_ok(
  $$ SELECT * FROM public.search_catalog(NULL, NULL, 0, 0) $$,
  'P0001', 'catalog_search_invalid', 'catalog paging rejects an invalid limit');

SET LOCAL ROLE authenticated;
SELECT pg_temp.p5_set_claims('00000000-0000-4000-8000-000000005101',
  'p5-retail@rebuy.test');
SELECT is((SELECT count(*)::integer FROM public.get_my_cart()), 0,
  'retail buyer begins without an active cart');
INSERT INTO pg_temp.p5_put_result SELECT * FROM public.put_cart_item(
  '00000000-0000-4000-8000-000000006101', 2, NULL, NULL,
  '00000000-0000-4000-8000-000000007001');
SELECT is((SELECT cart_version FROM pg_temp.p5_put_result ORDER BY ctid DESC LIMIT 1),
  1, 'first cart item creates version one cart');
SELECT is((SELECT quantity FROM pg_temp.p5_put_result ORDER BY ctid DESC LIMIT 1),
  2, 'first cart item keeps requested quantity');
INSERT INTO pg_temp.p5_put_result SELECT * FROM public.put_cart_item(
  '00000000-0000-4000-8000-000000006101', 2, NULL, NULL,
  '00000000-0000-4000-8000-000000007001');
SELECT is((SELECT count(DISTINCT cart_id)::integer FROM pg_temp.p5_put_result),
  1, 'same put key returns the original cart');
SELECT is((SELECT count(*)::integer FROM public.get_my_cart() WHERE listing_id IS NOT NULL),
  1, 'idempotent put creates exactly one item');
INSERT INTO pg_temp.p5_put_result SELECT * FROM public.put_cart_item(
  '00000000-0000-4000-8000-000000006102', 3, 1, NULL,
  '00000000-0000-4000-8000-000000007002');
SELECT is((SELECT cart_version FROM pg_temp.p5_put_result ORDER BY ctid DESC LIMIT 1),
  2, 'second store item advances cart version');
SELECT is((SELECT count(DISTINCT store_id)::integer FROM public.get_my_cart()
  WHERE listing_id IS NOT NULL), 2, 'one active cart spans two stores');
SELECT throws_ok(
  $$ SELECT * FROM public.put_cart_item(
    '00000000-0000-4000-8000-000000006102', 4, 1, 1,
    '00000000-0000-4000-8000-000000007003') $$,
  'P0001', 'cart_version_conflict', 'stale cart version fails closed');

SELECT is((SELECT cart_version FROM public.remove_cart_item(
  '00000000-0000-4000-8000-000000006102', 2, 1,
  '00000000-0000-4000-8000-000000007004')),
  3, 'buyer can remove an item with matching cart and item versions');
SELECT is((SELECT result_status FROM private.remove_cart_item_impl(
  '00000000-0000-4000-8000-000000006102', 2, 1,
  '00000000-0000-4000-8000-000000007004')),
  'removed', 'direct remove parity returns the stable original result');
SELECT is((SELECT count(*)::integer FROM public.get_my_cart()
  WHERE listing_id IS NOT NULL), 1, 'remove deletes exactly one cart item');
INSERT INTO pg_temp.p5_put_result SELECT * FROM public.put_cart_item(
  '00000000-0000-4000-8000-000000006102', 3, 3, NULL,
  '00000000-0000-4000-8000-000000007005');
SELECT is((SELECT cart_version FROM pg_temp.p5_put_result ORDER BY ctid DESC LIMIT 1),
  4, 're-adding the removed item advances the cart once');
SELECT is((SELECT cart_version FROM public.remove_cart_item(
  '00000000-0000-4000-8000-000000006102', 2, 1,
  '00000000-0000-4000-8000-000000007004')),
  3, 'old remove key keeps its immutable historical result after re-add');
SELECT is((SELECT count(*)::integer FROM public.get_my_cart()
  WHERE listing_id IS NOT NULL), 2,
  'old remove replay cannot delete the newly re-added cart item');

SELECT pg_catalog.set_config('rebuy.invite.authorized', 'true', true);
SELECT pg_catalog.set_config('rebuy.invite.op', 'accept_membership', true);
SELECT pg_catalog.set_config('rebuy.invite.member_id',
  '00000000-0000-4000-8000-000000005801', true);
SELECT is((SELECT count(*)::integer FROM private.get_my_cart_impl()
  WHERE listing_id IS NOT NULL), 2, 'direct cart implementation matches wrapper visibility');
SELECT is(pg_catalog.current_setting('rebuy.invite.authorized', true), 'false',
  'a P5 call clears stale P2 invitation authorization context');
SELECT is(pg_catalog.current_setting('rebuy.invite.op', true), '',
  'a P5 call clears stale P2 invitation operation context');
SELECT is(pg_catalog.current_setting('rebuy.invite.member_id', true), '',
  'a P5 call clears stale P2 invitation row context');
SELECT is(pg_catalog.current_setting('rebuy.p5.authorized', true), 'false',
  'successful P5 reads clear their transaction-local P5 context');
SELECT is((SELECT count(*)::integer FROM public.list_public_catalog()
  WHERE listing_id IN (
    '00000000-0000-4000-8000-000000006101',
    '00000000-0000-4000-8000-000000006102',
    '00000000-0000-4000-8000-000000006103'
  )), 3, 'a subsequent P4 call remains usable after P5');
SELECT is(pg_catalog.current_setting('rebuy.p5.authorized', true), 'false',
  'a subsequent P4 call cannot restore stale P5 context');

INSERT INTO pg_temp.p5_checkout_result SELECT * FROM public.checkout_cart(
  4, 'synthetic://delivery/p5-retail-point',
  '00000000-0000-4000-8000-000000007101');
SELECT is((SELECT total_cents FROM pg_temp.p5_checkout_result LIMIT 1),
  25500, 'checkout recomputes retail total on the server');
SELECT is((SELECT order_status || ':' || inventory_status
  FROM pg_temp.p5_checkout_result LIMIT 1), 'confirmed:reserved',
  'checkout confirms the batch with reserved inventory');
INSERT INTO pg_temp.p5_checkout_result SELECT * FROM public.checkout_cart(
  4, 'synthetic://delivery/p5-retail-point',
  '00000000-0000-4000-8000-000000007101');
SELECT is((SELECT count(DISTINCT batch_id)::integer FROM pg_temp.p5_checkout_result),
  1, 'same checkout key returns exactly one batch');
SELECT is((SELECT merchant_count FROM public.list_my_orders() LIMIT 1),
  2, 'checkout splits one batch into two merchant orders');
SELECT is((SELECT item_count FROM public.list_my_orders() LIMIT 1),
  5, 'order list reports total purchased units');
SELECT is((SELECT count(*)::integer FROM public.get_my_order(
  (SELECT batch_id FROM pg_temp.p5_checkout_result LIMIT 1))),
  2, 'order detail contains both immutable item snapshots');
SELECT is(
  COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(o)
      ORDER BY o.batch_id)
    FROM public.list_my_orders() AS o), '[]'::jsonb)::text,
  COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(o)
      ORDER BY o.batch_id)
    FROM private.list_my_orders_impl() AS o), '[]'::jsonb)::text,
  'direct order list implementation exactly matches the public wrapper DTO');
SELECT is(
  COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(o)
      ORDER BY o.merchant_order_id, o.listing_id)
    FROM public.get_my_order(
      (SELECT batch_id FROM pg_temp.p5_checkout_result LIMIT 1)) AS o),
    '[]'::jsonb)::text,
  COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(o)
      ORDER BY o.merchant_order_id, o.listing_id)
    FROM private.get_my_order_impl(
      (SELECT batch_id FROM pg_temp.p5_checkout_result LIMIT 1)) AS o),
    '[]'::jsonb)::text,
  'direct order detail implementation exactly matches the public wrapper DTO');
SELECT is(pg_temp.p5_inventory_reserved(
  '00000000-0000-4000-8000-000000006101'),
  2, 'standard inventory is reserved at checkout');

SELECT pg_temp.p5_set_claims('00000000-0000-4000-8000-000000005102',
  'p5-other@rebuy.test');
SELECT is((SELECT count(*)::integer FROM public.list_my_orders()), 0,
  'another buyer cannot list the retail buyer orders');
SELECT is((SELECT count(*)::integer FROM public.get_my_order(
  (SELECT batch_id FROM pg_temp.p5_checkout_result LIMIT 1))), 0,
  'another buyer cannot read order detail by UUID');
SELECT is((SELECT count(*)::integer FROM private.list_my_orders_impl()), 0,
  'direct order list implementation preserves cross-user denial');
SELECT is((SELECT count(*)::integer FROM private.get_my_order_impl(
  (SELECT batch_id FROM pg_temp.p5_checkout_result LIMIT 1))), 0,
  'direct order detail implementation preserves cross-user denial');
SELECT is((SELECT count(*)::integer FROM public.get_my_cart()), 0,
  'another buyer cannot read the retail buyer cart');

SELECT pg_temp.p5_set_claims('00000000-0000-4000-8000-000000005101',
  'p5-retail@rebuy.test');
INSERT INTO pg_temp.p5_cancel_result SELECT * FROM public.cancel_my_order_batch(
  (SELECT batch_id FROM pg_temp.p5_checkout_result LIMIT 1), 1,
  '00000000-0000-4000-8000-000000007201');
SELECT is((SELECT order_status || ':' || inventory_status
  FROM pg_temp.p5_cancel_result LIMIT 1), 'cancelled:released',
  'buyer cancellation atomically releases the full batch');
INSERT INTO pg_temp.p5_cancel_result SELECT * FROM private.cancel_my_order_batch_impl(
  (SELECT batch_id FROM pg_temp.p5_checkout_result LIMIT 1), 1,
  '00000000-0000-4000-8000-000000007201');
SELECT is((SELECT count(DISTINCT batch_id::text || ':' || order_status || ':'
    || inventory_status || ':' || order_version::text || ':'
    || cancelled_at::text)::integer FROM pg_temp.p5_cancel_result),
  1, 'direct cancel implementation exactly replays the public wrapper DTO');
INSERT INTO pg_temp.p5_cancel_result SELECT * FROM public.cancel_my_order_batch(
  (SELECT batch_id FROM pg_temp.p5_checkout_result LIMIT 1), 1,
  '00000000-0000-4000-8000-000000007201');
SELECT is((SELECT count(DISTINCT order_version)::integer FROM pg_temp.p5_cancel_result),
  1, 'same cancellation key returns the stable original result');
SELECT is((SELECT count(DISTINCT cancelled_at)::integer FROM pg_temp.p5_cancel_result),
  1, 'same cancellation key preserves the original cancellation timestamp');
SELECT is(pg_temp.p5_inventory_reserved(
  '00000000-0000-4000-8000-000000006101'),
  0, 'cancellation releases standard inventory exactly once');
SELECT is(pg_temp.p5_order_event_count(
  (SELECT batch_id FROM pg_temp.p5_checkout_result LIMIT 1)),
  2, 'checkout and cancellation each append one order event');
INSERT INTO pg_temp.p5_checkout_result SELECT * FROM private.checkout_cart_impl(
  4, 'synthetic://delivery/p5-retail-point',
  '00000000-0000-4000-8000-000000007101');
SELECT is((SELECT count(DISTINCT order_status || ':' || inventory_status
    || ':' || order_version::text)::integer FROM pg_temp.p5_checkout_result),
  1, 'old checkout key remains confirmed/reserved/version one after cancellation');
SELECT is((SELECT order_status || ':' || inventory_status || ':' || order_version::text
  FROM pg_temp.p5_checkout_result ORDER BY ctid DESC LIMIT 1),
  'confirmed:reserved:1', 'checkout retry replays the immutable original payload');
RESET ROLE;
UPDATE public.inventory_levels SET on_hand = reserved, version = version + 1
WHERE listing_id = '00000000-0000-4000-8000-000000006101';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p5_set_claims('00000000-0000-4000-8000-000000005101',
  'p5-retail@rebuy.test');
INSERT INTO pg_temp.p5_put_result SELECT * FROM private.put_cart_item_impl(
  '00000000-0000-4000-8000-000000006101', 2, NULL, NULL,
  '00000000-0000-4000-8000-000000007001');
SELECT is((SELECT cart_version::text || ':' || item_version::text || ':' || quantity::text
  FROM pg_temp.p5_put_result ORDER BY ctid DESC LIMIT 1),
  '1:1:2', 'old put key remains stable after later mutation, checkout, and stock exhaustion');
RESET ROLE;
UPDATE public.inventory_levels SET on_hand = 20, version = version + 1
WHERE listing_id = '00000000-0000-4000-8000-000000006101';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p5_set_claims('00000000-0000-4000-8000-000000005101',
  'p5-retail@rebuy.test');
SELECT throws_ok(
  $$ SELECT * FROM public.cancel_my_order_batch(
    (SELECT batch_id FROM pg_temp.p5_checkout_result LIMIT 1), 2,
    '00000000-0000-4000-8000-000000007202') $$,
  'P0001', 'order_cancel_not_allowed', 'a cancelled order cannot be changed again');

SELECT throws_ok(
  $$ SELECT * FROM public.put_cart_item(
    '00000000-0000-4000-8000-000000006103', 2, NULL, NULL,
    '00000000-0000-4000-8000-000000007301') $$,
  'P0001', 'cart_item_not_purchasable', 'secondhand quantity is fixed at one');
TRUNCATE pg_temp.p5_put_result;
INSERT INTO pg_temp.p5_put_result SELECT * FROM public.put_cart_item(
  '00000000-0000-4000-8000-000000006103', 1, NULL, NULL,
  '00000000-0000-4000-8000-000000007302');
SELECT is((SELECT product_kind || ':' || quantity::text FROM public.get_my_cart()
  WHERE listing_id IS NOT NULL), 'secondhand:1',
  'secondhand can be held once in an unreserved cart');
SELECT is(pg_temp.p5_secondhand_status(
  '00000000-0000-4000-8000-000000006103'),
  'available', 'adding secondhand to cart does not reserve it');

SELECT pg_temp.p5_set_claims('00000000-0000-4000-8000-000000005103',
  'p5-wholesale@rebuy.test');
SELECT is((SELECT audience || ':' || minimum_quantity::text
  FROM public.search_catalog(NULL, 'electronics', 24, 0)
  WHERE listing_id = '00000000-0000-4000-8000-000000006101'),
  'wholesale:2', 'active wholesale qualification automatically selects wholesale rules');
SELECT is((SELECT purchasable FROM public.search_catalog(NULL, 'electronics', 24, 0)
  WHERE listing_id = '00000000-0000-4000-8000-000000006101'),
  true, 'qualified wholesale catalog permits adding the legal MOQ quantity');
RESET ROLE;
UPDATE public.listing_prices SET minimum_quantity = 100, version = version + 1
WHERE id = '00000000-0000-4000-8000-000000006402';
UPDATE public.listing_price_tiers SET minimum_quantity = 150
WHERE price_id = '00000000-0000-4000-8000-000000006402';
UPDATE public.inventory_levels SET on_hand = 200, version = version + 1
WHERE listing_id = '00000000-0000-4000-8000-000000006101';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p5_set_claims('00000000-0000-4000-8000-000000005103',
  'p5-wholesale@rebuy.test');
SELECT is((SELECT purchasable::text || ':' || minimum_quantity::text
  FROM public.search_catalog(NULL, 'electronics', 24, 0)
  WHERE listing_id = '00000000-0000-4000-8000-000000006101'),
  'true:100', 'wholesale MOQ above 99 remains purchasable end to end');
SELECT throws_ok(
  $$ SELECT * FROM public.put_cart_item(
    '00000000-0000-4000-8000-000000006101', 1000001, NULL, NULL,
    '00000000-0000-4000-8000-000000007499') $$,
  'P0001', 'cart_put_invalid',
  'cart quantity above the shared P4 upper bound is rejected');
TRUNCATE pg_temp.p5_put_result;
INSERT INTO pg_temp.p5_put_result SELECT * FROM public.put_cart_item(
  '00000000-0000-4000-8000-000000006101', 150, NULL, NULL,
  '00000000-0000-4000-8000-000000007401');
TRUNCATE pg_temp.p5_checkout_result;
INSERT INTO pg_temp.p5_checkout_result SELECT * FROM public.checkout_cart(
  1, 'synthetic://delivery/p5-wholesale-point',
  '00000000-0000-4000-8000-000000007402');
SELECT is((SELECT total_cents FROM pg_temp.p5_checkout_result), 1350000,
  'qualified wholesale checkout receives the matching tier automatically');
SELECT is((SELECT audience || ':' || unit_amount_cents::text
  FROM public.get_my_order((SELECT batch_id FROM pg_temp.p5_checkout_result))),
  'wholesale:9000', 'order snapshot records the server-selected wholesale tier');

SELECT pg_temp.p5_set_claims('00000000-0000-4000-8000-000000005102',
  'p5-other@rebuy.test', false, 601);
SELECT throws_ok(
  $$ SELECT * FROM public.put_cart_item(
    '00000000-0000-4000-8000-000000006102', 1, NULL, NULL,
    '00000000-0000-4000-8000-000000007501') $$,
  'P0001', 'merchant_recent_otp_required',
  'cart writes require a recent email OTP session');

RESET ROLE;
REVOKE rebuy_business_executor FROM postgres GRANTED BY CURRENT_USER;
SELECT ok(
  NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
  AND NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET'),
  'workflow test removes temporary executor membership'
);
SELECT * FROM finish();
ROLLBACK;
