-- P2-L synthetic-only local slice: ten business tables and the invitation path.
-- No auth.users trigger, provider invite, service role, token, or secret is used.

DO $role_guard$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_invite_executor'
  ) THEN
    RAISE EXCEPTION 'rebuy_invite_executor_role_missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_invite_executor'
      AND (
        rolsuper
        OR rolcanlogin
        OR rolcreatedb
        OR rolcreaterole
        OR rolinherit
        OR rolreplication
        OR rolbypassrls
      )
  ) THEN
    RAISE EXCEPTION 'rebuy_invite_executor_attributes_invalid';
  END IF;
END
$role_guard$;

DO $membership_guard$
BEGIN
  IF (
    SELECT count(*)
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_invite_executor'
       OR member_role.rolname = 'rebuy_invite_executor'
  ) <> 1 OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_invite_executor'
      AND member_role.rolname = 'postgres'
      AND grantor_role.rolname = 'supabase_admin'
      AND pam.admin_option
      AND NOT pam.inherit_option
      AND NOT pam.set_option
  ) THEN
    RAISE EXCEPTION 'rebuy_invite_executor_role_membership_invalid';
  END IF;
END
$membership_guard$;

CREATE SCHEMA IF NOT EXISTS private;
ALTER SCHEMA private OWNER TO postgres;
REVOKE ALL ON SCHEMA public, private FROM rebuy_invite_executor;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA public, private TO rebuy_invite_executor;

CREATE TABLE public.profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email_normalized text NOT NULL,
  display_name text,
  locale text,
  timezone text,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT profiles_email_normalized_check CHECK (
    email_normalized = pg_catalog.lower(pg_catalog.btrim(email_normalized))
    AND email_normalized ~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
  ),
  CONSTRAINT profiles_status_check CHECK (status IN ('active', 'suspended', 'deleted'))
);

CREATE TABLE public.organizations (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  organization_type text NOT NULL,
  display_name text NOT NULL,
  legal_name text,
  status text NOT NULL DEFAULT 'active',
  created_by uuid NOT NULL REFERENCES auth.users (id),
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT organizations_id_type_key UNIQUE (id, organization_type),
  CONSTRAINT organizations_type_check CHECK (organization_type IN ('merchant', 'wholesale', 'platform')),
  CONSTRAINT organizations_status_check CHECK (status IN ('active', 'suspended', 'closed'))
);

CREATE TABLE public.stores (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  organization_id uuid NOT NULL,
  organization_type text NOT NULL,
  display_name text NOT NULL,
  slug text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  public_visibility boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT stores_id_org_key UNIQUE (id, organization_id, organization_type),
  CONSTRAINT stores_org_fk FOREIGN KEY (organization_id, organization_type)
    REFERENCES public.organizations (id, organization_type),
  CONSTRAINT stores_status_check CHECK (status IN ('active', 'suspended', 'closed')),
  CONSTRAINT stores_slug_check CHECK (
    slug = pg_catalog.lower(slug)
    AND slug ~ '^[a-z0-9][a-z0-9-]*$'
  ),
  CONSTRAINT stores_org_slug_key UNIQUE (organization_id, organization_type, slug)
);

CREATE TABLE public.role_definitions (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  organization_id uuid,
  organization_type text,
  role_key text NOT NULL,
  scope_type text NOT NULL,
  version integer NOT NULL,
  applicable_organization_type text NOT NULL,
  is_system boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'active',
  assignable boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT role_definitions_id_version_key UNIQUE (id, version),
  CONSTRAINT role_definitions_id_version_org_key UNIQUE NULLS NOT DISTINCT (
    id, version, organization_id, organization_type
  ),
  CONSTRAINT role_definitions_org_fk FOREIGN KEY (organization_id, organization_type)
    REFERENCES public.organizations (id, organization_type),
  CONSTRAINT role_definitions_org_pair_check CHECK (
    (organization_id IS NULL AND organization_type IS NULL)
    OR (organization_id IS NOT NULL AND organization_type IS NOT NULL)
  ),
  CONSTRAINT role_definitions_system_check CHECK (is_system = (organization_id IS NULL)),
  CONSTRAINT role_definitions_scope_check CHECK (scope_type IN ('organization', 'store', 'platform')),
  CONSTRAINT role_definitions_applicable_type_check CHECK (
    applicable_organization_type IN ('any', 'merchant', 'wholesale', 'platform')
  ),
  CONSTRAINT role_definitions_version_check CHECK (version > 0),
  CONSTRAINT role_definitions_status_check CHECK (status IN ('active', 'retired')),
  CONSTRAINT role_definitions_key UNIQUE NULLS NOT DISTINCT (
    role_key, version, organization_id, organization_type
  )
);

CREATE TABLE public.permissions (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  permission_key text NOT NULL UNIQUE,
  resource text NOT NULL,
  action text NOT NULL,
  scope_type text NOT NULL,
  risk_level text NOT NULL,
  requires_aal2 boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT permissions_scope_check CHECK (scope_type IN ('user', 'organization', 'store', 'platform')),
  CONSTRAINT permissions_risk_check CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  CONSTRAINT permissions_key_check CHECK (permission_key ~ '^[a-z][a-z0-9_.-]*$')
);

CREATE TABLE public.role_permissions (
  role_definition_id uuid NOT NULL,
  role_version integer NOT NULL,
  permission_id uuid NOT NULL,
  is_granted boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  PRIMARY KEY (role_definition_id, role_version, permission_id),
  CONSTRAINT role_permissions_role_fk FOREIGN KEY (role_definition_id, role_version)
    REFERENCES public.role_definitions (id, version),
  CONSTRAINT role_permissions_permission_fk FOREIGN KEY (permission_id)
    REFERENCES public.permissions (id)
);

CREATE TABLE public.memberships (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  organization_id uuid NOT NULL,
  organization_type text NOT NULL,
  role_definition_id uuid NOT NULL,
  role_version integer NOT NULL,
  role_definition_organization_id uuid,
  role_definition_organization_type text,
  status text NOT NULL DEFAULT 'pending_acceptance',
  invited_by uuid REFERENCES auth.users (id),
  source_invitation_id uuid,
  valid_from timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  valid_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT memberships_id_org_key UNIQUE (id, organization_id, organization_type),
  CONSTRAINT memberships_id_user_org_key UNIQUE (
    id, user_id, organization_id, organization_type
  ),
  CONSTRAINT memberships_user_org_key UNIQUE (user_id, organization_id, organization_type),
  CONSTRAINT memberships_org_fk FOREIGN KEY (organization_id, organization_type)
    REFERENCES public.organizations (id, organization_type),
  CONSTRAINT memberships_role_fk FOREIGN KEY (role_definition_id, role_version)
    REFERENCES public.role_definitions (id, version),
  CONSTRAINT memberships_role_org_fk FOREIGN KEY (
    role_definition_id, role_version,
    role_definition_organization_id, role_definition_organization_type
  ) REFERENCES public.role_definitions (
    id, version, organization_id, organization_type
  ),
  CONSTRAINT memberships_role_org_pair_check CHECK (
    (role_definition_organization_id IS NULL AND role_definition_organization_type IS NULL)
    OR (
      role_definition_organization_id IS NOT NULL
      AND role_definition_organization_type IS NOT NULL
    )
  ),
  CONSTRAINT memberships_status_check CHECK (
    status IN ('pending_acceptance', 'active', 'suspended', 'revoked', 'expired')
  ),
  CONSTRAINT memberships_validity_check CHECK (
    valid_until IS NULL OR valid_until > valid_from
  )
);

CREATE TABLE public.membership_invitations (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  organization_id uuid NOT NULL,
  organization_type text NOT NULL,
  store_id uuid,
  role_definition_id uuid NOT NULL,
  role_version integer NOT NULL,
  role_definition_organization_id uuid,
  role_definition_organization_type text,
  scope_type text NOT NULL,
  target_email_normalized text NOT NULL,
  idempotency_key uuid NOT NULL,
  creator_membership_id uuid NOT NULL,
  creator_user_id uuid NOT NULL REFERENCES auth.users (id),
  creator_role_definition_id uuid NOT NULL,
  creator_role_version integer NOT NULL,
  creator_role_organization_id uuid,
  creator_role_organization_type text,
  creator_membership_status text NOT NULL DEFAULT 'active',
  status text NOT NULL DEFAULT 'sent',
  expires_at timestamptz NOT NULL,
  accepted_user_id uuid REFERENCES auth.users (id),
  accepted_membership_id uuid,
  revoked_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT membership_invitations_id_org_key UNIQUE (id, organization_id, organization_type),
  CONSTRAINT membership_invitations_org_fk FOREIGN KEY (organization_id, organization_type)
    REFERENCES public.organizations (id, organization_type),
  CONSTRAINT membership_invitations_store_fk FOREIGN KEY (
    store_id, organization_id, organization_type
  ) REFERENCES public.stores (id, organization_id, organization_type),
  CONSTRAINT membership_invitations_role_fk FOREIGN KEY (role_definition_id, role_version)
    REFERENCES public.role_definitions (id, version),
  CONSTRAINT membership_invitations_role_org_fk FOREIGN KEY (
    role_definition_id, role_version,
    role_definition_organization_id, role_definition_organization_type
  ) REFERENCES public.role_definitions (
    id, version, organization_id, organization_type
  ),
  CONSTRAINT membership_invitations_role_org_pair_check CHECK (
    (role_definition_organization_id IS NULL AND role_definition_organization_type IS NULL)
    OR (
      role_definition_organization_id IS NOT NULL
      AND role_definition_organization_type IS NOT NULL
    )
  ),
  CONSTRAINT membership_invitations_creator_fk FOREIGN KEY (
    creator_membership_id, creator_user_id, organization_id, organization_type
  ) REFERENCES public.memberships (id, user_id, organization_id, organization_type),
  CONSTRAINT membership_invitations_creator_role_fk FOREIGN KEY (
    creator_role_definition_id, creator_role_version
  ) REFERENCES public.role_definitions (id, version),
  CONSTRAINT membership_invitations_creator_role_org_fk FOREIGN KEY (
    creator_role_definition_id, creator_role_version,
    creator_role_organization_id, creator_role_organization_type
  ) REFERENCES public.role_definitions (
    id, version, organization_id, organization_type
  ),
  CONSTRAINT membership_invitations_creator_role_org_pair_check CHECK (
    (creator_role_organization_id IS NULL AND creator_role_organization_type IS NULL)
    OR (
      creator_role_organization_id IS NOT NULL
      AND creator_role_organization_type IS NOT NULL
    )
  ),
  CONSTRAINT membership_invitations_scope_check CHECK (
    (scope_type = 'organization' AND store_id IS NULL)
    OR (scope_type = 'store' AND store_id IS NOT NULL)
  ),
  CONSTRAINT membership_invitations_scope_type_check CHECK (
    scope_type IN ('organization', 'store')
  ),
  CONSTRAINT membership_invitations_target_email_check CHECK (
    target_email_normalized = pg_catalog.lower(pg_catalog.btrim(target_email_normalized))
    AND target_email_normalized ~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
  ),
  CONSTRAINT membership_invitations_creator_status_check CHECK (
    creator_membership_status = 'active'
  ),
  CONSTRAINT membership_invitations_status_check CHECK (
    status IN ('created', 'sent', 'accepted', 'expired', 'revoked')
  ),
  CONSTRAINT membership_invitations_accepted_fields_check CHECK (
    (
      status = 'accepted'
      AND accepted_user_id IS NOT NULL
      AND accepted_membership_id IS NOT NULL
      AND consumed_at IS NOT NULL
    )
    OR (
      status <> 'accepted'
      AND accepted_user_id IS NULL
      AND accepted_membership_id IS NULL
      AND consumed_at IS NULL
    )
  ),
  CONSTRAINT membership_invitations_revoked_fields_check CHECK (
    (status = 'revoked' AND revoked_at IS NOT NULL)
    OR (status <> 'revoked' AND revoked_at IS NULL)
  ),
  CONSTRAINT membership_invitations_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT membership_invitations_creator_idempotency_key UNIQUE NULLS NOT DISTINCT (
    creator_membership_id, idempotency_key
  )
);

CREATE TABLE public.membership_store_scopes (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  membership_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  organization_type text NOT NULL,
  store_id uuid,
  scope_type text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT membership_store_scopes_id_membership_org_key UNIQUE (
    id, membership_id, organization_id, organization_type
  ),
  CONSTRAINT membership_store_scopes_membership_fk FOREIGN KEY (
    membership_id, organization_id, organization_type
  ) REFERENCES public.memberships (id, organization_id, organization_type),
  CONSTRAINT membership_store_scopes_store_fk FOREIGN KEY (
    store_id, organization_id, organization_type
  ) REFERENCES public.stores (id, organization_id, organization_type),
  CONSTRAINT membership_store_scopes_scope_check CHECK (
    (scope_type = 'organization' AND store_id IS NULL)
    OR (scope_type = 'store' AND store_id IS NOT NULL)
  ),
  CONSTRAINT membership_store_scopes_scope_type_check CHECK (
    scope_type IN ('organization', 'store')
  ),
  CONSTRAINT membership_store_scopes_status_check CHECK (
    status IN ('active', 'suspended', 'revoked')
  ),
  CONSTRAINT membership_store_scopes_unique UNIQUE NULLS NOT DISTINCT (
    membership_id, scope_type, store_id
  )
);

