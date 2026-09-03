BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL search_path = pg_catalog, public, extensions;

CREATE TEMP TABLE p3_application_result (
  application_id uuid NOT NULL,
  application_status text NOT NULL
);
CREATE TEMP TABLE p3_assignment_result (
  application_id uuid NOT NULL,
  application_status text NOT NULL,
  reviewer_membership_id uuid NOT NULL
);
CREATE TEMP TABLE p3_review_result (
  application_id uuid NOT NULL,
  application_status text NOT NULL,
  organization_id uuid,
  store_id uuid,
  owner_membership_id uuid
);
CREATE TEMP TABLE p3_detail_result (
  application_id uuid NOT NULL,
  applicant_user_id uuid NOT NULL,
  display_name text NOT NULL,
  country_code text NOT NULL,
  requested_store_slug text NOT NULL,
  application_status text NOT NULL,
  registration_reference text NOT NULL,
  evidence_reference text NOT NULL,
  submitted_at timestamptz,
  updated_at timestamptz NOT NULL
);
GRANT ALL PRIVILEGES ON TABLE
  pg_temp.p3_application_result,
  pg_temp.p3_assignment_result,
  pg_temp.p3_review_result,
  pg_temp.p3_detail_result
TO authenticated;

CREATE OR REPLACE FUNCTION pg_temp.p3_set_claims(
  p_uid uuid,
  p_email text,
  p_anonymous boolean DEFAULT false,
  p_age_seconds integer DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE v_claims jsonb;
BEGIN
  v_claims := pg_catalog.jsonb_build_object(
    'sub', p_uid::text,
    'email', p_email,
    'is_anonymous', p_anonymous,
    'amr', pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp()) - p_age_seconds
      )
    )
  );
  PERFORM pg_catalog.set_config('request.jwt.claims', v_claims::text, true);
END
$function$;

INSERT INTO auth.users (
  id, email, raw_app_meta_data, raw_user_meta_data, role, aud
)
VALUES
  ('00000000-0000-4000-8000-000000001301', 'p3-applicant@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000001302', 'p3-admin@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000001304', 'p3-other-reviewer@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000001305', 'p3-no-permission@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000001306', 'p3-rollback@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;

INSERT INTO public.organizations (
  id, organization_type, display_name, status, created_by
)
VALUES (
  '00000000-0000-4000-8000-000000001401', 'platform',
  'P3 Synthetic Platform', 'active',
  '00000000-0000-4000-8000-000000001302'
);

INSERT INTO public.memberships (
  id, user_id, organization_id, organization_type,
  role_definition_id, role_version, status, valid_from
)
VALUES
  ('00000000-0000-4000-8000-000000001801', '00000000-0000-4000-8000-000000001302', '00000000-0000-4000-8000-000000001401', 'platform', '00000000-0000-4000-8000-000000000203', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000001802', '00000000-0000-4000-8000-000000001303', '00000000-0000-4000-8000-000000001401', 'platform', '00000000-0000-4000-8000-000000000204', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000001803', '00000000-0000-4000-8000-000000001304', '00000000-0000-4000-8000-000000001401', 'platform', '00000000-0000-4000-8000-000000000204', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour');

SET LOCAL ROLE authenticated;
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001301', 'p3-applicant@rebuy.test'
);

SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p3_application_result
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant', 'it', 'synthetic-store', 'syn-merchant-001',
      'synthetic://merchant/evidence-001', false,
      '00000000-0000-4000-8000-000000002001'
    )
  $sql$,
  'applicant can save a normalized synthetic draft'
);

SELECT is(
  (SELECT application_status FROM pg_temp.p3_application_result LIMIT 1),
  'draft',
  'first save remains draft'
);

TRUNCATE pg_temp.p3_detail_result;
SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p3_detail_result
    SELECT application_id,
      '00000000-0000-4000-8000-000000001301'::uuid,
      display_name, country_code,
      requested_store_slug, application_status, registration_reference,
      evidence_reference, NULL::timestamptz, updated_at
    FROM public.get_my_merchant_application()
  $sql$,
  'applicant can read the own private synthetic references'
);
SELECT is(
  (SELECT country_code || ':' || registration_reference
   FROM pg_temp.p3_detail_result),
  'IT:SYN-MERCHANT-001',
  'country and registration reference are normalized server-side'
);

