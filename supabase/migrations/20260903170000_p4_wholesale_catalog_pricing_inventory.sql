-- P4 synthetic-only wholesale qualification, catalog, pricing and inventory.

DO $executor_guard$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'rebuy_business_executor'
  ) OR EXISTS (
    SELECT 1 FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_business_executor'
      AND (rolsuper OR rolcanlogin OR rolcreatedb OR rolcreaterole OR rolinherit
        OR rolreplication OR rolbypassrls)
  ) THEN
    RAISE EXCEPTION 'rebuy_business_executor_invalid';
  END IF;
END
$executor_guard$;

REVOKE ALL ON SCHEMA public, private FROM rebuy_business_executor;
GRANT USAGE ON SCHEMA public, private TO rebuy_business_executor;

CREATE TABLE public.wholesale_applications (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  applicant_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  company_name text NOT NULL,
  country_code text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  assigned_reviewer_membership_id uuid REFERENCES public.memberships (id),
  assigned_at timestamptz,
  organization_id uuid REFERENCES public.organizations (id),
  owner_membership_id uuid REFERENCES public.memberships (id),
  qualification_id uuid,
  submitted_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT wholesale_applications_id_applicant_key UNIQUE (id, applicant_user_id),
  CONSTRAINT wholesale_applications_company_check CHECK (
    company_name = pg_catalog.btrim(company_name)
    AND pg_catalog.char_length(company_name) BETWEEN 2 AND 80
  ),
  CONSTRAINT wholesale_applications_country_check CHECK (country_code ~ '^[A-Z]{2}$'),
  CONSTRAINT wholesale_applications_status_check CHECK (
    status IN ('draft', 'submitted', 'under_review', 'needs_info', 'approved', 'rejected', 'withdrawn')
  ),
  CONSTRAINT wholesale_applications_assignment_check CHECK (
    (status IN ('under_review', 'needs_info', 'approved', 'rejected')
      AND assigned_reviewer_membership_id IS NOT NULL AND assigned_at IS NOT NULL)
    OR (status IN ('draft', 'submitted', 'withdrawn')
      AND assigned_reviewer_membership_id IS NULL AND assigned_at IS NULL)
  ),
  CONSTRAINT wholesale_applications_approval_check CHECK (
    (status = 'approved' AND organization_id IS NOT NULL
      AND owner_membership_id IS NOT NULL AND qualification_id IS NOT NULL
      AND decided_at IS NOT NULL)
    OR (status <> 'approved' AND organization_id IS NULL
      AND owner_membership_id IS NULL AND qualification_id IS NULL)
  ),
  CONSTRAINT wholesale_applications_submitted_check CHECK (
    (status = 'draft' AND submitted_at IS NULL)
    OR status = 'withdrawn'
    OR (status NOT IN ('draft', 'withdrawn') AND submitted_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX wholesale_applications_one_open_per_applicant
  ON public.wholesale_applications (applicant_user_id)
  WHERE status NOT IN ('approved', 'rejected', 'withdrawn');
CREATE INDEX wholesale_applications_applicant_idx
  ON public.wholesale_applications (applicant_user_id);
CREATE INDEX wholesale_applications_queue_idx
  ON public.wholesale_applications (status, submitted_at, id);
CREATE INDEX wholesale_applications_reviewer_idx
  ON public.wholesale_applications (assigned_reviewer_membership_id, status);
CREATE INDEX wholesale_applications_organization_idx
  ON public.wholesale_applications (organization_id);
CREATE INDEX wholesale_applications_owner_idx
  ON public.wholesale_applications (owner_membership_id);
CREATE INDEX wholesale_applications_qualification_idx
  ON public.wholesale_applications (qualification_id);

CREATE TABLE public.wholesale_application_private (
  application_id uuid PRIMARY KEY,
  applicant_user_id uuid NOT NULL,
  registration_reference text NOT NULL,
  evidence_reference text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT wholesale_application_private_application_fk FOREIGN KEY (
    application_id, applicant_user_id
  ) REFERENCES public.wholesale_applications (id, applicant_user_id) ON DELETE CASCADE,
  CONSTRAINT wholesale_application_private_registration_check CHECK (
    registration_reference ~ '^SYN-[A-Z0-9-]{4,40}$'
  ),
  CONSTRAINT wholesale_application_private_evidence_check CHECK (
    evidence_reference ~ '^synthetic://[a-z0-9][a-z0-9/_-]{2,120}$'
  )
);
CREATE INDEX wholesale_application_private_applicant_idx
  ON public.wholesale_application_private (applicant_user_id);
CREATE INDEX wholesale_application_private_application_applicant_idx
  ON public.wholesale_application_private (application_id, applicant_user_id);

CREATE TABLE public.wholesale_qualifications (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  source_application_id uuid NOT NULL UNIQUE REFERENCES public.wholesale_applications (id),
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'wholesale',
  status text NOT NULL DEFAULT 'active',
  valid_from timestamptz NOT NULL,
  valid_until timestamptz NOT NULL,
  reason_code text NOT NULL,
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT wholesale_qualifications_org_fk FOREIGN KEY (organization_id, organization_type)
    REFERENCES public.organizations (id, organization_type),
  CONSTRAINT wholesale_qualifications_type_check CHECK (organization_type = 'wholesale'),
  CONSTRAINT wholesale_qualifications_status_check CHECK (
    status IN ('active', 'suspended', 'expired', 'revoked')
  ),
  CONSTRAINT wholesale_qualifications_validity_check CHECK (valid_until > valid_from),
  CONSTRAINT wholesale_qualifications_reason_check CHECK (
    reason_code IN ('approved_checks_complete', 'risk_suspension', 'validity_expired', 'policy_revoked')
  ),
  CONSTRAINT wholesale_qualifications_version_check CHECK (version > 0),
  CONSTRAINT wholesale_qualifications_id_org_key UNIQUE (id, organization_id, organization_type)
);
ALTER TABLE public.wholesale_applications
  ADD CONSTRAINT wholesale_applications_qualification_fk
  FOREIGN KEY (qualification_id)
  REFERENCES public.wholesale_qualifications (id);

CREATE UNIQUE INDEX wholesale_qualifications_one_current_org
  ON public.wholesale_qualifications (organization_id)
  WHERE status IN ('active', 'suspended');
CREATE INDEX wholesale_qualifications_org_status_idx
  ON public.wholesale_qualifications (organization_id, status, valid_until);
CREATE INDEX wholesale_qualifications_org_context_idx
  ON public.wholesale_qualifications (organization_id, organization_type);

CREATE TABLE public.wholesale_application_events (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.wholesale_applications (id) ON DELETE CASCADE,
  actor_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  event_code text NOT NULL,
  from_status text,
  to_status text NOT NULL,
  reason_code text,
  assigned_reviewer_membership_id uuid REFERENCES public.memberships (id),
  qualification_id uuid REFERENCES public.wholesale_qualifications (id),
  idempotency_key uuid NOT NULL,
  request_fingerprint text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT wholesale_application_events_code_check CHECK (
    event_code IN ('wholesale_application.saved', 'wholesale_application.submitted',
      'wholesale_application.assigned', 'wholesale_application.needs_info',
      'wholesale_application.approved', 'wholesale_application.rejected',
      'wholesale_application.withdrawn', 'wholesale_qualification.suspended',
      'wholesale_qualification.activated', 'wholesale_qualification.expired',
      'wholesale_qualification.revoked')
  ),
  CONSTRAINT wholesale_application_events_status_check CHECK (
    to_status IN ('draft', 'submitted', 'under_review', 'needs_info', 'approved',
      'rejected', 'withdrawn', 'active', 'suspended', 'expired', 'revoked')
  ),
  CONSTRAINT wholesale_application_events_reason_check CHECK (
    reason_code IS NULL OR reason_code IN ('information_incomplete',
      'eligibility_not_met', 'policy_violation', 'approved_checks_complete',
      'risk_suspension', 'validity_expired', 'policy_revoked')
  ),
  CONSTRAINT wholesale_application_events_fingerprint_check CHECK (
    request_fingerprint ~ '^[0-9a-f]{32}$'
  ),
  CONSTRAINT wholesale_application_events_actor_key UNIQUE (actor_user_id, idempotency_key)
);
CREATE INDEX wholesale_application_events_application_idx
  ON public.wholesale_application_events (application_id, created_at);
CREATE INDEX wholesale_application_events_actor_idx
  ON public.wholesale_application_events (actor_user_id, created_at);
CREATE INDEX wholesale_application_events_reviewer_idx
  ON public.wholesale_application_events (assigned_reviewer_membership_id);
CREATE INDEX wholesale_application_events_qualification_idx
  ON public.wholesale_application_events (qualification_id);

CREATE TABLE public.categories (
  id uuid PRIMARY KEY,
  parent_id uuid REFERENCES public.categories (id),
  slug text NOT NULL UNIQUE,
  name_zh text NOT NULL,
  name_it text NOT NULL,
  name_en text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT categories_slug_check CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,47}$'),
  CONSTRAINT categories_name_check CHECK (
    pg_catalog.char_length(pg_catalog.btrim(name_zh)) BETWEEN 1 AND 60
    AND pg_catalog.char_length(pg_catalog.btrim(name_it)) BETWEEN 1 AND 60
    AND pg_catalog.char_length(pg_catalog.btrim(name_en)) BETWEEN 1 AND 60
  ),
  CONSTRAINT categories_status_check CHECK (status IN ('active', 'inactive'))
);
CREATE INDEX categories_parent_idx ON public.categories (parent_id);
CREATE INDEX categories_status_sort_idx ON public.categories (status, sort_order, id);

CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  category_id uuid NOT NULL REFERENCES public.categories (id),
  product_kind text NOT NULL,
  internal_name text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  created_by uuid NOT NULL REFERENCES auth.users (id),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT products_org_fk FOREIGN KEY (organization_id, organization_type)
    REFERENCES public.organizations (id, organization_type),
  CONSTRAINT products_kind_check CHECK (product_kind IN ('standard', 'secondhand')),
  CONSTRAINT products_type_check CHECK (organization_type = 'merchant'),
  CONSTRAINT products_name_check CHECK (
    internal_name = pg_catalog.btrim(internal_name)
    AND pg_catalog.char_length(internal_name) BETWEEN 2 AND 120
  ),
  CONSTRAINT products_status_check CHECK (status IN ('active', 'inactive')),
  CONSTRAINT products_id_org_key UNIQUE (id, organization_id, organization_type),
  CONSTRAINT products_id_org_kind_key UNIQUE (id, organization_id, organization_type, product_kind)
);
CREATE INDEX products_org_idx ON public.products (organization_id, status);
CREATE INDEX products_org_context_idx
  ON public.products (organization_id, organization_type);
CREATE INDEX products_category_idx ON public.products (category_id);
CREATE INDEX products_creator_idx ON public.products (created_by);

CREATE TABLE public.product_variants (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  product_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  sku text NOT NULL,
  unit_code text NOT NULL DEFAULT 'unit',
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT product_variants_product_fk FOREIGN KEY (product_id, organization_id, organization_type)
    REFERENCES public.products (id, organization_id, organization_type),
  CONSTRAINT product_variants_sku_check CHECK (sku ~ '^SYN-SKU-[A-Z0-9-]{2,40}$'),
  CONSTRAINT product_variants_unit_check CHECK (unit_code IN ('unit', 'pack')),
  CONSTRAINT product_variants_status_check CHECK (status IN ('active', 'inactive')),
  CONSTRAINT product_variants_org_sku_key UNIQUE (organization_id, sku),
  CONSTRAINT product_variants_id_org_key UNIQUE (id, organization_id, organization_type),
  CONSTRAINT product_variants_id_product_org_key UNIQUE (id, product_id, organization_id, organization_type)
);
CREATE INDEX product_variants_product_idx ON public.product_variants (product_id);
CREATE INDEX product_variants_product_context_idx
  ON public.product_variants (product_id, organization_id, organization_type);
CREATE INDEX product_variants_org_idx ON public.product_variants (organization_id, status);

CREATE TABLE public.listings (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  store_id uuid NOT NULL,
  product_id uuid NOT NULL,
  variant_id uuid NOT NULL,
  product_kind text NOT NULL,
  slug text NOT NULL,
  title text NOT NULL,
  summary text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  version integer NOT NULL DEFAULT 1,
  published_at timestamptz,
  created_by uuid NOT NULL REFERENCES auth.users (id),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT listings_org_fk FOREIGN KEY (organization_id, organization_type)
    REFERENCES public.organizations (id, organization_type),
  CONSTRAINT listings_store_fk FOREIGN KEY (store_id, organization_id, organization_type)
    REFERENCES public.stores (id, organization_id, organization_type),
  CONSTRAINT listings_product_fk FOREIGN KEY (product_id, organization_id, organization_type, product_kind)
    REFERENCES public.products (id, organization_id, organization_type, product_kind),
  CONSTRAINT listings_variant_fk FOREIGN KEY (variant_id, product_id, organization_id, organization_type)
    REFERENCES public.product_variants (id, product_id, organization_id, organization_type),
  CONSTRAINT listings_type_check CHECK (organization_type = 'merchant'),
  CONSTRAINT listings_kind_check CHECK (product_kind IN ('standard', 'secondhand')),
  CONSTRAINT listings_slug_check CHECK (
    slug = pg_catalog.lower(slug) AND slug ~ '^[a-z0-9][a-z0-9-]{1,63}$'
  ),
  CONSTRAINT listings_text_check CHECK (
    title = pg_catalog.btrim(title) AND pg_catalog.char_length(title) BETWEEN 2 AND 120
    AND summary = pg_catalog.btrim(summary) AND pg_catalog.char_length(summary) BETWEEN 2 AND 240
  ),
  CONSTRAINT listings_status_check CHECK (status IN ('draft', 'active', 'inactive')),
  CONSTRAINT listings_publish_check CHECK (
    (status = 'active' AND published_at IS NOT NULL) OR status <> 'active'
  ),
  CONSTRAINT listings_version_check CHECK (version > 0),
  CONSTRAINT listings_store_slug_key UNIQUE (store_id, slug),
  CONSTRAINT listings_id_org_store_key UNIQUE (id, organization_id, organization_type, store_id),
  CONSTRAINT listings_id_kind_key UNIQUE (id, product_kind)
);
CREATE INDEX listings_org_store_idx ON public.listings (organization_id, store_id, status);
CREATE INDEX listings_org_context_idx
  ON public.listings (organization_id, organization_type);
CREATE INDEX listings_store_context_idx
  ON public.listings (store_id, organization_id, organization_type);
CREATE INDEX listings_product_context_idx
  ON public.listings (product_id, organization_id, organization_type, product_kind);
CREATE INDEX listings_variant_context_idx
  ON public.listings (variant_id, product_id, organization_id, organization_type);
CREATE INDEX listings_product_idx ON public.listings (product_id);
CREATE INDEX listings_variant_idx ON public.listings (variant_id);
CREATE INDEX listings_creator_idx ON public.listings (created_by);
CREATE INDEX listings_public_idx ON public.listings (status, published_at, id);

CREATE TABLE public.listing_prices (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  listing_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  store_id uuid NOT NULL,
  audience text NOT NULL,
  currency_code text NOT NULL DEFAULT 'EUR',
  unit_amount_cents integer NOT NULL,
  minimum_quantity integer NOT NULL,
  version integer NOT NULL,
  status text NOT NULL DEFAULT 'active',
  valid_from timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  valid_until timestamptz,
  created_by uuid NOT NULL REFERENCES auth.users (id),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT listing_prices_listing_fk FOREIGN KEY (
    listing_id, organization_id, organization_type, store_id
  ) REFERENCES public.listings (id, organization_id, organization_type, store_id),
  CONSTRAINT listing_prices_audience_check CHECK (audience IN ('retail', 'wholesale')),
  CONSTRAINT listing_prices_currency_check CHECK (currency_code = 'EUR'),
  CONSTRAINT listing_prices_amount_check CHECK (unit_amount_cents > 0),
  CONSTRAINT listing_prices_minimum_check CHECK (
    (audience = 'retail' AND minimum_quantity = 1)
    OR (audience = 'wholesale' AND minimum_quantity >= 2)
  ),
  CONSTRAINT listing_prices_version_check CHECK (version > 0),
  CONSTRAINT listing_prices_status_check CHECK (status IN ('active', 'superseded')),
  CONSTRAINT listing_prices_validity_check CHECK (valid_until IS NULL OR valid_until > valid_from),
  CONSTRAINT listing_prices_listing_audience_version_key UNIQUE (listing_id, audience, version),
  CONSTRAINT listing_prices_id_listing_key UNIQUE (id, listing_id)
);
CREATE UNIQUE INDEX listing_prices_one_active_audience
  ON public.listing_prices (listing_id, audience) WHERE status = 'active';
CREATE INDEX listing_prices_listing_idx ON public.listing_prices (listing_id, status);
CREATE INDEX listing_prices_listing_context_idx
  ON public.listing_prices (listing_id, organization_id, organization_type, store_id);
CREATE INDEX listing_prices_org_store_idx ON public.listing_prices (organization_id, store_id);
CREATE INDEX listing_prices_creator_idx ON public.listing_prices (created_by);

CREATE TABLE public.listing_price_tiers (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  price_id uuid NOT NULL,
  listing_id uuid NOT NULL,
  minimum_quantity integer NOT NULL,
  unit_amount_cents integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT listing_price_tiers_price_fk FOREIGN KEY (price_id, listing_id)
    REFERENCES public.listing_prices (id, listing_id) ON DELETE CASCADE,
  CONSTRAINT listing_price_tiers_quantity_check CHECK (minimum_quantity >= 2),
  CONSTRAINT listing_price_tiers_amount_check CHECK (unit_amount_cents > 0),
  CONSTRAINT listing_price_tiers_unique UNIQUE (price_id, minimum_quantity)
);
CREATE INDEX listing_price_tiers_listing_idx ON public.listing_price_tiers (listing_id);
CREATE INDEX listing_price_tiers_price_listing_idx
  ON public.listing_price_tiers (price_id, listing_id);

CREATE TABLE public.inventory_levels (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  listing_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  store_id uuid NOT NULL,
  on_hand integer NOT NULL DEFAULT 0,
  reserved integer NOT NULL DEFAULT 0,
  version integer NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT inventory_levels_listing_fk FOREIGN KEY (
    listing_id, organization_id, organization_type, store_id
  ) REFERENCES public.listings (id, organization_id, organization_type, store_id),
  CONSTRAINT inventory_levels_quantity_check CHECK (
    on_hand >= 0 AND reserved >= 0 AND reserved <= on_hand
  ),
  CONSTRAINT inventory_levels_version_check CHECK (version > 0),
  CONSTRAINT inventory_levels_listing_key UNIQUE (listing_id),
  CONSTRAINT inventory_levels_id_listing_key UNIQUE (id, listing_id)
);
CREATE INDEX inventory_levels_org_store_idx ON public.inventory_levels (organization_id, store_id);
CREATE INDEX inventory_levels_listing_context_idx
  ON public.inventory_levels (listing_id, organization_id, organization_type, store_id);

CREATE TABLE public.secondhand_units (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  listing_id uuid NOT NULL UNIQUE,
  product_kind text NOT NULL DEFAULT 'secondhand',
  synthetic_serial_reference text NOT NULL UNIQUE,
  condition_code text NOT NULL,
  defect_code text NOT NULL,
  battery_health_percent integer,
  warranty_days integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'available',
  version integer NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT secondhand_units_listing_fk FOREIGN KEY (listing_id, product_kind)
    REFERENCES public.listings (id, product_kind),
  CONSTRAINT secondhand_units_kind_check CHECK (product_kind = 'secondhand'),
  CONSTRAINT secondhand_units_serial_check CHECK (
    synthetic_serial_reference ~ '^SYN-UNIT-[A-Z0-9-]{4,40}$'
  ),
  CONSTRAINT secondhand_units_condition_check CHECK (
    condition_code IN ('like_new', 'good', 'fair')
  ),
  CONSTRAINT secondhand_units_defect_check CHECK (
    defect_code IN ('none', 'cosmetic_wear', 'screen_mark', 'housing_mark')
  ),
  CONSTRAINT secondhand_units_battery_check CHECK (
    battery_health_percent IS NULL OR battery_health_percent BETWEEN 50 AND 100
  ),
  CONSTRAINT secondhand_units_warranty_check CHECK (warranty_days BETWEEN 0 AND 730),
  CONSTRAINT secondhand_units_status_check CHECK (
    status IN ('available', 'reserved', 'sold', 'inactive')
  ),
  CONSTRAINT secondhand_units_version_check CHECK (version > 0),
  CONSTRAINT secondhand_units_id_listing_key UNIQUE (id, listing_id)
);
CREATE INDEX secondhand_units_listing_kind_idx ON public.secondhand_units (listing_id, product_kind);
CREATE INDEX secondhand_units_status_idx ON public.secondhand_units (status, listing_id);

CREATE TABLE public.catalog_events (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  actor_user_id uuid NOT NULL REFERENCES auth.users (id),
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  store_id uuid NOT NULL,
  listing_id uuid NOT NULL,
  event_code text NOT NULL,
  from_version integer,
  to_version integer NOT NULL,
  idempotency_key uuid NOT NULL,
  request_fingerprint text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT catalog_events_listing_fk FOREIGN KEY (
    listing_id, organization_id, organization_type, store_id
  ) REFERENCES public.listings (id, organization_id, organization_type, store_id),
  CONSTRAINT catalog_events_code_check CHECK (
    event_code IN ('catalog.listing_created', 'catalog.listing_updated', 'catalog.listing_deactivated')
  ),
  CONSTRAINT catalog_events_version_check CHECK (
    (from_version IS NULL OR from_version > 0) AND to_version > 0
  ),
  CONSTRAINT catalog_events_fingerprint_check CHECK (request_fingerprint ~ '^[0-9a-f]{32}$'),
  CONSTRAINT catalog_events_actor_key UNIQUE (actor_user_id, idempotency_key)
);
CREATE INDEX catalog_events_listing_idx ON public.catalog_events (listing_id, created_at);
CREATE INDEX catalog_events_listing_context_idx
  ON public.catalog_events (listing_id, organization_id, organization_type, store_id);
CREATE INDEX catalog_events_org_store_idx ON public.catalog_events (organization_id, store_id);
CREATE INDEX catalog_events_actor_idx ON public.catalog_events (actor_user_id);

CREATE TABLE public.inventory_events (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  actor_user_id uuid NOT NULL REFERENCES auth.users (id),
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  store_id uuid NOT NULL,
  listing_id uuid NOT NULL,
  inventory_id uuid,
  secondhand_unit_id uuid,
  event_code text NOT NULL,
  quantity_delta integer,
  reserved_delta integer,
  from_version integer NOT NULL,
  to_version integer NOT NULL,
  idempotency_key uuid NOT NULL,
  request_fingerprint text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT inventory_events_listing_fk FOREIGN KEY (
    listing_id, organization_id, organization_type, store_id
  ) REFERENCES public.listings (id, organization_id, organization_type, store_id),
  CONSTRAINT inventory_events_inventory_fk FOREIGN KEY (inventory_id, listing_id)
    REFERENCES public.inventory_levels (id, listing_id),
  CONSTRAINT inventory_events_secondhand_fk FOREIGN KEY (secondhand_unit_id, listing_id)
    REFERENCES public.secondhand_units (id, listing_id),
  CONSTRAINT inventory_events_target_check CHECK (
    (inventory_id IS NOT NULL AND secondhand_unit_id IS NULL)
    OR (inventory_id IS NULL AND secondhand_unit_id IS NOT NULL)
  ),
  CONSTRAINT inventory_events_code_check CHECK (
    event_code IN ('inventory.adjusted', 'inventory.reserved', 'inventory.released',
      'inventory.sold', 'secondhand.reserved', 'secondhand.released',
      'secondhand.sold')
  ),
  CONSTRAINT inventory_events_version_check CHECK (from_version > 0 AND to_version > from_version),
  CONSTRAINT inventory_events_fingerprint_check CHECK (request_fingerprint ~ '^[0-9a-f]{32}$'),
  CONSTRAINT inventory_events_actor_key UNIQUE (actor_user_id, idempotency_key)
);
CREATE INDEX inventory_events_listing_idx ON public.inventory_events (listing_id, created_at);
CREATE INDEX inventory_events_listing_context_idx
  ON public.inventory_events (listing_id, organization_id, organization_type, store_id);
CREATE INDEX inventory_events_inventory_idx ON public.inventory_events (inventory_id);
CREATE INDEX inventory_events_secondhand_idx ON public.inventory_events (secondhand_unit_id);
CREATE INDEX inventory_events_inventory_listing_idx
  ON public.inventory_events (inventory_id, listing_id);
CREATE INDEX inventory_events_secondhand_listing_idx
  ON public.inventory_events (secondhand_unit_id, listing_id);
CREATE INDEX inventory_events_org_store_idx ON public.inventory_events (organization_id, store_id);
CREATE INDEX inventory_events_actor_idx ON public.inventory_events (actor_user_id);

CREATE TABLE public.p4_idempotency_keys (
  actor_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  idempotency_key uuid NOT NULL,
  operation_code text NOT NULL,
  target_id uuid,
  request_fingerprint text NOT NULL,
  result_status text NOT NULL,
  result_version integer,
  result_on_hand integer,
  result_reserved integer,
  result_available integer,
  application_id uuid REFERENCES public.wholesale_applications (id),
  organization_id uuid REFERENCES public.organizations (id),
  membership_id uuid REFERENCES public.memberships (id),
  qualification_id uuid REFERENCES public.wholesale_qualifications (id),
  listing_id uuid REFERENCES public.listings (id),
  inventory_id uuid REFERENCES public.inventory_levels (id),
  secondhand_unit_id uuid REFERENCES public.secondhand_units (id),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  PRIMARY KEY (actor_user_id, idempotency_key),
  CONSTRAINT p4_idempotency_fingerprint_check CHECK (request_fingerprint ~ '^[0-9a-f]{32}$'),
  CONSTRAINT p4_idempotency_operation_check CHECK (
    operation_code IN ('wholesale.save', 'wholesale.assign', 'wholesale.review',
      'wholesale.withdraw', 'qualification.change', 'catalog.upsert',
      'inventory.adjust', 'inventory.reserve', 'inventory.release', 'inventory.sell')
  ),
  CONSTRAINT p4_idempotency_version_check CHECK (result_version IS NULL OR result_version > 0),
  CONSTRAINT p4_idempotency_quantity_check CHECK (
    (result_on_hand IS NULL OR result_on_hand >= 0)
    AND (result_reserved IS NULL OR result_reserved >= 0)
    AND (result_available IS NULL OR result_available >= 0)
    AND (result_on_hand IS NULL OR result_reserved IS NULL
      OR result_reserved <= result_on_hand)
  )
);
CREATE INDEX p4_idempotency_application_idx ON public.p4_idempotency_keys (application_id);
CREATE INDEX p4_idempotency_organization_idx ON public.p4_idempotency_keys (organization_id);
CREATE INDEX p4_idempotency_membership_idx ON public.p4_idempotency_keys (membership_id);
CREATE INDEX p4_idempotency_qualification_idx ON public.p4_idempotency_keys (qualification_id);
CREATE INDEX p4_idempotency_listing_idx ON public.p4_idempotency_keys (listing_id);
CREATE INDEX p4_idempotency_inventory_idx ON public.p4_idempotency_keys (inventory_id);
CREATE INDEX p4_idempotency_unit_idx ON public.p4_idempotency_keys (secondhand_unit_id);

ALTER TABLE public.wholesale_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wholesale_applications FORCE ROW LEVEL SECURITY;
ALTER TABLE public.wholesale_application_private ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wholesale_application_private FORCE ROW LEVEL SECURITY;
ALTER TABLE public.wholesale_application_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wholesale_application_events FORCE ROW LEVEL SECURITY;
ALTER TABLE public.wholesale_qualifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wholesale_qualifications FORCE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories FORCE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products FORCE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants FORCE ROW LEVEL SECURITY;
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings FORCE ROW LEVEL SECURITY;
ALTER TABLE public.listing_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listing_prices FORCE ROW LEVEL SECURITY;
ALTER TABLE public.listing_price_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listing_price_tiers FORCE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_levels FORCE ROW LEVEL SECURITY;
ALTER TABLE public.secondhand_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.secondhand_units FORCE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_events FORCE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_events FORCE ROW LEVEL SECURITY;
ALTER TABLE public.p4_idempotency_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.p4_idempotency_keys FORCE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION private.rebuy_p4_reset_context()
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $function$
BEGIN
  PERFORM private.rebuy_business_reset_context();
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'false', true);
  PERFORM pg_catalog.set_config('rebuy.p4.op', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.application_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.applicant_user_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.membership_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.target_membership_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.organization_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.store_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.scope_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.qualification_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.category_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.product_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.variant_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.listing_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.price_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.inventory_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.unit_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', '', true);
END
$function$;

-- P3 and P4 implementations are directly callable for parity testing. Reset both
-- context namespaces so a caller cannot carry permissive RLS state across RPCs
-- inside one explicit transaction.
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
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'false', true);
  PERFORM pg_catalog.set_config('rebuy.p4.op', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.application_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.applicant_user_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.membership_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.target_membership_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.organization_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.store_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.scope_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.qualification_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.category_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.product_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.variant_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.listing_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.price_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.inventory_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.unit_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', '', true);
END
$function$;

CREATE POLICY wholesale_applications_p4_select
  ON public.wholesale_applications FOR SELECT TO rebuy_business_executor
  USING (
    applicant_user_id = (SELECT private.rebuy_request_uid())
    OR ((SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.application_id', true)))
    OR ((SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'list_wholesale_queue')
  );
CREATE POLICY wholesale_applications_p4_insert
  ON public.wholesale_applications FOR INSERT TO rebuy_business_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.application_id', true))
    AND applicant_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.applicant_user_id', true))
  );
CREATE POLICY wholesale_applications_p4_update
  ON public.wholesale_applications FOR UPDATE TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.application_id', true))
  ) WITH CHECK (
    id::text = (SELECT pg_catalog.current_setting('rebuy.p4.application_id', true))
  );

CREATE POLICY wholesale_application_private_p4_select
  ON public.wholesale_application_private FOR SELECT TO rebuy_business_executor
  USING (
    applicant_user_id = (SELECT private.rebuy_request_uid())
    OR ((SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND application_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.application_id', true)))
  );
CREATE POLICY wholesale_application_private_p4_insert
  ON public.wholesale_application_private FOR INSERT TO rebuy_business_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND application_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.application_id', true))
    AND applicant_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.applicant_user_id', true))
  );
CREATE POLICY wholesale_application_private_p4_update
  ON public.wholesale_application_private FOR UPDATE TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND application_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.application_id', true))
  ) WITH CHECK (
    application_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.application_id', true))
  );

CREATE POLICY wholesale_application_events_p4_select
  ON public.wholesale_application_events FOR SELECT TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND (application_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.application_id', true))
      OR actor_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.actor_user_id', true)))
  );
CREATE POLICY wholesale_application_events_p4_insert
  ON public.wholesale_application_events FOR INSERT TO rebuy_business_executor
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.event_id', true))
    AND actor_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.actor_user_id', true))
  );

CREATE POLICY wholesale_qualifications_p4_all
  ON public.wholesale_qualifications FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p4.qualification_id', true))
      OR organization_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true)))
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.qualification_id', true))
    AND organization_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true))
  );

