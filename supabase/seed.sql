-- P2-L/P4 authorization and category catalogs only.
-- No auth.users, identity, email, tenant, store, membership, listing, price, or inventory rows.

INSERT INTO public.permissions (
  id, permission_key, resource, action, scope_type, risk_level, requires_aal2
)
VALUES
  ('00000000-0000-4000-8000-000000000101', 'profile.read_self', 'profile', 'read_self', 'user', 'medium', false),
  ('00000000-0000-4000-8000-000000000102', 'profile.update_self', 'profile', 'update_self', 'user', 'medium', false),
  ('00000000-0000-4000-8000-000000000103', 'organization.read', 'organization', 'read', 'organization', 'medium', false),
  ('00000000-0000-4000-8000-000000000104', 'store.read', 'store', 'read', 'store', 'medium', false),
  ('00000000-0000-4000-8000-000000000105', 'member.read', 'member', 'read', 'organization', 'high', false),
  ('00000000-0000-4000-8000-000000000106', 'member.invite', 'member', 'invite', 'organization', 'high', false),
  ('00000000-0000-4000-8000-000000000107', 'merchant_application.assign', 'merchant_application', 'assign', 'platform', 'high', false),
  ('00000000-0000-4000-8000-000000000108', 'merchant_application.read_assigned', 'merchant_application', 'read_assigned', 'platform', 'high', false),
  ('00000000-0000-4000-8000-000000000109', 'merchant_application.review', 'merchant_application', 'review', 'platform', 'critical', false),
  ('00000000-0000-4000-8000-000000000110', 'catalog.write', 'catalog', 'write', 'organization', 'high', false),
  ('00000000-0000-4000-8000-000000000111', 'listing.publish', 'listing', 'publish', 'store', 'high', false),
  ('00000000-0000-4000-8000-000000000112', 'pricing.write', 'pricing', 'write', 'store', 'critical', false),
  ('00000000-0000-4000-8000-000000000113', 'inventory.adjust', 'inventory', 'adjust', 'store', 'critical', false),
  ('00000000-0000-4000-8000-000000000114', 'wholesale_application.assign', 'wholesale_application', 'assign', 'platform', 'high', false),
  ('00000000-0000-4000-8000-000000000115', 'wholesale_application.read_assigned', 'wholesale_application', 'read_assigned', 'platform', 'high', false),
  ('00000000-0000-4000-8000-000000000116', 'wholesale_application.review', 'wholesale_application', 'review', 'platform', 'critical', false),
  ('00000000-0000-4000-8000-000000000117', 'wholesale_qualification.manage', 'wholesale_qualification', 'manage', 'platform', 'critical', false)
ON CONFLICT (id) DO UPDATE
SET permission_key = EXCLUDED.permission_key,
    resource = EXCLUDED.resource,
    action = EXCLUDED.action,
    scope_type = EXCLUDED.scope_type,
    risk_level = EXCLUDED.risk_level,
    requires_aal2 = EXCLUDED.requires_aal2;

INSERT INTO public.role_definitions (
  id, role_key, scope_type, version, applicable_organization_type,
  is_system, status, assignable
)
VALUES
  ('00000000-0000-4000-8000-000000000201', 'owner', 'organization', 1, 'any', true, 'active', true),
  ('00000000-0000-4000-8000-000000000202', 'employee', 'store', 1, 'merchant', true, 'active', true),
  ('00000000-0000-4000-8000-000000000203', 'platform_admin', 'platform', 1, 'platform', true, 'active', false),
  ('00000000-0000-4000-8000-000000000204', 'merchant_reviewer', 'platform', 1, 'platform', true, 'active', false),
  ('00000000-0000-4000-8000-000000000205', 'wholesale_reviewer', 'platform', 1, 'platform', true, 'active', false)
ON CONFLICT (id) DO UPDATE
SET organization_id = EXCLUDED.organization_id,
    organization_type = EXCLUDED.organization_type,
    role_key = EXCLUDED.role_key,
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
  ('00000000-0000-4000-8000-000000000201', 1, '00000000-0000-4000-8000-000000000103', true),
  ('00000000-0000-4000-8000-000000000201', 1, '00000000-0000-4000-8000-000000000104', true),
  ('00000000-0000-4000-8000-000000000201', 1, '00000000-0000-4000-8000-000000000105', true),
  ('00000000-0000-4000-8000-000000000201', 1, '00000000-0000-4000-8000-000000000106', true),
  ('00000000-0000-4000-8000-000000000202', 1, '00000000-0000-4000-8000-000000000104', true),
  ('00000000-0000-4000-8000-000000000203', 1, '00000000-0000-4000-8000-000000000107', true),
  ('00000000-0000-4000-8000-000000000203', 1, '00000000-0000-4000-8000-000000000108', true),
  ('00000000-0000-4000-8000-000000000203', 1, '00000000-0000-4000-8000-000000000109', true),
  ('00000000-0000-4000-8000-000000000204', 1, '00000000-0000-4000-8000-000000000108', true),
  ('00000000-0000-4000-8000-000000000204', 1, '00000000-0000-4000-8000-000000000109', true),
  ('00000000-0000-4000-8000-000000000201', 1, '00000000-0000-4000-8000-000000000110', true),
  ('00000000-0000-4000-8000-000000000201', 1, '00000000-0000-4000-8000-000000000111', true),
  ('00000000-0000-4000-8000-000000000201', 1, '00000000-0000-4000-8000-000000000112', true),
  ('00000000-0000-4000-8000-000000000201', 1, '00000000-0000-4000-8000-000000000113', true),
  ('00000000-0000-4000-8000-000000000203', 1, '00000000-0000-4000-8000-000000000114', true),
  ('00000000-0000-4000-8000-000000000203', 1, '00000000-0000-4000-8000-000000000115', true),
  ('00000000-0000-4000-8000-000000000203', 1, '00000000-0000-4000-8000-000000000116', true),
  ('00000000-0000-4000-8000-000000000203', 1, '00000000-0000-4000-8000-000000000117', true),
  ('00000000-0000-4000-8000-000000000205', 1, '00000000-0000-4000-8000-000000000115', true),
  ('00000000-0000-4000-8000-000000000205', 1, '00000000-0000-4000-8000-000000000116', true),
  ('00000000-0000-4000-8000-000000000205', 1, '00000000-0000-4000-8000-000000000117', true)
ON CONFLICT (role_definition_id, role_version, permission_id) DO UPDATE
SET is_granted = EXCLUDED.is_granted;

INSERT INTO public.categories (
  id, parent_id, slug, name_zh, name_it, name_en, status, sort_order
)
VALUES
  ('00000000-0000-4000-8000-000000000301', NULL, 'electronics', '电子产品', 'Elettronica', 'Electronics', 'active', 10),
  ('00000000-0000-4000-8000-000000000302', NULL, 'phone-accessories', '手机配件', 'Accessori telefono', 'Phone accessories', 'active', 20),
  ('00000000-0000-4000-8000-000000000303', NULL, 'secondhand', '二手交易', 'Seconda mano', 'Secondhand', 'active', 30),
  ('00000000-0000-4000-8000-000000000304', NULL, 'computers', '电脑与配件', 'Computer e accessori', 'Computers', 'active', 40)
ON CONFLICT (id) DO UPDATE
SET slug = EXCLUDED.slug,
    name_zh = EXCLUDED.name_zh,
    name_it = EXCLUDED.name_it,
    name_en = EXCLUDED.name_en,
    status = EXCLUDED.status,
    sort_order = EXCLUDED.sort_order;
