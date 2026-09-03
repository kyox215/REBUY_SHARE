-- P5 synthetic-only public catalog search, persistent carts and buyer orders.

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

-- P4 quotes and inventory mutations share a hard upper quantity bound of one
-- million. Close the older wholesale-rule gap here so every active MOQ remains
-- representable by the P5 cart and checkout contract.
ALTER TABLE public.listing_prices
  ADD CONSTRAINT listing_prices_minimum_upper_check
  CHECK (minimum_quantity <= 1000000);
ALTER TABLE public.listing_price_tiers
  ADD CONSTRAINT listing_price_tiers_quantity_upper_check
  CHECK (minimum_quantity <= 1000000);

CREATE TABLE public.carts (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active',
  version integer NOT NULL DEFAULT 1,
  checkout_batch_id uuid,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT carts_status_check CHECK (status IN ('active', 'checked_out', 'abandoned')),
  CONSTRAINT carts_version_check CHECK (version > 0),
  CONSTRAINT carts_checkout_state_check CHECK (
    (status = 'checked_out' AND checkout_batch_id IS NOT NULL)
    OR (status <> 'checked_out' AND checkout_batch_id IS NULL)
  ),
  CONSTRAINT carts_id_owner_key UNIQUE (id, owner_user_id)
);
CREATE UNIQUE INDEX carts_one_active_per_owner
  ON public.carts (owner_user_id) WHERE status = 'active';
CREATE INDEX carts_owner_status_idx ON public.carts (owner_user_id, status, updated_at DESC);
CREATE INDEX carts_checkout_batch_idx
  ON public.carts (checkout_batch_id, owner_user_id);

CREATE TABLE public.cart_items (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  cart_id uuid NOT NULL,
  owner_user_id uuid NOT NULL,
  listing_id uuid NOT NULL REFERENCES public.listings (id),
  quantity integer NOT NULL,
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT cart_items_cart_fk FOREIGN KEY (cart_id, owner_user_id)
    REFERENCES public.carts (id, owner_user_id) ON DELETE CASCADE,
  CONSTRAINT cart_items_quantity_check CHECK (quantity BETWEEN 1 AND 1000000),
  CONSTRAINT cart_items_version_check CHECK (version > 0),
  CONSTRAINT cart_items_cart_listing_key UNIQUE (cart_id, listing_id),
  CONSTRAINT cart_items_id_cart_key UNIQUE (id, cart_id)
);
CREATE INDEX cart_items_owner_cart_idx ON public.cart_items (owner_user_id, cart_id);
CREATE INDEX cart_items_cart_owner_idx ON public.cart_items (cart_id, owner_user_id);
CREATE INDEX cart_items_listing_idx ON public.cart_items (listing_id);

CREATE TABLE public.order_batches (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  buyer_user_id uuid NOT NULL REFERENCES auth.users (id),
  source_cart_id uuid NOT NULL,
  source_cart_version integer NOT NULL,
  synthetic_order_reference text NOT NULL UNIQUE,
  synthetic_delivery_reference text NOT NULL,
  currency_code text NOT NULL DEFAULT 'EUR',
  subtotal_cents integer NOT NULL,
  shipping_cents integer NOT NULL DEFAULT 0,
  tax_cents integer NOT NULL DEFAULT 0,
  discount_cents integer NOT NULL DEFAULT 0,
  total_cents integer NOT NULL,
  status text NOT NULL DEFAULT 'confirmed',
  inventory_status text NOT NULL DEFAULT 'reserved',
  payment_status text NOT NULL DEFAULT 'not_required',
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  cancelled_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT order_batches_cart_fk FOREIGN KEY (source_cart_id, buyer_user_id)
    REFERENCES public.carts (id, owner_user_id),
  CONSTRAINT order_batches_source_version_check CHECK (source_cart_version > 0),
  CONSTRAINT order_batches_order_ref_check CHECK (
    synthetic_order_reference ~ '^SYN-ORDER-[A-Z0-9-]{4,40}$'
  ),
  CONSTRAINT order_batches_delivery_ref_check CHECK (
    synthetic_delivery_reference ~ '^synthetic://delivery/[a-z0-9][a-z0-9/_-]{2,120}$'
  ),
  CONSTRAINT order_batches_currency_check CHECK (currency_code = 'EUR'),
  CONSTRAINT order_batches_amount_check CHECK (
    subtotal_cents > 0 AND shipping_cents = 0 AND tax_cents = 0
    AND discount_cents = 0 AND total_cents = subtotal_cents
  ),
  CONSTRAINT order_batches_status_check CHECK (status IN ('confirmed', 'cancelled')),
  CONSTRAINT order_batches_inventory_check CHECK (inventory_status IN ('reserved', 'released')),
  CONSTRAINT order_batches_payment_check CHECK (payment_status = 'not_required'),
  CONSTRAINT order_batches_state_check CHECK (
    (status = 'confirmed' AND inventory_status = 'reserved' AND cancelled_at IS NULL)
    OR (status = 'cancelled' AND inventory_status = 'released' AND cancelled_at IS NOT NULL)
  ),
  CONSTRAINT order_batches_version_check CHECK (version > 0),
  CONSTRAINT order_batches_id_buyer_key UNIQUE (id, buyer_user_id)
);
CREATE INDEX order_batches_buyer_created_idx
  ON public.order_batches (buyer_user_id, created_at DESC, id);
CREATE INDEX order_batches_cart_idx ON public.order_batches (source_cart_id, buyer_user_id);

ALTER TABLE public.carts
  ADD CONSTRAINT carts_checkout_batch_fk FOREIGN KEY (checkout_batch_id, owner_user_id)
  REFERENCES public.order_batches (id, buyer_user_id);

CREATE TABLE public.merchant_orders (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  batch_id uuid NOT NULL,
  buyer_user_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  store_id uuid NOT NULL,
  currency_code text NOT NULL DEFAULT 'EUR',
  subtotal_cents integer NOT NULL,
  total_cents integer NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  inventory_status text NOT NULL DEFAULT 'reserved',
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT merchant_orders_batch_fk FOREIGN KEY (batch_id, buyer_user_id)
    REFERENCES public.order_batches (id, buyer_user_id),
  CONSTRAINT merchant_orders_store_fk FOREIGN KEY (
    store_id, organization_id, organization_type
  ) REFERENCES public.stores (id, organization_id, organization_type),
  CONSTRAINT merchant_orders_type_check CHECK (organization_type = 'merchant'),
  CONSTRAINT merchant_orders_currency_check CHECK (currency_code = 'EUR'),
  CONSTRAINT merchant_orders_amount_check CHECK (
    subtotal_cents > 0 AND total_cents = subtotal_cents
  ),
  CONSTRAINT merchant_orders_status_check CHECK (status IN ('pending', 'cancelled')),
  CONSTRAINT merchant_orders_inventory_check CHECK (inventory_status IN ('reserved', 'released')),
  CONSTRAINT merchant_orders_state_check CHECK (
    (status = 'pending' AND inventory_status = 'reserved')
    OR (status = 'cancelled' AND inventory_status = 'released')
  ),
  CONSTRAINT merchant_orders_version_check CHECK (version > 0),
  CONSTRAINT merchant_orders_batch_store_key UNIQUE (batch_id, store_id),
  CONSTRAINT merchant_orders_id_batch_key UNIQUE (id, batch_id)
);
CREATE INDEX merchant_orders_buyer_batch_idx ON public.merchant_orders (buyer_user_id, batch_id);
CREATE INDEX merchant_orders_batch_buyer_idx ON public.merchant_orders (batch_id, buyer_user_id);
CREATE INDEX merchant_orders_org_store_status_idx
  ON public.merchant_orders (organization_id, store_id, status, created_at DESC);
CREATE INDEX merchant_orders_store_org_idx
  ON public.merchant_orders (store_id, organization_id, organization_type);

