BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL search_path = pg_catalog, public, extensions;

SELECT is(
  (SELECT count(*)::integer FROM pg_catalog.pg_class AS c
   JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relkind = 'r'
     AND c.relname = ANY (ARRAY['carts', 'cart_items', 'order_batches',
       'merchant_orders', 'order_items', 'order_events',
       'p5_idempotency_keys']::name[])),
  7,
  'all seven P5 tables exist'
);

SELECT is(
  (SELECT count(*)::integer FROM pg_catalog.pg_class AS c
   JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relname = ANY (ARRAY['carts', 'cart_items', 'order_batches',
       'merchant_orders', 'order_items', 'order_events',
       'p5_idempotency_keys']::name[])
     AND c.relrowsecurity AND c.relforcerowsecurity),
  7,
  'all P5 tables enable and force RLS'
);

SELECT ok(
  (SELECT NOT rolsuper AND NOT rolcanlogin AND NOT rolcreatedb
    AND NOT rolcreaterole AND NOT rolinherit AND NOT rolreplication
    AND NOT rolbypassrls FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_business_executor'),
  'business executor remains fully restricted'
);

SELECT ok(
  NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
  AND NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
  AND NOT pg_catalog.has_schema_privilege('rebuy_business_executor', 'private', 'CREATE'),
  'owner handoff capabilities are removed'
);

SELECT is(
  (SELECT pg_catalog.count(*)::integer
   FROM pg_catalog.pg_constraint AS c
   JOIN pg_catalog.pg_class AS r ON r.oid = c.conrelid
   JOIN pg_catalog.pg_namespace AS n ON n.oid = r.relnamespace
   WHERE n.nspname = 'public'
     AND ((r.relname = 'listing_prices'
           AND c.conname = 'listing_prices_minimum_upper_check')
       OR (r.relname = 'listing_price_tiers'
           AND c.conname = 'listing_price_tiers_quantity_upper_check'))
     AND c.contype = 'c' AND c.convalidated
     AND pg_catalog.pg_get_constraintdef(c.oid) LIKE '%minimum_quantity <= 1000000%'),
  2,
  'P5 aligns P4 wholesale MOQ and tier quantities to the shared upper bound'
);

SELECT is(
  (SELECT count(*)::integer FROM pg_catalog.pg_proc AS p
   JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
   WHERE n.nspname = 'private'
     AND p.proname = ANY (ARRAY['search_catalog_impl', 'get_my_cart_impl',
       'put_cart_item_impl', 'remove_cart_item_impl', 'checkout_cart_impl',
       'list_my_orders_impl', 'get_my_order_impl',
       'cancel_my_order_batch_impl']::name[])
     AND p.prosecdef AND p.proowner = 'rebuy_business_executor'::regrole
     AND p.provolatile = 'v'
     AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']),
  8,
  'all P5 private implementations are volatile empty-path executor definers'
);

SELECT is(
  (SELECT count(*)::integer FROM pg_catalog.pg_proc AS p
   JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = ANY (ARRAY['search_catalog', 'get_my_cart',
       'put_cart_item', 'remove_cart_item', 'checkout_cart',
       'list_my_orders', 'get_my_order', 'cancel_my_order_batch']::name[])
     AND NOT p.prosecdef AND p.provolatile = 'v'
     AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']),
  8,
  'all P5 public wrappers are volatile empty-path invokers'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) AS r(role_name)
    CROSS JOIN unnest(ARRAY['carts', 'cart_items', 'order_batches',
      'merchant_orders', 'order_items', 'order_events',
      'p5_idempotency_keys']) AS t(table_name)
    CROSS JOIN unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE',
      'TRUNCATE', 'REFERENCES', 'TRIGGER']) AS p(privilege_name)
    WHERE pg_catalog.has_table_privilege(r.role_name,
      pg_catalog.format('public.%I', t.table_name), p.privilege_name)
  ),
  'external roles have no P5 table privileges'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) AS r(role_name)
    CROSS JOIN information_schema.columns AS c
    CROSS JOIN unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'REFERENCES']) AS p(privilege_name)
    WHERE c.table_schema = 'public'
      AND c.table_name IN ('carts', 'cart_items', 'order_batches',
        'merchant_orders', 'order_items', 'order_events', 'p5_idempotency_keys')
      AND pg_catalog.has_column_privilege(r.role_name,
        pg_catalog.format('public.%I', c.table_name), c.column_name, p.privilege_name)
  ),
  'external roles have no P5 column privileges'
);