TRUNCATE pg_temp.p3_application_result;
SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p3_application_result
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', false,
      '00000000-0000-4000-8000-000000002001'
    )
  $sql$,
  'same save idempotency payload is accepted'
);

SELECT lives_ok(
  $sql$
    SELECT * FROM private.save_merchant_application_impl(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', false,
      '00000000-0000-4000-8000-000000002001'
    )
  $sql$,
  'direct private implementation revalidates and matches wrapper idempotency'
);

RESET ROLE;
SELECT is(
  (SELECT count(*)::integer
   FROM public.merchant_application_events
   WHERE idempotency_key = '00000000-0000-4000-8000-000000002001'),
  1,
  'idempotent save stores one event'
);
SET LOCAL ROLE authenticated;

SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_merchant_application(
      'Changed Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', false,
      '00000000-0000-4000-8000-000000002001'
    )
  $sql$,
  'P0001', 'merchant_idempotency_conflict',
  'same key with changed payload is rejected'
);

SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'https://example.invalid/evidence', false,
      '00000000-0000-4000-8000-000000002002'
    )
  $sql$,
  'P0001', 'merchant_application_invalid',
  'non-synthetic evidence reference is rejected'
);

SELECT pg_catalog.set_config(
  'request.jwt.claims',
  pg_catalog.jsonb_build_object(
    'sub', '00000000-0000-4000-8000-000000001301',
    'is_anonymous', false,
    'amr', pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      )
    )
  )::text,
  true
);
SELECT throws_ok(
  $sql$
    SELECT * FROM private.save_merchant_application_impl(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', true,
      '00000000-0000-4000-8000-000000002019'
    )
  $sql$,
  'P0001', 'merchant_identity_required',
  'missing signed email is rejected on a direct implementation call'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001301', NULL
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', true,
      '00000000-0000-4000-8000-000000002020'
    )
  $sql$,
  'P0001', 'merchant_identity_required',
  'null signed email is rejected'
);

SELECT pg_catalog.set_config(
  'request.jwt.claims',
  pg_catalog.jsonb_build_object(
    'sub', '00000000-0000-4000-8000-000000001301',
    'email', 'p3-applicant@rebuy.test',
    'is_anonymous', false
  )::text,
  true
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', true,
      '00000000-0000-4000-8000-000000002021'
    )
  $sql$,
  'P0001', 'merchant_recent_otp_required',
  'missing AMR is rejected'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001301',
  'p3-applicant@rebuy.test', true
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', true,
      '00000000-0000-4000-8000-000000002022'
    )
  $sql$,
  'P0001', 'merchant_identity_required',
  'anonymous identity is rejected'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001301', 'p3-applicant@rebuy.test', false, 601
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', true,
      '00000000-0000-4000-8000-000000002003'
    )
  $sql$,
  'P0001', 'merchant_recent_otp_required',
  'stale OTP cannot submit an application'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001301', 'outside@example.invalid'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', true,
      '00000000-0000-4000-8000-000000002003'
    )
  $sql$,
  'P0001', 'merchant_identity_required',
  'non-synthetic signed email is rejected'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001301', 'p3-applicant@rebuy.test'
);
TRUNCATE pg_temp.p3_application_result;
SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p3_application_result
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', true,
      '00000000-0000-4000-8000-000000002003'
    )
  $sql$,
  'fresh OTP submits a draft'
);
SELECT is(
  (SELECT application_status FROM pg_temp.p3_application_result),
  'submitted',
  'submitted state is returned'
);

SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
      'synthetic://merchant/evidence-001', true,
      '00000000-0000-4000-8000-000000002004'
    )
  $sql$,
  'P0001', 'merchant_application_state_conflict',
  'a different key cannot duplicate an already submitted application'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001302', 'p3-admin@rebuy.test'
);
SELECT is(
  (SELECT count(*)::integer FROM public.list_merchant_review_queue()),
  1,
  'platform admin sees the submitted safe queue row'
);
SELECT is(
  (SELECT count(*)::integer FROM private.get_my_merchant_application_impl()),
  0,
  'direct get-my implementation cannot expose another applicant'
);

SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_assigned_merchant_application(%L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)
  ),
  'P0001', 'merchant_application_not_available',
  'unassigned platform admin cannot read private review detail'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM private.get_assigned_merchant_application_impl(%L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)
  ),
  'P0001', 'merchant_application_not_available',
  'direct assigned-detail implementation enforces assignment'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001305', 'p3-no-permission@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM private.assign_merchant_application_impl(%L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    '00000000-0000-4000-8000-000000001802',
    '00000000-0000-4000-8000-000000002025'
  ),
  'P0001', 'merchant_review_forbidden',
  'direct assignment implementation revalidates platform permission'
);
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001302', 'p3-admin@rebuy.test'
);

TRUNCATE pg_temp.p3_assignment_result;
SELECT lives_ok(
  pg_catalog.format(
    'INSERT INTO pg_temp.p3_assignment_result SELECT * FROM public.assign_merchant_application(%L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    '00000000-0000-4000-8000-000000001802',
    '00000000-0000-4000-8000-000000002005'
  ),
  'platform admin assigns an eligible reviewer'
);
SELECT is(
  (SELECT application_status FROM pg_temp.p3_assignment_result),
  'under_review',
  'assignment enters under_review'
);

SELECT lives_ok(
  pg_catalog.format(
    'SELECT * FROM public.assign_merchant_application(%L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    '00000000-0000-4000-8000-000000001802',
    '00000000-0000-4000-8000-000000002005'
  ),
  'same assignment idempotency payload is accepted'
);

RESET ROLE;
SELECT is(
  (SELECT count(*)::integer
   FROM public.merchant_application_events
   WHERE idempotency_key = '00000000-0000-4000-8000-000000002005'),
  1,
  'idempotent assignment stores one event'
);
SET LOCAL ROLE authenticated;

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001304',
  'p3-other-reviewer@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_assigned_merchant_application(%L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)
  ),
  'P0001', 'merchant_application_not_available',
  'another reviewer cannot read private evidence'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM private.get_assigned_merchant_application_impl(%L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)
  ),
  'P0001', 'merchant_application_not_available',
  'direct assigned-detail implementation rejects another reviewer'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM private.review_merchant_application_impl(%L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    'needs_info', 'information_incomplete',
    '00000000-0000-4000-8000-000000002026'
  ),
  'P0001', 'merchant_application_not_available',
  'direct review implementation rejects a non-assigned reviewer'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM private.withdraw_merchant_application_impl(%L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    '00000000-0000-4000-8000-000000002027'
  ),
  'P0001', 'merchant_application_not_available',
  'direct withdrawal implementation rejects a non-applicant'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);
RESET ROLE;
UPDATE public.role_definitions
SET status = 'retired'
WHERE id = '00000000-0000-4000-8000-000000000204';
SET LOCAL ROLE authenticated;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_assigned_merchant_application(%L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)
  ),
  'P0001', 'merchant_application_not_available',
  'assigned reviewer loses access when the reviewer role is retired'
);
RESET ROLE;
UPDATE public.role_definitions
SET status = 'active'
WHERE id = '00000000-0000-4000-8000-000000000204';
UPDATE public.role_permissions
SET is_granted = false
WHERE role_definition_id = '00000000-0000-4000-8000-000000000204'
  AND permission_id = '00000000-0000-4000-8000-000000000109';
SET LOCAL ROLE authenticated;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_assigned_merchant_application(%L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)
  ),
  'P0001', 'merchant_application_not_available',
  'assigned detail revalidates the review permission'
);
RESET ROLE;
UPDATE public.role_permissions
SET is_granted = true
WHERE role_definition_id = '00000000-0000-4000-8000-000000000204'
  AND permission_id = '00000000-0000-4000-8000-000000000109';
UPDATE public.memberships
SET status = 'suspended'
WHERE id = '00000000-0000-4000-8000-000000001802';
SET LOCAL ROLE authenticated;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_assigned_merchant_application(%L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)
  ),
  'P0001', 'merchant_application_not_available',
  'inactive assigned membership cannot read private evidence'
);
RESET ROLE;
UPDATE public.memberships
SET status = 'active'
WHERE id = '00000000-0000-4000-8000-000000001802';
UPDATE public.organizations
SET status = 'suspended'
WHERE id = '00000000-0000-4000-8000-000000001401';
SET LOCAL ROLE authenticated;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_assigned_merchant_application(%L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)
  ),
  'P0001', 'merchant_application_not_available',
  'suspended platform organization removes reviewer access'
);
RESET ROLE;
UPDATE public.organizations
SET status = 'active'
WHERE id = '00000000-0000-4000-8000-000000001401';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);
TRUNCATE pg_temp.p3_detail_result;
SELECT lives_ok(
  pg_catalog.format(
    'INSERT INTO pg_temp.p3_detail_result SELECT * FROM public.get_assigned_merchant_application(%L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)
  ),
  'assigned reviewer can read private evidence'
);
SELECT is(
  (SELECT evidence_reference FROM pg_temp.p3_detail_result),
  'synthetic://merchant/evidence-001',
  'assigned detail returns only the synthetic reference'
);

