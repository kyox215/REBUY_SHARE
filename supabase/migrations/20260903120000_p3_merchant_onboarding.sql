-- P3 synthetic-only merchant onboarding and assigned platform review.

DO $executor_guard$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'rebuy_business_executor'
  ) OR EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_business_executor'
      AND (
        rolsuper OR rolcanlogin OR rolcreatedb OR rolcreaterole OR rolinherit
        OR rolreplication OR rolbypassrls
      )
  ) THEN
    RAISE EXCEPTION 'rebuy_business_executor_invalid';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_business_executor'
       OR member_role.rolname = 'rebuy_business_executor'
  ) <> 1 OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_business_executor'
      AND member_role.rolname = 'postgres'
      AND grantor_role.rolname = 'supabase_admin'
      AND pam.admin_option
      AND NOT pam.inherit_option
      AND NOT pam.set_option
  ) THEN
    RAISE EXCEPTION 'rebuy_business_executor_membership_invalid';
  END IF;
END
$executor_guard$;

REVOKE ALL ON SCHEMA public, private FROM rebuy_business_executor;
GRANT USAGE ON SCHEMA public, private TO rebuy_business_executor;

CREATE TABLE public.merchant_applications (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  applicant_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  display_name text NOT NULL,
  country_code text NOT NULL,
  requested_store_slug text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  assigned_reviewer_membership_id uuid REFERENCES public.memberships (id),
  assigned_at timestamptz,
  organization_id uuid REFERENCES public.organizations (id),
  store_id uuid REFERENCES public.stores (id),
  owner_membership_id uuid REFERENCES public.memberships (id),
  submitted_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT merchant_applications_id_applicant_key UNIQUE (id, applicant_user_id),
  CONSTRAINT merchant_applications_display_name_check CHECK (
    display_name = pg_catalog.btrim(display_name)
    AND pg_catalog.char_length(display_name) BETWEEN 2 AND 80
  ),
  CONSTRAINT merchant_applications_country_check CHECK (
    country_code ~ '^[A-Z]{2}$'
  ),
  CONSTRAINT merchant_applications_slug_check CHECK (
    requested_store_slug = pg_catalog.lower(requested_store_slug)
    AND requested_store_slug ~ '^[a-z0-9][a-z0-9-]{1,47}$'
  ),
  CONSTRAINT merchant_applications_status_check CHECK (
    status IN (
      'draft', 'submitted', 'under_review', 'needs_info', 'approved',
      'rejected', 'suspended', 'withdrawn'
    )
  ),
  CONSTRAINT merchant_applications_assignment_check CHECK (
    (
      status IN ('under_review', 'needs_info', 'approved', 'rejected', 'suspended')
      AND assigned_reviewer_membership_id IS NOT NULL
      AND assigned_at IS NOT NULL
    )
    OR (
      status IN ('draft', 'submitted', 'withdrawn')
      AND assigned_reviewer_membership_id IS NULL
      AND assigned_at IS NULL
    )
  ),
  CONSTRAINT merchant_applications_approval_refs_check CHECK (
    (
      status IN ('approved', 'suspended')
      AND organization_id IS NOT NULL
      AND store_id IS NOT NULL
      AND owner_membership_id IS NOT NULL
      AND decided_at IS NOT NULL
    )
    OR (
      status NOT IN ('approved', 'suspended')
      AND organization_id IS NULL
      AND store_id IS NULL
      AND owner_membership_id IS NULL
    )
  ),
  CONSTRAINT merchant_applications_submitted_check CHECK (
    (status = 'draft' AND submitted_at IS NULL)
    OR status = 'withdrawn'
    OR (status NOT IN ('draft', 'withdrawn') AND submitted_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX merchant_applications_one_open_per_applicant
  ON public.merchant_applications (applicant_user_id)
  WHERE status NOT IN ('rejected', 'withdrawn');
CREATE INDEX merchant_applications_queue_idx
  ON public.merchant_applications (status, created_at, id);
CREATE INDEX merchant_applications_reviewer_idx
  ON public.merchant_applications (assigned_reviewer_membership_id, status);
CREATE INDEX merchant_applications_organization_idx
  ON public.merchant_applications (organization_id);
CREATE INDEX merchant_applications_store_idx
  ON public.merchant_applications (store_id);
CREATE INDEX merchant_applications_owner_membership_idx
  ON public.merchant_applications (owner_membership_id);

CREATE TABLE public.merchant_application_private (
  application_id uuid PRIMARY KEY,
  applicant_user_id uuid NOT NULL,
  registration_reference text NOT NULL,
  evidence_reference text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT merchant_application_private_application_fk FOREIGN KEY (
    application_id, applicant_user_id
  ) REFERENCES public.merchant_applications (id, applicant_user_id) ON DELETE CASCADE,
  CONSTRAINT merchant_application_private_registration_check CHECK (
    registration_reference ~ '^SYN-[A-Z0-9-]{4,40}$'
  ),
  CONSTRAINT merchant_application_private_evidence_check CHECK (
    evidence_reference ~ '^synthetic://[a-z0-9][a-z0-9/_-]{2,120}$'
  )
);
CREATE INDEX merchant_application_private_applicant_idx
  ON public.merchant_application_private (applicant_user_id);
CREATE INDEX merchant_application_private_application_applicant_idx
  ON public.merchant_application_private (application_id, applicant_user_id);

CREATE TABLE public.merchant_application_events (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.merchant_applications (id) ON DELETE CASCADE,
  actor_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  event_code text NOT NULL,
  from_status text,
  to_status text NOT NULL,
  reason_code text,
  assigned_reviewer_membership_id uuid REFERENCES public.memberships (id),
  idempotency_key uuid NOT NULL,
  request_fingerprint text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT merchant_application_events_code_check CHECK (
    event_code IN (
      'merchant_application.saved',
      'merchant_application.submitted',
      'merchant_application.assigned',
      'merchant_application.needs_info',
      'merchant_application.approved',
      'merchant_application.rejected',
      'merchant_application.suspended',
      'merchant_application.withdrawn'
    )
  ),
  CONSTRAINT merchant_application_events_from_status_check CHECK (
    from_status IS NULL OR from_status IN (
      'draft', 'submitted', 'under_review', 'needs_info', 'approved',
      'rejected', 'suspended', 'withdrawn'
    )
  ),
  CONSTRAINT merchant_application_events_to_status_check CHECK (
    to_status IN (
      'draft', 'submitted', 'under_review', 'needs_info', 'approved',
      'rejected', 'suspended', 'withdrawn'
    )
  ),
  CONSTRAINT merchant_application_events_reason_check CHECK (
    reason_code IS NULL OR reason_code IN (
      'information_incomplete', 'eligibility_not_met', 'policy_violation',
      'approved_checks_complete', 'risk_suspension'
    )
  ),
  CONSTRAINT merchant_application_events_fingerprint_check CHECK (
    request_fingerprint ~ '^[0-9a-f]{32}$'
  ),
  CONSTRAINT merchant_application_events_idempotency_key UNIQUE (
    actor_user_id, idempotency_key
  )
);
CREATE INDEX merchant_application_events_actor_idx
  ON public.merchant_application_events (actor_user_id, created_at);
CREATE INDEX merchant_application_events_application_idx
  ON public.merchant_application_events (application_id, created_at);
CREATE INDEX merchant_application_events_reviewer_idx
  ON public.merchant_application_events (assigned_reviewer_membership_id);

ALTER TABLE public.merchant_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_applications FORCE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_application_private ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_application_private FORCE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_application_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_application_events FORCE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION private.rebuy_business_reset_context()
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $function$
BEGIN
  PERFORM pg_catalog.set_config('rebuy.business.authorized', 'false', true);
  PERFORM pg_catalog.set_config('rebuy.business.op', '', true);
  PERFORM pg_catalog.set_config('rebuy.business.application_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.business.applicant_user_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.business.target_membership_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.business.organization_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.business.store_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.business.owner_membership_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.business.scope_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.business.event_id', '', true);
END
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_business_require_identity(
  p_require_recent_otp boolean DEFAULT false
)
RETURNS TABLE (user_id uuid, email_normalized text)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_claims jsonb;
  v_amr jsonb;
  v_uid uuid;
  v_email text;
  v_otp_timestamp numeric;
  v_now_epoch numeric;
BEGIN
  v_claims := private.rebuy_request_jwt();
  v_uid := private.rebuy_request_uid();
  v_email := pg_catalog.lower(pg_catalog.btrim(v_claims ->> 'email'));

  IF v_uid IS NULL
     OR (v_claims -> 'is_anonymous') IS DISTINCT FROM 'false'::jsonb
     OR v_email IS NULL
     OR v_email !~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
  THEN
    RAISE EXCEPTION 'merchant_identity_required';
  END IF;

  IF p_require_recent_otp THEN
    IF pg_catalog.jsonb_typeof(v_claims -> 'amr') IS DISTINCT FROM 'array'
       OR pg_catalog.jsonb_array_length(v_claims -> 'amr') < 1
    THEN
      RAISE EXCEPTION 'merchant_recent_otp_required';
    END IF;
    v_amr := v_claims -> 'amr' -> 0;
    IF pg_catalog.jsonb_typeof(v_amr) IS DISTINCT FROM 'object'
       OR (v_amr ->> 'method') IS DISTINCT FROM 'otp'
       OR pg_catalog.jsonb_typeof(v_amr -> 'timestamp') IS DISTINCT FROM 'number'
    THEN
      RAISE EXCEPTION 'merchant_recent_otp_required';
    END IF;
    BEGIN
      v_otp_timestamp := (v_amr ->> 'timestamp')::numeric;
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'merchant_recent_otp_required';
    END;
    v_now_epoch := EXTRACT(epoch FROM pg_catalog.statement_timestamp())::numeric;
    IF v_otp_timestamp < v_now_epoch - 600
       OR v_otp_timestamp > v_now_epoch + 60
    THEN
      RAISE EXCEPTION 'merchant_recent_otp_required';
    END IF;
  END IF;

  RETURN QUERY SELECT v_uid, v_email;
END
$function$;

CREATE POLICY merchant_applications_business_select
  ON public.merchant_applications
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_business_executor
  USING (
    applicant_user_id = (SELECT private.rebuy_request_uid())
    OR (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND (
        id::text = (SELECT pg_catalog.current_setting('rebuy.business.application_id', true))
        OR (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'list_queue'
      )
    )
  );

CREATE POLICY merchant_applications_business_insert
  ON public.merchant_applications
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_business_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'save_application'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.application_id', true))
    AND applicant_user_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.applicant_user_id', true)
    )
    AND applicant_user_id = (SELECT private.rebuy_request_uid())
  );

CREATE POLICY merchant_applications_business_update
  ON public.merchant_applications
  AS PERMISSIVE
  FOR UPDATE
  TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.application_id', true))
  )
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.application_id', true))
  );

