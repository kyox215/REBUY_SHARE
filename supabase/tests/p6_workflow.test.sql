BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL search_path = pg_catalog, public, extensions;

CREATE OR REPLACE FUNCTION pg_temp.p6_set_claims(p_age_seconds integer DEFAULT 0)
RETURNS void LANGUAGE plpgsql AS $function$
BEGIN
  PERFORM pg_catalog.set_config('request.jwt.claims', pg_catalog.jsonb_build_object(
    'sub', '90000000-0000-4000-8000-000000000001',
    'email', 'p5-local-catalog-owner@rebuy.test', 'is_anonymous', false,
    'amr', pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'method', 'otp', 'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp()) - p_age_seconds
    )))::text, true);
END
$function$;

CREATE TEMP TABLE p6_cart (
  cart_id uuid, cart_version integer, item_id uuid,
  item_version integer, quantity integer
);
CREATE TEMP TABLE p6_checkout (
  batch_id uuid, synthetic_order_reference text, order_status text,
  inventory_status text, currency_code text, total_cents integer,
  order_version integer
);
CREATE TEMP TABLE p6_rollback_checkout (LIKE p6_checkout);
CREATE TEMP TABLE p6_order_action (
  merchant_order_id uuid, order_status text, inventory_status text,
  order_version integer, batch_status text, batch_inventory_status text,
  batch_version integer, synthetic_shipment_reference text
);
CREATE TEMP TABLE p6_case (
  case_id uuid, merchant_order_id uuid, case_status text,
  case_version integer, reason_code text
);
GRANT ALL ON TABLE pg_temp.p6_cart, pg_temp.p6_checkout,
  pg_temp.p6_rollback_checkout, pg_temp.p6_order_action, pg_temp.p6_case
  TO authenticated;

SET LOCAL ROLE authenticated;
SELECT pg_temp.p6_set_claims();

SELECT is((SELECT count(*)::integer FROM public.get_my_merchant_context()), 1,
  'merchant context exposes only the authorized store');
SELECT is((SELECT store_id FROM public.get_my_merchant_context()),
  '90000000-0000-4000-8000-000000000201'::uuid,
  'merchant context is organization scoped');
SELECT is((SELECT count(*)::integer FROM public.list_my_merchant_products(
  '90000000-0000-4000-8000-000000000201')), 2,
  'merchant product DTO contains only own-store listings');

SELECT throws_ok($$SELECT * FROM public.get_my_merchant_dashboard(
  '90000000-0000-4000-8000-000000000202')$$,
  'P0001', 'merchant_scope_forbidden',
  'cross-store merchant order access fails closed');

INSERT INTO p6_cart SELECT * FROM public.put_cart_item(
  '90000000-0000-4000-8000-000000000501', 1, NULL, NULL,
  '96000000-0000-4000-8000-000000000011');
INSERT INTO p6_cart SELECT * FROM public.put_cart_item(
  '90000000-0000-4000-8000-000000000503', 1, 1, NULL,
  '96000000-0000-4000-8000-000000000010');
INSERT INTO p6_checkout SELECT * FROM public.checkout_cart(
  (SELECT max(cart_version) FROM p6_cart), 'synthetic://delivery/p6-workflow',
  '96000000-0000-4000-8000-000000000012');

RESET ROLE;
UPDATE public.listings SET status = 'inactive'
WHERE id IN ('90000000-0000-4000-8000-000000000501',
  '90000000-0000-4000-8000-000000000503');
UPDATE public.stores SET public_visibility = false
WHERE id = '90000000-0000-4000-8000-000000000201';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p6_set_claims();

CREATE TEMP TABLE p6_target AS
SELECT mo.merchant_order_id FROM public.list_my_merchant_orders(
  '90000000-0000-4000-8000-000000000201') AS mo
WHERE mo.batch_id = (SELECT batch_id FROM p6_checkout) LIMIT 1;
GRANT SELECT ON TABLE pg_temp.p6_target TO authenticated;

INSERT INTO p6_order_action SELECT * FROM public.advance_my_merchant_order(
  '90000000-0000-4000-8000-000000000201',
  (SELECT merchant_order_id FROM p6_target), 'accept', NULL, NULL, 1,
  '96000000-0000-4000-8000-000000000021');
SELECT is((SELECT order_status FROM p6_order_action), 'accepted',
  'merchant accepts its own pending suborder');

TRUNCATE p6_order_action;
INSERT INTO p6_order_action SELECT * FROM public.advance_my_merchant_order(
  '90000000-0000-4000-8000-000000000201',
  (SELECT merchant_order_id FROM p6_target), 'accept', NULL, NULL, 1,
  '96000000-0000-4000-8000-000000000021');