RESET ROLE;
UPDATE public.role_permissions
SET is_granted = false
WHERE role_definition_id = '00000000-0000-4000-8000-000000000204'
  AND permission_id = '00000000-0000-4000-8000-000000000108';
SET LOCAL ROLE authenticated;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.review_merchant_application(%L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    'needs_info', 'information_incomplete',
    '00000000-0000-4000-8000-000000002023'
  ),
  'P0001', 'merchant_application_not_available',
  'review action revalidates read_assigned as well as review permission'
);
RESET ROLE;
UPDATE public.role_permissions
SET is_granted = true
WHERE role_definition_id = '00000000-0000-4000-8000-000000000204'
  AND permission_id = '00000000-0000-4000-8000-000000000108';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);

TRUNCATE pg_temp.p3_review_result;
SELECT lives_ok(
  pg_catalog.format(
    'INSERT INTO pg_temp.p3_review_result SELECT * FROM public.review_merchant_application(%L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    'needs_info', 'information_incomplete',
    '00000000-0000-4000-8000-000000002006'
  ),
  'assigned reviewer can request information'
);
SELECT is(
  (SELECT application_status FROM pg_temp.p3_review_result),
  'needs_info',
  'request information enters needs_info'
);

SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.review_merchant_application(%L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    'approve', 'policy_violation',
    '00000000-0000-4000-8000-000000002007'
  ),
  'P0001', 'merchant_review_reason_invalid',
  'approval rejects a mismatched reason code'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001301', 'p3-applicant@rebuy.test'
);
TRUNCATE pg_temp.p3_application_result;
SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p3_application_result
    SELECT * FROM public.save_merchant_application(
      'Synthetic Merchant Updated', 'IT', 'synthetic-store',
      'SYN-MERCHANT-001', 'synthetic://merchant/evidence-002', true,
      '00000000-0000-4000-8000-000000002008'
    )
  $sql$,
  'applicant can resubmit requested information'
);
RESET ROLE;
SELECT ok(
  (SELECT status = 'submitted'
      AND assigned_reviewer_membership_id IS NULL
      AND assigned_at IS NULL
   FROM public.merchant_applications
   WHERE id = (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)),
  'resubmission clears the prior assignment'
);
SET LOCAL ROLE authenticated;

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);
SELECT is(
  (SELECT application_status
   FROM public.review_merchant_application(
     (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
     'needs_info', 'information_incomplete',
     '00000000-0000-4000-8000-000000002006'
   )),
  'needs_info',
  'old needs-info key returns the original result after assignment is cleared'
);
RESET ROLE;
SELECT is(
  (SELECT count(*)::integer
   FROM public.merchant_application_events
   WHERE idempotency_key = '00000000-0000-4000-8000-000000002006'),
  1,
  'old needs-info retry does not add an event'
);
SELECT ok(
  (SELECT status = 'submitted'
      AND assigned_reviewer_membership_id IS NULL
      AND assigned_at IS NULL
   FROM public.merchant_applications
   WHERE id = (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)),
  'old needs-info retry does not roll back the current application state'
);
SET LOCAL ROLE authenticated;

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001302', 'p3-admin@rebuy.test'
);
SELECT lives_ok(
  pg_catalog.format(
    'SELECT * FROM public.assign_merchant_application(%L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    '00000000-0000-4000-8000-000000001802',
    '00000000-0000-4000-8000-000000002009'
  ),
  'resubmitted application can be assigned again'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);
TRUNCATE pg_temp.p3_review_result;
SELECT lives_ok(
  pg_catalog.format(
    'INSERT INTO pg_temp.p3_review_result SELECT * FROM public.review_merchant_application(%L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    'approve', 'approved_checks_complete',
    '00000000-0000-4000-8000-000000002010'
  ),
  'assigned reviewer approves the application'
);
SELECT ok(
  (SELECT application_status = 'approved'
      AND organization_id IS NOT NULL
      AND store_id IS NOT NULL
      AND owner_membership_id IS NOT NULL
   FROM pg_temp.p3_review_result),
  'approval returns all created merchant references'
);