CREATE POLICY merchant_application_private_business_select
  ON public.merchant_application_private
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_business_executor
  USING (
    applicant_user_id = (SELECT private.rebuy_request_uid())
    OR (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND application_id::text = (
        SELECT pg_catalog.current_setting('rebuy.business.application_id', true)
      )
      AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) IN (
        'review_detail', 'review_application'
      )
    )
  );

CREATE POLICY merchant_application_private_business_insert
  ON public.merchant_application_private
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_business_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'save_application'
    AND application_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.application_id', true)
    )
    AND applicant_user_id = (SELECT private.rebuy_request_uid())
  );

CREATE POLICY merchant_application_private_business_update
  ON public.merchant_application_private
  AS PERMISSIVE
  FOR UPDATE
  TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'save_application'
    AND application_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.application_id', true)
    )
    AND applicant_user_id = (SELECT private.rebuy_request_uid())
  )
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND application_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.application_id', true)
    )
    AND applicant_user_id = (SELECT private.rebuy_request_uid())
  );

CREATE POLICY merchant_application_events_business_select
  ON public.merchant_application_events
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_business_executor
  USING (
    actor_user_id = (SELECT private.rebuy_request_uid())
    OR (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND application_id::text = (
        SELECT pg_catalog.current_setting('rebuy.business.application_id', true)
      )
    )
  );

CREATE POLICY merchant_application_events_business_insert
  ON public.merchant_application_events
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_business_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND application_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.application_id', true)
    )
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.event_id', true))
    AND actor_user_id = (SELECT private.rebuy_request_uid())
  );

-- Existing P2-L catalogs and organization tables stay FORCE RLS. These policies
-- give only the isolated business executor the rows required by the workflow.
CREATE POLICY memberships_business_select
  ON public.memberships
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_business_executor
  USING (
    user_id = (SELECT private.rebuy_request_uid())
    OR (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND id::text IN (
        (SELECT pg_catalog.current_setting('rebuy.business.target_membership_id', true)),
        (SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true))
      )
    )
  );

CREATE POLICY memberships_business_insert_owner
  ON public.memberships
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_business_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true)
    )
    AND user_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.applicant_user_id', true)
    )
    AND organization_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.organization_id', true)
    )
    AND organization_type = 'merchant'
    AND role_definition_id = '00000000-0000-4000-8000-000000000201'::uuid
    AND role_version = 1
    AND status = 'active'
  );

CREATE POLICY memberships_business_update_owner
  ON public.memberships
  AS PERMISSIVE
  FOR UPDATE
  TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true)
    )
  )
  WITH CHECK (
    id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true)
    )
    AND status = 'suspended'
  );

CREATE POLICY organizations_business_select
  ON public.organizations
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND id::text = (
        SELECT pg_catalog.current_setting('rebuy.business.organization_id', true)
      )
    )
    OR EXISTS (
      SELECT 1
      FROM public.memberships AS m
      WHERE m.organization_id = organizations.id
        AND m.organization_type = organizations.organization_type
        AND m.user_id = (SELECT private.rebuy_request_uid())
        AND m.status = 'active'
        AND m.valid_from <= pg_catalog.statement_timestamp()
        AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
    )
  );

CREATE POLICY stores_business_select
  ON public.stores
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.store_id', true))
  );