CREATE TABLE public.audit_logs (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  event_code text NOT NULL,
  outcome text NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users (id),
  organization_id uuid NOT NULL,
  organization_type text NOT NULL,
  store_id uuid,
  invitation_id uuid NOT NULL,
  membership_id uuid,
  request_id uuid,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT audit_logs_org_fk FOREIGN KEY (organization_id, organization_type)
    REFERENCES public.organizations (id, organization_type),
  CONSTRAINT audit_logs_store_fk FOREIGN KEY (
    store_id, organization_id, organization_type
  ) REFERENCES public.stores (id, organization_id, organization_type),
  CONSTRAINT audit_logs_event_invitation_fk FOREIGN KEY (
    invitation_id, organization_id, organization_type
  ) REFERENCES public.membership_invitations (
    id, organization_id, organization_type
  ),
  CONSTRAINT audit_logs_event_membership_fk FOREIGN KEY (
    membership_id, organization_id, organization_type
  ) REFERENCES public.memberships (id, organization_id, organization_type),
  CONSTRAINT audit_logs_event_check CHECK (
    event_code IN (
      'membership_invitation.created',
      'membership_invitation.accepted'
    )
  ),
  CONSTRAINT audit_logs_outcome_check CHECK (outcome IN ('success', 'rejected')),
  CONSTRAINT audit_logs_event_membership_check CHECK (
    (event_code = 'membership_invitation.created' AND membership_id IS NULL)
    OR (event_code = 'membership_invitation.accepted' AND membership_id IS NOT NULL)
  ),
  CONSTRAINT audit_logs_invitation_event_key UNIQUE (event_code, invitation_id)
);

ALTER TABLE public.memberships
  ADD CONSTRAINT memberships_source_invitation_fk
  FOREIGN KEY (source_invitation_id, organization_id, organization_type)
  REFERENCES public.membership_invitations (id, organization_id, organization_type);

ALTER TABLE public.membership_invitations
  ADD CONSTRAINT membership_invitations_accepted_membership_fk
  FOREIGN KEY (
    accepted_membership_id, accepted_user_id, organization_id, organization_type
  ) REFERENCES public.memberships (
    id, user_id, organization_id, organization_type
  );

CREATE UNIQUE INDEX memberships_source_invitation_unique
  ON public.memberships (source_invitation_id)
  WHERE source_invitation_id IS NOT NULL;

CREATE UNIQUE INDEX membership_invitations_pending_business_key
  ON public.membership_invitations (
    creator_membership_id,
    organization_id,
    organization_type,
    target_email_normalized,
    role_definition_id,
    role_version,
    scope_type,
    store_id
  ) NULLS NOT DISTINCT
  WHERE status IN ('created', 'sent');

CREATE INDEX organizations_created_by_idx ON public.organizations (created_by);
CREATE INDEX stores_organization_idx
  ON public.stores (organization_id, organization_type);
CREATE INDEX role_definitions_organization_idx
  ON public.role_definitions (organization_id, organization_type, status, assignable);
CREATE INDEX role_permissions_permission_idx
  ON public.role_permissions (permission_id);
CREATE INDEX memberships_user_idx
  ON public.memberships (user_id, status, valid_from, valid_until);
CREATE INDEX memberships_organization_idx
  ON public.memberships (organization_id, organization_type, status);
CREATE INDEX memberships_role_idx
  ON public.memberships (role_definition_id, role_version);
CREATE INDEX memberships_role_org_idx
  ON public.memberships (
    role_definition_id, role_version,
    role_definition_organization_id, role_definition_organization_type
  );
CREATE INDEX memberships_invited_by_idx
  ON public.memberships (invited_by);
CREATE INDEX memberships_source_invitation_idx
  ON public.memberships (
    source_invitation_id, organization_id, organization_type
  );
CREATE INDEX membership_invitations_organization_idx
  ON public.membership_invitations (organization_id, organization_type, status);
CREATE INDEX membership_invitations_store_idx
  ON public.membership_invitations (
    store_id, organization_id, organization_type, status
  );
CREATE INDEX membership_invitations_role_idx
  ON public.membership_invitations (role_definition_id, role_version);
CREATE INDEX membership_invitations_role_org_idx
  ON public.membership_invitations (
    role_definition_id, role_version,
    role_definition_organization_id, role_definition_organization_type
  );
CREATE INDEX membership_invitations_creator_idx
  ON public.membership_invitations (creator_membership_id, status);
CREATE INDEX membership_invitations_creator_fk_idx
  ON public.membership_invitations (
    creator_membership_id, creator_user_id, organization_id, organization_type
  );
CREATE INDEX membership_invitations_creator_role_idx
  ON public.membership_invitations (
    creator_role_definition_id, creator_role_version,
    creator_role_organization_id, creator_role_organization_type
  );
CREATE INDEX membership_invitations_creator_user_idx
  ON public.membership_invitations (creator_user_id, status);
CREATE INDEX membership_invitations_target_idx
  ON public.membership_invitations (
    target_email_normalized, status, expires_at
  );
CREATE INDEX membership_invitations_accepted_user_idx
  ON public.membership_invitations (accepted_user_id);
CREATE INDEX membership_invitations_accepted_membership_idx
  ON public.membership_invitations (
    accepted_membership_id, accepted_user_id,
    organization_id, organization_type
  );
CREATE INDEX membership_store_scopes_membership_idx
  ON public.membership_store_scopes (membership_id, status);
CREATE INDEX membership_store_scopes_membership_org_idx
  ON public.membership_store_scopes (
    membership_id, organization_id, organization_type, status
  );
CREATE INDEX membership_store_scopes_store_idx
  ON public.membership_store_scopes (
    store_id, organization_id, organization_type, status
  );
CREATE INDEX membership_store_scopes_organization_idx
  ON public.membership_store_scopes (
    organization_id, organization_type, status
  );
CREATE INDEX audit_logs_actor_idx
  ON public.audit_logs (actor_user_id, created_at);
CREATE INDEX audit_logs_organization_idx
  ON public.audit_logs (organization_id, organization_type, created_at);
CREATE INDEX audit_logs_store_idx
  ON public.audit_logs (
    store_id, organization_id, organization_type, created_at
  );
CREATE INDEX audit_logs_invitation_idx
  ON public.audit_logs (invitation_id, organization_id, organization_type);
CREATE INDEX audit_logs_membership_idx
  ON public.audit_logs (membership_id, organization_id, organization_type);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE public.membership_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_invitations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.membership_store_scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_store_scopes FORCE ROW LEVEL SECURITY;
ALTER TABLE public.role_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_definitions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs FORCE ROW LEVEL SECURITY;

-- Mirror Supabase's auth.uid()/auth.jwt() claim lookup without requiring the
-- isolated executor to enter the platform-owned auth schema. PostgREST places
-- only the already verified request claims in these transaction-local GUCs.
CREATE OR REPLACE FUNCTION private.rebuy_request_jwt()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT COALESCE(
    NULLIF(pg_catalog.current_setting('request.jwt.claim', true), ''),
    NULLIF(pg_catalog.current_setting('request.jwt.claims', true), '')
  )::jsonb
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_request_uid()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT NULLIF(private.rebuy_request_jwt() ->> 'sub', '')::uuid
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION private.rebuy_request_jwt()
  FROM PUBLIC, anon, authenticated, rebuy_invite_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.rebuy_request_uid()
  FROM PUBLIC, anon, authenticated, rebuy_invite_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_request_jwt()
  TO authenticated, rebuy_invite_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_request_uid()
  TO authenticated, rebuy_invite_executor;

CREATE POLICY profiles_executor_self_select
  ON public.profiles
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_invite_executor
  USING (
    user_id = (SELECT private.rebuy_request_uid())
    AND ((SELECT private.rebuy_request_jwt()) -> 'is_anonymous') = 'false'::jsonb
    AND ((SELECT private.rebuy_request_jwt()) ->> 'email') =
        pg_catalog.lower(pg_catalog.btrim((SELECT private.rebuy_request_jwt()) ->> 'email'))
    AND ((SELECT private.rebuy_request_jwt()) ->> 'email') ~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
    AND email_normalized = ((SELECT private.rebuy_request_jwt()) ->> 'email')
  );

CREATE POLICY profiles_executor_self_insert
  ON public.profiles
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_invite_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.invite.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'profile_insert'
    AND user_id = (SELECT private.rebuy_request_uid())
    AND user_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.uid', true)), ''
    )::uuid
    AND email_normalized = ((SELECT private.rebuy_request_jwt()) ->> 'email')
    AND email_normalized = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.email', true)), ''
    )
    AND ((SELECT private.rebuy_request_jwt()) -> 'is_anonymous') = 'false'::jsonb
    AND status = 'active'
  );

CREATE POLICY profiles_authenticated_self_select
  ON public.profiles
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT private.rebuy_request_uid()));

CREATE POLICY profiles_authenticated_self_insert
  ON public.profiles
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = (SELECT private.rebuy_request_uid())
    AND email_normalized = ((SELECT private.rebuy_request_jwt()) ->> 'email')
    AND email_normalized = pg_catalog.lower(pg_catalog.btrim(email_normalized))
    AND email_normalized ~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
    AND ((SELECT private.rebuy_request_jwt()) -> 'is_anonymous') = 'false'::jsonb
    AND status = 'active'
  );

CREATE POLICY profiles_authenticated_self_update
  ON public.profiles
  AS PERMISSIVE
  FOR UPDATE
  TO authenticated
  USING (user_id = (SELECT private.rebuy_request_uid()))
  WITH CHECK (
    user_id = (SELECT private.rebuy_request_uid())
    AND email_normalized = pg_catalog.lower(pg_catalog.btrim(email_normalized))
    AND email_normalized ~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
  );

CREATE POLICY organizations_executor_scoped_select
  ON public.organizations
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_invite_executor
  USING (
    status = 'active'
    AND (
      EXISTS (
        SELECT 1
        FROM public.memberships AS m
        JOIN public.membership_store_scopes AS ms
          ON ms.membership_id = m.id
         AND ms.organization_id = m.organization_id
         AND ms.organization_type = m.organization_type
        WHERE m.user_id = (SELECT private.rebuy_request_uid())
          AND m.organization_id = organizations.id
          AND m.organization_type = organizations.organization_type
          AND m.status = 'active'
          AND m.valid_from <= pg_catalog.statement_timestamp()
          AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
          AND ms.status = 'active'
      )
      OR (
        (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_validate'
        AND (SELECT pg_catalog.current_setting('rebuy.invite.authorized', true)) = 'false'
        AND id = NULLIF(
          (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
        )::uuid
        AND organization_type = NULLIF(
          (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
        )
        AND (SELECT pg_catalog.current_setting('rebuy.invite.target_email', true)) =
            ((SELECT private.rebuy_request_jwt()) ->> 'email')
      )
    )
  );

CREATE POLICY stores_executor_scoped_select
  ON public.stores
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_invite_executor
  USING (
    status = 'active'
    AND (
      EXISTS (
        SELECT 1
        FROM public.memberships AS m
        JOIN public.membership_store_scopes AS ms
          ON ms.membership_id = m.id
         AND ms.organization_id = m.organization_id
         AND ms.organization_type = m.organization_type
        WHERE m.user_id = (SELECT private.rebuy_request_uid())
          AND m.organization_id = stores.organization_id
          AND m.organization_type = stores.organization_type
          AND m.status = 'active'
          AND m.valid_from <= pg_catalog.statement_timestamp()
          AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
          AND ms.status = 'active'
          AND (
            (ms.scope_type = 'organization' AND ms.store_id IS NULL)
            OR (ms.scope_type = 'store' AND ms.store_id = stores.id)
          )
      )
      OR (
        (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_validate'
        AND (SELECT pg_catalog.current_setting('rebuy.invite.authorized', true)) = 'false'
        AND id = NULLIF(
          (SELECT pg_catalog.current_setting('rebuy.invite.store_id', true)), ''
        )::uuid
        AND organization_id = NULLIF(
          (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
        )::uuid
        AND organization_type = NULLIF(
          (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
        )
        AND (SELECT pg_catalog.current_setting('rebuy.invite.scope_type', true)) = 'store'
        AND (SELECT pg_catalog.current_setting('rebuy.invite.target_email', true)) =
            ((SELECT private.rebuy_request_jwt()) ->> 'email')
      )
    )
  );

CREATE POLICY memberships_executor_identity_select
  ON public.memberships
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_invite_executor
  USING (
    (
      user_id = (SELECT private.rebuy_request_uid())
      AND status = 'active'
      AND valid_from <= pg_catalog.statement_timestamp()
      AND (valid_until IS NULL OR valid_until > pg_catalog.statement_timestamp())
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_validate'
      AND id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_membership_id', true)), ''
      )::uuid
      AND user_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_user_id', true)), ''
      )::uuid
      AND organization_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
      )::uuid
      AND organization_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
      )
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_replay'
      AND id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.member_id', true)), ''
      )::uuid
      AND user_id = (SELECT private.rebuy_request_uid())
      AND source_invitation_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.invitation_id', true)), ''
      )::uuid
      AND organization_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
      )::uuid
      AND organization_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
      )
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_validate'
      AND user_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.uid', true)), ''
      )::uuid
      AND organization_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
      )::uuid
      AND organization_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
      )
    )
  );