SELECT lives_ok(
  pg_catalog.format(
    'SELECT * FROM public.review_merchant_application(%L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    'approve', 'approved_checks_complete',
    '00000000-0000-4000-8000-000000002010'
  ),
  'same approval idempotency payload is accepted'
);

RESET ROLE;
SELECT ok(
  (SELECT o.organization_type = 'merchant' AND o.status = 'active'
      AND o.created_by = '00000000-0000-4000-8000-000000001301'
   FROM public.organizations AS o
   WHERE o.id = (SELECT organization_id FROM pg_temp.p3_review_result)),
  'approval creates the active merchant organization for the applicant'
);
SELECT ok(
  (SELECT s.status = 'active' AND NOT s.public_visibility
   FROM public.stores AS s
   WHERE s.id = (SELECT store_id FROM pg_temp.p3_review_result)),
  'approval creates an active but private store'
);
SELECT ok(
  (SELECT m.status = 'active'
      AND m.role_definition_id = '00000000-0000-4000-8000-000000000201'
      AND m.user_id = '00000000-0000-4000-8000-000000001301'
   FROM public.memberships AS m
   WHERE m.id = (SELECT owner_membership_id FROM pg_temp.p3_review_result)),
  'approval creates the active owner membership'
);
SELECT is(
  (SELECT count(*)::integer
   FROM public.membership_store_scopes AS s
   WHERE s.membership_id = (SELECT owner_membership_id FROM pg_temp.p3_review_result)
     AND s.scope_type = 'organization' AND s.store_id IS NULL
     AND s.status = 'active'),
  1,
  'approval creates one explicit organization scope'
);
SELECT is(
  (SELECT count(*)::integer
   FROM public.merchant_application_events
   WHERE idempotency_key = '00000000-0000-4000-8000-000000002010'),
  1,
  'idempotent approval stores one audit event'
);
SET LOCAL ROLE authenticated;

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);
SELECT lives_ok(
  pg_catalog.format(
    'SELECT * FROM public.review_merchant_application(%L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    'suspend', 'risk_suspension',
    '00000000-0000-4000-8000-000000002011'
  ),
  'assigned reviewer can suspend an approved merchant'
);
RESET ROLE;
SELECT ok(
  (SELECT a.status = 'suspended' AND o.status = 'suspended'
      AND s.status = 'suspended' AND m.status = 'suspended'
   FROM public.merchant_applications AS a
   JOIN public.organizations AS o ON o.id = a.organization_id
   JOIN public.stores AS s ON s.id = a.store_id
   JOIN public.memberships AS m ON m.id = a.owner_membership_id
   WHERE a.id = (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)),
  'suspension keeps application, organization, store and owner aligned'
);
SELECT is(
  (SELECT count(*)::integer
   FROM public.membership_store_scopes
   WHERE membership_id = (SELECT owner_membership_id FROM pg_temp.p3_review_result)
     AND status = 'suspended'),
  1,
  'suspension also suspends the explicit owner scope'
);
SET LOCAL ROLE authenticated;

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);
SELECT is(
  (SELECT application_status
   FROM public.review_merchant_application(
     (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
     'approve', 'approved_checks_complete',
     '00000000-0000-4000-8000-000000002010'
   )),
  'approved',
  'approve retry returns the original approved result after suspension'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001302', 'p3-admin@rebuy.test'
);
SELECT is(
  (SELECT application_status
   FROM public.assign_merchant_application(
     (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
     '00000000-0000-4000-8000-000000001802',
     '00000000-0000-4000-8000-000000002009'
   )),
  'under_review',
  'assignment retry returns its original state after later decisions'
);

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001301', 'p3-applicant@rebuy.test'
);
SELECT is(
  (SELECT application_status
   FROM public.save_merchant_application(
     'Synthetic Merchant', 'IT', 'synthetic-store', 'SYN-MERCHANT-001',
     'synthetic://merchant/evidence-001', false,
     '00000000-0000-4000-8000-000000002001'
   )),
  'draft',
  'old save retry returns the original draft result after terminal progress'
);
RESET ROLE;
SELECT is(
  (SELECT count(*)::integer
   FROM public.merchant_applications
   WHERE applicant_user_id = '00000000-0000-4000-8000-000000001301'),
  1,
  'old save retry does not create another application'
);
SET LOCAL ROLE authenticated;

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001305', 'p3-no-permission@rebuy.test'
);
SELECT throws_ok(
  'SELECT * FROM public.list_merchant_review_queue()',
  'P0001', 'merchant_review_forbidden',
  'ordinary user cannot list the platform review queue'
);
SELECT throws_ok(
  'SELECT * FROM private.list_merchant_review_queue_impl()',
  'P0001', 'merchant_review_forbidden',
  'direct queue implementation revalidates platform permission'
);

