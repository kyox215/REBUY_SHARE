BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL search_path = pg_catalog, public, extensions;

CREATE TEMP TABLE p2l_create_result (
  invitation_id uuid NOT NULL,
  expires_at timestamptz NOT NULL
);

CREATE TEMP TABLE p2l_accept_result (
  membership_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  store_id uuid,
  scope_type text NOT NULL
);

GRANT ALL PRIVILEGES ON TABLE
  pg_temp.p2l_create_result,
  pg_temp.p2l_accept_result
TO authenticated;

CREATE OR REPLACE FUNCTION pg_temp.p2l_set_claims(
  p_uid uuid,
  p_email text,
  p_anonymous boolean,
  p_amr jsonb,
  p_extra jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
  v_claims jsonb;
BEGIN
  v_claims := pg_catalog.jsonb_build_object(
    'sub', p_uid::text,
    'email', p_email,
    'is_anonymous', p_anonymous,
    'amr', p_amr
  ) || p_extra;
  PERFORM pg_catalog.set_config('request.jwt.claim.sub', p_uid::text, true);
  PERFORM pg_catalog.set_config('request.jwt.claim.email', p_email, true);
  PERFORM pg_catalog.set_config(
    'request.jwt.claim.is_anonymous', p_anonymous::text, true
  );
  PERFORM pg_catalog.set_config(
    'request.jwt.claim.amr', p_amr::text, true
  );
  PERFORM pg_catalog.set_config('request.jwt.claims', v_claims::text, true);
END
$function$;

INSERT INTO auth.users (
  id, email, raw_app_meta_data, raw_user_meta_data, role, aud
)
VALUES
  ('00000000-0000-4000-8000-000000000301', 'p2l-creator@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000302', 'p2l-target-a@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000303', 'p2l-target-b@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000304', 'p2l-target-c@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000305', 'p2l-target-d@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000306', 'p2l-target-e@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000307', 'p2l-noscope@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000308', 'p2l-inactive@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000309', 'p2l-other@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email,
    raw_app_meta_data = EXCLUDED.raw_app_meta_data,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data;

INSERT INTO public.organizations (
  id, organization_type, display_name, status, created_by
)
VALUES
  ('00000000-0000-4000-8000-000000000401', 'merchant', 'P2L Org A', 'active', '00000000-0000-4000-8000-000000000301'),
  ('00000000-0000-4000-8000-000000000402', 'merchant', 'P2L Org B', 'active', '00000000-0000-4000-8000-000000000309')
ON CONFLICT (id) DO UPDATE
SET organization_type = EXCLUDED.organization_type,
    display_name = EXCLUDED.display_name,
    status = EXCLUDED.status,
    created_by = EXCLUDED.created_by;

INSERT INTO public.stores (
  id, organization_id, organization_type, display_name, slug, status
)
VALUES
  ('00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000401', 'merchant', 'P2L Store A1', 'p2l-store-a1', 'active'),
  ('00000000-0000-4000-8000-000000000502', '00000000-0000-4000-8000-000000000401', 'merchant', 'P2L Store A2', 'p2l-store-a2', 'active'),
  ('00000000-0000-4000-8000-000000000503', '00000000-0000-4000-8000-000000000402', 'merchant', 'P2L Store B1', 'p2l-store-b1', 'active')
ON CONFLICT (id) DO UPDATE
SET organization_id = EXCLUDED.organization_id,
    organization_type = EXCLUDED.organization_type,
    display_name = EXCLUDED.display_name,
    slug = EXCLUDED.slug,
    status = EXCLUDED.status;

INSERT INTO public.permissions (
  id, permission_key, resource, action, scope_type, risk_level, requires_aal2, is_active
)
VALUES
  ('00000000-0000-4000-8000-000000000106', 'member.invite', 'member', 'invite', 'organization', 'high', false, true),
  ('00000000-0000-4000-8000-000000000105', 'member.read', 'member', 'read', 'organization', 'high', false, true)
ON CONFLICT (id) DO UPDATE
SET permission_key = EXCLUDED.permission_key,
    resource = EXCLUDED.resource,
    action = EXCLUDED.action,
    scope_type = EXCLUDED.scope_type,
    risk_level = EXCLUDED.risk_level,
    requires_aal2 = EXCLUDED.requires_aal2,
    is_active = EXCLUDED.is_active;

INSERT INTO public.role_definitions (
  id, role_key, scope_type, version, applicable_organization_type,
  is_system, status, assignable
)
VALUES
  ('00000000-0000-4000-8000-000000000601', 'p2l-owner', 'organization', 1, 'any', true, 'active', true),
  ('00000000-0000-4000-8000-000000000602', 'p2l-store-member', 'store', 1, 'merchant', true, 'active', true),
  ('00000000-0000-4000-8000-000000000603', 'p2l-org-member', 'organization', 1, 'merchant', true, 'active', true),
  ('00000000-0000-4000-8000-000000000604', 'p2l-retired', 'store', 1, 'merchant', true, 'retired', true),
  ('00000000-0000-4000-8000-000000000605', 'p2l-unassignable', 'store', 1, 'merchant', true, 'active', false)
ON CONFLICT (id) DO UPDATE
SET role_key = EXCLUDED.role_key,
    scope_type = EXCLUDED.scope_type,
    version = EXCLUDED.version,
    applicable_organization_type = EXCLUDED.applicable_organization_type,
    is_system = EXCLUDED.is_system,
    status = EXCLUDED.status,
    assignable = EXCLUDED.assignable;

INSERT INTO public.role_permissions (
  role_definition_id, role_version, permission_id, is_granted
)
VALUES
  ('00000000-0000-4000-8000-000000000601', 1, '00000000-0000-4000-8000-000000000106', true),
  ('00000000-0000-4000-8000-000000000601', 1, '00000000-0000-4000-8000-000000000105', true)
ON CONFLICT (role_definition_id, role_version, permission_id) DO UPDATE
SET is_granted = EXCLUDED.is_granted;

INSERT INTO public.memberships (
  id, user_id, organization_id, organization_type,
  role_definition_id, role_version, status, valid_from
)
VALUES
  ('00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401', 'merchant', '00000000-0000-4000-8000-000000000601', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000000802', '00000000-0000-4000-8000-000000000307', '00000000-0000-4000-8000-000000000401', 'merchant', '00000000-0000-4000-8000-000000000601', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000000803', '00000000-0000-4000-8000-000000000308', '00000000-0000-4000-8000-000000000401', 'merchant', '00000000-0000-4000-8000-000000000601', 1, 'suspended', pg_catalog.statement_timestamp() - INTERVAL '1 hour')
ON CONFLICT (id) DO UPDATE
SET status = EXCLUDED.status,
    valid_from = EXCLUDED.valid_from;

INSERT INTO public.membership_store_scopes (
  id, membership_id, organization_id, organization_type,
  scope_type, status
)
VALUES
  ('00000000-0000-4000-0000-000000000901', '00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000401', 'merchant', 'organization', 'active')
ON CONFLICT (id) DO UPDATE
SET membership_id = EXCLUDED.membership_id,
    organization_id = EXCLUDED.organization_id,
    organization_type = EXCLUDED.organization_type,
    scope_type = EXCLUDED.scope_type,
    status = EXCLUDED.status;

SET LOCAL ROLE authenticated;

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;

TRUNCATE pg_temp.p2l_create_result;
SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p2l_create_result
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-a@rebuy.test',
      '00000000-0000-4000-8000-000000001001'
    )
  $sql$,
  'organization invitation create succeeds'
);