CREATE POLICY organizations_business_insert_merchant
  ON public.organizations
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_business_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.organization_id', true)
    )
    AND organization_type = 'merchant'
    AND created_by::text = (
      SELECT pg_catalog.current_setting('rebuy.business.applicant_user_id', true)
    )
    AND status = 'active'
  );

CREATE POLICY organizations_business_update_merchant
  ON public.organizations
  AS PERMISSIVE
  FOR UPDATE
  TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.organization_id', true)
    )
  )
  WITH CHECK (status = 'suspended');

CREATE POLICY stores_business_insert_merchant
  ON public.stores
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_business_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.store_id', true))
    AND organization_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.organization_id', true)
    )
    AND organization_type = 'merchant'
    AND status = 'active'
    AND public_visibility = false
  );

CREATE POLICY stores_business_update_merchant
  ON public.stores
  AS PERMISSIVE
  FOR UPDATE
  TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.store_id', true))
  )
  WITH CHECK (status = 'suspended' AND public_visibility = false);

CREATE POLICY membership_store_scopes_business_insert_owner
  ON public.membership_store_scopes
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_business_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.scope_id', true))
    AND membership_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true)
    )
    AND organization_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.organization_id', true)
    )
    AND organization_type = 'merchant'
    AND scope_type = 'organization'
    AND store_id IS NULL
    AND status = 'active'
  );

CREATE POLICY membership_store_scopes_business_select_owner
  ON public.membership_store_scopes
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND membership_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true)
    )
  );

CREATE POLICY membership_store_scopes_business_update_owner
  ON public.membership_store_scopes
  AS PERMISSIVE
  FOR UPDATE
  TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND membership_id::text = (
      SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true)
    )
  )
  WITH CHECK (status = 'suspended');

CREATE POLICY permissions_business_catalog_select
  ON public.permissions
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_business_executor
  USING (is_active);

CREATE POLICY role_permissions_business_catalog_select
  ON public.role_permissions
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_business_executor
  USING (is_granted);

CREATE POLICY role_definitions_business_catalog_select
  ON public.role_definitions
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_business_executor
  USING (status = 'active');

REVOKE ALL PRIVILEGES ON TABLE
  public.merchant_applications,
  public.merchant_application_private,
  public.merchant_application_events
FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;

GRANT SELECT, INSERT, UPDATE ON public.merchant_applications
  TO rebuy_business_executor;
GRANT SELECT, INSERT, UPDATE ON public.merchant_application_private
  TO rebuy_business_executor;
GRANT SELECT, INSERT ON public.merchant_application_events
  TO rebuy_business_executor;
GRANT SELECT (id, organization_type, status)
  ON public.organizations TO rebuy_business_executor;
GRANT INSERT (id, organization_type, display_name, legal_name, status, created_by,
  verified_at, created_at, updated_at)
  ON public.organizations TO rebuy_business_executor;
GRANT UPDATE (status, updated_at)
  ON public.organizations TO rebuy_business_executor;
GRANT INSERT (id, organization_id, organization_type, display_name, slug, status,
  public_visibility, created_at, updated_at)
  ON public.stores TO rebuy_business_executor;
GRANT SELECT (id, organization_id, organization_type, status, public_visibility)
  ON public.stores TO rebuy_business_executor;
GRANT UPDATE (status, public_visibility, updated_at)
  ON public.stores TO rebuy_business_executor;
GRANT SELECT (id, user_id, organization_id, organization_type, role_definition_id,
  role_version, role_definition_organization_id, role_definition_organization_type,
  status, valid_from, valid_until)
  ON public.memberships TO rebuy_business_executor;
GRANT INSERT (id, user_id, organization_id, organization_type, role_definition_id,
  role_version, role_definition_organization_id, role_definition_organization_type,
  status, invited_by, valid_from, created_at, updated_at)
  ON public.memberships TO rebuy_business_executor;
GRANT UPDATE (status, updated_at)
  ON public.memberships TO rebuy_business_executor;
GRANT INSERT (id, membership_id, organization_id, organization_type, store_id,
  scope_type, status, created_at)
  ON public.membership_store_scopes TO rebuy_business_executor;
GRANT SELECT (id, membership_id, organization_id, organization_type, store_id,
  scope_type, status)
  ON public.membership_store_scopes TO rebuy_business_executor;
GRANT UPDATE (status)
  ON public.membership_store_scopes TO rebuy_business_executor;
GRANT SELECT (
  id, organization_id, organization_type, role_key, version, scope_type,
  applicable_organization_type, is_system, status, assignable
)
  ON public.role_definitions TO rebuy_business_executor;
GRANT SELECT (id, permission_key, is_active)
  ON public.permissions TO rebuy_business_executor;
GRANT SELECT (role_definition_id, role_version, permission_id, is_granted)
  ON public.role_permissions TO rebuy_business_executor;

GRANT EXECUTE ON FUNCTION private.rebuy_request_jwt()
  TO rebuy_business_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_request_uid()
  TO rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.rebuy_business_reset_context()
  FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.rebuy_business_require_identity(boolean)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_business_reset_context()
  TO rebuy_business_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_business_require_identity(boolean)
  TO rebuy_business_executor;

CREATE OR REPLACE FUNCTION private.rebuy_business_membership_has_permission(
  p_membership_id uuid,
  p_user_id uuid,
  p_permission_key text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships AS m
    JOIN public.organizations AS o
      ON o.id = m.organization_id
     AND o.organization_type = m.organization_type
    JOIN public.role_permissions AS rp
      ON rp.role_definition_id = m.role_definition_id
     AND rp.role_version = m.role_version
     AND rp.is_granted
    JOIN public.role_definitions AS rd
      ON rd.id = m.role_definition_id
     AND rd.version = m.role_version
     AND rd.status = 'active'
     AND rd.scope_type = 'platform'
     AND rd.applicable_organization_type = 'platform'
    JOIN public.permissions AS p
      ON p.id = rp.permission_id
     AND p.is_active
    WHERE m.id = p_membership_id
      AND m.user_id = p_user_id
      AND m.organization_type = 'platform'
      AND m.status = 'active'
      AND m.valid_from <= pg_catalog.statement_timestamp()
      AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
      AND o.status = 'active'
      AND p.permission_key = p_permission_key
  )
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_business_find_platform_membership(
  p_permission_key text
)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT m.id
  FROM public.memberships AS m
  JOIN public.organizations AS o
    ON o.id = m.organization_id
   AND o.organization_type = m.organization_type
  JOIN public.role_permissions AS rp
    ON rp.role_definition_id = m.role_definition_id
   AND rp.role_version = m.role_version
   AND rp.is_granted
  JOIN public.role_definitions AS rd
    ON rd.id = m.role_definition_id
   AND rd.version = m.role_version
   AND rd.status = 'active'
   AND rd.scope_type = 'platform'
   AND rd.applicable_organization_type = 'platform'
  JOIN public.permissions AS p
    ON p.id = rp.permission_id
   AND p.is_active
  WHERE m.user_id = (SELECT private.rebuy_request_uid())
    AND m.organization_type = 'platform'
    AND m.status = 'active'
    AND m.valid_from <= pg_catalog.statement_timestamp()
    AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
    AND o.status = 'active'
    AND p.permission_key = p_permission_key
  ORDER BY m.id
  LIMIT 1
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION private.rebuy_business_membership_has_permission(
  uuid, uuid, text
) FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.rebuy_business_find_platform_membership(text)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_business_membership_has_permission(
  uuid, uuid, text
) TO rebuy_business_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_business_find_platform_membership(text)
  TO rebuy_business_executor;