CREATE TABLE public.order_items (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  batch_id uuid NOT NULL,
  merchant_order_id uuid NOT NULL,
  buyer_user_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  store_id uuid NOT NULL,
  listing_id uuid NOT NULL REFERENCES public.listings (id),
  product_id uuid NOT NULL REFERENCES public.products (id),
  variant_id uuid NOT NULL REFERENCES public.product_variants (id),
  product_kind text NOT NULL,
  quantity integer NOT NULL,
  audience text NOT NULL,
  currency_code text NOT NULL DEFAULT 'EUR',
  unit_amount_cents integer NOT NULL,
  line_amount_cents integer NOT NULL,
  price_version integer NOT NULL,
  listing_version integer NOT NULL,
  inventory_version integer NOT NULL,
  inventory_status text NOT NULL DEFAULT 'reserved',
  title_snapshot text NOT NULL,
  sku_snapshot text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT order_items_batch_fk FOREIGN KEY (batch_id, buyer_user_id)
    REFERENCES public.order_batches (id, buyer_user_id),
  CONSTRAINT order_items_merchant_order_fk FOREIGN KEY (merchant_order_id, batch_id)
    REFERENCES public.merchant_orders (id, batch_id),
  CONSTRAINT order_items_kind_check CHECK (product_kind IN ('standard', 'secondhand')),
  CONSTRAINT order_items_quantity_check CHECK (
    quantity BETWEEN 1 AND 1000000 AND (product_kind = 'standard' OR quantity = 1)
  ),
  CONSTRAINT order_items_audience_check CHECK (audience IN ('retail', 'wholesale')),
  CONSTRAINT order_items_currency_check CHECK (currency_code = 'EUR'),
  CONSTRAINT order_items_amount_check CHECK (
    unit_amount_cents > 0 AND line_amount_cents = unit_amount_cents * quantity
  ),
  CONSTRAINT order_items_versions_check CHECK (
    price_version > 0 AND listing_version > 0 AND inventory_version > 0
  ),
  CONSTRAINT order_items_inventory_check CHECK (inventory_status IN ('reserved', 'released')),
  CONSTRAINT order_items_snapshot_check CHECK (
    title_snapshot = pg_catalog.btrim(title_snapshot)
    AND pg_catalog.char_length(title_snapshot) BETWEEN 2 AND 120
    AND sku_snapshot ~ '^SYN-SKU-[A-Z0-9-]{2,40}$'
  ),
  CONSTRAINT order_items_batch_listing_key UNIQUE (batch_id, listing_id)
);
CREATE INDEX order_items_buyer_batch_idx ON public.order_items (buyer_user_id, batch_id);
CREATE INDEX order_items_batch_buyer_idx ON public.order_items (batch_id, buyer_user_id);
CREATE INDEX order_items_merchant_order_idx
  ON public.order_items (merchant_order_id, batch_id, id);
CREATE INDEX order_items_listing_idx ON public.order_items (listing_id);
CREATE INDEX order_items_product_idx ON public.order_items (product_id);
CREATE INDEX order_items_variant_idx ON public.order_items (variant_id);

CREATE TABLE public.order_events (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  batch_id uuid NOT NULL,
  merchant_order_id uuid,
  buyer_user_id uuid NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users (id),
  event_code text NOT NULL,
  reason_code text NOT NULL,
  from_status text,
  to_status text NOT NULL,
  from_version integer,
  to_version integer NOT NULL,
  idempotency_key uuid NOT NULL,
  request_fingerprint text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT order_events_batch_fk FOREIGN KEY (batch_id, buyer_user_id)
    REFERENCES public.order_batches (id, buyer_user_id),
  CONSTRAINT order_events_merchant_fk FOREIGN KEY (merchant_order_id, batch_id)
    REFERENCES public.merchant_orders (id, batch_id),
  CONSTRAINT order_events_code_check CHECK (
    event_code IN ('order.confirmed', 'order.cancelled')
  ),
  CONSTRAINT order_events_reason_check CHECK (
    reason_code IN ('buyer_checkout', 'buyer_cancelled_before_fulfillment')
  ),
  CONSTRAINT order_events_status_check CHECK (
    (event_code = 'order.confirmed' AND from_status IS NULL AND to_status = 'confirmed')
    OR (event_code = 'order.cancelled' AND from_status = 'confirmed' AND to_status = 'cancelled')
  ),
  CONSTRAINT order_events_version_check CHECK (
    (from_version IS NULL AND to_version = 1)
    OR (from_version IS NOT NULL AND from_version > 0 AND to_version = from_version + 1)
  ),
  CONSTRAINT order_events_fingerprint_check CHECK (request_fingerprint ~ '^[0-9a-f]{32}$')
);
CREATE INDEX order_events_buyer_batch_idx ON public.order_events (buyer_user_id, batch_id, created_at, id);
CREATE INDEX order_events_batch_buyer_idx ON public.order_events (batch_id, buyer_user_id);
CREATE INDEX order_events_merchant_batch_idx
  ON public.order_events (merchant_order_id, batch_id);
CREATE INDEX order_events_actor_idx ON public.order_events (actor_user_id, created_at DESC);
CREATE UNIQUE INDEX order_events_operation_key
  ON public.order_events (actor_user_id, idempotency_key, event_code);

CREATE TABLE public.p5_idempotency_keys (
  actor_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  idempotency_key uuid NOT NULL,
  operation_code text NOT NULL,
  request_fingerprint text NOT NULL,
  cart_id uuid,
  cart_item_id uuid,
  listing_id uuid,
  batch_id uuid,
  result_status text NOT NULL,
  result_version integer NOT NULL,
  result_item_version integer,
  result_quantity integer,
  result_reference text,
  result_inventory_status text,
  result_currency_code text,
  result_total_cents integer,
  result_cancelled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  PRIMARY KEY (actor_user_id, idempotency_key),
  CONSTRAINT p5_idempotency_operation_check CHECK (
    operation_code IN ('cart.put', 'cart.remove', 'order.checkout', 'order.cancel')
  ),
  CONSTRAINT p5_idempotency_fingerprint_check CHECK (request_fingerprint ~ '^[0-9a-f]{32}$'),
  CONSTRAINT p5_idempotency_status_check CHECK (
    result_status IN ('active', 'removed', 'confirmed', 'cancelled')
  ),
  CONSTRAINT p5_idempotency_version_check CHECK (result_version > 0),
  CONSTRAINT p5_idempotency_item_version_check CHECK (
    result_item_version IS NULL OR result_item_version > 0
  ),
  CONSTRAINT p5_idempotency_quantity_check CHECK (
    result_quantity IS NULL OR result_quantity BETWEEN 1 AND 1000000
  ),
  CONSTRAINT p5_idempotency_reference_check CHECK (
    result_reference IS NULL OR result_reference ~ '^SYN-ORDER-[A-Z0-9-]{4,40}$'
  ),
  CONSTRAINT p5_idempotency_inventory_status_check CHECK (
    result_inventory_status IS NULL OR result_inventory_status IN ('reserved', 'released')
  ),
  CONSTRAINT p5_idempotency_currency_check CHECK (
    result_currency_code IS NULL OR result_currency_code = 'EUR'
  ),
  CONSTRAINT p5_idempotency_total_check CHECK (
    result_total_cents IS NULL OR result_total_cents > 0
  )
);
CREATE INDEX p5_idempotency_cart_idx ON public.p5_idempotency_keys (cart_id);
CREATE INDEX p5_idempotency_item_idx ON public.p5_idempotency_keys (cart_item_id);
CREATE INDEX p5_idempotency_listing_idx ON public.p5_idempotency_keys (listing_id);
CREATE INDEX p5_idempotency_batch_idx ON public.p5_idempotency_keys (batch_id);

ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.order_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_batches FORCE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_orders FORCE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.order_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_events FORCE ROW LEVEL SECURITY;
ALTER TABLE public.p5_idempotency_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.p5_idempotency_keys FORCE ROW LEVEL SECURITY;

-- PostgreSQL row-locking clauses require UPDATE privilege even when the caller
-- only takes a SHARE lock. No UPDATE policy exists on role_definitions, so this
-- narrow column grant enables the pricing-context lock without making a role
-- definition mutable through the executor.
GRANT UPDATE (status) ON TABLE public.role_definitions
  TO rebuy_business_executor;

-- Extend the existing UPDATE policies only far enough for SELECT ... FOR SHARE
-- during checkout. The WITH CHECK branches remain limited to the pre-existing
-- business mutations, so the P5 lock path cannot change these control rows.
DROP POLICY memberships_business_update_owner ON public.memberships;
CREATE POLICY memberships_business_update_owner
  ON public.memberships FOR UPDATE TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
      AND id::text = (SELECT pg_catalog.current_setting(
        'rebuy.business.owner_membership_id', true))
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_checkout'
      AND user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p5.actor_user_id', true))
    )
  )
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (SELECT pg_catalog.current_setting(
      'rebuy.business.owner_membership_id', true))
    AND status = 'suspended'
  );