SELECT ok(
  (SELECT expires_at > pg_catalog.statement_timestamp() + INTERVAL '23 hours'
     AND expires_at <= pg_catalog.statement_timestamp() + INTERVAL '24 hours'
   FROM pg_temp.p2l_create_result),
  'invitation expiry is bounded to twenty-four hours'
);

SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p2l_create_result
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-a@rebuy.test',
      '00000000-0000-4000-8000-000000001001'
    )
  $sql$,
  'same idempotency payload is accepted'
);

RESET ROLE;
SELECT is(
  (SELECT count(*)::integer
   FROM public.membership_invitations
   WHERE creator_membership_id = '00000000-0000-4000-8000-000000000801'
     AND idempotency_key = '00000000-0000-4000-8000-000000001001'),
  1,
  'idempotent create stores one invitation'
);
SELECT is(
  (SELECT count(*)::integer
   FROM public.audit_logs
   WHERE event_code = 'membership_invitation.created'
     AND invitation_id = (SELECT invitation_id FROM pg_temp.p2l_create_result LIMIT 1)),
  1,
  'idempotent create stores one audit event'
);
SET LOCAL ROLE authenticated;

SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-b@rebuy.test',
      '00000000-0000-4000-8000-000000001001'
    )
  $sql$,
  'P0001',
  'invitation_idempotency_conflict',
  'different payload under one idempotency key is rejected'
);

