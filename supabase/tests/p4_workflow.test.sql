BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL search_path = pg_catalog, public, extensions;
GRANT rebuy_business_executor TO postgres
  WITH INHERIT FALSE GRANTED BY CURRENT_USER;

CREATE OR REPLACE FUNCTION pg_temp.p4_set_claims(
  p_uid uuid,
  p_email text,
  p_anonymous boolean DEFAULT false,
  p_age_seconds integer DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', p_uid::text,
      'email', p_email,
      'is_anonymous', p_anonymous,
      'amr', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'method', 'otp',
          'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp()) - p_age_seconds
        )
      )
    )::text,
    true
  );
END
$function$;

CREATE TEMP TABLE p4_application_result (
  application_id uuid NOT NULL,
  application_status text NOT NULL
);
CREATE TEMP TABLE p4_assignment_result (
  application_id uuid NOT NULL,
  application_status text NOT NULL,
  reviewer_membership_id uuid NOT NULL
);
CREATE TEMP TABLE p4_review_result (
  application_id uuid NOT NULL,
  application_status text NOT NULL,
  organization_id uuid,
  owner_membership_id uuid,
  qualification_id uuid
);
CREATE TEMP TABLE p4_listing_result (
  listing_id uuid NOT NULL,
  product_id uuid NOT NULL,
  variant_id uuid NOT NULL,
  listing_status text NOT NULL,
  listing_version integer NOT NULL
);
CREATE TEMP TABLE p4_standard_listing_target (listing_id uuid NOT NULL);
CREATE TEMP TABLE p4_inventory_result (
  listing_id uuid NOT NULL,
  on_hand integer NOT NULL,
  reserved integer NOT NULL,
  available integer NOT NULL,
  inventory_version integer NOT NULL
);
CREATE TEMP TABLE p4_reservation_result (
  listing_id uuid NOT NULL,
  inventory_kind text NOT NULL,
  inventory_status text NOT NULL,
  available_quantity integer NOT NULL,
  inventory_version integer NOT NULL
);
CREATE TEMP TABLE p4_error_result (
  error_state text NOT NULL,
  error_message text NOT NULL
);
GRANT ALL PRIVILEGES ON TABLE
  pg_temp.p4_application_result, pg_temp.p4_assignment_result,
  pg_temp.p4_review_result, pg_temp.p4_listing_result,
  pg_temp.p4_standard_listing_target,
  pg_temp.p4_inventory_result, pg_temp.p4_reservation_result,
  pg_temp.p4_error_result
TO authenticated, rebuy_business_executor;
GRANT SELECT ON TABLE
  pg_temp.p4_listing_result, pg_temp.p4_standard_listing_target
TO anon;

INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, role, aud)
VALUES
  ('00000000-0000-4000-8000-000000004101', 'p4-applicant@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000004102', 'p4-admin@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000004104', 'p4-other-reviewer@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000004105', 'p4-merchant@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000004106', 'p4-retail@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000004107', 'p4-needs-info@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000004108', 'p4-no-permission@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000004109', 'p4-expired@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;

INSERT INTO public.organizations (
  id, organization_type, display_name, status, created_by
)
VALUES
  ('00000000-0000-4000-8000-000000004401', 'platform', 'P4 Synthetic Platform', 'active', '00000000-0000-4000-8000-000000004102'),
  ('00000000-0000-4000-8000-000000004402', 'merchant', 'P4 Synthetic Merchant', 'active', '00000000-0000-4000-8000-000000004105'),
  ('00000000-0000-4000-8000-000000004403', 'wholesale', 'P4 Expired Wholesale', 'active', '00000000-0000-4000-8000-000000004109');

INSERT INTO public.stores (
  id, organization_id, organization_type, display_name, slug, status, public_visibility
)
VALUES
  ('00000000-0000-4000-8000-000000004501',
   '00000000-0000-4000-8000-000000004402', 'merchant',
   'P4 Synthetic Store', 'p4-synthetic-store', 'active', false),
  ('00000000-0000-4000-8000-000000004502',
   '00000000-0000-4000-8000-000000004402', 'merchant',
   'P4 Other Synthetic Store', 'p4-other-synthetic-store', 'active', false);

INSERT INTO public.memberships (
  id, user_id, organization_id, organization_type,
  role_definition_id, role_version, status, valid_from
)
VALUES
  ('00000000-0000-4000-8000-000000004801', '00000000-0000-4000-8000-000000004102', '00000000-0000-4000-8000-000000004401', 'platform', '00000000-0000-4000-8000-000000000203', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000004802', '00000000-0000-4000-8000-000000004103', '00000000-0000-4000-8000-000000004401', 'platform', '00000000-0000-4000-8000-000000000205', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000004803', '00000000-0000-4000-8000-000000004104', '00000000-0000-4000-8000-000000004401', 'platform', '00000000-0000-4000-8000-000000000205', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000004804', '00000000-0000-4000-8000-000000004105', '00000000-0000-4000-8000-000000004402', 'merchant', '00000000-0000-4000-8000-000000000201', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000004805', '00000000-0000-4000-8000-000000004109', '00000000-0000-4000-8000-000000004403', 'wholesale', '00000000-0000-4000-8000-000000000201', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '3 days'),
  ('00000000-0000-4000-8000-000000004806', '00000000-0000-4000-8000-000000004108', '00000000-0000-4000-8000-000000004401', 'platform', '00000000-0000-4000-8000-000000000205', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
  ('00000000-0000-4000-8000-000000004807', '00000000-0000-4000-8000-000000004106', '00000000-0000-4000-8000-000000004402', 'merchant', '00000000-0000-4000-8000-000000000202', 1, 'active', pg_catalog.statement_timestamp() - INTERVAL '1 hour');

INSERT INTO public.membership_store_scopes (
  id, membership_id, organization_id, organization_type, store_id, scope_type, status
)
VALUES
  ('00000000-0000-4000-8000-000000004901',
   '00000000-0000-4000-8000-000000004804',
   '00000000-0000-4000-8000-000000004402', 'merchant', NULL,
   'organization', 'active'),
  ('00000000-0000-4000-8000-000000004902',
   '00000000-0000-4000-8000-000000004805',
   '00000000-0000-4000-8000-000000004403', 'wholesale', NULL,
   'organization', 'active'),
  ('00000000-0000-4000-8000-000000004903',
   '00000000-0000-4000-8000-000000004807',
   '00000000-0000-4000-8000-000000004402', 'merchant',
   '00000000-0000-4000-8000-000000004501', 'store', 'active');

INSERT INTO public.role_permissions (
  role_definition_id, role_version, permission_id, is_granted
)
VALUES
  ('00000000-0000-4000-8000-000000000202', 1, '00000000-0000-4000-8000-000000000110', true),
  ('00000000-0000-4000-8000-000000000202', 1, '00000000-0000-4000-8000-000000000111', true),
  ('00000000-0000-4000-8000-000000000202', 1, '00000000-0000-4000-8000-000000000112', true),
  ('00000000-0000-4000-8000-000000000202', 1, '00000000-0000-4000-8000-000000000113', true)
ON CONFLICT (role_definition_id, role_version, permission_id)
DO UPDATE SET is_granted = EXCLUDED.is_granted;

INSERT INTO public.wholesale_applications (
  id, applicant_user_id, company_name, country_code, status,
  assigned_reviewer_membership_id, assigned_at, submitted_at
)
VALUES (
  '00000000-0000-4000-8000-000000004601',
  '00000000-0000-4000-8000-000000004109', 'P4 Expired Wholesale', 'IT',
  'under_review', '00000000-0000-4000-8000-000000004802',
  pg_catalog.statement_timestamp() - INTERVAL '2 days',
  pg_catalog.statement_timestamp() - INTERVAL '3 days'
);
INSERT INTO public.wholesale_qualifications (
  id, source_application_id, organization_id, organization_type, status,
  valid_from, valid_until, reason_code, version
)
VALUES (
  '00000000-0000-4000-8000-000000004701',
  '00000000-0000-4000-8000-000000004601',
  '00000000-0000-4000-8000-000000004403', 'wholesale', 'active',
  pg_catalog.statement_timestamp() - INTERVAL '2 days',
  pg_catalog.statement_timestamp() - INTERVAL '1 day',
  'approved_checks_complete', 1
);
UPDATE public.wholesale_applications
SET status = 'approved', organization_id = '00000000-0000-4000-8000-000000004403',
  owner_membership_id = '00000000-0000-4000-8000-000000004805',
  qualification_id = '00000000-0000-4000-8000-000000004701',
  decided_at = pg_catalog.statement_timestamp() - INTERVAL '1 day'
WHERE id = '00000000-0000-4000-8000-000000004601';

SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004101', 'p4-applicant@rebuy.test'
);
SELECT lives_ok(
  $sql$
    INSERT INTO pg_temp.p4_application_result
    SELECT * FROM public.save_wholesale_application(
      'P4 Synthetic Wholesale', 'it', 'syn-wholesale-001',
      'synthetic://wholesale/evidence-001', false,
      '00000000-0000-4000-8000-000000005001'
    )
  $sql$,
  'applicant can save a normalized wholesale draft'
);
SELECT is(
  (SELECT company_name || ':' || country_code || ':' || registration_reference
   FROM public.get_my_wholesale_application()),
  'P4 Synthetic Wholesale:IT:SYN-WHOLESALE-001',
  'own application returns normalized private synthetic references'
);
SELECT is(
  (SELECT application_status FROM private.get_my_wholesale_application_impl()),
  'draft',
  'direct get-my implementation matches the own wrapper result'
);
SELECT is(
  (SELECT application_status FROM private.save_wholesale_application_impl(
    'P4 Synthetic Wholesale', 'IT', 'SYN-WHOLESALE-001',
    'synthetic://wholesale/evidence-001', false,
    '00000000-0000-4000-8000-000000005001'
  )),
  'draft',
  'direct save implementation preserves wrapper idempotency parity'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_wholesale_application(
      'P4 Synthetic Wholesale', 'IT', 'SYN-WHOLESALE-001',
      'https://invalid.example/evidence', true,
      '00000000-0000-4000-8000-000000005002'
    )
  $sql$,
  'P0001', 'wholesale_application_invalid',
  'non-synthetic wholesale evidence is rejected'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_wholesale_application(
      'Changed Wholesale', 'IT', 'SYN-WHOLESALE-001',
      'synthetic://wholesale/evidence-001', false,
      '00000000-0000-4000-8000-000000005001'
    )
  $sql$,
  'P0001', 'p4_idempotency_conflict',
  'same actor and key cannot be reused with another wholesale payload'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004101', 'p4-applicant@rebuy.test', false, 601
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.save_wholesale_application(
      'P4 Synthetic Wholesale', 'IT', 'SYN-WHOLESALE-001',
      'synthetic://wholesale/evidence-001', true,
      '00000000-0000-4000-8000-000000005003'
    )
  $sql$,
  'P0001', 'merchant_recent_otp_required',
  'stale OTP cannot submit a wholesale application'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004101', 'p4-applicant@rebuy.test'
);
TRUNCATE pg_temp.p4_application_result;
INSERT INTO pg_temp.p4_application_result
SELECT * FROM public.save_wholesale_application(
  'P4 Synthetic Wholesale', 'IT', 'SYN-WHOLESALE-001',
  'synthetic://wholesale/evidence-001', true,
  '00000000-0000-4000-8000-000000005003'
);
SELECT is(
  (SELECT application_status FROM pg_temp.p4_application_result),
  'submitted',
  'fresh OTP submits the wholesale application'
);

SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004102', 'p4-admin@rebuy.test'
);
SELECT is(
  (SELECT count(*)::integer FROM public.list_wholesale_review_queue()),
  1,
  'platform admin sees one safe wholesale queue row'
);
SELECT is(
  (SELECT count(*)::integer FROM private.list_wholesale_review_queue_impl()),
  1,
  'direct queue implementation matches the authorized wrapper result'
);
TRUNCATE pg_temp.p4_assignment_result;
INSERT INTO pg_temp.p4_assignment_result
SELECT * FROM public.assign_wholesale_application(
  (SELECT application_id FROM pg_temp.p4_application_result),
  '00000000-0000-4000-8000-000000004802',
  '00000000-0000-4000-8000-000000005004'
);
SELECT is(
  (SELECT application_status FROM pg_temp.p4_assignment_result),
  'under_review',
  'admin assigns the application to an eligible reviewer'
);
SELECT is(
  (SELECT application_status FROM private.assign_wholesale_application_impl(
    (SELECT application_id FROM pg_temp.p4_application_result),
    '00000000-0000-4000-8000-000000004802',
    '00000000-0000-4000-8000-000000005004'
  )),
  'under_review',
  'direct assignment implementation preserves wrapper idempotency parity'
);

SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004104', 'p4-other-reviewer@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_assigned_wholesale_application(%L)',
    (SELECT application_id FROM pg_temp.p4_application_result)
  ),
  'P0001', 'wholesale_application_not_available',
  'another reviewer cannot read assigned private evidence'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM private.get_assigned_wholesale_application_impl(%L)',
    (SELECT application_id FROM pg_temp.p4_application_result)
  ),
  'P0001', 'wholesale_application_not_available',
  'direct assigned-detail implementation rejects another reviewer'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM private.review_wholesale_application_impl(%L, %L, %L, NULL, %L)',
    (SELECT application_id FROM pg_temp.p4_application_result),
    'reject', 'eligibility_not_met',
    '00000000-0000-4000-8000-000000005021'
  ),
  'P0001', 'wholesale_application_not_available',
  'direct review implementation rejects a non-assigned reviewer'
);

SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test'
);
SELECT is(
  (SELECT registration_reference
   FROM public.get_assigned_wholesale_application(
     (SELECT application_id FROM pg_temp.p4_application_result)
   )),
  'SYN-WHOLESALE-001',
  'assigned reviewer can read only the controlled private detail'
);
SELECT is(
  (SELECT registration_reference
   FROM private.get_assigned_wholesale_application_impl(
     (SELECT application_id FROM pg_temp.p4_application_result)
   )),
  'SYN-WHOLESALE-001',
  'direct assigned-detail implementation matches the authorized wrapper'
);
TRUNCATE pg_temp.p4_review_result;
INSERT INTO pg_temp.p4_review_result
SELECT * FROM public.review_wholesale_application(
  (SELECT application_id FROM pg_temp.p4_application_result),
  'approve', 'approved_checks_complete',
  pg_catalog.transaction_timestamp() + INTERVAL '365 days',
  '00000000-0000-4000-8000-000000005005'
);
SELECT is(
  (SELECT application_status FROM pg_temp.p4_review_result),
  'approved',
  'assigned reviewer approves the wholesale application'
);
SELECT lives_ok(
  pg_catalog.format(
    'SELECT * FROM public.review_wholesale_application(%L, %L, %L, %L, %L)',
    (SELECT application_id FROM pg_temp.p4_review_result),
    'approve', 'approved_checks_complete',
    pg_catalog.transaction_timestamp() + INTERVAL '365 days',
    '00000000-0000-4000-8000-000000005005'
  ),
  'same approval key returns the original wholesale result'
);
SELECT is(
  (SELECT application_status FROM private.review_wholesale_application_impl(
    (SELECT application_id FROM pg_temp.p4_review_result),
    'approve', 'approved_checks_complete',
    pg_catalog.transaction_timestamp() + INTERVAL '365 days',
    '00000000-0000-4000-8000-000000005005'
  )),
  'approved',
  'direct review implementation preserves wrapper idempotency parity'
);

