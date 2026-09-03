BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL search_path = pg_catalog, public, extensions;

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r'
      AND c.relname = ANY (ARRAY[
        'wholesale_applications', 'wholesale_application_private',
        'wholesale_qualifications', 'wholesale_application_events',
        'categories', 'products', 'product_variants', 'listings',
        'listing_prices', 'listing_price_tiers', 'inventory_levels',
        'secondhand_units', 'catalog_events', 'inventory_events',
        'p4_idempotency_keys'
      ]::name[])
  ),
  15,
  'all fifteen P4 tables exist'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY (ARRAY[
        'wholesale_applications', 'wholesale_application_private',
        'wholesale_qualifications', 'wholesale_application_events',
        'categories', 'products', 'product_variants', 'listings',
        'listing_prices', 'listing_price_tiers', 'inventory_levels',
        'secondhand_units', 'catalog_events', 'inventory_events',
        'p4_idempotency_keys'
      ]::name[])
      AND c.relrowsecurity AND c.relforcerowsecurity
  ),
  15,
  'all P4 tables enable and force RLS'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM (
      SELECT c.oid, command.code
      FROM pg_catalog.pg_policy AS p
      JOIN pg_catalog.pg_class AS c ON c.oid = p.polrelid
      JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
      CROSS JOIN (VALUES ('r'::"char"), ('a'::"char"),
        ('w'::"char"), ('d'::"char")) AS command(code)
      WHERE n.nspname = 'public' AND p.polpermissive
        AND 'rebuy_business_executor'::regrole::oid = ANY (p.polroles)
        AND p.polcmd IN ('*'::"char", command.code)
      GROUP BY c.oid, command.code
      HAVING count(*) > 1
    ) AS duplicate_permissive_policy
  ),
  0,
  'business executor has at most one permissive policy per public table action'
);

SELECT ok(
  (
    SELECT NOT rolsuper AND NOT rolcanlogin AND NOT rolcreatedb
      AND NOT rolcreaterole AND NOT rolinherit AND NOT rolreplication
      AND NOT rolbypassrls
    FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_business_executor'
  ),
  'business executor retains all seven restricted attributes'
);

SELECT ok(
  NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
  AND NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
  AND NOT pg_catalog.has_schema_privilege('rebuy_business_executor', 'private', 'CREATE'),
  'P4 owner handoff leaves no postgres set-role or executor create capability'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'private'
      AND p.proname = ANY (ARRAY[
        'save_wholesale_application_impl',
        'get_my_wholesale_application_impl',
        'list_wholesale_review_queue_impl',
        'get_assigned_wholesale_application_impl',
        'assign_wholesale_application_impl',
        'review_wholesale_application_impl',
        'change_wholesale_qualification_impl',
        'withdraw_wholesale_application_impl',
        'upsert_catalog_listing_impl', 'get_catalog_quote_impl',
        'list_public_catalog_impl', 'adjust_inventory_impl',
        'change_inventory_reservation_impl'
      ]::name[])
      AND p.prosecdef
      AND p.proowner = 'rebuy_business_executor'::regrole
      AND p.provolatile = 'v'
      AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
  ),
  13,
  'all private P4 implementations are volatile empty-path executor definers'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY (ARRAY[
        'save_wholesale_application', 'get_my_wholesale_application',
        'list_wholesale_review_queue', 'get_assigned_wholesale_application',
        'assign_wholesale_application', 'review_wholesale_application',
        'change_wholesale_qualification', 'withdraw_wholesale_application',
        'upsert_catalog_listing', 'get_catalog_quote',
        'list_public_catalog', 'adjust_inventory'
      ]::name[])
      AND NOT p.prosecdef
      AND p.provolatile = 'v'
      AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
  ),
  12,
  'all twelve public P4 RPCs are volatile empty-path invokers'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'change_inventory_reservation'
  ),
  0,
  'P5-only inventory reservation has no public P4 RPC'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) AS r(role_name)
    CROSS JOIN unnest(ARRAY[
      'wholesale_applications', 'wholesale_application_private',
      'wholesale_qualifications', 'wholesale_application_events',
      'categories', 'products', 'product_variants', 'listings',
      'listing_prices', 'listing_price_tiers', 'inventory_levels',
      'secondhand_units', 'catalog_events', 'inventory_events',
      'p4_idempotency_keys'
    ]) AS t(table_name)
    CROSS JOIN unnest(ARRAY[
      'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'
    ]) AS p(privilege_name)
    WHERE pg_catalog.has_table_privilege(
      r.role_name, pg_catalog.format('public.%I', t.table_name), p.privilege_name
    )
  ),
  'external roles have no effective P4 table privileges'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) AS r(role_name)
    CROSS JOIN information_schema.columns AS c
    CROSS JOIN unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'REFERENCES']) AS p(privilege_name)
    WHERE c.table_schema = 'public'
      AND c.table_name IN (
        'wholesale_applications', 'wholesale_application_private',
        'wholesale_qualifications', 'wholesale_application_events',
        'categories', 'products', 'product_variants', 'listings',
        'listing_prices', 'listing_price_tiers', 'inventory_levels',
        'secondhand_units', 'catalog_events', 'inventory_events',
        'p4_idempotency_keys'
      )
      AND pg_catalog.has_column_privilege(
        r.role_name, pg_catalog.format('public.%I', c.table_name),
        c.column_name, p.privilege_name
      )
  ),
  'external roles have no effective P4 column privileges'
);