DROP POLICY organizations_business_update_merchant ON public.organizations;
CREATE POLICY organizations_business_update_merchant
  ON public.organizations FOR UPDATE TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
      AND id::text = (SELECT pg_catalog.current_setting(
        'rebuy.business.organization_id', true))
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_checkout'
      AND id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p4.organization_id', true))
      AND organization_type = 'wholesale'
    )
  )
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (SELECT pg_catalog.current_setting(
      'rebuy.business.organization_id', true))
    AND status = 'suspended'
  );

DROP POLICY membership_store_scopes_business_update_owner
  ON public.membership_store_scopes;
CREATE POLICY membership_store_scopes_business_update_owner
  ON public.membership_store_scopes FOR UPDATE TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
      AND membership_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.business.owner_membership_id', true))
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_checkout'
      AND membership_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p4.membership_id', true))
    )
  )
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND membership_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.business.owner_membership_id', true))
    AND status = 'suspended'
  );

CREATE POLICY role_definitions_p5_pricing_lock
  ON public.role_definitions FOR UPDATE TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_checkout'
    AND role_key = 'owner' AND scope_type = 'organization'
    AND status = 'active' AND is_system
    AND applicable_organization_type IN ('any', 'wholesale')
  )
  WITH CHECK (false);

CREATE OR REPLACE FUNCTION private.rebuy_p5_clear_context()
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $function$
BEGIN
  PERFORM pg_catalog.set_config('rebuy.p5.authorized', 'false', true);
  PERFORM pg_catalog.set_config('rebuy.p5.op', '', true);
  PERFORM pg_catalog.set_config('rebuy.p5.actor_user_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p5.cart_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p5.cart_item_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p5.listing_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p5.batch_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p5.merchant_order_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p5.event_id', '', true);
END
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_p5_reset_context()
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $function$
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
  PERFORM private.rebuy_p4_reset_context();
  PERFORM private.rebuy_p5_clear_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_p5_derived_uuid(
  p_namespace uuid,
  p_value text
)
RETURNS uuid
LANGUAGE sql
IMMUTABLE
STRICT
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT (
    pg_catalog.substr(v.hash, 1, 8) || '-' ||
    pg_catalog.substr(v.hash, 9, 4) || '-' ||
    pg_catalog.substr(v.hash, 13, 4) || '-' ||
    pg_catalog.substr(v.hash, 17, 4) || '-' ||
    pg_catalog.substr(v.hash, 21, 12)
  )::uuid
  FROM (SELECT pg_catalog.md5(p_namespace::text || ':' || p_value) AS hash) AS v
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_p5_lock_pricing_context(p_user_id uuid)
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
  IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM private.rebuy_request_uid()
  THEN RAISE EXCEPTION 'pricing_context_invalid'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
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
    FOR SHARE OF m, rd
  LOOP
    PERFORM pg_catalog.set_config('rebuy.p4.organization_id',
      v_membership.organization_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.membership_id',
      v_membership.id::text, true);
    PERFORM 1 FROM public.organizations AS o
      WHERE o.id = v_membership.organization_id
        AND o.organization_type = 'wholesale' AND o.status = 'active'
      FOR SHARE;
    IF NOT FOUND THEN CONTINUE; END IF;
    PERFORM 1 FROM public.membership_store_scopes AS s
      WHERE s.membership_id = v_membership.id
        AND s.organization_id = v_membership.organization_id
        AND s.organization_type = 'wholesale'
        AND s.scope_type = 'organization'
        AND s.store_id IS NULL AND s.status = 'active'
      FOR SHARE;
    IF NOT FOUND THEN CONTINUE; END IF;
    SELECT q.id INTO v_qualification_id
    FROM public.wholesale_qualifications AS q
    WHERE q.organization_id = v_membership.organization_id
      AND q.status = 'active'
      AND q.valid_from <= pg_catalog.statement_timestamp()
      AND q.valid_until > pg_catalog.statement_timestamp()
    ORDER BY q.id LIMIT 1;
    IF v_qualification_id IS NULL THEN CONTINUE; END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_qualification_id::text, 0));
    PERFORM pg_catalog.set_config('rebuy.p4.qualification_id',
      v_qualification_id::text, true);
    PERFORM 1 FROM public.wholesale_qualifications AS q
      WHERE q.id = v_qualification_id
        AND q.organization_id = v_membership.organization_id
        AND q.status = 'active'
        AND q.valid_from <= pg_catalog.statement_timestamp()
        AND q.valid_until > pg_catalog.statement_timestamp()
      FOR SHARE;
    IF FOUND THEN RETURN v_qualification_id; END IF;
    v_qualification_id := NULL;
  END LOOP;
  RETURN NULL;
END
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION private.rebuy_p5_clear_context(),
  private.rebuy_p5_reset_context(),
  private.rebuy_p5_derived_uuid(uuid, text),
  private.rebuy_p5_lock_pricing_context(uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_p5_clear_context(),
  private.rebuy_p5_reset_context(),
  private.rebuy_p5_derived_uuid(uuid, text),
  private.rebuy_p5_lock_pricing_context(uuid)
  TO rebuy_business_executor;

CREATE POLICY carts_p5_all
  ON public.carts FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND owner_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p5.cart_id', true))
      OR ((SELECT pg_catalog.current_setting('rebuy.p5.op', true)) IN (
          'cart_get', 'cart_put', 'cart_remove', 'order_checkout', 'order_list'
        ) AND status = 'active'))
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND owner_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p5.cart_id', true))
  );
CREATE POLICY cart_items_p5_all
  ON public.cart_items FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND owner_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND cart_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.cart_id', true))
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND owner_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND cart_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.cart_id', true))
  );
CREATE POLICY order_batches_p5_all
  ON public.order_batches FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND buyer_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_list')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND buyer_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
  );
CREATE POLICY merchant_orders_p5_all
  ON public.merchant_orders FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND buyer_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND (batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_list')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND buyer_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
  );
CREATE POLICY order_items_p5_all
  ON public.order_items FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND buyer_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND (batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_list')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND buyer_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
  );
CREATE POLICY order_events_p5_all
  ON public.order_events FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND buyer_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND (batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_list')
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND buyer_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
    AND actor_user_id = buyer_user_id
    AND batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p5.event_id', true))
  );
CREATE POLICY p5_idempotency_keys_p5_all
  ON public.p5_idempotency_keys FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND actor_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
    AND actor_user_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.actor_user_id', true))
  );

REVOKE ALL PRIVILEGES ON TABLE public.carts, public.cart_items,
  public.order_batches, public.merchant_orders, public.order_items,
  public.order_events, public.p5_idempotency_keys
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
GRANT SELECT, INSERT ON TABLE public.carts, public.order_batches,
  public.merchant_orders, public.order_items TO rebuy_business_executor;
GRANT UPDATE (status, checkout_batch_id, version, updated_at)
  ON TABLE public.carts TO rebuy_business_executor;
GRANT UPDATE (subtotal_cents, total_cents, status, inventory_status,
  version, cancelled_at, updated_at)
  ON TABLE public.order_batches TO rebuy_business_executor;
GRANT UPDATE (subtotal_cents, total_cents, status, inventory_status,
  version, updated_at)
  ON TABLE public.merchant_orders TO rebuy_business_executor;
GRANT UPDATE (inventory_status, inventory_version, updated_at)
  ON TABLE public.order_items TO rebuy_business_executor;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cart_items TO rebuy_business_executor;
GRANT SELECT, INSERT ON TABLE public.order_events, public.p5_idempotency_keys
  TO rebuy_business_executor;
GRANT EXECUTE ON FUNCTION private.rebuy_request_jwt(), private.rebuy_request_uid(),
  private.rebuy_business_require_identity(boolean), private.rebuy_p4_reset_context(),
  private.rebuy_p5_reset_context(), private.rebuy_p5_derived_uuid(uuid, text)
  TO rebuy_business_executor;