RESET ROLE;
SELECT is(
  (SELECT count(*)::integer FROM public.organizations
   WHERE id = (SELECT organization_id FROM pg_temp.p4_review_result)
     AND organization_type = 'wholesale' AND status = 'active'),
  1,
  'approval atomically creates the wholesale organization'
);
SELECT is(
  (SELECT count(*)::integer FROM public.memberships
   WHERE id = (SELECT owner_membership_id FROM pg_temp.p4_review_result)
     AND user_id = '00000000-0000-4000-8000-000000004101'
     AND status = 'active'),
  1,
  'approval atomically creates the wholesale owner membership'
);
SELECT is(
  (SELECT count(*)::integer FROM public.wholesale_qualifications
   WHERE id = (SELECT qualification_id FROM pg_temp.p4_review_result)
     AND status = 'active'),
  1,
  'approval atomically creates one active qualification'
);
SELECT is(
  (SELECT count(*)::integer FROM public.membership_store_scopes
   WHERE membership_id = (SELECT owner_membership_id FROM pg_temp.p4_review_result)
     AND scope_type = 'organization' AND status = 'active'),
  1,
  'approval atomically creates the wholesale organization scope'
);

SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004107', 'p4-needs-info@rebuy.test'
);
TRUNCATE pg_temp.p4_application_result;
INSERT INTO pg_temp.p4_application_result
SELECT * FROM public.save_wholesale_application(
  'P4 Needs Info Wholesale', 'IT', 'SYN-WHOLESALE-NEEDS-INFO',
  'synthetic://wholesale/needs-info', true,
  '00000000-0000-4000-8000-000000005010'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004102', 'p4-admin@rebuy.test'
);
SELECT lives_ok(
  pg_catalog.format(
    'SELECT * FROM public.assign_wholesale_application(%L, %L, %L)',
    (SELECT application_id FROM pg_temp.p4_application_result),
    '00000000-0000-4000-8000-000000004802',
    '00000000-0000-4000-8000-000000005011'
  ),
  'admin assigns the needs-info test application'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test'
);
SELECT is(
  (SELECT application_status FROM public.review_wholesale_application(
    (SELECT application_id FROM pg_temp.p4_application_result),
    'needs_info', 'information_incomplete', NULL,
    '00000000-0000-4000-8000-000000005012'
  )),
  'needs_info',
  'assigned reviewer can request bounded additional information'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004107', 'p4-needs-info@rebuy.test'
);
SELECT is(
  (SELECT application_status FROM public.save_wholesale_application(
    'P4 Needs Info Wholesale', 'IT', 'SYN-WHOLESALE-NEEDS-INFO',
    'synthetic://wholesale/needs-info-updated', false,
    '00000000-0000-4000-8000-000000005013'
  )),
  'draft',
  'applicant can return a needs-info application to draft'
);
RESET ROLE;
SELECT ok(
  (SELECT submitted_at IS NULL AND assigned_reviewer_membership_id IS NULL
   FROM public.wholesale_applications
   WHERE id = (SELECT application_id FROM pg_temp.p4_application_result)),
  'draft after needs-info clears submission and reviewer assignment'
);
SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004107', 'p4-needs-info@rebuy.test'
);
SELECT is(
  (SELECT application_status FROM public.save_wholesale_application(
    'P4 Needs Info Wholesale', 'IT', 'SYN-WHOLESALE-NEEDS-INFO',
    'synthetic://wholesale/needs-info-updated', true,
    '00000000-0000-4000-8000-000000005014'
  )),
  'submitted',
  'updated needs-info draft can be resubmitted'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test'
);
SELECT is(
  (SELECT application_status FROM public.review_wholesale_application(
    (SELECT application_id FROM pg_temp.p4_application_result),
    'needs_info', 'information_incomplete', NULL,
    '00000000-0000-4000-8000-000000005012'
  )),
  'needs_info',
  'old needs-info key returns the original result after resubmission clears assignment'
);
RESET ROLE;
SELECT is(
  (SELECT status FROM public.wholesale_applications
   WHERE id = (SELECT application_id FROM pg_temp.p4_application_result)),
  'submitted',
  'old needs-info retry does not roll back the current application state'
);
SELECT is(
  (SELECT count(*)::integer FROM public.wholesale_application_events
   WHERE application_id = (SELECT application_id FROM pg_temp.p4_application_result)
     AND idempotency_key = '00000000-0000-4000-8000-000000005012'),
  1,
  'old needs-info retry does not append a duplicate event'
);
SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004102', 'p4-admin@rebuy.test'
);
SELECT lives_ok(
  pg_catalog.format(
    'SELECT * FROM public.assign_wholesale_application(%L, %L, %L)',
    (SELECT application_id FROM pg_temp.p4_application_result),
    '00000000-0000-4000-8000-000000004802',
    '00000000-0000-4000-8000-000000005015'
  ),
  'admin reassigns the resubmitted application'
);
RESET ROLE;
CREATE OR REPLACE FUNCTION pg_temp.p4_fail_qualification_insert()
RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
  RAISE EXCEPTION 'p4_test_injected_qualification_failure';
END
$function$;
CREATE TRIGGER p4_test_fail_qualification_insert
BEFORE INSERT ON public.wholesale_qualifications
FOR EACH ROW EXECUTE FUNCTION pg_temp.p4_fail_qualification_insert();
SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.review_wholesale_application(%L, %L, %L, pg_catalog.transaction_timestamp() + interval %L, %L)',
    (SELECT application_id FROM pg_temp.p4_application_result),
    'approve', 'approved_checks_complete', '365 days',
    '00000000-0000-4000-8000-000000005016'
  ),
  'P0001', 'p4_test_injected_qualification_failure',
  'injected failure after organization and membership inserts aborts approval'
);
RESET ROLE;
DROP TRIGGER p4_test_fail_qualification_insert ON public.wholesale_qualifications;
SELECT is(
  (SELECT count(*)::integer FROM public.organizations
   WHERE created_by = '00000000-0000-4000-8000-000000004107'),
  0,
  'mid-approval failure leaves no partial wholesale organization'
);
SELECT is(
  (SELECT count(*)::integer FROM public.memberships
   WHERE user_id = '00000000-0000-4000-8000-000000004107'),
  0,
  'mid-approval failure leaves no partial owner membership'
);
SELECT is(
  (SELECT count(*)::integer FROM public.wholesale_application_events
   WHERE application_id = (SELECT application_id FROM pg_temp.p4_application_result)
     AND event_code = 'wholesale_application.approved'),
  0,
  'mid-approval failure leaves no approval audit event'
);
SELECT is(
  (SELECT count(*)::integer FROM public.p4_idempotency_keys
   WHERE actor_user_id = '00000000-0000-4000-8000-000000004103'
     AND idempotency_key = '00000000-0000-4000-8000-000000005016'),
  0,
  'mid-approval failure leaves no idempotency result'
);
SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test'
);
SELECT is(
  (SELECT application_status FROM public.review_wholesale_application(
    (SELECT application_id FROM pg_temp.p4_application_result),
    'reject', 'eligibility_not_met', NULL,
    '00000000-0000-4000-8000-000000005017'
  )),
  'rejected',
  'assigned reviewer can reject without creating wholesale business objects'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004108', 'p4-no-permission@rebuy.test'
);
TRUNCATE pg_temp.p4_application_result;
INSERT INTO pg_temp.p4_application_result
SELECT * FROM public.save_wholesale_application(
  'P4 Self Review Wholesale', 'IT', 'SYN-WHOLESALE-SELF',
  'synthetic://wholesale/self-review', true,
  '00000000-0000-4000-8000-000000005018'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004102', 'p4-admin@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.assign_wholesale_application(%L, %L, %L)',
    (SELECT application_id FROM pg_temp.p4_application_result),
    '00000000-0000-4000-8000-000000004806',
    '00000000-0000-4000-8000-000000005019'
  ),
  'P0001', 'wholesale_reviewer_not_available',
  'an applicant cannot be assigned to review the own application'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004108', 'p4-no-permission@rebuy.test'
);
SELECT is(
  (SELECT application_status FROM public.withdraw_wholesale_application(
    (SELECT application_id FROM pg_temp.p4_application_result),
    '00000000-0000-4000-8000-000000005020'
  )),
  'withdrawn',
  'applicant can withdraw an unassigned submitted application'
);
SELECT is(
  (SELECT application_status FROM private.withdraw_wholesale_application_impl(
    (SELECT application_id FROM pg_temp.p4_application_result),
    '00000000-0000-4000-8000-000000005020'
  )),
  'withdrawn',
  'direct withdrawal implementation preserves wrapper idempotency parity'
);

SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004105', 'p4-merchant@rebuy.test'
);
TRUNCATE pg_temp.p4_listing_result;
INSERT INTO pg_temp.p4_listing_result
SELECT * FROM public.upsert_catalog_listing(
  NULL, '00000000-0000-4000-8000-000000004501', 'electronics',
  'standard', 'Synthetic Standard Device', 'syn-sku-standard-01',
  'synthetic-standard-device', 'Synthetic Standard Device',
  'Synthetic catalog item for P4 tests',
  10000, 8000, 5,
  '[{"minimum_quantity":10,"unit_amount_cents":7500},{"minimum_quantity":20,"unit_amount_cents":7000}]'::jsonb,
  12, NULL, NULL, NULL, NULL, NULL, true, 0,
  '00000000-0000-4000-8000-000000005101'
);
SELECT is(
  (SELECT listing_status || ':' || listing_version::text FROM pg_temp.p4_listing_result),
  'active:1',
  'merchant owner publishes a standard listing with version one'
);
INSERT INTO pg_temp.p4_standard_listing_target
SELECT listing_id FROM pg_temp.p4_listing_result;
SELECT throws_ok(
  $sql$
    SELECT * FROM public.upsert_catalog_listing(
      NULL, '00000000-0000-4000-8000-000000004501', 'electronics',
      'standard', 'Duplicate Slug Device', 'SYN-SKU-DUPLICATE-SLUG',
      'synthetic-standard-device', 'Duplicate Slug Device',
      'Synthetic duplicate slug for bounded conflict',
      9900, NULL, NULL, '[]'::jsonb,
      2, NULL, NULL, NULL, NULL, NULL, true, 0,
      '00000000-0000-4000-8000-000000005106'
    )
  $sql$,
  'P0001', 'catalog_unique_conflict',
  'duplicate store slug maps to a bounded catalog error'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.upsert_catalog_listing(
      NULL, '00000000-0000-4000-8000-000000004501', 'electronics',
      'standard', 'Duplicate SKU Device', 'SYN-SKU-STANDARD-01',
      'duplicate-sku-device', 'Duplicate SKU Device',
      'Synthetic duplicate sku for bounded conflict',
      9900, NULL, NULL, '[]'::jsonb,
      2, NULL, NULL, NULL, NULL, NULL, true, 0,
      '00000000-0000-4000-8000-000000005107'
    )
  $sql$,
  'P0001', 'catalog_unique_conflict',
  'duplicate organization SKU maps to a bounded catalog error'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.upsert_catalog_listing(
      NULL, '00000000-0000-4000-8000-000000004501', 'electronics',
      'standard', 'Invalid Slug Device', 'SYN-SKU-INVALID-SLUG',
      'Invalid Slug!', 'Invalid Slug Device', 'Synthetic invalid slug',
      9900, NULL, NULL, '[]'::jsonb,
      2, NULL, NULL, NULL, NULL, NULL, true, 0,
      '00000000-0000-4000-8000-000000005108'
    )
  $sql$,
  'P0001', 'catalog_listing_invalid',
  'invalid listing slug is rejected before any write'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.upsert_catalog_listing(
      NULL, '00000000-0000-4000-8000-000000004501', 'electronics',
      'standard', 'Invalid SKU Device', 'INVALID-SKU',
      'invalid-sku-device', 'Invalid SKU Device', 'Synthetic invalid sku',
      9900, NULL, NULL, '[]'::jsonb,
      2, NULL, NULL, NULL, NULL, NULL, true, 0,
      '00000000-0000-4000-8000-000000005109'
    )
  $sql$,
  'P0001', 'catalog_listing_invalid',
  'invalid synthetic SKU is rejected before any write'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004108', 'p4-no-permission@rebuy.test'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.upsert_catalog_listing(
      NULL, '00000000-0000-4000-8000-000000004501', 'electronics',
      'standard', 'Cross Tenant Device', 'SYN-SKU-CROSS-TENANT',
      'cross-tenant-device', 'Cross Tenant Device', 'Synthetic cross tenant attempt',
      9900, NULL, NULL, '[]'::jsonb,
      2, NULL, NULL, NULL, NULL, NULL, true, 0,
      '00000000-0000-4000-8000-000000005110'
    )
  $sql$,
  'P0001', 'catalog_write_forbidden',
  'platform reviewer cannot write another tenant catalog'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM private.upsert_catalog_listing_impl(
      NULL, '00000000-0000-4000-8000-000000004501', 'electronics',
      'standard', 'Cross Tenant Device', 'SYN-SKU-CROSS-TENANT',
      'cross-tenant-device', 'Cross Tenant Device', 'Synthetic cross tenant attempt',
      9900, NULL, NULL, '[]'::jsonb,
      2, NULL, NULL, NULL, NULL, NULL, true, 0,
      '00000000-0000-4000-8000-000000005110'
    )
  $sql$,
  'P0001', 'catalog_write_forbidden',
  'direct catalog implementation rejects another tenant actor'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004106', 'p4-retail@rebuy.test'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.upsert_catalog_listing(
      NULL, '00000000-0000-4000-8000-000000004502', 'electronics',
      'standard', 'Cross Store Device', 'SYN-SKU-CROSS-STORE',
      'cross-store-device', 'Cross Store Device', 'Synthetic cross store attempt',
      9900, NULL, NULL, '[]'::jsonb,
      2, NULL, NULL, NULL, NULL, NULL, true, 0,
      '00000000-0000-4000-8000-000000005111'
    )
  $sql$,
  'P0001', 'catalog_write_forbidden',
  'store-scoped merchant member cannot write another store'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004105', 'p4-merchant@rebuy.test'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.upsert_catalog_listing(
      NULL, '00000000-0000-4000-8000-000000004501', 'electronics',
      'standard', 'Invalid Tier Device', 'SYN-SKU-INVALID-01',
      'invalid-tier-device', 'Invalid Tier Device', 'Synthetic invalid tier matrix',
      10000, 8000, 5,
      '[{"minimum_quantity":10,"unit_amount_cents":7000},{"minimum_quantity":20,"unit_amount_cents":7500}]'::jsonb,
      2, NULL, NULL, NULL, NULL, NULL, true, 0,
      '00000000-0000-4000-8000-000000005102'
    )
  $sql$,
  'P0001', 'catalog_wholesale_tier_invalid',
  'a wholesale tier price cannot rise with quantity'
);