CREATE OR REPLACE FUNCTION private.save_merchant_application_impl(
  p_display_name text,
  p_country_code text,
  p_requested_store_slug text,
  p_registration_reference text,
  p_evidence_reference text,
  p_submit boolean,
  p_idempotency_key uuid
)
RETURNS TABLE (application_id uuid, application_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid;
  v_display_name text := pg_catalog.btrim(p_display_name);
  v_country_code text := pg_catalog.upper(pg_catalog.btrim(p_country_code));
  v_slug text := pg_catalog.lower(pg_catalog.btrim(p_requested_store_slug));
  v_registration text := pg_catalog.upper(pg_catalog.btrim(p_registration_reference));
  v_evidence text := pg_catalog.lower(pg_catalog.btrim(p_evidence_reference));
  v_application public.merchant_applications%ROWTYPE;
  v_locked_application_id uuid;
  v_event public.merchant_application_events%ROWTYPE;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_target_status text;
  v_event_code text;
  v_fingerprint text;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_business_reset_context();
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(true) AS i;
  IF p_idempotency_key IS NULL OR p_submit IS NULL
     OR v_display_name IS NULL OR v_display_name !~ '^.{2,80}$'
     OR v_country_code IS NULL OR v_country_code !~ '^[A-Z]{2}$'
     OR v_slug IS NULL OR v_slug !~ '^[a-z0-9][a-z0-9-]{1,47}$'
     OR v_registration IS NULL OR v_registration !~ '^SYN-[A-Z0-9-]{4,40}$'
     OR v_evidence IS NULL
     OR v_evidence !~ '^synthetic://[a-z0-9][a-z0-9/_-]{2,120}$'
  THEN
    RAISE EXCEPTION 'merchant_application_invalid';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_uid::text || ':' || p_idempotency_key::text || ':merchant-idempotency',
      0
    )
  );
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_uid::text || ':merchant-application', 0)
  );
  PERFORM pg_catalog.set_config('rebuy.business.op', 'save_application', true);
  PERFORM pg_catalog.set_config('rebuy.business.applicant_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.business.authorized', 'true', true);

  v_event_code := CASE
    WHEN p_submit THEN 'merchant_application.submitted'
    ELSE 'merchant_application.saved'
  END;
  v_fingerprint := pg_catalog.md5(
    pg_catalog.concat_ws('|', v_display_name, v_country_code, v_slug,
      v_registration, v_evidence, p_submit::text)
  );
  SELECT e.* INTO v_event
  FROM public.merchant_application_events AS e
  WHERE e.actor_user_id = v_uid
    AND e.idempotency_key = p_idempotency_key;
  IF v_event.id IS NOT NULL THEN
    IF v_event.event_code IS DISTINCT FROM v_event_code
       OR v_event.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN
      RAISE EXCEPTION 'merchant_idempotency_conflict';
    END IF;
    RETURN QUERY SELECT v_event.application_id, v_event.to_status;
    RETURN;
  END IF;

  SELECT a.* INTO v_application
  FROM public.merchant_applications AS a
  WHERE a.applicant_user_id = v_uid
    AND a.status NOT IN ('rejected', 'withdrawn');

  IF v_application.id IS NOT NULL THEN
    v_locked_application_id := v_application.id;
    PERFORM pg_catalog.set_config(
      'rebuy.business.application_id', v_locked_application_id::text, true
    );
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_locked_application_id::text, 0)
    );
    SELECT a.* INTO v_application
    FROM public.merchant_applications AS a
    WHERE a.id = v_locked_application_id
      AND a.applicant_user_id = v_uid
    FOR UPDATE;
  END IF;

  v_target_status := CASE
    WHEN p_submit THEN 'submitted'
    WHEN v_application.status = 'needs_info' THEN 'needs_info'
    ELSE 'draft'
  END;

  IF v_application.id IS NOT NULL THEN
    IF p_submit AND v_application.status NOT IN ('draft', 'needs_info') THEN
      RAISE EXCEPTION 'merchant_application_state_conflict';
    ELSIF NOT p_submit AND v_application.status NOT IN ('draft', 'needs_info') THEN
      RAISE EXCEPTION 'merchant_application_state_conflict';
    END IF;
  ELSE
    v_application.id := pg_catalog.gen_random_uuid();
    v_application.status := 'draft';
    PERFORM pg_catalog.set_config(
      'rebuy.business.application_id', v_application.id::text, true
    );
    INSERT INTO public.merchant_applications (
      id, applicant_user_id, display_name, country_code, requested_store_slug,
      status, submitted_at, created_at, updated_at
    ) VALUES (
      v_application.id, v_uid, v_display_name, v_country_code, v_slug,
      v_target_status, CASE WHEN p_submit THEN v_now ELSE NULL END, v_now, v_now
    );
    INSERT INTO public.merchant_application_private (
      application_id, applicant_user_id, registration_reference,
      evidence_reference, created_at, updated_at
    ) VALUES (
      v_application.id, v_uid, v_registration, v_evidence, v_now, v_now
    );
  END IF;

  IF v_application.applicant_user_id IS NOT NULL THEN
    UPDATE public.merchant_applications
    SET display_name = v_display_name,
        country_code = v_country_code,
        requested_store_slug = v_slug,
        status = v_target_status,
        assigned_reviewer_membership_id = CASE
          WHEN p_submit AND v_application.status = 'needs_info' THEN NULL
          ELSE assigned_reviewer_membership_id
        END,
        assigned_at = CASE
          WHEN p_submit AND v_application.status = 'needs_info' THEN NULL
          ELSE assigned_at
        END,
        submitted_at = CASE
          WHEN p_submit THEN COALESCE(submitted_at, v_now)
          ELSE submitted_at
        END,
        updated_at = v_now
    WHERE id = v_application.id;
    UPDATE public.merchant_application_private AS ap
    SET registration_reference = v_registration,
        evidence_reference = v_evidence,
        updated_at = v_now
    WHERE ap.application_id = v_application.id;
  END IF;

  PERFORM pg_catalog.set_config('rebuy.business.event_id', v_event_id::text, true);
  INSERT INTO public.merchant_application_events (
    id, application_id, actor_user_id, event_code, from_status, to_status,
    idempotency_key, request_fingerprint, created_at
  ) VALUES (
    v_event_id, v_application.id, v_uid, v_event_code,
    CASE WHEN v_application.applicant_user_id IS NULL THEN NULL ELSE v_application.status END,
    v_target_status, p_idempotency_key, v_fingerprint, v_now
  );
  RETURN QUERY SELECT v_application.id, v_target_status;
END
$function$;

