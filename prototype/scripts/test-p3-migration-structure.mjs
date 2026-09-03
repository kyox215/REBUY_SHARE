import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

const migration = await readFile(
  fileURLToPath(
    new URL(
      '../../supabase/migrations/20260903120000_p3_merchant_onboarding.sql',
      import.meta.url,
    ),
  ),
  'utf8',
)
const roles = await readFile(
  fileURLToPath(new URL('../../supabase/roles.sql', import.meta.url)),
  'utf8',
)
const seed = await readFile(
  fileURLToPath(new URL('../../supabase/seed.sql', import.meta.url)),
  'utf8',
)
const concurrency = await readFile(
  fileURLToPath(new URL('./run-p3-approval-concurrency.mjs', import.meta.url)),
  'utf8',
)
const schemaTest = await readFile(
  fileURLToPath(
    new URL('../../supabase/tests/p3_merchant_schema_security.test.sql', import.meta.url),
  ),
  'utf8',
)
const workflowTest = await readFile(
  fileURLToPath(
    new URL('../../supabase/tests/p3_merchant_workflow.test.sql', import.meta.url),
  ),
  'utf8',
)

const tables = [
  'merchant_applications',
  'merchant_application_private',
  'merchant_application_events',
]
for (const table of tables) {
  assert.match(migration, new RegExp(`CREATE TABLE public[.]${table} \\(`))
  assert.match(
    migration,
    new RegExp(`ALTER TABLE public[.]${table} ENABLE ROW LEVEL SECURITY;`),
  )
  assert.match(
    migration,
    new RegExp(`ALTER TABLE public[.]${table} FORCE ROW LEVEL SECURITY;`),
  )
}
assert.match(
  migration,
  /CREATE INDEX merchant_application_private_application_applicant_idx\s+ON public[.]merchant_application_private \(application_id, applicant_user_id\);/,
)

assert.match(
  roles,
  /CREATE ROLE rebuy_business_executor\s+NOLOGIN\s+NOSUPERUSER\s+NOCREATEDB\s+NOCREATEROLE\s+NOINHERIT\s+NOREPLICATION\s+NOBYPASSRLS;/,
)
assert.doesNotMatch(migration, /(?:CREATE|ALTER) ROLE rebuy_business_executor/)
assert.match(
  migration,
  /grantor_role[.]rolname = 'supabase_admin'[\s\S]*?pam[.]admin_option[\s\S]*?NOT pam[.]inherit_option[\s\S]*?NOT pam[.]set_option/,
)
assert.doesNotMatch(
  `${roles}\n${migration}`,
  /(?:GRANT|ALTER DEFAULT PRIVILEGES)[^;]*\bservice_role\b/is,
)
assert.match(
  migration,
  /REVOKE ALL PRIVILEGES ON TABLE[\s\S]*?public[.]merchant_application_events[\s\S]*?FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;/,
)

for (const wrapper of [
  'save_merchant_application',
  'get_my_merchant_application',
  'list_merchant_review_queue',
  'get_assigned_merchant_application',
  'assign_merchant_application',
  'review_merchant_application',
  'withdraw_merchant_application',
]) {
  assert.match(
    migration,
    new RegExp(
      `CREATE OR REPLACE FUNCTION public[.]${wrapper}\\([\\s\\S]*?SECURITY INVOKER`,
    ),
    `${wrapper} must be a SECURITY INVOKER wrapper`,
  )
}

for (const implementation of [
  'save_merchant_application_impl',
  'get_my_merchant_application_impl',
  'list_merchant_review_queue_impl',
  'get_assigned_merchant_application_impl',
  'assign_merchant_application_impl',
  'review_merchant_application_impl',
  'withdraw_merchant_application_impl',
]) {
  assert.match(
    migration,
    new RegExp(
      `CREATE OR REPLACE FUNCTION private[.]${implementation}\\([\\s\\S]*?SECURITY DEFINER\\nSET search_path = ''`,
    ),
    `${implementation} must be an empty-search-path SECURITY DEFINER`,
  )
  assert.match(
    migration,
    new RegExp(
      `ALTER FUNCTION private[.]${implementation}\\([^;]*\\) OWNER TO rebuy_business_executor`,
    ),
    `${implementation} must be handed to the isolated executor`,
  )
}

