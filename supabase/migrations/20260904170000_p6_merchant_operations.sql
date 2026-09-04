-- P6 synthetic-only Merchant Shell, scoped fulfillment, after-sales and audit.

DO $roles$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'rebuy_business_executor'
  ) OR pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
     OR pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR pg_catalog.has_schema_privilege(
       'rebuy_business_executor', 'private', 'CREATE'
     )
  THEN
    RAISE EXCEPTION 'rebuy_p6_executor_precondition_invalid';
  END IF;
END
$roles$;

ALTER TABLE public.order_batches
  DROP CONSTRAINT order_batches_status_check,
  DROP CONSTRAINT order_batches_inventory_check,
  DROP CONSTRAINT order_batches_state_check;
ALTER TABLE public.order_batches
  ADD CONSTRAINT order_batches_status_check CHECK (
    status IN ('confirmed', 'processing', 'completed', 'cancelled')
  ),
  ADD CONSTRAINT order_batches_inventory_check CHECK (
    inventory_status IN ('reserved', 'mixed', 'sold', 'released')
  ),
  ADD CONSTRAINT order_batches_state_check CHECK (
    (status = 'confirmed' AND inventory_status = 'reserved'
      AND cancelled_at IS NULL)
    OR (status = 'processing' AND inventory_status IN ('reserved', 'mixed', 'sold')
      AND cancelled_at IS NULL)
    OR (status = 'completed' AND inventory_status IN ('sold', 'mixed')
      AND cancelled_at IS NULL)
    OR (status = 'cancelled' AND inventory_status = 'released'
      AND cancelled_at IS NOT NULL)
  );

ALTER TABLE public.merchant_orders
  ADD COLUMN synthetic_shipment_reference text,
  ADD COLUMN accepted_at timestamptz,
  ADD COLUMN shipped_at timestamptz,
  ADD COLUMN completed_at timestamptz,
  DROP CONSTRAINT merchant_orders_status_check,
  DROP CONSTRAINT merchant_orders_inventory_check,
  DROP CONSTRAINT merchant_orders_state_check;
ALTER TABLE public.merchant_orders
  ADD CONSTRAINT merchant_orders_status_check CHECK (
    status IN ('pending', 'accepted', 'shipped', 'completed', 'rejected', 'cancelled')
  ),
  ADD CONSTRAINT merchant_orders_inventory_check CHECK (
    inventory_status IN ('reserved', 'sold', 'released')
  ),
  ADD CONSTRAINT merchant_orders_shipment_reference_check CHECK (
    synthetic_shipment_reference IS NULL
    OR synthetic_shipment_reference ~ '^synthetic://shipment/[a-z0-9][a-z0-9/_-]{2,120}$'
  ),
  ADD CONSTRAINT merchant_orders_state_check CHECK (
    (status = 'pending' AND inventory_status = 'reserved'
      AND accepted_at IS NULL AND shipped_at IS NULL AND completed_at IS NULL
      AND synthetic_shipment_reference IS NULL)
    OR (status = 'accepted' AND inventory_status = 'reserved'
      AND accepted_at IS NOT NULL AND shipped_at IS NULL AND completed_at IS NULL
      AND synthetic_shipment_reference IS NULL)
    OR (status = 'shipped' AND inventory_status = 'reserved'
      AND accepted_at IS NOT NULL AND shipped_at IS NOT NULL AND completed_at IS NULL
      AND synthetic_shipment_reference IS NOT NULL)
    OR (status = 'completed' AND inventory_status = 'sold'
      AND accepted_at IS NOT NULL AND shipped_at IS NOT NULL AND completed_at IS NOT NULL
      AND synthetic_shipment_reference IS NOT NULL)
    OR (status IN ('rejected', 'cancelled') AND inventory_status = 'released'
      AND shipped_at IS NULL AND completed_at IS NULL
      AND synthetic_shipment_reference IS NULL)
  );

ALTER TABLE public.order_items
  DROP CONSTRAINT order_items_inventory_check;
ALTER TABLE public.order_items
  ADD CONSTRAINT order_items_inventory_check CHECK (
    inventory_status IN ('reserved', 'sold', 'released')
  );

ALTER TABLE public.order_events
  DROP CONSTRAINT order_events_code_check,
  DROP CONSTRAINT order_events_reason_check,
  DROP CONSTRAINT order_events_status_check;
ALTER TABLE public.order_events
  ADD CONSTRAINT order_events_code_check CHECK (
    event_code IN ('order.confirmed', 'order.cancelled',
      'merchant_order.accepted', 'merchant_order.rejected',
      'merchant_order.shipped', 'merchant_order.completed')
  ),
  ADD CONSTRAINT order_events_reason_check CHECK (
    reason_code IN ('buyer_checkout', 'buyer_cancelled_before_fulfillment',
      'merchant_accepted', 'merchant_rejected_out_of_stock',
      'merchant_rejected_listing_issue', 'synthetic_shipment_created',
      'merchant_completed')
  ),
  ADD CONSTRAINT order_events_status_check CHECK (
    (event_code = 'order.confirmed' AND merchant_order_id IS NULL
      AND from_status IS NULL AND to_status = 'confirmed')
    OR (event_code = 'order.cancelled' AND merchant_order_id IS NULL
      AND from_status = 'confirmed' AND to_status = 'cancelled')
    OR (event_code = 'merchant_order.accepted' AND merchant_order_id IS NOT NULL
      AND from_status = 'pending' AND to_status = 'accepted')
    OR (event_code = 'merchant_order.rejected' AND merchant_order_id IS NOT NULL
      AND from_status = 'pending' AND to_status = 'rejected')
    OR (event_code = 'merchant_order.shipped' AND merchant_order_id IS NOT NULL
      AND from_status = 'accepted' AND to_status = 'shipped')
    OR (event_code = 'merchant_order.completed' AND merchant_order_id IS NOT NULL
      AND from_status = 'shipped' AND to_status = 'completed')
  );

CREATE TABLE public.merchant_after_sale_cases (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  merchant_order_id uuid NOT NULL,
  batch_id uuid NOT NULL,
  buyer_user_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  store_id uuid NOT NULL,
  reason_code text NOT NULL,
  status text NOT NULL DEFAULT 'opened',
  resolution_code text,
  version integer NOT NULL DEFAULT 1,
  created_by uuid NOT NULL REFERENCES auth.users (id),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  resolved_at timestamptz,
  CONSTRAINT merchant_after_sale_order_fk FOREIGN KEY (merchant_order_id, batch_id)
    REFERENCES public.merchant_orders (id, batch_id),
  CONSTRAINT merchant_after_sale_batch_buyer_fk FOREIGN KEY (batch_id, buyer_user_id)
    REFERENCES public.order_batches (id, buyer_user_id),
  CONSTRAINT merchant_after_sale_store_fk FOREIGN KEY (
    store_id, organization_id, organization_type
  ) REFERENCES public.stores (id, organization_id, organization_type),
  CONSTRAINT merchant_after_sale_type_check CHECK (organization_type = 'merchant'),
  CONSTRAINT merchant_after_sale_reason_check CHECK (
    reason_code IN ('return_request', 'damaged', 'wrong_item')
  ),
  CONSTRAINT merchant_after_sale_status_check CHECK (
    status IN ('opened', 'reviewing', 'resolved', 'rejected')
  ),
  CONSTRAINT merchant_after_sale_resolution_check CHECK (
    (status IN ('opened', 'reviewing') AND resolution_code IS NULL
      AND resolved_at IS NULL)
    OR (status = 'resolved'
      AND resolution_code IN ('replacement_recorded', 'return_recorded',
        'no_action_recorded') AND resolved_at IS NOT NULL)
    OR (status = 'rejected' AND resolution_code = 'request_rejected'
      AND resolved_at IS NOT NULL)
  ),
  CONSTRAINT merchant_after_sale_version_check CHECK (version > 0),
  CONSTRAINT merchant_after_sale_order_reason_key UNIQUE (
    merchant_order_id, reason_code
  ),
  CONSTRAINT merchant_after_sale_id_store_key UNIQUE (id, store_id)
);
CREATE INDEX merchant_after_sale_store_status_idx
  ON public.merchant_after_sale_cases (store_id, status, created_at DESC, id);
CREATE INDEX merchant_after_sale_org_store_idx
  ON public.merchant_after_sale_cases (organization_id, store_id);
CREATE INDEX merchant_after_sale_store_org_type_idx
  ON public.merchant_after_sale_cases (
    store_id, organization_id, organization_type
  );
CREATE INDEX merchant_after_sale_order_idx
  ON public.merchant_after_sale_cases (merchant_order_id, batch_id);
CREATE INDEX merchant_after_sale_batch_buyer_idx
  ON public.merchant_after_sale_cases (batch_id, buyer_user_id);
CREATE INDEX merchant_after_sale_created_by_idx
  ON public.merchant_after_sale_cases (created_by);

CREATE TABLE public.merchant_operation_events (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  store_id uuid NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users (id),
  actor_membership_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  event_code text NOT NULL,
  reason_code text NOT NULL,
  from_status text,
  to_status text NOT NULL,
  from_version integer,
  to_version integer NOT NULL,
  idempotency_key uuid NOT NULL,
  request_fingerprint text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  CONSTRAINT merchant_operation_store_fk FOREIGN KEY (
    store_id, organization_id, organization_type
  ) REFERENCES public.stores (id, organization_id, organization_type),
  CONSTRAINT merchant_operation_membership_fk FOREIGN KEY (
    actor_membership_id, organization_id, organization_type
  ) REFERENCES public.memberships (id, organization_id, organization_type),
  CONSTRAINT merchant_operation_type_check CHECK (organization_type = 'merchant'),
  CONSTRAINT merchant_operation_entity_check CHECK (
    entity_type IN ('merchant_order', 'after_sale', 'inventory')
  ),
  CONSTRAINT merchant_operation_event_check CHECK (
    event_code IN ('merchant_order.accepted', 'merchant_order.rejected',
      'merchant_order.shipped', 'merchant_order.completed',
      'inventory.adjusted',
      'after_sale.opened', 'after_sale.reviewing',
      'after_sale.resolved', 'after_sale.rejected')
  ),
  CONSTRAINT merchant_operation_reason_check CHECK (
    reason_code IN ('merchant_accepted', 'merchant_rejected_out_of_stock',
      'merchant_rejected_listing_issue', 'synthetic_shipment_created',
      'merchant_completed', 'return_request', 'damaged', 'wrong_item',
      'stock_received', 'stock_correction', 'cycle_count',
      'review_started', 'replacement_recorded', 'return_recorded',
      'no_action_recorded', 'request_rejected')
  ),
  CONSTRAINT merchant_operation_version_check CHECK (
    (from_version IS NULL AND to_version = 1)
    OR (from_version IS NOT NULL AND from_version > 0
      AND to_version = from_version + 1)
  ),
  CONSTRAINT merchant_operation_fingerprint_check CHECK (
    request_fingerprint ~ '^[0-9a-f]{32}$'
  ),
  CONSTRAINT merchant_operation_actor_key UNIQUE (
    actor_user_id, idempotency_key
  )
);
CREATE INDEX merchant_operation_store_created_idx
  ON public.merchant_operation_events (store_id, created_at DESC, id);
CREATE INDEX merchant_operation_org_store_idx
  ON public.merchant_operation_events (organization_id, store_id);
CREATE INDEX merchant_operation_store_org_type_idx
  ON public.merchant_operation_events (
    store_id, organization_id, organization_type
  );
CREATE INDEX merchant_operation_membership_org_type_idx
  ON public.merchant_operation_events (
    actor_membership_id, organization_id, organization_type
  );
CREATE INDEX merchant_operation_entity_idx
  ON public.merchant_operation_events (entity_type, entity_id, created_at);

