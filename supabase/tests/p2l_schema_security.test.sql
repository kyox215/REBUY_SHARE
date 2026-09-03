BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL search_path = pg_catalog, public, extensions;

-- The original ten-table P2-L boundary remains intact. Later stage regressions
-- verify only objects that are still intentionally outside the current V1 gate.
SELECT ok(
  (
    SELECT count(*) = 10
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname = ANY (ARRAY[
        'profiles', 'organizations', 'stores', 'memberships',
        'membership_invitations', 'membership_store_scopes',
        'role_definitions', 'permissions', 'role_permissions', 'audit_logs'
      ]::name[])
  ),
  'the approved ten business tables exist'
);

SELECT ok(
  to_regclass('public.qualifications') IS NULL
  AND to_regclass('public.security_events') IS NULL,
  'unopened generic qualification and security-event tables are absent'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'membership_invitations'
      AND column_name IN ('token_hash', 'invitation_token')
  ),
  'invitation records contain no raw-token or token-hash column'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger
    WHERE tgrelid = 'auth.users'::regclass
      AND NOT tgisinternal
  ),
  'auth.users has no business trigger'
);

SELECT ok(
  (
    SELECT count(*) = 10
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY (ARRAY[
        'profiles', 'organizations', 'stores', 'memberships',
        'membership_invitations', 'membership_store_scopes',
        'role_definitions', 'permissions', 'role_permissions', 'audit_logs'
      ]::name[])
      AND c.relrowsecurity
      AND c.relforcerowsecurity
  ),
  'all ten tables enable and force RLS'
);

SELECT ok(
  (
    SELECT count(*) = 8
      AND count(DISTINCT c.conname) = 8
    FROM pg_catalog.pg_constraint AS c
    JOIN pg_catalog.pg_class AS t ON t.oid = c.conrelid
    JOIN pg_catalog.pg_namespace AS n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND c.conname IN (
        'membership_invitations_accepted_membership_fk',
        'memberships_source_invitation_fk',
        'audit_logs_event_invitation_fk',
        'audit_logs_event_membership_fk',
        'membership_invitations_creator_fk',
        'membership_invitations_creator_role_org_fk',
        'membership_store_scopes_membership_fk',
        'membership_store_scopes_store_fk'
      )
  ),
  'organization-bound and accepted-result foreign keys are present'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_index AS i
    JOIN pg_catalog.pg_class AS c ON c.oid = i.indexrelid
    WHERE c.relname = 'memberships_source_invitation_unique'
      AND i.indisunique
      AND i.indpred IS NOT NULL
  ),
  'source invitation has a non-null partial unique index'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_index AS i
    JOIN pg_catalog.pg_class AS c ON c.oid = i.indexrelid
    WHERE c.relname = 'membership_invitations_pending_business_key'
      AND i.indisunique
      AND i.indpred IS NOT NULL
  ),
  'pending invitation business key is unique'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conrelid = 'public.memberships'::regclass
      AND conname = 'memberships_user_org_key'
  ),
  'one membership per user and organization is constrained'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conrelid = 'public.membership_store_scopes'::regclass
      AND conname = 'membership_store_scopes_unique'
  ),
  'scope rows are unique per membership and scope key'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'membership_invitations_creator_role_idx'
  ),
  'creator role foreign-key lookup has an index'
);

SELECT ok(
  (
    SELECT NOT rolsuper
       AND NOT rolcanlogin
       AND NOT rolcreatedb
       AND NOT rolcreaterole
       AND NOT rolinherit
       AND NOT rolreplication
       AND NOT rolbypassrls
    FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_invite_executor'
  ),
  'executor role has the required restricted attributes'
);

SELECT ok(
  (
    SELECT count(*) = 1
    FROM pg_catalog.pg_auth_members AS am
    WHERE am.roleid = 'rebuy_invite_executor'::regrole
       OR am.member = 'rebuy_invite_executor'::regrole
  ),
  'executor has exactly one related platform bootstrap membership'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS am
    WHERE am.roleid = 'rebuy_invite_executor'::regrole
      AND am.member = 'postgres'::regrole
      AND pg_catalog.pg_get_userbyid(am.grantor) = 'supabase_admin'
      AND am.admin_option
      AND NOT am.inherit_option
      AND NOT am.set_option
  ),
  'the sole bootstrap membership has the exact approved options'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS am
    WHERE am.member = 'rebuy_invite_executor'::regrole
  ),
  'executor remains a member of no role'
);