CREATE OR REPLACE FUNCTION private.get_my_merchant_application_impl()
RETURNS TABLE (
  application_id uuid,
  display_name text,
  country_code text,
  requested_store_slug text,
  application_status text,
  registration_reference text,
  evidence_reference text,
  organization_id uuid,
  store_id uuid,
  owner_membership_id uuid,
  updated_at timestamptz
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_uid uuid;
BEGIN
  PERFORM private.rebuy_business_reset_context();
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(false) AS i;
  RETURN QUERY
  SELECT a.id, a.display_name, a.country_code, a.requested_store_slug,
    a.status, ap.registration_reference, ap.evidence_reference,
    a.organization_id, a.store_id, a.owner_membership_id, a.updated_at
  FROM public.merchant_applications AS a
  JOIN public.merchant_application_private AS ap ON ap.application_id = a.id
  WHERE a.applicant_user_id = v_uid
  ORDER BY (a.status NOT IN ('rejected', 'withdrawn')) DESC, a.updated_at DESC
  LIMIT 1;
END
$function$;

CREATE OR REPLACE FUNCTION private.list_merchant_review_queue_impl()
RETURNS TABLE (
  application_id uuid,
  display_name text,
  country_code text,
  requested_store_slug text,
  application_status text,
  assigned_reviewer_membership_id uuid,
  submitted_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_membership_id uuid;
BEGIN
  PERFORM private.rebuy_business_reset_context();
  PERFORM i.user_id
  FROM private.rebuy_business_require_identity(false) AS i;
  v_membership_id := private.rebuy_business_find_platform_membership(
    'merchant_application.assign'
  );
  IF v_membership_id IS NULL THEN
    RAISE EXCEPTION 'merchant_review_forbidden';
  END IF;
  PERFORM pg_catalog.set_config('rebuy.business.op', 'list_queue', true);
  PERFORM pg_catalog.set_config('rebuy.business.authorized', 'true', true);
  RETURN QUERY
  SELECT a.id, a.display_name, a.country_code, a.requested_store_slug,
    a.status, a.assigned_reviewer_membership_id, a.submitted_at, a.updated_at
  FROM public.merchant_applications AS a
  WHERE a.status IN ('submitted', 'under_review', 'needs_info')
  ORDER BY a.submitted_at, a.id;
END
$function$;

CREATE OR REPLACE FUNCTION private.get_assigned_merchant_application_impl(
  p_application_id uuid
)
RETURNS TABLE (
  application_id uuid,
  applicant_user_id uuid,
  display_name text,
  country_code text,
  requested_store_slug text,
  application_status text,
  registration_reference text,
  evidence_reference text,
  submitted_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid;
  v_application public.merchant_applications%ROWTYPE;
BEGIN
  PERFORM private.rebuy_business_reset_context();
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(false) AS i;
  IF p_application_id IS NULL THEN
    RAISE EXCEPTION 'merchant_application_not_available';
  END IF;
  PERFORM pg_catalog.set_config('rebuy.business.op', 'review_detail', true);
  PERFORM pg_catalog.set_config(
    'rebuy.business.application_id', p_application_id::text, true
  );
  PERFORM pg_catalog.set_config('rebuy.business.authorized', 'true', true);
  SELECT a.* INTO v_application
  FROM public.merchant_applications AS a
  WHERE a.id = p_application_id;
  IF v_application.id IS NULL
     OR v_application.assigned_reviewer_membership_id IS NULL
     OR NOT private.rebuy_business_membership_has_permission(
       v_application.assigned_reviewer_membership_id,
       v_uid,
       'merchant_application.read_assigned'
     )
     OR NOT private.rebuy_business_membership_has_permission(
       v_application.assigned_reviewer_membership_id,
       v_uid,
       'merchant_application.review'
     )
  THEN
    RAISE EXCEPTION 'merchant_application_not_available';
  END IF;
  RETURN QUERY
  SELECT a.id, a.applicant_user_id, a.display_name, a.country_code,
    a.requested_store_slug, a.status, ap.registration_reference,
    ap.evidence_reference, a.submitted_at, a.updated_at
  FROM public.merchant_applications AS a
  JOIN public.merchant_application_private AS ap ON ap.application_id = a.id
  WHERE a.id = p_application_id;
END
$function$;

CREATE OR REPLACE FUNCTION private.assign_merchant_application_impl(
  p_application_id uuid,
  p_reviewer_membership_id uuid,
  p_idempotency_key uuid
)
RETURNS TABLE (
  application_id uuid,
  application_status text,
  reviewer_membership_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid;
  v_admin_membership_id uuid;
  v_application public.merchant_applications%ROWTYPE;
  v_target_user_id uuid;
  v_event public.merchant_application_events%ROWTYPE;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_fingerprint text;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_business_reset_context();
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(true) AS i;
  IF p_application_id IS NULL OR p_reviewer_membership_id IS NULL
     OR p_idempotency_key IS NULL
  THEN
    RAISE EXCEPTION 'merchant_assignment_invalid';
  END IF;
  v_admin_membership_id := private.rebuy_business_find_platform_membership(
    'merchant_application.assign'
  );
  IF v_admin_membership_id IS NULL THEN
    RAISE EXCEPTION 'merchant_review_forbidden';
  END IF;
  v_fingerprint := pg_catalog.md5(p_reviewer_membership_id::text);
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_uid::text || ':' || p_idempotency_key::text || ':merchant-idempotency',
      0
    )
  );
  PERFORM pg_catalog.set_config('rebuy.business.op', 'assign_application', true);
  PERFORM pg_catalog.set_config(
    'rebuy.business.application_id', p_application_id::text, true
  );
  PERFORM pg_catalog.set_config(
    'rebuy.business.target_membership_id', p_reviewer_membership_id::text, true
  );
  PERFORM pg_catalog.set_config('rebuy.business.authorized', 'true', true);
  SELECT e.* INTO v_event
  FROM public.merchant_application_events AS e
  WHERE e.actor_user_id = v_uid
    AND e.idempotency_key = p_idempotency_key;
  IF v_event.id IS NOT NULL THEN
    IF v_event.application_id IS DISTINCT FROM p_application_id
       OR v_event.event_code IS DISTINCT FROM 'merchant_application.assigned'
       OR v_event.request_fingerprint IS DISTINCT FROM v_fingerprint
       OR v_event.assigned_reviewer_membership_id IS DISTINCT FROM p_reviewer_membership_id
    THEN
      RAISE EXCEPTION 'merchant_idempotency_conflict';
    END IF;
    RETURN QUERY SELECT v_event.application_id, v_event.to_status,
      v_event.assigned_reviewer_membership_id;
    RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_application_id::text, 0)
  );
  SELECT a.* INTO v_application
  FROM public.merchant_applications AS a
  WHERE a.id = p_application_id
  FOR UPDATE;
  IF v_application.id IS NULL THEN
    RAISE EXCEPTION 'merchant_application_not_available';
  END IF;
  IF v_application.status <> 'submitted' THEN
    RAISE EXCEPTION 'merchant_application_state_conflict';
  END IF;
  SELECT m.user_id INTO v_target_user_id
  FROM public.memberships AS m
  WHERE m.id = p_reviewer_membership_id
    AND m.organization_type = 'platform'
    AND m.status = 'active'
    AND m.valid_from <= v_now
    AND (m.valid_until IS NULL OR m.valid_until > v_now);
  IF v_target_user_id IS NULL
     OR v_target_user_id = v_application.applicant_user_id
     OR NOT private.rebuy_business_membership_has_permission(
       p_reviewer_membership_id, v_target_user_id,
       'merchant_application.read_assigned'
     )
     OR NOT private.rebuy_business_membership_has_permission(
       p_reviewer_membership_id, v_target_user_id,
       'merchant_application.review'
     )
  THEN
    RAISE EXCEPTION 'merchant_reviewer_not_available';
  END IF;
  UPDATE public.merchant_applications
  SET status = 'under_review',
      assigned_reviewer_membership_id = p_reviewer_membership_id,
      assigned_at = v_now,
      updated_at = v_now
  WHERE id = p_application_id;
  PERFORM pg_catalog.set_config('rebuy.business.event_id', v_event_id::text, true);
  INSERT INTO public.merchant_application_events (
    id, application_id, actor_user_id, event_code, from_status, to_status,
    assigned_reviewer_membership_id, idempotency_key, request_fingerprint,
    created_at
  ) VALUES (
    v_event_id, p_application_id, v_uid, 'merchant_application.assigned',
    'submitted', 'under_review', p_reviewer_membership_id,
    p_idempotency_key, v_fingerprint, v_now
  );
  RETURN QUERY SELECT p_application_id, 'under_review'::text,
    p_reviewer_membership_id;