CREATE TABLE public.p6_idempotency_keys (
  actor_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  idempotency_key uuid NOT NULL,
  operation_code text NOT NULL,
  target_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  organization_type text NOT NULL DEFAULT 'merchant',
  store_id uuid NOT NULL,
  request_fingerprint text NOT NULL,
  result_status text NOT NULL,
  result_version integer NOT NULL,
  result_reference text,
  result_id uuid,
  result_batch_status text,
  result_batch_inventory_status text,
  result_batch_version integer,
  result_resolution_code text,
  result_resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.statement_timestamp(),
  PRIMARY KEY (actor_user_id, idempotency_key),
  CONSTRAINT p6_idempotency_store_fk FOREIGN KEY (
    store_id, organization_id, organization_type
  ) REFERENCES public.stores (id, organization_id, organization_type),
  CONSTRAINT p6_idempotency_type_check CHECK (organization_type = 'merchant'),
  CONSTRAINT p6_idempotency_operation_check CHECK (
    operation_code IN ('merchant_order.advance', 'after_sale.open',
      'after_sale.review')
  ),
  CONSTRAINT p6_idempotency_fingerprint_check CHECK (
    request_fingerprint ~ '^[0-9a-f]{32}$'
  ),
  CONSTRAINT p6_idempotency_status_check CHECK (
    result_status IN ('accepted', 'rejected', 'shipped', 'completed',
      'opened', 'reviewing', 'resolved')
  ),
  CONSTRAINT p6_idempotency_version_check CHECK (result_version > 0),
  CONSTRAINT p6_idempotency_reference_check CHECK (
    result_reference IS NULL
    OR result_reference ~ '^synthetic://shipment/[a-z0-9][a-z0-9/_-]{2,120}$'
  ),
  CONSTRAINT p6_idempotency_batch_result_check CHECK (
    (operation_code = 'merchant_order.advance'
      AND result_batch_status IN ('confirmed', 'processing', 'completed', 'cancelled')
      AND result_batch_inventory_status IN ('reserved', 'mixed', 'sold', 'released')
      AND result_batch_version > 0)
    OR (operation_code <> 'merchant_order.advance'
      AND result_batch_status IS NULL
      AND result_batch_inventory_status IS NULL
      AND result_batch_version IS NULL)
  ),
  CONSTRAINT p6_idempotency_resolution_result_check CHECK (
    (operation_code = 'after_sale.review' AND (
      (result_status = 'reviewing' AND result_resolution_code IS NULL
        AND result_resolved_at IS NULL)
      OR (result_status = 'resolved'
        AND result_resolution_code IN ('replacement_recorded',
          'return_recorded', 'no_action_recorded')
        AND result_resolved_at IS NOT NULL)
      OR (result_status = 'rejected'
        AND result_resolution_code = 'request_rejected'
        AND result_resolved_at IS NOT NULL)))
    OR (operation_code <> 'after_sale.review'
      AND result_resolution_code IS NULL AND result_resolved_at IS NULL)
  )
);
CREATE INDEX p6_idempotency_store_org_type_idx
  ON public.p6_idempotency_keys (store_id, organization_id, organization_type);
CREATE INDEX p6_idempotency_target_idx
  ON public.p6_idempotency_keys (target_id);

ALTER TABLE public.merchant_after_sale_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_after_sale_cases FORCE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_operation_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_operation_events FORCE ROW LEVEL SECURITY;
ALTER TABLE public.p6_idempotency_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.p6_idempotency_keys FORCE ROW LEVEL SECURITY;

