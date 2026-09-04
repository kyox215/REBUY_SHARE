BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL search_path = pg_catalog, public, extensions;

SELECT is((SELECT count(*)::integer FROM pg_catalog.pg_class AS c
  JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname = ANY (ARRAY[
    'merchant_after_sale_cases', 'merchant_operation_events',
    'p6_idempotency_keys']::name[]) AND c.relkind = 'r'), 3,
  'all three P6 tables exist');

SELECT is((SELECT count(*)::integer FROM pg_catalog.pg_class AS c
  JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname = ANY (ARRAY[
    'merchant_after_sale_cases', 'merchant_operation_events',
    'p6_idempotency_keys']::name[]) AND c.relrowsecurity AND c.relforcerowsecurity), 3,
  'all P6 tables enable and force RLS');

SELECT ok(NOT EXISTS (
  SELECT 1 FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) AS r(role_name)
  CROSS JOIN unnest(ARRAY['merchant_after_sale_cases', 'merchant_operation_events',
    'p6_idempotency_keys']) AS t(table_name)
  CROSS JOIN unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE',
    'REFERENCES', 'TRIGGER']) AS p(privilege_name)
  WHERE pg_catalog.has_table_privilege(r.role_name,
    pg_catalog.format('public.%I', t.table_name), p.privilege_name)
), 'external roles have no P6 table privileges');

SELECT ok(NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
  AND NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
  AND NOT pg_catalog.has_schema_privilege('rebuy_business_executor', 'private', 'CREATE'),
  'executor owner handoff capabilities are removed');

SELECT ok(
  (SELECT NOT p.prosecdef
     AND p.proowner = 'rebuy_business_executor'::regrole
     AND p.provolatile = 'v'
     AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
   FROM pg_catalog.pg_proc AS p
   WHERE p.oid = 'private.rebuy_p6_lock_actor_key(uuid)'::regprocedure)
  AND pg_catalog.has_function_privilege('rebuy_business_executor',
    'private.rebuy_p6_lock_actor_key(uuid)', 'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('anon',
    'private.rebuy_p6_lock_actor_key(uuid)', 'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('authenticated',
    'private.rebuy_p6_lock_actor_key(uuid)', 'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('service_role',
    'private.rebuy_p6_lock_actor_key(uuid)', 'EXECUTE'),
  'actor-key lock helper is an executor-owned invoker with executor-only ACL'
);

SELECT is((SELECT count(*)::integer FROM pg_catalog.pg_policies AS p
  WHERE p.schemaname = 'public' AND p.cmd = 'UPDATE'
    AND p.tablename = ANY (ARRAY['stores', 'organizations', 'memberships',
      'role_definitions', 'permissions', 'role_permissions',
      'membership_store_scopes'])
    AND p.roles @> ARRAY['rebuy_business_executor']::name[]
    AND p.qual LIKE '%rebuy.p6.op%'), 7,
  'all seven authorization control tables expose one combined P6 lock branch');

SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_catalog.pg_policies AS p
  WHERE p.schemaname = 'public' AND p.cmd = 'UPDATE'
    AND p.tablename = ANY (ARRAY['stores', 'organizations', 'memberships',
      'role_definitions', 'permissions', 'role_permissions',
      'membership_store_scopes'])
    AND p.roles @> ARRAY['rebuy_business_executor']::name[]
  GROUP BY p.tablename
  HAVING count(*) > 1
), 'authorization locking keeps one permissive executor UPDATE policy per table');

SELECT ok(
  pg_catalog.has_column_privilege('rebuy_business_executor',
    'public.permissions', 'is_active', 'UPDATE')
  AND NOT pg_catalog.has_column_privilege('rebuy_business_executor',
    'public.permissions', 'permission_key', 'UPDATE')
  AND pg_catalog.has_column_privilege('rebuy_business_executor',
    'public.role_permissions', 'is_granted', 'UPDATE')
  AND NOT pg_catalog.has_column_privilege('rebuy_business_executor',
    'public.role_permissions', 'permission_id', 'UPDATE'),
  'new authorization locks grant only the required control-row columns'
);