CREATE POLICY categories_p4_select
  ON public.categories FOR SELECT TO rebuy_business_executor
  USING ((SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true');

CREATE POLICY products_p4_all
  ON public.products FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p4.product_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_public')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.product_id', true))
    AND organization_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true))
  );
CREATE POLICY product_variants_p4_all
  ON public.product_variants FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p4.variant_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_public')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.variant_id', true))
    AND product_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.product_id', true))
  );
CREATE POLICY listings_p4_all
  ON public.listings FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_public')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
    AND organization_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true))
    AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.store_id', true))
  );
CREATE POLICY listing_prices_p4_all
  ON public.listing_prices FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND (listing_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_public')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND listing_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
    AND organization_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true))
    AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.store_id', true))
  );
CREATE POLICY listing_price_tiers_p4_all
  ON public.listing_price_tiers FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND (listing_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_public')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND listing_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
  );
CREATE POLICY inventory_levels_p4_all
  ON public.inventory_levels FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND (listing_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_public')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND listing_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.inventory_id', true))
  );
CREATE POLICY secondhand_units_p4_all
  ON public.secondhand_units FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND (listing_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_public')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND listing_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.unit_id', true))
  );
CREATE POLICY catalog_events_p4_all
  ON public.catalog_events FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND listing_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.event_id', true))
    AND actor_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.actor_user_id', true))
  );