SELECT ok(
  pg_catalog.has_function_privilege('anon',
    'public.search_catalog(text,text,integer,integer)', 'EXECUTE')
  AND pg_catalog.has_function_privilege('authenticated',
    'public.search_catalog(text,text,integer,integer)', 'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('service_role',
    'public.search_catalog(text,text,integer,integer)', 'EXECUTE'),
  'catalog search is exposed only to anon and authenticated'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM unnest(ARRAY[
      'public.get_my_cart()',
      'public.put_cart_item(uuid,integer,integer,integer,uuid)',
      'public.remove_cart_item(uuid,integer,integer,uuid)',
      'public.checkout_cart(integer,text,uuid)',
      'public.list_my_orders()',
      'public.get_my_order(uuid)',
      'public.cancel_my_order_batch(uuid,integer,uuid)'
    ]) AS f(signature)
    WHERE NOT pg_catalog.has_function_privilege('authenticated', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('anon', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('service_role', f.signature, 'EXECUTE')
  ),
  'buyer RPCs are authenticated-only and unavailable to service_role'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM unnest(ARRAY[
      'private.get_my_cart_impl()',
      'private.put_cart_item_impl(uuid,integer,integer,integer,uuid)',
      'private.remove_cart_item_impl(uuid,integer,integer,uuid)',
      'private.checkout_cart_impl(integer,text,uuid)',
      'private.list_my_orders_impl()',
      'private.get_my_order_impl(uuid)',
      'private.cancel_my_order_batch_impl(uuid,integer,uuid)'
    ]) AS f(signature)
    WHERE NOT pg_catalog.has_function_privilege('authenticated', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('anon', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('service_role', f.signature, 'EXECUTE')
  ),
  'direct private parity surface matches authenticated buyer wrappers'
);

SELECT ok(
  NOT pg_catalog.has_function_privilege('authenticated',
    'private.change_inventory_reservation_impl(uuid,integer,text,integer,text,uuid)',
    'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('anon',
    'private.change_inventory_reservation_impl(uuid,integer,text,integer,text,uuid)',
    'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('service_role',
    'private.change_inventory_reservation_impl(uuid,integer,text,integer,text,uuid)',
    'EXECUTE'),
  'inventory reservation primitive remains private to the isolated executor'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY['anon', 'authenticated', 'service_role',
      'rebuy_invite_executor']) AS r(role_name)
    CROSS JOIN unnest(ARRAY[
      'private.rebuy_p5_clear_context()',
      'private.rebuy_p5_reset_context()',
      'private.rebuy_p5_derived_uuid(uuid,text)',
      'private.rebuy_p5_lock_pricing_context(uuid)'
    ]) AS f(signature)
    WHERE pg_catalog.has_function_privilege(r.role_name, f.signature, 'EXECUTE')
  )
  AND NOT EXISTS (
    SELECT 1 FROM unnest(ARRAY[
      'private.rebuy_p5_clear_context()',
      'private.rebuy_p5_reset_context()',
      'private.rebuy_p5_derived_uuid(uuid,text)',
      'private.rebuy_p5_lock_pricing_context(uuid)'
    ]) AS f(signature)
    WHERE NOT pg_catalog.has_function_privilege(
      'rebuy_business_executor', f.signature, 'EXECUTE')
  ),
  'P5 helpers are executable only by the isolated executor'
);