DROP POLICY order_batches_p5_all ON public.order_batches;
CREATE POLICY order_batches_p5_all
  ON public.order_batches FOR ALL TO rebuy_business_executor
  USING (
    ((SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND buyer_user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p5.actor_user_id', true))
      AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
        OR (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_list'))
    OR ((SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p6.batch_id', true))
        OR ((SELECT pg_catalog.current_setting('rebuy.p6.op', true)) IN (
            'order_list', 'after_sale_list'
          )
          AND EXISTS (
            SELECT 1 FROM public.merchant_orders AS mo
            WHERE mo.batch_id = order_batches.id
              AND mo.organization_id::text = (SELECT pg_catalog.current_setting(
                'rebuy.p6.organization_id', true))
              AND mo.store_id::text = (SELECT pg_catalog.current_setting(
                'rebuy.p6.store_id', true))
          ))))
  ) WITH CHECK (
    ((SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND buyer_user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p5.actor_user_id', true))
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true)))
    OR ((SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p6.batch_id', true)))
  );

DROP POLICY merchant_orders_p5_all ON public.merchant_orders;
CREATE POLICY merchant_orders_p5_all
  ON public.merchant_orders FOR ALL TO rebuy_business_executor
  USING (
    ((SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND buyer_user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p5.actor_user_id', true))
      AND (batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
        OR (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_list'))
    OR ((SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'order_advance'
      AND batch_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.batch_id', true)))
    OR ((SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND organization_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.organization_id', true))
      AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p6.store_id', true))
      AND (id::text = (SELECT pg_catalog.current_setting(
          'rebuy.p6.merchant_order_id', true))
        OR (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) IN (
          'dashboard', 'order_list', 'after_sale_list', 'audit_list'
        )))
  ) WITH CHECK (
    ((SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND buyer_user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p5.actor_user_id', true))
      AND batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true)))
    OR ((SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND organization_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.organization_id', true))
      AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p6.store_id', true))
      AND id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.merchant_order_id', true)))
  );

DROP POLICY order_items_p5_all ON public.order_items;
CREATE POLICY order_items_p5_all
  ON public.order_items FOR ALL TO rebuy_business_executor
  USING (
    ((SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND buyer_user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p5.actor_user_id', true))
      AND (batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
        OR (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_list'))
    OR ((SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND organization_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.organization_id', true))
      AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p6.store_id', true))
      AND (merchant_order_id::text = (SELECT pg_catalog.current_setting(
          'rebuy.p6.merchant_order_id', true))
        OR (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'order_list'))
  ) WITH CHECK (
    ((SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND buyer_user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p5.actor_user_id', true))
      AND batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true)))
    OR ((SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND organization_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.organization_id', true))
      AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p6.store_id', true))
      AND merchant_order_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.merchant_order_id', true)))
  );

DROP POLICY order_events_p5_all ON public.order_events;
CREATE POLICY order_events_p5_all
  ON public.order_events FOR ALL TO rebuy_business_executor
  USING (
    ((SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND buyer_user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p5.actor_user_id', true))
      AND (batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
        OR (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_list'))
    OR ((SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND EXISTS (
        SELECT 1 FROM public.merchant_orders AS mo
        WHERE mo.id = order_events.merchant_order_id
          AND mo.batch_id = order_events.batch_id
          AND mo.organization_id::text = (SELECT pg_catalog.current_setting(
            'rebuy.p6.organization_id', true))
          AND mo.store_id::text = (SELECT pg_catalog.current_setting(
            'rebuy.p6.store_id', true))
      )
      AND (merchant_order_id::text = (SELECT pg_catalog.current_setting(
          'rebuy.p6.merchant_order_id', true))
        OR (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) IN (
          'order_list', 'audit_list'
        )))
  ) WITH CHECK (
    ((SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND buyer_user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p5.actor_user_id', true))
      AND actor_user_id = buyer_user_id
      AND batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p5.batch_id', true))
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p5.event_id', true)))
    OR ((SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND actor_user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.actor_user_id', true))
      AND batch_id::text = (SELECT pg_catalog.current_setting('rebuy.p6.batch_id', true))
      AND merchant_order_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.merchant_order_id', true))
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p6.event_id', true)))
  );

CREATE POLICY merchant_after_sale_p6_all
  ON public.merchant_after_sale_cases FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
    AND organization_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.organization_id', true))
    AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p6.store_id', true))
    AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p6.case_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) IN (
        'dashboard', 'after_sale_open', 'after_sale_list'
      ))
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
    AND organization_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.organization_id', true))
    AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p6.store_id', true))
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p6.case_id', true))
  );

CREATE POLICY merchant_operation_events_p6_all
  ON public.merchant_operation_events FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
    AND organization_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.organization_id', true))
    AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p6.store_id', true))
    AND (id::text = (SELECT pg_catalog.current_setting('rebuy.p6.operation_event_id', true))
      OR (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) IN (
        'dashboard', 'audit_list'
      ))
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
    AND organization_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.organization_id', true))
    AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p6.store_id', true))
    AND actor_user_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.actor_user_id', true))
    AND actor_membership_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.membership_id', true))
    AND id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.operation_event_id', true))
  );

CREATE POLICY p6_idempotency_keys_p6_all
  ON public.p6_idempotency_keys FOR ALL TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
    AND actor_user_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.actor_user_id', true))
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
    AND actor_user_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.actor_user_id', true))
    AND organization_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.organization_id', true))
    AND store_id::text = (SELECT pg_catalog.current_setting('rebuy.p6.store_id', true))
  );

-- Audit reads need a relation-wide path so filtering/sorting/limiting happens
-- before rows are materialized. Extend the existing single permissive policy
-- per table/action; the P6 branch is read-only because WITH CHECK remains P4-only.
DROP POLICY catalog_events_p4_all ON public.catalog_events;
CREATE POLICY catalog_events_p4_all
  ON public.catalog_events FOR ALL TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND listing_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p4.listing_id', true))
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'audit_list'
      AND organization_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.organization_id', true))
      AND store_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.store_id', true))
    )
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.event_id', true))
    AND actor_user_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p4.actor_user_id', true))
  );

DROP POLICY inventory_events_p4_all ON public.inventory_events;
CREATE POLICY inventory_events_p4_all
  ON public.inventory_events FOR ALL TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
      AND listing_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p4.listing_id', true))
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p6.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'audit_list'
      AND organization_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.organization_id', true))
      AND store_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.store_id', true))
    )
  ) WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.p4.authorized', true)) = 'true'
    AND id::text = (SELECT pg_catalog.current_setting('rebuy.p4.event_id', true))
    AND actor_user_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p4.actor_user_id', true))
  );

-- Mutation authorization rows are held with SHARE locks until commit. Extend
-- the existing permissive UPDATE policies instead of adding parallel policies;
-- the P6 branch never passes WITH CHECK and therefore cannot update a row.
DROP POLICY stores_business_p4_update ON public.stores;
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
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'authorization_lock'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p6.store_id', true))
      AND organization_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.organization_id', true))
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
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'authorization_lock'
      AND id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.organization_id', true))
    )
  )
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (SELECT pg_catalog.current_setting(
      'rebuy.business.organization_id', true))
    AND status = 'suspended'
  );

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
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'authorization_lock'
      AND id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.membership_id', true))
      AND user_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.actor_user_id', true))
    )
  )
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND id::text = (SELECT pg_catalog.current_setting(
      'rebuy.business.owner_membership_id', true))
    AND status = 'suspended'
  );

DROP POLICY role_definitions_p5_pricing_lock ON public.role_definitions;
CREATE POLICY role_definitions_p5_pricing_lock
  ON public.role_definitions FOR UPDATE TO rebuy_business_executor
  USING (
    (
      (SELECT pg_catalog.current_setting('rebuy.p5.authorized', true)) = 'true'
      AND (SELECT pg_catalog.current_setting('rebuy.p5.op', true)) = 'order_checkout'
      AND role_key = 'owner' AND scope_type = 'organization'
      AND status = 'active' AND is_system
      AND applicable_organization_type IN ('any', 'wholesale')
    )
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'authorization_lock'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p6.role_id', true))
      AND version::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.role_version', true))
    )
  )
  WITH CHECK (false);

CREATE POLICY permissions_p6_authorization_lock
  ON public.permissions FOR UPDATE TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'authorization_lock'
    AND id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.permission_id', true))
  ) WITH CHECK (false);
CREATE POLICY role_permissions_p6_authorization_lock
  ON public.role_permissions FOR UPDATE TO rebuy_business_executor
  USING (
    (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'authorization_lock'
    AND role_definition_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.role_id', true))
    AND role_version::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.role_version', true))
    AND permission_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.p6.permission_id', true))
  ) WITH CHECK (false);
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
    OR (
      (SELECT pg_catalog.current_setting('rebuy.p6.op', true)) = 'authorization_lock'
      AND id::text = (SELECT pg_catalog.current_setting('rebuy.p6.scope_id', true))
      AND membership_id::text = (SELECT pg_catalog.current_setting(
        'rebuy.p6.membership_id', true))
    )
  )
  WITH CHECK (
    (SELECT pg_catalog.current_setting('rebuy.business.authorized', true)) = 'true'
    AND (SELECT pg_catalog.current_setting('rebuy.business.op', true)) = 'review_application'
    AND membership_id::text = (SELECT pg_catalog.current_setting(
      'rebuy.business.owner_membership_id', true))
    AND status = 'suspended'
  );

GRANT UPDATE (status) ON TABLE public.stores, public.organizations,
  public.memberships, public.role_definitions, public.membership_store_scopes
  TO rebuy_business_executor;
GRANT UPDATE (is_active) ON TABLE public.permissions TO rebuy_business_executor;
GRANT UPDATE (is_granted) ON TABLE public.role_permissions
  TO rebuy_business_executor;

REVOKE ALL PRIVILEGES ON TABLE public.merchant_after_sale_cases,
  public.merchant_operation_events, public.p6_idempotency_keys
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
GRANT SELECT, INSERT ON TABLE public.merchant_after_sale_cases
  TO rebuy_business_executor;
GRANT UPDATE (status, resolution_code, version, updated_at, resolved_at)
  ON TABLE public.merchant_after_sale_cases TO rebuy_business_executor;
GRANT SELECT, INSERT ON TABLE public.merchant_operation_events,
  public.p6_idempotency_keys TO rebuy_business_executor;
GRANT UPDATE (synthetic_shipment_reference, accepted_at, shipped_at, completed_at)
  ON TABLE public.merchant_orders TO rebuy_business_executor;

CREATE OR REPLACE FUNCTION private.rebuy_p6_clear_context()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$
BEGIN
  PERFORM pg_catalog.set_config('rebuy.p6.authorized', 'false', true);
  PERFORM pg_catalog.set_config('rebuy.p6.op', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.actor_user_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.membership_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.role_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.role_version', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.permission_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.scope_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.organization_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.store_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.batch_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.merchant_order_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.case_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.event_id', '', true);
  PERFORM pg_catalog.set_config('rebuy.p6.operation_event_id', '', true);
END
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_p6_reset_context()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$
BEGIN
  PERFORM private.rebuy_p5_reset_context();
  PERFORM private.rebuy_p6_clear_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_p6_lock_actor_key(
  p_idempotency_key uuid
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$
DECLARE v_uid uuid;
BEGIN
  PERFORM private.rebuy_p6_reset_context();
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(true) AS i;
  IF p_idempotency_key IS NULL
  THEN RAISE EXCEPTION 'p6_idempotency_key_invalid'; END IF;
  -- P6 inventory delegates to the P4 mutation surface. Acquire the shared P4
  -- actor/key namespace before any authorization or target-row lock so a
  -- same-key P4 catalog call cannot form a key/row lock cycle.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p4-idempotency', 0));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_uid::text || ':' || p_idempotency_key::text || ':p6-idempotency', 0));
  RETURN v_uid;
END
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_p6_authorize_store(
  p_store_id uuid,
  p_permission_key text,
  p_require_recent_identity boolean
)
RETURNS TABLE (
  user_id uuid, membership_id uuid, organization_id uuid,
  store_id uuid, store_name text
)
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_store record; v_membership_id uuid;
  v_membership record; v_role record; v_permission_id uuid; v_scope_id uuid;
BEGIN
  PERFORM private.rebuy_p6_reset_context();
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(p_require_recent_identity) AS i;
  IF p_store_id IS NULL OR p_permission_key IS NULL
     OR p_permission_key !~ '^[a-z][a-z0-9_.-]*$'
  THEN RAISE EXCEPTION 'merchant_context_invalid'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
  PERFORM pg_catalog.set_config('rebuy.p6.actor_user_id', v_uid::text, true);
  PERFORM pg_catalog.set_config('rebuy.p6.store_id', p_store_id::text, true);
  SELECT s.id, s.organization_id, s.display_name INTO v_store
  FROM public.stores AS s
  WHERE s.id = p_store_id AND s.organization_type = 'merchant';
  IF v_store.id IS NULL THEN RAISE EXCEPTION 'merchant_store_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p6.organization_id',
    v_store.organization_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.organization_id',
    v_store.organization_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.store_id', v_store.id::text, true);
  IF p_require_recent_identity THEN
    PERFORM pg_catalog.set_config('rebuy.p6.op', 'authorization_lock', true);
    -- Match P3 suspension order: organization, then store. The first store
    -- read only resolves the organization; both control rows are revalidated
    -- while locked before membership authorization proceeds.
    PERFORM 1 FROM public.organizations AS o
    WHERE o.id = v_store.organization_id AND o.organization_type = 'merchant'
      AND o.status = 'active'
    FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'merchant_store_not_available'; END IF;
    SELECT s.id, s.organization_id, s.display_name INTO v_store
    FROM public.stores AS s
    WHERE s.id = p_store_id AND s.organization_id = v_store.organization_id
      AND s.organization_type = 'merchant' AND s.status = 'active'
    FOR SHARE;
    IF v_store.id IS NULL THEN RAISE EXCEPTION 'merchant_store_not_available'; END IF;
  ELSE
    PERFORM 1 FROM public.organizations AS o
    WHERE o.id = v_store.organization_id AND o.organization_type = 'merchant'
      AND o.status = 'active';
    IF NOT FOUND THEN RAISE EXCEPTION 'merchant_store_not_available'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.stores AS s
      WHERE s.id = v_store.id AND s.organization_id = v_store.organization_id
        AND s.organization_type = 'merchant' AND s.status = 'active')
    THEN RAISE EXCEPTION 'merchant_store_not_available'; END IF;
  END IF;
  v_membership_id := private.rebuy_p4_find_merchant_membership(
    v_uid, v_store.organization_id, v_store.id, p_permission_key
  );
  IF v_membership_id IS NULL THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
  IF p_require_recent_identity THEN
    PERFORM pg_catalog.set_config('rebuy.p6.membership_id',
      v_membership_id::text, true);
    SELECT m.id, m.role_definition_id, m.role_version INTO v_membership
    FROM public.memberships AS m
    WHERE m.id = v_membership_id AND m.user_id = v_uid
      AND m.organization_id = v_store.organization_id
      AND m.organization_type = 'merchant' AND m.status = 'active'
      AND m.valid_from <= pg_catalog.statement_timestamp()
      AND (m.valid_until IS NULL OR m.valid_until > pg_catalog.statement_timestamp())
    FOR SHARE;
    IF v_membership.id IS NULL
    THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p6.role_id',
      v_membership.role_definition_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p6.role_version',
      v_membership.role_version::text, true);
    SELECT rd.id, rd.version, rd.scope_type INTO v_role
    FROM public.role_definitions AS rd
    WHERE rd.id = v_membership.role_definition_id
      AND rd.version = v_membership.role_version AND rd.status = 'active'
      AND rd.applicable_organization_type IN ('any', 'merchant')
    FOR SHARE;
    IF v_role.id IS NULL THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
    SELECT p.id INTO v_permission_id FROM public.permissions AS p
    WHERE p.permission_key = p_permission_key AND p.is_active;
    IF v_permission_id IS NULL
    THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p6.permission_id',
      v_permission_id::text, true);
    PERFORM 1 FROM public.permissions AS p
    WHERE p.id = v_permission_id AND p.permission_key = p_permission_key
      AND p.is_active
    FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
    PERFORM 1 FROM public.role_permissions AS rp
    WHERE rp.role_definition_id = v_role.id AND rp.role_version = v_role.version
      AND rp.permission_id = v_permission_id AND rp.is_granted
    FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
    SELECT s.id INTO v_scope_id FROM public.membership_store_scopes AS s
    WHERE s.membership_id = v_membership.id
      AND s.organization_id = v_store.organization_id
      AND s.organization_type = 'merchant' AND s.status = 'active'
      AND ((v_role.scope_type = 'organization'
          AND s.scope_type = 'organization' AND s.store_id IS NULL)
        OR (v_role.scope_type = 'store'
          AND s.scope_type = 'store' AND s.store_id = v_store.id))
    ORDER BY s.id LIMIT 1;
    IF v_scope_id IS NULL THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p6.scope_id', v_scope_id::text, true);
    PERFORM 1 FROM public.membership_store_scopes AS s
    WHERE s.id = v_scope_id AND s.membership_id = v_membership.id
      AND s.organization_id = v_store.organization_id
      AND s.organization_type = 'merchant' AND s.status = 'active'
      AND ((v_role.scope_type = 'organization'
          AND s.scope_type = 'organization' AND s.store_id IS NULL)
        OR (v_role.scope_type = 'store'
          AND s.scope_type = 'store' AND s.store_id = v_store.id))
    FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
  END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
  PERFORM pg_catalog.set_config('rebuy.p6.membership_id', v_membership_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p6.authorized', 'true', true);
  RETURN QUERY SELECT v_uid, v_membership_id, v_store.organization_id,
    v_store.id, v_store.display_name;
END
$function$;

-- Order termination must remain possible after catalog visibility is withdrawn.
-- This P6-only primitive preserves P4 event/key/version semantics but exposes
-- only release and sell; initial reserve continues through the stricter P4 path.
CREATE OR REPLACE FUNCTION private.rebuy_p6_change_order_inventory_impl(
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
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(true) AS i;
  IF p_listing_id IS NULL OR p_idempotency_key IS NULL
     OR p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 1000000
     OR p_action IS NULL OR p_action NOT IN ('release', 'sell')
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
      PERFORM pg_catalog.set_config('rebuy.p4.inventory_id',
        v_key.inventory_id::text, true);
      RETURN QUERY SELECT p_listing_id, 'standard'::text, v_key.result_status,
        v_key.result_available, v_key.result_version;
      RETURN;
    END IF;
    PERFORM pg_catalog.set_config('rebuy.p4.unit_id',
      v_key.secondhand_unit_id::text, true);
    RETURN QUERY SELECT p_listing_id, 'secondhand'::text, v_key.result_status,
      v_key.result_available, v_key.result_version;
    RETURN;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_listing_id::text, 0));
  SELECT l.* INTO v_listing FROM public.listings AS l
  WHERE l.id = p_listing_id;
  IF v_listing.id IS NULL THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.organization_id',
    v_listing.organization_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.store_id',
    v_listing.store_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.product_id',
    v_listing.product_id::text, true);
  PERFORM pg_catalog.set_config('rebuy.p4.variant_id',
    v_listing.variant_id::text, true);
  IF v_listing.product_kind = 'standard' THEN
    SELECT il.* INTO v_inventory FROM public.inventory_levels AS il
    WHERE il.listing_id = p_listing_id FOR UPDATE;
    IF v_inventory.id IS NULL THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p4.inventory_id',
      v_inventory.id::text, true);
    IF v_inventory.version <> p_expected_version
    THEN RAISE EXCEPTION 'inventory_version_conflict'; END IF;
    IF p_action = 'release' THEN
      IF v_inventory.reserved < p_quantity
      THEN RAISE EXCEPTION 'inventory_quantity_conflict'; END IF;
      UPDATE public.inventory_levels AS il
      SET reserved = il.reserved - p_quantity, version = il.version + 1,
        updated_at = v_now WHERE il.id = v_inventory.id;
      v_event_code := 'inventory.released'; v_result_status := 'released';
    ELSE
      IF v_inventory.reserved < p_quantity OR v_inventory.on_hand < p_quantity
      THEN RAISE EXCEPTION 'inventory_quantity_conflict'; END IF;
      UPDATE public.inventory_levels AS il
      SET on_hand = il.on_hand - p_quantity,
        reserved = il.reserved - p_quantity, version = il.version + 1,
        updated_at = v_now WHERE il.id = v_inventory.id;
      v_event_code := 'inventory.sold'; v_result_status := 'sold';
    END IF;
    v_result_version := v_inventory.version + 1;
    SELECT il.on_hand - il.reserved INTO v_available
    FROM public.inventory_levels AS il WHERE il.id = v_inventory.id;
    PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
    INSERT INTO public.inventory_events (
      id, actor_user_id, organization_id, organization_type, store_id,
      listing_id, inventory_id, event_code, quantity_delta, reserved_delta,
      from_version, to_version, idempotency_key, request_fingerprint, created_at
    ) VALUES (
      v_event_id, v_uid, v_listing.organization_id, 'merchant',
      v_listing.store_id, p_listing_id, v_inventory.id, v_event_code,
      CASE WHEN p_action = 'sell' THEN -p_quantity ELSE 0 END,
      -p_quantity,
      v_inventory.version, v_result_version, p_idempotency_key,
      v_fingerprint, v_now
    );
    INSERT INTO public.p4_idempotency_keys (
      actor_user_id, idempotency_key, operation_code, target_id,
      request_fingerprint, result_status, result_version, result_on_hand,
      result_reserved, result_available, organization_id, listing_id,
      inventory_id, created_at
    ) VALUES (
      v_uid, p_idempotency_key, v_operation, p_listing_id, v_fingerprint,
      v_result_status, v_result_version,
      CASE WHEN p_action = 'sell' THEN v_inventory.on_hand - p_quantity
        ELSE v_inventory.on_hand END,
      v_inventory.reserved - p_quantity,
      v_available, v_listing.organization_id, p_listing_id,
      v_inventory.id, v_now
    );
    RETURN QUERY SELECT p_listing_id, 'standard'::text, v_result_status,
      v_available, v_result_version;
    RETURN;
  END IF;
  IF v_listing.product_kind <> 'secondhand'
  THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
  IF p_quantity <> 1 THEN RAISE EXCEPTION 'secondhand_quantity_must_be_one'; END IF;
  SELECT su.* INTO v_unit FROM public.secondhand_units AS su
  WHERE su.listing_id = p_listing_id FOR UPDATE;
  IF v_unit.id IS NULL THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.unit_id', v_unit.id::text, true);
  IF v_unit.version <> p_expected_version
  THEN RAISE EXCEPTION 'inventory_version_conflict'; END IF;
  IF p_action = 'release' AND v_unit.status = 'reserved' THEN
    v_result_status := 'available'; v_event_code := 'secondhand.released';
  ELSIF p_action = 'sell' AND v_unit.status = 'reserved' THEN
    v_result_status := 'sold'; v_event_code := 'secondhand.sold';
  ELSE RAISE EXCEPTION 'secondhand_state_conflict'; END IF;
  UPDATE public.secondhand_units AS su
  SET status = v_result_status, version = su.version + 1, updated_at = v_now
  WHERE su.id = v_unit.id;
  v_result_version := v_unit.version + 1;
  v_available := CASE WHEN v_result_status = 'available' THEN 1 ELSE 0 END;
  PERFORM pg_catalog.set_config('rebuy.p4.event_id', v_event_id::text, true);
  INSERT INTO public.inventory_events (
    id, actor_user_id, organization_id, organization_type, store_id,
    listing_id, secondhand_unit_id, event_code, quantity_delta,
    reserved_delta, from_version, to_version, idempotency_key,
    request_fingerprint, created_at
  ) VALUES (
    v_event_id, v_uid, v_listing.organization_id, 'merchant',
    v_listing.store_id, p_listing_id, v_unit.id, v_event_code, 0,
    -1,
    v_unit.version, v_result_version, p_idempotency_key, v_fingerprint, v_now
  );
  INSERT INTO public.p4_idempotency_keys (
    actor_user_id, idempotency_key, operation_code, target_id,
    request_fingerprint, result_status, result_version, result_available,
    organization_id, listing_id, secondhand_unit_id, created_at
  ) VALUES (
    v_uid, p_idempotency_key, v_operation, p_listing_id, v_fingerprint,
    v_result_status, v_result_version, v_available,
    v_listing.organization_id, p_listing_id, v_unit.id, v_now
  );
  RETURN QUERY SELECT p_listing_id, 'secondhand'::text, v_result_status,
    v_available, v_result_version;
END
$function$;

CREATE OR REPLACE FUNCTION private.cancel_my_order_batch_p6_impl(
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
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(true) AS i;
  IF p_batch_id IS NULL OR p_expected_version IS NULL
     OR p_expected_version < 1 OR p_idempotency_key IS NULL
  THEN RAISE EXCEPTION 'order_cancel_invalid'; END IF;
  v_fingerprint := pg_catalog.md5(
    p_batch_id::text || '|' || p_expected_version::text);
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
  IF v_batch.version <> p_expected_version
  THEN RAISE EXCEPTION 'order_version_conflict'; END IF;
  PERFORM 1 FROM public.merchant_orders AS mo
  WHERE mo.batch_id = p_batch_id ORDER BY mo.id FOR UPDATE;
  IF v_batch.status <> 'confirmed' OR v_batch.inventory_status <> 'reserved'
     OR EXISTS (SELECT 1 FROM public.merchant_orders AS mo
       WHERE mo.batch_id = p_batch_id AND mo.status <> 'pending')
  THEN RAISE EXCEPTION 'order_cancel_not_allowed'; END IF;
  FOR v_item IN SELECT oi.* FROM public.order_items AS oi
    WHERE oi.batch_id = p_batch_id ORDER BY oi.listing_id FOR UPDATE
  LOOP
    PERFORM pg_catalog.set_config('rebuy.p5.listing_id',
      v_item.listing_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
    PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
    PERFORM pg_catalog.set_config('rebuy.p4.listing_id',
      v_item.listing_id::text, true);
    IF v_item.product_kind = 'standard' THEN
      SELECT il.version INTO v_inventory_version
      FROM public.inventory_levels AS il
      WHERE il.listing_id = v_item.listing_id;
    ELSE
      SELECT su.version INTO v_inventory_version
      FROM public.secondhand_units AS su
      WHERE su.listing_id = v_item.listing_id;
    END IF;
    IF v_inventory_version IS NULL
    THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
    SELECT r.inventory_version INTO v_released_version
    FROM private.rebuy_p6_change_order_inventory_impl(
      v_item.listing_id, v_item.quantity, 'release', v_inventory_version,
      v_batch.synthetic_order_reference,
      private.rebuy_p5_derived_uuid(p_idempotency_key,
        'release:' || v_item.listing_id::text)
    ) AS r;
    UPDATE public.order_items AS oi
    SET inventory_status = 'released', inventory_version = v_released_version,
      updated_at = v_now WHERE oi.id = v_item.id;
  END LOOP;
  UPDATE public.merchant_orders AS mo
  SET status = 'cancelled', inventory_status = 'released',
    version = mo.version + 1, updated_at = v_now
  WHERE mo.batch_id = p_batch_id;
  UPDATE public.order_batches AS ob
  SET status = 'cancelled', inventory_status = 'released',
    version = ob.version + 1, cancelled_at = v_now, updated_at = v_now
  WHERE ob.id = p_batch_id;
  PERFORM pg_catalog.set_config('rebuy.p5.event_id', v_event_id::text, true);
  INSERT INTO public.order_events (
    id, batch_id, buyer_user_id, actor_user_id, event_code, reason_code,
    from_status, to_status, from_version, to_version, idempotency_key,
    request_fingerprint, created_at
  ) VALUES (
    v_event_id, p_batch_id, v_uid, v_uid, 'order.cancelled',
    'buyer_cancelled_before_fulfillment', 'confirmed', 'cancelled',
    v_batch.version, v_batch.version + 1, p_idempotency_key,
    v_fingerprint, v_now
  );
  INSERT INTO public.p5_idempotency_keys (
    actor_user_id, idempotency_key, operation_code, request_fingerprint,
    batch_id, result_status, result_version, result_inventory_status,
    result_cancelled_at
  ) VALUES (
    v_uid, p_idempotency_key, 'order.cancel', v_fingerprint, p_batch_id,
    'cancelled', v_batch.version + 1, 'released', v_now
  );
  RETURN QUERY SELECT p_batch_id, 'cancelled'::text, 'released'::text,
    v_batch.version + 1, v_now;
  PERFORM private.rebuy_p5_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.adjust_my_merchant_inventory_impl(
  p_store_id uuid,
  p_listing_id uuid,
  p_quantity_delta integer,
  p_reason_code text,
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
  v_auth record; v_result record; v_existing record;
  v_listing record; v_uid uuid; v_event_id uuid; v_fingerprint text;
BEGIN
  IF p_listing_id IS NULL OR p_idempotency_key IS NULL
     OR p_quantity_delta IS NULL OR p_quantity_delta = 0
     OR p_quantity_delta NOT BETWEEN -1000000 AND 1000000
     OR p_expected_version IS NULL OR p_expected_version < 1
     OR p_reason_code IS NULL
     OR p_reason_code NOT IN ('stock_received', 'stock_correction', 'cycle_count')
  THEN RAISE EXCEPTION 'merchant_inventory_adjust_invalid'; END IF;
  v_uid := private.rebuy_p6_lock_actor_key(p_idempotency_key);
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'inventory.adjust', true
  );
  IF v_auth.user_id IS DISTINCT FROM v_uid
  THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p4.listing_id', p_listing_id::text, true);
  SELECT l.organization_id, l.store_id INTO v_listing
  FROM public.listings AS l
  WHERE l.id = p_listing_id
    AND l.organization_id = v_auth.organization_id
    AND l.store_id = v_auth.store_id
    AND l.organization_type = 'merchant'
  FOR SHARE;
  IF v_listing.organization_id IS NULL
  THEN RAISE EXCEPTION 'merchant_inventory_scope_forbidden'; END IF;
  v_event_id := private.rebuy_p5_derived_uuid(
    p_idempotency_key, 'p6-operation:' || v_uid::text);
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|',
    p_store_id::text, p_listing_id::text, p_quantity_delta::text,
    p_reason_code, p_expected_version::text));
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'inventory_adjust', true);
  PERFORM pg_catalog.set_config('rebuy.p6.operation_event_id',
    v_event_id::text, true);
  SELECT e.* INTO v_existing FROM public.merchant_operation_events AS e
  WHERE e.id = v_event_id;
  IF v_existing.id IS NOT NULL AND (
       v_existing.entity_type IS DISTINCT FROM 'inventory'
       OR v_existing.entity_id IS DISTINCT FROM p_listing_id
       OR v_existing.event_code IS DISTINCT FROM 'inventory.adjusted'
       OR v_existing.reason_code IS DISTINCT FROM p_reason_code
       OR v_existing.from_version IS DISTINCT FROM p_expected_version
       OR v_existing.request_fingerprint IS DISTINCT FROM v_fingerprint
     )
  THEN RAISE EXCEPTION 'p6_idempotency_conflict'; END IF;
  IF v_existing.id IS NULL AND EXISTS (
    SELECT 1 FROM public.p6_idempotency_keys AS k
    WHERE k.actor_user_id = v_uid
      AND k.idempotency_key = p_idempotency_key
  ) THEN RAISE EXCEPTION 'p6_idempotency_conflict'; END IF;
  SELECT * INTO v_result FROM private.adjust_inventory_impl(
    p_listing_id, p_quantity_delta, p_expected_version, p_idempotency_key
  );
  IF v_result.listing_id IS NULL
  THEN RAISE EXCEPTION 'merchant_inventory_adjust_unavailable'; END IF;
  IF v_existing.id IS NULL THEN
    PERFORM pg_catalog.set_config('rebuy.p6.op', 'inventory_adjust', true);
    PERFORM pg_catalog.set_config('rebuy.p6.operation_event_id',
      v_event_id::text, true);
    INSERT INTO public.merchant_operation_events (
      id, organization_id, store_id, actor_user_id, actor_membership_id,
      entity_type, entity_id, event_code, reason_code, from_status,
      to_status, from_version, to_version, idempotency_key,
      request_fingerprint
    ) VALUES (
      v_event_id, v_auth.organization_id, v_auth.store_id, v_auth.user_id,
      v_auth.membership_id, 'inventory', p_listing_id, 'inventory.adjusted',
      p_reason_code, NULL, 'adjusted', p_expected_version,
      v_result.inventory_version, p_idempotency_key, v_fingerprint
    );
  END IF;
  RETURN QUERY SELECT v_result.listing_id, v_result.on_hand,
    v_result.reserved, v_result.available, v_result.inventory_version;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.get_my_merchant_context_impl()
RETURNS TABLE (
  store_id uuid, organization_id uuid, store_name text, role_key text,
  membership_id uuid, can_catalog boolean, can_pricing boolean,
  can_inventory boolean, can_fulfill boolean, can_after_sale boolean,
  can_audit boolean
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_uid uuid; v_store record; v_membership_id uuid; v_role_key text;
BEGIN
  PERFORM private.rebuy_p6_reset_context();
  SELECT i.user_id INTO v_uid
  FROM private.rebuy_business_require_identity(false) AS i;
  PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
  PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
  FOR v_store IN
    SELECT s.id, s.organization_id, s.display_name
    FROM public.stores AS s
    JOIN public.organizations AS o
      ON o.id = s.organization_id AND o.organization_type = s.organization_type
    WHERE s.organization_type = 'merchant' AND s.status = 'active'
      AND o.status = 'active'
    ORDER BY s.display_name, s.id
  LOOP
    PERFORM pg_catalog.set_config('rebuy.p4.organization_id',
      v_store.organization_id::text, true);
    PERFORM pg_catalog.set_config('rebuy.p4.store_id', v_store.id::text, true);
    v_membership_id := private.rebuy_p4_find_merchant_membership(
      v_uid, v_store.organization_id, v_store.id, 'merchant.dashboard.read'
    );
    IF v_membership_id IS NULL THEN CONTINUE; END IF;
    SELECT rd.role_key INTO v_role_key
    FROM public.memberships AS m
    JOIN public.role_definitions AS rd
      ON rd.id = m.role_definition_id AND rd.version = m.role_version
    WHERE m.id = v_membership_id AND m.user_id = v_uid;
    store_id := v_store.id;
    organization_id := v_store.organization_id;
    store_name := v_store.display_name;
    role_key := v_role_key;
    membership_id := v_membership_id;
    can_catalog := private.rebuy_p4_find_merchant_membership(
      v_uid, v_store.organization_id, v_store.id, 'catalog.write') IS NOT NULL;
    can_pricing := private.rebuy_p4_find_merchant_membership(
      v_uid, v_store.organization_id, v_store.id, 'pricing.write') IS NOT NULL;
    can_inventory := private.rebuy_p4_find_merchant_membership(
      v_uid, v_store.organization_id, v_store.id, 'inventory.adjust') IS NOT NULL;
    can_fulfill := private.rebuy_p4_find_merchant_membership(
      v_uid, v_store.organization_id, v_store.id,
      'merchant.order.fulfill') IS NOT NULL;
    can_after_sale := private.rebuy_p4_find_merchant_membership(
      v_uid, v_store.organization_id, v_store.id,
      'merchant.after_sale.manage') IS NOT NULL;
    can_audit := private.rebuy_p4_find_merchant_membership(
      v_uid, v_store.organization_id, v_store.id,
      'merchant.audit.read') IS NOT NULL;
    RETURN NEXT;
  END LOOP;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.get_my_merchant_dashboard_impl(p_store_id uuid)
RETURNS TABLE (
  store_id uuid, store_name text, active_listing_count integer,
  low_stock_count integer, pending_order_count integer,
  active_after_sale_count integer, recent_operation_count integer
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_auth record;
BEGIN
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'merchant.dashboard.read', false
  );
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'dashboard', true);
  RETURN QUERY SELECT v_auth.store_id, v_auth.store_name,
    (SELECT pg_catalog.count(*)::integer FROM public.listings AS l
      WHERE l.store_id = v_auth.store_id AND l.status = 'active'),
    (SELECT pg_catalog.count(*)::integer FROM public.listings AS l
      LEFT JOIN public.inventory_levels AS il ON il.listing_id = l.id
      LEFT JOIN public.secondhand_units AS su ON su.listing_id = l.id
      WHERE l.store_id = v_auth.store_id AND l.status = 'active'
        AND ((l.product_kind = 'standard' AND il.on_hand - il.reserved <= 5)
          OR (l.product_kind = 'secondhand' AND su.status <> 'available'))),
    (SELECT pg_catalog.count(*)::integer FROM public.merchant_orders AS mo
      WHERE mo.store_id = v_auth.store_id AND mo.status IN ('pending', 'accepted')),
    (SELECT pg_catalog.count(*)::integer FROM public.merchant_after_sale_cases AS c
      WHERE c.store_id = v_auth.store_id AND c.status IN ('opened', 'reviewing')),
    (SELECT pg_catalog.count(*)::integer FROM public.merchant_operation_events AS e
      WHERE e.store_id = v_auth.store_id
        AND e.created_at >= pg_catalog.statement_timestamp() - interval '7 days');
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.list_my_merchant_products_impl(p_store_id uuid)
RETURNS TABLE (
  listing_id uuid, product_id uuid, variant_id uuid, category_slug text,
  product_kind text, internal_name text, sku text, listing_slug text,
  title text, summary text, listing_status text, listing_version integer,
  retail_cents integer, wholesale_cents integer, wholesale_minimum integer,
  wholesale_tiers jsonb, available_quantity integer, inventory_version integer,
  synthetic_serial_reference text,
  condition_code text, defect_code text, battery_health_percent integer,
  warranty_days integer
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_auth record;
BEGIN
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'catalog.write', false
  );
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'product_list', true);
  RETURN QUERY
  SELECT l.id, l.product_id, l.variant_id, c.slug, l.product_kind,
    p.internal_name, pv.sku, l.slug, l.title, l.summary, l.status, l.version,
    (SELECT lp.unit_amount_cents FROM public.listing_prices AS lp
      WHERE lp.listing_id = l.id AND lp.audience = 'retail'
        AND lp.status = 'active' ORDER BY lp.valid_from DESC, lp.id LIMIT 1),
    (SELECT lp.unit_amount_cents FROM public.listing_prices AS lp
      WHERE lp.listing_id = l.id AND lp.audience = 'wholesale'
        AND lp.status = 'active' ORDER BY lp.valid_from DESC, lp.id LIMIT 1),
    (SELECT lp.minimum_quantity FROM public.listing_prices AS lp
      WHERE lp.listing_id = l.id AND lp.audience = 'wholesale'
        AND lp.status = 'active' ORDER BY lp.valid_from DESC, lp.id LIMIT 1),
    COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'minimum_quantity', t.minimum_quantity,
      'unit_amount_cents', t.unit_amount_cents
    ) ORDER BY t.minimum_quantity)
      FROM public.listing_price_tiers AS t
      JOIN public.listing_prices AS wp ON wp.id = t.price_id
      WHERE t.listing_id = l.id AND wp.status = 'active'
        AND wp.audience = 'wholesale'), '[]'::jsonb),
    CASE WHEN l.product_kind = 'standard' THEN il.on_hand - il.reserved
      WHEN su.status = 'available' THEN 1 ELSE 0 END,
    COALESCE(il.version, su.version), su.synthetic_serial_reference,
    su.condition_code, su.defect_code,
    su.battery_health_percent, su.warranty_days
  FROM public.listings AS l
  JOIN public.products AS p ON p.id = l.product_id
  JOIN public.product_variants AS pv ON pv.id = l.variant_id
  JOIN public.categories AS c ON c.id = p.category_id
  LEFT JOIN public.inventory_levels AS il ON il.listing_id = l.id
  LEFT JOIN public.secondhand_units AS su ON su.listing_id = l.id
  WHERE l.organization_id = v_auth.organization_id
    AND l.store_id = v_auth.store_id
  ORDER BY l.updated_at DESC, l.id;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.list_my_merchant_inventory_impl(p_store_id uuid)