CREATE POLICY inventory_events_p4_all
  ON public.inventory_events FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND listing_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.listing_id', true))
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.event_id', true))
    AND actor_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.actor_user_id', true))
  );
CREATE POLICY p4_idempotency_keys_p4_all
  ON public.p4_idempotency_keys FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND actor_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.actor_user_id', true))
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND actor_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.actor_user_id', true))
  );

-- P3 already owns policies on these shared tables. Replace only the overlapping
-- actions with one combined permissive policy per table/role/action so the
-- Supabase advisor stays warning-free without widening either workflow.
DROP POLICY organizations_business_select ON public.organizations;
DROP POLICY organizations_business_insert_merchant ON public.organizations;
CREATE POLICY organizations_business_p4_select
  ON public.organizations FOR SELECT TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.organization_id', true))
    )
    OR EXISTS (
      SELECT 1 FROM public.memberships AS m
      WHERE m.organization_id = organizations.id
        AND m.organization_type = organizations.organization_type
        AND m.user_id = (SELECT private.rebuy_request_uid())
        AND m.status = 'active'
        AND m.valid_from <= pg_catalog.statement_timestamp()
        AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true))
        OR (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_public')
    )
  );
CREATE POLICY organizations_business_p4_insert
  ON public.organizations FOR INSERT TO rebuy_business_executor
  WITH CHECK (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.organization_id', true))
      AND organization_type = 'merchant'
      AND created_by::text = (SELECT pg_catalog.current_setting('rebuy.business.applicant_user_id', true))
      AND status = 'active'
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'review_wholesale'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true))
      AND organization_type = 'wholesale'
      AND created_by::text = (SELECT pg_catalog.current_setting('rebuy.p4.applicant_user_id', true))
      AND status = 'active'
    )
  );

DROP POLICY stores_business_select ON public.stores;
DROP POLICY stores_business_update_merchant ON public.stores;
CREATE POLICY stores_business_p4_select
  ON public.stores FOR SELECT TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.store_id', true))
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p4.store_id', true))
        OR (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_public')
    )
  );
CREATE POLICY stores_business_p4_update
  ON public.stores FOR UPDATE TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.store_id', true))
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_upsert'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.store_id', true))
      AND organization_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true))
      AND organization_type = 'merchant' AND status = 'active'
    )
  )
  WITH CHECK (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.store_id', true))
      AND status = 'suspended' AND public_visibility = false
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'catalog_upsert'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.store_id', true))
      AND organization_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true))
      AND organization_type = 'merchant' AND status = 'active'
    )
  );

DROP POLICY memberships_business_select ON public.memberships;
DROP POLICY memberships_business_insert_owner ON public.memberships;
CREATE POLICY memberships_business_p4_select
  ON public.memberships FOR SELECT TO rebuy_business_executor
  USING (
    user_id = (SELECT private.rebuy_request_uid())
    OR (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND id::text IN (
        (SELECT pg_catalog.current_setting('rebuy.business.target_membership_id', true)),
        (SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true))
      )
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND id::text IN (
        (SELECT pg_catalog.current_setting('rebuy.p4.membership_id', true)),
        (SELECT pg_catalog.current_setting('rebuy.p4.target_membership_id', true))
      )
    )
  );
CREATE POLICY memberships_business_p4_insert
  ON public.memberships FOR INSERT TO rebuy_business_executor
  WITH CHECK (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true))
      AND user_id::text = (SELECT pg_catalog.current_setting('rebuy.business.applicant_user_id', true))
      AND organization_id::text = (SELECT pg_catalog.current_setting('rebuy.business.organization_id', true))
      AND organization_type = 'merchant'
      AND role_definition_id = '00000000-0000-4000-8000-000000000201'::uuid
      AND role_version = 1 AND status = 'active'
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'review_wholesale'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.membership_id', true))
      AND user_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.applicant_user_id', true))
      AND organization_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true))
      AND organization_type = 'wholesale'
      AND role_definition_id = '00000000-0000-4000-8000-000000000201'::uuid
      AND role_version = 1 AND status = 'active'
    )
  );

DROP POLICY membership_store_scopes_business_insert_owner
  ON public.membership_store_scopes;
DROP POLICY membership_store_scopes_business_select_owner
  ON public.membership_store_scopes;
CREATE POLICY membership_store_scopes_business_p4_insert
  ON public.membership_store_scopes FOR INSERT TO rebuy_business_executor
  WITH CHECK (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.business.scope_id', true))
      AND membership_id::text = (SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true))
      AND organization_id::text = (SELECT pg_catalog.current_setting('rebuy.business.organization_id', true))
      AND organization_type = 'merchant'
      AND scope_type = 'organization' AND store_id IS NULL AND status = 'active'
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p4.op', true)) = 'review_wholesale'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.scope_id', true))
      AND membership_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.membership_id', true))
      AND organization_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.organization_id', true))
      AND organization_type = 'wholesale'
      AND scope_type = 'organization' AND store_id IS NULL AND status = 'active'
    )
  );
CREATE POLICY membership_store_scopes_business_p4_select
  ON public.membership_store_scopes FOR SELECT TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND membership_id::text = (SELECT pg_catalog.current_setting('rebuy.business.owner_membership_id', true))
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND membership_id::text = (SELECT pg_catalog.current_setting('rebuy.p4.membership_id', true))
    )
  );

REVOKE ALL PRIVILEGES ON TABLE public.wholesale_applications,
  public.wholesale_application_private, public.wholesale_application_events,
  public.wholesale_qualifications, public.categories, public.products,
  public.product_variants, public.listings, public.listing_prices,
  public.listing_price_tiers, public.inventory_levels, public.secondhand_units,
  public.catalog_events, public.inventory_events, public.p4_idempotency_keys
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
GRANT SELECT, INSERT, UPDATE ON TABLE public.wholesale_applications,
  public.wholesale_application_private, public.wholesale_qualifications,
  public.products, public.product_variants, public.listings,
  public.listing_prices, public.inventory_levels, public.secondhand_units
  TO rebuy_business_executor;
GRANT SELECT, INSERT ON TABLE public.p4_idempotency_keys
  TO rebuy_business_executor;
GRANT SELECT, INSERT ON TABLE public.wholesale_application_events,
  public.catalog_events, public.inventory_events, public.listing_price_tiers
  TO rebuy_business_executor;
GRANT SELECT ON TABLE public.categories TO rebuy_business_executor;
GRANT SELECT (display_name) ON TABLE public.stores TO rebuy_business_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_request_jwt(), private.rebuy_request_uid(),
  private.rebuy_business_require_identity(boolean) TO rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.rebuy_p4_reset_context()
  FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_p4_reset_context() TO rebuy_business_executor;