SELECT is((SELECT order_status || ':' || order_version FROM p6_order_action),
  'accepted:2', 'same order action key replays the original result');

TRUNCATE p6_order_action;
INSERT INTO p6_order_action SELECT * FROM public.advance_my_merchant_order(
  '90000000-0000-4000-8000-000000000201',
  (SELECT merchant_order_id FROM p6_target), 'ship', NULL,
  'synthetic://shipment/p6-workflow', 2,
  '96000000-0000-4000-8000-000000000022');
TRUNCATE p6_order_action;
INSERT INTO p6_order_action SELECT * FROM public.advance_my_merchant_order(
  '90000000-0000-4000-8000-000000000201',
  (SELECT merchant_order_id FROM p6_target), 'complete', NULL, NULL, 3,
  '96000000-0000-4000-8000-000000000023');
SELECT is((SELECT order_status || ':' || inventory_status FROM p6_order_action),
  'completed:sold', 'full merchant fulfillment reaches completed and sold');
SELECT is((SELECT order_status || ':' || inventory_status FROM public.list_my_orders()
  WHERE batch_id = (SELECT batch_id FROM p6_checkout)), 'completed:sold',
  'buyer batch reflects completed merchant fulfillment');
SELECT is((SELECT count(*)::integer FROM public.get_my_order(
  (SELECT batch_id FROM p6_checkout)) WHERE item_inventory_status = 'sold'), 2,
  'standard and secondhand reservations terminate after listing/store invisibility');
SELECT throws_ok($$SELECT * FROM public.adjust_my_merchant_inventory(
  '90000000-0000-4000-8000-000000000201',
  '90000000-0000-4000-8000-000000000501', 2, NULL, 3,
  '96000000-0000-4000-8000-000000000024')$$,
  'P0001', 'merchant_inventory_adjust_invalid',
  'inventory adjustment rejects a missing finite reason');
SELECT is((SELECT on_hand FROM public.adjust_my_merchant_inventory(
  '90000000-0000-4000-8000-000000000201',
  '90000000-0000-4000-8000-000000000501', 2, 'stock_received', 3,
  '96000000-0000-4000-8000-000000000025')), 25,
  'inventory adjustment records a finite merchant reason after visibility withdrawal');
SELECT is((SELECT count(*)::integer FROM public.list_my_merchant_audit(
  '90000000-0000-4000-8000-000000000201', 'inventory', 20)
  WHERE reason_code = 'stock_received'), 1,
  'inventory reason is visible in the immutable merchant audit');
TRUNCATE p6_order_action;
INSERT INTO p6_order_action SELECT * FROM public.advance_my_merchant_order(
  '90000000-0000-4000-8000-000000000201',
  (SELECT merchant_order_id FROM p6_target), 'accept', NULL, NULL, 1,
  '96000000-0000-4000-8000-000000000021');
SELECT is((SELECT order_status || ':' || order_version || ':' || batch_status
  || ':' || batch_version FROM p6_order_action), 'accepted:2:processing:2',
  'historical order replay remains stable after later fulfillment');

INSERT INTO p6_case SELECT * FROM public.open_my_merchant_after_sale(
  '90000000-0000-4000-8000-000000000201',
  (SELECT merchant_order_id FROM p6_target), 'damaged',
  '96000000-0000-4000-8000-000000000031');
SELECT is((SELECT case_status FROM p6_case), 'opened', 'completed order accepts a finite after-sale reason');

SELECT is((SELECT case_status FROM public.review_my_merchant_after_sale(
  '90000000-0000-4000-8000-000000000201', (SELECT case_id FROM p6_case),
  'start_review', NULL, 1, '96000000-0000-4000-8000-000000000032')),
  'reviewing', 'after-sale enters review');
SELECT is((SELECT case_status || ':' || resolution_code FROM public.review_my_merchant_after_sale(
  '90000000-0000-4000-8000-000000000201', (SELECT case_id FROM p6_case),
  'resolve', 'replacement_recorded', 2,
  '96000000-0000-4000-8000-000000000033')),
  'resolved:replacement_recorded', 'after-sale reaches a recorded terminal resolution');
SELECT is((SELECT case_status || ':' || case_version || ':'
  || COALESCE(resolution_code, 'none') || ':'
  || COALESCE(resolved_at::text, 'none')
  FROM public.review_my_merchant_after_sale(
    '90000000-0000-4000-8000-000000000201', (SELECT case_id FROM p6_case),
    'start_review', NULL, 1, '96000000-0000-4000-8000-000000000032')),
  'reviewing:2:none:none',
  'historical after-sale replay remains stable after terminal resolution');