RETURNS TABLE (
  listing_id uuid, title text, sku text, inventory_kind text,
  on_hand integer, reserved integer, available integer,
  unit_status text, inventory_version integer, updated_at timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_auth record;
BEGIN
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'inventory.adjust', false
  );
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'inventory_list', true);
  RETURN QUERY SELECT l.id, l.title, pv.sku, l.product_kind,
    CASE WHEN l.product_kind = 'standard' THEN il.on_hand ELSE 1 END,
    CASE WHEN l.product_kind = 'standard' THEN il.reserved
      WHEN su.status = 'reserved' THEN 1 ELSE 0 END,
    CASE WHEN l.product_kind = 'standard' THEN il.on_hand - il.reserved
      WHEN su.status = 'available' THEN 1 ELSE 0 END,
    su.status, COALESCE(il.version, su.version),
    COALESCE(il.updated_at, su.updated_at)
  FROM public.listings AS l
  JOIN public.product_variants AS pv ON pv.id = l.variant_id
  LEFT JOIN public.inventory_levels AS il ON il.listing_id = l.id
  LEFT JOIN public.secondhand_units AS su ON su.listing_id = l.id
  WHERE l.organization_id = v_auth.organization_id
    AND l.store_id = v_auth.store_id
  ORDER BY l.updated_at DESC, l.id;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.list_my_merchant_orders_impl(p_store_id uuid)