RESET ROLE;
SELECT pg_catalog.set_config('request.jwt.claims', '{}'::jsonb::text, true);
SET LOCAL ROLE anon;
SELECT is(
  (SELECT count(*)::integer FROM public.list_public_catalog()
   WHERE listing_id = (SELECT listing_id FROM pg_temp.p4_standard_listing_target)),
  1,
  'anonymous catalog exposes the active in-stock listing DTO'
);
SELECT is(
  (SELECT audience || ':' || unit_amount_cents::text || ':' || minimum_quantity::text
   FROM public.get_catalog_quote(
     (SELECT listing_id FROM pg_temp.p4_listing_result), 5
   )),
  'retail:10000:1',
  'guest quote exposes only the retail price'
);
SELECT is(
  (SELECT count(*)::integer FROM private.list_public_catalog_impl()
   WHERE listing_id = (SELECT listing_id FROM pg_temp.p4_listing_result)),
  1,
  'direct public-catalog implementation matches the anonymous wrapper DTO'
);
SELECT is(
  (SELECT audience || ':' || unit_amount_cents::text
   FROM private.get_catalog_quote_impl(
     (SELECT listing_id FROM pg_temp.p4_listing_result), 5
   )),
  'retail:10000',
  'direct quote implementation preserves anonymous retail parity'
);

RESET ROLE;
UPDATE public.stores SET status = 'suspended'
WHERE id = '00000000-0000-4000-8000-000000004501';
SET LOCAL ROLE anon;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_catalog_quote(%L, 1)',
    (SELECT listing_id FROM pg_temp.p4_listing_result)
  ),
  'P0001', 'catalog_listing_not_available',
  'suspended store makes its listing unavailable'
);
RESET ROLE;
UPDATE public.stores SET status = 'active'
WHERE id = '00000000-0000-4000-8000-000000004501';
UPDATE public.organizations SET status = 'suspended'
WHERE id = '00000000-0000-4000-8000-000000004402';
SET LOCAL ROLE anon;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_catalog_quote(%L, 1)',
    (SELECT listing_id FROM pg_temp.p4_listing_result)
  ),
  'P0001', 'catalog_listing_not_available',
  'suspended merchant organization makes its listing unavailable'
);
RESET ROLE;
UPDATE public.organizations SET status = 'active'
WHERE id = '00000000-0000-4000-8000-000000004402';
UPDATE public.products SET status = 'inactive'
WHERE id = (SELECT product_id FROM pg_temp.p4_listing_result);
SET LOCAL ROLE anon;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_catalog_quote(%L, 1)',
    (SELECT listing_id FROM pg_temp.p4_listing_result)
  ),
  'P0001', 'catalog_listing_not_available',
  'inactive product makes its listing unavailable'
);
RESET ROLE;
UPDATE public.products SET status = 'active'
WHERE id = (SELECT product_id FROM pg_temp.p4_listing_result);
UPDATE public.product_variants SET status = 'inactive'
WHERE id = (SELECT variant_id FROM pg_temp.p4_listing_result);
SET LOCAL ROLE anon;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_catalog_quote(%L, 1)',
    (SELECT listing_id FROM pg_temp.p4_listing_result)
  ),
  'P0001', 'catalog_listing_not_available',
  'inactive variant makes its listing unavailable'
);
RESET ROLE;
UPDATE public.product_variants SET status = 'active'
WHERE id = (SELECT variant_id FROM pg_temp.p4_listing_result);
UPDATE public.listings SET status = 'inactive'
WHERE id = (SELECT listing_id FROM pg_temp.p4_listing_result);
SET LOCAL ROLE anon;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_catalog_quote(%L, 1)',
    (SELECT listing_id FROM pg_temp.p4_listing_result)
  ),
  'P0001', 'catalog_listing_not_available',
  'inactive listing is not publicly quotable'
);
RESET ROLE;
UPDATE public.listings SET status = 'active'
WHERE id = (SELECT listing_id FROM pg_temp.p4_listing_result);
UPDATE public.inventory_levels SET reserved = on_hand
WHERE listing_id = (SELECT listing_id FROM pg_temp.p4_listing_result);
SET LOCAL ROLE anon;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_catalog_quote(%L, 1)',
    (SELECT listing_id FROM pg_temp.p4_listing_result)
  ),
  'P0001', 'catalog_listing_not_available',
  'standard listing with zero available stock is not publicly quotable'
);
RESET ROLE;
UPDATE public.inventory_levels SET reserved = 0
WHERE listing_id = (SELECT listing_id FROM pg_temp.p4_listing_result);

SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004101', 'p4-applicant@rebuy.test'
);
SELECT is(
  (SELECT audience || ':' || unit_amount_cents::text || ':' || minimum_quantity::text
   FROM public.get_catalog_quote(
     (SELECT listing_id FROM pg_temp.p4_listing_result), 10
   )),
  'wholesale:7500:5',
  'active qualified owner receives the automatic wholesale tier quote'
);
SELECT is(
  (SELECT purchasable FROM public.get_catalog_quote(
    (SELECT listing_id FROM pg_temp.p4_listing_result), 1
  )),
  false,
  'qualified wholesale quote enforces MOQ server-side'
);

SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004109', 'p4-expired@rebuy.test'
);
SELECT is(
  (SELECT audience || ':' || unit_amount_cents::text
   FROM public.get_catalog_quote(
     (SELECT listing_id FROM pg_temp.p4_listing_result), 10
   )),
  'retail:10000',
  'time-expired qualification falls back to retail before status cleanup'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test'
);
SELECT is(
  (SELECT qualification_status || ':' || qualification_version::text
   FROM public.change_wholesale_qualification(
     '00000000-0000-4000-8000-000000004701',
     'expire', '00000000-0000-4000-8000-000000005008'
   )),
  'expired:2',
  'assigned reviewer records an elapsed qualification as expired'
);

SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test'
);
SELECT is(
  (SELECT qualification_status || ':' || qualification_version::text
   FROM public.change_wholesale_qualification(
     (SELECT qualification_id FROM pg_temp.p4_review_result),
     'suspend', '00000000-0000-4000-8000-000000005006'
   )),
  'suspended:2',
  'assigned reviewer can suspend the current qualification'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004101', 'p4-applicant@rebuy.test'
);
SELECT is(
  (SELECT audience || ':' || unit_amount_cents::text
   FROM public.get_catalog_quote(
     (SELECT listing_id FROM pg_temp.p4_listing_result), 10
   )),
  'retail:10000',
  'suspended qualification immediately falls back to retail price'
);

SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test'
);
SELECT is(
  (SELECT qualification_status || ':' || qualification_version::text
   FROM public.change_wholesale_qualification(
     (SELECT qualification_id FROM pg_temp.p4_review_result),
     'reactivate', '00000000-0000-4000-8000-000000005007'
   )),
  'active:3',
  'unexpired suspended qualification can be reactivated'
);
SELECT is(
  (SELECT qualification_status || ':' || qualification_version::text
   FROM private.change_wholesale_qualification_impl(
     (SELECT qualification_id FROM pg_temp.p4_review_result),
     'reactivate', '00000000-0000-4000-8000-000000005007'
   )),
  'active:3',
  'direct qualification implementation preserves wrapper idempotency parity'
);

RESET ROLE;
UPDATE public.organizations SET status = 'suspended'
WHERE id = (SELECT organization_id FROM pg_temp.p4_review_result);
SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004101', 'p4-applicant@rebuy.test'
);
SELECT is(
  (SELECT audience FROM public.get_catalog_quote(
    (SELECT listing_id FROM pg_temp.p4_listing_result), 10
  )),
  'retail',
  'suspended wholesale organization immediately falls back to retail'
);
RESET ROLE;
UPDATE public.organizations SET status = 'active'
WHERE id = (SELECT organization_id FROM pg_temp.p4_review_result);
UPDATE public.memberships SET status = 'suspended'
WHERE id = (SELECT owner_membership_id FROM pg_temp.p4_review_result);
SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004101', 'p4-applicant@rebuy.test'
);
SELECT is(
  (SELECT audience FROM public.get_catalog_quote(
    (SELECT listing_id FROM pg_temp.p4_listing_result), 10
  )),
  'retail',
  'suspended wholesale owner membership immediately falls back to retail'
);
RESET ROLE;
UPDATE public.memberships SET status = 'active'
WHERE id = (SELECT owner_membership_id FROM pg_temp.p4_review_result);
SET LOCAL ROLE authenticated;

SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004105', 'p4-merchant@rebuy.test'
);
SELECT is(
  (SELECT listing_version FROM private.upsert_catalog_listing_impl(
    NULL, '00000000-0000-4000-8000-000000004501', 'electronics',
    'standard', 'Synthetic Standard Device', 'SYN-SKU-STANDARD-01',
    'synthetic-standard-device', 'Synthetic Standard Device',
    'Synthetic catalog item for P4 tests',
    10000, 8000, 5,
    '[{"minimum_quantity":10,"unit_amount_cents":7500},{"minimum_quantity":20,"unit_amount_cents":7000}]'::jsonb,
    12, NULL, NULL, NULL, NULL, NULL, true, 0,
    '00000000-0000-4000-8000-000000005101'
  )),
  1,
  'direct catalog implementation returns the original create result'
);
TRUNCATE pg_temp.p4_listing_result;
INSERT INTO pg_temp.p4_listing_result
SELECT * FROM public.upsert_catalog_listing(
  (SELECT listing_id FROM pg_temp.p4_standard_listing_target),
  '00000000-0000-4000-8000-000000004501', 'electronics',
  'standard', 'Synthetic Standard Device V2', 'SYN-SKU-STANDARD-01',
  'synthetic-standard-device', 'Synthetic Standard Device V2',
  'Synthetic catalog item with versioned price',
  9500, 7600, 5,
  '[{"minimum_quantity":10,"unit_amount_cents":7200},{"minimum_quantity":20,"unit_amount_cents":6800}]'::jsonb,
  NULL, NULL, NULL, NULL, NULL, NULL, true, 1,
  '00000000-0000-4000-8000-000000005112'
);
SELECT is(
  (SELECT listing_status || ':' || listing_version::text FROM pg_temp.p4_listing_result),
  'active:2',
  'catalog update publishes a new listing and price version'
);
SELECT is(
  (SELECT unit_amount_cents::text || ':' || price_version::text || ':' || listing_version::text
   FROM public.get_catalog_quote(
     (SELECT listing_id FROM pg_temp.p4_listing_result), 1
   )),
  '9500:2:2',
  'updated retail quote exposes the new price and listing versions'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.upsert_catalog_listing(%L, %L, %L, %L, %L, %L, %L, %L, %L, 9500, 7600, 5, %L::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, true, 1, %L)',
    (SELECT listing_id FROM pg_temp.p4_listing_result),
    '00000000-0000-4000-8000-000000004501', 'electronics', 'standard',
    'Synthetic Standard Device V2', 'SYN-SKU-STANDARD-01',
    'synthetic-standard-device', 'Synthetic Standard Device V2',
    'Synthetic catalog item with versioned price',
    '[{"minimum_quantity":10,"unit_amount_cents":7200},{"minimum_quantity":20,"unit_amount_cents":6800}]',
    '00000000-0000-4000-8000-000000005113'
  ),
  'P0001', 'catalog_version_conflict',
  'stale expected listing version is rejected'
);
SELECT is(
  (SELECT listing_version FROM private.upsert_catalog_listing_impl(
    (SELECT listing_id FROM pg_temp.p4_listing_result),
    '00000000-0000-4000-8000-000000004501', 'electronics',
    'standard', 'Synthetic Standard Device V2', 'SYN-SKU-STANDARD-01',
    'synthetic-standard-device', 'Synthetic Standard Device V2',
    'Synthetic catalog item with versioned price',
    9500, 7600, 5,
    '[{"minimum_quantity":10,"unit_amount_cents":7200},{"minimum_quantity":20,"unit_amount_cents":6800}]'::jsonb,
    NULL, NULL, NULL, NULL, NULL, NULL, true, 1,
    '00000000-0000-4000-8000-000000005112'
  )),
  2,
  'direct catalog implementation preserves update idempotency parity'
);
TRUNCATE pg_temp.p4_inventory_result;
INSERT INTO pg_temp.p4_inventory_result
SELECT * FROM public.adjust_inventory(
  (SELECT listing_id FROM pg_temp.p4_listing_result), 3, 1,
  '00000000-0000-4000-8000-000000005103'
);
SELECT is(
  (SELECT on_hand::text || ':' || reserved::text || ':' || available::text || ':' || inventory_version::text
   FROM pg_temp.p4_inventory_result),
  '15:0:15:2',
  'merchant stock adjustment updates the versioned inventory truth'
);
TRUNCATE pg_temp.p4_inventory_result;
INSERT INTO pg_temp.p4_inventory_result
SELECT * FROM public.adjust_inventory(
  (SELECT listing_id FROM pg_temp.p4_listing_result), -2, 2,
  '00000000-0000-4000-8000-000000005104'
);
SELECT is(
  (SELECT on_hand::text || ':' || available::text || ':' || inventory_version::text
   FROM pg_temp.p4_inventory_result),
  '13:13:3',
  'a second stock adjustment consumes the expected version'
);
TRUNCATE pg_temp.p4_inventory_result;
INSERT INTO pg_temp.p4_inventory_result
SELECT * FROM public.adjust_inventory(
  (SELECT listing_id FROM pg_temp.p4_listing_result), 3, 1,
  '00000000-0000-4000-8000-000000005103'
);
SELECT is(
  (SELECT on_hand::text || ':' || reserved::text || ':' || available::text || ':' || inventory_version::text
   FROM pg_temp.p4_inventory_result),
  '15:0:15:2',
  'old inventory retry returns its original quantities and version after later changes'
);
SELECT is(
  (SELECT on_hand::text || ':' || available::text || ':' || inventory_version::text
   FROM private.adjust_inventory_impl(
     (SELECT listing_id FROM pg_temp.p4_listing_result), 3, 1,
     '00000000-0000-4000-8000-000000005103'
   )),
  '15:15:2',
  'direct inventory implementation preserves historical result parity'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.adjust_inventory(%L, 1, 3, %L)',
    (SELECT listing_id FROM pg_temp.p4_listing_result),
    '00000000-0000-4000-8000-000000005101'
  ),
  'P0001', 'p4_idempotency_conflict',
  'same actor-global key cannot cross from catalog to inventory operation'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.adjust_inventory(%L, -14, 3, %L)',
    (SELECT listing_id FROM pg_temp.p4_listing_result),
    '00000000-0000-4000-8000-000000005105'
  ),
  'P0001', 'inventory_quantity_conflict',
  'stock cannot be adjusted below zero'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.adjust_inventory(%L, 1000000, 3, %L)',
    (SELECT listing_id FROM pg_temp.p4_listing_result),
    '00000000-0000-4000-8000-000000005106'
  ),
  'P0001', 'inventory_quantity_conflict',
  'repeated legal adjustments cannot exceed the bounded total stock ceiling'
);