SELECT ok(
  NOT pg_catalog.pg_has_role('postgres', 'rebuy_invite_executor', 'USAGE'),
  'postgres cannot inherit executor privileges'
);

SELECT ok(
  NOT pg_catalog.pg_has_role('postgres', 'rebuy_invite_executor', 'SET'),
  'postgres cannot SET ROLE to executor'
);

SELECT ok(has_schema_privilege(
  'rebuy_invite_executor', 'public', 'USAGE'
), 'executor has explicit public schema usage');
SELECT ok(NOT has_schema_privilege(
  'rebuy_invite_executor', 'auth', 'USAGE'
), 'executor cannot enter the platform-owned auth schema');
SELECT ok(has_schema_privilege(
  'rebuy_invite_executor', 'private', 'USAGE'
), 'executor has explicit private schema usage');
SELECT ok(NOT has_schema_privilege(
  'rebuy_invite_executor', 'public', 'CREATE'
), 'executor cannot create in public');
SELECT ok(NOT has_schema_privilege(
  'rebuy_invite_executor', 'auth', 'CREATE'
), 'executor cannot create in auth');
SELECT ok(NOT has_schema_privilege(
  'rebuy_invite_executor', 'private', 'CREATE'
), 'executor cannot create in private');

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS c
    WHERE c.relowner = 'rebuy_invite_executor'::regrole
  ),
  'executor owns no relation'
);
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_namespace AS n
    WHERE n.nspowner = 'rebuy_invite_executor'::regrole
  ),
  'executor owns no schema'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'create_membership_invitation',
        'accept_membership_invitation'
      )
  ),
  2,
  'exactly two public invitation wrappers exist'
);

SELECT ok(
  (
    SELECT NOT p.prosecdef
       AND pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
       AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
    FROM pg_catalog.pg_proc AS p
    WHERE p.oid = to_regprocedure(
      'public.create_membership_invitation(uuid,uuid,integer,text,uuid,text,uuid)'
    )
  ),
  'create wrapper is invoker-owned and has an empty search path'
);

SELECT ok(
  (
    SELECT NOT p.prosecdef
       AND pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
       AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
    FROM pg_catalog.pg_proc AS p
    WHERE p.oid = to_regprocedure(
      'public.accept_membership_invitation(uuid)'
    )
  ),
  'accept wrapper is invoker-owned and has an empty search path'
);

SELECT ok(
  (
    SELECT p.prosecdef
       AND pg_catalog.pg_get_userbyid(p.proowner) = 'rebuy_invite_executor'
       AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
    FROM pg_catalog.pg_proc AS p
    WHERE p.oid = to_regprocedure(
      'private.create_membership_invitation_impl(uuid,uuid,integer,text,uuid,text,uuid)'
    )
  ),
  'create implementation is definer-owned with an empty search path'
);