END
$function$;

CREATE OR REPLACE FUNCTION private.review_merchant_application_impl(
  p_application_id uuid,
  p_action text,
  p_reason_code text,
  p_idempotency_key uuid
)
RETURNS TABLE (
  application_id uuid,
  application_status text,
  organization_id uuid,
  store_id uuid,
  owner_membership_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid;
  v_application public.merchant_applications%ROWTYPE;
  v_event public.merchant_application_events%ROWTYPE;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_org_id uuid;
  v_store_id uuid;
  v_owner_membership_id uuid;
  v_scope_id uuid;
  v_target_status text;
  v_event_code text;
  v_fingerprint text;
  v_now timestamptz := pg_catalog.statement_timestamp();
  v_owner_role_valid boolean;
BEGIN
  PERFORM private.rebuy_business_reset_context();
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(true) AS i;
  IF p_application_id IS NULL OR p_idempotency_key IS NULL
     OR p_action IS NULL OR p_reason_code IS NULL
     OR p_action NOT IN ('needs_info', 'approve', 'reject', 'suspend')
  THEN
    RAISE EXCEPTION 'merchant_review_invalid';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_uid::text || ':' || p_idempotency_key::text || ':merchant-idempotency',
      0
    )
  );
  PERFORM pg_catalog.set_config('rebuy.business.op', 'review_application', true);
  PERFORM pg_catalog.set_config(
    'rebuy.business.application_id', p_application_id::text, true
  );
  PERFORM pg_catalog.set_config('rebuy.business.authorized', 'true', true);
  v_target_status := CASE p_action
    WHEN 'needs_info' THEN 'needs_info'
    WHEN 'approve' THEN 'approved'
    WHEN 'reject' THEN 'rejected'
    WHEN 'suspend' THEN 'suspended'
  END;
  v_event_code := 'merchant_application.' || v_target_status;
  IF (p_action = 'needs_info' AND p_reason_code <> 'information_incomplete')
     OR (p_action = 'approve' AND p_reason_code <> 'approved_checks_complete')
     OR (p_action = 'reject' AND p_reason_code NOT IN (
       'eligibility_not_met', 'policy_violation'
     ))
     OR (p_action = 'suspend' AND p_reason_code <> 'risk_suspension')
  THEN
    RAISE EXCEPTION 'merchant_review_reason_invalid';
  END IF;
  v_fingerprint := pg_catalog.md5(p_action || '|' || p_reason_code);
  SELECT e.* INTO v_event
  FROM public.merchant_application_events AS e
  WHERE e.actor_user_id = v_uid
    AND e.idempotency_key = p_idempotency_key;
  IF v_event.id IS NOT NULL THEN
    IF v_event.application_id IS DISTINCT FROM p_application_id
       OR v_event.event_code IS DISTINCT FROM v_event_code
       OR v_event.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN
      RAISE EXCEPTION 'merchant_idempotency_conflict';
    END IF;
    SELECT a.* INTO v_application
    FROM public.merchant_applications AS a
    WHERE a.id = v_event.application_id;
    IF v_application.id IS NULL
       OR v_event.assigned_reviewer_membership_id IS NULL
       OR NOT private.rebuy_business_membership_has_permission(
         v_event.assigned_reviewer_membership_id,
         v_uid,
         'merchant_application.review'
       )
       OR NOT private.rebuy_business_membership_has_permission(
         v_event.assigned_reviewer_membership_id,
         v_uid,
         'merchant_application.read_assigned'
       )
       OR v_uid = v_application.applicant_user_id
    THEN
      RAISE EXCEPTION 'merchant_application_not_available';
    END IF;
    RETURN QUERY SELECT v_event.application_id, v_event.to_status,
      CASE WHEN v_event.to_status IN ('approved', 'suspended')
        THEN v_application.organization_id ELSE NULL END,
      CASE WHEN v_event.to_status IN ('approved', 'suspended')
        THEN v_application.store_id ELSE NULL END,
      CASE WHEN v_event.to_status IN ('approved', 'suspended')
        THEN v_application.owner_membership_id ELSE NULL END;
    RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_application_id::text, 0)
  );
  SELECT a.* INTO v_application
  FROM public.merchant_applications AS a
  WHERE a.id = p_application_id
  FOR UPDATE;
  IF v_application.id IS NULL
     OR v_application.assigned_reviewer_membership_id IS NULL
     OR NOT private.rebuy_business_membership_has_permission(
       v_application.assigned_reviewer_membership_id,
       v_uid,
       'merchant_application.review'
     )
     OR NOT private.rebuy_business_membership_has_permission(
       v_application.assigned_reviewer_membership_id,
       v_uid,
       'merchant_application.read_assigned'
     )
     OR v_uid = v_application.applicant_user_id
  THEN
    RAISE EXCEPTION 'merchant_application_not_available';
  END IF;
  IF p_action = 'suspend' THEN
    IF v_application.status <> 'approved' THEN
      RAISE EXCEPTION 'merchant_application_state_conflict';
    END IF;
    v_org_id := v_application.organization_id;
    v_store_id := v_application.store_id;
    v_owner_membership_id := v_application.owner_membership_id;
    PERFORM pg_catalog.set_config('rebuy.business.organization_id', v_org_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.business.store_id', v_store_id::text, true);
    PERFORM pg_catalog.set_config(
      'rebuy.business.owner_membership_id', v_owner_membership_id::text, true
    );
    UPDATE public.organizations SET status = 'suspended', updated_at = v_now
      WHERE id = v_org_id;
    UPDATE public.stores
      SET status = 'suspended', public_visibility = false, updated_at = v_now
      WHERE id = v_store_id;
    UPDATE public.memberships SET status = 'suspended', updated_at = v_now
      WHERE id = v_owner_membership_id;
    UPDATE public.membership_store_scopes SET status = 'suspended'
      WHERE membership_id = v_owner_membership_id;
  ELSE
    IF v_application.status <> 'under_review' THEN
      RAISE EXCEPTION 'merchant_application_state_conflict';
    END IF;
    IF p_action = 'approve' THEN
      SELECT EXISTS (
        SELECT 1 FROM public.role_definitions AS rd
        WHERE rd.id = '00000000-0000-4000-8000-000000000201'::uuid
          AND rd.version = 1
          AND rd.role_key = 'owner'
          AND rd.scope_type = 'organization'
          AND rd.is_system
          AND rd.organization_id IS NULL
          AND rd.organization_type IS NULL
          AND rd.status = 'active'
          AND rd.assignable
          AND rd.applicable_organization_type IN ('any', 'merchant')
      ) INTO v_owner_role_valid;
      IF NOT COALESCE(v_owner_role_valid, false) THEN
        RAISE EXCEPTION 'merchant_owner_role_unavailable';
      END IF;
      v_org_id := pg_catalog.gen_random_uuid();
      v_store_id := pg_catalog.gen_random_uuid();
      v_owner_membership_id := pg_catalog.gen_random_uuid();
      v_scope_id := pg_catalog.gen_random_uuid();
      PERFORM pg_catalog.set_config(
        'rebuy.business.applicant_user_id', v_application.applicant_user_id::text, true
      );
      PERFORM pg_catalog.set_config('rebuy.business.organization_id', v_org_id::text, true);
      PERFORM pg_catalog.set_config('rebuy.business.store_id', v_store_id::text, true);
      PERFORM pg_catalog.set_config(
        'rebuy.business.owner_membership_id', v_owner_membership_id::text, true
      );
      PERFORM pg_catalog.set_config('rebuy.business.scope_id', v_scope_id::text, true);
      INSERT INTO public.organizations (
        id, organization_type, display_name, legal_name, status, created_by,
        verified_at, created_at, updated_at
      ) VALUES (
        v_org_id, 'merchant', v_application.display_name, NULL, 'active',
        v_application.applicant_user_id, v_now, v_now, v_now
      );
      INSERT INTO public.stores (
        id, organization_id, organization_type, display_name, slug, status,
        public_visibility, created_at, updated_at
      ) VALUES (
        v_store_id, v_org_id, 'merchant', v_application.display_name,
        v_application.requested_store_slug, 'active', false, v_now, v_now
      );
      INSERT INTO public.memberships (
        id, user_id, organization_id, organization_type, role_definition_id,
        role_version, role_definition_organization_id,
        role_definition_organization_type, status, invited_by, valid_from,
        created_at, updated_at
      ) VALUES (
        v_owner_membership_id, v_application.applicant_user_id, v_org_id,
        'merchant', '00000000-0000-4000-8000-000000000201'::uuid, 1,
        NULL, NULL, 'active', v_uid, v_now, v_now, v_now
      );
      INSERT INTO public.membership_store_scopes (
        id, membership_id, organization_id, organization_type, store_id,
        scope_type, status, created_at
      ) VALUES (
        v_scope_id, v_owner_membership_id, v_org_id, 'merchant', NULL,
        'organization', 'active', v_now
      );
    END IF;
  END IF;
  UPDATE public.merchant_applications
  SET status = v_target_status,
      organization_id = CASE WHEN p_action IN ('approve', 'suspend') THEN v_org_id ELSE NULL END,
      store_id = CASE WHEN p_action IN ('approve', 'suspend') THEN v_store_id ELSE NULL END,
      owner_membership_id = CASE
        WHEN p_action IN ('approve', 'suspend') THEN v_owner_membership_id ELSE NULL
      END,
      decided_at = CASE WHEN p_action IN ('approve', 'reject') THEN v_now ELSE decided_at END,
      updated_at = v_now
  WHERE id = p_application_id;
  PERFORM pg_catalog.set_config('rebuy.business.event_id', v_event_id::text, true);
  INSERT INTO public.merchant_application_events (
    id, application_id, actor_user_id, event_code, from_status, to_status,
    reason_code, assigned_reviewer_membership_id, idempotency_key,
    request_fingerprint, created_at
  ) VALUES (
    v_event_id, p_application_id, v_uid, v_event_code, v_application.status,
    v_target_status, p_reason_code, v_application.assigned_reviewer_membership_id,
    p_idempotency_key, v_fingerprint, v_now
  );
  RETURN QUERY SELECT p_application_id, v_target_status, v_org_id,
    v_store_id, v_owner_membership_id;
END
$function$;

CREATE OR REPLACE FUNCTION private.withdraw_merchant_application_impl(
  p_application_id uuid,
  p_idempotency_key uuid
)
RETURNS TABLE (application_id uuid, application_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid;
  v_application public.merchant_applications%ROWTYPE;
  v_event public.merchant_application_events%ROWTYPE;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_fingerprint text;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_business_reset_context();
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(true) AS i;
  IF p_application_id IS NULL OR p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'merchant_withdraw_invalid';
  END IF;
  PERFORM pg_catalog.set_config('rebuy.business.op', 'withdraw_application', true);
  PERFORM pg_catalog.set_config(
    'rebuy.business.application_id', p_application_id::text, true
  );
  PERFORM pg_catalog.set_config('rebuy.business.authorized', 'true', true);
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_uid::text || ':' || p_idempotency_key::text || ':merchant-idempotency',
      0
    )
  );
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_uid::text || ':merchant-application', 0)
  );
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_application_id::text, 0)
  );
  SELECT a.* INTO v_application
  FROM public.merchant_applications AS a
  WHERE a.id = p_application_id
    AND a.applicant_user_id = v_uid
  FOR UPDATE;
  IF v_application.id IS NULL THEN
    RAISE EXCEPTION 'merchant_application_not_available';
  END IF;
  v_fingerprint := pg_catalog.md5('withdraw');
  SELECT e.* INTO v_event
  FROM public.merchant_application_events AS e
  WHERE e.actor_user_id = v_uid
    AND e.idempotency_key = p_idempotency_key;
  IF v_event.id IS NOT NULL THEN
    IF v_event.application_id IS DISTINCT FROM p_application_id
       OR v_event.event_code IS DISTINCT FROM 'merchant_application.withdrawn'
       OR v_event.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN
      RAISE EXCEPTION 'merchant_idempotency_conflict';
    END IF;
    RETURN QUERY SELECT v_event.application_id, v_event.to_status;
    RETURN;
  END IF;
  IF v_application.status NOT IN ('draft', 'submitted', 'needs_info') THEN
    RAISE EXCEPTION 'merchant_application_state_conflict';
  END IF;
  UPDATE public.merchant_applications
  SET status = 'withdrawn',
      assigned_reviewer_membership_id = NULL,
      assigned_at = NULL,
      updated_at = v_now
  WHERE id = p_application_id;
  PERFORM pg_catalog.set_config('rebuy.business.event_id', v_event_id::text, true);
  INSERT INTO public.merchant_application_events (
    id, application_id, actor_user_id, event_code, from_status, to_status,
    idempotency_key, request_fingerprint, created_at
  ) VALUES (
    v_event_id, p_application_id, v_uid, 'merchant_application.withdrawn',
    v_application.status, 'withdrawn', p_idempotency_key, v_fingerprint, v_now
  );
  RETURN QUERY SELECT p_application_id, 'withdrawn'::text;