CREATE OR REPLACE FUNCTION private.rebuy_p4_find_merchant_membership(
  p_user_id uuid,
  p_organization_id uuid,
  p_store_id uuid,
  p_permission_key text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_membership record;
BEGIN
  FOR v_membership IN
    SELECT m.id, rd.scope_type AS role_scope_type
    FROM public.memberships AS m
    JOIN public.organizations AS o
      ON o.id = m.organization_id AND o.organization_type = m.organization_type
    JOIN public.role_definitions AS rd
      ON rd.id = m.role_definition_id AND rd.version = m.role_version
    JOIN public.role_permissions AS rp
      ON rp.role_definition_id = m.role_definition_id
     AND rp.role_version = m.role_version AND rp.is_granted
    JOIN public.permissions AS p
      ON p.id = rp.permission_id AND p.is_active
    WHERE m.user_id = p_user_id
      AND m.organization_id = p_organization_id
      AND m.organization_type = 'merchant'
      AND m.status = 'active'
      AND m.valid_from <= pg_catalog.statement_timestamp()
      AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
      AND o.status = 'active'
      AND rd.status = 'active'
      AND rd.applicable_organization_type IN ('any', 'merchant')
      AND p.permission_key = p_permission_key
    ORDER BY m.id
  LOOP
    PERFORM pg_catalog.set_config('rebuy.p4.membership_id', v_membership.id::text, true);
    IF EXISTS (
      SELECT 1
      FROM public.membership_store_scopes AS s
      WHERE s.membership_id = v_membership.id
        AND s.organization_id = p_organization_id
        AND s.organization_type = 'merchant'
        AND s.status = 'active'
        AND ((v_membership.role_scope_type = 'organization'
            AND s.scope_type = 'organization' AND s.store_id IS NULL)
          OR (v_membership.role_scope_type = 'store'
            AND s.scope_type = 'store' AND s.store_id = p_store_id))
    ) THEN
      RETURN v_membership.id;
    END IF;
  END LOOP;
  RETURN NULL;
END
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_p4_active_wholesale_qualification(
  p_user_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_membership record;
  v_qualification_id uuid;
BEGIN
  FOR v_membership IN
    SELECT m.id, m.organization_id
    FROM public.memberships AS m
    JOIN public.role_definitions AS rd
      ON rd.id = m.role_definition_id AND rd.version = m.role_version
    WHERE m.user_id = p_user_id
      AND m.organization_type = 'wholesale'
      AND m.status = 'active'
      AND m.valid_from <= pg_catalog.statement_timestamp()
      AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
      AND rd.role_key = 'owner' AND rd.scope_type = 'organization'
      AND rd.status = 'active' AND rd.is_system
      AND rd.applicable_organization_type IN ('any', 'wholesale')
    ORDER BY m.id
  LOOP
    PERFORM pg_catalog.set_config('rebuy.p4.organization_id', v_membership.organization_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.membership_id', v_membership.id::text, true);
    SELECT q.id INTO v_qualification_id
    FROM public.wholesale_qualifications AS q
    JOIN public.organizations AS o
      ON o.id = q.organization_id AND o.organization_type = q.organization_type
    WHERE q.organization_id = v_membership.organization_id
      AND q.status = 'active'
      AND q.valid_from <= pg_catalog.statement_timestamp()
      AND q.valid_until > pg_catalog.statement_timestamp()
      AND o.status = 'active'
      AND EXISTS (
        SELECT 1 FROM public.membership_store_scopes AS s
        WHERE s.membership_id = v_membership.id
          AND s.organization_id = v_membership.organization_id
          AND s.organization_type = 'wholesale'
          AND s.scope_type = 'organization'
          AND s.store_id IS NULL AND s.status = 'active'
      )
    ORDER BY q.id LIMIT 1;
    IF v_qualification_id IS NOT NULL THEN
      RETURN v_qualification_id;
    END IF;
  END LOOP;
  RETURN NULL;
END
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION private.rebuy_p4_find_merchant_membership(
  uuid, uuid, uuid, text
) FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.rebuy_p4_active_wholesale_qualification(uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_p4_find_merchant_membership(
  uuid, uuid, uuid, text
) TO rebuy_business_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_p4_active_wholesale_qualification(uuid)
  TO rebuy_business_executor;

CREATE OR REPLACE FUNCTION private.save_wholesale_application_impl(
  p_company_name text,
  p_country_code text,
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
  v_company text := pg_catalog.btrim(p_company_name);
  v_country text := pg_catalog.upper(pg_catalog.btrim(p_country_code));
  v_registration text := pg_catalog.upper(pg_catalog.btrim(p_registration_reference));
  v_evidence text := pg_catalog.lower(pg_catalog.btrim(p_evidence_reference));
  v_application public.wholesale_applications%ROWTYPE;
  v_event public.wholesale_application_events%ROWTYPE;
  v_key public.p4_idempotency_keys%ROWTYPE;
  v_application_id uuid;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_target_status text;
  v_event_code text;
  v_fingerprint text;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(true) AS i;
  IF p_idempotency_key IS NULL OR p_submit IS NULL
     OR v_company IS NULL OR pg_catalog.char_length(v_company) NOT BETWEEN 2 AND 80
     OR v_country IS NULL OR v_country !~ '^[A-Z]{2}$'
     OR v_registration IS NULL OR v_registration !~ '^SYN-[A-Z0-9-]{4,40}$'
     OR v_evidence IS NULL OR v_evidence !~ '^synthetic://[a-z0-9][a-z0-9/_-]{2,120}$'
  THEN
    RAISE EXCEPTION 'wholesale_application_invalid';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p4-idempotency', 0));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':wholesale-application', 0));
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'save_wholesale', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.applicant_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  v_event_code := CASE WHEN p_submit THEN 'wholesale_application.submitted'
    ELSE 'wholesale_application.saved' END;
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|', v_company, v_country,
    v_registration, v_evidence, p_submit::text));
  SELECT k.* INTO v_key FROM public.p4_idempotency_keys AS k
  WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'wholesale.save'
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RAISE EXCEPTION 'p4_idempotency_conflict';
    END IF;
    RETURN QUERY SELECT v_key.application_id, v_key.result_status; RETURN;
  END IF;
  SELECT e.* INTO v_event
  FROM public.wholesale_application_events AS e
  WHERE e.actor_user_id = v_uid AND e.idempotency_key = p_idempotency_key;
  IF v_event.id IS NOT NULL THEN
    IF v_event.event_code IS DISTINCT FROM v_event_code
       OR v_event.request_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RAISE EXCEPTION 'wholesale_idempotency_conflict';
    END IF;
    RETURN QUERY SELECT v_event.application_id, v_event.to_status;
    RETURN;
  END IF;
  SELECT a.* INTO v_application
  FROM public.wholesale_applications AS a
  WHERE a.applicant_user_id = v_uid
    AND a.status NOT IN ('approved', 'rejected', 'withdrawn')
  ORDER BY a.created_at DESC LIMIT 1;
  IF v_application.id IS NULL THEN
    v_application_id := pg_catalog.gen_random_uuid();
    PERFORM pg_catalog.set_config('rebuy.p4.application_id', v_application_id::text, true);
    INSERT INTO public.wholesale_applications (
      id, applicant_user_id, company_name, country_code, status, submitted_at,
      created_at, updated_at
    ) VALUES (
      v_application_id, v_uid, v_company, v_country,
      CASE WHEN p_submit THEN 'submitted' ELSE 'draft' END,
      CASE WHEN p_submit THEN v_now ELSE NULL END, v_now, v_now
    );
    INSERT INTO public.wholesale_application_private (
      application_id, applicant_user_id, registration_reference,
      evidence_reference, created_at, updated_at
    ) VALUES (v_application_id, v_uid, v_registration, v_evidence, v_now, v_now);
    v_target_status := CASE WHEN p_submit THEN 'submitted' ELSE 'draft' END;
  ELSE
    IF v_application.status NOT IN ('draft', 'needs_info') THEN
      RAISE EXCEPTION 'wholesale_application_state_conflict';
    END IF;
    v_application_id := v_application.id;
    PERFORM pg_catalog.set_config('rebuy.p4.application_id', v_application_id::text, true);
    v_target_status := CASE WHEN p_submit THEN 'submitted' ELSE 'draft' END;
    UPDATE public.wholesale_applications
    SET company_name = v_company, country_code = v_country,
      status = v_target_status,
      assigned_reviewer_membership_id = NULL, assigned_at = NULL,
      submitted_at = CASE WHEN p_submit THEN COALESCE(submitted_at, v_now) ELSE NULL END,
      updated_at = v_now
    WHERE id = v_application_id;
    UPDATE public.wholesale_application_private AS wap
    SET registration_reference = v_registration, evidence_reference = v_evidence,
      updated_at = v_now
    WHERE wap.application_id = v_application_id;
  END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
  INSERT INTO public.wholesale_application_events (
    id, application_id, actor_user_id, event_code, from_status, to_status,
    idempotency_key, request_fingerprint, created_at
  ) VALUES (
    v_event_id, v_application_id, v_uid, v_event_code, v_application.status,
    v_target_status, p_idempotency_key, v_fingerprint, v_now
  );
  INSERT INTO public.p4_idempotency_keys (
    actor_user_id, idempotency_key, operation_code, target_id,
    request_fingerprint, result_status, application_id, created_at
  ) VALUES (v_uid, p_idempotency_key, 'wholesale.save', v_application_id,
    v_fingerprint, v_target_status, v_application_id, v_now);
  RETURN QUERY SELECT v_application_id, v_target_status;
END
$function$;

CREATE OR REPLACE FUNCTION private.get_my_wholesale_application_impl()
RETURNS TABLE (
  application_id uuid, company_name text, country_code text,
  application_status text, registration_reference text,
  evidence_reference text, organization_id uuid,
  qualification_id uuid, qualification_status text,
  valid_until timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_uid uuid; v_application public.wholesale_applications%ROWTYPE;
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(false) AS i;
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  SELECT a.* INTO v_application FROM public.wholesale_applications AS a
  WHERE a.applicant_user_id = v_uid ORDER BY a.created_at DESC LIMIT 1;
  IF v_application.id IS NULL THEN RETURN; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.application_id', v_application.id::text, true);
  IF v_application.qualification_id IS NOT NULL THEN
    PERFORM pg_catalog.set_config('rebuy.p4.qualification_id',
      v_application.qualification_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.organization_id',
      v_application.organization_id::text, true);
  END IF;
  RETURN QUERY
  SELECT a.id, a.company_name, a.country_code, a.status,
    ap.registration_reference, ap.evidence_reference, a.organization_id,
    a.qualification_id, q.status, q.valid_until, a.updated_at
  FROM public.wholesale_applications AS a
  JOIN public.wholesale_application_private AS ap ON ap.application_id = a.id
  LEFT JOIN public.wholesale_qualifications AS q ON q.id = a.qualification_id
  WHERE a.applicant_user_id = v_uid
  ORDER BY a.created_at DESC LIMIT 1;
END
$function$;

CREATE OR REPLACE FUNCTION private.list_wholesale_review_queue_impl()
RETURNS TABLE (
  application_id uuid, company_name text, country_code text,
  application_status text, assigned_reviewer_membership_id uuid,
  submitted_at timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_uid uuid; v_membership_id uuid;
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(false) AS i;
  v_membership_id := private.rebuy_business_find_platform_membership(
    'wholesale_application.assign');
  IF v_membership_id IS NULL THEN RAISE EXCEPTION 'wholesale_review_forbidden'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'list_wholesale_queue', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  RETURN QUERY SELECT a.id, a.company_name, a.country_code, a.status,
    a.assigned_reviewer_membership_id, a.submitted_at, a.updated_at
  FROM public.wholesale_applications AS a
  WHERE a.status IN ('submitted', 'under_review', 'needs_info')
  ORDER BY a.submitted_at, a.id;
END
$function$;

CREATE OR REPLACE FUNCTION private.assign_wholesale_application_impl(
  p_application_id uuid,
  p_reviewer_membership_id uuid,
  p_idempotency_key uuid
)
RETURNS TABLE (application_id uuid, application_status text, reviewer_membership_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_admin_membership_id uuid; v_target_user_id uuid;
  v_application public.wholesale_applications%ROWTYPE;
  v_event public.wholesale_application_events%ROWTYPE;
  v_key public.p4_idempotency_keys%ROWTYPE;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_fingerprint text; v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_application_id IS NULL OR p_reviewer_membership_id IS NULL
     OR p_idempotency_key IS NULL THEN RAISE EXCEPTION 'wholesale_assignment_invalid'; END IF;
  v_admin_membership_id := private.rebuy_business_find_platform_membership(
    'wholesale_application.assign');
  IF v_admin_membership_id IS NULL THEN RAISE EXCEPTION 'wholesale_review_forbidden'; END IF;
  v_fingerprint := pg_catalog.md5(p_reviewer_membership_id::text);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p4-idempotency', 0));
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'assign_wholesale', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.application_id', p_application_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.target_membership_id', p_reviewer_membership_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  SELECT k.* INTO v_key FROM public.p4_idempotency_keys AS k
  WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'wholesale.assign'
       OR v_key.target_id IS DISTINCT FROM p_application_id
       OR v_key.membership_id IS DISTINCT FROM p_reviewer_membership_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p4_idempotency_conflict'; END IF;
    RETURN QUERY SELECT v_key.application_id, v_key.result_status,
      v_key.membership_id; RETURN;
  END IF;
  SELECT e.* INTO v_event FROM public.wholesale_application_events AS e
  WHERE e.actor_user_id = v_uid AND e.idempotency_key = p_idempotency_key;
  IF v_event.id IS NOT NULL THEN
    IF v_event.application_id IS DISTINCT FROM p_application_id
       OR v_event.event_code IS DISTINCT FROM 'wholesale_application.assigned'
       OR v_event.request_fingerprint IS DISTINCT FROM v_fingerprint
       OR v_event.assigned_reviewer_membership_id IS DISTINCT FROM p_reviewer_membership_id
    THEN RAISE EXCEPTION 'wholesale_idempotency_conflict'; END IF;
    RETURN QUERY SELECT v_event.application_id, v_event.to_status,
      v_event.assigned_reviewer_membership_id; RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_application_id::text, 0));
  SELECT a.* INTO v_application FROM public.wholesale_applications AS a
  WHERE a.id = p_application_id FOR UPDATE;
  IF v_application.id IS NULL THEN RAISE EXCEPTION 'wholesale_application_not_available'; END IF;
  IF v_application.status <> 'submitted' THEN RAISE EXCEPTION 'wholesale_application_state_conflict'; END IF;
  SELECT m.user_id INTO v_target_user_id FROM public.memberships AS m
  WHERE m.id = p_reviewer_membership_id AND m.organization_type = 'platform'
    AND m.status = 'active' AND m.valid_from <= v_now
    AND (m.valid_until IS NULL OR m.valid_until > v_now);
  IF v_target_user_id IS NULL OR v_target_user_id = v_application.applicant_user_id
     OR NOT private.rebuy_business_membership_has_permission(
       p_reviewer_membership_id, v_target_user_id, 'wholesale_application.read_assigned')
     OR NOT private.rebuy_business_membership_has_permission(
       p_reviewer_membership_id, v_target_user_id, 'wholesale_application.review')
  THEN RAISE EXCEPTION 'wholesale_reviewer_not_available'; END IF;
  UPDATE public.wholesale_applications SET status = 'under_review',
    assigned_reviewer_membership_id = p_reviewer_membership_id,
    assigned_at = v_now, updated_at = v_now WHERE id = p_application_id;
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
  INSERT INTO public.wholesale_application_events (
    id, application_id, actor_user_id, event_code, from_status, to_status,
    assigned_reviewer_membership_id, idempotency_key, request_fingerprint, created_at
  ) VALUES (v_event_id, p_application_id, v_uid, 'wholesale_application.assigned',
    'submitted', 'under_review', p_reviewer_membership_id, p_idempotency_key,
    v_fingerprint, v_now);
  INSERT INTO public.p4_idempotency_keys (
    actor_user_id, idempotency_key, operation_code, target_id,
    request_fingerprint, result_status, application_id, membership_id, created_at
  ) VALUES (v_uid, p_idempotency_key, 'wholesale.assign', p_application_id,
    v_fingerprint, 'under_review', p_application_id,
    p_reviewer_membership_id, v_now);
  RETURN QUERY SELECT p_application_id, 'under_review'::text, p_reviewer_membership_id;
END
$function$;

CREATE OR REPLACE FUNCTION private.review_wholesale_application_impl(
  p_application_id uuid,
  p_action text,
  p_reason_code text,
  p_valid_until timestamptz,
  p_idempotency_key uuid
)
RETURNS TABLE (
  application_id uuid, application_status text, organization_id uuid,
  owner_membership_id uuid, qualification_id uuid
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_application public.wholesale_applications%ROWTYPE;
  v_event public.wholesale_application_events%ROWTYPE;
  v_key public.p4_idempotency_keys%ROWTYPE;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_org_id uuid; v_owner_id uuid; v_scope_id uuid; v_qualification_id uuid;
  v_target_status text; v_event_code text; v_fingerprint text;
  v_owner_role_valid boolean; v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_application_id IS NULL OR p_idempotency_key IS NULL
     OR p_action IS NULL
     OR p_action NOT IN ('needs_info', 'approve', 'reject')
     OR p_reason_code IS NULL THEN RAISE EXCEPTION 'wholesale_review_invalid'; END IF;
  IF (p_action = 'needs_info' AND p_reason_code <> 'information_incomplete')
     OR (p_action = 'approve' AND p_reason_code <> 'approved_checks_complete')
     OR (p_action = 'reject' AND p_reason_code NOT IN ('eligibility_not_met', 'policy_violation'))
     OR (p_action = 'approve' AND (p_valid_until IS NULL
       OR p_valid_until < v_now + interval '30 days'
       OR p_valid_until > v_now + interval '730 days'))
     OR (p_action <> 'approve' AND p_valid_until IS NOT NULL)
  THEN RAISE EXCEPTION 'wholesale_review_reason_invalid'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p4-idempotency', 0));
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'review_wholesale', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.application_id', p_application_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  v_target_status := CASE p_action WHEN 'needs_info' THEN 'needs_info'
    WHEN 'approve' THEN 'approved' ELSE 'rejected' END;
  v_event_code := 'wholesale_application.' || v_target_status;
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|', p_action, p_reason_code,
    COALESCE(p_valid_until::text, '')));
  SELECT k.* INTO v_key FROM public.p4_idempotency_keys AS k
  WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'wholesale.review'
       OR v_key.target_id IS DISTINCT FROM p_application_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p4_idempotency_conflict'; END IF;
    SELECT e.* INTO v_event FROM public.wholesale_application_events AS e
    WHERE e.actor_user_id = v_uid AND e.idempotency_key = p_idempotency_key;
    SELECT a.* INTO v_application FROM public.wholesale_applications AS a
      WHERE a.id = p_application_id;
    IF v_application.id IS NULL OR v_event.id IS NULL
       OR v_event.assigned_reviewer_membership_id IS NULL
       OR v_uid = v_application.applicant_user_id
       OR NOT private.rebuy_business_membership_has_permission(
         v_event.assigned_reviewer_membership_id, v_uid,
         'wholesale_application.read_assigned')
       OR NOT private.rebuy_business_membership_has_permission(
         v_event.assigned_reviewer_membership_id, v_uid,
         'wholesale_application.review')
    THEN RAISE EXCEPTION 'wholesale_application_not_available'; END IF;
    RETURN QUERY SELECT v_key.application_id, v_key.result_status,
      v_key.organization_id, v_key.membership_id, v_key.qualification_id; RETURN;
  END IF;
  SELECT e.* INTO v_event FROM public.wholesale_application_events AS e
  WHERE e.actor_user_id = v_uid AND e.idempotency_key = p_idempotency_key;
  IF v_event.id IS NOT NULL THEN
    IF v_event.application_id IS DISTINCT FROM p_application_id
       OR v_event.event_code IS DISTINCT FROM v_event_code
       OR v_event.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'wholesale_idempotency_conflict'; END IF;
    SELECT a.* INTO v_application FROM public.wholesale_applications AS a
      WHERE a.id = v_event.application_id;
    IF v_application.id IS NULL OR v_event.assigned_reviewer_membership_id IS NULL
       OR v_uid = v_application.applicant_user_id
       OR NOT private.rebuy_business_membership_has_permission(
         v_event.assigned_reviewer_membership_id, v_uid, 'wholesale_application.read_assigned')
       OR NOT private.rebuy_business_membership_has_permission(
         v_event.assigned_reviewer_membership_id, v_uid, 'wholesale_application.review')
    THEN RAISE EXCEPTION 'wholesale_application_not_available'; END IF;
    RETURN QUERY SELECT v_event.application_id, v_event.to_status,
      v_application.organization_id, v_application.owner_membership_id,
      v_application.qualification_id; RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_application_id::text, 0));
  SELECT a.* INTO v_application FROM public.wholesale_applications AS a
    WHERE a.id = p_application_id FOR UPDATE;
  IF v_application.id IS NULL OR v_application.assigned_reviewer_membership_id IS NULL
     OR v_uid = v_application.applicant_user_id
     OR NOT private.rebuy_business_membership_has_permission(
       v_application.assigned_reviewer_membership_id, v_uid,
       'wholesale_application.read_assigned')
     OR NOT private.rebuy_business_membership_has_permission(
       v_application.assigned_reviewer_membership_id, v_uid,
       'wholesale_application.review')
  THEN RAISE EXCEPTION 'wholesale_application_not_available'; END IF;
  IF v_application.status <> 'under_review' THEN
    RAISE EXCEPTION 'wholesale_application_state_conflict';
  END IF;
  IF p_action = 'approve' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.role_definitions AS rd
      WHERE rd.id = '00000000-0000-4000-8000-000000000201'::uuid
        AND rd.version = 1 AND rd.role_key = 'owner'
        AND rd.scope_type = 'organization' AND rd.is_system
        AND rd.organization_id IS NULL AND rd.organization_type IS NULL
        AND rd.status = 'active' AND rd.assignable
        AND rd.applicable_organization_type IN ('any', 'wholesale')
    ) INTO v_owner_role_valid;
    IF NOT COALESCE(v_owner_role_valid, false) THEN
      RAISE EXCEPTION 'wholesale_owner_role_unavailable';
    END IF;
    v_org_id := pg_catalog.gen_random_uuid();
    v_owner_id := pg_catalog.gen_random_uuid();
    v_scope_id := pg_catalog.gen_random_uuid();
    v_qualification_id := pg_catalog.gen_random_uuid();
    PERFORM pg_catalog.set_config('rebuy.p4.applicant_user_id',
      v_application.applicant_user_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.organization_id', v_org_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.membership_id', v_owner_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.scope_id', v_scope_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.qualification_id', v_qualification_id::text, true);
    INSERT INTO public.organizations (
      id, organization_type, display_name, legal_name, status, created_by,
      verified_at, created_at, updated_at
    ) VALUES (v_org_id, 'wholesale', v_application.company_name, NULL, 'active',
      v_application.applicant_user_id, v_now, v_now, v_now);
    INSERT INTO public.memberships (
      id, user_id, organization_id, organization_type, role_definition_id,
      role_version, role_definition_organization_id,
      role_definition_organization_type, status, invited_by, valid_from,
      created_at, updated_at
    ) VALUES (v_owner_id, v_application.applicant_user_id, v_org_id, 'wholesale',
      '00000000-0000-4000-8000-000000000201'::uuid, 1, NULL, NULL,
      'active', v_uid, v_now, v_now, v_now);
    INSERT INTO public.membership_store_scopes (
      id, membership_id, organization_id, organization_type, store_id,
      scope_type, status, created_at
    ) VALUES (v_scope_id, v_owner_id, v_org_id, 'wholesale', NULL,
      'organization', 'active', v_now);
    INSERT INTO public.wholesale_qualifications (
      id, source_application_id, organization_id, organization_type, status,
      valid_from, valid_until, reason_code, version, created_at, updated_at
    ) VALUES (v_qualification_id, p_application_id, v_org_id, 'wholesale',
      'active', v_now, p_valid_until, 'approved_checks_complete', 1, v_now, v_now);
  END IF;
  UPDATE public.wholesale_applications
  SET status = v_target_status,
    organization_id = CASE WHEN p_action = 'approve' THEN v_org_id ELSE NULL END,
    owner_membership_id = CASE WHEN p_action = 'approve' THEN v_owner_id ELSE NULL END,
    qualification_id = CASE WHEN p_action = 'approve' THEN v_qualification_id ELSE NULL END,
    decided_at = CASE WHEN p_action IN ('approve', 'reject') THEN v_now ELSE NULL END,
    updated_at = v_now
  WHERE id = p_application_id;
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
  INSERT INTO public.wholesale_application_events (
    id, application_id, actor_user_id, event_code, from_status, to_status,
    reason_code, assigned_reviewer_membership_id, qualification_id,
    idempotency_key, request_fingerprint, created_at
  ) VALUES (v_event_id, p_application_id, v_uid, v_event_code,
    v_application.status, v_target_status, p_reason_code,
    v_application.assigned_reviewer_membership_id, v_qualification_id,
    p_idempotency_key, v_fingerprint, v_now);
  INSERT INTO public.p4_idempotency_keys (
    actor_user_id, idempotency_key, operation_code, target_id,
    request_fingerprint, result_status, application_id, organization_id,
    membership_id, qualification_id, created_at
  ) VALUES (v_uid, p_idempotency_key, 'wholesale.review', p_application_id,
    v_fingerprint, v_target_status, p_application_id, v_org_id, v_owner_id,
    v_qualification_id, v_now);
  RETURN QUERY SELECT p_application_id, v_target_status, v_org_id,
    v_owner_id, v_qualification_id;