CREATE OR REPLACE FUNCTION private.search_catalog_impl(
  p_query text DEFAULT NULL,
  p_category_slug text DEFAULT NULL,
  p_limit integer DEFAULT 24,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  listing_id uuid, store_id uuid, store_name text, category_slug text,
  product_kind text, listing_slug text, title text, summary text,
  audience text, unit_amount_cents integer, minimum_quantity integer,
  currency_code text, available_quantity integer, price_version integer,
  listing_version integer, purchasable boolean
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_query text := pg_catalog.lower(pg_catalog.btrim(COALESCE(p_query, '')));
  v_category text := pg_catalog.lower(pg_catalog.btrim(COALESCE(p_category_slug, '')));
BEGIN
  PERFORM private.rebuy_p5_reset_context();
  IF pg_catalog.char_length(v_query) > 80
     OR pg_catalog.char_length(v_category) > 48
     OR (v_category <> '' AND v_category !~ '^[a-z0-9][a-z0-9-]{1,47}$')
     OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50
     OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 10000
  THEN RAISE EXCEPTION 'catalog_search_invalid'; END IF;
  RETURN QUERY
  SELECT c.listing_id, c.store_id, c.store_name, c.category_slug,
    c.product_kind, c.listing_slug, c.title, c.summary,
    q.audience, q.unit_amount_cents, q.minimum_quantity,
    q.currency_code, q.available_quantity, q.price_version,
    q.listing_version,
    (q.available_quantity >= q.minimum_quantity
      AND (c.product_kind = 'standard' OR q.minimum_quantity = 1))
  FROM private.list_public_catalog_impl() AS c
  CROSS JOIN LATERAL private.get_catalog_quote_impl(c.listing_id, 1) AS q
  WHERE (v_query = '' OR pg_catalog.lower(c.title || ' ' || c.summary || ' ' || c.store_name)
      LIKE '%' || v_query || '%')
    AND (v_category = '' OR c.category_slug = v_category)
  ORDER BY c.title, c.listing_id
  LIMIT p_limit OFFSET p_offset;
  PERFORM private.rebuy_p5_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.get_my_cart_impl()
RETURNS TABLE (
  cart_id uuid, cart_version integer, listing_id uuid, item_id uuid,
  quantity integer, item_version integer, store_id uuid, store_name text,
  product_kind text, title text, sku text, audience text,
  unit_amount_cents integer, minimum_quantity integer, currency_code text,
  available_quantity integer, price_version integer, listing_version integer,
  purchasable boolean, invalid_reason text
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_cart public.carts%ROWTYPE; v_item public.cart_items%ROWTYPE;
  v_store_id uuid; v_store_name text; v_kind text; v_title text; v_sku text;
  v_audience text; v_unit integer; v_minimum integer; v_currency text;
  v_available integer; v_price_version integer; v_listing_version integer;
  v_purchasable boolean; v_invalid text;
BEGIN
  PERFORM private.rebuy_p5_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(false) AS i;
  PERFORM pg_catalog.set_config('rebuy.p5.op', 'cart_get', true);
  PERFORM pg_catalog.set_config('rebuy.p5.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.authorized', 'true', true);
  SELECT c.* INTO v_cart FROM public.carts AS c
    WHERE c.owner_user_id = v_uid AND c.status = 'active';
  IF v_cart.id IS NULL THEN
  PERFORM private.rebuy_p5_reset_context();
    RETURN;
  END IF;
  PERFORM pg_catalog.set_config('rebuy.p5.cart_id', v_cart.id::text, true);
  IF NOT EXISTS (SELECT 1 FROM public.cart_items AS ci WHERE ci.cart_id = v_cart.id) THEN
    RETURN QUERY SELECT v_cart.id, v_cart.version, NULL::uuid, NULL::uuid,
      NULL::integer, NULL::integer, NULL::uuid, NULL::text, NULL::text,
      NULL::text, NULL::text, NULL::text, NULL::integer, NULL::integer,
      NULL::text, NULL::integer, NULL::integer, NULL::integer,
      false, NULL::text;
  PERFORM private.rebuy_p5_reset_context();
    RETURN;
  END IF;
  FOR v_item IN SELECT ci.* FROM public.cart_items AS ci
    WHERE ci.cart_id = v_cart.id ORDER BY ci.created_at, ci.id
  LOOP
    v_store_id := NULL; v_store_name := NULL; v_kind := NULL;
    v_title := NULL; v_sku := NULL; v_audience := NULL; v_unit := NULL;
    v_minimum := NULL; v_currency := NULL; v_available := NULL;
    v_price_version := NULL; v_listing_version := NULL;
    v_purchasable := false; v_invalid := NULL;
    BEGIN
      SELECT q.audience, q.unit_amount_cents, q.minimum_quantity,
        q.currency_code, q.available_quantity, q.price_version,
        q.listing_version, q.purchasable
      INTO v_audience, v_unit, v_minimum, v_currency, v_available,
        v_price_version, v_listing_version, v_purchasable
      FROM private.get_catalog_quote_impl(v_item.listing_id, v_item.quantity) AS q;
      SELECT l.store_id, s.display_name, l.product_kind, l.title, pv.sku
      INTO v_store_id, v_store_name, v_kind, v_title, v_sku
      FROM public.listings AS l
      JOIN public.stores AS s ON s.id = l.store_id
      JOIN public.product_variants AS pv ON pv.id = l.variant_id
      WHERE l.id = v_item.listing_id;
      IF NOT v_purchasable THEN v_invalid := 'cart_item_not_purchasable'; END IF;
    EXCEPTION WHEN others THEN
      v_invalid := CASE
        WHEN SQLERRM IN ('catalog_listing_not_available', 'catalog_price_not_available')
          THEN SQLERRM
        ELSE 'cart_item_not_available'
      END;
    END;
    RETURN QUERY SELECT v_cart.id, v_cart.version, v_item.listing_id,
      v_item.id, v_item.quantity, v_item.version, v_store_id, v_store_name,
      v_kind, v_title, v_sku, v_audience, v_unit, v_minimum, v_currency,
      v_available, v_price_version, v_listing_version,
      v_purchasable AND v_invalid IS NULL, v_invalid;
  END LOOP;
  PERFORM private.rebuy_p5_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.put_cart_item_impl(
  p_listing_id uuid,
  p_quantity integer,
  p_expected_cart_version integer,
  p_expected_item_version integer,
  p_idempotency_key uuid
)
RETURNS TABLE (
  cart_id uuid, cart_version integer, item_id uuid,
  item_version integer, quantity integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_cart public.carts%ROWTYPE; v_item public.cart_items%ROWTYPE;
  v_key public.p5_idempotency_keys%ROWTYPE; v_cart_id uuid; v_item_id uuid;
  v_cart_version integer; v_item_version integer; v_kind text;
  v_fingerprint text; v_purchasable boolean;
BEGIN
  PERFORM private.rebuy_p5_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_listing_id IS NULL OR p_quantity IS NULL OR p_quantity NOT BETWEEN 1 AND 1000000
     OR p_idempotency_key IS NULL
     OR (p_expected_cart_version IS NOT NULL AND p_expected_cart_version < 1)
     OR (p_expected_item_version IS NOT NULL AND p_expected_item_version < 1)
  THEN RAISE EXCEPTION 'cart_put_invalid'; END IF;
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|', p_listing_id::text,
    p_quantity::text, COALESCE(p_expected_cart_version::text, ''),
    COALESCE(p_expected_item_version::text, '')));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p5-idempotency', 0));
  PERFORM pg_catalog.set_config('rebuy.p5.op', 'cart_put', true);
  PERFORM pg_catalog.set_config('rebuy.p5.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.listing_id', p_listing_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.authorized', 'true', true);
  SELECT k.* INTO v_key FROM public.p5_idempotency_keys AS k
    WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'cart.put'
       OR v_key.listing_id IS DISTINCT FROM p_listing_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p5_idempotency_conflict'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p5.cart_id', v_key.cart_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
    PERFORM pg_catalog.set_config('rebuy.p4.listing_id', p_listing_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
    IF NOT EXISTS (
      SELECT 1
      FROM public.listings AS l
      JOIN public.products AS p ON p.id = l.product_id
      JOIN public.product_variants AS pv ON pv.id = l.variant_id
      JOIN public.stores AS s ON s.id = l.store_id
      JOIN public.organizations AS o
        ON o.id = l.organization_id AND o.organization_type = l.organization_type
      WHERE l.id = p_listing_id AND l.status = 'active'
        AND p.status = 'active' AND pv.status = 'active'
        AND s.status = 'active' AND s.public_visibility AND o.status = 'active'
    ) THEN RAISE EXCEPTION 'cart_item_not_available'; END IF;
    RETURN QUERY SELECT v_key.cart_id, v_key.result_version,
      v_key.cart_item_id, v_key.result_item_version, v_key.result_quantity;
  PERFORM private.rebuy_p5_reset_context();
    RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':active-cart', 0));
  SELECT c.* INTO v_cart FROM public.carts AS c
    WHERE c.owner_user_id = v_uid AND c.status = 'active' FOR UPDATE;
  IF v_cart.id IS NULL THEN
    IF p_expected_cart_version IS NOT NULL OR p_expected_item_version IS NOT NULL
    THEN RAISE EXCEPTION 'cart_version_conflict'; END IF;
    v_cart_id := pg_catalog.gen_random_uuid(); v_cart_version := 1;
    PERFORM pg_catalog.set_config('rebuy.p5.cart_id', v_cart_id::text, true);
    INSERT INTO public.carts (id, owner_user_id, status, version)
      VALUES (v_cart_id, v_uid, 'active', v_cart_version);
  ELSE
    v_cart_id := v_cart.id;
    PERFORM pg_catalog.set_config('rebuy.p5.cart_id', v_cart_id::text, true);
    IF p_expected_cart_version IS NULL OR v_cart.version <> p_expected_cart_version
    THEN RAISE EXCEPTION 'cart_version_conflict'; END IF;
    v_cart_version := v_cart.version + 1;
  END IF;
  SELECT q.purchasable INTO v_purchasable
    FROM private.get_catalog_quote_impl(p_listing_id, p_quantity) AS q;
  SELECT l.product_kind INTO v_kind FROM public.listings AS l
    WHERE l.id = p_listing_id;
  IF NOT COALESCE(v_purchasable, false) OR (v_kind = 'secondhand' AND p_quantity <> 1)
  THEN RAISE EXCEPTION 'cart_item_not_purchasable'; END IF;
  SELECT ci.* INTO v_item FROM public.cart_items AS ci
    WHERE ci.cart_id = v_cart_id AND ci.listing_id = p_listing_id FOR UPDATE;
  IF v_item.id IS NULL THEN
    IF p_expected_item_version IS NOT NULL THEN RAISE EXCEPTION 'cart_item_version_conflict'; END IF;
    v_item_id := pg_catalog.gen_random_uuid(); v_item_version := 1;
    PERFORM pg_catalog.set_config('rebuy.p5.cart_item_id', v_item_id::text, true);
    INSERT INTO public.cart_items (id, cart_id, owner_user_id, listing_id, quantity, version)
      VALUES (v_item_id, v_cart_id, v_uid, p_listing_id, p_quantity, v_item_version);
  ELSE
    IF p_expected_item_version IS NULL OR v_item.version <> p_expected_item_version
    THEN RAISE EXCEPTION 'cart_item_version_conflict'; END IF;
    v_item_id := v_item.id; v_item_version := v_item.version + 1;
    PERFORM pg_catalog.set_config('rebuy.p5.cart_item_id', v_item_id::text, true);
    UPDATE public.cart_items AS ci SET quantity = p_quantity,
      version = v_item_version, updated_at = pg_catalog.statement_timestamp()
      WHERE ci.id = v_item_id;
  END IF;
  IF v_cart.id IS NOT NULL THEN
    UPDATE public.carts AS c SET version = v_cart_version,
      updated_at = pg_catalog.statement_timestamp() WHERE c.id = v_cart_id;
  END IF;
  INSERT INTO public.p5_idempotency_keys (actor_user_id, idempotency_key,
    operation_code, request_fingerprint, cart_id, cart_item_id, listing_id,
    result_status, result_version, result_item_version, result_quantity)
  VALUES (v_uid, p_idempotency_key, 'cart.put', v_fingerprint, v_cart_id,
    v_item_id, p_listing_id, 'active', v_cart_version, v_item_version, p_quantity);
  RETURN QUERY SELECT v_cart_id, v_cart_version, v_item_id, v_item_version, p_quantity;
  PERFORM private.rebuy_p5_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.remove_cart_item_impl(
  p_listing_id uuid,
  p_expected_cart_version integer,
  p_expected_item_version integer,
  p_idempotency_key uuid
)
RETURNS TABLE (cart_id uuid, cart_version integer, listing_id uuid, result_status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_cart public.carts%ROWTYPE; v_item public.cart_items%ROWTYPE;
  v_key public.p5_idempotency_keys%ROWTYPE; v_fingerprint text; v_version integer;
BEGIN
  PERFORM private.rebuy_p5_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_listing_id IS NULL OR p_expected_cart_version IS NULL OR p_expected_cart_version < 1
     OR p_expected_item_version IS NULL OR p_expected_item_version < 1
     OR p_idempotency_key IS NULL THEN RAISE EXCEPTION 'cart_remove_invalid'; END IF;
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|', p_listing_id::text,
    p_expected_cart_version::text, p_expected_item_version::text));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p5-idempotency', 0));
  PERFORM pg_catalog.set_config('rebuy.p5.op', 'cart_remove', true);
  PERFORM pg_catalog.set_config('rebuy.p5.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.listing_id', p_listing_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.authorized', 'true', true);
  SELECT k.* INTO v_key FROM public.p5_idempotency_keys AS k
    WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'cart.remove'
       OR v_key.listing_id IS DISTINCT FROM p_listing_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p5_idempotency_conflict'; END IF;
    RETURN QUERY SELECT v_key.cart_id, v_key.result_version,
      v_key.listing_id, v_key.result_status;
  PERFORM private.rebuy_p5_reset_context();
    RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':active-cart', 0));
  SELECT c.* INTO v_cart FROM public.carts AS c
    WHERE c.owner_user_id = v_uid AND c.status = 'active' FOR UPDATE;
  IF v_cart.id IS NULL OR v_cart.version <> p_expected_cart_version
  THEN RAISE EXCEPTION 'cart_version_conflict'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p5.cart_id', v_cart.id::text, true);
  SELECT ci.* INTO v_item FROM public.cart_items AS ci
    WHERE ci.cart_id = v_cart.id AND ci.listing_id = p_listing_id FOR UPDATE;
  IF v_item.id IS NULL OR v_item.version <> p_expected_item_version
  THEN RAISE EXCEPTION 'cart_item_version_conflict'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p5.cart_item_id', v_item.id::text, true);
  DELETE FROM public.cart_items AS ci WHERE ci.id = v_item.id;
  v_version := v_cart.version + 1;
  UPDATE public.carts AS c SET version = v_version,
    updated_at = pg_catalog.statement_timestamp() WHERE c.id = v_cart.id;
  INSERT INTO public.p5_idempotency_keys (actor_user_id, idempotency_key,
    operation_code, request_fingerprint, cart_id, cart_item_id, listing_id,
    result_status, result_version)
  VALUES (v_uid, p_idempotency_key, 'cart.remove', v_fingerprint,
    v_cart.id, v_item.id, p_listing_id, 'removed', v_version);
  RETURN QUERY SELECT v_cart.id, v_version, p_listing_id, 'removed'::text;
  PERFORM private.rebuy_p5_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.checkout_cart_impl(
  p_expected_cart_version integer,
  p_synthetic_delivery_reference text,
  p_idempotency_key uuid
)
RETURNS TABLE (
  batch_id uuid, synthetic_order_reference text, order_status text,
  inventory_status text, currency_code text, total_cents integer,
  order_version integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_cart public.carts%ROWTYPE; v_key public.p5_idempotency_keys%ROWTYPE;
  v_item public.cart_items%ROWTYPE; v_quote record; v_listing public.listings%ROWTYPE;
  v_batch_id uuid := pg_catalog.gen_random_uuid(); v_suborder_id uuid;
  v_event_id uuid := pg_catalog.gen_random_uuid(); v_inventory_version integer;
  v_reserved_version integer; v_line bigint; v_total bigint := 0;
  v_fingerprint text; v_order_ref text;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_p5_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_expected_cart_version IS NULL OR p_expected_cart_version < 1
     OR p_idempotency_key IS NULL OR p_synthetic_delivery_reference IS NULL
     OR pg_catalog.lower(pg_catalog.btrim(p_synthetic_delivery_reference))
       !~ '^synthetic://delivery/[a-z0-9][a-z0-9/_-]{2,120}$'
  THEN RAISE EXCEPTION 'checkout_invalid'; END IF;
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|',
    p_expected_cart_version::text,
    pg_catalog.lower(pg_catalog.btrim(p_synthetic_delivery_reference))));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p5-idempotency', 0));
  PERFORM pg_catalog.set_config('rebuy.p5.op', 'order_checkout', true);
  PERFORM pg_catalog.set_config('rebuy.p5.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.authorized', 'true', true);
  SELECT k.* INTO v_key FROM public.p5_idempotency_keys AS k
    WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'order.checkout'
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p5_idempotency_conflict'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p5.batch_id', v_key.batch_id::text, true);
    RETURN QUERY SELECT v_key.batch_id, v_key.result_reference,
      v_key.result_status, v_key.result_inventory_status,
      v_key.result_currency_code, v_key.result_total_cents,
      v_key.result_version;
  PERFORM private.rebuy_p5_reset_context();
    RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':active-cart', 0));
  SELECT c.* INTO v_cart FROM public.carts AS c
    WHERE c.owner_user_id = v_uid AND c.status = 'active' FOR UPDATE;
  IF v_cart.id IS NULL OR v_cart.version <> p_expected_cart_version
  THEN RAISE EXCEPTION 'cart_version_conflict'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p5.cart_id', v_cart.id::text, true);
  IF NOT EXISTS (SELECT 1 FROM public.cart_items AS ci WHERE ci.cart_id = v_cart.id)
  THEN RAISE EXCEPTION 'checkout_cart_empty'; END IF;
  -- P4 obtains its actor/idempotency advisory lock before its business-row
  -- locks. Pre-acquire every reservation key in the same deterministic listing
  -- order before pricing or listing locks, so cross-role merchant/buyer calls
  -- cannot invert the P4 lock order and deadlock checkout.
  FOR v_item IN SELECT ci.* FROM public.cart_items AS ci
    WHERE ci.cart_id = v_cart.id ORDER BY ci.listing_id
  LOOP
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
      v_uid::text || ':' || private.rebuy_p5_derived_uuid(p_idempotency_key,
        'reserve:' || v_item.listing_id::text)::text || ':p4-idempotency', 0));
  END LOOP;
  PERFORM private.rebuy_p5_lock_pricing_context(v_uid);
  FOR v_item IN SELECT ci.* FROM public.cart_items AS ci
    WHERE ci.cart_id = v_cart.id ORDER BY ci.listing_id
  LOOP
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_item.listing_id::text, 0));
  END LOOP;
  PERFORM pg_catalog.set_config('rebuy.p5.batch_id', v_batch_id::text, true);
  v_order_ref := 'SYN-ORDER-' || pg_catalog.upper(
    pg_catalog.substr(pg_catalog.replace(v_batch_id::text, '-', ''), 1, 20));
  INSERT INTO public.order_batches (id, buyer_user_id, source_cart_id,
    source_cart_version, synthetic_order_reference, synthetic_delivery_reference,
    subtotal_cents, total_cents, status, inventory_status, payment_status,
    version, created_at, updated_at)
  VALUES (v_batch_id, v_uid, v_cart.id, v_cart.version, v_order_ref,
    pg_catalog.lower(pg_catalog.btrim(p_synthetic_delivery_reference)),
    1, 1, 'confirmed', 'reserved', 'not_required', 1, v_now, v_now);
  FOR v_item IN SELECT ci.* FROM public.cart_items AS ci
    WHERE ci.cart_id = v_cart.id ORDER BY ci.listing_id
  LOOP
    PERFORM pg_catalog.set_config('rebuy.p5.listing_id', v_item.listing_id::text, true);
    SELECT q.* INTO v_quote
      FROM private.get_catalog_quote_impl(v_item.listing_id, v_item.quantity) AS q;
    IF v_quote.listing_id IS NULL OR NOT v_quote.purchasable
    THEN RAISE EXCEPTION 'checkout_item_not_purchasable'; END IF;
    SELECT l.* INTO v_listing FROM public.listings AS l WHERE l.id = v_item.listing_id;
    IF v_listing.product_kind = 'standard' THEN
      SELECT il.version INTO v_inventory_version FROM public.inventory_levels AS il
        WHERE il.listing_id = v_item.listing_id;
    ELSE
      SELECT su.version INTO v_inventory_version FROM public.secondhand_units AS su
        WHERE su.listing_id = v_item.listing_id;
    END IF;
    IF v_inventory_version IS NULL THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
    SELECT r.inventory_version INTO v_reserved_version
      FROM private.change_inventory_reservation_impl(v_item.listing_id,
        v_item.quantity, 'reserve', v_inventory_version, v_order_ref,
        private.rebuy_p5_derived_uuid(p_idempotency_key,
          'reserve:' || v_item.listing_id::text)) AS r;
    SELECT mo.id INTO v_suborder_id FROM public.merchant_orders AS mo
      WHERE mo.batch_id = v_batch_id AND mo.store_id = v_listing.store_id;
    v_line := v_quote.unit_amount_cents::bigint * v_item.quantity::bigint;
    IF v_line < 1 OR v_total + v_line > 2147483647
    THEN RAISE EXCEPTION 'checkout_total_invalid'; END IF;
    IF v_suborder_id IS NULL THEN
      v_suborder_id := pg_catalog.gen_random_uuid();
      INSERT INTO public.merchant_orders (id, batch_id, buyer_user_id,
        organization_id, organization_type, store_id, currency_code,
        subtotal_cents, total_cents, status, inventory_status, version,
        created_at, updated_at)
      VALUES (v_suborder_id, v_batch_id, v_uid, v_listing.organization_id,
        'merchant', v_listing.store_id, 'EUR', v_line::integer, v_line::integer,
        'pending', 'reserved', 1, v_now, v_now);
    ELSE
      UPDATE public.merchant_orders AS mo
      SET subtotal_cents = mo.subtotal_cents + v_line::integer,
        total_cents = mo.total_cents + v_line::integer,
        updated_at = v_now WHERE mo.id = v_suborder_id;
    END IF;
    INSERT INTO public.order_items (batch_id, merchant_order_id, buyer_user_id,
      organization_id, store_id, listing_id, product_id, variant_id,
      product_kind, quantity, audience, currency_code, unit_amount_cents,
      line_amount_cents, price_version, listing_version, inventory_version,
      inventory_status, title_snapshot, sku_snapshot, created_at, updated_at)
    SELECT v_batch_id, v_suborder_id, v_uid, v_listing.organization_id,
      v_listing.store_id, v_listing.id, v_listing.product_id, v_listing.variant_id,
      v_listing.product_kind, v_item.quantity, v_quote.audience, 'EUR',
      v_quote.unit_amount_cents, v_line::integer, v_quote.price_version,
      v_quote.listing_version, v_reserved_version, 'reserved',
      v_listing.title, pv.sku, v_now, v_now
    FROM public.product_variants AS pv WHERE pv.id = v_listing.variant_id;
    v_total := v_total + v_line;
  END LOOP;
  UPDATE public.order_batches AS ob SET subtotal_cents = v_total::integer,
    total_cents = v_total::integer, updated_at = v_now WHERE ob.id = v_batch_id;
  DELETE FROM public.cart_items AS ci WHERE ci.cart_id = v_cart.id;
  UPDATE public.carts AS c SET status = 'checked_out',
    checkout_batch_id = v_batch_id, version = c.version + 1,
    updated_at = v_now WHERE c.id = v_cart.id;
  PERFORM pg_catalog.set_config('rebuy.p5.event_id', v_event_id::text, true);
  INSERT INTO public.order_events (id, batch_id, buyer_user_id, actor_user_id,
    event_code, reason_code, from_status, to_status, from_version, to_version,
    idempotency_key, request_fingerprint, created_at)
  VALUES (v_event_id, v_batch_id, v_uid, v_uid, 'order.confirmed',
    'buyer_checkout', NULL, 'confirmed', NULL, 1, p_idempotency_key,
    v_fingerprint, v_now);
  INSERT INTO public.p5_idempotency_keys (actor_user_id, idempotency_key,
    operation_code, request_fingerprint, cart_id, batch_id, result_status,
    result_version, result_reference, result_inventory_status,
    result_currency_code, result_total_cents)
  VALUES (v_uid, p_idempotency_key, 'order.checkout', v_fingerprint,
    v_cart.id, v_batch_id, 'confirmed', 1, v_order_ref, 'reserved',
    'EUR', v_total::integer);
  RETURN QUERY SELECT v_batch_id, v_order_ref, 'confirmed'::text,
    'reserved'::text, 'EUR'::text, v_total::integer, 1;
  PERFORM private.rebuy_p5_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.list_my_orders_impl()