RESET ROLE;
UPDATE public.memberships SET status = 'suspended'
WHERE id = '00000000-0000-4000-8000-000000004804';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004105', 'p4-merchant@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.adjust_inventory(%L, 3, 1, %L)',
    (SELECT listing_id FROM pg_temp.p4_listing_result),
    '00000000-0000-4000-8000-000000005103'
  ),
  'P0001', 'inventory_adjust_forbidden',
  'old inventory retry revalidates current merchant membership'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.upsert_catalog_listing(
      NULL, '00000000-0000-4000-8000-000000004501', 'electronics',
      'standard', 'Synthetic Standard Device', 'SYN-SKU-STANDARD-01',
      'synthetic-standard-device', 'Synthetic Standard Device',
      'Synthetic catalog item for P4 tests',
      10000, 8000, 5,
      '[{"minimum_quantity":10,"unit_amount_cents":7500},{"minimum_quantity":20,"unit_amount_cents":7000}]'::jsonb,
      12, NULL, NULL, NULL, NULL, NULL, true, 0,
      '00000000-0000-4000-8000-000000005101'
    )
  $sql$,
  'P0001', 'catalog_write_forbidden',
  'old catalog retry revalidates current merchant membership'
);
RESET ROLE;
UPDATE public.memberships SET status = 'active'
WHERE id = '00000000-0000-4000-8000-000000004804';
UPDATE public.stores SET status = 'suspended'
WHERE id = '00000000-0000-4000-8000-000000004501';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004105', 'p4-merchant@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.adjust_inventory(%L, 3, 1, %L)',
    (SELECT listing_id FROM pg_temp.p4_listing_result),
    '00000000-0000-4000-8000-000000005103'
  ),
  'P0001', 'inventory_not_available',
  'inventory adjustment retry rejects a suspended store'
);
RESET ROLE;
UPDATE public.stores SET status = 'active'
WHERE id = '00000000-0000-4000-8000-000000004501';

SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004106', 'p4-retail@rebuy.test'
);
SET LOCAL ROLE rebuy_business_executor;
TRUNCATE pg_temp.p4_reservation_result;
INSERT INTO pg_temp.p4_reservation_result
SELECT * FROM private.change_inventory_reservation_impl(
  (SELECT listing_id FROM pg_temp.p4_listing_result), 10, 'reserve', 3,
  'SYN-ORDER-STANDARD-01', '00000000-0000-4000-8000-000000005201'
);
RESET ROLE;
SELECT is(
  (SELECT inventory_kind || ':' || inventory_status || ':' || available_quantity::text || ':' || inventory_version::text
   FROM pg_temp.p4_reservation_result),
  'standard:reserved:3:4',
  'P5-only primitive atomically reserves available standard inventory'
);
TRUNCATE pg_temp.p4_reservation_result;
SET LOCAL ROLE rebuy_business_executor;
INSERT INTO pg_temp.p4_reservation_result
SELECT * FROM private.change_inventory_reservation_impl(
  (SELECT listing_id FROM pg_temp.p4_listing_result), 2, 'sell', 4,
  'SYN-ORDER-STANDARD-01', '00000000-0000-4000-8000-000000005202'
);
RESET ROLE;
SELECT is(
  (SELECT inventory_status || ':' || available_quantity::text || ':' || inventory_version::text
   FROM pg_temp.p4_reservation_result),
  'sold:3:5',
  'standard sale consumes on-hand and reserved quantities together'
);
SELECT is(
  (SELECT count(*)::integer FROM public.inventory_events
   WHERE listing_id = (SELECT listing_id FROM pg_temp.p4_listing_result)
     AND event_code = 'inventory.sold'),
  1,
  'standard sale emits one distinct sold audit event'
);
TRUNCATE pg_temp.p4_reservation_result;
SET LOCAL ROLE rebuy_business_executor;
INSERT INTO pg_temp.p4_reservation_result
SELECT * FROM private.change_inventory_reservation_impl(
  (SELECT listing_id FROM pg_temp.p4_listing_result), 10, 'reserve', 3,
  'SYN-ORDER-STANDARD-01', '00000000-0000-4000-8000-000000005201'
);
RESET ROLE;
SELECT is(
  (SELECT inventory_status || ':' || available_quantity::text || ':' || inventory_version::text
   FROM pg_temp.p4_reservation_result),
  'reserved:3:4',
  'old reservation retry returns its original status, availability and version'
);
TRUNCATE pg_temp.p4_reservation_result;
SET LOCAL ROLE rebuy_business_executor;
INSERT INTO pg_temp.p4_reservation_result
SELECT * FROM private.change_inventory_reservation_impl(
  (SELECT listing_id FROM pg_temp.p4_listing_result), 3, 'release', 5,
  'SYN-ORDER-STANDARD-01', '00000000-0000-4000-8000-000000005204'
);
RESET ROLE;
SELECT is(
  (SELECT il.on_hand::text || ':' || il.reserved::text || ':' ||
          (il.on_hand - il.reserved)::text || ':' || il.version::text
   FROM public.inventory_levels il
   WHERE il.listing_id = (SELECT listing_id FROM pg_temp.p4_listing_result)),
  '11:5:6:6',
  'standard release preserves on-hand while returning reserved stock to availability'
);
SELECT is(
  (SELECT inventory_status || ':' || available_quantity::text || ':' || inventory_version::text
   FROM pg_temp.p4_reservation_result),
  'released:6:6',
  'standard release returns the conserved availability and next inventory version'
);
TRUNCATE pg_temp.p4_reservation_result;
SET LOCAL ROLE rebuy_business_executor;
INSERT INTO pg_temp.p4_reservation_result
SELECT * FROM private.change_inventory_reservation_impl(
  (SELECT listing_id FROM pg_temp.p4_listing_result), 3, 'release', 5,
  'SYN-ORDER-STANDARD-01', '00000000-0000-4000-8000-000000005204'
);
RESET ROLE;
SELECT is(
  (SELECT inventory_status || ':' || available_quantity::text || ':' || inventory_version::text
   FROM pg_temp.p4_reservation_result),
  'released:6:6',
  'same-key standard release retry returns its original result without another mutation'
);
TRUNCATE pg_temp.p4_error_result;
SET LOCAL ROLE rebuy_business_executor;
DO $block$
BEGIN
  PERFORM * FROM private.change_inventory_reservation_impl(
    (SELECT listing_id FROM pg_temp.p4_listing_result), 7, 'reserve', 6,
    'SYN-ORDER-STANDARD-02', '00000000-0000-4000-8000-000000005203'
  );
EXCEPTION WHEN OTHERS THEN
  INSERT INTO pg_temp.p4_error_result (error_state, error_message)
  VALUES (SQLSTATE, SQLERRM);
END
$block$;
RESET ROLE;
SELECT is(
  (SELECT error_state || ':' || error_message FROM pg_temp.p4_error_result),
  'P0001:inventory_quantity_conflict',
  'reservation cannot oversell standard available inventory'
);

SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004105', 'p4-merchant@rebuy.test'
);
TRUNCATE pg_temp.p4_listing_result;
INSERT INTO pg_temp.p4_listing_result
SELECT * FROM public.upsert_catalog_listing(
  NULL, '00000000-0000-4000-8000-000000004501', 'secondhand',
  'secondhand', 'Synthetic Used Device', 'SYN-SKU-USED-01',
  'synthetic-used-device', 'Synthetic Used Device',
  'Synthetic unique used unit for P4 tests',
  15000, NULL, NULL, '[]'::jsonb,
  NULL, 'syn-unit-used-0001', 'good', 'cosmetic_wear', 88, 90,
  true, 0, '00000000-0000-4000-8000-000000005301'
);
SELECT is(
  (SELECT product_kind || ':' || available_quantity::text
   FROM public.list_public_catalog()
   WHERE listing_id = (SELECT listing_id FROM pg_temp.p4_listing_result)),
  'secondhand:1',
  'published secondhand listing exposes exactly one available unit'
);
SELECT throws_ok(
  $sql$
    SELECT * FROM public.upsert_catalog_listing(
      NULL, '00000000-0000-4000-8000-000000004501', 'secondhand',
      'secondhand', 'Duplicate Used Serial', 'SYN-SKU-USED-02',
      'duplicate-used-serial', 'Duplicate Used Serial',
      'Synthetic duplicate serial for bounded conflict',
      14000, NULL, NULL, '[]'::jsonb,
      NULL, 'SYN-UNIT-USED-0001', 'good', 'none', 90, 30,
      true, 0, '00000000-0000-4000-8000-000000005306'
    )
  $sql$,
  'P0001', 'catalog_unique_conflict',
  'duplicate secondhand serial maps to a bounded catalog error'
);
RESET ROLE;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004106', 'p4-retail@rebuy.test'
);
TRUNCATE pg_temp.p4_error_result;
SET LOCAL ROLE rebuy_business_executor;
DO $block$
BEGIN
  PERFORM * FROM private.change_inventory_reservation_impl(
    (SELECT listing_id FROM pg_temp.p4_listing_result), 2, 'reserve', 1,
    'SYN-ORDER-USED-01', '00000000-0000-4000-8000-000000005302'
  );