for (const implementation of [
  'get_my_merchant_application_impl',
  'list_merchant_review_queue_impl',
  'get_assigned_merchant_application_impl',
]) {
  assert.match(
    migration,
    new RegExp(
      `CREATE OR REPLACE FUNCTION private[.]${implementation}\\([\\s\\S]*?LANGUAGE plpgsql\\nVOLATILE`,
    ),
    `${implementation} must remain volatile because it resets request context`,
  )
}

for (const wrapper of [
  'get_my_merchant_application',
  'list_merchant_review_queue',
  'get_assigned_merchant_application',
]) {
  assert.match(
    migration,
    new RegExp(
      `CREATE OR REPLACE FUNCTION public[.]${wrapper}\\([\\s\\S]*?LANGUAGE sql VOLATILE SECURITY INVOKER`,
    ),
    `${wrapper} must remain volatile with its implementation`,
  )
}

assert.match(migration, /pg_advisory_xact_lock\([\s\S]*?hashtextextended/)
assert.match(migration, /v_uid = v_application[.]applicant_user_id/)
assert.match(
  migration,
  /CONSTRAINT merchant_application_events_idempotency_key UNIQUE \(\s*actor_user_id, idempotency_key\s*\)/,
)
assert.match(migration, /actor_user_id = \(SELECT private[.]rebuy_request_uid\(\)\)/)
assert.match(
  migration,
  /OR\s+v_email IS NULL\s+OR\s+v_email !~ '\^\[a-z0-9/,
)
assert.match(migration, /v_event[.]application_id IS DISTINCT FROM p_application_id/)
assert.match(migration, /RETURN QUERY SELECT v_event[.]application_id, v_event[.]to_status/)
assert.match(
  migration,
  /v_uid::text \|\| ':' \|\| p_idempotency_key::text \|\| ':merchant-idempotency'/,
)
assert.match(
  migration,
  /CREATE OR REPLACE FUNCTION private[.]save_merchant_application_impl[\s\S]*?v_uid::text \|\| ':merchant-application'[\s\S]*?hashtextextended\(v_locked_application_id::text, 0\)/,
)
assert.match(
  migration,
  /CREATE OR REPLACE FUNCTION private[.]withdraw_merchant_application_impl[\s\S]*?v_uid::text \|\| ':merchant-application'[\s\S]*?hashtextextended\(p_application_id::text, 0\)/,
)
assert.match(
  migration,
  /JOIN public[.]role_definitions AS rd[\s\S]*?rd[.]status = 'active'[\s\S]*?rd[.]scope_type = 'platform'[\s\S]*?rd[.]applicable_organization_type = 'platform'/,
)
assert.match(
  migration,
  /CREATE OR REPLACE FUNCTION private[.]review_merchant_application_impl[\s\S]*?'merchant_application[.]review'[\s\S]*?'merchant_application[.]read_assigned'/,
)
assert.match(
  migration,
  /rd[.]role_key = 'owner'[\s\S]*?rd[.]scope_type = 'organization'[\s\S]*?rd[.]is_system[\s\S]*?rd[.]organization_id IS NULL[\s\S]*?rd[.]organization_type IS NULL/,
)
const reviewImplementation = migration.slice(
  migration.indexOf(
    'CREATE OR REPLACE FUNCTION private.review_merchant_application_impl(',
  ),
  migration.indexOf(
    'CREATE OR REPLACE FUNCTION private.withdraw_merchant_application_impl(',
  ),
)
const reviewEventLookup = reviewImplementation.indexOf(
  'FROM public.merchant_application_events AS e',
)
const reviewCurrentAssignmentGate = reviewImplementation.indexOf(
  'v_application.assigned_reviewer_membership_id IS NULL',
)
const reviewApplicationLock = reviewImplementation.indexOf(
  'pg_catalog.hashtextextended(p_application_id::text, 0)',
)
assert.ok(reviewEventLookup >= 0, 'review event lookup must exist')
assert.ok(
  reviewEventLookup < reviewCurrentAssignmentGate,
  'review history lookup must precede the current assignment gate',
)
assert.ok(
  reviewEventLookup < reviewApplicationLock,
  'review history lookup must precede the current application lock',
)
assert.doesNotMatch(
  migration,
  /(?<!SELECT )pg_catalog[.]current_setting\('rebuy[.]business/,
  'all RLS context lookups must use init-plan SELECT wrapping',
)
assert.match(migration, /public_visibility, created_at, updated_at[\s\S]*?'active', false/)
assert.match(
  migration,
  /INSERT INTO public[.]organizations[\s\S]*?INSERT INTO public[.]stores[\s\S]*?INSERT INTO public[.]memberships[\s\S]*?INSERT INTO public[.]membership_store_scopes[\s\S]*?UPDATE public[.]merchant_applications/,
)
assert.match(migration, /p_action NOT IN \('needs_info', 'approve', 'reject', 'suspend'\)/)
assert.match(migration, /evidence_reference ~ '\^synthetic:\/\//)
assert.doesNotMatch(migration, /CREATE(?: OR REPLACE)? TRIGGER[^;]*auth[.]users/is)
assert.doesNotMatch(migration, /\b(?:phone|address|tax|bank|document_blob)\b/i)

for (const key of [
  'merchant_application.assign',
  'merchant_application.read_assigned',
  'merchant_application.review',
]) {
  assert.match(seed, new RegExp(`'${key.replace('.', '[.]')}'`))
}
assert.match(seed, /'platform_admin', 'platform', 1, 'platform'/)
assert.match(seed, /'merchant_reviewer', 'platform', 1, 'platform'/)
assert.match(schemaTest, /external roles have no effective P3 table privileges/)
assert.match(schemaTest, /external roles have no effective P3 column privileges/)
assert.match(schemaTest, /all public wrappers have exact effective execution ACLs/)
assert.match(schemaTest, /all private implementations allow only authenticated direct parity execution/)
assert.match(workflowTest, /missing signed email is rejected on a direct implementation call/)
assert.match(workflowTest, /direct get-my implementation cannot expose another applicant/)
assert.match(workflowTest, /direct assignment implementation revalidates platform permission/)
assert.match(workflowTest, /direct assigned-detail implementation rejects another reviewer/)
assert.match(workflowTest, /direct review implementation rejects a non-assigned reviewer/)
assert.match(workflowTest, /direct withdrawal implementation rejects a non-applicant/)
assert.match(workflowTest, /direct queue implementation revalidates platform permission/)
assert.match(workflowTest, /missing AMR is rejected/)
assert.match(workflowTest, /anonymous identity is rejected/)
assert.match(workflowTest, /assigned reviewer loses access when the reviewer role is retired/)
assert.match(workflowTest, /review action revalidates read_assigned as well as review permission/)
assert.match(workflowTest, /old save retry returns the original draft result after terminal progress/)
assert.match(workflowTest, /old needs-info key returns the original result after assignment is cleared/)
assert.match(workflowTest, /old needs-info retry does not roll back the current application state/)
assert.match(workflowTest, /same actor and key cannot be reused for a changed payload/)
assert.match(workflowTest, /same actor and key cannot be reused for a different application/)
assert.match(workflowTest, /approval fails closed when the canonical owner scope drifts/)
assert.match(workflowTest, /a failure after organization insert aborts the whole approval statement/)
assert.match(workflowTest, /mid-approval failure leaves no audit event/)
assert.match(concurrency, /same_key_approval/)
assert.match(concurrency, /different_key_approval/)
assert.match(concurrency, /save_withdraw_race/)
assert.match(concurrency, /Promise[.]all\(sameAttempts\)/)
assert.match(concurrency, /Promise[.]all\(conflictAttempts\)/)
assert.match(concurrency, /merchant_application_state_conflict/)
assert.match(concurrency, /deadlock detected\|statement timeout\|lock timeout/)
assert.match(concurrency, /pg_advisory_xact_lock/)
assert.match(concurrency, /P3_APPROVAL_CONCURRENCY_PASS/)
assert.match(concurrency, /cleanupVerificationSql/)
for (const category of [
  'applications',
  'private_rows',
  'events',
  'scopes',
  'memberships',
  'stores',
  'organizations',
  'profiles',
  'users',
]) {
  assert.match(concurrency, new RegExp(`'${category}'`))
}
assert.match(concurrency, /cleanup_fail/)
assert.match(concurrency, /cleanup_pass/)
assert.doesNotMatch(concurrency, /[.]catch\(\(\) => undefined\)/)

console.log('P3_MIGRATION_STRUCTURE_PASS')