CREATE POLICY memberships_executor_invitation_insert
  ON public.memberships
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_invite_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.invite.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_membership'
    AND id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.member_id', true)), ''
    )::uuid
    AND user_id = (SELECT private.rebuy_request_uid())
    AND user_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.uid', true)), ''
    )::uuid
    AND organization_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
    )::uuid
    AND organization_type = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
    )
    AND role_definition_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.role_id', true)), ''
    )::uuid
    AND role_version = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.role_version', true)), ''
    )::integer
    AND role_definition_organization_id IS NOT DISTINCT FROM NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.role_org_id', true)), ''
    )::uuid
    AND role_definition_organization_type IS NOT DISTINCT FROM NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.role_org_type', true)), ''
    )
    AND status = 'active'
    AND invited_by = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.creator_user_id', true)), ''
    )::uuid
    AND source_invitation_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.invitation_id', true)), ''
    )::uuid
    AND valid_from = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.valid_from', true)), ''
    )::timestamptz
    AND created_at = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.created_at', true)), ''
    )::timestamptz
    AND updated_at = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.updated_at', true)), ''
    )::timestamptz
  );

CREATE POLICY memberships_executor_lock
  ON public.memberships
  AS PERMISSIVE
  FOR UPDATE
  TO rebuy_invite_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_validate'
      AND id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_membership_id', true)), ''
      )::uuid
      AND user_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_user_id', true)), ''
      )::uuid
      AND organization_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
      )::uuid
      AND organization_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
      )
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_replay'
      AND id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.member_id', true)), ''
      )::uuid
      AND user_id = (SELECT private.rebuy_request_uid())
      AND source_invitation_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.invitation_id', true)), ''
      )::uuid
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_validate'
      AND user_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.uid', true)), ''
      )::uuid
      AND organization_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
      )::uuid
      AND organization_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
      )
    )
  )
  WITH CHECK (false);

CREATE POLICY membership_invitations_executor_context_select
  ON public.membership_invitations
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_invite_executor
  USING (
    (
      creator_user_id = (SELECT private.rebuy_request_uid())
      AND ((SELECT private.rebuy_request_jwt()) -> 'is_anonymous') = 'false'::jsonb
      AND ((SELECT private.rebuy_request_jwt()) ->> 'email') =
          pg_catalog.lower(pg_catalog.btrim((SELECT private.rebuy_request_jwt()) ->> 'email'))
      AND ((SELECT private.rebuy_request_jwt()) ->> 'email') ~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
      AND status IN ('created', 'sent', 'accepted', 'expired', 'revoked')
    )
    OR (
      target_email_normalized = ((SELECT private.rebuy_request_jwt()) ->> 'email')
      AND ((SELECT private.rebuy_request_jwt()) -> 'is_anonymous') = 'false'::jsonb
      AND ((SELECT private.rebuy_request_jwt()) ->> 'email') =
          pg_catalog.lower(pg_catalog.btrim((SELECT private.rebuy_request_jwt()) ->> 'email'))
      AND ((SELECT private.rebuy_request_jwt()) ->> 'email') ~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
      AND status IN ('created', 'sent', 'accepted')
    )
  );

CREATE POLICY membership_invitations_executor_create
  ON public.membership_invitations
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_invite_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.invite.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'create_invitation'
    AND id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.invitation_id', true)), ''
    )::uuid
    AND organization_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
    )::uuid
    AND organization_type = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
    )
    AND store_id IS NOT DISTINCT FROM NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.store_id', true)), ''
    )::uuid
    AND role_definition_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.role_id', true)), ''
    )::uuid
    AND role_version = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.role_version', true)), ''
    )::integer
    AND role_definition_organization_id IS NOT DISTINCT FROM NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.role_org_id', true)), ''
    )::uuid
    AND role_definition_organization_type IS NOT DISTINCT FROM NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.role_org_type', true)), ''
    )
    AND scope_type = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.scope_type', true)), ''
    )
    AND target_email_normalized = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.target_email', true)), ''
    )
    AND idempotency_key = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.idempotency_key', true)), ''
    )::uuid
    AND creator_membership_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.creator_membership_id', true)), ''
    )::uuid
    AND creator_user_id = (SELECT private.rebuy_request_uid())
    AND creator_user_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.creator_user_id', true)), ''
    )::uuid
    AND creator_role_definition_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_id', true)), ''
    )::uuid
    AND creator_role_version = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_version', true)), ''
    )::integer
    AND creator_role_organization_id IS NOT DISTINCT FROM NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_org_id', true)), ''
    )::uuid
    AND creator_role_organization_type IS NOT DISTINCT FROM NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_org_type', true)), ''
    )
    AND creator_membership_status = 'active'
    AND status = 'sent'
    AND expires_at = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.expires_at', true)), ''
    )::timestamptz
    AND accepted_user_id IS NULL
    AND accepted_membership_id IS NULL
    AND revoked_at IS NULL
    AND consumed_at IS NULL
    AND created_at = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.created_at', true)), ''
    )::timestamptz
    AND updated_at = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.updated_at', true)), ''
    )::timestamptz
  );

CREATE POLICY membership_invitations_executor_update
  ON public.membership_invitations
  AS PERMISSIVE
  FOR UPDATE
  TO rebuy_invite_executor
  USING (
    (
      creator_user_id = (SELECT private.rebuy_request_uid())
      AND ((SELECT private.rebuy_request_jwt()) -> 'is_anonymous') = 'false'::jsonb
      AND ((SELECT private.rebuy_request_jwt()) ->> 'email') =
          pg_catalog.lower(pg_catalog.btrim((SELECT private.rebuy_request_jwt()) ->> 'email'))
      AND ((SELECT private.rebuy_request_jwt()) ->> 'email') ~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
      AND status IN ('created', 'sent', 'expired')
      AND expires_at <= pg_catalog.statement_timestamp()
    )
    OR (
      target_email_normalized = ((SELECT private.rebuy_request_jwt()) ->> 'email')
      AND ((SELECT private.rebuy_request_jwt()) -> 'is_anonymous') = 'false'::jsonb
      AND ((SELECT private.rebuy_request_jwt()) ->> 'email') =
          pg_catalog.lower(pg_catalog.btrim((SELECT private.rebuy_request_jwt()) ->> 'email'))
      AND ((SELECT private.rebuy_request_jwt()) ->> 'email') ~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
      AND status IN ('created', 'sent')
    )
    OR (
      target_email_normalized = ((SELECT private.rebuy_request_jwt()) ->> 'email')
      AND accepted_user_id = (SELECT private.rebuy_request_uid())
      AND ((SELECT private.rebuy_request_jwt()) -> 'is_anonymous') = 'false'::jsonb
      AND ((SELECT private.rebuy_request_jwt()) ->> 'email') =
          pg_catalog.lower(pg_catalog.btrim((SELECT private.rebuy_request_jwt()) ->> 'email'))
      AND ((SELECT private.rebuy_request_jwt()) ->> 'email') ~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
      AND status = 'accepted'
    )
  )
  WITH CHECK (
    (
      (SELECT pg_catalog.current_setting('rebuy.invite.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_invitation'
      AND id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.invitation_id', true)), ''
      )::uuid
      AND organization_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
      )::uuid
      AND organization_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
      )
      AND store_id IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.store_id', true)), ''
      )::uuid
      AND role_definition_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.role_id', true)), ''
      )::uuid
      AND role_version = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.role_version', true)), ''
      )::integer
      AND role_definition_organization_id IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.role_org_id', true)), ''
      )::uuid
      AND role_definition_organization_type IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.role_org_type', true)), ''
      )
      AND scope_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.scope_type', true)), ''
      )
      AND target_email_normalized = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.target_email', true)), ''
      )
      AND idempotency_key = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.idempotency_key', true)), ''
      )::uuid
      AND creator_membership_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_membership_id', true)), ''
      )::uuid
      AND creator_user_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_user_id', true)), ''
      )::uuid
      AND creator_role_definition_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_id', true)), ''
      )::uuid
      AND creator_role_version = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_version', true)), ''
      )::integer
      AND creator_role_organization_id IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_org_id', true)), ''
      )::uuid
      AND creator_role_organization_type IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_org_type', true)), ''
      )
      AND creator_membership_status = 'active'
      AND status = 'accepted'
      AND accepted_user_id = (SELECT private.rebuy_request_uid())
      AND accepted_user_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.uid', true)), ''
      )::uuid
      AND accepted_membership_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.member_id', true)), ''
      )::uuid
      AND revoked_at IS NULL
      AND consumed_at = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.consumed_at', true)), ''
      )::timestamptz
      AND expires_at = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.expires_at', true)), ''
      )::timestamptz
      AND created_at = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.created_at', true)), ''
      )::timestamptz
      AND updated_at = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.updated_at', true)), ''
      )::timestamptz
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'expire_invitation'
      AND id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.invitation_id', true)), ''
      )::uuid
      AND organization_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
      )::uuid
      AND organization_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
      )
      AND store_id IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.store_id', true)), ''
      )::uuid
      AND role_definition_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.role_id', true)), ''
      )::uuid
      AND role_version = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.role_version', true)), ''
      )::integer
      AND role_definition_organization_id IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.role_org_id', true)), ''
      )::uuid
      AND role_definition_organization_type IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.role_org_type', true)), ''
      )
      AND scope_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.scope_type', true)), ''
      )
      AND target_email_normalized = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.target_email', true)), ''
      )
      AND idempotency_key = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.idempotency_key', true)), ''
      )::uuid
      AND creator_membership_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_membership_id', true)), ''
      )::uuid
      AND creator_user_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_user_id', true)), ''
      )::uuid
      AND creator_role_definition_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_id', true)), ''
      )::uuid
      AND creator_role_version = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_version', true)), ''
      )::integer
      AND creator_role_organization_id IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_org_id', true)), ''
      )::uuid
      AND creator_role_organization_type IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_org_type', true)), ''
      )
      AND creator_membership_status = 'active'
      AND status = 'expired'
      AND accepted_user_id IS NULL
      AND accepted_membership_id IS NULL
      AND revoked_at IS NULL
      AND consumed_at IS NULL
      AND expires_at = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.expires_at', true)), ''
      )::timestamptz
      AND created_at = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.created_at', true)), ''
      )::timestamptz
      AND updated_at = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.updated_at', true)), ''
      )::timestamptz
    )
  );

CREATE POLICY membership_store_scopes_executor_context_select
  ON public.membership_store_scopes
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_invite_executor
  USING (
    EXISTS (
      SELECT 1
      FROM public.memberships AS m
      WHERE m.id = membership_store_scopes.membership_id
        AND m.user_id = (SELECT private.rebuy_request_uid())
        AND m.organization_id = membership_store_scopes.organization_id
        AND m.organization_type = membership_store_scopes.organization_type
        AND m.status = 'active'
        AND m.valid_from <= pg_catalog.statement_timestamp()
        AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_validate'
      AND membership_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.creator_membership_id', true)), ''
      )::uuid
      AND organization_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
      )::uuid
      AND organization_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
      )
      AND scope_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.scope_type', true)), ''
      )
      AND store_id IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.store_id', true)), ''
      )::uuid
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_replay'
      AND membership_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.member_id', true)), ''
      )::uuid
      AND organization_id = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
      )::uuid
      AND organization_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
      )
      AND scope_type = NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.scope_type', true)), ''
      )
      AND store_id IS NOT DISTINCT FROM NULLIF(
        (SELECT pg_catalog.current_setting('rebuy.invite.store_id', true)), ''
      )::uuid
    )
  );

CREATE POLICY membership_store_scopes_executor_invitation_insert
  ON public.membership_store_scopes
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_invite_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.invite.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_scope'
    AND id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.scope_id', true)), ''
    )::uuid
    AND membership_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.member_id', true)), ''
    )::uuid
    AND organization_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
    )::uuid
    AND organization_type = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
    )
    AND store_id IS NOT DISTINCT FROM NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.store_id', true)), ''
    )::uuid
    AND scope_type = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.scope_type', true)), ''
    )
    AND status = 'active'
    AND created_at = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.created_at', true)), ''
    )::timestamptz
  );