TRUNCATE pg_temp.p2l_accept_result;
DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000302',
    'p2l-target-a@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    ),
    pg_catalog.jsonb_build_object('user_metadata', pg_catalog.jsonb_build_object('role', 'owner'))
  );
END
$claims$;

SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p2l_accept_result
    SELECT *
    FROM public.accept_membership_invitation(
      (SELECT invitation_id FROM pg_temp.p2l_create_result LIMIT 1)
    )
  $sql$,
  'organization invitation accept succeeds with ignored user metadata'
);

RESET ROLE;
SELECT is(
  (SELECT count(*)::integer
   FROM public.membership_store_scopes
   WHERE membership_id = (SELECT membership_id FROM pg_temp.p2l_accept_result LIMIT 1)
     AND scope_type = 'organization'
     AND store_id IS NULL
     AND status = 'active'),
  1,
  'organization accept writes one explicit organization scope'
);
SET LOCAL ROLE authenticated;

SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p2l_accept_result
    SELECT *
    FROM public.accept_membership_invitation(
      (SELECT invitation_id FROM pg_temp.p2l_create_result LIMIT 1)
    )
  $sql$,
  'same accepted user can retry'
);
RESET ROLE;
SELECT is(
  (SELECT count(*)::integer
   FROM public.memberships
   WHERE user_id = '00000000-0000-4000-8000-000000000302'
     AND organization_id = '00000000-0000-4000-8000-000000000401'),
  1,
  'same-user retry does not duplicate membership'
);
SELECT is(
  (SELECT count(*)::integer
   FROM public.audit_logs
   WHERE event_code = 'membership_invitation.accepted'
     AND invitation_id = (SELECT invitation_id FROM pg_temp.p2l_create_result LIMIT 1)),
  1,
  'same-user retry does not duplicate acceptance audit'
);
SET LOCAL ROLE authenticated;

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000309',
    'p2l-target-a@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.accept_membership_invitation(
      (SELECT invitation_id FROM pg_temp.p2l_create_result LIMIT 1)
    )
  $sql$,
  'P0001',
  'invitation_not_available',
  'different uid cannot retry an accepted invitation'
);

RESET ROLE;
UPDATE public.role_permissions
SET is_granted = false
WHERE role_definition_id = '00000000-0000-4000-8000-000000000601'
  AND role_version = 1
  AND permission_id = '00000000-0000-4000-8000-000000000106';
SET LOCAL ROLE authenticated;

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001002'
    )
  $sql$,
  'P0001',
  'member_invite_required',
  'missing creator permission is rejected'
);