RETURNS TABLE (
  merchant_order_id uuid, batch_id uuid, synthetic_order_reference text,
  order_status text, inventory_status text, currency_code text,
  total_cents integer, order_version integer, item_count integer,
  created_at timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_auth record;
BEGIN
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'merchant.order.fulfill', false
  );
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'order_list', true);
  RETURN QUERY SELECT mo.id, mo.batch_id, ob.synthetic_order_reference,
    mo.status, mo.inventory_status, mo.currency_code, mo.total_cents,
    mo.version, (SELECT pg_catalog.sum(oi.quantity)::integer
      FROM public.order_items AS oi WHERE oi.merchant_order_id = mo.id),
    mo.created_at, mo.updated_at
  FROM public.merchant_orders AS mo
  JOIN public.order_batches AS ob ON ob.id = mo.batch_id
  WHERE mo.organization_id = v_auth.organization_id
    AND mo.store_id = v_auth.store_id
  ORDER BY mo.created_at DESC, mo.id DESC;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.get_my_merchant_order_impl(
  p_store_id uuid, p_merchant_order_id uuid
)
RETURNS TABLE (
  merchant_order_id uuid, batch_id uuid, synthetic_order_reference text,
  order_status text, inventory_status text, synthetic_shipment_reference text,
  currency_code text, total_cents integer, order_version integer,
  listing_id uuid, title_snapshot text, sku_snapshot text,
  product_kind text, quantity integer, audience text,
  unit_amount_cents integer, line_amount_cents integer,
  item_inventory_status text, event_codes jsonb, created_at timestamptz,
  accepted_at timestamptz, shipped_at timestamptz, completed_at timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_auth record; v_order public.merchant_orders%ROWTYPE;
BEGIN
  IF p_merchant_order_id IS NULL THEN
    RAISE EXCEPTION 'merchant_order_invalid';
  END IF;
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'merchant.order.fulfill', false
  );
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'order_detail', true);
  PERFORM pg_catalog.set_config('rebuy.p6.merchant_order_id',
    p_merchant_order_id::text, true);
  SELECT mo.* INTO v_order FROM public.merchant_orders AS mo
  WHERE mo.id = p_merchant_order_id
    AND mo.organization_id = v_auth.organization_id
    AND mo.store_id = v_auth.store_id;
  IF v_order.id IS NULL THEN RAISE EXCEPTION 'merchant_order_not_available'; END IF;
  PERFORM pg_catalog.set_config('rebuy.p6.batch_id', v_order.batch_id::text, true);
  RETURN QUERY SELECT mo.id, mo.batch_id, ob.synthetic_order_reference,
    mo.status, mo.inventory_status, mo.synthetic_shipment_reference,
    mo.currency_code, mo.total_cents, mo.version, oi.listing_id,
    oi.title_snapshot, oi.sku_snapshot, oi.product_kind, oi.quantity,
    oi.audience, oi.unit_amount_cents, oi.line_amount_cents,
    oi.inventory_status,
    COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'event', oe.event_code, 'status', oe.to_status,
      'created_at', oe.created_at
    ) ORDER BY oe.created_at, oe.id)
      FROM public.order_events AS oe
      WHERE oe.merchant_order_id = mo.id), '[]'::jsonb),
    mo.created_at, mo.accepted_at, mo.shipped_at, mo.completed_at
  FROM public.merchant_orders AS mo
  JOIN public.order_batches AS ob ON ob.id = mo.batch_id
  JOIN public.order_items AS oi ON oi.merchant_order_id = mo.id
  WHERE mo.id = v_order.id
  ORDER BY oi.id;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.list_my_merchant_after_sales_impl(p_store_id uuid)
RETURNS TABLE (
  case_id uuid, merchant_order_id uuid, synthetic_order_reference text,
  reason_code text, case_status text, resolution_code text,
  case_version integer, created_at timestamptz, updated_at timestamptz,
  resolved_at timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_auth record;
BEGIN
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'merchant.after_sale.manage', false
  );
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'after_sale_list', true);
  RETURN QUERY SELECT c.id, c.merchant_order_id,
    ob.synthetic_order_reference, c.reason_code, c.status,
    c.resolution_code, c.version, c.created_at, c.updated_at, c.resolved_at
  FROM public.merchant_after_sale_cases AS c
  JOIN public.merchant_orders AS mo ON mo.id = c.merchant_order_id
  JOIN public.order_batches AS ob ON ob.id = c.batch_id
  WHERE c.organization_id = v_auth.organization_id
    AND c.store_id = v_auth.store_id
  ORDER BY c.updated_at DESC, c.id DESC;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.list_my_merchant_audit_impl(
  p_store_id uuid, p_event_prefix text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  event_code text, entity_type text, entity_id uuid, reason_code text,
  from_status text, to_status text, from_version integer,
  to_version integer, created_at timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_auth record;
BEGIN
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100
     OR (p_event_prefix IS NOT NULL
       AND (pg_catalog.char_length(p_event_prefix) > 40
         OR p_event_prefix !~ '^[a-z_]+([.][a-z_]+)?$'))
  THEN RAISE EXCEPTION 'merchant_audit_query_invalid'; END IF;
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'merchant.audit.read', false
  );
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'audit_list', true);
  RETURN QUERY SELECT r.event_code, r.entity_type, r.entity_id,
    r.reason_code, r.from_status, r.to_status, r.from_version,
    r.to_version, r.created_at
  FROM (
    SELECT e.event_code, e.entity_type, e.entity_id, e.reason_code,
      e.from_status, e.to_status, e.from_version, e.to_version, e.created_at
    FROM public.merchant_operation_events AS e
    WHERE e.organization_id = v_auth.organization_id
      AND e.store_id = v_auth.store_id
    UNION ALL
    SELECT e.event_code, 'listing'::text, e.listing_id,
      'catalog_change'::text, NULL::text, e.event_code,
      e.from_version, e.to_version, e.created_at
    FROM public.catalog_events AS e
    WHERE e.organization_id = v_auth.organization_id
      AND e.store_id = v_auth.store_id
    UNION ALL
    SELECT e.event_code, 'inventory'::text, e.listing_id,
      'inventory_change'::text, NULL::text, e.event_code,
      e.from_version, e.to_version, e.created_at
    FROM public.inventory_events AS e
    WHERE e.organization_id = v_auth.organization_id
      AND e.store_id = v_auth.store_id
  ) AS r
  WHERE p_event_prefix IS NULL OR r.event_code LIKE p_event_prefix || '%'
  ORDER BY r.created_at DESC, r.entity_id DESC LIMIT p_limit;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.rebuy_p6_refresh_batch(p_batch_id uuid)