END
$function$;

CREATE OR REPLACE FUNCTION private.change_wholesale_qualification_impl(
  p_qualification_id uuid,
  p_action text,
  p_idempotency_key uuid
)
RETURNS TABLE (qualification_id uuid, qualification_status text, qualification_version integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_platform_membership_id uuid;
  v_qualification public.wholesale_qualifications%ROWTYPE;
  v_application public.wholesale_applications%ROWTYPE;
  v_event public.wholesale_application_events%ROWTYPE;
  v_key public.p4_idempotency_keys%ROWTYPE;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_target_status text; v_reason text; v_fingerprint text;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_qualification_id IS NULL OR p_idempotency_key IS NULL
     OR p_action IS NULL
     OR p_action NOT IN ('suspend', 'reactivate', 'expire', 'revoke')
  THEN RAISE EXCEPTION 'wholesale_qualification_change_invalid'; END IF;
  v_platform_membership_id := private.rebuy_business_find_platform_membership(
    'wholesale_qualification.manage');
  IF v_platform_membership_id IS NULL THEN RAISE EXCEPTION 'wholesale_review_forbidden'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p4-idempotency', 0));
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'change_qualification', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.qualification_id', p_qualification_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  v_target_status := CASE p_action WHEN 'suspend' THEN 'suspended'
    WHEN 'reactivate' THEN 'active' WHEN 'expire' THEN 'expired' ELSE 'revoked' END;
  v_reason := CASE p_action WHEN 'suspend' THEN 'risk_suspension'
    WHEN 'reactivate' THEN 'approved_checks_complete'
    WHEN 'expire' THEN 'validity_expired' ELSE 'policy_revoked' END;
  v_fingerprint := pg_catalog.md5(p_action);
  SELECT k.* INTO v_key FROM public.p4_idempotency_keys AS k
  WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'qualification.change'
       OR v_key.target_id IS DISTINCT FROM p_qualification_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p4_idempotency_conflict'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p4.application_id', v_key.application_id::text, true);
    SELECT a.* INTO v_application FROM public.wholesale_applications AS a
      WHERE a.id = v_key.application_id;
    IF v_application.id IS NULL OR v_application.assigned_reviewer_membership_id IS NULL
       OR v_uid = v_application.applicant_user_id
       OR NOT private.rebuy_business_membership_has_permission(
         v_application.assigned_reviewer_membership_id, v_uid,
         'wholesale_application.read_assigned')
       OR NOT private.rebuy_business_membership_has_permission(
         v_application.assigned_reviewer_membership_id, v_uid,
         'wholesale_qualification.manage')
    THEN RAISE EXCEPTION 'wholesale_qualification_not_available'; END IF;
    RETURN QUERY SELECT v_key.qualification_id, v_key.result_status,
      v_key.result_version; RETURN;
  END IF;
  SELECT e.* INTO v_event FROM public.wholesale_application_events AS e
  WHERE e.actor_user_id = v_uid AND e.idempotency_key = p_idempotency_key;
  IF v_event.id IS NOT NULL THEN
    IF v_event.qualification_id IS DISTINCT FROM p_qualification_id
       OR v_event.event_code IS DISTINCT FROM ('wholesale_qualification.' ||
         CASE WHEN p_action = 'reactivate' THEN 'activated' ELSE v_target_status END)
       OR v_event.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'wholesale_idempotency_conflict'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p4.application_id', v_event.application_id::text, true);
    SELECT a.* INTO v_application FROM public.wholesale_applications AS a
      WHERE a.id = v_event.application_id;
    IF v_application.id IS NULL OR v_application.assigned_reviewer_membership_id IS NULL
       OR v_uid = v_application.applicant_user_id
       OR NOT private.rebuy_business_membership_has_permission(
         v_application.assigned_reviewer_membership_id, v_uid,
         'wholesale_application.read_assigned')
       OR NOT private.rebuy_business_membership_has_permission(
         v_application.assigned_reviewer_membership_id, v_uid,
         'wholesale_qualification.manage')
    THEN RAISE EXCEPTION 'wholesale_qualification_not_available'; END IF;
    SELECT q.* INTO v_qualification FROM public.wholesale_qualifications AS q
      WHERE q.id = p_qualification_id;
    RETURN QUERY SELECT v_event.qualification_id, v_event.to_status,
      v_qualification.version; RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_qualification_id::text, 0));
  SELECT q.* INTO v_qualification FROM public.wholesale_qualifications AS q
    WHERE q.id = p_qualification_id FOR UPDATE;
  IF v_qualification.id IS NULL THEN RAISE EXCEPTION 'wholesale_qualification_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.organization_id', v_qualification.organization_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.application_id',
    v_qualification.source_application_id::text, true);
  SELECT a.* INTO v_application FROM public.wholesale_applications AS a
    WHERE a.id = v_qualification.source_application_id;
  IF v_application.id IS NULL OR v_application.assigned_reviewer_membership_id IS NULL
     OR v_uid = v_application.applicant_user_id
     OR NOT private.rebuy_business_membership_has_permission(
       v_application.assigned_reviewer_membership_id, v_uid,
       'wholesale_application.read_assigned')
     OR NOT private.rebuy_business_membership_has_permission(
       v_application.assigned_reviewer_membership_id, v_uid,
       'wholesale_qualification.manage')
  THEN RAISE EXCEPTION 'wholesale_qualification_not_available'; END IF;
  IF (p_action = 'suspend' AND v_qualification.status <> 'active')
     OR (p_action = 'reactivate' AND (v_qualification.status <> 'suspended'
       OR v_qualification.valid_until <= v_now))
     OR (p_action IN ('expire', 'revoke')
       AND v_qualification.status NOT IN ('active', 'suspended'))
     OR (p_action = 'expire' AND v_qualification.valid_until > v_now)
  THEN RAISE EXCEPTION 'wholesale_qualification_state_conflict'; END IF;
  UPDATE public.wholesale_qualifications SET status = v_target_status,
    reason_code = v_reason, version = version + 1, updated_at = v_now
  WHERE id = p_qualification_id;
  PERFORM pg_catalog.set_config('rebuy.p4.application_id', v_application.id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
  INSERT INTO public.wholesale_application_events (
    id, application_id, actor_user_id, event_code, from_status, to_status,
    reason_code, assigned_reviewer_membership_id, qualification_id,
    idempotency_key, request_fingerprint, created_at
  ) VALUES (v_event_id, v_application.id, v_uid,
    'wholesale_qualification.' || CASE WHEN p_action = 'reactivate'
      THEN 'activated' ELSE v_target_status END,
    v_qualification.status, v_target_status, v_reason,
    v_application.assigned_reviewer_membership_id, p_qualification_id,
    p_idempotency_key, v_fingerprint, v_now);
  INSERT INTO public.p4_idempotency_keys (
    actor_user_id, idempotency_key, operation_code, target_id,
    request_fingerprint, result_status, result_version, application_id,
    organization_id, qualification_id, created_at
  ) VALUES (v_uid, p_idempotency_key, 'qualification.change', p_qualification_id,
    v_fingerprint, v_target_status, v_qualification.version + 1,
    v_application.id, v_qualification.organization_id, p_qualification_id, v_now);
  RETURN QUERY SELECT p_qualification_id, v_target_status, v_qualification.version + 1;
END
$function$;

CREATE OR REPLACE FUNCTION private.withdraw_wholesale_application_impl(
  p_application_id uuid,
  p_idempotency_key uuid
)
RETURNS TABLE (application_id uuid, application_status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_application public.wholesale_applications%ROWTYPE;
  v_event public.wholesale_application_events%ROWTYPE;
  v_key public.p4_idempotency_keys%ROWTYPE;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_fingerprint text := pg_catalog.md5('withdraw');
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_application_id IS NULL OR p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'wholesale_withdraw_invalid'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p4-idempotency', 0));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':wholesale-application', 0));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_application_id::text, 0));
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'withdraw_wholesale', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.applicant_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.application_id', p_application_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  SELECT k.* INTO v_key FROM public.p4_idempotency_keys AS k
  WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'wholesale.withdraw'
       OR v_key.target_id IS DISTINCT FROM p_application_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p4_idempotency_conflict'; END IF;
    RETURN QUERY SELECT v_key.application_id, v_key.result_status; RETURN;
  END IF;
  SELECT e.* INTO v_event FROM public.wholesale_application_events AS e
  WHERE e.actor_user_id = v_uid AND e.idempotency_key = p_idempotency_key;
  IF v_event.id IS NOT NULL THEN
    IF v_event.application_id IS DISTINCT FROM p_application_id
       OR v_event.event_code IS DISTINCT FROM 'wholesale_application.withdrawn'
       OR v_event.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'wholesale_idempotency_conflict'; END IF;
    RETURN QUERY SELECT v_event.application_id, v_event.to_status; RETURN;
  END IF;
  SELECT a.* INTO v_application FROM public.wholesale_applications AS a
  WHERE a.id = p_application_id AND a.applicant_user_id = v_uid FOR UPDATE;
  IF v_application.id IS NULL THEN RAISE EXCEPTION 'wholesale_application_not_available'; END IF;
  IF v_application.status NOT IN ('draft', 'submitted', 'needs_info') THEN
    RAISE EXCEPTION 'wholesale_application_state_conflict'; END IF;
  UPDATE public.wholesale_applications SET status = 'withdrawn',
    assigned_reviewer_membership_id = NULL, assigned_at = NULL, updated_at = v_now
  WHERE id = p_application_id;
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
  INSERT INTO public.wholesale_application_events (
    id, application_id, actor_user_id, event_code, from_status, to_status,
    idempotency_key, request_fingerprint, created_at
  ) VALUES (v_event_id, p_application_id, v_uid, 'wholesale_application.withdrawn',
    v_application.status, 'withdrawn', p_idempotency_key, v_fingerprint, v_now);
  INSERT INTO public.p4_idempotency_keys (
    actor_user_id, idempotency_key, operation_code, target_id,
    request_fingerprint, result_status, application_id, created_at
  ) VALUES (v_uid, p_idempotency_key, 'wholesale.withdraw', p_application_id,
    v_fingerprint, 'withdrawn', p_application_id, v_now);
  RETURN QUERY SELECT p_application_id, 'withdrawn'::text;
END
$function$;

CREATE OR REPLACE FUNCTION private.upsert_catalog_listing_impl(
  p_listing_id uuid,
  p_store_id uuid,
  p_category_slug text,
  p_product_kind text,
  p_internal_name text,
  p_sku text,
  p_listing_slug text,
  p_title text,
  p_summary text,
  p_retail_cents integer,
  p_wholesale_cents integer,
  p_wholesale_minimum integer,
  p_wholesale_tiers jsonb,
  p_initial_stock integer,
  p_synthetic_serial_reference text,
  p_condition_code text,
  p_defect_code text,
  p_battery_health_percent integer,
  p_warranty_days integer,
  p_publish boolean,
  p_expected_version integer,
  p_idempotency_key uuid
)
RETURNS TABLE (
  listing_id uuid, product_id uuid, variant_id uuid,
  listing_status text, listing_version integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_store record; v_listing public.listings%ROWTYPE;
  v_key public.p4_idempotency_keys%ROWTYPE; v_category_id uuid;
  v_product_id uuid; v_variant_id uuid; v_listing_id uuid;
  v_inventory_id uuid; v_unit_id uuid; v_event_id uuid := pg_catalog.gen_random_uuid();
  v_retail_price_id uuid := pg_catalog.gen_random_uuid();
  v_wholesale_price_id uuid := pg_catalog.gen_random_uuid();
  v_version integer; v_status text; v_fingerprint text;
  v_tier jsonb; v_tier_min integer; v_tier_price integer;
  v_previous_min integer := 0; v_previous_price integer;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_store_id IS NULL OR p_idempotency_key IS NULL OR p_publish IS NULL
     OR p_product_kind IS NULL
     OR p_product_kind NOT IN ('standard', 'secondhand')
     OR p_category_slug IS NULL OR pg_catalog.lower(pg_catalog.btrim(p_category_slug))
       !~ '^[a-z0-9][a-z0-9-]{1,47}$'
     OR p_internal_name IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_internal_name)) NOT BETWEEN 2 AND 120
     OR p_sku IS NULL OR pg_catalog.upper(pg_catalog.btrim(p_sku)) !~ '^SYN-SKU-[A-Z0-9-]{2,40}$'
     OR p_listing_slug IS NULL OR pg_catalog.lower(pg_catalog.btrim(p_listing_slug))
       !~ '^[a-z0-9][a-z0-9-]{1,63}$'
     OR p_title IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_title)) NOT BETWEEN 2 AND 120
     OR p_summary IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_summary)) NOT BETWEEN 2 AND 240
     OR p_retail_cents IS NULL OR p_retail_cents <= 0
     OR p_wholesale_tiers IS NULL OR pg_catalog.jsonb_typeof(p_wholesale_tiers) <> 'array'
     OR pg_catalog.jsonb_array_length(p_wholesale_tiers) > 8
     OR p_expected_version IS NULL OR p_expected_version < 0
  THEN RAISE EXCEPTION 'catalog_listing_invalid'; END IF;
  IF p_wholesale_cents IS NULL THEN
    IF p_wholesale_minimum IS NOT NULL OR p_wholesale_tiers <> '[]'::jsonb THEN
      RAISE EXCEPTION 'catalog_wholesale_rule_invalid'; END IF;
  ELSIF p_wholesale_cents <= 0 OR p_wholesale_cents > p_retail_cents
     OR p_wholesale_minimum IS NULL OR p_wholesale_minimum < 2 THEN
    RAISE EXCEPTION 'catalog_wholesale_rule_invalid';
  END IF;
  IF p_product_kind = 'standard' THEN
    IF p_listing_id IS NULL AND (p_initial_stock IS NULL OR p_initial_stock < 0
      OR p_initial_stock > 1000000) THEN RAISE EXCEPTION 'catalog_inventory_invalid'; END IF;
    IF p_listing_id IS NOT NULL AND p_initial_stock IS NOT NULL THEN
      RAISE EXCEPTION 'catalog_inventory_invalid'; END IF;
    IF p_synthetic_serial_reference IS NOT NULL OR p_condition_code IS NOT NULL
       OR p_defect_code IS NOT NULL OR p_battery_health_percent IS NOT NULL
       OR p_warranty_days IS NOT NULL THEN RAISE EXCEPTION 'catalog_secondhand_invalid'; END IF;
  ELSE
    IF p_initial_stock IS NOT NULL
       OR p_synthetic_serial_reference IS NULL
       OR pg_catalog.upper(pg_catalog.btrim(p_synthetic_serial_reference))
         !~ '^SYN-UNIT-[A-Z0-9-]{4,40}$'
       OR p_condition_code IS NULL
       OR p_condition_code NOT IN ('like_new', 'good', 'fair')
       OR p_defect_code IS NULL
       OR p_defect_code NOT IN ('none', 'cosmetic_wear', 'screen_mark', 'housing_mark')
       OR p_warranty_days IS NULL OR p_warranty_days NOT BETWEEN 0 AND 730
       OR (p_battery_health_percent IS NOT NULL
         AND p_battery_health_percent NOT BETWEEN 50 AND 100)
    THEN RAISE EXCEPTION 'catalog_secondhand_invalid'; END IF;
  END IF;
  v_previous_price := p_wholesale_cents;
  FOR v_tier IN SELECT value FROM pg_catalog.jsonb_array_elements(p_wholesale_tiers)
  LOOP
    IF pg_catalog.jsonb_typeof(v_tier) <> 'object'
       OR NOT (v_tier ? 'minimum_quantity') OR NOT (v_tier ? 'unit_amount_cents')
       OR (v_tier->>'minimum_quantity') IS NULL
       OR (v_tier->>'unit_amount_cents') IS NULL
       OR (v_tier->>'minimum_quantity') !~ '^[0-9]{1,7}$'
       OR (v_tier->>'unit_amount_cents') !~ '^[0-9]{1,9}$'
    THEN RAISE EXCEPTION 'catalog_wholesale_tier_invalid'; END IF;
    v_tier_min := (v_tier->>'minimum_quantity')::integer;
    v_tier_price := (v_tier->>'unit_amount_cents')::integer;
    IF p_wholesale_cents IS NULL OR v_tier_min <= p_wholesale_minimum
       OR v_tier_min <= v_previous_min OR v_tier_price <= 0
       OR v_tier_price > v_previous_price
    THEN RAISE EXCEPTION 'catalog_wholesale_tier_invalid'; END IF;
    v_previous_min := v_tier_min; v_previous_price := v_tier_price;
  END LOOP;
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|', COALESCE(p_listing_id::text, ''),
    p_store_id::text, pg_catalog.lower(pg_catalog.btrim(p_category_slug)), p_product_kind,
    pg_catalog.btrim(p_internal_name), pg_catalog.upper(pg_catalog.btrim(p_sku)),
    pg_catalog.lower(pg_catalog.btrim(p_listing_slug)), pg_catalog.btrim(p_title),
    pg_catalog.btrim(p_summary), p_retail_cents::text, COALESCE(p_wholesale_cents::text, ''),
    COALESCE(p_wholesale_minimum::text, ''), p_wholesale_tiers::text,
    COALESCE(p_initial_stock::text, ''), COALESCE(p_synthetic_serial_reference, ''),
    COALESCE(p_condition_code, ''), COALESCE(p_defect_code, ''),
    COALESCE(p_battery_health_percent::text, ''), COALESCE(p_warranty_days::text, ''),
    p_publish::text, p_expected_version::text));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p4-idempotency', 0));
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_upsert', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.store_id', p_store_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  SELECT s.id, s.organization_id, s.organization_type, s.status
  INTO v_store FROM public.stores AS s WHERE s.id = p_store_id;
  IF v_store.id IS NULL OR v_store.organization_type <> 'merchant' OR v_store.status <> 'active'
  THEN RAISE EXCEPTION 'catalog_store_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.organization_id', v_store.organization_id::text, true);
  IF private.rebuy_p4_find_merchant_membership(v_uid, v_store.organization_id,
      p_store_id, 'catalog.write') IS NULL
     OR private.rebuy_p4_find_merchant_membership(v_uid, v_store.organization_id,
      p_store_id, 'listing.publish') IS NULL
     OR private.rebuy_p4_find_merchant_membership(v_uid, v_store.organization_id,
      p_store_id, 'pricing.write') IS NULL
  THEN RAISE EXCEPTION 'catalog_write_forbidden'; END IF;
  SELECT k.* INTO v_key FROM public.p4_idempotency_keys AS k
    WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'catalog.upsert'
       OR v_key.target_id IS DISTINCT FROM p_listing_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p4_idempotency_conflict'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p4.listing_id', v_key.listing_id::text, true);
    RETURN QUERY SELECT v_key.listing_id,
      (SELECT l.product_id FROM public.listings AS l WHERE l.id = v_key.listing_id),
      (SELECT l.variant_id FROM public.listings AS l WHERE l.id = v_key.listing_id),
      v_key.result_status, v_key.result_version; RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'catalog:store-slug:' || p_store_id::text || ':' ||
      pg_catalog.lower(pg_catalog.btrim(p_listing_slug)), 0));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'catalog:org-sku:' || v_store.organization_id::text || ':' ||
      pg_catalog.upper(pg_catalog.btrim(p_sku)), 0));
  IF p_product_kind = 'secondhand' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
      'catalog:unit-serial:' ||
        pg_catalog.upper(pg_catalog.btrim(p_synthetic_serial_reference)), 0));
  END IF;
  SELECT c.id INTO v_category_id FROM public.categories AS c
  WHERE c.slug = pg_catalog.lower(pg_catalog.btrim(p_category_slug)) AND c.status = 'active';
  IF v_category_id IS NULL THEN RAISE EXCEPTION 'catalog_category_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.category_id', v_category_id::text, true);
  IF p_listing_id IS NULL THEN
    IF p_expected_version <> 0 THEN RAISE EXCEPTION 'catalog_version_conflict'; END IF;
    v_product_id := pg_catalog.gen_random_uuid(); v_variant_id := pg_catalog.gen_random_uuid();
    v_listing_id := pg_catalog.gen_random_uuid(); v_version := 1;
    v_status := CASE WHEN p_publish THEN 'active' ELSE 'draft' END;
    IF p_publish AND ((p_product_kind = 'standard' AND p_initial_stock <= 0)
      OR p_product_kind = 'secondhand' AND p_synthetic_serial_reference IS NULL)
    THEN RAISE EXCEPTION 'catalog_publish_inventory_required'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p4.product_id', v_product_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.variant_id', v_variant_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.listing_id', v_listing_id::text, true);
    INSERT INTO public.products (id, organization_id, organization_type, category_id,
      product_kind, internal_name, status, created_by, created_at, updated_at)
    VALUES (v_product_id, v_store.organization_id, 'merchant', v_category_id,
      p_product_kind, pg_catalog.btrim(p_internal_name), 'active', v_uid, v_now, v_now);
    INSERT INTO public.product_variants (id, product_id, organization_id,
      organization_type, sku, unit_code, status, created_at, updated_at)
    VALUES (v_variant_id, v_product_id, v_store.organization_id, 'merchant',
      pg_catalog.upper(pg_catalog.btrim(p_sku)), 'unit', 'active', v_now, v_now);
    INSERT INTO public.listings (id, organization_id, organization_type, store_id,
      product_id, variant_id, product_kind, slug, title, summary, status, version,
      published_at, created_by, created_at, updated_at)
    VALUES (v_listing_id, v_store.organization_id, 'merchant', p_store_id,
      v_product_id, v_variant_id, p_product_kind,
      pg_catalog.lower(pg_catalog.btrim(p_listing_slug)), pg_catalog.btrim(p_title),
      pg_catalog.btrim(p_summary), v_status, v_version,
      CASE WHEN p_publish THEN v_now ELSE NULL END, v_uid, v_now, v_now);
    IF p_product_kind = 'standard' THEN
      v_inventory_id := pg_catalog.gen_random_uuid();
      PERFORM pg_catalog.set_config('rebuy.p4.inventory_id', v_inventory_id::text, true);
      INSERT INTO public.inventory_levels (id, listing_id, organization_id,
        organization_type, store_id, on_hand, reserved, version, updated_at)
      VALUES (v_inventory_id, v_listing_id, v_store.organization_id, 'merchant',
        p_store_id, p_initial_stock, 0, 1, v_now);
    ELSE
      v_unit_id := pg_catalog.gen_random_uuid();
      PERFORM pg_catalog.set_config('rebuy.p4.unit_id', v_unit_id::text, true);
      INSERT INTO public.secondhand_units (id, listing_id, product_kind,
        synthetic_serial_reference, condition_code, defect_code,
        battery_health_percent, warranty_days, status, version, updated_at)
      VALUES (v_unit_id, v_listing_id, 'secondhand',
        pg_catalog.upper(pg_catalog.btrim(p_synthetic_serial_reference)),
        p_condition_code, p_defect_code, p_battery_health_percent,
        p_warranty_days, 'available', 1, v_now);
    END IF;
  ELSE
    v_listing_id := p_listing_id;
    PERFORM pg_catalog.set_config('rebuy.p4.listing_id', v_listing_id::text, true);
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_listing_id::text, 0));
    SELECT l.* INTO v_listing FROM public.listings AS l
    WHERE l.id = v_listing_id AND l.store_id = p_store_id FOR UPDATE;
    IF v_listing.id IS NULL OR v_listing.organization_id <> v_store.organization_id
       OR v_listing.product_kind <> p_product_kind
    THEN RAISE EXCEPTION 'catalog_listing_not_available'; END IF;
    IF v_listing.version <> p_expected_version THEN RAISE EXCEPTION 'catalog_version_conflict'; END IF;
    v_product_id := v_listing.product_id; v_variant_id := v_listing.variant_id;
    v_version := v_listing.version + 1;
    v_status := CASE WHEN p_publish THEN 'active' ELSE 'inactive' END;
    PERFORM pg_catalog.set_config('rebuy.p4.product_id', v_product_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.variant_id', v_variant_id::text, true);
    IF p_publish AND NOT EXISTS (
      SELECT 1 FROM public.inventory_levels AS il WHERE il.listing_id = v_listing_id
        AND il.on_hand - il.reserved > 0
      UNION ALL
      SELECT 1 FROM public.secondhand_units AS su WHERE su.listing_id = v_listing_id
        AND su.status = 'available'
    ) THEN RAISE EXCEPTION 'catalog_publish_inventory_required'; END IF;
    UPDATE public.products SET category_id = v_category_id,
      internal_name = pg_catalog.btrim(p_internal_name), status = 'active', updated_at = v_now
    WHERE id = v_product_id;
    UPDATE public.product_variants SET sku = pg_catalog.upper(pg_catalog.btrim(p_sku)),
      status = 'active', updated_at = v_now WHERE id = v_variant_id;
    UPDATE public.listings SET slug = pg_catalog.lower(pg_catalog.btrim(p_listing_slug)),
      title = pg_catalog.btrim(p_title), summary = pg_catalog.btrim(p_summary),
      status = v_status, version = v_version,
      published_at = CASE WHEN p_publish THEN COALESCE(published_at, v_now) ELSE published_at END,
      updated_at = v_now WHERE id = v_listing_id;
    IF p_product_kind = 'secondhand' THEN
      SELECT su.id INTO v_unit_id FROM public.secondhand_units AS su
        WHERE su.listing_id = v_listing_id;
      PERFORM pg_catalog.set_config('rebuy.p4.unit_id', v_unit_id::text, true);
      UPDATE public.secondhand_units
      SET synthetic_serial_reference = pg_catalog.upper(pg_catalog.btrim(p_synthetic_serial_reference)),
        condition_code = p_condition_code, defect_code = p_defect_code,
        battery_health_percent = p_battery_health_percent, warranty_days = p_warranty_days,
        updated_at = v_now WHERE id = v_unit_id AND status IN ('available', 'inactive');
      IF NOT FOUND THEN RAISE EXCEPTION 'catalog_secondhand_state_conflict'; END IF;
    END IF;
  END IF;
  UPDATE public.listing_prices AS lp
  SET status = 'superseded', valid_until = v_now
  WHERE lp.listing_id = v_listing_id AND lp.status = 'active';
  PERFORM pg_catalog.set_config('rebuy.p4.price_id', v_retail_price_id::text, true);
  INSERT INTO public.listing_prices (id, listing_id, organization_id,
    organization_type, store_id, audience, currency_code, unit_amount_cents,
    minimum_quantity, version, status, valid_from, created_by, created_at)
  VALUES (v_retail_price_id, v_listing_id, v_store.organization_id, 'merchant',
    p_store_id, 'retail', 'EUR', p_retail_cents, 1, v_version, 'active', v_now,
    v_uid, v_now);
  IF p_wholesale_cents IS NOT NULL THEN
    PERFORM pg_catalog.set_config('rebuy.p4.price_id', v_wholesale_price_id::text, true);
    INSERT INTO public.listing_prices (id, listing_id, organization_id,
      organization_type, store_id, audience, currency_code, unit_amount_cents,
      minimum_quantity, version, status, valid_from, created_by, created_at)
    VALUES (v_wholesale_price_id, v_listing_id, v_store.organization_id, 'merchant',
      p_store_id, 'wholesale', 'EUR', p_wholesale_cents, p_wholesale_minimum,
      v_version, 'active', v_now, v_uid, v_now);
    FOR v_tier IN SELECT value FROM pg_catalog.jsonb_array_elements(p_wholesale_tiers)
    LOOP
      INSERT INTO public.listing_price_tiers (price_id, listing_id,
        minimum_quantity, unit_amount_cents)
      VALUES (v_wholesale_price_id, v_listing_id,
        (v_tier->>'minimum_quantity')::integer,
        (v_tier->>'unit_amount_cents')::integer);
    END LOOP;
  END IF;
  IF p_publish THEN
    UPDATE public.stores SET public_visibility = true, updated_at = v_now
      WHERE id = p_store_id;
  END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
  INSERT INTO public.catalog_events (id, actor_user_id, organization_id,
    organization_type, store_id, listing_id, event_code, from_version,
    to_version, idempotency_key, request_fingerprint, created_at)
  VALUES (v_event_id, v_uid, v_store.organization_id, 'merchant', p_store_id,
    v_listing_id, CASE WHEN p_listing_id IS NULL THEN 'catalog.listing_created'
      WHEN NOT p_publish THEN 'catalog.listing_deactivated'
      ELSE 'catalog.listing_updated' END,
    CASE WHEN p_listing_id IS NULL THEN NULL ELSE p_expected_version END,
    v_version, p_idempotency_key, v_fingerprint, v_now);
  INSERT INTO public.p4_idempotency_keys (actor_user_id, idempotency_key,
    operation_code, target_id, request_fingerprint, result_status,
    result_version, organization_id, listing_id, inventory_id,
    secondhand_unit_id, created_at)
  VALUES (v_uid, p_idempotency_key, 'catalog.upsert', p_listing_id,
    v_fingerprint, v_status, v_version, v_store.organization_id,
    v_listing_id, v_inventory_id, v_unit_id, v_now);
  RETURN QUERY SELECT v_listing_id, v_product_id, v_variant_id, v_status, v_version;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'catalog_unique_conflict';
  WHEN integrity_constraint_violation THEN
    RAISE EXCEPTION 'catalog_integrity_conflict';
END
$function$;

CREATE OR REPLACE FUNCTION private.get_catalog_quote_impl(
  p_listing_id uuid,
  p_quantity integer
)
RETURNS TABLE (
  listing_id uuid, audience text, currency_code text,
  unit_amount_cents integer, minimum_quantity integer,
  available_quantity integer, price_version integer,
  listing_version integer, purchasable boolean
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_listing public.listings%ROWTYPE;
  v_price public.listing_prices%ROWTYPE; v_qualification_id uuid;
  v_available integer; v_unit_amount integer;
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  IF p_listing_id IS NULL OR p_quantity IS NULL OR p_quantity < 1
     OR p_quantity > 1000000 THEN RAISE EXCEPTION 'catalog_quote_invalid'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
  PERFORM pg_catalog.set_config('rebuy.p4.listing_id', p_listing_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  SELECT l.* INTO v_listing
  FROM public.listings AS l
  JOIN public.products AS p ON p.id = l.product_id
  JOIN public.product_variants AS pv ON pv.id = l.variant_id
  JOIN public.stores AS s ON s.id = l.store_id
  JOIN public.organizations AS o ON o.id = l.organization_id
  WHERE l.id = p_listing_id AND l.status = 'active'
    AND p.status = 'active' AND pv.status = 'active'
    AND s.status = 'active' AND s.public_visibility AND o.status = 'active';
  IF v_listing.id IS NULL THEN RAISE EXCEPTION 'catalog_listing_not_available'; END IF;
  IF v_listing.product_kind = 'standard' THEN
    SELECT il.on_hand - il.reserved INTO v_available
    FROM public.inventory_levels AS il WHERE il.listing_id = p_listing_id;
  ELSE
    SELECT CASE WHEN su.status = 'available' THEN 1 ELSE 0 END INTO v_available
    FROM public.secondhand_units AS su WHERE su.listing_id = p_listing_id;
  END IF;
  v_available := COALESCE(v_available, 0);
  IF v_available <= 0 THEN
    RAISE EXCEPTION 'catalog_listing_not_available';
  END IF;
  v_uid := private.rebuy_request_uid();
  IF v_uid IS NOT NULL THEN
    PERFORM i.user_id FROM private.rebuy_business_require_identity(false) AS i;
    v_qualification_id := private.rebuy_p4_active_wholesale_qualification(v_uid);
  END IF;
  IF v_qualification_id IS NOT NULL THEN
    SELECT lp.* INTO v_price FROM public.listing_prices AS lp
    WHERE lp.listing_id = p_listing_id AND lp.audience = 'wholesale'
      AND lp.status = 'active' AND lp.valid_from <= pg_catalog.statement_timestamp()
      AND (lp.valid_until IS NULL OR lp.valid_until > pg_catalog.statement_timestamp());
  END IF;
  IF v_price.id IS NULL THEN
    SELECT lp.* INTO v_price FROM public.listing_prices AS lp
    WHERE lp.listing_id = p_listing_id AND lp.audience = 'retail'
      AND lp.status = 'active' AND lp.valid_from <= pg_catalog.statement_timestamp()
      AND (lp.valid_until IS NULL OR lp.valid_until > pg_catalog.statement_timestamp());
  END IF;
  IF v_price.id IS NULL THEN RAISE EXCEPTION 'catalog_price_not_available'; END IF;
  v_unit_amount := v_price.unit_amount_cents;
  IF v_price.audience = 'wholesale' THEN
    SELECT t.unit_amount_cents INTO v_unit_amount
    FROM public.listing_price_tiers AS t
    WHERE t.price_id = v_price.id AND t.minimum_quantity <= p_quantity
    ORDER BY t.minimum_quantity DESC LIMIT 1;
    v_unit_amount := COALESCE(v_unit_amount, v_price.unit_amount_cents);
  END IF;
  RETURN QUERY SELECT v_listing.id, v_price.audience, v_price.currency_code,
    v_unit_amount, v_price.minimum_quantity, v_available, v_price.version,
    v_listing.version, (p_quantity >= v_price.minimum_quantity
      AND p_quantity <= v_available
      AND (v_listing.product_kind = 'standard' OR p_quantity = 1));
END
$function$;

CREATE OR REPLACE FUNCTION private.list_public_catalog_impl()
RETURNS TABLE (
  listing_id uuid, store_id uuid, store_name text, category_slug text,
  product_kind text, listing_slug text, title text, summary text,
  retail_cents integer, currency_code text, available_quantity integer,
  listing_version integer
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  RETURN QUERY
  SELECT l.id, l.store_id, s.display_name, c.slug, l.product_kind, l.slug,
    l.title, l.summary, lp.unit_amount_cents, lp.currency_code,
    CASE WHEN l.product_kind = 'standard' THEN il.on_hand - il.reserved
      WHEN su.status = 'available' THEN 1 ELSE 0 END,
    l.version
  FROM public.listings AS l
  JOIN public.products AS p ON p.id = l.product_id AND p.status = 'active'
  JOIN public.product_variants AS pv ON pv.id = l.variant_id AND pv.status = 'active'
  JOIN public.categories AS c ON c.id = p.category_id AND c.status = 'active'
  JOIN public.stores AS s ON s.id = l.store_id AND s.status = 'active'
    AND s.public_visibility
  JOIN public.organizations AS o ON o.id = l.organization_id AND o.status = 'active'
  JOIN public.listing_prices AS lp ON lp.listing_id = l.id
    AND lp.audience = 'retail' AND lp.status = 'active'
    AND lp.valid_from <= pg_catalog.statement_timestamp()
    AND (lp.valid_until IS NULL OR lp.valid_until > pg_catalog.statement_timestamp())
  LEFT JOIN public.inventory_levels AS il ON il.listing_id = l.id
  LEFT JOIN public.secondhand_units AS su ON su.listing_id = l.id
  WHERE l.status = 'active'
    AND ((l.product_kind = 'standard' AND il.on_hand - il.reserved > 0)
      OR (l.product_kind = 'secondhand' AND su.status = 'available'))
  ORDER BY l.published_at DESC, l.id;
END
$function$;

CREATE OR REPLACE FUNCTION private.adjust_inventory_impl(
  p_listing_id uuid,
  p_quantity_delta integer,
  p_expected_version integer,
  p_idempotency_key uuid
)
RETURNS TABLE (
  listing_id uuid, on_hand integer, reserved integer,
  available integer, inventory_version integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_listing public.listings%ROWTYPE;
  v_inventory public.inventory_levels%ROWTYPE; v_key public.p4_idempotency_keys%ROWTYPE;
  v_store_status text;
  v_event_id uuid := pg_catalog.gen_random_uuid(); v_fingerprint text;
  v_result_on_hand bigint;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_listing_id IS NULL OR p_idempotency_key IS NULL OR p_quantity_delta IS NULL
     OR p_quantity_delta = 0 OR p_quantity_delta NOT BETWEEN -1000000 AND 1000000
     OR p_expected_version IS NULL OR p_expected_version < 1
  THEN RAISE EXCEPTION 'inventory_adjust_invalid'; END IF;
  v_fingerprint := pg_catalog.md5(p_quantity_delta::text || '|' || p_expected_version::text);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p4-idempotency', 0));
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'inventory_adjust', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.listing_id', p_listing_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  SELECT l.* INTO v_listing FROM public.listings AS l WHERE l.id = p_listing_id;
  IF v_listing.id IS NULL OR v_listing.product_kind <> 'standard'
  THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.organization_id', v_listing.organization_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.store_id', v_listing.store_id::text, true);
  SELECT s.status INTO v_store_status FROM public.stores AS s
    WHERE s.id = v_listing.store_id AND s.organization_id = v_listing.organization_id;
  IF v_store_status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'inventory_not_available'; END IF;
  IF private.rebuy_p4_find_merchant_membership(v_uid, v_listing.organization_id,
      v_listing.store_id, 'inventory.adjust') IS NULL
  THEN RAISE EXCEPTION 'inventory_adjust_forbidden'; END IF;
  SELECT k.* INTO v_key FROM public.p4_idempotency_keys AS k
    WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'inventory.adjust'
       OR v_key.target_id IS DISTINCT FROM p_listing_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p4_idempotency_conflict'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p4.inventory_id', v_key.inventory_id::text, true);
    RETURN QUERY SELECT p_listing_id, v_key.result_on_hand,
      v_key.result_reserved, v_key.result_available, v_key.result_version; RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_listing_id::text, 0));
  SELECT il.* INTO v_inventory FROM public.inventory_levels AS il
    WHERE il.listing_id = p_listing_id FOR UPDATE;
  IF v_inventory.id IS NULL THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.inventory_id', v_inventory.id::text, true);
  IF v_inventory.version <> p_expected_version THEN RAISE EXCEPTION 'inventory_version_conflict'; END IF;
  v_result_on_hand := v_inventory.on_hand::bigint + p_quantity_delta::bigint;
  IF v_result_on_hand < v_inventory.reserved::bigint
     OR v_result_on_hand < 0 OR v_result_on_hand > 1000000
  THEN RAISE EXCEPTION 'inventory_quantity_conflict'; END IF;
  UPDATE public.inventory_levels AS il
  SET on_hand = v_result_on_hand::integer,
    version = il.version + 1, updated_at = v_now
  WHERE il.id = v_inventory.id;
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
  INSERT INTO public.inventory_events (id, actor_user_id, organization_id,
    organization_type, store_id, listing_id, inventory_id, event_code,
    quantity_delta, reserved_delta, from_version, to_version, idempotency_key,
    request_fingerprint, created_at)
  VALUES (v_event_id, v_uid, v_listing.organization_id, 'merchant', v_listing.store_id,
    p_listing_id, v_inventory.id, 'inventory.adjusted', p_quantity_delta, 0,
    v_inventory.version, v_inventory.version + 1, p_idempotency_key,
    v_fingerprint, v_now);
  INSERT INTO public.p4_idempotency_keys (actor_user_id, idempotency_key,
    operation_code, target_id, request_fingerprint, result_status,
    result_version, result_on_hand, result_reserved, result_available,
    organization_id, listing_id, inventory_id, created_at)
  VALUES (v_uid, p_idempotency_key, 'inventory.adjust', p_listing_id,
    v_fingerprint, 'adjusted', v_inventory.version + 1,
    v_result_on_hand::integer, v_inventory.reserved,
    (v_result_on_hand - v_inventory.reserved::bigint)::integer,
    v_listing.organization_id, p_listing_id, v_inventory.id, v_now);
  RETURN QUERY SELECT p_listing_id, v_result_on_hand::integer,
    v_inventory.reserved,
    (v_result_on_hand - v_inventory.reserved::bigint)::integer,
    v_inventory.version + 1;
END
$function$;

CREATE OR REPLACE FUNCTION private.change_inventory_reservation_impl(
  p_listing_id uuid,
  p_quantity integer,
  p_action text,
  p_expected_version integer,
  p_synthetic_order_reference text,
  p_idempotency_key uuid
)
RETURNS TABLE (
  listing_id uuid, inventory_kind text, inventory_status text,
  available_quantity integer, inventory_version integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_listing public.listings%ROWTYPE;
  v_inventory public.inventory_levels%ROWTYPE;
  v_unit public.secondhand_units%ROWTYPE;
  v_key public.p4_idempotency_keys%ROWTYPE;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_operation text; v_event_code text; v_result_status text;
  v_fingerprint text; v_available integer; v_result_version integer;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_listing_id IS NULL OR p_idempotency_key IS NULL
     OR p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 1000000
     OR p_action IS NULL
     OR p_action NOT IN ('reserve', 'release', 'sell')
     OR p_expected_version IS NULL OR p_expected_version < 1
     OR p_synthetic_order_reference IS NULL
     OR pg_catalog.upper(pg_catalog.btrim(p_synthetic_order_reference))
       !~ '^SYN-ORDER-[A-Z0-9-]{4,40}$'
  THEN RAISE EXCEPTION 'inventory_reservation_invalid'; END IF;
  v_operation := CASE p_action WHEN 'reserve' THEN 'inventory.reserve'
    WHEN 'release' THEN 'inventory.release' ELSE 'inventory.sell' END;
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|', p_listing_id::text,
    p_quantity::text, p_action, p_expected_version::text,
    pg_catalog.upper(pg_catalog.btrim(p_synthetic_order_reference))));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p4-idempotency', 0));
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'inventory_reservation', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.listing_id', p_listing_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  SELECT k.* INTO v_key FROM public.p4_idempotency_keys AS k
    WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM v_operation
       OR v_key.target_id IS DISTINCT FROM p_listing_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p4_idempotency_conflict'; END IF;
    IF v_key.inventory_id IS NOT NULL THEN
      PERFORM pg_catalog.set_config('rebuy.p4.inventory_id', v_key.inventory_id::text, true);
      RETURN QUERY SELECT p_listing_id, 'standard'::text, v_key.result_status,
        v_key.result_available, v_key.result_version; RETURN;
    END IF;
    PERFORM pg_catalog.set_config('rebuy.p4.unit_id', v_key.secondhand_unit_id::text, true);
    RETURN QUERY SELECT p_listing_id, 'secondhand'::text, v_key.result_status,
      v_key.result_available,
      v_key.result_version; RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_listing_id::text, 0));
  SELECT l.* INTO v_listing FROM public.listings AS l
  WHERE l.id = p_listing_id AND l.status = 'active';
  IF v_listing.id IS NULL THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.organization_id', v_listing.organization_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.store_id', v_listing.store_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.product_id', v_listing.product_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.variant_id', v_listing.variant_id::text, true);
  IF NOT EXISTS (
    SELECT 1
    FROM public.products AS p
    JOIN public.product_variants AS pv
      ON pv.id = v_listing.variant_id AND pv.product_id = p.id
    JOIN public.stores AS s ON s.id = v_listing.store_id
    JOIN public.organizations AS o
      ON o.id = v_listing.organization_id AND o.organization_type = 'merchant'
    WHERE p.id = v_listing.product_id
      AND p.organization_id = v_listing.organization_id
      AND p.status = 'active' AND pv.status = 'active'
      AND s.organization_id = v_listing.organization_id
      AND s.status = 'active' AND s.public_visibility
      AND o.status = 'active'
  ) THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
  IF v_listing.product_kind = 'standard' THEN
    SELECT il.* INTO v_inventory FROM public.inventory_levels AS il
      WHERE il.listing_id = p_listing_id FOR UPDATE;
    IF v_inventory.id IS NULL THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p4.inventory_id', v_inventory.id::text, true);
    IF v_inventory.version <> p_expected_version THEN
      RAISE EXCEPTION 'inventory_version_conflict'; END IF;
    IF p_action = 'reserve' THEN
      IF v_inventory.on_hand - v_inventory.reserved < p_quantity THEN
        RAISE EXCEPTION 'inventory_quantity_conflict'; END IF;
      UPDATE public.inventory_levels SET reserved = reserved + p_quantity,
        version = version + 1, updated_at = v_now WHERE id = v_inventory.id;
      v_event_code := 'inventory.reserved'; v_result_status := 'reserved';
    ELSIF p_action = 'release' THEN
      IF v_inventory.reserved < p_quantity THEN
        RAISE EXCEPTION 'inventory_quantity_conflict'; END IF;
      UPDATE public.inventory_levels SET reserved = reserved - p_quantity,
        version = version + 1, updated_at = v_now WHERE id = v_inventory.id;
      v_event_code := 'inventory.released'; v_result_status := 'released';
    ELSE
      IF v_inventory.reserved < p_quantity OR v_inventory.on_hand < p_quantity THEN
        RAISE EXCEPTION 'inventory_quantity_conflict'; END IF;
      UPDATE public.inventory_levels SET on_hand = on_hand - p_quantity,
        reserved = reserved - p_quantity, version = version + 1,
        updated_at = v_now WHERE id = v_inventory.id;
      v_event_code := 'inventory.sold'; v_result_status := 'sold';
    END IF;
    v_result_version := v_inventory.version + 1;
    SELECT il.on_hand - il.reserved INTO v_available
      FROM public.inventory_levels AS il WHERE il.id = v_inventory.id;
    PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
    INSERT INTO public.inventory_events (id, actor_user_id, organization_id,
      organization_type, store_id, listing_id, inventory_id, event_code,
      quantity_delta, reserved_delta, from_version, to_version,
      idempotency_key, request_fingerprint, created_at)
    VALUES (v_event_id, v_uid, v_listing.organization_id, 'merchant',
      v_listing.store_id, p_listing_id, v_inventory.id, v_event_code,
      CASE WHEN p_action = 'sell' THEN -p_quantity ELSE 0 END,
      CASE WHEN p_action = 'reserve' THEN p_quantity ELSE -p_quantity END,
      v_inventory.version, v_result_version, p_idempotency_key,
      v_fingerprint, v_now);
    INSERT INTO public.p4_idempotency_keys (actor_user_id, idempotency_key,
      operation_code, target_id, request_fingerprint, result_status,
      result_version, result_on_hand, result_reserved, result_available,
      organization_id, listing_id, inventory_id, created_at)
    VALUES (v_uid, p_idempotency_key,
      CASE p_action WHEN 'reserve' THEN 'inventory.reserve'
        WHEN 'release' THEN 'inventory.release' ELSE 'inventory.sell' END,
      p_listing_id, v_fingerprint, v_result_status, v_result_version,
      CASE WHEN p_action = 'sell' THEN v_inventory.on_hand - p_quantity
        ELSE v_inventory.on_hand END,
      CASE WHEN p_action = 'reserve' THEN v_inventory.reserved + p_quantity
        ELSE v_inventory.reserved - p_quantity END,
      v_available,
      v_listing.organization_id, p_listing_id, v_inventory.id, v_now);
    RETURN QUERY SELECT p_listing_id, 'standard'::text, v_result_status,
      v_available, v_result_version; RETURN;
  END IF;
  IF p_quantity <> 1 THEN RAISE EXCEPTION 'secondhand_quantity_must_be_one'; END IF;
  SELECT su.* INTO v_unit FROM public.secondhand_units AS su
    WHERE su.listing_id = p_listing_id FOR UPDATE;
  IF v_unit.id IS NULL THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.unit_id', v_unit.id::text, true);
  IF v_unit.version <> p_expected_version THEN
    RAISE EXCEPTION 'inventory_version_conflict'; END IF;
  IF p_action = 'reserve' AND v_unit.status = 'available' THEN
    v_result_status := 'reserved'; v_event_code := 'secondhand.reserved';
  ELSIF p_action = 'release' AND v_unit.status = 'reserved' THEN
    v_result_status := 'available'; v_event_code := 'secondhand.released';
  ELSIF p_action = 'sell' AND v_unit.status = 'reserved' THEN
    v_result_status := 'sold'; v_event_code := 'secondhand.sold';
  ELSE RAISE EXCEPTION 'secondhand_state_conflict'; END IF;
  UPDATE public.secondhand_units SET status = v_result_status,
    version = version + 1, updated_at = v_now WHERE id = v_unit.id;
  v_result_version := v_unit.version + 1;
  v_available := CASE WHEN v_result_status = 'available' THEN 1 ELSE 0 END;
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
  INSERT INTO public.inventory_events (id, actor_user_id, organization_id,
    organization_type, store_id, listing_id, secondhand_unit_id, event_code,
    quantity_delta, reserved_delta, from_version, to_version,
    idempotency_key, request_fingerprint, created_at)
  VALUES (v_event_id, v_uid, v_listing.organization_id, 'merchant',
    v_listing.store_id, p_listing_id, v_unit.id, v_event_code, 0,
    CASE WHEN p_action = 'reserve' THEN 1 ELSE -1 END,
    v_unit.version, v_result_version, p_idempotency_key, v_fingerprint, v_now);
  INSERT INTO public.p4_idempotency_keys (actor_user_id, idempotency_key,
    operation_code, target_id, request_fingerprint, result_status,
    result_version, result_available, organization_id, listing_id,
    secondhand_unit_id, created_at)
  VALUES (v_uid, p_idempotency_key,
    CASE p_action WHEN 'reserve' THEN 'inventory.reserve'
      WHEN 'release' THEN 'inventory.release' ELSE 'inventory.sell' END,
    p_listing_id, v_fingerprint, v_result_status, v_result_version,
    v_available,
    v_listing.organization_id, p_listing_id, v_unit.id, v_now);
  RETURN QUERY SELECT p_listing_id, 'secondhand'::text, v_result_status,
    v_available, v_result_version;