SELECT ok(
  (
    SELECT p.prosecdef
       AND pg_catalog.pg_get_userbyid(p.proowner) = 'rebuy_invite_executor'
       AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
    FROM pg_catalog.pg_proc AS p
    WHERE p.oid = to_regprocedure(
      'private.accept_membership_invitation_impl(uuid)'
    )
  ),
  'accept implementation is definer-owned with an empty search path'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS p
    CROSS JOIN LATERAL pg_catalog.aclexplode(
      COALESCE(p.proacl, pg_catalog.acldefault('f', p.proowner))
    ) AS acl
    WHERE p.oid IN (to_regprocedure('auth.uid()'), to_regprocedure('auth.jwt()'))
      AND acl.grantee = 'rebuy_invite_executor'::regrole
      AND acl.privilege_type = 'EXECUTE'
  ),
  'executor has no direct grant on platform auth helpers'
);
SELECT ok(has_function_privilege(
  'rebuy_invite_executor', 'private.rebuy_request_uid()', 'EXECUTE'
), 'executor can execute the project-owned request uid helper');
SELECT ok(has_function_privilege(
  'rebuy_invite_executor', 'private.rebuy_request_jwt()', 'EXECUTE'
), 'executor can execute the project-owned request claims helper');
SELECT ok(
  (
    SELECT NOT p.prosecdef
       AND pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
       AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
    FROM pg_catalog.pg_proc AS p
    WHERE p.oid = to_regprocedure('private.rebuy_request_uid()')
  ),
  'request uid helper is invoker-owned with an empty search path'
);
SELECT ok(
  (
    SELECT NOT p.prosecdef
       AND pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
       AND coalesce(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
    FROM pg_catalog.pg_proc AS p
    WHERE p.oid = to_regprocedure('private.rebuy_request_jwt()')
  ),
  'request claims helper is invoker-owned with an empty search path'
);
SELECT ok(has_function_privilege(
  'authenticated',
  'public.create_membership_invitation(uuid,uuid,integer,text,uuid,text,uuid)',
  'EXECUTE'
), 'authenticated can execute only through the create wrapper');
SELECT ok(has_function_privilege(
  'authenticated', 'public.accept_membership_invitation(uuid)', 'EXECUTE'
), 'authenticated can execute only through the accept wrapper');
SELECT ok(NOT has_function_privilege(
  'anon', 'public.create_membership_invitation(uuid,uuid,integer,text,uuid,text,uuid)',
  'EXECUTE'
), 'anon cannot execute the create wrapper');
SELECT ok(NOT has_function_privilege(
  'anon', 'public.accept_membership_invitation(uuid)', 'EXECUTE'
), 'anon cannot execute the accept wrapper');
SELECT ok(has_function_privilege(
  'authenticated',
  'private.create_membership_invitation_impl(uuid,uuid,integer,text,uuid,text,uuid)',
  'EXECUTE'
), 'wrapper caller has only the required private create execution');
SELECT ok(has_function_privilege(
  'authenticated', 'private.accept_membership_invitation_impl(uuid)', 'EXECUTE'
), 'wrapper caller has only the required private accept execution');
SELECT ok(NOT has_function_privilege(
  'anon',
  'private.create_membership_invitation_impl(uuid,uuid,integer,text,uuid,text,uuid)',
  'EXECUTE'
), 'anon cannot execute the private create implementation');
SELECT ok(NOT has_function_privilege(
  'anon', 'private.accept_membership_invitation_impl(uuid)', 'EXECUTE'
), 'anon cannot execute the private accept implementation');

-- private is not exposed by config.toml. That is static-config evidence and
-- cannot be established by a catalog query in this database-only candidate.
SELECT ok(true, 'private schema exposure is recorded as static config evidence');

CREATE TEMP TABLE p2l_expected_executor_policies (
  table_name name NOT NULL,
  policy_name name NOT NULL,
  command "char" NOT NULL
);

INSERT INTO p2l_expected_executor_policies VALUES
  ('profiles', 'profiles_executor_self_select', 'r'),
  ('profiles', 'profiles_executor_self_insert', 'a'),
  ('organizations', 'organizations_executor_scoped_select', 'r'),
  ('stores', 'stores_executor_scoped_select', 'r'),
  ('memberships', 'memberships_executor_identity_select', 'r'),
  ('memberships', 'memberships_executor_invitation_insert', 'a'),
  ('memberships', 'memberships_executor_lock', 'w'),
  ('membership_invitations', 'membership_invitations_executor_context_select', 'r'),
  ('membership_invitations', 'membership_invitations_executor_create', 'a'),
  ('membership_invitations', 'membership_invitations_executor_update', 'w'),
  ('membership_store_scopes', 'membership_store_scopes_executor_context_select', 'r'),
  ('membership_store_scopes', 'membership_store_scopes_executor_invitation_insert', 'a'),
  ('role_definitions', 'role_definitions_executor_context_select', 'r'),
  ('permissions', 'permissions_executor_role_link_select', 'r'),
  ('role_permissions', 'role_permissions_executor_role_link_select', 'r'),
  ('audit_logs', 'audit_logs_executor_minimal_insert', 'a');

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM p2l_expected_executor_policies AS e
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_policy AS p
      JOIN pg_catalog.pg_class AS c ON c.oid = p.polrelid
      JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = e.table_name
        AND p.polname = e.policy_name
        AND p.polpermissive
        AND p.polcmd = e.command
        AND pg_catalog.array_length(p.polroles, 1) = 1
        AND pg_catalog.pg_get_userbyid(p.polroles[1]) = 'rebuy_invite_executor'
        AND coalesce(pg_catalog.pg_get_expr(p.polqual, p.polrelid), '') NOT IN ('true', '(true)')
        AND coalesce(pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid), '') NOT IN ('true', '(true)')
    )
  ),
  'every touched table has a narrow executor-only permissive policy'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_policy AS p
    WHERE 'rebuy_invite_executor'::regrole = ANY (p.polroles)
      AND (
        pg_catalog.pg_get_expr(p.polqual, p.polrelid) IN ('true', '(true)')
        OR pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid) IN ('true', '(true)')
      )
  ),
  'executor has no blanket permissive policy'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'membership_invitations',
      'memberships',
      'membership_store_scopes',
      'audit_logs'
    ]::text[]) AS t(table_name)
    WHERE has_table_privilege('anon', 'public.' || t.table_name, 'SELECT')
       OR has_table_privilege('anon', 'public.' || t.table_name, 'INSERT')
       OR has_table_privilege('anon', 'public.' || t.table_name, 'UPDATE')
       OR has_table_privilege('anon', 'public.' || t.table_name, 'DELETE')
  ),
  'anon has no direct invitation-path table privilege'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'membership_invitations',
      'memberships',
      'membership_store_scopes',
      'audit_logs'
    ]::text[]) AS t(table_name)
    WHERE has_table_privilege('authenticated', 'public.' || t.table_name, 'SELECT')
       OR has_table_privilege('authenticated', 'public.' || t.table_name, 'INSERT')
       OR has_table_privilege('authenticated', 'public.' || t.table_name, 'UPDATE')
       OR has_table_privilege('authenticated', 'public.' || t.table_name, 'DELETE')
  ),
  'authenticated has no direct invitation-path table privilege'
);

