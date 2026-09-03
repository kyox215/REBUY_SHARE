BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL search_path = pg_catalog, public, extensions;

SELECT ok(
  (
    SELECT count(*) = 3
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname = ANY (ARRAY[
        'merchant_applications', 'merchant_application_private',
        'merchant_application_events'
      ]::name[])
  ),
  'the three P3 tables exist'
);

SELECT ok(
  (
    SELECT count(*) = 3
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY (ARRAY[
        'merchant_applications', 'merchant_application_private',
        'merchant_application_events'
      ]::name[])
      AND c.relrowsecurity
      AND c.relforcerowsecurity
  ),
  'all P3 tables enable and force RLS'
);

SELECT ok(
  (
    SELECT NOT rolsuper AND NOT rolcanlogin AND NOT rolcreatedb
      AND NOT rolcreaterole AND NOT rolinherit AND NOT rolreplication
      AND NOT rolbypassrls
    FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_business_executor'
  ),
  'business executor has all seven restricted attributes'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_catalog.pg_auth_members
    WHERE roleid = 'rebuy_business_executor'::regrole
       OR member = 'rebuy_business_executor'::regrole
  ),
  1,
  'business executor has exactly one bootstrap membership'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS am
    WHERE am.roleid = 'rebuy_business_executor'::regrole
      AND am.member = 'postgres'::regrole
      AND pg_catalog.pg_get_userbyid(am.grantor) = 'supabase_admin'
      AND am.admin_option
      AND NOT am.inherit_option
      AND NOT am.set_option
  ),
  'business executor bootstrap options are exact'
);

SELECT ok(
  NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
  AND NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET'),
  'postgres cannot inherit or set business executor'
);
SELECT ok(
  has_schema_privilege('rebuy_business_executor', 'public', 'USAGE')
  AND has_schema_privilege('rebuy_business_executor', 'private', 'USAGE')
  AND NOT has_schema_privilege('rebuy_business_executor', 'public', 'CREATE')
  AND NOT has_schema_privilege('rebuy_business_executor', 'private', 'CREATE')
  AND NOT has_schema_privilege('rebuy_business_executor', 'auth', 'USAGE'),
  'business executor has only required schema usage'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class
    WHERE relowner = 'rebuy_business_executor'::regrole
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_namespace
    WHERE nspowner = 'rebuy_business_executor'::regrole
  ),
  'business executor owns no table or schema'
);

SELECT ok(
  (
    SELECT count(*) = 7
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'private'
      AND p.proname = ANY (ARRAY[
        'save_merchant_application_impl',
        'get_my_merchant_application_impl',
        'list_merchant_review_queue_impl',
        'get_assigned_merchant_application_impl',
        'assign_merchant_application_impl',
        'review_merchant_application_impl',
        'withdraw_merchant_application_impl'
      ]::name[])
      AND p.prosecdef
      AND p.proowner = 'rebuy_business_executor'::regrole
      AND p.provolatile = 'v'
      AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
  ),
  'all private implementations are empty-path executor definers'
);

SELECT ok(
  (
    SELECT count(*) = 7
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY (ARRAY[
        'save_merchant_application',
        'get_my_merchant_application',
        'list_merchant_review_queue',
        'get_assigned_merchant_application',
        'assign_merchant_application',
        'review_merchant_application',
        'withdraw_merchant_application'
      ]::name[])
      AND NOT p.prosecdef
      AND p.provolatile = 'v'
      AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
  ),
  'all public wrappers are empty-path invokers'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.role_table_grants
    WHERE grantee IN ('anon', 'authenticated', 'service_role')
      AND table_schema = 'public'
      AND table_name IN (
        'merchant_applications', 'merchant_application_private',
        'merchant_application_events'
      )
  ),
  'external roles have no direct P3 table grants'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) AS r(role_name)
    CROSS JOIN unnest(ARRAY[
      'merchant_applications', 'merchant_application_private',
      'merchant_application_events'
    ]) AS t(table_name)
    CROSS JOIN unnest(ARRAY[
      'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'
    ]) AS p(privilege_name)
    WHERE pg_catalog.has_table_privilege(
      r.role_name,
      pg_catalog.format('public.%I', t.table_name),
      p.privilege_name
    )
  ),
  'external roles have no effective P3 table privileges'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) AS r(role_name)
    CROSS JOIN information_schema.columns AS c
    CROSS JOIN unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'REFERENCES']) AS p(privilege_name)
    WHERE c.table_schema = 'public'
      AND c.table_name IN (
        'merchant_applications', 'merchant_application_private',
        'merchant_application_events'
      )
      AND pg_catalog.has_column_privilege(
        r.role_name,
        pg_catalog.format('public.%I', c.table_name),
        c.column_name,
        p.privilege_name
      )
  ),
  'external roles have no effective P3 column privileges'
);

SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.save_merchant_application(text,text,text,text,text,boolean,uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.review_merchant_application(uuid,text,text,uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'private.review_merchant_application_impl(uuid,text,text,uuid)',
    'EXECUTE'
  ),
  'service role has no effective P3 function execution'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.save_merchant_application(text,text,text,text,text,boolean,uuid)',
    'EXECUTE'
  )
  AND has_function_privilege(
    'authenticated',
    'public.review_merchant_application(uuid,text,text,uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.review_merchant_application(uuid,text,text,uuid)',
    'EXECUTE'
  ),
  'only authenticated receives public workflow execution'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'public.save_merchant_application(text,text,text,text,text,boolean,uuid)',
      'public.get_my_merchant_application()',
      'public.list_merchant_review_queue()',
      'public.get_assigned_merchant_application(uuid)',
      'public.assign_merchant_application(uuid,uuid,uuid)',
      'public.review_merchant_application(uuid,text,text,uuid)',
      'public.withdraw_merchant_application(uuid,uuid)'
    ]) AS f(signature)
    WHERE NOT pg_catalog.has_function_privilege('authenticated', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('anon', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('service_role', f.signature, 'EXECUTE')
  ),
  'all public wrappers have exact effective execution ACLs'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'private.save_merchant_application_impl(text,text,text,text,text,boolean,uuid)',
      'private.get_my_merchant_application_impl()',
      'private.list_merchant_review_queue_impl()',
      'private.get_assigned_merchant_application_impl(uuid)',
      'private.assign_merchant_application_impl(uuid,uuid,uuid)',
      'private.review_merchant_application_impl(uuid,text,text,uuid)',
      'private.withdraw_merchant_application_impl(uuid,uuid)'
    ]) AS f(signature)
    WHERE NOT pg_catalog.has_function_privilege('authenticated', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('anon', f.signature, 'EXECUTE')
       OR pg_catalog.has_function_privilege('service_role', f.signature, 'EXECUTE')
  ),
  'all private implementations allow only authenticated direct parity execution'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'private.rebuy_business_reset_context()',
      'private.rebuy_business_require_identity(boolean)',
      'private.rebuy_business_membership_has_permission(uuid,uuid,text)',
      'private.rebuy_business_find_platform_membership(text)'
    ]) AS f(signature)
    CROSS JOIN unnest(ARRAY['anon', 'authenticated', 'service_role']) AS r(role_name)
    WHERE pg_catalog.has_function_privilege(r.role_name, f.signature, 'EXECUTE')
  ),
  'no external role can execute executor-only helpers'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.permissions
    WHERE permission_key IN (
      'merchant_application.assign',
      'merchant_application.read_assigned',
      'merchant_application.review'
    )
      AND is_active
  ),
  3,
  'the three P3 permissions are seeded'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.role_definitions
    WHERE role_key IN ('platform_admin', 'merchant_reviewer')
      AND scope_type = 'platform'
      AND applicable_organization_type = 'platform'
      AND status = 'active'
  ),
  2,
  'platform admin and reviewer roles are seeded'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_index AS i
    JOIN pg_catalog.pg_class AS c ON c.oid = i.indexrelid
    WHERE c.relname = 'merchant_applications_one_open_per_applicant'
      AND i.indisunique
      AND i.indpred IS NOT NULL
  ),
  'one open application per applicant is constrained'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_index AS i
    JOIN pg_catalog.pg_class AS c ON c.oid = i.indexrelid
    WHERE c.relname = 'merchant_application_private_application_applicant_idx'
      AND i.indrelid = 'public.merchant_application_private'::regclass
      AND i.indnkeyatts = 2
  ),
  'private application foreign key has a covering composite index'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conname = 'merchant_application_events_idempotency_key'
      AND conrelid = 'public.merchant_application_events'::regclass
  ),
  'event idempotency is constrained by actor and request key'
);

SELECT ok(
  (
    SELECT pg_catalog.pg_get_constraintdef(oid) LIKE
      'UNIQUE (actor_user_id, idempotency_key)%'
    FROM pg_catalog.pg_constraint
    WHERE conname = 'merchant_application_events_idempotency_key'
      AND conrelid = 'public.merchant_application_events'::regclass
  ),
  'event idempotency uses the actor-key scope'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name IN (
        'merchant_applications', 'merchant_application_private',
        'merchant_application_events'
      )
      AND column_name IN (
        'phone', 'address', 'tax_number', 'bank_account', 'document_blob',
        'review_note'
      )
  ),
  'P3 schema contains no real-document or free-text review fields'
);

SELECT * FROM finish();
ROLLBACK;