EXCEPTION WHEN OTHERS THEN
  INSERT INTO pg_temp.p4_error_result (error_state, error_message)
  VALUES (SQLSTATE, SQLERRM);
END
$block$;
RESET ROLE;
SELECT is(
  (SELECT error_state || ':' || error_message FROM pg_temp.p4_error_result),
  'P0001:secondhand_quantity_must_be_one',
  'secondhand reservation quantity must equal one'
);
TRUNCATE pg_temp.p4_reservation_result;
SET LOCAL ROLE rebuy_business_executor;
INSERT INTO pg_temp.p4_reservation_result
SELECT * FROM private.change_inventory_reservation_impl(
  (SELECT listing_id FROM pg_temp.p4_listing_result), 1, 'reserve', 1,
  'SYN-ORDER-USED-01', '00000000-0000-4000-8000-000000005303'
);
RESET ROLE;
SELECT is(
  (SELECT inventory_kind || ':' || inventory_status || ':' || available_quantity::text || ':' || inventory_version::text
   FROM pg_temp.p4_reservation_result),
  'secondhand:reserved:0:2',
  'secondhand unit changes from available to reserved exactly once'
);
SET LOCAL ROLE anon;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_catalog_quote(%L, 1)',
    (SELECT listing_id FROM pg_temp.p4_listing_result)
  ),
  'P0001', 'catalog_listing_not_available',
  'reserved secondhand unit is not publicly quotable by known listing id'
);
RESET ROLE;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004106', 'p4-retail@rebuy.test'
);
SET LOCAL ROLE rebuy_business_executor;
TRUNCATE pg_temp.p4_reservation_result;
INSERT INTO pg_temp.p4_reservation_result
SELECT * FROM private.change_inventory_reservation_impl(
  (SELECT listing_id FROM pg_temp.p4_listing_result), 1, 'sell', 2,
  'SYN-ORDER-USED-01', '00000000-0000-4000-8000-000000005304'
);
RESET ROLE;
SELECT is(
  (SELECT inventory_status || ':' || available_quantity::text || ':' || inventory_version::text
   FROM pg_temp.p4_reservation_result),
  'sold:0:3',
  'reserved secondhand unit can transition once to sold'
);
SET LOCAL ROLE anon;
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.get_catalog_quote(%L, 1)',
    (SELECT listing_id FROM pg_temp.p4_listing_result)
  ),
  'P0001', 'catalog_listing_not_available',
  'sold secondhand unit is not publicly quotable by known listing id'
);
RESET ROLE;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004106', 'p4-retail@rebuy.test'
);
TRUNCATE pg_temp.p4_error_result;
SET LOCAL ROLE rebuy_business_executor;
DO $block$
BEGIN
  PERFORM * FROM private.change_inventory_reservation_impl(
    (SELECT listing_id FROM pg_temp.p4_listing_result), 1, 'release', 3,
    'SYN-ORDER-USED-01', '00000000-0000-4000-8000-000000005305'
  );
EXCEPTION WHEN OTHERS THEN
  INSERT INTO pg_temp.p4_error_result (error_state, error_message)
  VALUES (SQLSTATE, SQLERRM);
END
$block$;
RESET ROLE;
SELECT is(
  (SELECT error_state || ':' || error_message FROM pg_temp.p4_error_result),
  'P0001:secondhand_state_conflict',
  'sold secondhand unit cannot return to available'
);

SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test'
);
SELECT is(
  (SELECT qualification_status || ':' || qualification_version::text
   FROM public.change_wholesale_qualification(
     (SELECT qualification_id FROM pg_temp.p4_review_result),
     'revoke', '00000000-0000-4000-8000-000000005009'
   )),
  'revoked:4',
  'assigned reviewer can irreversibly revoke the qualification'
);
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004101', 'p4-applicant@rebuy.test'
);
SELECT is(
  (SELECT audience FROM public.get_catalog_quote(
    (SELECT listing_id FROM pg_temp.p4_standard_listing_target), 10
  )),
  'retail',
  'revoked qualification immediately falls back to retail'
);
RESET ROLE;
UPDATE public.memberships SET status = 'suspended'
WHERE id = '00000000-0000-4000-8000-000000004802';
SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004103', 'p4-reviewer@rebuy.test'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM public.change_wholesale_qualification(%L, %L, %L)',
    (SELECT qualification_id FROM pg_temp.p4_review_result),
    'revoke', '00000000-0000-4000-8000-000000005009'
  ),
  'P0001', 'wholesale_review_forbidden',
  'old qualification retry revalidates current platform permission'
);
SELECT throws_ok(
  pg_catalog.format(
    'SELECT * FROM private.review_wholesale_application_impl(%L, %L, %L, pg_catalog.transaction_timestamp() + interval %L, %L)',
    (SELECT application_id FROM pg_temp.p4_review_result),
    'approve', 'approved_checks_complete', '365 days',
    '00000000-0000-4000-8000-000000005005'
  ),
  'P0001', 'wholesale_application_not_available',
  'old review retry revalidates the historical review actor membership'
);
RESET ROLE;
UPDATE public.memberships SET status = 'active'
WHERE id = '00000000-0000-4000-8000-000000004802';

SELECT is(
  (SELECT count(*)::integer FROM public.catalog_events),
  3,
  'successful catalog writes append exactly one event each'
);
SELECT is(
  (SELECT count(*)::integer FROM public.inventory_events),
  7,
  'successful inventory changes append exactly one event each'
);
SELECT is(
  (SELECT count(*)::integer FROM public.p4_idempotency_keys),
  27,
  'successful P4 writes share one actor-global idempotency registry'
);

SET LOCAL ROLE authenticated;
SELECT pg_temp.p4_set_claims(
  '00000000-0000-4000-8000-000000004105', 'p4-merchant@rebuy.test'
);
SELECT is(
  (SELECT count(*)::integer FROM public.list_public_catalog()
   WHERE listing_id = (SELECT listing_id FROM pg_temp.p4_standard_listing_target)),
  1,
  'P4 context reset probe sees the remaining standard catalog row'
);
SELECT is(
  pg_catalog.current_setting('rebuy.p4.authorized', true),
  'true',
  'a P4 RPC establishes only bounded transaction-local P4 context'
);
SELECT is(
  (SELECT count(*)::integer FROM public.get_my_merchant_application()),
  0,
  'P3 context reset probe has no merchant application for this user'
);
SELECT is(
  pg_catalog.current_setting('rebuy.p4.authorized', true),
  'false',
  'a subsequent P3 RPC clears stale P4 RLS context'
);
SELECT is(
  (SELECT count(*)::integer FROM public.list_public_catalog()
   WHERE listing_id = (SELECT listing_id FROM pg_temp.p4_standard_listing_target)),
  1,
  'P4 context reset probe remains minimal after the P3 call'
);
SELECT is(
  pg_catalog.current_setting('rebuy.business.authorized', true),
  'false',
  'a subsequent P4 RPC clears stale P3 RLS context'
);

RESET ROLE;
REVOKE rebuy_business_executor FROM postgres GRANTED BY CURRENT_USER;
SELECT ok(
  NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
  AND NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET'),
  'test-only reservation role membership is removed before rollback'
);

SELECT * FROM finish();
ROLLBACK;