RESET ROLE;
UPDATE public.role_permissions
SET is_granted = true
WHERE role_definition_id = '00000000-0000-4000-8000-000000000601'
  AND role_version = 1
  AND permission_id = '00000000-0000-4000-8000-000000000106';
SET LOCAL ROLE authenticated;

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;

SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000604',
      1,
      'store',
      '00000000-0000-4000-8000-000000000501',
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001003'
    )
  $sql$,
  'P0001',
  'role_not_assignable',
  'retired candidate role is rejected'
);

SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000605',
      1,
      'store',
      '00000000-0000-4000-8000-000000000501',
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001004'
    )
  $sql$,
  'P0001',
  'role_not_assignable',
  'unassignable candidate role is rejected'
);

SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000402',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001005'
    )
  $sql$,
  'P0001',
  'organization_not_available',
  'cross-organization create is rejected'
);

SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000602',
      1,
      'store',
      '00000000-0000-4000-8000-000000000503',
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001006'
    )
  $sql$,
  'P0001',
  'store_not_available',
  'cross-organization store is rejected'
);

SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      '00000000-0000-4000-8000-000000000501',
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001007'
    )
  $sql$,
  'P0001',
  'invalid_invitation_scope',
  'organization and store scope mismatch is rejected'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-0000-0000-000000000307',
    'p2l-noscope@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-c@rebuy.test',
      '00000000-0000-0000-0000-000000001008'
    )
  $sql$,
  'P0001',
  'organization_not_available',
  'empty scope defaults to deny'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-0000-0000-000000000308',
    'p2l-inactive@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-c@rebuy.test',
      '00000000-0000-0000-0000-000000001009'
    )
  $sql$,
  'P0001',
  'organization_not_available',
  'inactive membership defaults to deny'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'not-rebuy.example',
      '00000000-0000-0000-0000-000000001010'
    )
  $sql$,
  'P0001',
  'invalid_invitation_target',
  'non-synthetic target is rejected'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'P2L-CREATOR@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001011'
    )
  $sql$,
  'P0001',
  'synthetic_email_required',
  'non-normalized signed email is rejected'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    true,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001012'
    )
  $sql$,
  'P0001',
  'recent_otp_required',
  'anonymous identity is rejected'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    false,
    pg_catalog.jsonb_build_object('method', 'otp'),
    pg_catalog.jsonb_build_object('iat', 9999999999)
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001013'
    )
  $sql$,
  'P0001',
  'recent_otp_required',
  'missing AMR timestamp is rejected even with iat'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    false,
    pg_catalog.jsonb_build_object('method', 'otp', 'timestamp', 'not-a-number')
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001014'
    )
  $sql$,
  'P0001',
  'recent_otp_required',
  'malformed AMR timestamp is rejected without raw JSON error'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'password',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      ),
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001015'
    )
  $sql$,
  'P0001',
  'recent_otp_required',
  'only the first AMR element is accepted'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp()) - 601
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001016'
    )
  $sql$,
  'P0001',
  'recent_otp_required',
  'stale OTP evidence is rejected'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp()) + 61
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000603',
      1,
      'organization',
      NULL,
      'p2l-target-b@rebuy.test',
      '00000000-0000-0000-0000-000000001017'
    )
  $sql$,
  'P0001',
  'recent_otp_required',
  'OTP future skew beyond sixty seconds is rejected'
);