END
$function$;

CREATE OR REPLACE FUNCTION public.save_merchant_application(
  p_display_name text,
  p_country_code text,
  p_requested_store_slug text,
  p_registration_reference text,
  p_evidence_reference text,
  p_submit boolean,
  p_idempotency_key uuid
)
RETURNS TABLE (application_id uuid, application_status text)
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT * FROM private.save_merchant_application_impl(
    p_display_name, p_country_code, p_requested_store_slug,
    p_registration_reference, p_evidence_reference, p_submit,
    p_idempotency_key
  )
$function$;

CREATE OR REPLACE FUNCTION public.get_my_merchant_application()
RETURNS TABLE (
  application_id uuid, display_name text, country_code text,
  requested_store_slug text, application_status text,
  registration_reference text, evidence_reference text,
  organization_id uuid, store_id uuid, owner_membership_id uuid,
  updated_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_my_merchant_application_impl() $function$;

CREATE OR REPLACE FUNCTION public.list_merchant_review_queue()
RETURNS TABLE (
  application_id uuid, display_name text, country_code text,
  requested_store_slug text, application_status text,
  assigned_reviewer_membership_id uuid, submitted_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.list_merchant_review_queue_impl() $function$;

CREATE OR REPLACE FUNCTION public.get_assigned_merchant_application(
  p_application_id uuid
)
RETURNS TABLE (
  application_id uuid, applicant_user_id uuid, display_name text,
  country_code text, requested_store_slug text, application_status text,
  registration_reference text, evidence_reference text,
  submitted_at timestamptz, updated_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.get_assigned_merchant_application_impl(p_application_id)
$function$;

CREATE OR REPLACE FUNCTION public.assign_merchant_application(
  p_application_id uuid,
  p_reviewer_membership_id uuid,
  p_idempotency_key uuid
)
RETURNS TABLE (
  application_id uuid, application_status text, reviewer_membership_id uuid
)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.assign_merchant_application_impl(
    p_application_id, p_reviewer_membership_id, p_idempotency_key
  )
$function$;

CREATE OR REPLACE FUNCTION public.review_merchant_application(
  p_application_id uuid,
  p_action text,
  p_reason_code text,
  p_idempotency_key uuid
)
RETURNS TABLE (
  application_id uuid, application_status text, organization_id uuid,
  store_id uuid, owner_membership_id uuid
)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.review_merchant_application_impl(
    p_application_id, p_action, p_reason_code, p_idempotency_key
  )
$function$;

CREATE OR REPLACE FUNCTION public.withdraw_merchant_application(
  p_application_id uuid,
  p_idempotency_key uuid
)
RETURNS TABLE (application_id uuid, application_status text)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.withdraw_merchant_application_impl(
    p_application_id, p_idempotency_key
  )
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION private.save_merchant_application_impl(
  text, text, text, text, text, boolean, uuid
) FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.get_my_merchant_application_impl()
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.list_merchant_review_queue_impl()
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.get_assigned_merchant_application_impl(uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.assign_merchant_application_impl(uuid, uuid, uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.review_merchant_application_impl(
  uuid, text, text, uuid
) FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.withdraw_merchant_application_impl(uuid, uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;

GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.save_merchant_application_impl(
  text, text, text, text, text, boolean, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION private.get_my_merchant_application_impl()
  TO authenticated;
GRANT EXECUTE ON FUNCTION private.list_merchant_review_queue_impl()
  TO authenticated;
GRANT EXECUTE ON FUNCTION private.get_assigned_merchant_application_impl(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION private.assign_merchant_application_impl(uuid, uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION private.review_merchant_application_impl(
  uuid, text, text, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION private.withdraw_merchant_application_impl(uuid, uuid)
  TO authenticated;

DO $owner_handoff$
BEGIN
  IF pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR pg_catalog.has_schema_privilege(
       'rebuy_business_executor', 'private', 'CREATE'
     )
  THEN
    RAISE EXCEPTION 'rebuy_business_owner_handoff_precondition_invalid';
  END IF;
  EXECUTE 'GRANT rebuy_business_executor TO postgres WITH INHERIT FALSE GRANTED BY CURRENT_USER';
  EXECUTE 'GRANT CREATE ON SCHEMA private TO rebuy_business_executor GRANTED BY CURRENT_USER';
  IF NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR NOT pg_catalog.has_schema_privilege(
       'rebuy_business_executor', 'private', 'CREATE'
     )
  THEN
    RAISE EXCEPTION 'rebuy_business_owner_handoff_capability_invalid';
  END IF;
  EXECUTE 'ALTER FUNCTION private.save_merchant_application_impl(text, text, text, text, text, boolean, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.get_my_merchant_application_impl() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.list_merchant_review_queue_impl() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.get_assigned_merchant_application_impl(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.assign_merchant_application_impl(uuid, uuid, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.review_merchant_application_impl(uuid, text, text, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.withdraw_merchant_application_impl(uuid, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'REVOKE rebuy_business_executor FROM postgres GRANTED BY CURRENT_USER';
  EXECUTE 'REVOKE CREATE ON SCHEMA private FROM rebuy_business_executor GRANTED BY CURRENT_USER';
  IF pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
     OR pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR pg_catalog.has_schema_privilege(
       'rebuy_business_executor', 'private', 'CREATE'
     )
  THEN
    RAISE EXCEPTION 'rebuy_business_owner_handoff_cleanup_invalid';
  END IF;
END
$owner_handoff$;

REVOKE ALL PRIVILEGES ON FUNCTION public.save_merchant_application(
  text, text, text, text, text, boolean, uuid
) FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.get_my_merchant_application()
  FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.list_merchant_review_queue()
  FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.get_assigned_merchant_application(uuid)
  FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.assign_merchant_application(uuid, uuid, uuid)
  FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.review_merchant_application(
  uuid, text, text, uuid
) FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.withdraw_merchant_application(uuid, uuid)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.save_merchant_application(
  text, text, text, text, text, boolean, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_merchant_application()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_merchant_review_queue()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_assigned_merchant_application(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_merchant_application(uuid, uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_merchant_application(
  uuid, text, text, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.withdraw_merchant_application(uuid, uuid)
  TO authenticated;

-- The public schema receives default function EXECUTE in PostgreSQL. Close
-- effective service-role access on every P3 helper, implementation and wrapper.
REVOKE EXECUTE ON FUNCTION private.rebuy_business_reset_context() FROM service_role;
REVOKE EXECUTE ON FUNCTION private.rebuy_business_require_identity(boolean) FROM service_role;
REVOKE EXECUTE ON FUNCTION private.rebuy_business_membership_has_permission(
  uuid, uuid, text
) FROM service_role;
REVOKE EXECUTE ON FUNCTION private.rebuy_business_find_platform_membership(text)
  FROM service_role;