SELECT is((SELECT count(*)::integer FROM pg_catalog.pg_proc AS p
  JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
  WHERE n.nspname = 'private' AND p.proname = ANY (ARRAY[
    'get_my_merchant_context_impl', 'get_my_merchant_dashboard_impl',
    'list_my_merchant_products_impl', 'list_my_merchant_inventory_impl',
    'list_my_merchant_orders_impl', 'get_my_merchant_order_impl',
    'list_my_merchant_after_sales_impl', 'list_my_merchant_audit_impl',
    'adjust_my_merchant_inventory_impl',
    'advance_my_merchant_order_impl', 'open_my_merchant_after_sale_impl',
    'review_my_merchant_after_sale_impl']::name[])
    AND p.prosecdef AND p.proowner = 'rebuy_business_executor'::regrole
    AND p.provolatile = 'v'
    AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']), 12,
  'all P6 private implementations are volatile empty-path executor definers');

SELECT is((SELECT count(*)::integer FROM pg_catalog.pg_proc AS p
  JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = ANY (ARRAY[
    'get_my_merchant_context', 'get_my_merchant_dashboard',
    'list_my_merchant_products', 'list_my_merchant_inventory',
    'list_my_merchant_orders', 'get_my_merchant_order',
    'list_my_merchant_after_sales', 'list_my_merchant_audit',
    'adjust_my_merchant_inventory',
    'advance_my_merchant_order', 'open_my_merchant_after_sale',
    'review_my_merchant_after_sale']::name[])
    AND NOT p.prosecdef AND p.provolatile = 'v'
    AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']), 12,
  'all P6 public wrappers are volatile empty-path invokers');

SELECT ok(NOT EXISTS (
  SELECT 1 FROM unnest(ARRAY[
    'public.get_my_merchant_context()',
    'public.get_my_merchant_dashboard(uuid)',
    'public.list_my_merchant_products(uuid)',
    'public.list_my_merchant_inventory(uuid)',
    'public.list_my_merchant_orders(uuid)',
    'public.get_my_merchant_order(uuid,uuid)',
    'public.list_my_merchant_after_sales(uuid)',
    'public.list_my_merchant_audit(uuid,text,integer)',
    'public.adjust_my_merchant_inventory(uuid,uuid,integer,text,integer,uuid)',
    'public.advance_my_merchant_order(uuid,uuid,text,text,text,integer,uuid)',
    'public.open_my_merchant_after_sale(uuid,uuid,text,uuid)',
    'public.review_my_merchant_after_sale(uuid,uuid,text,text,integer,uuid)'
  ]) AS f(signature)
  WHERE NOT pg_catalog.has_function_privilege('authenticated', f.signature, 'EXECUTE')
     OR pg_catalog.has_function_privilege('anon', f.signature, 'EXECUTE')
     OR pg_catalog.has_function_privilege('service_role', f.signature, 'EXECUTE')
), 'P6 RPCs are authenticated-only and unavailable to service_role');

SELECT ok(
  pg_catalog.has_function_privilege('authenticated',
    'public.cancel_my_order_batch(uuid,integer,uuid)', 'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('anon',
    'public.cancel_my_order_batch(uuid,integer,uuid)', 'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('service_role',
    'public.cancel_my_order_batch(uuid,integer,uuid)', 'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('authenticated',
    'private.cancel_my_order_batch_impl(uuid,integer,uuid)', 'EXECUTE')
  AND pg_catalog.has_function_privilege('authenticated',
    'private.cancel_my_order_batch_p6_impl(uuid,integer,uuid)', 'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('anon',
    'private.cancel_my_order_batch_p6_impl(uuid,integer,uuid)', 'EXECUTE')
  AND NOT pg_catalog.has_function_privilege('service_role',
    'private.cancel_my_order_batch_p6_impl(uuid,integer,uuid)', 'EXECUTE'),
  'legacy cancellation implementation is closed and P6 parity is authenticated-only'
);

SELECT ok(
  pg_catalog.has_column_privilege('rebuy_business_executor',
    'public.merchant_after_sale_cases', 'status', 'UPDATE')
  AND pg_catalog.has_column_privilege('rebuy_business_executor',
    'public.merchant_after_sale_cases', 'resolution_code', 'UPDATE')
  AND NOT pg_catalog.has_column_privilege('rebuy_business_executor',
    'public.merchant_after_sale_cases', 'buyer_user_id', 'UPDATE')
  AND NOT pg_catalog.has_column_privilege('rebuy_business_executor',
    'public.merchant_after_sale_cases', 'reason_code', 'UPDATE'),
  'after-sale updates are limited to workflow columns'
);

SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_catalog.pg_constraint AS fk
  JOIN pg_catalog.pg_class AS table_class ON table_class.oid = fk.conrelid
  JOIN pg_catalog.pg_namespace AS n ON n.oid = table_class.relnamespace
  WHERE n.nspname = 'public' AND table_class.relname IN (
      'merchant_after_sale_cases', 'merchant_operation_events', 'p6_idempotency_keys')
    AND fk.contype = 'f' AND NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_index AS i
      WHERE i.indrelid = fk.conrelid AND i.indisvalid AND i.indisready
        AND i.indpred IS NULL
        AND ARRAY(
          SELECT (i.indkey::smallint[])[position]
          FROM pg_catalog.generate_series(
            0, pg_catalog.cardinality(fk.conkey) - 1
          ) AS gs(position)
        ) = fk.conkey
    )
), 'every P6 foreign key has a valid non-partial full leading-column index');

SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_catalog.pg_trigger AS t
  JOIN pg_catalog.pg_class AS c ON c.oid = t.tgrelid
  JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname = 'merchant_operation_events'
    AND NOT t.tgisinternal
), 'merchant operation events remain append-only without mutable trigger behavior');

SELECT * FROM finish();
ROLLBACK;