CREATE POLICY role_definitions_executor_context_select
  ON public.role_definitions
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_invite_executor
  USING (
    EXISTS (
      SELECT 1
      FROM public.memberships AS m
      JOIN public.membership_store_scopes AS ms
        ON ms.membership_id = m.id
       AND ms.organization_id = m.organization_id
       AND ms.organization_type = m.organization_type
      WHERE m.user_id = (SELECT private.rebuy_request_uid())
        AND m.status = 'active'
        AND m.valid_from <= pg_catalog.statement_timestamp()
        AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
        AND ms.status = 'active'
        AND (
          (
            role_definitions.organization_id IS NULL
            AND (
              role_definitions.applicable_organization_type = 'any'
              OR role_definitions.applicable_organization_type = m.organization_type
            )
          )
          OR (
            role_definitions.organization_id = m.organization_id
            AND role_definitions.organization_type = m.organization_type
          )
        )
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_validate'
      AND (SELECT pg_catalog.current_setting('rebuy.invite.authorized', true)) = 'false'
      AND (
        (
          id = NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.role_id', true)), ''
          )::uuid
          AND version = NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.role_version', true)), ''
          )::integer
          AND organization_id IS NOT DISTINCT FROM NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.role_org_id', true)), ''
          )::uuid
          AND organization_type IS NOT DISTINCT FROM NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.role_org_type', true)), ''
          )
        )
        OR (
          id = NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_id', true)), ''
          )::uuid
          AND version = NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_version', true)), ''
          )::integer
          AND organization_id IS NOT DISTINCT FROM NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_org_id', true)), ''
          )::uuid
          AND organization_type IS NOT DISTINCT FROM NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_org_type', true)), ''
          )
        )
      )
    )
  );

CREATE POLICY permissions_executor_role_link_select
  ON public.permissions
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_invite_executor
  USING (
    EXISTS (
      SELECT 1
      FROM public.role_permissions AS rp
      JOIN public.memberships AS m
        ON m.role_definition_id = rp.role_definition_id
       AND m.role_version = rp.role_version
      JOIN public.membership_store_scopes AS ms
        ON ms.membership_id = m.id
       AND ms.organization_id = m.organization_id
       AND ms.organization_type = m.organization_type
      WHERE rp.permission_id = permissions.id
        AND m.user_id = (SELECT private.rebuy_request_uid())
        AND m.status = 'active'
        AND m.valid_from <= pg_catalog.statement_timestamp()
        AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
        AND ms.status = 'active'
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_validate'
      AND EXISTS (
        SELECT 1
        FROM public.role_permissions AS rp
        WHERE rp.permission_id = permissions.id
          AND (
            (
              rp.role_definition_id = NULLIF(
                (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_id', true)), ''
              )::uuid
              AND rp.role_version = NULLIF(
                (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_version', true)), ''
              )::integer
            )
            OR (
              rp.role_definition_id = NULLIF(
                (SELECT pg_catalog.current_setting('rebuy.invite.role_id', true)), ''
              )::uuid
              AND rp.role_version = NULLIF(
                (SELECT pg_catalog.current_setting('rebuy.invite.role_version', true)), ''
              )::integer
            )
          )
      )
    )
  );

CREATE POLICY role_permissions_executor_role_link_select
  ON public.role_permissions
  AS PERMISSIVE
  FOR SELECT
  TO rebuy_invite_executor
  USING (
    EXISTS (
      SELECT 1
      FROM public.memberships AS m
      JOIN public.membership_store_scopes AS ms
        ON ms.membership_id = m.id
       AND ms.organization_id = m.organization_id
       AND ms.organization_type = m.organization_type
      WHERE m.user_id = (SELECT private.rebuy_request_uid())
        AND m.status = 'active'
        AND m.valid_from <= pg_catalog.statement_timestamp()
        AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
        AND ms.status = 'active'
        AND role_permissions.role_definition_id = m.role_definition_id
        AND role_permissions.role_version = m.role_version
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) = 'accept_validate'
      AND (
        (
          role_permissions.role_definition_id = NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_id', true)), ''
          )::uuid
          AND role_permissions.role_version = NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.creator_role_version', true)), ''
          )::integer
        )
        OR (
          role_permissions.role_definition_id = NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.role_id', true)), ''
          )::uuid
          AND role_permissions.role_version = NULLIF(
            (SELECT pg_catalog.current_setting('rebuy.invite.role_version', true)), ''
          )::integer
        )
      )
    )
  );

CREATE POLICY audit_logs_executor_minimal_insert
  ON public.audit_logs
  AS PERMISSIVE
  FOR INSERT
  TO rebuy_invite_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.invite.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.invite.op', true)) IN (
      'create_audit', 'accept_audit'
    )
    AND id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.audit_id', true)), ''
    )::uuid
    AND event_code = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.event_code', true)), ''
    )
    AND outcome = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.outcome', true)), ''
    )
    AND actor_user_id = (SELECT private.rebuy_request_uid())
    AND actor_user_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.uid', true)), ''
    )::uuid
    AND organization_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.org_id', true)), ''
    )::uuid
    AND organization_type = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.org_type', true)), ''
    )
    AND store_id IS NOT DISTINCT FROM NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.store_id', true)), ''
    )::uuid
    AND invitation_id = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.invitation_id', true)), ''
    )::uuid
    AND membership_id IS NOT DISTINCT FROM NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.member_id', true)), ''
    )::uuid
    AND request_id IS NULL
    AND created_at = NULLIF(
      (SELECT pg_catalog.current_setting('rebuy.invite.created_at', true)), ''
    )::timestamptz
  );

REVOKE ALL PRIVILEGES ON TABLE
  public.profiles,
  public.organizations,
  public.stores,
  public.memberships,
  public.membership_invitations,
  public.membership_store_scopes,
  public.role_definitions,
  public.permissions,
  public.role_permissions,
  public.audit_logs
FROM PUBLIC, anon, authenticated, rebuy_invite_executor;

GRANT SELECT (user_id, display_name, locale, timezone, status)
  ON public.profiles TO authenticated;
GRANT INSERT (user_id, email_normalized, status)
  ON public.profiles TO authenticated;
GRANT UPDATE (display_name, locale, timezone)
  ON public.profiles TO authenticated;

GRANT SELECT (user_id, email_normalized, status)
  ON public.profiles TO rebuy_invite_executor;
GRANT INSERT (user_id, email_normalized, status)
  ON public.profiles TO rebuy_invite_executor;

GRANT SELECT (id, organization_type, status)
  ON public.organizations TO rebuy_invite_executor;
GRANT SELECT (id, organization_id, organization_type, status)
  ON public.stores TO rebuy_invite_executor;
GRANT SELECT (
  id, organization_id, organization_type, role_key, scope_type, version,
  applicable_organization_type, is_system, status, assignable
)
  ON public.role_definitions TO rebuy_invite_executor;
GRANT SELECT (id, permission_key, resource, action, scope_type, is_active)
  ON public.permissions TO rebuy_invite_executor;
GRANT SELECT (role_definition_id, role_version, permission_id, is_granted)
  ON public.role_permissions TO rebuy_invite_executor;

GRANT SELECT (
  id, user_id, organization_id, organization_type, role_definition_id,
  role_version, role_definition_organization_id, role_definition_organization_type,
  status, invited_by, source_invitation_id, valid_from, valid_until
)
  ON public.memberships TO rebuy_invite_executor;
GRANT INSERT (
  id, user_id, organization_id, organization_type, role_definition_id,
  role_version, role_definition_organization_id, role_definition_organization_type,
  status, invited_by, source_invitation_id, valid_from, created_at, updated_at
)
  ON public.memberships TO rebuy_invite_executor;
GRANT UPDATE (updated_at)
  ON public.memberships TO rebuy_invite_executor;

GRANT SELECT (
  id, organization_id, organization_type, store_id, role_definition_id,
  role_version, role_definition_organization_id, role_definition_organization_type,
  scope_type, target_email_normalized, idempotency_key, creator_membership_id,
  creator_user_id, creator_role_definition_id, creator_role_version,
  creator_role_organization_id, creator_role_organization_type,
  creator_membership_status, status, expires_at, accepted_user_id,
  accepted_membership_id, revoked_at, consumed_at, created_at, updated_at
)
  ON public.membership_invitations TO rebuy_invite_executor;
GRANT INSERT (
  id, organization_id, organization_type, store_id, role_definition_id,
  role_version, role_definition_organization_id, role_definition_organization_type,
  scope_type, target_email_normalized, idempotency_key, creator_membership_id,
  creator_user_id, creator_role_definition_id, creator_role_version,
  creator_role_organization_id, creator_role_organization_type,
  creator_membership_status, status, expires_at, created_at, updated_at
)
  ON public.membership_invitations TO rebuy_invite_executor;
GRANT UPDATE (
  status, accepted_user_id, accepted_membership_id, consumed_at, updated_at
)
  ON public.membership_invitations TO rebuy_invite_executor;

GRANT SELECT (
  id, membership_id, organization_id, organization_type, store_id, scope_type, status
)
  ON public.membership_store_scopes TO rebuy_invite_executor;
GRANT INSERT (
  id, membership_id, organization_id, organization_type, store_id, scope_type,
  status, created_at
)
  ON public.membership_store_scopes TO rebuy_invite_executor;

GRANT INSERT (
  id, event_code, outcome, actor_user_id, organization_id, organization_type,
  store_id, invitation_id, membership_id, created_at
)
  ON public.audit_logs TO rebuy_invite_executor;