RETURNS TABLE (
  batch_id uuid, synthetic_order_reference text, order_status text,
  inventory_status text, payment_status text, currency_code text,
  total_cents integer, order_version integer, merchant_count integer,
  item_count integer, created_at timestamptz, cancelled_at timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_uid uuid;
BEGIN
  PERFORM private.rebuy_p5_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(false) AS i;
  PERFORM pg_catalog.set_config('rebuy.p5.op', 'order_list', true);
  PERFORM pg_catalog.set_config('rebuy.p5.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.authorized', 'true', true);
  RETURN QUERY SELECT ob.id, ob.synthetic_order_reference, ob.status,
    ob.inventory_status, ob.payment_status, ob.currency_code, ob.total_cents,
    ob.version, (SELECT pg_catalog.count(*)::integer FROM public.merchant_orders AS mo
      WHERE mo.batch_id = ob.id),
    (SELECT pg_catalog.sum(oi.quantity)::integer FROM public.order_items AS oi
      WHERE oi.batch_id = ob.id), ob.created_at, ob.cancelled_at
  FROM public.order_batches AS ob WHERE ob.buyer_user_id = v_uid
  ORDER BY ob.created_at DESC, ob.id DESC;
  PERFORM private.rebuy_p5_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.get_my_order_impl(p_batch_id uuid)
RETURNS TABLE (
  batch_id uuid, synthetic_order_reference text, synthetic_delivery_reference text,
  order_status text, inventory_status text, payment_status text,
  currency_code text, total_cents integer, order_version integer,
  merchant_order_id uuid, merchant_order_status text, store_id uuid,
  store_name text, merchant_subtotal_cents integer, listing_id uuid,
  title_snapshot text, sku_snapshot text, product_kind text, quantity integer,
  audience text, unit_amount_cents integer, line_amount_cents integer,
  item_inventory_status text, event_codes jsonb, created_at timestamptz,
  cancelled_at timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_uid uuid;
BEGIN
  PERFORM private.rebuy_p5_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(false) AS i;
  IF p_batch_id IS NULL THEN RAISE EXCEPTION 'order_detail_invalid'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p5.op', 'order_detail', true);
  PERFORM pg_catalog.set_config('rebuy.p5.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.batch_id', p_batch_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.authorized', 'true', true);
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  RETURN QUERY SELECT ob.id, ob.synthetic_order_reference,
    ob.synthetic_delivery_reference, ob.status, ob.inventory_status,
    ob.payment_status, ob.currency_code, ob.total_cents, ob.version,
    mo.id, mo.status, mo.store_id, s.display_name, mo.subtotal_cents,
    oi.listing_id, oi.title_snapshot, oi.sku_snapshot, oi.product_kind,
    oi.quantity, oi.audience, oi.unit_amount_cents, oi.line_amount_cents,
    oi.inventory_status,
    COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'event', oe.event_code, 'status', oe.to_status, 'created_at', oe.created_at)
      ORDER BY oe.created_at, oe.id) FROM public.order_events AS oe
      WHERE oe.batch_id = ob.id), '[]'::jsonb),
    ob.created_at, ob.cancelled_at
  FROM public.order_batches AS ob
  JOIN public.merchant_orders AS mo ON mo.batch_id = ob.id
  JOIN public.order_items AS oi ON oi.merchant_order_id = mo.id
  JOIN public.stores AS s ON s.id = mo.store_id
  WHERE ob.id = p_batch_id AND ob.buyer_user_id = v_uid
  ORDER BY mo.id, oi.id;
  PERFORM private.rebuy_p5_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.cancel_my_order_batch_impl(
  p_batch_id uuid,
  p_expected_version integer,
  p_idempotency_key uuid
)
RETURNS TABLE (
  batch_id uuid, order_status text, inventory_status text,
  order_version integer, cancelled_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_batch public.order_batches%ROWTYPE;
  v_key public.p5_idempotency_keys%ROWTYPE; v_item public.order_items%ROWTYPE;
  v_event_id uuid := pg_catalog.gen_random_uuid(); v_inventory_version integer;
  v_released_version integer; v_fingerprint text;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  PERFORM private.rebuy_p5_reset_context();
  SELECT i.user_id INTO v_uid FROM private.rebuy_business_require_identity(true) AS i;
  IF p_batch_id IS NULL OR p_expected_version IS NULL OR p_expected_version < 1
     OR p_idempotency_key IS NULL THEN RAISE EXCEPTION 'order_cancel_invalid'; END IF;
  v_fingerprint := pg_catalog.md5(p_batch_id::text || '|' || p_expected_version::text);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p5-idempotency', 0));
  PERFORM pg_catalog.set_config('rebuy.p5.op', 'order_cancel', true);
  PERFORM pg_catalog.set_config('rebuy.p5.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.batch_id', p_batch_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p5.authorized', 'true', true);
  SELECT k.* INTO v_key FROM public.p5_idempotency_keys AS k
    WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'order.cancel'
       OR v_key.batch_id IS DISTINCT FROM p_batch_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p5_idempotency_conflict'; END IF;
    RETURN QUERY SELECT v_key.batch_id, v_key.result_status,
      v_key.result_inventory_status, v_key.result_version,
      v_key.result_cancelled_at;
  PERFORM private.rebuy_p5_reset_context();
    RETURN;
  END IF;
  SELECT ob.* INTO v_batch FROM public.order_batches AS ob
    WHERE ob.id = p_batch_id AND ob.buyer_user_id = v_uid FOR UPDATE;
  IF v_batch.id IS NULL THEN RAISE EXCEPTION 'order_not_available'; END IF;
  IF v_batch.version <> p_expected_version THEN RAISE EXCEPTION 'order_version_conflict'; END IF;
  PERFORM 1 FROM public.merchant_orders AS mo
    WHERE mo.batch_id = p_batch_id ORDER BY mo.id FOR UPDATE;
  IF v_batch.status <> 'confirmed' OR v_batch.inventory_status <> 'reserved'
     OR EXISTS (SELECT 1 FROM public.merchant_orders AS mo
       WHERE mo.batch_id = p_batch_id AND mo.status <> 'pending')
  THEN RAISE EXCEPTION 'order_cancel_not_allowed'; END IF;
  FOR v_item IN SELECT oi.* FROM public.order_items AS oi
    WHERE oi.batch_id = p_batch_id ORDER BY oi.listing_id FOR UPDATE
  LOOP
    PERFORM pg_catalog.set_config('rebuy.p5.listing_id', v_item.listing_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
    PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
    PERFORM pg_catalog.set_config('rebuy.p4.listing_id', v_item.listing_id::text, true);
    IF v_item.product_kind = 'standard' THEN
      SELECT il.version INTO v_inventory_version FROM public.inventory_levels AS il
        WHERE il.listing_id = v_item.listing_id;
    ELSE
      SELECT su.version INTO v_inventory_version FROM public.secondhand_units AS su
        WHERE su.listing_id = v_item.listing_id;
    END IF;
    IF v_inventory_version IS NULL THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
    SELECT r.inventory_version INTO v_released_version
      FROM private.change_inventory_reservation_impl(v_item.listing_id,
        v_item.quantity, 'release', v_inventory_version,
        v_batch.synthetic_order_reference,
        private.rebuy_p5_derived_uuid(p_idempotency_key,
          'release:' || v_item.listing_id::text)) AS r;
    UPDATE public.order_items AS oi SET inventory_status = 'released',
      inventory_version = v_released_version, updated_at = v_now
      WHERE oi.id = v_item.id;
  END LOOP;
  UPDATE public.merchant_orders AS mo SET status = 'cancelled',
    inventory_status = 'released', version = mo.version + 1,
    updated_at = v_now WHERE mo.batch_id = p_batch_id;
  UPDATE public.order_batches AS ob SET status = 'cancelled',
    inventory_status = 'released', version = ob.version + 1,
    cancelled_at = v_now, updated_at = v_now WHERE ob.id = p_batch_id;
  PERFORM pg_catalog.set_config('rebuy.p5.event_id', v_event_id::text, true);
  INSERT INTO public.order_events (id, batch_id, buyer_user_id, actor_user_id,
    event_code, reason_code, from_status, to_status, from_version, to_version,
    idempotency_key, request_fingerprint, created_at)
  VALUES (v_event_id, p_batch_id, v_uid, v_uid, 'order.cancelled',
    'buyer_cancelled_before_fulfillment', 'confirmed', 'cancelled',
    v_batch.version, v_batch.version + 1, p_idempotency_key, v_fingerprint, v_now);
  INSERT INTO public.p5_idempotency_keys (actor_user_id, idempotency_key,
    operation_code, request_fingerprint, batch_id, result_status, result_version,
    result_inventory_status, result_cancelled_at)
  VALUES (v_uid, p_idempotency_key, 'order.cancel', v_fingerprint,
    p_batch_id, 'cancelled', v_batch.version + 1, 'released', v_now);
  RETURN QUERY SELECT p_batch_id, 'cancelled'::text, 'released'::text,
    v_batch.version + 1, v_now;
  PERFORM private.rebuy_p5_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION public.search_catalog(
  p_query text DEFAULT NULL, p_category_slug text DEFAULT NULL,
  p_limit integer DEFAULT 24, p_offset integer DEFAULT 0
)
RETURNS TABLE (
  listing_id uuid, store_id uuid, store_name text, category_slug text,
  product_kind text, listing_slug text, title text, summary text,
  audience text, unit_amount_cents integer, minimum_quantity integer,
  currency_code text, available_quantity integer, price_version integer,
  listing_version integer, purchasable boolean
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.search_catalog_impl(p_query, p_category_slug, p_limit, p_offset)
$function$;

CREATE OR REPLACE FUNCTION public.get_my_cart()
RETURNS TABLE (
  cart_id uuid, cart_version integer, listing_id uuid, item_id uuid,
  quantity integer, item_version integer, store_id uuid, store_name text,
  product_kind text, title text, sku text, audience text,
  unit_amount_cents integer, minimum_quantity integer, currency_code text,
  available_quantity integer, price_version integer, listing_version integer,
  purchasable boolean, invalid_reason text
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_my_cart_impl() $function$;

CREATE OR REPLACE FUNCTION public.put_cart_item(
  p_listing_id uuid, p_quantity integer, p_expected_cart_version integer,
  p_expected_item_version integer, p_idempotency_key uuid
)
RETURNS TABLE (
  cart_id uuid, cart_version integer, item_id uuid,
  item_version integer, quantity integer
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.put_cart_item_impl(p_listing_id, p_quantity,
  p_expected_cart_version, p_expected_item_version, p_idempotency_key) $function$;

CREATE OR REPLACE FUNCTION public.remove_cart_item(
  p_listing_id uuid, p_expected_cart_version integer,
  p_expected_item_version integer, p_idempotency_key uuid
)
RETURNS TABLE (cart_id uuid, cart_version integer, listing_id uuid, result_status text)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.remove_cart_item_impl(p_listing_id,
  p_expected_cart_version, p_expected_item_version, p_idempotency_key) $function$;

CREATE OR REPLACE FUNCTION public.checkout_cart(
  p_expected_cart_version integer, p_synthetic_delivery_reference text,
  p_idempotency_key uuid
)
RETURNS TABLE (
  batch_id uuid, synthetic_order_reference text, order_status text,
  inventory_status text, currency_code text, total_cents integer,
  order_version integer
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.checkout_cart_impl(p_expected_cart_version,
  p_synthetic_delivery_reference, p_idempotency_key) $function$;

CREATE OR REPLACE FUNCTION public.list_my_orders()
RETURNS TABLE (
  batch_id uuid, synthetic_order_reference text, order_status text,
  inventory_status text, payment_status text, currency_code text,
  total_cents integer, order_version integer, merchant_count integer,
  item_count integer, created_at timestamptz, cancelled_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.list_my_orders_impl() $function$;

CREATE OR REPLACE FUNCTION public.get_my_order(p_batch_id uuid)
RETURNS TABLE (
  batch_id uuid, synthetic_order_reference text, synthetic_delivery_reference text,
  order_status text, inventory_status text, payment_status text,
  currency_code text, total_cents integer, order_version integer,
  merchant_order_id uuid, merchant_order_status text, store_id uuid,
  store_name text, merchant_subtotal_cents integer, listing_id uuid,
  title_snapshot text, sku_snapshot text, product_kind text, quantity integer,
  audience text, unit_amount_cents integer, line_amount_cents integer,
  item_inventory_status text, event_codes jsonb, created_at timestamptz,
  cancelled_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_my_order_impl(p_batch_id) $function$;

CREATE OR REPLACE FUNCTION public.cancel_my_order_batch(
  p_batch_id uuid, p_expected_version integer, p_idempotency_key uuid
)
RETURNS TABLE (
  batch_id uuid, order_status text, inventory_status text,
  order_version integer, cancelled_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.cancel_my_order_batch_impl(p_batch_id,
  p_expected_version, p_idempotency_key) $function$;

REVOKE ALL PRIVILEGES ON FUNCTION private.search_catalog_impl(text, text, integer, integer),
  private.get_my_cart_impl(),
  private.put_cart_item_impl(uuid, integer, integer, integer, uuid),
  private.remove_cart_item_impl(uuid, integer, integer, uuid),
  private.checkout_cart_impl(integer, text, uuid),
  private.list_my_orders_impl(), private.get_my_order_impl(uuid),
  private.cancel_my_order_batch_impl(uuid, integer, uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
GRANT EXECUTE ON FUNCTION private.search_catalog_impl(text, text, integer, integer)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION private.get_my_cart_impl(),
  private.put_cart_item_impl(uuid, integer, integer, integer, uuid),
  private.remove_cart_item_impl(uuid, integer, integer, uuid),
  private.checkout_cart_impl(integer, text, uuid),
  private.list_my_orders_impl(), private.get_my_order_impl(uuid),
  private.cancel_my_order_batch_impl(uuid, integer, uuid)
  TO authenticated;

DO $owner_handoff$
BEGIN
  IF pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR pg_catalog.has_schema_privilege('rebuy_business_executor', 'private', 'CREATE')
  THEN RAISE EXCEPTION 'rebuy_p5_owner_handoff_precondition_invalid'; END IF;
  EXECUTE 'GRANT rebuy_business_executor TO postgres WITH INHERIT FALSE GRANTED BY CURRENT_USER';
  EXECUTE 'GRANT CREATE ON SCHEMA private TO rebuy_business_executor GRANTED BY CURRENT_USER';
  EXECUTE 'ALTER FUNCTION private.search_catalog_impl(text, text, integer, integer) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.get_my_cart_impl() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.put_cart_item_impl(uuid, integer, integer, integer, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.remove_cart_item_impl(uuid, integer, integer, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.checkout_cart_impl(integer, text, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.list_my_orders_impl() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.get_my_order_impl(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.cancel_my_order_batch_impl(uuid, integer, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.rebuy_p5_clear_context() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.rebuy_p5_lock_pricing_context(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'REVOKE rebuy_business_executor FROM postgres GRANTED BY CURRENT_USER';
  EXECUTE 'REVOKE CREATE ON SCHEMA private FROM rebuy_business_executor GRANTED BY CURRENT_USER';
  IF pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
     OR pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR pg_catalog.has_schema_privilege('rebuy_business_executor', 'private', 'CREATE')
  THEN RAISE EXCEPTION 'rebuy_p5_owner_handoff_cleanup_invalid'; END IF;
END
$owner_handoff$;

REVOKE ALL PRIVILEGES ON FUNCTION public.search_catalog(text, text, integer, integer)
  FROM PUBLIC, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public.get_my_cart(),
  public.put_cart_item(uuid, integer, integer, integer, uuid),
  public.remove_cart_item(uuid, integer, integer, uuid),
  public.checkout_cart(integer, text, uuid), public.list_my_orders(),
  public.get_my_order(uuid), public.cancel_my_order_batch(uuid, integer, uuid)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.search_catalog(text, text, integer, integer)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_cart(),
  public.put_cart_item(uuid, integer, integer, integer, uuid),
  public.remove_cart_item(uuid, integer, integer, uuid),
  public.checkout_cart(integer, text, uuid), public.list_my_orders(),
  public.get_my_order(uuid), public.cancel_my_order_batch(uuid, integer, uuid)
  TO authenticated;