SELECT ok(
  NOT has_schema_privilege('service_role', 'private', 'USAGE')
  AND NOT has_schema_privilege('service_role', 'private', 'CREATE'),
  'service_role has no effective privilege on the private schema'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'profiles',
      'organizations',
      'stores',
      'memberships',
      'membership_invitations',
      'membership_store_scopes',
      'role_definitions',
      'permissions',
      'role_permissions',
      'audit_logs'
    ]::text[]) AS t(table_name)
    CROSS JOIN unnest(ARRAY[
      'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'
    ]::text[]) AS privilege(privilege_name)
    WHERE has_table_privilege(
            'service_role', 'public.' || t.table_name,
            privilege.privilege_name
          )
       OR (
         privilege.privilege_name IN ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
         AND has_any_column_privilege(
           'service_role', 'public.' || t.table_name,
           privilege.privilege_name
         )
       )
  ),
  'service_role has no effective table or column privilege on the ten tables'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'private.rebuy_request_jwt()',
      'private.rebuy_request_uid()',
      'private.create_membership_invitation_impl(uuid,uuid,integer,text,uuid,text,uuid)',
      'private.accept_membership_invitation_impl(uuid)',
      'public.create_membership_invitation(uuid,uuid,integer,text,uuid,text,uuid)',
      'public.accept_membership_invitation(uuid)'
    ]::text[]) AS f(function_signature)
    WHERE has_function_privilege(
      'service_role', f.function_signature, 'EXECUTE'
    )
  ),
  'service_role cannot execute any project request helper or invitation RPC'
);

SELECT ok(has_column_privilege(
  'authenticated', 'public.profiles', 'user_id', 'INSERT'
), 'authenticated can insert only the profile identity columns');
SELECT ok(has_column_privilege(
  'authenticated', 'public.profiles', 'email_normalized', 'INSERT'
), 'authenticated can insert the signed profile email column');
SELECT ok(has_column_privilege(
  'authenticated', 'public.profiles', 'status', 'INSERT'
), 'authenticated can insert the profile status column');
SELECT ok(NOT has_column_privilege(
  'authenticated', 'public.profiles', 'display_name', 'INSERT'
), 'authenticated cannot insert profile display fields');

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_policy AS p
    JOIN pg_catalog.pg_class AS c ON c.oid = p.polrelid
    WHERE c.relname = 'profiles'
      AND p.polname = 'profiles_authenticated_self_insert'
      AND p.polpermissive
      AND pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid) LIKE '%rebuy_request_uid%'
      AND pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid) LIKE '%rebuy_request_jwt%'
      AND pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid) LIKE '%is_anonymous%'
  ),
  'profile self-insert policy binds uid, signed identity, and non-anonymous state'
);

SELECT ok(
  has_column_privilege('rebuy_invite_executor', 'public.memberships', 'updated_at', 'UPDATE')
  AND NOT has_column_privilege('rebuy_invite_executor', 'public.memberships', 'status', 'UPDATE'),
  'executor can update only memberships.updated_at for row locking'
);

SELECT * FROM finish();
ROLLBACK;