TRUNCATE pg_temp.p3_application_result;
SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p3_application_result
    SELECT * FROM public.save_merchant_application(
      'Withdraw Merchant', 'FR', 'withdraw-store', 'SYN-WITHDRAW-001',
      'synthetic://merchant/withdraw-001', false,
      '00000000-0000-4000-8000-000000002012'
    )
  $sql$,
  'ordinary authenticated user can create a separate draft'
);
SELECT lives_ok(
  pg_catalog.format(
    'SELECT * FROM public.withdraw_merchant_application(%L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    '00000000-0000-4000-8000-000000002013'
  ),
  'applicant can withdraw the own draft'
);
RESET ROLE;
SELECT is(
  (SELECT status FROM public.merchant_applications
   WHERE id = (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)),
  'withdrawn',
  'withdrawal reaches the terminal state'
);
SET LOCAL ROLE authenticated;

SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001305', 'p3-no-permission@rebuy.test'
);
SELECT is(
  (SELECT application_status
   FROM public.save_merchant_application(
     'Withdraw Merchant', 'FR', 'withdraw-store', 'SYN-WITHDRAW-001',
     'synthetic://merchant/withdraw-001', false,
     '00000000-0000-4000-8000-000000002012'
   )),
  'draft',
  'old save key returns its original draft result after withdrawal'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_merchant_application(
      'Changed Withdraw Merchant', 'FR', 'withdraw-store', 'SYN-WITHDRAW-001',
      'synthetic://merchant/withdraw-001', false,
      '00000000-0000-4000-8000-000000002012'
    )
  $sql$,
  'P0001', 'merchant_idempotency_conflict',
  'same actor and key cannot be reused for a changed payload'
);

TRUNCATE pg_temp.p3_application_result;
SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p3_application_result
    SELECT * FROM public.save_merchant_application(
      'Second Withdraw Merchant', 'FR', 'withdraw-store-2',
      'SYN-WITHDRAW-002', 'synthetic://merchant/withdraw-002', false,
      '00000000-0000-4000-8000-000000002024'
    )
  $sql$,
  'applicant can create a new draft after the prior withdrawal'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.withdraw_merchant_application(%L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    '00000000-0000-4000-8000-000000002013'
  ),
  'P0001', 'merchant_idempotency_conflict',
  'same actor and key cannot be reused for a different application'
);

-- A reviewer may also be a merchant applicant, but cannot be assigned to the
-- own case.
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);
TRUNCATE pg_temp.p3_application_result;
SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p3_application_result
    SELECT * FROM public.save_merchant_application(
      'Reviewer Merchant', 'DE', 'reviewer-store', 'SYN-REVIEWER-001',
      'synthetic://merchant/reviewer-001', true,
      '00000000-0000-4000-8000-000000002014'
    )
  $sql$,
  'reviewer can submit a personal merchant application'
);
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001302', 'p3-admin@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.assign_merchant_application(%L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    '00000000-0000-4000-8000-000000001802',
    '00000000-0000-4000-8000-000000002015'
  ),
  'P0001', 'merchant_reviewer_not_available',
  'platform admin cannot assign an applicant to review the own case'
);