SELECT is((SELECT count(*)::integer FROM public.list_my_merchant_audit(
  '90000000-0000-4000-8000-000000000201', 'merchant_order', 80)), 3,
  'merchant audit contains each fulfillment transition exactly once');

-- p6_mid_operation_rollback: create a second pending order, then fail the
-- merchant audit insert after inventory, item, order and order-event writes.
-- pgTAP catches the exception in a subtransaction, so every category below
-- must match its pre-call snapshot exactly.
RESET ROLE;
UPDATE public.listings SET status = 'active'
WHERE id = '90000000-0000-4000-8000-000000000501';
UPDATE public.stores SET public_visibility = true
WHERE id = '90000000-0000-4000-8000-000000000201';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p6_set_claims();
TRUNCATE p6_cart;
INSERT INTO p6_cart SELECT * FROM public.put_cart_item(
  '90000000-0000-4000-8000-000000000501', 1, NULL, NULL,
  '96000000-0000-4000-8000-000000000041');
INSERT INTO p6_rollback_checkout SELECT * FROM public.checkout_cart(
  (SELECT max(cart_version) FROM p6_cart),
  'synthetic://delivery/p6-mid-operation-rollback',
  '96000000-0000-4000-8000-000000000042');
RESET ROLE;
UPDATE public.listings SET status = 'inactive'
WHERE id = '90000000-0000-4000-8000-000000000501';
UPDATE public.stores SET public_visibility = false
WHERE id = '90000000-0000-4000-8000-000000000201';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p6_set_claims();
CREATE TEMP TABLE p6_rollback_target AS
SELECT mo.merchant_order_id
FROM public.list_my_merchant_orders(
  '90000000-0000-4000-8000-000000000201') AS mo
WHERE mo.batch_id = (SELECT batch_id FROM p6_rollback_checkout)
LIMIT 1;
GRANT SELECT ON TABLE pg_temp.p6_rollback_target TO authenticated;

RESET ROLE;
CREATE TEMP TABLE p6_rollback_snapshot AS
SELECT
  (SELECT il.on_hand::text || ':' || il.reserved::text || ':' || il.version::text
   FROM public.inventory_levels AS il
   WHERE il.listing_id = '90000000-0000-4000-8000-000000000501') AS inventory_state,
  (SELECT mo.status || ':' || mo.inventory_status || ':' || mo.version::text
   FROM public.merchant_orders AS mo
   WHERE mo.id = (SELECT merchant_order_id FROM p6_rollback_target)) AS order_state,
  (SELECT ob.status || ':' || ob.inventory_status || ':' || ob.version::text
   FROM public.order_batches AS ob
   WHERE ob.id = (SELECT batch_id FROM p6_rollback_checkout)) AS batch_state,
  (SELECT pg_catalog.string_agg(oi.inventory_status || ':' || oi.inventory_version::text,
      ',' ORDER BY oi.id)
   FROM public.order_items AS oi
   WHERE oi.merchant_order_id = (SELECT merchant_order_id FROM p6_rollback_target)) AS items_state,
  (SELECT count(*)::integer FROM public.order_events AS oe
   WHERE oe.merchant_order_id = (SELECT merchant_order_id FROM p6_rollback_target))
    AS order_event_count,
  (SELECT count(*)::integer FROM public.inventory_events AS ie
   WHERE ie.listing_id = '90000000-0000-4000-8000-000000000501')
    AS inventory_event_count,
  (SELECT count(*)::integer FROM public.p4_idempotency_keys AS k
   WHERE k.actor_user_id = '90000000-0000-4000-8000-000000000001')
    AS p4_key_count,
  (SELECT count(*)::integer FROM public.p6_idempotency_keys AS k
   WHERE k.actor_user_id = '90000000-0000-4000-8000-000000000001')
    AS p6_key_count,
  (SELECT count(*)::integer FROM public.merchant_operation_events AS e
   WHERE e.actor_user_id = '90000000-0000-4000-8000-000000000001')
    AS merchant_event_count;
GRANT SELECT ON TABLE pg_temp.p6_rollback_snapshot TO authenticated;

SELECT pg_catalog.set_config('rebuy.test.p6_rollback_order_id',
  (SELECT merchant_order_id::text FROM pg_temp.p6_rollback_target), true);