CREATE OR REPLACE FUNCTION private.create_membership_invitation_impl(
  p_organization_id uuid,
  p_role_definition_id uuid,
  p_role_version integer,
  p_scope_type text,
  p_store_id uuid,
  p_target_email text,
  p_idempotency_key uuid
)
RETURNS TABLE (
  invitation_id uuid,
  expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_claims jsonb;
  v_amr jsonb;
  v_uid uuid;
  v_email text;
  v_target_email text;
  v_scope_type text;
  v_otp_timestamp numeric;
  v_now timestamptz;
  v_now_epoch numeric;
  v_org_type text;
  v_org_status text;
  v_inviter_membership_id uuid;
  v_inviter_user_id uuid;
  v_inviter_role_id uuid;
  v_inviter_role_version integer;
  v_inviter_status text;
  v_inviter_role_org_id uuid;
  v_inviter_role_org_type text;
  v_has_invite boolean;
  v_role_scope_type text;
  v_role_org_id uuid;
  v_role_org_type text;
  v_role_applicable_type text;
  v_role_status text;
  v_role_assignable boolean;
  v_store_status text;
  v_expires_at timestamptz;
  v_existing_id uuid;
  v_existing_expires_at timestamptz;
  v_existing_created_at timestamptz;
  v_existing_org_id uuid;
  v_existing_org_type text;
  v_existing_store_id uuid;
  v_existing_role_id uuid;
  v_existing_role_version integer;
  v_existing_role_org_id uuid;
  v_existing_role_org_type text;
  v_existing_scope_type text;
  v_existing_target_email text;
  v_existing_idempotency_key uuid;
  v_existing_creator_membership_id uuid;
  v_existing_creator_user_id uuid;
  v_existing_creator_role_id uuid;
  v_existing_creator_role_version integer;
  v_existing_creator_role_org_id uuid;
  v_existing_creator_role_org_type text;
  v_existing_creator_status text;
  v_existing_status text;
  v_new_invitation_id uuid;
  v_profile_status text;
  v_profile_email text;
  v_row_count integer;
BEGIN
  PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'false', true);
  PERFORM pg_catalog.set_config('rebuy.invite.op', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.uid', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.email', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.invitation_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.member_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.scope_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.audit_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.org_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.org_type', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.store_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.scope_type', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_version', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_org_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_org_type', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_membership_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_user_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_version', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_type', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.target_email', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.idempotency_key', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.expires_at', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.valid_from', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.consumed_at', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.created_at', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.updated_at', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.event_code', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.outcome', '', true);

  v_claims := private.rebuy_request_jwt();
  v_uid := private.rebuy_request_uid();
  v_now := pg_catalog.statement_timestamp();

  IF v_uid IS NULL
     OR (v_claims -> 'is_anonymous') IS DISTINCT FROM 'false'::jsonb
  THEN
    RAISE EXCEPTION 'recent_otp_required';
  END IF;
  IF pg_catalog.jsonb_typeof(v_claims -> 'amr') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'recent_otp_required';
  END IF;
  IF pg_catalog.jsonb_array_length(v_claims -> 'amr') < 1 THEN
    RAISE EXCEPTION 'recent_otp_required';
  END IF;
  v_amr := v_claims -> 'amr' -> 0;
  IF pg_catalog.jsonb_typeof(v_amr) IS DISTINCT FROM 'object'
     OR (v_amr ->> 'method') IS DISTINCT FROM 'otp'
     OR pg_catalog.jsonb_typeof(v_amr -> 'timestamp') IS DISTINCT FROM 'number'
  THEN
    RAISE EXCEPTION 'recent_otp_required';
  END IF;
  BEGIN
    v_otp_timestamp := (v_amr ->> 'timestamp')::numeric;
  EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'recent_otp_required';
  END;
  v_now_epoch := EXTRACT(epoch FROM v_now)::numeric;
  IF v_otp_timestamp < v_now_epoch - 600
     OR v_otp_timestamp > v_now_epoch + 60
  THEN
    RAISE EXCEPTION 'recent_otp_required';
  END IF;

  v_email := v_claims ->> 'email';
  IF v_email IS NULL
     OR v_email IS DISTINCT FROM pg_catalog.lower(pg_catalog.btrim(v_email))
     OR v_email !~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
  THEN
    RAISE EXCEPTION 'synthetic_email_required';
  END IF;

  IF p_organization_id IS NULL
     OR p_role_definition_id IS NULL
     OR p_role_version IS NULL
     OR p_role_version <= 0
     OR p_idempotency_key IS NULL
  THEN
    RAISE EXCEPTION 'invalid_invitation_candidate';
  END IF;

  v_scope_type := pg_catalog.lower(pg_catalog.btrim(p_scope_type));
  IF v_scope_type IS NULL
     OR v_scope_type NOT IN ('organization', 'store')
     OR (v_scope_type = 'organization' AND p_store_id IS NOT NULL)
     OR (v_scope_type = 'store' AND p_store_id IS NULL)
  THEN
    RAISE EXCEPTION 'invalid_invitation_scope';
  END IF;

  v_target_email := pg_catalog.lower(pg_catalog.btrim(p_target_email));
  IF v_target_email IS NULL
     OR v_target_email !~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
  THEN
    RAISE EXCEPTION 'invalid_invitation_target';
  END IF;
  IF v_target_email = v_email THEN
    RAISE EXCEPTION 'self_invitation_forbidden';
  END IF;

  SELECT o.organization_type, o.status
    INTO v_org_type, v_org_status
  FROM public.organizations AS o
  WHERE o.id = p_organization_id;
  IF NOT FOUND OR v_org_status <> 'active' THEN
    RAISE EXCEPTION 'organization_not_available';
  END IF;

  SELECT m.id, m.user_id, m.role_definition_id, m.role_version, m.status,
         m.role_definition_organization_id, m.role_definition_organization_type
    INTO v_inviter_membership_id, v_inviter_user_id, v_inviter_role_id,
         v_inviter_role_version, v_inviter_status, v_inviter_role_org_id,
         v_inviter_role_org_type
  FROM public.memberships AS m
  WHERE m.user_id = v_uid
    AND m.organization_id = p_organization_id
    AND m.organization_type = v_org_type
    AND m.status = 'active'
    AND m.valid_from <= v_now
    AND (m.valid_until IS NULL OR m.valid_until > v_now);
  IF NOT FOUND OR v_inviter_user_id <> v_uid OR v_inviter_status <> 'active' THEN
    RAISE EXCEPTION 'inviter_membership_required';
  END IF;

  SELECT rd.organization_id, rd.organization_type, rd.status,
         rd.applicable_organization_type
    INTO v_inviter_role_org_id, v_inviter_role_org_type,
         v_role_status, v_role_applicable_type
  FROM public.role_definitions AS rd
  WHERE rd.id = v_inviter_role_id
    AND rd.version = v_inviter_role_version;
  IF NOT FOUND
     OR v_role_status <> 'active'
     OR NOT (
       (
         v_inviter_role_org_id IS NULL
         AND (
           v_role_applicable_type = 'any'
           OR v_role_applicable_type = v_org_type
         )
       )
       OR (
         v_inviter_role_org_id = p_organization_id
         AND v_inviter_role_org_type = v_org_type
       )
     )
  THEN
    RAISE EXCEPTION 'creator_role_not_active';
  END IF;

  SELECT COALESCE(
    pg_catalog.bool_or(
      rp.is_granted
      AND p.is_active
      AND p.permission_key = 'member.invite'
    ),
    false
  )
    INTO v_has_invite
  FROM public.role_permissions AS rp
  JOIN public.permissions AS p ON p.id = rp.permission_id
  WHERE rp.role_definition_id = v_inviter_role_id
    AND rp.role_version = v_inviter_role_version;
  IF NOT v_has_invite THEN
    RAISE EXCEPTION 'member_invite_required';
  END IF;

  SELECT rd.scope_type, rd.organization_id, rd.organization_type,
         rd.applicable_organization_type, rd.status, rd.assignable
    INTO v_role_scope_type, v_role_org_id, v_role_org_type,
         v_role_applicable_type, v_role_status, v_role_assignable
  FROM public.role_definitions AS rd
  WHERE rd.id = p_role_definition_id
    AND rd.version = p_role_version;
  IF NOT FOUND
     OR v_role_status <> 'active'
     OR NOT v_role_assignable
     OR v_role_scope_type <> v_scope_type
     OR NOT (
       (
         v_role_org_id IS NULL
         AND (
           v_role_applicable_type = 'any'
           OR v_role_applicable_type = v_org_type
         )
       )
       OR (
         v_role_org_id = p_organization_id
         AND v_role_org_type = v_org_type
       )
     )
  THEN
    RAISE EXCEPTION 'role_not_assignable';
  END IF;

  IF v_scope_type = 'organization' THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.membership_store_scopes AS ms
      WHERE ms.membership_id = v_inviter_membership_id
        AND ms.organization_id = p_organization_id
        AND ms.organization_type = v_org_type
        AND ms.scope_type = 'organization'
        AND ms.store_id IS NULL
        AND ms.status = 'active'
    ) THEN
      RAISE EXCEPTION 'inviter_scope_required';
    END IF;
  ELSE
    SELECT s.status
      INTO v_store_status
    FROM public.stores AS s
    WHERE s.id = p_store_id
      AND s.organization_id = p_organization_id
      AND s.organization_type = v_org_type;
    IF NOT FOUND OR v_store_status <> 'active' THEN
      RAISE EXCEPTION 'store_not_available';
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM public.membership_store_scopes AS ms
      WHERE ms.membership_id = v_inviter_membership_id
        AND ms.organization_id = p_organization_id
        AND ms.organization_type = v_org_type
        AND ms.status = 'active'
        AND (
          (ms.scope_type = 'organization' AND ms.store_id IS NULL)
          OR (ms.scope_type = 'store' AND ms.store_id = p_store_id)
        )
    ) THEN
      RAISE EXCEPTION 'inviter_scope_required';
    END IF;
  END IF;

  v_expires_at := v_now + INTERVAL '24 hours';

  SELECT i.id, i.expires_at, i.created_at,
         i.organization_id, i.organization_type, i.store_id,
         i.role_definition_id, i.role_version,
         i.role_definition_organization_id, i.role_definition_organization_type,
         i.scope_type, i.target_email_normalized, i.idempotency_key,
         i.creator_membership_id, i.creator_user_id,
         i.creator_role_definition_id, i.creator_role_version,
         i.creator_role_organization_id, i.creator_role_organization_type,
         i.creator_membership_status, i.status
    INTO v_existing_id, v_existing_expires_at, v_existing_created_at,
         v_existing_org_id, v_existing_org_type,
         v_existing_store_id, v_existing_role_id, v_existing_role_version,
         v_existing_role_org_id, v_existing_role_org_type, v_existing_scope_type,
         v_existing_target_email, v_existing_idempotency_key,
         v_existing_creator_membership_id, v_existing_creator_user_id,
         v_existing_creator_role_id, v_existing_creator_role_version,
         v_existing_creator_role_org_id, v_existing_creator_role_org_type,
         v_existing_creator_status, v_existing_status
  FROM public.membership_invitations AS i
  WHERE i.creator_membership_id = v_inviter_membership_id
    AND i.idempotency_key = p_idempotency_key;

  IF FOUND THEN
    IF v_existing_org_id <> p_organization_id
       OR v_existing_org_type <> v_org_type
       OR v_existing_store_id IS DISTINCT FROM p_store_id
       OR v_existing_role_id <> p_role_definition_id
       OR v_existing_role_version <> p_role_version
       OR v_existing_role_org_id IS DISTINCT FROM v_role_org_id
       OR v_existing_role_org_type IS DISTINCT FROM v_role_org_type
       OR v_existing_scope_type <> v_scope_type
       OR v_existing_target_email <> v_target_email
       OR v_existing_idempotency_key <> p_idempotency_key
       OR v_existing_creator_membership_id <> v_inviter_membership_id
       OR v_existing_creator_user_id <> v_uid
       OR v_existing_creator_role_id <> v_inviter_role_id
       OR v_existing_creator_role_version <> v_inviter_role_version
       OR v_existing_creator_role_org_id IS DISTINCT FROM v_inviter_role_org_id
       OR v_existing_creator_role_org_type IS DISTINCT FROM v_inviter_role_org_type
       OR v_existing_creator_status <> 'active'
    THEN
      RAISE EXCEPTION 'invitation_idempotency_conflict';
    END IF;
    IF v_existing_status IN ('created', 'sent', 'accepted') THEN
      RETURN QUERY SELECT v_existing_id, v_existing_expires_at;
      RETURN;
    END IF;
    RAISE EXCEPTION 'invitation_already_closed';
  END IF;

  SELECT i.id, i.expires_at, i.created_at,
         i.organization_id, i.organization_type, i.store_id,
         i.role_definition_id, i.role_version,
         i.role_definition_organization_id, i.role_definition_organization_type,
         i.scope_type, i.target_email_normalized, i.idempotency_key,
         i.creator_membership_id, i.creator_user_id,
         i.creator_role_definition_id, i.creator_role_version,
         i.creator_role_organization_id, i.creator_role_organization_type,
         i.creator_membership_status, i.status
    INTO v_existing_id, v_existing_expires_at, v_existing_created_at,
         v_existing_org_id, v_existing_org_type,
         v_existing_store_id, v_existing_role_id, v_existing_role_version,
         v_existing_role_org_id, v_existing_role_org_type, v_existing_scope_type,
         v_existing_target_email, v_existing_idempotency_key,
         v_existing_creator_membership_id, v_existing_creator_user_id,
         v_existing_creator_role_id, v_existing_creator_role_version,
         v_existing_creator_role_org_id, v_existing_creator_role_org_type,
         v_existing_creator_status, v_existing_status
  FROM public.membership_invitations AS i
  WHERE i.creator_membership_id = v_inviter_membership_id
    AND i.organization_id = p_organization_id
    AND i.organization_type = v_org_type
    AND i.store_id IS NOT DISTINCT FROM p_store_id
    AND i.role_definition_id = p_role_definition_id
    AND i.role_version = p_role_version
    AND i.role_definition_organization_id IS NOT DISTINCT FROM v_role_org_id
    AND i.role_definition_organization_type IS NOT DISTINCT FROM v_role_org_type
    AND i.scope_type = v_scope_type
    AND i.target_email_normalized = v_target_email
    AND i.status IN ('created', 'sent');

  IF FOUND AND v_existing_expires_at > v_now THEN
    RETURN QUERY SELECT v_existing_id, v_existing_expires_at;
    RETURN;
  END IF;

  IF FOUND AND v_existing_expires_at <= v_now THEN
    PERFORM pg_catalog.set_config('rebuy.invite.op', 'expire_invitation', true);
    PERFORM pg_catalog.set_config('rebuy.invite.invitation_id', v_existing_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.uid', v_uid::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.email', v_email, true);
    PERFORM pg_catalog.set_config('rebuy.invite.org_id', v_existing_org_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.org_type', v_existing_org_type, true);
    PERFORM pg_catalog.set_config('rebuy.invite.store_id', COALESCE(v_existing_store_id::text, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.scope_type', v_existing_scope_type, true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_id', v_existing_role_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_version', v_existing_role_version::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_org_id', COALESCE(v_existing_role_org_id::text, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_org_type', COALESCE(v_existing_role_org_type, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.target_email', v_existing_target_email, true);
    PERFORM pg_catalog.set_config('rebuy.invite.idempotency_key', v_existing_idempotency_key::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_membership_id', v_existing_creator_membership_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_user_id', v_existing_creator_user_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_role_id', v_existing_creator_role_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_role_version', v_existing_creator_role_version::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_id', COALESCE(v_existing_creator_role_org_id::text, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_type', COALESCE(v_existing_creator_role_org_type, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.expires_at', v_existing_expires_at::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.created_at', v_existing_created_at::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.updated_at', v_now::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'true', true);
    UPDATE public.membership_invitations AS i
    SET status = 'expired',
        updated_at = v_now
    WHERE i.id = v_existing_id
      AND i.status IN ('created', 'sent')
      AND i.expires_at <= v_now;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count <> 1 THEN
      RAISE EXCEPTION 'invitation_conflict_retry';
    END IF;
  END IF;

  SELECT p.status, p.email_normalized
    INTO v_profile_status, v_profile_email
  FROM public.profiles AS p
  WHERE p.user_id = v_uid;
  IF FOUND THEN
    IF v_profile_status <> 'active' OR v_profile_email <> v_email THEN
      RAISE EXCEPTION 'profile_not_ready';
    END IF;
  ELSE
    PERFORM pg_catalog.set_config('rebuy.invite.op', 'profile_insert', true);
    PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'true', true);
    PERFORM pg_catalog.set_config('rebuy.invite.uid', v_uid::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.email', v_email, true);
    BEGIN
      INSERT INTO public.profiles (user_id, email_normalized, status)
      VALUES (v_uid, v_email, 'active');
    EXCEPTION WHEN unique_violation THEN
      NULL;
    END;
    SELECT p.status, p.email_normalized
      INTO v_profile_status, v_profile_email
    FROM public.profiles AS p
    WHERE p.user_id = v_uid;
    IF NOT FOUND OR v_profile_status <> 'active' OR v_profile_email <> v_email THEN
      RAISE EXCEPTION 'profile_not_ready';
    END IF;
  END IF;

  <<insert_invitation>>
  LOOP
    v_new_invitation_id := pg_catalog.gen_random_uuid();
    PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'true', true);
    PERFORM pg_catalog.set_config('rebuy.invite.op', 'create_invitation', true);
    PERFORM pg_catalog.set_config('rebuy.invite.invitation_id', v_new_invitation_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.uid', v_uid::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.email', v_email, true);
    PERFORM pg_catalog.set_config('rebuy.invite.org_id', p_organization_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.org_type', v_org_type, true);
    PERFORM pg_catalog.set_config('rebuy.invite.store_id', COALESCE(p_store_id::text, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.scope_type', v_scope_type, true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_id', p_role_definition_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_version', p_role_version::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_org_id', COALESCE(v_role_org_id::text, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_org_type', COALESCE(v_role_org_type, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_membership_id', v_inviter_membership_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_user_id', v_uid::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_role_id', v_inviter_role_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_role_version', v_inviter_role_version::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_id', COALESCE(v_inviter_role_org_id::text, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_type', COALESCE(v_inviter_role_org_type, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.target_email', v_target_email, true);
    PERFORM pg_catalog.set_config('rebuy.invite.idempotency_key', p_idempotency_key::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.expires_at', v_expires_at::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.created_at', v_now::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.updated_at', v_now::text, true);

    BEGIN
      INSERT INTO public.membership_invitations (
        id, organization_id, organization_type, store_id,
        role_definition_id, role_version,
        role_definition_organization_id, role_definition_organization_type,
        scope_type, target_email_normalized, idempotency_key,
        creator_membership_id, creator_user_id,
        creator_role_definition_id, creator_role_version,
        creator_role_organization_id, creator_role_organization_type,
        creator_membership_status, status, expires_at, created_at, updated_at
      )
      VALUES (
        v_new_invitation_id, p_organization_id, v_org_type, p_store_id,
        p_role_definition_id, p_role_version, v_role_org_id, v_role_org_type,
        v_scope_type, v_target_email, p_idempotency_key,
        v_inviter_membership_id, v_uid, v_inviter_role_id, v_inviter_role_version,
        v_inviter_role_org_id, v_inviter_role_org_type, 'active', 'sent',
        v_expires_at, v_now, v_now
      );
    EXCEPTION WHEN unique_violation THEN
      SELECT i.id, i.expires_at, i.created_at,
           i.organization_id, i.organization_type, i.store_id,
           i.role_definition_id, i.role_version,
           i.role_definition_organization_id, i.role_definition_organization_type,
           i.scope_type, i.target_email_normalized, i.idempotency_key,
           i.creator_membership_id, i.creator_user_id,
           i.creator_role_definition_id, i.creator_role_version,
           i.creator_role_organization_id, i.creator_role_organization_type,
           i.creator_membership_status, i.status
      INTO v_existing_id, v_existing_expires_at, v_existing_created_at,
           v_existing_org_id, v_existing_org_type,
           v_existing_store_id, v_existing_role_id, v_existing_role_version,
           v_existing_role_org_id, v_existing_role_org_type, v_existing_scope_type,
           v_existing_target_email, v_existing_idempotency_key,
           v_existing_creator_membership_id, v_existing_creator_user_id,
           v_existing_creator_role_id, v_existing_creator_role_version,
           v_existing_creator_role_org_id, v_existing_creator_role_org_type,
           v_existing_creator_status, v_existing_status
    FROM public.membership_invitations AS i
    WHERE i.creator_membership_id = v_inviter_membership_id
      AND (
        i.idempotency_key = p_idempotency_key
        OR (
          i.organization_id = p_organization_id
          AND i.organization_type = v_org_type
          AND i.store_id IS NOT DISTINCT FROM p_store_id
          AND i.role_definition_id = p_role_definition_id
          AND i.role_version = p_role_version
          AND i.role_definition_organization_id IS NOT DISTINCT FROM v_role_org_id
          AND i.role_definition_organization_type IS NOT DISTINCT FROM v_role_org_type
          AND i.scope_type = v_scope_type
          AND i.target_email_normalized = v_target_email
          AND i.status IN ('created', 'sent')
        )
      )
    ORDER BY i.id
    LIMIT 1;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'invitation_conflict_retry';
    END IF;

    IF v_existing_idempotency_key = p_idempotency_key THEN
      IF v_existing_org_id <> p_organization_id
         OR v_existing_org_type <> v_org_type
         OR v_existing_store_id IS DISTINCT FROM p_store_id
         OR v_existing_role_id <> p_role_definition_id
         OR v_existing_role_version <> p_role_version
         OR v_existing_role_org_id IS DISTINCT FROM v_role_org_id
         OR v_existing_role_org_type IS DISTINCT FROM v_role_org_type
         OR v_existing_scope_type <> v_scope_type
         OR v_existing_target_email <> v_target_email
         OR v_existing_creator_membership_id <> v_inviter_membership_id
         OR v_existing_creator_user_id <> v_uid
         OR v_existing_creator_role_id <> v_inviter_role_id
         OR v_existing_creator_role_version <> v_inviter_role_version
         OR v_existing_creator_role_org_id IS DISTINCT FROM v_inviter_role_org_id
         OR v_existing_creator_role_org_type IS DISTINCT FROM v_inviter_role_org_type
      THEN
        RAISE EXCEPTION 'invitation_idempotency_conflict';
      END IF;
      IF v_existing_status IN ('created', 'sent', 'accepted') THEN
        RETURN QUERY SELECT v_existing_id, v_existing_expires_at;
        RETURN;
      END IF;
      RAISE EXCEPTION 'invitation_already_closed';
    END IF;

    IF v_existing_status IN ('created', 'sent')
       AND v_existing_expires_at > v_now
    THEN
      RETURN QUERY SELECT v_existing_id, v_existing_expires_at;
      RETURN;
    END IF;
    IF v_existing_status IN ('created', 'sent')
       AND v_existing_expires_at <= v_now
    THEN
      PERFORM pg_catalog.set_config('rebuy.invite.op', 'expire_invitation', true);
      PERFORM pg_catalog.set_config('rebuy.invite.invitation_id', v_existing_id::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.org_id', v_existing_org_id::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.org_type', v_existing_org_type, true);
      PERFORM pg_catalog.set_config('rebuy.invite.store_id', COALESCE(v_existing_store_id::text, ''), true);
      PERFORM pg_catalog.set_config('rebuy.invite.scope_type', v_existing_scope_type, true);
      PERFORM pg_catalog.set_config('rebuy.invite.role_id', v_existing_role_id::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.role_version', v_existing_role_version::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.role_org_id', COALESCE(v_existing_role_org_id::text, ''), true);
      PERFORM pg_catalog.set_config('rebuy.invite.role_org_type', COALESCE(v_existing_role_org_type, ''), true);
      PERFORM pg_catalog.set_config('rebuy.invite.target_email', v_existing_target_email, true);
      PERFORM pg_catalog.set_config('rebuy.invite.idempotency_key', v_existing_idempotency_key::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.creator_membership_id', v_existing_creator_membership_id::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.creator_user_id', v_existing_creator_user_id::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.creator_role_id', v_existing_creator_role_id::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.creator_role_version', v_existing_creator_role_version::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_id', COALESCE(v_existing_creator_role_org_id::text, ''), true);
      PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_type', COALESCE(v_existing_creator_role_org_type, ''), true);
      PERFORM pg_catalog.set_config('rebuy.invite.expires_at', v_existing_expires_at::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.created_at', v_existing_created_at::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.updated_at', v_now::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'true', true);
      UPDATE public.membership_invitations AS i
      SET status = 'expired',
          updated_at = v_now
      WHERE i.id = v_existing_id
        AND i.status IN ('created', 'sent')
        AND i.expires_at <= v_now;
      GET DIAGNOSTICS v_row_count = ROW_COUNT;
      IF v_row_count <> 1 THEN
        RAISE EXCEPTION 'invitation_conflict_retry';
      END IF;
      CONTINUE insert_invitation;
    END IF;
    RAISE EXCEPTION 'invitation_conflict_retry';
    END;

  PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'true', true);
  PERFORM pg_catalog.set_config('rebuy.invite.op', 'create_audit', true);
  PERFORM pg_catalog.set_config('rebuy.invite.audit_id', pg_catalog.gen_random_uuid()::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.event_code', 'membership_invitation.created', true);
  PERFORM pg_catalog.set_config('rebuy.invite.outcome', 'success', true);
  INSERT INTO public.audit_logs (
    id, event_code, outcome, actor_user_id, organization_id, organization_type,
    store_id, invitation_id, membership_id, created_at
  )
  VALUES (
    NULLIF(pg_catalog.current_setting('rebuy.invite.audit_id', true), '')::uuid,
    'membership_invitation.created', 'success', v_uid, p_organization_id, v_org_type,
    p_store_id, v_new_invitation_id, NULL, v_now
  );

  RETURN QUERY SELECT v_new_invitation_id, v_expires_at;
  RETURN;
  END LOOP;
END
$function$;

CREATE OR REPLACE FUNCTION private.accept_membership_invitation_impl(
  p_invitation_id uuid
)
RETURNS TABLE (
  membership_id uuid,
  organization_id uuid,
  store_id uuid,
  scope_type text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_claims jsonb;
  v_amr jsonb;
  v_uid uuid;
  v_email text;
  v_otp_timestamp numeric;
  v_now timestamptz;
  v_now_epoch numeric;
  v_org_type text;
  v_org_status text;
  v_invitation_org_id uuid;
  v_invitation_store_id uuid;
  v_invitation_role_id uuid;
  v_invitation_role_version integer;
  v_invitation_role_org_id uuid;
  v_invitation_role_org_type text;
  v_invitation_scope_type text;
  v_target_email text;
  v_invitation_idempotency_key uuid;
  v_invitation_status text;
  v_expires_at timestamptz;
  v_invitation_created_at timestamptz;
  v_creator_membership_id uuid;
  v_creator_user_id uuid;
  v_creator_role_id uuid;
  v_creator_role_version integer;
  v_creator_role_org_id uuid;
  v_creator_role_org_type text;
  v_creator_membership_status text;
  v_accepted_user_id uuid;
  v_accepted_membership_id uuid;
  v_revoked_at timestamptz;
  v_consumed_at timestamptz;
  v_role_scope_type text;
  v_role_org_id uuid;
  v_role_org_type text;
  v_role_applicable_type text;
  v_role_status text;
  v_role_assignable boolean;
  v_creator_role_current_org_id uuid;
  v_creator_role_current_org_type text;
  v_creator_role_current_status text;
  v_creator_role_current_applicable_type text;
  v_creator_user_from_membership uuid;
  v_creator_role_from_membership uuid;
  v_creator_version_from_membership integer;
  v_creator_status_from_membership text;
  v_creator_role_org_from_membership uuid;
  v_creator_role_org_type_from_membership text;
  v_has_invite boolean;
  v_store_status text;
  v_existing_membership_id uuid;
  v_scope_count bigint;
  v_new_membership_id uuid;
  v_new_scope_id uuid;
  v_profile_status text;
  v_profile_email text;
BEGIN
  PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'false', true);
  PERFORM pg_catalog.set_config('rebuy.invite.op', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.uid', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.email', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.invitation_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.member_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.scope_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.audit_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.org_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.org_type', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.store_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.scope_type', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_version', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_org_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_org_type', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_membership_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_user_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_version', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_type', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.target_email', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.idempotency_key', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.expires_at', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.valid_from', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.consumed_at', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.created_at', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.updated_at', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.event_code', '', true);
  PERFORM pg_catalog.set_config('rebuy.invite.outcome', '', true);

  v_claims := private.rebuy_request_jwt();
  v_uid := private.rebuy_request_uid();
  v_now := pg_catalog.statement_timestamp();

  IF v_uid IS NULL
     OR (v_claims -> 'is_anonymous') IS DISTINCT FROM 'false'::jsonb
  THEN
    RAISE EXCEPTION 'recent_otp_required';
  END IF;
  IF pg_catalog.jsonb_typeof(v_claims -> 'amr') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'recent_otp_required';
  END IF;
  IF pg_catalog.jsonb_array_length(v_claims -> 'amr') < 1 THEN
    RAISE EXCEPTION 'recent_otp_required';
  END IF;
  v_amr := v_claims -> 'amr' -> 0;
  IF pg_catalog.jsonb_typeof(v_amr) IS DISTINCT FROM 'object'
     OR (v_amr ->> 'method') IS DISTINCT FROM 'otp'
     OR pg_catalog.jsonb_typeof(v_amr -> 'timestamp') IS DISTINCT FROM 'number'
  THEN
    RAISE EXCEPTION 'recent_otp_required';
  END IF;
  BEGIN
    v_otp_timestamp := (v_amr ->> 'timestamp')::numeric;
  EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'recent_otp_required';
  END;
  v_now_epoch := EXTRACT(epoch FROM v_now)::numeric;
  IF v_otp_timestamp < v_now_epoch - 600
     OR v_otp_timestamp > v_now_epoch + 60
  THEN
    RAISE EXCEPTION 'recent_otp_required';
  END IF;

  v_email := v_claims ->> 'email';
  IF v_email IS NULL
     OR v_email IS DISTINCT FROM pg_catalog.lower(pg_catalog.btrim(v_email))
     OR v_email !~ '^[a-z0-9][-a-z0-9._%+]*@rebuy[.]test$'
  THEN
    RAISE EXCEPTION 'synthetic_email_required';
  END IF;

  SELECT i.organization_id, i.organization_type, i.store_id,
         i.role_definition_id, i.role_version,
         i.role_definition_organization_id, i.role_definition_organization_type,
         i.scope_type, i.target_email_normalized, i.idempotency_key,
         i.status, i.expires_at,
         i.created_at, i.creator_membership_id, i.creator_user_id,
         i.creator_role_definition_id, i.creator_role_version,
         i.creator_role_organization_id, i.creator_role_organization_type,
         i.creator_membership_status, i.accepted_user_id,
         i.accepted_membership_id, i.revoked_at, i.consumed_at
    INTO v_invitation_org_id, v_org_type, v_invitation_store_id,
         v_invitation_role_id, v_invitation_role_version,
         v_invitation_role_org_id, v_invitation_role_org_type,
         v_invitation_scope_type, v_target_email,
         v_invitation_idempotency_key, v_invitation_status,
         v_expires_at, v_invitation_created_at, v_creator_membership_id,
         v_creator_user_id, v_creator_role_id, v_creator_role_version,
         v_creator_role_org_id, v_creator_role_org_type,
         v_creator_membership_status, v_accepted_user_id,
         v_accepted_membership_id, v_revoked_at, v_consumed_at
  FROM public.membership_invitations AS i
  WHERE i.id = p_invitation_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invitation_not_available';
  END IF;

  IF v_target_email <> v_email THEN
    RAISE EXCEPTION 'invitation_email_mismatch';
  END IF;

  IF v_invitation_status = 'accepted' THEN
    IF v_accepted_user_id IS DISTINCT FROM v_uid
       OR v_accepted_membership_id IS NULL
       OR v_consumed_at IS NULL
       OR v_revoked_at IS NOT NULL
    THEN
      RAISE EXCEPTION 'invitation_already_consumed';
    END IF;

    PERFORM pg_catalog.set_config('rebuy.invite.op', 'accept_replay', true);
    PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'false', true);
    PERFORM pg_catalog.set_config('rebuy.invite.uid', v_uid::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.email', v_email, true);
    PERFORM pg_catalog.set_config('rebuy.invite.invitation_id', p_invitation_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.member_id', v_accepted_membership_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.org_id', v_invitation_org_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.org_type', v_org_type, true);
    PERFORM pg_catalog.set_config('rebuy.invite.store_id', COALESCE(v_invitation_store_id::text, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.scope_type', v_invitation_scope_type, true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_id', v_invitation_role_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_version', v_invitation_role_version::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_org_id', COALESCE(v_invitation_role_org_id::text, ''), true);
    PERFORM pg_catalog.set_config('rebuy.invite.role_org_type', COALESCE(v_invitation_role_org_type, ''), true);

    SELECT m.id
      INTO v_existing_membership_id
    FROM public.memberships AS m
    WHERE m.id = v_accepted_membership_id
      AND m.user_id = v_uid
      AND m.organization_id = v_invitation_org_id
      AND m.organization_type = v_org_type
      AND m.role_definition_id = v_invitation_role_id
      AND m.role_version = v_invitation_role_version
      AND m.role_definition_organization_id IS NOT DISTINCT FROM v_invitation_role_org_id
      AND m.role_definition_organization_type IS NOT DISTINCT FROM v_invitation_role_org_type
      AND m.source_invitation_id = p_invitation_id
      AND m.status = 'active'
      AND m.valid_from <= v_now
      AND (m.valid_until IS NULL OR m.valid_until > v_now)
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'accepted_membership_not_active';
    END IF;

    SELECT pg_catalog.count(*)
      INTO v_scope_count
    FROM public.membership_store_scopes AS ms
    WHERE ms.membership_id = v_existing_membership_id
      AND ms.organization_id = v_invitation_org_id
      AND ms.organization_type = v_org_type
      AND ms.scope_type = v_invitation_scope_type
      AND ms.store_id IS NOT DISTINCT FROM v_invitation_store_id
      AND ms.status = 'active';
    IF v_scope_count <> 1 THEN
      RAISE EXCEPTION 'accepted_scope_not_active';
    END IF;

    SELECT p.status, p.email_normalized
      INTO v_profile_status, v_profile_email
    FROM public.profiles AS p
    WHERE p.user_id = v_uid;
    IF FOUND THEN
      IF v_profile_status <> 'active' OR v_profile_email <> v_email THEN
        RAISE EXCEPTION 'profile_not_ready';
      END IF;
    ELSE
      PERFORM pg_catalog.set_config('rebuy.invite.op', 'profile_insert', true);
      PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'true', true);
      PERFORM pg_catalog.set_config('rebuy.invite.uid', v_uid::text, true);
      PERFORM pg_catalog.set_config('rebuy.invite.email', v_email, true);
      INSERT INTO public.profiles (user_id, email_normalized, status)
      VALUES (v_uid, v_email, 'active');
    END IF;

    RETURN QUERY SELECT v_existing_membership_id, v_invitation_org_id,
                        v_invitation_store_id, v_invitation_scope_type;
    RETURN;
  END IF;

  IF v_invitation_status NOT IN ('created', 'sent')
     OR v_expires_at <= v_now
     OR v_accepted_user_id IS NOT NULL
     OR v_accepted_membership_id IS NOT NULL
     OR v_revoked_at IS NOT NULL
     OR v_consumed_at IS NOT NULL
  THEN
    RAISE EXCEPTION 'invitation_not_available';
  END IF;

  -- The invitation row is already locked. Serialize all first accepts for the
  -- same target and organization before locking the creator membership.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      pg_catalog.concat(v_uid::text, ':', v_invitation_org_id::text),
      0
    )
  );

  PERFORM pg_catalog.set_config('rebuy.invite.op', 'accept_validate', true);
  PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'false', true);
  PERFORM pg_catalog.set_config('rebuy.invite.uid', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.email', v_email, true);
  PERFORM pg_catalog.set_config('rebuy.invite.invitation_id', p_invitation_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.org_id', v_invitation_org_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.org_type', v_org_type, true);
  PERFORM pg_catalog.set_config('rebuy.invite.store_id', COALESCE(v_invitation_store_id::text, ''), true);
  PERFORM pg_catalog.set_config('rebuy.invite.scope_type', v_invitation_scope_type, true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_id', v_invitation_role_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_version', v_invitation_role_version::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_org_id', COALESCE(v_invitation_role_org_id::text, ''), true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_org_type', COALESCE(v_invitation_role_org_type, ''), true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_membership_id', v_creator_membership_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_user_id', v_creator_user_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_id', v_creator_role_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_version', v_creator_role_version::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_id', COALESCE(v_creator_role_org_id::text, ''), true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_type', COALESCE(v_creator_role_org_type, ''), true);
  PERFORM pg_catalog.set_config('rebuy.invite.target_email', v_target_email, true);
  PERFORM pg_catalog.set_config('rebuy.invite.expires_at', v_expires_at::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.created_at', v_invitation_created_at::text, true);

  SELECT o.status
    INTO v_org_status
  FROM public.organizations AS o
  WHERE o.id = v_invitation_org_id
    AND o.organization_type = v_org_type;
  IF NOT FOUND OR v_org_status <> 'active' THEN
    RAISE EXCEPTION 'organization_not_available';
  END IF;

  SELECT rd.scope_type, rd.organization_id, rd.organization_type,
         rd.applicable_organization_type, rd.status, rd.assignable
    INTO v_role_scope_type, v_role_org_id, v_role_org_type,
         v_role_applicable_type, v_role_status, v_role_assignable
  FROM public.role_definitions AS rd
  WHERE rd.id = v_invitation_role_id
    AND rd.version = v_invitation_role_version;
  IF NOT FOUND
     OR v_role_status <> 'active'
     OR NOT v_role_assignable
     OR v_role_scope_type <> v_invitation_scope_type
     OR v_role_org_id IS DISTINCT FROM v_invitation_role_org_id
     OR v_role_org_type IS DISTINCT FROM v_invitation_role_org_type
     OR NOT (
       (
         v_role_org_id IS NULL
         AND (
           v_role_applicable_type = 'any'
           OR v_role_applicable_type = v_org_type
         )
       )
       OR (
         v_role_org_id = v_invitation_org_id
         AND v_role_org_type = v_org_type
       )
     )
  THEN
    RAISE EXCEPTION 'role_not_assignable';
  END IF;

  SELECT m.user_id, m.role_definition_id, m.role_version, m.status,
         m.role_definition_organization_id, m.role_definition_organization_type
    INTO v_creator_user_from_membership, v_creator_role_from_membership,
         v_creator_version_from_membership, v_creator_status_from_membership,
         v_creator_role_org_from_membership, v_creator_role_org_type_from_membership
  FROM public.memberships AS m
  WHERE m.id = v_creator_membership_id
    AND m.user_id = v_creator_user_id
    AND m.organization_id = v_invitation_org_id
    AND m.organization_type = v_org_type
  FOR UPDATE;
  IF NOT FOUND
     OR v_creator_user_from_membership <> v_creator_user_id
     OR v_creator_status_from_membership <> 'active'
     OR v_creator_status_from_membership IS NULL
     OR v_creator_role_from_membership <> v_creator_role_id
     OR v_creator_version_from_membership <> v_creator_role_version
     OR v_creator_role_org_from_membership IS DISTINCT FROM v_creator_role_org_id
     OR v_creator_role_org_type_from_membership IS DISTINCT FROM v_creator_role_org_type
     OR v_creator_membership_status <> 'active'
  THEN
    RAISE EXCEPTION 'creator_membership_not_active';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships AS m
    WHERE m.id = v_creator_membership_id
      AND m.valid_from <= v_now
      AND (m.valid_until IS NULL OR m.valid_until > v_now)
  ) THEN
    RAISE EXCEPTION 'creator_membership_not_active';
  END IF;

  SELECT rd.organization_id, rd.organization_type, rd.status,
         rd.applicable_organization_type
    INTO v_creator_role_current_org_id, v_creator_role_current_org_type,
         v_creator_role_current_status, v_creator_role_current_applicable_type
  FROM public.role_definitions AS rd
  WHERE rd.id = v_creator_role_from_membership
    AND rd.version = v_creator_version_from_membership;
  IF NOT FOUND
     OR v_creator_role_current_status <> 'active'
     OR NOT (
       (
         v_creator_role_current_org_id IS NULL
         AND (
           v_creator_role_current_applicable_type = 'any'
           OR v_creator_role_current_applicable_type = v_org_type
         )
       )
       OR (
         v_creator_role_current_org_id = v_invitation_org_id
         AND v_creator_role_current_org_type = v_org_type
       )
     )
  THEN
    RAISE EXCEPTION 'creator_role_not_active';
  END IF;

  SELECT COALESCE(
    pg_catalog.bool_or(
      rp.is_granted
      AND p.is_active
      AND p.permission_key = 'member.invite'
    ),
    false
  )
    INTO v_has_invite
  FROM public.role_permissions AS rp
  JOIN public.permissions AS p ON p.id = rp.permission_id
  WHERE rp.role_definition_id = v_creator_role_from_membership
    AND rp.role_version = v_creator_version_from_membership;
  IF NOT v_has_invite THEN
    RAISE EXCEPTION 'creator_permission_revoked';
  END IF;

  IF v_invitation_scope_type = 'organization' THEN
    IF v_invitation_store_id IS NOT NULL THEN
      RAISE EXCEPTION 'invalid_invitation_scope';
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM public.membership_store_scopes AS ms
      WHERE ms.membership_id = v_creator_membership_id
        AND ms.organization_id = v_invitation_org_id
        AND ms.organization_type = v_org_type
        AND ms.scope_type = 'organization'
        AND ms.store_id IS NULL
        AND ms.status = 'active'
    ) THEN
      RAISE EXCEPTION 'creator_scope_not_active';
    END IF;
  ELSE
    IF v_invitation_store_id IS NULL THEN
      RAISE EXCEPTION 'invalid_invitation_scope';
    END IF;
    SELECT s.status
      INTO v_store_status
    FROM public.stores AS s
    WHERE s.id = v_invitation_store_id
      AND s.organization_id = v_invitation_org_id
      AND s.organization_type = v_org_type;
    IF NOT FOUND OR v_store_status <> 'active' THEN
      RAISE EXCEPTION 'store_not_available';
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM public.membership_store_scopes AS ms
      WHERE ms.membership_id = v_creator_membership_id
        AND ms.organization_id = v_invitation_org_id
        AND ms.organization_type = v_org_type
        AND ms.status = 'active'
        AND (
          (ms.scope_type = 'organization' AND ms.store_id IS NULL)
          OR (ms.scope_type = 'store' AND ms.store_id = v_invitation_store_id)
        )
    ) THEN
      RAISE EXCEPTION 'creator_scope_not_active';
    END IF;
  END IF;

  SELECT m.id
    INTO v_existing_membership_id
  FROM public.memberships AS m
  WHERE m.user_id = v_uid
    AND m.organization_id = v_invitation_org_id
    AND m.organization_type = v_org_type
  FOR UPDATE;
  IF FOUND THEN
    RAISE EXCEPTION 'membership_already_exists';
  END IF;

  SELECT p.status, p.email_normalized
    INTO v_profile_status, v_profile_email
  FROM public.profiles AS p
  WHERE p.user_id = v_uid;
  IF FOUND THEN
    IF v_profile_status <> 'active' OR v_profile_email <> v_email THEN
      RAISE EXCEPTION 'profile_not_ready';
    END IF;
  ELSE
    PERFORM pg_catalog.set_config('rebuy.invite.op', 'profile_insert', true);
    PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'true', true);
    PERFORM pg_catalog.set_config('rebuy.invite.uid', v_uid::text, true);
    PERFORM pg_catalog.set_config('rebuy.invite.email', v_email, true);
    BEGIN
      INSERT INTO public.profiles (user_id, email_normalized, status)
      VALUES (v_uid, v_email, 'active');
    EXCEPTION WHEN unique_violation THEN
      NULL;
    END;
    SELECT p.status, p.email_normalized
      INTO v_profile_status, v_profile_email
    FROM public.profiles AS p
    WHERE p.user_id = v_uid;
    IF NOT FOUND OR v_profile_status <> 'active' OR v_profile_email <> v_email THEN
      RAISE EXCEPTION 'profile_not_ready';
    END IF;
  END IF;

  v_new_membership_id := pg_catalog.gen_random_uuid();
  v_new_scope_id := pg_catalog.gen_random_uuid();
  PERFORM pg_catalog.set_config('rebuy.invite.authorized', 'true', true);
  PERFORM pg_catalog.set_config('rebuy.invite.op', 'accept_membership', true);
  PERFORM pg_catalog.set_config('rebuy.invite.uid', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.email', v_email, true);
  PERFORM pg_catalog.set_config('rebuy.invite.invitation_id', p_invitation_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.member_id', v_new_membership_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.scope_id', v_new_scope_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.org_id', v_invitation_org_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.org_type', v_org_type, true);
  PERFORM pg_catalog.set_config('rebuy.invite.store_id', COALESCE(v_invitation_store_id::text, ''), true);
  PERFORM pg_catalog.set_config('rebuy.invite.scope_type', v_invitation_scope_type, true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_id', v_invitation_role_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_version', v_invitation_role_version::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_org_id', COALESCE(v_invitation_role_org_id::text, ''), true);
  PERFORM pg_catalog.set_config('rebuy.invite.role_org_type', COALESCE(v_invitation_role_org_type, ''), true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_membership_id', v_creator_membership_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_user_id', v_creator_user_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_id', v_creator_role_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_version', v_creator_role_version::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_id', COALESCE(v_creator_role_org_id::text, ''), true);
  PERFORM pg_catalog.set_config('rebuy.invite.creator_role_org_type', COALESCE(v_creator_role_org_type, ''), true);
  PERFORM pg_catalog.set_config('rebuy.invite.target_email', v_target_email, true);
  PERFORM pg_catalog.set_config('rebuy.invite.expires_at', v_expires_at::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.valid_from', v_now::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.created_at', v_now::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.updated_at', v_now::text, true);

  BEGIN
    INSERT INTO public.memberships (
      id, user_id, organization_id, organization_type,
      role_definition_id, role_version,
      role_definition_organization_id, role_definition_organization_type,
      status, invited_by, source_invitation_id, valid_from, created_at, updated_at
    )
    VALUES (
      v_new_membership_id, v_uid, v_invitation_org_id, v_org_type,
      v_invitation_role_id, v_invitation_role_version,
      v_invitation_role_org_id, v_invitation_role_org_type,
      'active', v_creator_user_id, p_invitation_id, v_now, v_now, v_now
    );
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'membership_already_exists';
  END;

  PERFORM pg_catalog.set_config('rebuy.invite.op', 'accept_scope', true);
  INSERT INTO public.membership_store_scopes (
    id, membership_id, organization_id, organization_type,
    store_id, scope_type, status, created_at
  )
  VALUES (
    v_new_scope_id, v_new_membership_id, v_invitation_org_id, v_org_type,
    v_invitation_store_id, v_invitation_scope_type, 'active', v_now
  );

  PERFORM pg_catalog.set_config('rebuy.invite.op', 'accept_invitation', true);
  PERFORM pg_catalog.set_config(
    'rebuy.invite.idempotency_key', v_invitation_idempotency_key::text, true
  );
  PERFORM pg_catalog.set_config('rebuy.invite.consumed_at', v_now::text, true);
  PERFORM pg_catalog.set_config(
    'rebuy.invite.created_at', v_invitation_created_at::text, true
  );
  PERFORM pg_catalog.set_config('rebuy.invite.updated_at', v_now::text, true);
  UPDATE public.membership_invitations
  SET status = 'accepted',
      accepted_user_id = v_uid,
      accepted_membership_id = v_new_membership_id,
      consumed_at = v_now,
      updated_at = v_now
  WHERE id = p_invitation_id
    AND status IN ('created', 'sent');
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invitation_not_available';
  END IF;

  PERFORM pg_catalog.set_config('rebuy.invite.op', 'accept_audit', true);
  PERFORM pg_catalog.set_config('rebuy.invite.audit_id', pg_catalog.gen_random_uuid()::text, true);
  PERFORM pg_catalog.set_config('rebuy.invite.event_code', 'membership_invitation.accepted', true);
  PERFORM pg_catalog.set_config('rebuy.invite.outcome', 'success', true);
  PERFORM pg_catalog.set_config('rebuy.invite.created_at', v_now::text, true);
  INSERT INTO public.audit_logs (
    id, event_code, outcome, actor_user_id, organization_id, organization_type,
    store_id, invitation_id, membership_id, created_at
  )
  VALUES (
    NULLIF(pg_catalog.current_setting('rebuy.invite.audit_id', true), '')::uuid,
    'membership_invitation.accepted', 'success', v_uid, v_invitation_org_id, v_org_type,
    v_invitation_store_id, p_invitation_id, v_new_membership_id, v_now
  );

  RETURN QUERY SELECT v_new_membership_id, v_invitation_org_id,
                      v_invitation_store_id, v_invitation_scope_type;
END
$function$;

CREATE OR REPLACE FUNCTION public.create_membership_invitation(
  p_organization_id uuid,
  p_role_definition_id uuid,
  p_role_version integer,
  p_scope_type text,
  p_store_id uuid,
  p_target_email text,
  p_idempotency_key uuid
)
RETURNS TABLE (
  invitation_id uuid,
  expires_at timestamptz
)
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT i.invitation_id, i.expires_at
  FROM private.create_membership_invitation_impl(
    p_organization_id,
    p_role_definition_id,
    p_role_version,
    p_scope_type,
    p_store_id,
    p_target_email,
    p_idempotency_key
  ) AS i
$function$;

CREATE OR REPLACE FUNCTION public.accept_membership_invitation(
  p_invitation_id uuid
)
RETURNS TABLE (
  membership_id uuid,
  organization_id uuid,
  store_id uuid,
  scope_type text
)
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT a.membership_id, a.organization_id, a.store_id, a.scope_type
  FROM private.accept_membership_invitation_impl(p_invitation_id) AS a
$function$;

ALTER FUNCTION public.create_membership_invitation(
  uuid, uuid, integer, text, uuid, text, uuid
) OWNER TO postgres;
ALTER FUNCTION public.accept_membership_invitation(uuid) OWNER TO postgres;

-- Establish the implementation ACL while postgres still owns both functions;
-- the ACL is preserved when the atomic handoff changes their owner.
REVOKE ALL PRIVILEGES ON FUNCTION private.create_membership_invitation_impl(
  uuid, uuid, integer, text, uuid, text, uuid
) FROM PUBLIC, anon, authenticated, rebuy_invite_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.accept_membership_invitation_impl(uuid)
  FROM PUBLIC, anon, authenticated, rebuy_invite_executor;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.create_membership_invitation_impl(
  uuid, uuid, integer, text, uuid, text, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION private.accept_membership_invitation_impl(uuid)
  TO authenticated;

-- PostgreSQL requires the migration runner to be able to SET ROLE to a new
-- function owner, and requires that owner to have CREATE on the schema. Keep
-- both capabilities inside one atomic statement and prove their removal before
-- the statement can complete.
DO $owner_handoff$
BEGIN
  IF (
    SELECT count(*)
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_invite_executor'
       OR member_role.rolname = 'rebuy_invite_executor'
  ) <> 1 OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_invite_executor'
      AND member_role.rolname = 'postgres'
      AND grantor_role.rolname = 'supabase_admin'
      AND pam.admin_option
      AND NOT pam.inherit_option
      AND NOT pam.set_option
  ) OR EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    WHERE member_role.rolname = 'rebuy_invite_executor'
  ) OR pg_catalog.pg_has_role(
    'postgres', 'rebuy_invite_executor', 'USAGE'
  ) OR pg_catalog.pg_has_role(
    'postgres', 'rebuy_invite_executor', 'SET'
  ) OR pg_catalog.has_schema_privilege(
    'rebuy_invite_executor', 'private', 'CREATE'
  ) THEN
    RAISE EXCEPTION 'rebuy_owner_handoff_precondition_invalid';
  END IF;

  EXECUTE 'GRANT rebuy_invite_executor TO postgres WITH INHERIT FALSE GRANTED BY CURRENT_USER';
  EXECUTE 'GRANT CREATE ON SCHEMA private TO rebuy_invite_executor GRANTED BY CURRENT_USER';

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    WHERE granted_role.rolname = 'rebuy_invite_executor'
       OR member_role.rolname = 'rebuy_invite_executor'
  ) <> 2 OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_invite_executor'
      AND member_role.rolname = 'postgres'
      AND grantor_role.rolname = 'postgres'
      AND NOT pam.admin_option
      AND NOT pam.inherit_option
      AND pam.set_option
  ) OR NOT pg_catalog.pg_has_role(
    'postgres', 'rebuy_invite_executor', 'SET'
  ) OR NOT pg_catalog.has_schema_privilege(
    'rebuy_invite_executor', 'private', 'CREATE'
  ) THEN
    RAISE EXCEPTION 'rebuy_owner_handoff_temporary_capability_invalid';
  END IF;

  EXECUTE 'ALTER FUNCTION private.create_membership_invitation_impl(uuid, uuid, integer, text, uuid, text, uuid) OWNER TO rebuy_invite_executor';
  EXECUTE 'ALTER FUNCTION private.accept_membership_invitation_impl(uuid) OWNER TO rebuy_invite_executor';

  EXECUTE 'REVOKE rebuy_invite_executor FROM postgres GRANTED BY CURRENT_USER';
  EXECUTE 'REVOKE CREATE ON SCHEMA private FROM rebuy_invite_executor GRANTED BY CURRENT_USER';

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_invite_executor'
       OR member_role.rolname = 'rebuy_invite_executor'
  ) <> 1 OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_invite_executor'
      AND member_role.rolname = 'postgres'
      AND grantor_role.rolname = 'supabase_admin'
      AND pam.admin_option
      AND NOT pam.inherit_option
      AND NOT pam.set_option
  ) OR EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    WHERE member_role.rolname = 'rebuy_invite_executor'
  ) OR pg_catalog.pg_has_role(
    'postgres', 'rebuy_invite_executor', 'USAGE'
  ) OR pg_catalog.pg_has_role(
    'postgres', 'rebuy_invite_executor', 'SET'
  ) OR pg_catalog.has_schema_privilege(
    'rebuy_invite_executor', 'private', 'CREATE'
  ) OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    WHERE procedure.oid = pg_catalog.to_regprocedure(
      'private.create_membership_invitation_impl(uuid,uuid,integer,text,uuid,text,uuid)'
    )
      AND pg_catalog.pg_get_userbyid(procedure.proowner) = 'rebuy_invite_executor'
  ) OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS procedure
    WHERE procedure.oid = pg_catalog.to_regprocedure(
      'private.accept_membership_invitation_impl(uuid)'
    )
      AND pg_catalog.pg_get_userbyid(procedure.proowner) = 'rebuy_invite_executor'
  ) THEN
    RAISE EXCEPTION 'rebuy_owner_handoff_final_state_invalid';
  END IF;
END
$owner_handoff$;

REVOKE ALL PRIVILEGES ON FUNCTION public.create_membership_invitation(
  uuid, uuid, integer, text, uuid, text, uuid
) FROM PUBLIC, anon, authenticated, rebuy_invite_executor;
REVOKE ALL PRIVILEGES ON FUNCTION public.accept_membership_invitation(uuid)
  FROM PUBLIC, anon, authenticated, rebuy_invite_executor;
GRANT EXECUTE ON FUNCTION public.create_membership_invitation(
  uuid, uuid, integer, text, uuid, text, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_membership_invitation(uuid)
  TO authenticated;