RETURNS TABLE (
  batch_status text, inventory_status text, batch_version integer
)
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$
DECLARE
  v_batch public.order_batches%ROWTYPE;
  v_all_terminal boolean; v_any_completed boolean;
  v_any_progress boolean; v_all_sold boolean;
  v_all_released boolean; v_all_reserved boolean;
  v_status text; v_inventory_status text;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  SELECT ob.* INTO v_batch FROM public.order_batches AS ob
  WHERE ob.id = p_batch_id FOR UPDATE;
  IF v_batch.id IS NULL THEN RAISE EXCEPTION 'merchant_batch_not_available'; END IF;
  SELECT pg_catalog.bool_and(mo.status IN ('completed', 'rejected', 'cancelled')),
    pg_catalog.bool_or(mo.status = 'completed'),
    pg_catalog.bool_or(mo.status IN ('accepted', 'shipped', 'completed', 'rejected')),
    pg_catalog.bool_and(mo.inventory_status = 'sold'),
    pg_catalog.bool_and(mo.inventory_status = 'released'),
    pg_catalog.bool_and(mo.inventory_status = 'reserved')
  INTO v_all_terminal, v_any_completed, v_any_progress,
    v_all_sold, v_all_released, v_all_reserved
  FROM public.merchant_orders AS mo WHERE mo.batch_id = p_batch_id;
  v_status := CASE
    WHEN v_all_terminal AND v_any_completed THEN 'completed'
    WHEN v_all_terminal THEN 'cancelled'
    WHEN v_any_progress THEN 'processing'
    ELSE 'confirmed'
  END;
  v_inventory_status := CASE
    WHEN v_all_sold THEN 'sold'
    WHEN v_all_released THEN 'released'
    WHEN v_all_reserved THEN 'reserved'
    ELSE 'mixed'
  END;
  UPDATE public.order_batches AS ob
  SET status = v_status, inventory_status = v_inventory_status,
    version = ob.version + 1,
    cancelled_at = CASE WHEN v_status = 'cancelled'
      THEN COALESCE(ob.cancelled_at, v_now) ELSE NULL END,
    updated_at = v_now
  WHERE ob.id = p_batch_id;
  RETURN QUERY SELECT v_status, v_inventory_status, v_batch.version + 1;
END
$function$;