END
$function$;

CREATE OR REPLACE FUNCTION private.get_assigned_wholesale_application_impl(
  p_application_id uuid
)
RETURNS TABLE (
  application_id uuid, applicant_user_id uuid, company_name text,
  country_code text, application_status text, registration_reference text,
  evidence_reference text, submitted_at timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_uid uuid; v_application public.wholesale_applications%ROWTYPE;
BEGIN
  PERFORM private.rebuy_p4_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(false) AS i;
  IF p_application_id IS NULL THEN RAISE EXCEPTION 'wholesale_application_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'wholesale_review_detail', true);
  PERFORM pg_catalog.set_config('rebuy.p4.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.application_id', p_application_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  SELECT a.* INTO v_application FROM public.wholesale_applications AS a
    WHERE a.id = p_application_id;
  IF v_application.id IS NULL OR v_application.assigned_reviewer_membership_id IS NULL
     OR v_uid = v_application.applicant_user_id
     OR NOT private.rebuy_business_membership_has_permission(
       v_application.assigned_reviewer_membership_id, v_uid,
       'wholesale_application.read_assigned')
     OR NOT private.rebuy_business_membership_has_permission(
       v_application.assigned_reviewer_membership_id, v_uid,
       'wholesale_application.review')
  THEN RAISE EXCEPTION 'wholesale_application_not_available'; END IF;
  RETURN QUERY SELECT a.id, a.applicant_user_id, a.company_name, a.country_code,
    a.status, ap.registration_reference, ap.evidence_reference,
    a.submitted_at, a.updated_at
  FROM public.wholesale_applications AS a
  JOIN public.wholesale_application_private AS ap ON ap.application_id = a.id
  WHERE a.id = p_application_id;
END
$function$;

CREATE OR REPLACE FUNCTION public.save_wholesale_application(
  p_company_name text, p_country_code text, p_registration_reference text,
  p_evidence_reference text, p_submit boolean, p_idempotency_key uuid
)
RETURNS TABLE (application_id uuid, application_status text)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.save_wholesale_application_impl(p_company_name,
    p_country_code, p_registration_reference, p_evidence_reference,
    p_submit, p_idempotency_key)
$function$;

CREATE OR REPLACE FUNCTION public.get_my_wholesale_application()
RETURNS TABLE (
  application_id uuid, company_name text, country_code text,
  application_status text, registration_reference text,
  evidence_reference text, organization_id uuid,
  qualification_id uuid, qualification_status text,
  valid_until timestamptz, updated_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_my_wholesale_application_impl() $function$;

CREATE OR REPLACE FUNCTION public.list_wholesale_review_queue()
RETURNS TABLE (
  application_id uuid, company_name text, country_code text,
  application_status text, assigned_reviewer_membership_id uuid,
  submitted_at timestamptz, updated_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.list_wholesale_review_queue_impl() $function$;

CREATE OR REPLACE FUNCTION public.get_assigned_wholesale_application(p_application_id uuid)
RETURNS TABLE (
  application_id uuid, applicant_user_id uuid, company_name text,
  country_code text, application_status text, registration_reference text,
  evidence_reference text, submitted_at timestamptz, updated_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.get_assigned_wholesale_application_impl(p_application_id)
$function$;

CREATE OR REPLACE FUNCTION public.assign_wholesale_application(
  p_application_id uuid, p_reviewer_membership_id uuid, p_idempotency_key uuid
)
RETURNS TABLE (application_id uuid, application_status text, reviewer_membership_id uuid)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.assign_wholesale_application_impl(p_application_id,
    p_reviewer_membership_id, p_idempotency_key)
$function$;

CREATE OR REPLACE FUNCTION public.review_wholesale_application(
  p_application_id uuid, p_action text, p_reason_code text,
  p_valid_until timestamptz, p_idempotency_key uuid
)
RETURNS TABLE (
  application_id uuid, application_status text, organization_id uuid,
  owner_membership_id uuid, qualification_id uuid
)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.review_wholesale_application_impl(p_application_id,
    p_action, p_reason_code, p_valid_until, p_idempotency_key)
$function$;

CREATE OR REPLACE FUNCTION public.change_wholesale_qualification(
  p_qualification_id uuid, p_action text, p_idempotency_key uuid
)
RETURNS TABLE (qualification_id uuid, qualification_status text, qualification_version integer)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.change_wholesale_qualification_impl(p_qualification_id,
    p_action, p_idempotency_key)
$function$;

CREATE OR REPLACE FUNCTION public.withdraw_wholesale_application(
  p_application_id uuid, p_idempotency_key uuid
)
RETURNS TABLE (application_id uuid, application_status text)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.withdraw_wholesale_application_impl(p_application_id,
    p_idempotency_key)
$function$;

CREATE OR REPLACE FUNCTION public.upsert_catalog_listing(
  p_listing_id uuid, p_store_id uuid, p_category_slug text,
  p_product_kind text, p_internal_name text, p_sku text,
  p_listing_slug text, p_title text, p_summary text,
  p_retail_cents integer, p_wholesale_cents integer,
  p_wholesale_minimum integer, p_wholesale_tiers jsonb,
  p_initial_stock integer, p_synthetic_serial_reference text,
  p_condition_code text, p_defect_code text,
  p_battery_health_percent integer, p_warranty_days integer,
  p_publish boolean, p_expected_version integer, p_idempotency_key uuid
)
RETURNS TABLE (
  listing_id uuid, product_id uuid, variant_id uuid,
  listing_status text, listing_version integer
)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.upsert_catalog_listing_impl(p_listing_id, p_store_id,
    p_category_slug, p_product_kind, p_internal_name, p_sku,
    p_listing_slug, p_title, p_summary, p_retail_cents,
    p_wholesale_cents, p_wholesale_minimum, p_wholesale_tiers,
    p_initial_stock, p_synthetic_serial_reference, p_condition_code,
    p_defect_code, p_battery_health_percent, p_warranty_days,
    p_publish, p_expected_version, p_idempotency_key)
$function$;

CREATE OR REPLACE FUNCTION public.get_catalog_quote(
  p_listing_id uuid, p_quantity integer
)
RETURNS TABLE (
  listing_id uuid, audience text, currency_code text,
  unit_amount_cents integer, minimum_quantity integer,
  available_quantity integer, price_version integer,
  listing_version integer, purchasable boolean
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_catalog_quote_impl(p_listing_id, p_quantity) $function$;

CREATE OR REPLACE FUNCTION public.list_public_catalog()
RETURNS TABLE (
  listing_id uuid, store_id uuid, store_name text, category_slug text,
  product_kind text, listing_slug text, title text, summary text,
  retail_cents integer, currency_code text, available_quantity integer,
  listing_version integer
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.list_public_catalog_impl() $function$;

CREATE OR REPLACE FUNCTION public.adjust_inventory(
  p_listing_id uuid, p_quantity_delta integer,
  p_expected_version integer, p_idempotency_key uuid
)
RETURNS TABLE (
  listing_id uuid, on_hand integer, reserved integer,
  available integer, inventory_version integer
)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.adjust_inventory_impl(p_listing_id, p_quantity_delta,
    p_expected_version, p_idempotency_key)
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION private.save_wholesale_application_impl(
  text, text, text, text, boolean, uuid
) FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.get_my_wholesale_application_impl()
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.list_wholesale_review_queue_impl()
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.get_assigned_wholesale_application_impl(uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.assign_wholesale_application_impl(uuid, uuid, uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.review_wholesale_application_impl(
  uuid, text, text, timestamptz, uuid
) FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.change_wholesale_qualification_impl(uuid, text, uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.withdraw_wholesale_application_impl(uuid, uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.upsert_catalog_listing_impl(
  uuid, uuid, text, text, text, text, text, text, text, integer, integer,
  integer, jsonb, integer, text, text, text, integer, integer, boolean,
  integer, uuid
) FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.get_catalog_quote_impl(uuid, integer)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.list_public_catalog_impl()
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.adjust_inventory_impl(uuid, integer, integer, uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
REVOKE ALL PRIVILEGES ON FUNCTION private.change_inventory_reservation_impl(
  uuid, integer, text, integer, text, uuid
) FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;

GRANT USAGE ON SCHEMA private TO anon, authenticated;
GRANT EXECUTE ON FUNCTION private.save_wholesale_application_impl(
  text, text, text, text, boolean, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION private.get_my_wholesale_application_impl() TO authenticated;
GRANT EXECUTE ON FUNCTION private.list_wholesale_review_queue_impl() TO authenticated;
GRANT EXECUTE ON FUNCTION private.get_assigned_wholesale_application_impl(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION private.assign_wholesale_application_impl(uuid, uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION private.review_wholesale_application_impl(
  uuid, text, text, timestamptz, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION private.change_wholesale_qualification_impl(uuid, text, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION private.withdraw_wholesale_application_impl(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION private.upsert_catalog_listing_impl(
  uuid, uuid, text, text, text, text, text, text, text, integer, integer,
  integer, jsonb, integer, text, text, text, integer, integer, boolean,
  integer, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION private.get_catalog_quote_impl(uuid, integer)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION private.list_public_catalog_impl() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION private.adjust_inventory_impl(uuid, integer, integer, uuid)
  TO authenticated;
DO $owner_handoff$
BEGIN
  IF pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR pg_catalog.has_schema_privilege('rebuy_business_executor', 'private', 'CREATE')
  THEN RAISE EXCEPTION 'rebuy_p4_owner_handoff_precondition_invalid'; END IF;
  EXECUTE 'GRANT rebuy_business_executor TO postgres WITH INHERIT FALSE GRANTED BY CURRENT_USER';
  EXECUTE 'GRANT CREATE ON SCHEMA private TO rebuy_business_executor GRANTED BY CURRENT_USER';
  IF NOT pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR NOT pg_catalog.has_schema_privilege('rebuy_business_executor', 'private', 'CREATE')
  THEN RAISE EXCEPTION 'rebuy_p4_owner_handoff_capability_invalid'; END IF;
  EXECUTE 'ALTER FUNCTION private.save_wholesale_application_impl(text, text, text, text, boolean, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.get_my_wholesale_application_impl() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.list_wholesale_review_queue_impl() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.get_assigned_wholesale_application_impl(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.assign_wholesale_application_impl(uuid, uuid, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.review_wholesale_application_impl(uuid, text, text, timestamptz, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.change_wholesale_qualification_impl(uuid, text, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.withdraw_wholesale_application_impl(uuid, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.upsert_catalog_listing_impl(uuid, uuid, text, text, text, text, text, text, text, integer, integer, integer, jsonb, integer, text, text, text, integer, integer, boolean, integer, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.get_catalog_quote_impl(uuid, integer) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.list_public_catalog_impl() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.adjust_inventory_impl(uuid, integer, integer, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.change_inventory_reservation_impl(uuid, integer, text, integer, text, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'REVOKE rebuy_business_executor FROM postgres GRANTED BY CURRENT_USER';
  EXECUTE 'REVOKE CREATE ON SCHEMA private FROM rebuy_business_executor GRANTED BY CURRENT_USER';
  IF pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
     OR pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR pg_catalog.has_schema_privilege('rebuy_business_executor', 'private', 'CREATE')
  THEN RAISE EXCEPTION 'rebuy_p4_owner_handoff_cleanup_invalid'; END IF;
END
$owner_handoff$;

REVOKE ALL PRIVILEGES ON FUNCTION public.save_wholesale_application(
  text, text, text, text, boolean, uuid
) FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.get_my_wholesale_application()
  FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.list_wholesale_review_queue()
  FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.get_assigned_wholesale_application(uuid)
  FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.assign_wholesale_application(uuid, uuid, uuid)
  FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.review_wholesale_application(
  uuid, text, text, timestamptz, uuid
) FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.change_wholesale_qualification(uuid, text, uuid)
  FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.withdraw_wholesale_application(uuid, uuid)
  FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.upsert_catalog_listing(
  uuid, uuid, text, text, text, text, text, text, text, integer, integer,
  integer, jsonb, integer, text, text, text, integer, integer, boolean,
  integer, uuid
) FROM PUBLIC, anon, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.get_catalog_quote(uuid, integer)
  FROM PUBLIC, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.list_public_catalog()
  FROM PUBLIC, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.adjust_inventory(uuid, integer, integer, uuid)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.save_wholesale_application(
  text, text, text, text, boolean, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_wholesale_application() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_wholesale_review_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_assigned_wholesale_application(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_wholesale_application(uuid, uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_wholesale_application(
  uuid, text, text, timestamptz, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.change_wholesale_qualification(uuid, text, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.withdraw_wholesale_application(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_catalog_listing(
  uuid, uuid, text, text, text, text, text, text, text, integer, integer,
  integer, jsonb, integer, text, text, text, integer, integer, boolean,
  integer, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_catalog_quote(uuid, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_public_catalog() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.adjust_inventory(uuid, integer, integer, uuid)
  TO authenticated;
REVOKE EXECUTE ON FUNCTION private.rebuy_p4_reset_context() FROM service_role;
REVOKE EXECUTE ON FUNCTION private.rebuy_p4_find_merchant_membership(
  uuid, uuid, uuid, text
) FROM service_role;
REVOKE EXECUTE ON FUNCTION private.rebuy_p4_active_wholesale_qualification(uuid)
  FROM service_role;