-- Failure before merchant creation must leave no partial organization/store or
-- owner membership for the rollback applicant.
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001306', 'p3-rollback@rebuy.test'
);
TRUNCATE pg_temp.p3_application_result;
SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p3_application_result
    SELECT * FROM public.save_merchant_application(
      'Rollback Merchant', 'ES', 'rollback-store', 'SYN-ROLLBACK-001',
      'synthetic://merchant/rollback-001', true,
      '00000000-0000-4000-8000-000000002016'
    )
  $sql$,
  'rollback fixture application is submitted'
);
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001302', 'p3-admin@rebuy.test'
);
SELECT lives_ok(
  pg_catalog.format(
    'SELECT * FROM public.assign_merchant_application(%L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    '00000000-0000-4000-8000-000000001802',
    '00000000-0000-4000-8000-000000002017'
  ),
  'rollback fixture is assigned'
);
RESET ROLE;
UPDATE public.role_definitions
SET status = 'retired'
WHERE id = '00000000-0000-4000-8000-000000000201';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.review_merchant_application(%L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    'approve', 'approved_checks_complete',
    '00000000-0000-4000-8000-000000002018'
  ),
  'P0001', 'merchant_owner_role_unavailable',
  'approval fails closed when the canonical owner role is unavailable'
);
RESET ROLE;
SELECT is(
  (SELECT count(*)::integer FROM public.organizations
   WHERE organization_type = 'merchant'
     AND created_by = '00000000-0000-4000-8000-000000001306'),
  0,
  'failed approval leaves no merchant organization'
);
SELECT is(
  (SELECT count(*)::integer FROM public.stores AS s
   JOIN public.organizations AS o ON o.id = s.organization_id
   WHERE o.created_by = '00000000-0000-4000-8000-000000001306'),
  0,
  'failed approval leaves no merchant store'
);
SELECT is(
  (SELECT count(*)::integer FROM public.memberships AS m
   JOIN public.organizations AS o ON o.id = m.organization_id
   WHERE o.created_by = '00000000-0000-4000-8000-000000001306'),
  0,
  'failed approval leaves no owner membership'
);
UPDATE public.role_definitions
SET status = 'active'
WHERE id = '00000000-0000-4000-8000-000000000201';

UPDATE public.role_definitions
SET scope_type = 'store'
WHERE id = '00000000-0000-4000-8000-000000000201';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.review_merchant_application(%L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    'approve', 'approved_checks_complete',
    '00000000-0000-4000-8000-000000002029'
  ),
  'P0001', 'merchant_owner_role_unavailable',
  'approval fails closed when the canonical owner scope drifts'
);
RESET ROLE;
SELECT is(
  (SELECT count(*)::integer FROM public.organizations
   WHERE organization_type = 'merchant'
     AND created_by = '00000000-0000-4000-8000-000000001306'),
  0,
  'owner scope drift leaves no partial merchant organization'
);
SELECT is(
  (SELECT count(*)::integer FROM public.merchant_application_events
   WHERE idempotency_key = '00000000-0000-4000-8000-000000002029'),
  0,
  'owner scope drift leaves no decision event'
);
UPDATE public.role_definitions
SET scope_type = 'organization'
WHERE id = '00000000-0000-4000-8000-000000000201';

CREATE OR REPLACE FUNCTION pg_temp.p3_fail_store_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  RAISE EXCEPTION 'p3_injected_store_failure';
END
$function$;
CREATE TRIGGER p3_injected_store_failure
BEFORE INSERT ON public.stores
FOR EACH ROW EXECUTE FUNCTION pg_temp.p3_fail_store_insert();

SET LOCAL ROLE authenticated;
SELECT pg_temp.p3_set_claims(
  '00000000-0000-4000-8000-000000001303', 'p3-reviewer@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.review_merchant_application(%L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1),
    'approve', 'approved_checks_complete',
    '00000000-0000-4000-8000-000000002028'
  ),
  'P0001', 'p3_injected_store_failure',
  'a failure after organization insert aborts the whole approval statement'
);
RESET ROLE;
DROP TRIGGER p3_injected_store_failure ON public.stores;
SELECT is(
  (SELECT count(*)::integer FROM public.organizations
   WHERE organization_type = 'merchant'
     AND created_by = '00000000-0000-4000-8000-000000001306'),
  0,
  'mid-approval failure rolls back the inserted merchant organization'
);
SELECT is(
  (SELECT count(*)::integer FROM public.merchant_application_events
   WHERE idempotency_key = '00000000-0000-4000-8000-000000002028'),
  0,
  'mid-approval failure leaves no audit event'
);
SELECT is(
  (SELECT status FROM public.merchant_applications
   WHERE id = (SELECT application_id FROM pg_temp.p3_application_result LIMIT 1)),
  'under_review',
  'mid-approval failure leaves the application decision unchanged'
);

SELECT * FROM finish();
ROLLBACK;