CREATE OR REPLACE FUNCTION private.advance_my_merchant_order_impl(
  p_store_id uuid,
  p_merchant_order_id uuid,
  p_action text,
  p_reason_code text,
  p_synthetic_shipment_reference text,
  p_expected_version integer,
  p_idempotency_key uuid
)
RETURNS TABLE (
  merchant_order_id uuid, order_status text, inventory_status text,
  order_version integer, batch_status text, batch_inventory_status text,
  batch_version integer, synthetic_shipment_reference text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_auth record; v_order public.merchant_orders%ROWTYPE;
  v_key public.p6_idempotency_keys%ROWTYPE;
  v_item public.order_items%ROWTYPE; v_batch_result record;
  v_uid uuid; v_membership_id uuid; v_batch_id uuid;
  v_next_status text; v_next_inventory text; v_reason text;
  v_event_code text; v_reference text; v_fingerprint text;
  v_order_reference text;
  v_event_id uuid := pg_catalog.gen_random_uuid();
  v_operation_event_id uuid;
  v_inventory_version integer; v_result_inventory_version integer;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  IF p_merchant_order_id IS NULL OR p_idempotency_key IS NULL
     OR p_expected_version IS NULL OR p_expected_version < 1
     OR p_action IS NULL OR p_action NOT IN ('accept', 'reject', 'ship', 'complete')
  THEN RAISE EXCEPTION 'merchant_order_action_invalid'; END IF;
  IF p_action = 'reject' THEN
    IF p_reason_code IS NULL
       OR p_reason_code NOT IN ('out_of_stock', 'listing_issue')
       OR p_synthetic_shipment_reference IS NOT NULL
    THEN RAISE EXCEPTION 'merchant_order_action_invalid'; END IF;
    v_reason := CASE p_reason_code WHEN 'out_of_stock'
      THEN 'merchant_rejected_out_of_stock'
      ELSE 'merchant_rejected_listing_issue' END;
  ELSIF p_action = 'ship' THEN
    IF p_reason_code IS NOT NULL
       OR p_synthetic_shipment_reference IS NULL
       OR pg_catalog.lower(pg_catalog.btrim(p_synthetic_shipment_reference))
         !~ '^synthetic://shipment/[a-z0-9][a-z0-9/_-]{2,120}$'
    THEN RAISE EXCEPTION 'merchant_order_action_invalid'; END IF;
    v_reason := 'synthetic_shipment_created';
  ELSE
    IF p_reason_code IS NOT NULL OR p_synthetic_shipment_reference IS NOT NULL
    THEN RAISE EXCEPTION 'merchant_order_action_invalid'; END IF;
    v_reason := CASE p_action WHEN 'accept' THEN 'merchant_accepted'
      ELSE 'merchant_completed' END;
  END IF;
  v_reference := CASE WHEN p_action = 'ship'
    THEN pg_catalog.lower(pg_catalog.btrim(p_synthetic_shipment_reference))
    ELSE NULL END;
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|', p_store_id::text,
    p_merchant_order_id::text, p_action, COALESCE(p_reason_code, ''),
    COALESCE(v_reference, ''), p_expected_version::text));
  v_uid := private.rebuy_p6_lock_actor_key(p_idempotency_key);
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'merchant.order.fulfill', true
  );
  IF v_auth.user_id IS DISTINCT FROM v_uid
  THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
  v_membership_id := v_auth.membership_id;
  v_operation_event_id := private.rebuy_p5_derived_uuid(
    p_idempotency_key, 'p6-operation:' || v_uid::text);
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'order_advance', true);
  PERFORM pg_catalog.set_config('rebuy.p6.merchant_order_id',
    p_merchant_order_id::text, true);
  SELECT k.* INTO v_key FROM public.p6_idempotency_keys AS k
  WHERE k.actor_user_id = v_uid AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'merchant_order.advance'
       OR v_key.target_id IS DISTINCT FROM p_merchant_order_id
       OR v_key.organization_id IS DISTINCT FROM v_auth.organization_id
       OR v_key.store_id IS DISTINCT FROM v_auth.store_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p6_idempotency_conflict'; END IF;
    RETURN QUERY SELECT v_key.target_id, v_key.result_status,
      CASE WHEN v_key.result_status IN ('rejected') THEN 'released'
        WHEN v_key.result_status = 'completed' THEN 'sold' ELSE 'reserved' END,
      v_key.result_version, v_key.result_batch_status,
      v_key.result_batch_inventory_status, v_key.result_batch_version,
      v_key.result_reference
    ;
    PERFORM private.rebuy_p6_reset_context();
    RETURN;
  END IF;
  PERFORM pg_catalog.set_config('rebuy.p6.operation_event_id',
    v_operation_event_id::text, true);
  IF EXISTS (SELECT 1 FROM public.merchant_operation_events AS e
    WHERE e.id = v_operation_event_id)
  THEN RAISE EXCEPTION 'p6_idempotency_conflict'; END IF;
  SELECT mo.* INTO v_order FROM public.merchant_orders AS mo
  WHERE mo.id = p_merchant_order_id
    AND mo.organization_id = v_auth.organization_id
    AND mo.store_id = v_auth.store_id;
  IF v_order.id IS NULL THEN RAISE EXCEPTION 'merchant_order_not_available'; END IF;
  v_batch_id := v_order.batch_id;
  PERFORM pg_catalog.set_config('rebuy.p6.batch_id', v_batch_id::text, true);
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_batch_id::text, 0));
  SELECT ob.synthetic_order_reference INTO v_order_reference
  FROM public.order_batches AS ob
  WHERE ob.id = v_batch_id FOR UPDATE;
  PERFORM 1 FROM public.merchant_orders AS mo
    WHERE mo.batch_id = v_batch_id ORDER BY mo.id FOR UPDATE;
  SELECT mo.* INTO v_order FROM public.merchant_orders AS mo
  WHERE mo.id = p_merchant_order_id;
  IF v_order.version <> p_expected_version
  THEN RAISE EXCEPTION 'merchant_order_version_conflict'; END IF;
  IF p_action = 'accept' AND v_order.status = 'pending' THEN
    v_next_status := 'accepted'; v_next_inventory := 'reserved';
  ELSIF p_action = 'reject' AND v_order.status = 'pending' THEN
    v_next_status := 'rejected'; v_next_inventory := 'released';
  ELSIF p_action = 'ship' AND v_order.status = 'accepted' THEN
    v_next_status := 'shipped'; v_next_inventory := 'reserved';
  ELSIF p_action = 'complete' AND v_order.status = 'shipped' THEN
    v_next_status := 'completed'; v_next_inventory := 'sold';
    v_reference := v_order.synthetic_shipment_reference;
  ELSE
    RAISE EXCEPTION 'merchant_order_state_conflict';
  END IF;
  IF p_action IN ('reject', 'complete') THEN
    FOR v_item IN SELECT oi.* FROM public.order_items AS oi
      WHERE oi.merchant_order_id = v_order.id
      ORDER BY oi.listing_id FOR UPDATE
    LOOP
      IF v_item.inventory_status <> 'reserved'
      THEN RAISE EXCEPTION 'merchant_order_inventory_conflict'; END IF;
      PERFORM pg_catalog.set_config('rebuy.p4.authorized', 'true', true);
      PERFORM pg_catalog.set_config('rebuy.p4.op', 'catalog_public', true);
      PERFORM pg_catalog.set_config('rebuy.p4.listing_id',
        v_item.listing_id::text, true);
      IF v_item.product_kind = 'standard' THEN
        SELECT il.version INTO v_inventory_version
        FROM public.inventory_levels AS il WHERE il.listing_id = v_item.listing_id;
      ELSE
        SELECT su.version INTO v_inventory_version
        FROM public.secondhand_units AS su WHERE su.listing_id = v_item.listing_id;
      END IF;
      IF v_inventory_version IS NULL
      THEN RAISE EXCEPTION 'inventory_not_available'; END IF;
      SELECT r.inventory_version INTO v_result_inventory_version
      FROM private.rebuy_p6_change_order_inventory_impl(
        v_item.listing_id, v_item.quantity,
        CASE p_action WHEN 'reject' THEN 'release' ELSE 'sell' END,
        v_inventory_version, v_order_reference,
        private.rebuy_p5_derived_uuid(p_idempotency_key,
          p_action || ':' || v_item.listing_id::text)
      ) AS r;
      UPDATE public.order_items AS oi
      SET inventory_status = v_next_inventory,
        inventory_version = v_result_inventory_version, updated_at = v_now
      WHERE oi.id = v_item.id;
    END LOOP;
  END IF;
  UPDATE public.merchant_orders AS mo
  SET status = v_next_status, inventory_status = v_next_inventory,
    version = mo.version + 1,
    synthetic_shipment_reference = CASE WHEN p_action = 'ship'
      THEN v_reference ELSE mo.synthetic_shipment_reference END,
    accepted_at = CASE WHEN p_action = 'accept' THEN v_now ELSE mo.accepted_at END,
    shipped_at = CASE WHEN p_action = 'ship' THEN v_now ELSE mo.shipped_at END,
    completed_at = CASE WHEN p_action = 'complete' THEN v_now ELSE mo.completed_at END,
    updated_at = v_now
  WHERE mo.id = v_order.id;
  v_event_code := 'merchant_order.' || v_next_status;
  PERFORM pg_catalog.set_config('rebuy.p6.event_id', v_event_id::text, true);
  INSERT INTO public.order_events (
    id, batch_id, merchant_order_id, buyer_user_id, actor_user_id,
    event_code, reason_code, from_status, to_status, from_version,
    to_version, idempotency_key, request_fingerprint, created_at
  ) VALUES (
    v_event_id, v_order.batch_id, v_order.id, v_order.buyer_user_id, v_uid,
    v_event_code, v_reason, v_order.status, v_next_status, v_order.version,
    v_order.version + 1, p_idempotency_key, v_fingerprint, v_now
  );
  PERFORM pg_catalog.set_config('rebuy.p6.operation_event_id',
    v_operation_event_id::text, true);
  INSERT INTO public.merchant_operation_events (
    id, organization_id, store_id, actor_user_id, actor_membership_id,
    entity_type, entity_id, event_code, reason_code, from_status,
    to_status, from_version, to_version, idempotency_key,
    request_fingerprint, created_at
  ) VALUES (
    v_operation_event_id, v_auth.organization_id, v_auth.store_id, v_uid,
    v_membership_id, 'merchant_order', v_order.id, v_event_code, v_reason,
    v_order.status, v_next_status, v_order.version, v_order.version + 1,
    p_idempotency_key, v_fingerprint, v_now
  );
  SELECT * INTO v_batch_result FROM private.rebuy_p6_refresh_batch(v_batch_id);
  INSERT INTO public.p6_idempotency_keys (
    actor_user_id, idempotency_key, operation_code, target_id,
    organization_id, store_id, request_fingerprint, result_status,
    result_version, result_reference, result_id, result_batch_status,
    result_batch_inventory_status, result_batch_version, created_at
  ) VALUES (
    v_uid, p_idempotency_key, 'merchant_order.advance', v_order.id,
    v_auth.organization_id, v_auth.store_id, v_fingerprint, v_next_status,
    v_order.version + 1, v_reference, v_order.id,
    v_batch_result.batch_status, v_batch_result.inventory_status,
    v_batch_result.batch_version, v_now
  );
  RETURN QUERY SELECT v_order.id, v_next_status, v_next_inventory,
    v_order.version + 1, v_batch_result.batch_status,
    v_batch_result.inventory_status, v_batch_result.batch_version, v_reference;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.open_my_merchant_after_sale_impl(
  p_store_id uuid,
  p_merchant_order_id uuid,
  p_reason_code text,
  p_idempotency_key uuid
)
RETURNS TABLE (
  case_id uuid, merchant_order_id uuid, case_status text,
  case_version integer, reason_code text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_auth record; v_order public.merchant_orders%ROWTYPE;
  v_key public.p6_idempotency_keys%ROWTYPE; v_existing_id uuid;
  v_uid uuid; v_case_id uuid; v_fingerprint text;
  v_event_id uuid;
  v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
  IF p_merchant_order_id IS NULL OR p_idempotency_key IS NULL
     OR p_reason_code IS NULL
     OR p_reason_code NOT IN ('return_request', 'damaged', 'wrong_item')
  THEN RAISE EXCEPTION 'after_sale_open_invalid'; END IF;
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|', p_store_id::text,
    p_merchant_order_id::text, p_reason_code));
  v_uid := private.rebuy_p6_lock_actor_key(p_idempotency_key);
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'merchant.after_sale.manage', true
  );
  IF v_auth.user_id IS DISTINCT FROM v_uid
  THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
  v_event_id := private.rebuy_p5_derived_uuid(
    p_idempotency_key, 'p6-operation:' || v_uid::text);
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'after_sale_open', true);
  PERFORM pg_catalog.set_config('rebuy.p6.merchant_order_id',
    p_merchant_order_id::text, true);
  SELECT k.* INTO v_key FROM public.p6_idempotency_keys AS k
  WHERE k.actor_user_id = v_auth.user_id AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'after_sale.open'
       OR v_key.target_id IS DISTINCT FROM p_merchant_order_id
       OR v_key.organization_id IS DISTINCT FROM v_auth.organization_id
       OR v_key.store_id IS DISTINCT FROM v_auth.store_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p6_idempotency_conflict'; END IF;
    PERFORM pg_catalog.set_config('rebuy.p6.case_id', v_key.result_id::text, true);
    RETURN QUERY SELECT v_key.result_id, v_key.target_id,
      v_key.result_status, v_key.result_version, c.reason_code
    FROM public.merchant_after_sale_cases AS c WHERE c.id = v_key.result_id;
    PERFORM private.rebuy_p6_reset_context();
    RETURN;
  END IF;
  PERFORM pg_catalog.set_config('rebuy.p6.operation_event_id',
    v_event_id::text, true);
  IF EXISTS (SELECT 1 FROM public.merchant_operation_events AS e
    WHERE e.id = v_event_id)
  THEN RAISE EXCEPTION 'p6_idempotency_conflict'; END IF;
  SELECT mo.* INTO v_order FROM public.merchant_orders AS mo
  WHERE mo.id = p_merchant_order_id
    AND mo.organization_id = v_auth.organization_id
    AND mo.store_id = v_auth.store_id FOR UPDATE;
  IF v_order.id IS NULL THEN RAISE EXCEPTION 'merchant_order_not_available'; END IF;
  IF v_order.status <> 'completed'
  THEN RAISE EXCEPTION 'after_sale_order_state_conflict'; END IF;
  SELECT c.id INTO v_existing_id FROM public.merchant_after_sale_cases AS c
  WHERE c.merchant_order_id = v_order.id AND c.reason_code = p_reason_code;
  IF v_existing_id IS NOT NULL THEN RAISE EXCEPTION 'after_sale_already_exists'; END IF;
  v_case_id := pg_catalog.gen_random_uuid();
  PERFORM pg_catalog.set_config('rebuy.p6.case_id', v_case_id::text, true);
  INSERT INTO public.merchant_after_sale_cases (
    id, merchant_order_id, batch_id, buyer_user_id, organization_id,
    store_id, reason_code, status, version, created_by, created_at, updated_at
  ) VALUES (
    v_case_id, v_order.id, v_order.batch_id, v_order.buyer_user_id,
    v_auth.organization_id, v_auth.store_id, p_reason_code, 'opened', 1,
    v_auth.user_id, v_now, v_now
  );
  PERFORM pg_catalog.set_config('rebuy.p6.operation_event_id', v_event_id::text, true);
  INSERT INTO public.merchant_operation_events (
    id, organization_id, store_id, actor_user_id, actor_membership_id,
    entity_type, entity_id, event_code, reason_code, from_status,
    to_status, from_version, to_version, idempotency_key,
    request_fingerprint, created_at
  ) VALUES (
    v_event_id, v_auth.organization_id, v_auth.store_id, v_auth.user_id,
    v_auth.membership_id, 'after_sale', v_case_id, 'after_sale.opened',
    p_reason_code, NULL, 'opened', NULL, 1, p_idempotency_key,
    v_fingerprint, v_now
  );
  INSERT INTO public.p6_idempotency_keys (
    actor_user_id, idempotency_key, operation_code, target_id,
    organization_id, store_id, request_fingerprint, result_status,
    result_version, result_id, created_at
  ) VALUES (
    v_auth.user_id, p_idempotency_key, 'after_sale.open', v_order.id,
    v_auth.organization_id, v_auth.store_id, v_fingerprint, 'opened',
    1, v_case_id, v_now
  );
  RETURN QUERY SELECT v_case_id, v_order.id, 'opened'::text,
    1, p_reason_code;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION private.review_my_merchant_after_sale_impl(
  p_store_id uuid,
  p_case_id uuid,
  p_action text,
  p_resolution_code text,
  p_expected_version integer,
  p_idempotency_key uuid
)
RETURNS TABLE (
  case_id uuid, case_status text, resolution_code text,
  case_version integer, resolved_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_auth record; v_case public.merchant_after_sale_cases%ROWTYPE;
  v_key public.p6_idempotency_keys%ROWTYPE;
  v_next_status text; v_reason text; v_resolution text; v_fingerprint text;
  v_uid uuid; v_event_id uuid;
  v_now timestamptz := pg_catalog.statement_timestamp();
  v_resolved_at timestamptz;
BEGIN
  IF p_case_id IS NULL OR p_idempotency_key IS NULL
     OR p_expected_version IS NULL OR p_expected_version < 1
     OR p_action IS NULL OR p_action NOT IN ('start_review', 'resolve', 'reject')
  THEN RAISE EXCEPTION 'after_sale_review_invalid'; END IF;
  IF p_action = 'start_review' THEN
    IF p_resolution_code IS NOT NULL THEN RAISE EXCEPTION 'after_sale_review_invalid'; END IF;
    v_next_status := 'reviewing'; v_reason := 'review_started';
    v_resolution := NULL; v_resolved_at := NULL;
  ELSIF p_action = 'resolve' THEN
    IF p_resolution_code IS NULL
       OR p_resolution_code NOT IN ('replacement_recorded', 'return_recorded',
      'no_action_recorded') THEN RAISE EXCEPTION 'after_sale_review_invalid'; END IF;
    v_next_status := 'resolved'; v_reason := p_resolution_code;
    v_resolution := p_resolution_code; v_resolved_at := v_now;
  ELSE
    IF p_resolution_code IS NOT NULL AND p_resolution_code <> 'request_rejected'
    THEN RAISE EXCEPTION 'after_sale_review_invalid'; END IF;
    v_next_status := 'rejected'; v_reason := 'request_rejected';
    v_resolution := 'request_rejected'; v_resolved_at := v_now;
  END IF;
  v_fingerprint := pg_catalog.md5(pg_catalog.concat_ws('|', p_store_id::text,
    p_case_id::text, p_action, COALESCE(v_resolution, ''),
    p_expected_version::text));
  v_uid := private.rebuy_p6_lock_actor_key(p_idempotency_key);
  SELECT * INTO v_auth FROM private.rebuy_p6_authorize_store(
    p_store_id, 'merchant.after_sale.manage', true
  );
  IF v_auth.user_id IS DISTINCT FROM v_uid
  THEN RAISE EXCEPTION 'merchant_scope_forbidden'; END IF;
  v_event_id := private.rebuy_p5_derived_uuid(
    p_idempotency_key, 'p6-operation:' || v_uid::text);
  PERFORM pg_catalog.set_config('rebuy.p6.op', 'after_sale_review', true);
  PERFORM pg_catalog.set_config('rebuy.p6.case_id', p_case_id::text, true);
  SELECT k.* INTO v_key FROM public.p6_idempotency_keys AS k
  WHERE k.actor_user_id = v_auth.user_id AND k.idempotency_key = p_idempotency_key;
  IF v_key.actor_user_id IS NOT NULL THEN
    IF v_key.operation_code IS DISTINCT FROM 'after_sale.review'
       OR v_key.target_id IS DISTINCT FROM p_case_id
       OR v_key.organization_id IS DISTINCT FROM v_auth.organization_id
       OR v_key.store_id IS DISTINCT FROM v_auth.store_id
       OR v_key.request_fingerprint IS DISTINCT FROM v_fingerprint
    THEN RAISE EXCEPTION 'p6_idempotency_conflict'; END IF;
    RETURN QUERY SELECT v_key.target_id, v_key.result_status,
      v_key.result_resolution_code, v_key.result_version,
      v_key.result_resolved_at;
    PERFORM private.rebuy_p6_reset_context();
    RETURN;
  END IF;
  PERFORM pg_catalog.set_config('rebuy.p6.operation_event_id',
    v_event_id::text, true);
  IF EXISTS (SELECT 1 FROM public.merchant_operation_events AS e
    WHERE e.id = v_event_id)
  THEN RAISE EXCEPTION 'p6_idempotency_conflict'; END IF;
  SELECT c.* INTO v_case FROM public.merchant_after_sale_cases AS c
  WHERE c.id = p_case_id AND c.organization_id = v_auth.organization_id
    AND c.store_id = v_auth.store_id FOR UPDATE;
  IF v_case.id IS NULL THEN RAISE EXCEPTION 'after_sale_not_available'; END IF;
  IF v_case.version <> p_expected_version
  THEN RAISE EXCEPTION 'after_sale_version_conflict'; END IF;
  IF (p_action = 'start_review' AND v_case.status <> 'opened')
     OR (p_action IN ('resolve', 'reject') AND v_case.status <> 'reviewing')
  THEN RAISE EXCEPTION 'after_sale_state_conflict'; END IF;
  UPDATE public.merchant_after_sale_cases AS c
  SET status = v_next_status, resolution_code = v_resolution,
    version = c.version + 1, updated_at = v_now, resolved_at = v_resolved_at
  WHERE c.id = v_case.id;
  PERFORM pg_catalog.set_config('rebuy.p6.operation_event_id', v_event_id::text, true);
  INSERT INTO public.merchant_operation_events (
    id, organization_id, store_id, actor_user_id, actor_membership_id,
    entity_type, entity_id, event_code, reason_code, from_status,
    to_status, from_version, to_version, idempotency_key,
    request_fingerprint, created_at
  ) VALUES (
    v_event_id, v_auth.organization_id, v_auth.store_id, v_auth.user_id,
    v_auth.membership_id, 'after_sale', v_case.id,
    'after_sale.' || v_next_status, v_reason, v_case.status, v_next_status,
    v_case.version, v_case.version + 1, p_idempotency_key,
    v_fingerprint, v_now
  );
  INSERT INTO public.p6_idempotency_keys (
    actor_user_id, idempotency_key, operation_code, target_id,
    organization_id, store_id, request_fingerprint, result_status,
    result_version, result_id, result_resolution_code,
    result_resolved_at, created_at
  ) VALUES (
    v_auth.user_id, p_idempotency_key, 'after_sale.review', v_case.id,
    v_auth.organization_id, v_auth.store_id, v_fingerprint, v_next_status,
    v_case.version + 1, v_case.id, v_resolution, v_resolved_at, v_now
  );
  RETURN QUERY SELECT v_case.id, v_next_status, v_resolution,
    v_case.version + 1, v_resolved_at;
  PERFORM private.rebuy_p6_reset_context();
END
$function$;

CREATE OR REPLACE FUNCTION public.get_my_merchant_context()
RETURNS TABLE (
  store_id uuid, organization_id uuid, store_name text, role_key text,
  membership_id uuid, can_catalog boolean, can_pricing boolean,
  can_inventory boolean, can_fulfill boolean, can_after_sale boolean,
  can_audit boolean
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_my_merchant_context_impl() $function$;

CREATE OR REPLACE FUNCTION public.cancel_my_order_batch(
  p_batch_id uuid, p_expected_version integer, p_idempotency_key uuid
)
RETURNS TABLE (
  batch_id uuid, order_status text, inventory_status text,
  order_version integer, cancelled_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.cancel_my_order_batch_p6_impl(
  p_batch_id, p_expected_version, p_idempotency_key
) $function$;

CREATE OR REPLACE FUNCTION public.get_my_merchant_dashboard(p_store_id uuid)
RETURNS TABLE (
  store_id uuid, store_name text, active_listing_count integer,
  low_stock_count integer, pending_order_count integer,
  active_after_sale_count integer, recent_operation_count integer
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_my_merchant_dashboard_impl(p_store_id) $function$;

CREATE OR REPLACE FUNCTION public.list_my_merchant_products(p_store_id uuid)
RETURNS TABLE (
  listing_id uuid, product_id uuid, variant_id uuid, category_slug text,
  product_kind text, internal_name text, sku text, listing_slug text,
  title text, summary text, listing_status text, listing_version integer,
  retail_cents integer, wholesale_cents integer, wholesale_minimum integer,
  wholesale_tiers jsonb, available_quantity integer, inventory_version integer,
  synthetic_serial_reference text,
  condition_code text, defect_code text, battery_health_percent integer,
  warranty_days integer
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.list_my_merchant_products_impl(p_store_id) $function$;

CREATE OR REPLACE FUNCTION public.list_my_merchant_inventory(p_store_id uuid)
RETURNS TABLE (
  listing_id uuid, title text, sku text, inventory_kind text,
  on_hand integer, reserved integer, available integer,
  unit_status text, inventory_version integer, updated_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.list_my_merchant_inventory_impl(p_store_id) $function$;

CREATE OR REPLACE FUNCTION public.list_my_merchant_orders(p_store_id uuid)
RETURNS TABLE (
  merchant_order_id uuid, batch_id uuid, synthetic_order_reference text,
  order_status text, inventory_status text, currency_code text,
  total_cents integer, order_version integer, item_count integer,
  created_at timestamptz, updated_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.list_my_merchant_orders_impl(p_store_id) $function$;

CREATE OR REPLACE FUNCTION public.get_my_merchant_order(
  p_store_id uuid, p_merchant_order_id uuid
)
RETURNS TABLE (
  merchant_order_id uuid, batch_id uuid, synthetic_order_reference text,
  order_status text, inventory_status text, synthetic_shipment_reference text,
  currency_code text, total_cents integer, order_version integer,
  listing_id uuid, title_snapshot text, sku_snapshot text,
  product_kind text, quantity integer, audience text,
  unit_amount_cents integer, line_amount_cents integer,
  item_inventory_status text, event_codes jsonb, created_at timestamptz,
  accepted_at timestamptz, shipped_at timestamptz, completed_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_my_merchant_order_impl(
  p_store_id, p_merchant_order_id
) $function$;

CREATE OR REPLACE FUNCTION public.list_my_merchant_after_sales(p_store_id uuid)
RETURNS TABLE (
  case_id uuid, merchant_order_id uuid, synthetic_order_reference text,
  reason_code text, case_status text, resolution_code text,
  case_version integer, created_at timestamptz, updated_at timestamptz,
  resolved_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.list_my_merchant_after_sales_impl(p_store_id) $function$;

CREATE OR REPLACE FUNCTION public.list_my_merchant_audit(
  p_store_id uuid, p_event_prefix text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  event_code text, entity_type text, entity_id uuid, reason_code text,
  from_status text, to_status text, from_version integer,
  to_version integer, created_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.list_my_merchant_audit_impl(
  p_store_id, p_event_prefix, p_limit
) $function$;

CREATE OR REPLACE FUNCTION public.adjust_my_merchant_inventory(
  p_store_id uuid, p_listing_id uuid, p_quantity_delta integer,
  p_reason_code text, p_expected_version integer, p_idempotency_key uuid
)
RETURNS TABLE (
  listing_id uuid, on_hand integer, reserved integer,
  available integer, inventory_version integer
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.adjust_my_merchant_inventory_impl(
  p_store_id, p_listing_id, p_quantity_delta, p_reason_code,
  p_expected_version, p_idempotency_key
) $function$;

CREATE OR REPLACE FUNCTION public.advance_my_merchant_order(
  p_store_id uuid, p_merchant_order_id uuid, p_action text,
  p_reason_code text, p_synthetic_shipment_reference text,
  p_expected_version integer, p_idempotency_key uuid
)
RETURNS TABLE (
  merchant_order_id uuid, order_status text, inventory_status text,
  order_version integer, batch_status text, batch_inventory_status text,
  batch_version integer, synthetic_shipment_reference text
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.advance_my_merchant_order_impl(
  p_store_id, p_merchant_order_id, p_action, p_reason_code,
  p_synthetic_shipment_reference, p_expected_version, p_idempotency_key
) $function$;

CREATE OR REPLACE FUNCTION public.open_my_merchant_after_sale(
  p_store_id uuid, p_merchant_order_id uuid,
  p_reason_code text, p_idempotency_key uuid
)
RETURNS TABLE (
  case_id uuid, merchant_order_id uuid, case_status text,
  case_version integer, reason_code text
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.open_my_merchant_after_sale_impl(
  p_store_id, p_merchant_order_id, p_reason_code, p_idempotency_key
) $function$;

CREATE OR REPLACE FUNCTION public.review_my_merchant_after_sale(
  p_store_id uuid, p_case_id uuid, p_action text,
  p_resolution_code text, p_expected_version integer,
  p_idempotency_key uuid
)
RETURNS TABLE (
  case_id uuid, case_status text, resolution_code text,
  case_version integer, resolved_at timestamptz
)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.review_my_merchant_after_sale_impl(
  p_store_id, p_case_id, p_action, p_resolution_code,
  p_expected_version, p_idempotency_key
) $function$;

REVOKE ALL PRIVILEGES ON FUNCTION
  private.get_my_merchant_context_impl(),
  private.get_my_merchant_dashboard_impl(uuid),
  private.list_my_merchant_products_impl(uuid),
  private.list_my_merchant_inventory_impl(uuid),
  private.list_my_merchant_orders_impl(uuid),
  private.get_my_merchant_order_impl(uuid, uuid),
  private.list_my_merchant_after_sales_impl(uuid),
  private.list_my_merchant_audit_impl(uuid, text, integer),
  private.adjust_my_merchant_inventory_impl(uuid, uuid, integer, text, integer, uuid),
  private.advance_my_merchant_order_impl(uuid, uuid, text, text, text, integer, uuid),
  private.open_my_merchant_after_sale_impl(uuid, uuid, text, uuid),
  private.review_my_merchant_after_sale_impl(uuid, uuid, text, text, integer, uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
GRANT EXECUTE ON FUNCTION
  private.get_my_merchant_context_impl(),
  private.get_my_merchant_dashboard_impl(uuid),
  private.list_my_merchant_products_impl(uuid),
  private.list_my_merchant_inventory_impl(uuid),
  private.list_my_merchant_orders_impl(uuid),
  private.get_my_merchant_order_impl(uuid, uuid),
  private.list_my_merchant_after_sales_impl(uuid),
  private.list_my_merchant_audit_impl(uuid, text, integer),
  private.adjust_my_merchant_inventory_impl(uuid, uuid, integer, text, integer, uuid),
  private.advance_my_merchant_order_impl(uuid, uuid, text, text, text, integer, uuid),
  private.open_my_merchant_after_sale_impl(uuid, uuid, text, uuid),
  private.review_my_merchant_after_sale_impl(uuid, uuid, text, text, integer, uuid)
  TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION
  private.cancel_my_order_batch_p6_impl(uuid, integer, uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;
GRANT EXECUTE ON FUNCTION
  private.cancel_my_order_batch_p6_impl(uuid, integer, uuid)
  TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION
  private.rebuy_p6_clear_context(), private.rebuy_p6_reset_context(),
  private.rebuy_p6_lock_actor_key(uuid),
  private.rebuy_p6_authorize_store(uuid, text, boolean),
  private.rebuy_p6_refresh_batch(uuid),
  private.rebuy_p6_change_order_inventory_impl(uuid, integer, text, integer, text, uuid)
  FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;
GRANT EXECUTE ON FUNCTION
  private.rebuy_p6_clear_context(), private.rebuy_p6_reset_context(),
  private.rebuy_p6_lock_actor_key(uuid),
  private.rebuy_p6_authorize_store(uuid, text, boolean),
  private.rebuy_p6_refresh_batch(uuid),
  private.rebuy_p6_change_order_inventory_impl(uuid, integer, text, integer, text, uuid)
  TO rebuy_business_executor;

DO $owner_handoff$
BEGIN
  IF pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR pg_catalog.has_schema_privilege('rebuy_business_executor', 'private', 'CREATE')
  THEN RAISE EXCEPTION 'rebuy_p6_owner_handoff_precondition_invalid'; END IF;
  EXECUTE 'GRANT rebuy_business_executor TO postgres WITH INHERIT FALSE GRANTED BY CURRENT_USER';
  EXECUTE 'GRANT CREATE ON SCHEMA private TO rebuy_business_executor GRANTED BY CURRENT_USER';
  -- P5 already handed this implementation to the isolated executor. Revoke
  -- its superseded external ACL while executing as that actual owner.
  EXECUTE 'SET LOCAL ROLE rebuy_business_executor';
  EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION private.cancel_my_order_batch_impl(uuid, integer, uuid) FROM PUBLIC, anon, authenticated, service_role';
  EXECUTE 'RESET ROLE';
  EXECUTE 'ALTER FUNCTION private.rebuy_p6_clear_context() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.rebuy_p6_reset_context() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.rebuy_p6_lock_actor_key(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.rebuy_p6_authorize_store(uuid, text, boolean) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.rebuy_p6_refresh_batch(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.rebuy_p6_change_order_inventory_impl(uuid, integer, text, integer, text, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.cancel_my_order_batch_p6_impl(uuid, integer, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.adjust_my_merchant_inventory_impl(uuid, uuid, integer, text, integer, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.get_my_merchant_context_impl() OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.get_my_merchant_dashboard_impl(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.list_my_merchant_products_impl(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.list_my_merchant_inventory_impl(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.list_my_merchant_orders_impl(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.get_my_merchant_order_impl(uuid, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.list_my_merchant_after_sales_impl(uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.list_my_merchant_audit_impl(uuid, text, integer) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.advance_my_merchant_order_impl(uuid, uuid, text, text, text, integer, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.open_my_merchant_after_sale_impl(uuid, uuid, text, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'ALTER FUNCTION private.review_my_merchant_after_sale_impl(uuid, uuid, text, text, integer, uuid) OWNER TO rebuy_business_executor';
  EXECUTE 'REVOKE rebuy_business_executor FROM postgres GRANTED BY CURRENT_USER';
  EXECUTE 'REVOKE CREATE ON SCHEMA private FROM rebuy_business_executor GRANTED BY CURRENT_USER';
  IF pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'USAGE')
     OR pg_catalog.pg_has_role('postgres', 'rebuy_business_executor', 'SET')
     OR pg_catalog.has_schema_privilege('rebuy_business_executor', 'private', 'CREATE')
  THEN RAISE EXCEPTION 'rebuy_p6_owner_handoff_cleanup_invalid'; END IF;
END
$owner_handoff$;

REVOKE ALL PRIVILEGES ON FUNCTION public.cancel_my_order_batch(uuid, integer, uuid),
  public.get_my_merchant_context(),
  public.get_my_merchant_dashboard(uuid),
  public.list_my_merchant_products(uuid),
  public.list_my_merchant_inventory(uuid),
  public.list_my_merchant_orders(uuid),
  public.get_my_merchant_order(uuid, uuid),
  public.list_my_merchant_after_sales(uuid),
  public.list_my_merchant_audit(uuid, text, integer),
  public.adjust_my_merchant_inventory(uuid, uuid, integer, text, integer, uuid),
  public.advance_my_merchant_order(uuid, uuid, text, text, text, integer, uuid),
  public.open_my_merchant_after_sale(uuid, uuid, text, uuid),
  public.review_my_merchant_after_sale(uuid, uuid, text, text, integer, uuid)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_my_order_batch(uuid, integer, uuid),
  public.get_my_merchant_context(),
  public.get_my_merchant_dashboard(uuid),
  public.list_my_merchant_products(uuid),
  public.list_my_merchant_inventory(uuid),
  public.list_my_merchant_orders(uuid),
  public.get_my_merchant_order(uuid, uuid),
  public.list_my_merchant_after_sales(uuid),
  public.list_my_merchant_audit(uuid, text, integer),
  public.adjust_my_merchant_inventory(uuid, uuid, integer, text, integer, uuid),
  public.advance_my_merchant_order(uuid, uuid, text, text, text, integer, uuid),
  public.open_my_merchant_after_sale(uuid, uuid, text, uuid),
  public.review_my_merchant_after_sale(uuid, uuid, text, text, integer, uuid)
  TO authenticated;