SELECT ok(
  NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.organizations', 'SELECT')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.memberships', 'SELECT')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.membership_store_scopes', 'SELECT')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.stores', 'SELECT')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.role_definitions', 'SELECT')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.permissions', 'SELECT')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.role_permissions', 'SELECT')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.p4_idempotency_keys', 'UPDATE'),
  'executor receives no widened table-level ACL on existing catalogs or idempotency rows'
);

SELECT ok(
  pg_catalog.has_column_privilege('rebuy_business_executor', 'public.organizations', 'id', 'SELECT')
  AND pg_catalog.has_column_privilege('rebuy_business_executor', 'public.organizations', 'status', 'SELECT')
  AND NOT pg_catalog.has_column_privilege('rebuy_business_executor', 'public.organizations', 'display_name', 'SELECT')
  AND pg_catalog.has_column_privilege('rebuy_business_executor', 'public.stores', 'display_name', 'SELECT')
  AND NOT pg_catalog.has_column_privilege('rebuy_business_executor', 'public.stores', 'slug', 'SELECT')
  AND pg_catalog.has_column_privilege('rebuy_business_executor', 'public.memberships', 'role_definition_id', 'SELECT')
  AND NOT pg_catalog.has_column_privilege('rebuy_business_executor', 'public.memberships', 'invited_by', 'SELECT')
  AND pg_catalog.has_column_privilege('rebuy_business_executor', 'public.role_definitions', 'assignable', 'SELECT')
  AND NOT pg_catalog.has_column_privilege('rebuy_business_executor', 'public.role_definitions', 'created_at', 'SELECT')
  AND pg_catalog.has_column_privilege('rebuy_business_executor', 'public.permissions', 'permission_key', 'SELECT')
  AND NOT pg_catalog.has_column_privilege('rebuy_business_executor', 'public.permissions', 'risk_level', 'SELECT')
  AND pg_catalog.has_column_privilege('rebuy_business_executor', 'public.role_permissions', 'is_granted', 'SELECT')
  AND NOT pg_catalog.has_column_privilege('rebuy_business_executor', 'public.role_permissions', 'created_at', 'SELECT'),
  'executor retains only the required effective columns on shared authorization catalogs'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'public.save_wholesale_application(text,text,text,text,boolean,uuid)',
      'public.get_my_wholesale_application()',
      'public.list_wholesale_review_queue()',
      'public.get_assigned_wholesale_application(uuid)',
      'public.assign_wholesale_application(uuid,uuid,uuid)',
      'public.review_wholesale_application(uuid,text,text,timestamptz,uuid)',
      'public.change_wholesale_qualification(uuid,text,uuid)',
      'public.withdraw_wholesale_application(uuid,uuid)',
      'public.upsert_catalog_listing(uuid,uuid,text,text,text,text,text,text,text,integer,integer,integer,jsonb,integer,text,text,text,integer,integer,boolean,integer,uuid)',
      'public.adjust_inventory(uuid,integer,integer,uuid)'
    ]) AS f(signature)
    WHERE NOT pg_catalog.has_function_privilege('authenticated', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('anon', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('service_role', f.signature, 'EXECUTE')
  ),
  'authenticated-only public P4 RPCs have exact effective execution ACLs'
);

SELECT ok(
  pg_catalog.has_function_privilege(
    'anon', 'public.get_catalog_quote(uuid,integer)', 'EXECUTE'
  )
  AND pg_catalog.has_function_privilege(
    'authenticated', 'public.get_catalog_quote(uuid,integer)', 'EXECUTE'
  )
  AND pg_catalog.has_function_privilege(
    'anon', 'public.list_public_catalog()', 'EXECUTE'
  )
  AND pg_catalog.has_function_privilege(
    'authenticated', 'public.list_public_catalog()', 'EXECUTE'
  )
  AND NOT pg_catalog.has_function_privilege(
    'service_role', 'public.get_catalog_quote(uuid,integer)', 'EXECUTE'
  )
  AND NOT pg_catalog.has_function_privilege(
    'service_role', 'public.list_public_catalog()', 'EXECUTE'
  ),
  'public catalog DTO RPCs are callable only by anon and authenticated'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'private.save_wholesale_application_impl(text,text,text,text,boolean,uuid)',
      'private.get_my_wholesale_application_impl()',
      'private.list_wholesale_review_queue_impl()',
      'private.get_assigned_wholesale_application_impl(uuid)',
      'private.assign_wholesale_application_impl(uuid,uuid,uuid)',
      'private.review_wholesale_application_impl(uuid,text,text,timestamptz,uuid)',
      'private.change_wholesale_qualification_impl(uuid,text,uuid)',
      'private.withdraw_wholesale_application_impl(uuid,uuid)',
      'private.upsert_catalog_listing_impl(uuid,uuid,text,text,text,text,text,text,text,integer,integer,integer,jsonb,integer,text,text,text,integer,integer,boolean,integer,uuid)',
      'private.adjust_inventory_impl(uuid,integer,integer,uuid)'
    ]) AS f(signature)
    WHERE NOT pg_catalog.has_function_privilege('authenticated', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('anon', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('service_role', f.signature, 'EXECUTE')
  ),
  'authenticated-only private implementations have exact direct-parity ACLs'
);