SELECT ok(
  NOT pg_catalog.has_table_privilege(
    'rebuy_business_executor', 'public.order_items', 'UPDATE')
  AND pg_catalog.has_column_privilege(
    'rebuy_business_executor', 'public.order_items', 'inventory_status', 'UPDATE')
  AND pg_catalog.has_column_privilege(
    'rebuy_business_executor', 'public.order_items', 'inventory_version', 'UPDATE')
  AND pg_catalog.has_column_privilege(
    'rebuy_business_executor', 'public.order_items', 'updated_at', 'UPDATE')
  AND NOT pg_catalog.has_column_privilege(
    'rebuy_business_executor', 'public.order_items', 'buyer_user_id', 'UPDATE')
  AND NOT pg_catalog.has_column_privilege(
    'rebuy_business_executor', 'public.order_items', 'unit_amount_cents', 'UPDATE')
  AND NOT pg_catalog.has_column_privilege(
    'rebuy_business_executor', 'public.order_items', 'title_snapshot', 'UPDATE'),
  'executor can update only order-item fulfillment columns, not immutable snapshots'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint AS fk
    JOIN pg_catalog.pg_class AS c ON c.oid = fk.conrelid
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE fk.contype = 'f' AND n.nspname = 'public'
      AND c.relname IN ('carts', 'cart_items', 'order_batches',
        'merchant_orders', 'order_items', 'order_events',
        'p5_idempotency_keys')
      AND NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_index AS i
        WHERE i.indrelid = fk.conrelid
          AND i.indisvalid AND i.indisready AND i.indpred IS NULL
          AND ARRAY(
            SELECT (i.indkey::smallint[])[position]
            FROM pg_catalog.generate_series(
              0, pg_catalog.cardinality(fk.conkey) - 1
            ) AS gs(position)
          ) = fk.conkey
      )
  ),
  'every P5 foreign key has a valid non-partial full leading-column index'
);

SELECT is(
  (SELECT count(*)::integer FROM pg_catalog.pg_indexes
   WHERE schemaname = 'public' AND indexname = 'carts_one_active_per_owner'
     AND indexdef LIKE '%WHERE (status = ''active''::text)%'),
  1,
  'one active cart per owner is enforced by a partial unique index'
);

SELECT is(
  (SELECT count(*)::integer FROM pg_catalog.pg_constraint
   WHERE conrelid = 'public.order_batches'::regclass
     AND conname IN ('order_batches_delivery_ref_check',
       'order_batches_currency_check', 'order_batches_amount_check',
       'order_batches_state_check')),
  4,
  'order batch synthetic, currency, amount and state constraints exist'
);

SELECT is(
  (SELECT count(*)::integer FROM pg_catalog.pg_policy AS p
   JOIN pg_catalog.pg_class AS c ON c.oid = p.polrelid
   JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relname = ANY (ARRAY['carts', 'cart_items', 'order_batches',
       'merchant_orders', 'order_items', 'order_events',
       'p5_idempotency_keys']::name[])
     AND p.polpermissive
     AND 'rebuy_business_executor'::regrole::oid = ANY (p.polroles)),
  7,
  'each P5 table has one executor policy'
);

SELECT ok(
  pg_catalog.has_column_privilege(
    'rebuy_business_executor', 'public.role_definitions', 'status', 'UPDATE')
  AND NOT pg_catalog.has_table_privilege(
    'rebuy_business_executor', 'public.role_definitions', 'UPDATE')
  AND EXISTS (
    SELECT 1 FROM pg_catalog.pg_policy AS p
    WHERE p.polrelid = 'public.role_definitions'::regclass
      AND p.polname = 'role_definitions_p5_pricing_lock'
      AND p.polcmd = 'w'
      AND pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid) = 'false'
  ),
  'pricing can share-lock active role metadata but cannot mutate it'
);

SELECT is(
  (SELECT count(*)::integer FROM pg_catalog.pg_policy AS p
   WHERE p.polrelid = ANY (ARRAY[
     'public.memberships'::regclass,
     'public.organizations'::regclass,
     'public.membership_store_scopes'::regclass
   ])
     AND p.polcmd = 'w'
     AND 'rebuy_business_executor'::regrole::oid = ANY (p.polroles)),
  3,
  'shared pricing-control tables retain one combined executor update policy each'
);

SELECT * FROM finish();
ROLLBACK;