RESET ROLE;
INSERT INTO public.membership_invitations (
  id, organization_id, organization_type, store_id,
  role_definition_id, role_version,
  role_definition_organization_id, role_definition_organization_type,
  scope_type, target_email_normalized, idempotency_key,
  creator_membership_id, creator_user_id,
  creator_role_definition_id, creator_role_version,
  creator_role_organization_id, creator_role_organization_type,
  creator_membership_status, status, expires_at, revoked_at, created_at, updated_at
)
VALUES
  ('00000000-0000-4000-8000-000000001101', '00000000-0000-4000-8000-000000000401', 'merchant', NULL,
   '00000000-0000-4000-8000-000000000603', 1, NULL, NULL, 'organization',
   'p2l-target-c@rebuy.test', '00000000-0000-0000-0000-000000001101',
   '00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000301',
   '00000000-0000-4000-8000-000000000601', 1, NULL, NULL, 'active', 'sent',
   pg_catalog.statement_timestamp() - INTERVAL '1 minute', NULL,
   pg_catalog.statement_timestamp() - INTERVAL '2 hours',
   pg_catalog.statement_timestamp() - INTERVAL '2 hours'),
  ('00000000-0000-4000-8000-000000001102', '00000000-0000-4000-8000-000000000401', 'merchant', NULL,
   '00000000-0000-4000-8000-000000000603', 1, NULL, NULL, 'organization',
   'p2l-target-d@rebuy.test', '00000000-0000-0000-0000-000000001102',
   '00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000301',
   '00000000-0000-4000-8000-000000000601', 1, NULL, NULL, 'active', 'revoked',
   pg_catalog.statement_timestamp() + INTERVAL '24 hours', pg_catalog.statement_timestamp(),
   pg_catalog.statement_timestamp() - INTERVAL '1 hour',
   pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000001103', '00000000-0000-4000-8000-000000000401', 'merchant', NULL,
   '00000000-0000-4000-8000-000000000603', 1, NULL, NULL, 'organization',
   'p2l-target-e@rebuy.test', '00000000-0000-0000-0000-000000001103',
   '00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000301',
   '00000000-0000-4000-8000-000000000601', 1, NULL, NULL, 'active', 'sent',
   pg_catalog.statement_timestamp() + INTERVAL '24 hours', NULL,
   pg_catalog.statement_timestamp() - INTERVAL '1 hour',
   pg_catalog.statement_timestamp() - INTERVAL '1 hour')
ON CONFLICT (id) DO UPDATE
SET status = EXCLUDED.status,
    expires_at = EXCLUDED.expires_at,
    revoked_at = CASE WHEN EXCLUDED.status = 'revoked' THEN pg_catalog.statement_timestamp() ELSE NULL END,
    updated_at = EXCLUDED.updated_at;
SET LOCAL ROLE authenticated;

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000304',
    'p2l-target-c@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$SELECT * FROM public.accept_membership_invitation('00000000-0000-0000-0000-000000001101')$sql$,
  'P0001',
  'invitation_not_available',
  'expired invitation is rejected'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000305',
    'p2l-target-d@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$SELECT * FROM public.accept_membership_invitation('00000000-0000-0000-0000-000000001102')$sql$,
  'P0001',
  'invitation_not_available',
  'revoked invitation is rejected'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000302',
    'p2l-target-a@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;
SELECT throws_ok(
  $sql$
    SELECT *
    FROM private.accept_membership_invitation_impl(
      '00000000-0000-0000-0000-000000001101'
    )
  $sql$,
  'P0001',
  'invitation_not_available',
  'direct private implementation still performs status checks'
);

DO $claims$
BEGIN
  PERFORM pg_temp.p2l_set_claims(
    '00000000-0000-4000-8000-000000000301',
    'p2l-creator@rebuy.test',
    false,
    pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  );
END
$claims$;

SELECT lives_ok(
  $sql$
    SELECT *
    FROM public.create_membership_invitation(
      '00000000-0000-4000-8000-000000000401',
      '00000000-0000-4000-8000-000000000602',
      1,
      'store',
      '00000000-0000-4000-8000-000000000501',
      'p2l-target-e@rebuy.test',
      '00000000-0000-0000-0000-000000001104'
    )
  $sql$,
  'store invitation create succeeds'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'membership_invitations'
      AND data_type IN ('ARRAY', 'jsonb')
  ),
  'invitation scope has no multi-store array or JSONB input'
);

SELECT * FROM finish();
ROLLBACK;