SELECT ok(
  pg_catalog.has_function_privilege(
    'anon', 'private.get_catalog_quote_impl(uuid,integer)', 'EXECUTE'
  )
  AND pg_catalog.has_function_privilege(
    'authenticated', 'private.get_catalog_quote_impl(uuid,integer)', 'EXECUTE'
  )
  AND pg_catalog.has_function_privilege(
    'anon', 'private.list_public_catalog_impl()', 'EXECUTE'
  )
  AND pg_catalog.has_function_privilege(
    'authenticated', 'private.list_public_catalog_impl()', 'EXECUTE'
  )
  AND NOT pg_catalog.has_function_privilege(
    'service_role', 'private.get_catalog_quote_impl(uuid,integer)', 'EXECUTE'
  )
  AND NOT pg_catalog.has_function_privilege(
    'service_role', 'private.list_public_catalog_impl()', 'EXECUTE'
  ),
  'private public-catalog implementations preserve exact direct-parity ACLs'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) AS r(role_name)
    WHERE pg_catalog.has_function_privilege(
      r.role_name,
      'private.change_inventory_reservation_impl(uuid,integer,text,integer,text,uuid)',
      'EXECUTE'
    )
  ),
  'P5-only reservation primitive is inaccessible to every external role'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'private.rebuy_p4_reset_context()',
      'private.rebuy_p4_find_merchant_membership(uuid,uuid,uuid,text)',
      'private.rebuy_p4_active_wholesale_qualification(uuid)'
    ]) AS f(signature)
    CROSS JOIN unnest(ARRAY['anon', 'authenticated', 'service_role']) AS r(role_name)
    WHERE pg_catalog.has_function_privilege(r.role_name, f.signature, 'EXECUTE')
  ),
  'no external role can execute P4 executor-only helpers'
);

SELECT is(
  (
    SELECT count(*)::integer FROM public.permissions
    WHERE permission_key IN (
      'catalog.write', 'listing.publish', 'pricing.write', 'inventory.adjust',
      'wholesale_application.assign', 'wholesale_application.read_assigned',
      'wholesale_application.review', 'wholesale_qualification.manage'
    ) AND is_active
  ),
  8,
  'all eight P4 permissions are seeded active'
);

SELECT is(
  (
    SELECT count(*)::integer FROM public.categories
    WHERE slug IN ('electronics', 'phone-accessories', 'secondhand', 'computers')
      AND status = 'active'
  ),
  4,
  'four synthetic-safe public categories are seeded'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_catalog.pg_constraint
    WHERE conrelid = 'public.p4_idempotency_keys'::regclass
      AND contype = 'p'
      AND pg_catalog.pg_get_constraintdef(oid) =
        'PRIMARY KEY (actor_user_id, idempotency_key)'
  ),
  'actor and key form the global P4 idempotency primary key'
);

SELECT ok(
  (
    SELECT attnotnull FROM pg_catalog.pg_attribute
    WHERE attrelid = 'public.inventory_events'::regclass
      AND attname = 'actor_user_id'
  ),
  'inventory audit actor is mandatory'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint AS fk
    JOIN pg_catalog.pg_class AS c ON c.oid = fk.conrelid
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE fk.contype = 'f' AND n.nspname = 'public'
      AND c.relname IN (
        'wholesale_applications', 'wholesale_application_private',
        'wholesale_qualifications', 'wholesale_application_events',
        'categories', 'products', 'product_variants', 'listings',
        'listing_prices', 'listing_price_tiers', 'inventory_levels',
        'secondhand_units', 'catalog_events', 'inventory_events',
        'p4_idempotency_keys'
      )
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
  'every P4 foreign key has a full leading-column covering index'
);

SELECT ok(
  NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.catalog_events', 'UPDATE')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.catalog_events', 'DELETE')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.inventory_events', 'UPDATE')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.inventory_events', 'DELETE')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.wholesale_application_events', 'UPDATE')
  AND NOT pg_catalog.has_table_privilege('rebuy_business_executor', 'public.wholesale_application_events', 'DELETE'),
  'all P4 audit streams are append-only for the executor'
);

SELECT * FROM finish();
ROLLBACK;
