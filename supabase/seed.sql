-- P2-L catalog only. No auth.users, identity, email, tenant, store, or member data.

INSERT INTO public.permissions (
  id, permission_key, resource, action, scope_type, risk_level, requires_aal2
)
VALUES
  ('00000000-0000-4000-8000-000000000101', 'profile.read_self', 'profile', 'read_self', 'user', 'medium', false),
  ('00000000-0000-4000-8000-000000000102', 'profile.update_self', 'profile', 'update_self', 'user', 'medium', false),
  ('00000000-0000-4000-8000-000000000103', 'organization.read', 'organization', 'read', 'organization', 'medium', false),
  ('00000000-0000-4000-8000-000000000104', 'store.read', 'store', 'read', 'store', 'medium', false),
  ('00000000-0000-4000-8000-000000000105', 'member.read', 'member', 'read', 'organization', 'high', false),
  ('00000000-0000-4000-8000-000000000106', 'member.invite', 'member', 'invite', 'organization', 'high', false)
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
  ('00000000-0000-4000-8000-000000000202', 'employee', 'store', 1, 'merchant', true, 'active', true)
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
  ('00000000-0000-4000-8000-000000000202', 1, '00000000-0000-4000-8000-000000000104', true)
ON CONFLICT (role_definition_id, role_version, permission_id) DO UPDATE
SET is_granted = EXCLUDED.is_granted;