CREATE OR REPLACE FUNCTION pg_temp.p6_fail_merchant_operation_event()
RETURNS trigger LANGUAGE plpgsql AS $trigger$
BEGIN
  IF NEW.entity_id::text = pg_catalog.current_setting(
      'rebuy.test.p6_rollback_order_id', true)
     AND NEW.event_code = 'merchant_order.rejected'
     AND NEW.reason_code = 'merchant_rejected_listing_issue'
  THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'p6_injected_operation_event_failure';
  END IF;
  RETURN NEW;
END
$trigger$;
CREATE TRIGGER p6_mid_operation_rollback
AFTER INSERT ON public.merchant_operation_events
FOR EACH ROW EXECUTE FUNCTION pg_temp.p6_fail_merchant_operation_event();

SET LOCAL ROLE authenticated;
SELECT pg_temp.p6_set_claims();
SELECT throws_ok(pg_catalog.format(
  'SELECT * FROM public.advance_my_merchant_order(%L, %L, %L, %L, NULL, 1, %L)',
  '90000000-0000-4000-8000-000000000201',
  (SELECT merchant_order_id FROM p6_rollback_target), 'reject', 'listing_issue',
  '96000000-0000-4000-8000-000000000043'),
  'P0001', 'p6_injected_operation_event_failure',
  'mid-operation failure is finite and observable');
RESET ROLE;
SELECT is((SELECT il.on_hand::text || ':' || il.reserved::text || ':' || il.version::text
  FROM public.inventory_levels AS il
  WHERE il.listing_id = '90000000-0000-4000-8000-000000000501'),
  (SELECT inventory_state FROM p6_rollback_snapshot),
  'mid-operation rollback leaves inventory unchanged');
SELECT is((SELECT mo.status || ':' || mo.inventory_status || ':' || mo.version::text
  FROM public.merchant_orders AS mo
  WHERE mo.id = (SELECT merchant_order_id FROM p6_rollback_target)),
  (SELECT order_state FROM p6_rollback_snapshot),
  'mid-operation rollback leaves merchant order unchanged');
SELECT is((SELECT ob.status || ':' || ob.inventory_status || ':' || ob.version::text
  FROM public.order_batches AS ob
  WHERE ob.id = (SELECT batch_id FROM p6_rollback_checkout)),
  (SELECT batch_state FROM p6_rollback_snapshot),
  'mid-operation rollback leaves batch unchanged');
SELECT is((SELECT pg_catalog.string_agg(oi.inventory_status || ':' ||
    oi.inventory_version::text, ',' ORDER BY oi.id)
  FROM public.order_items AS oi
  WHERE oi.merchant_order_id = (SELECT merchant_order_id FROM p6_rollback_target)),
  (SELECT items_state FROM p6_rollback_snapshot),
  'mid-operation rollback leaves order items unchanged');
SELECT is((SELECT count(*)::integer FROM public.order_events AS oe
  WHERE oe.merchant_order_id = (SELECT merchant_order_id FROM p6_rollback_target)),
  (SELECT order_event_count FROM p6_rollback_snapshot),
  'mid-operation rollback leaves order events unchanged');
SELECT is((SELECT count(*)::integer FROM public.inventory_events AS ie
  WHERE ie.listing_id = '90000000-0000-4000-8000-000000000501'),
  (SELECT inventory_event_count FROM p6_rollback_snapshot),
  'mid-operation rollback leaves inventory events unchanged');
SELECT is((SELECT count(*)::integer FROM public.p4_idempotency_keys AS k
  WHERE k.actor_user_id = '90000000-0000-4000-8000-000000000001'),
  (SELECT p4_key_count FROM p6_rollback_snapshot),
  'mid-operation rollback leaves P4 keys unchanged');
SELECT is((SELECT count(*)::integer FROM public.p6_idempotency_keys AS k
  WHERE k.actor_user_id = '90000000-0000-4000-8000-000000000001'),
  (SELECT p6_key_count FROM p6_rollback_snapshot),
  'mid-operation rollback leaves P6 keys unchanged');
SELECT is((SELECT count(*)::integer FROM public.merchant_operation_events AS e
  WHERE e.actor_user_id = '90000000-0000-4000-8000-000000000001'),
  (SELECT merchant_event_count FROM p6_rollback_snapshot),
  'mid-operation rollback leaves merchant events unchanged');
RESET ROLE;
DROP TRIGGER p6_mid_operation_rollback ON public.merchant_operation_events;
DROP FUNCTION pg_temp.p6_fail_merchant_operation_event();

SELECT * FROM finish();
ROLLBACK;
