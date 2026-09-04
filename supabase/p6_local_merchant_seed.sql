-- P6 local-only synthetic merchant membership. Never use as production data.
INSERT INTO public.memberships (
  id, user_id, organization_id, organization_type,
  role_definition_id, role_version, status, valid_from
)
VALUES (
  '90000000-0000-4000-8000-000000000901',
  '90000000-0000-4000-8000-000000000001',
  '90000000-0000-4000-8000-000000000101', 'merchant',
  '00000000-0000-4000-8000-000000000201', 1, 'active',
  pg_catalog.statement_timestamp()
);

INSERT INTO public.membership_store_scopes (
  id, membership_id, organization_id, organization_type,
  store_id, scope_type, status
)
VALUES (
  '90000000-0000-4000-8000-000000000902',
  '90000000-0000-4000-8000-000000000901',
  '90000000-0000-4000-8000-000000000101', 'merchant',
  NULL, 'organization', 'active'
);
