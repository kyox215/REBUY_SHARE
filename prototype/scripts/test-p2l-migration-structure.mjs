import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

const migrationUrl = new URL(
  '../../supabase/migrations/20260831183358_p2l_local_schema_rls_invites.sql',
  import.meta.url,
)
const configUrl = new URL('../../supabase/config.toml', import.meta.url)
const rolesUrl = new URL('../../supabase/roles.sql', import.meta.url)
const seedUrl = new URL('../../supabase/seed.sql', import.meta.url)
const schemaTestUrl = new URL(
  '../../supabase/tests/p2l_schema_security.test.sql',
  import.meta.url,
)
const invitationTestUrl = new URL(
  '../../supabase/tests/p2l_invitation_flows.test.sql',
  import.meta.url,
)
const concurrencyTestUrl = new URL(
  './run-p2l-invitation-concurrency.mjs',
  import.meta.url,
)
const migration = await readFile(fileURLToPath(migrationUrl), 'utf8')
const config = await readFile(fileURLToPath(configUrl), 'utf8')
const roles = await readFile(fileURLToPath(rolesUrl), 'utf8')
const seed = await readFile(fileURLToPath(seedUrl), 'utf8')
const schemaTest = await readFile(fileURLToPath(schemaTestUrl), 'utf8')
const invitationTest = await readFile(fileURLToPath(invitationTestUrl), 'utf8')
const concurrencyTest = await readFile(fileURLToPath(concurrencyTestUrl), 'utf8')

const expectedTables = [
  'audit_logs',
  'membership_invitations',
  'membership_store_scopes',
  'memberships',
  'organizations',
  'permissions',
  'profiles',
  'role_definitions',
  'role_permissions',
  'stores',
]

const createdTables = Array.from(
  migration.matchAll(/CREATE TABLE public[.]([a-z_]+)\s*\(/g),
  (match) => match[1],
).sort()

assert.deepEqual(
  createdTables,
  expectedTables,
  'P2-L migration must create exactly the approved ten public tables',
)

for (const table of expectedTables) {
  assert.match(
    migration,
    new RegExp(`ALTER TABLE public[.]${table} ENABLE ROW LEVEL SECURITY;`),
    `${table} must enable RLS`,
  )
  assert.match(
    migration,
    new RegExp(`ALTER TABLE public[.]${table} FORCE ROW LEVEL SECURITY;`),
    `${table} must force RLS`,
  )
}

assert.match(
  roles,
  /CREATE ROLE rebuy_invite_executor\s+NOLOGIN\s+NOSUPERUSER\s+NOCREATEDB\s+NOCREATEROLE\s+NOINHERIT\s+NOREPLICATION\s+NOBYPASSRLS;/,
  'roles.sql must create the invitation executor with the approved attributes',
)
assert.doesNotMatch(
  migration,
  /(?:CREATE|ALTER) ROLE rebuy_invite_executor/,
  'the migration runner must not create or alter the cluster role',
)
for (const unsafeAttribute of [
  'rolsuper',
  'rolcanlogin',
  'rolcreatedb',
  'rolcreaterole',
  'rolinherit',
  'rolreplication',
  'rolbypassrls',
]) {
  for (const [sourceName, source] of [
    ['roles.sql', roles],
    ['migration', migration],
  ]) {
    assert.match(
      source,
      new RegExp(`\\b${unsafeAttribute}\\b`),
      `${sourceName} must fail closed when ${unsafeAttribute} is enabled`,
    )
  }
}
for (const [sourceName, source] of [
  ['roles.sql', roles],
  ['migration', migration],
]) {
  assert.match(
    source,
    /SELECT count\(\*\)[\s\S]*?granted_role[.]rolname = 'rebuy_invite_executor'[\s\S]*?member_role[.]rolname = 'rebuy_invite_executor'[\s\S]*?\) <> 1/,
    `${sourceName} must reject every extra executor membership in either direction`,
  )
  assert.match(
    source,
    /granted_role[.]rolname = 'rebuy_invite_executor'[\s\S]*?member_role[.]rolname = 'postgres'[\s\S]*?grantor_role[.]rolname = 'supabase_admin'[\s\S]*?pam[.]admin_option[\s\S]*?NOT pam[.]inherit_option[\s\S]*?NOT pam[.]set_option/,
    `${sourceName} must allow only the approved PostgreSQL 17 bootstrap membership`,
  )
}
assert.doesNotMatch(
  `${roles}\n${migration}`,
  /(?:GRANT|ALTER DEFAULT PRIVILEGES)[^;]*\bservice_role\b/is,
  'the P2-L migration must not grant access to service_role',
)
assert.match(
  migration,
  /REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated, service_role;/,
  'the private schema must explicitly revoke service_role',
)
assert.match(
  migration,
  /REVOKE ALL PRIVILEGES ON TABLE[\s\S]*?public[.]audit_logs\s+FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;/,
  'all ten business tables must explicitly revoke service_role',
)
for (const functionSignature of [
  'private.rebuy_request_jwt\\(\\)',
  'private.rebuy_request_uid\\(\\)',
  'private.create_membership_invitation_impl\\(\\s*uuid, uuid, integer, text, uuid, text, uuid\\s*\\)',
  'private.accept_membership_invitation_impl\\(uuid\\)',
  'public.create_membership_invitation\\(\\s*uuid, uuid, integer, text, uuid, text, uuid\\s*\\)',
  'public.accept_membership_invitation\\(uuid\\)',
]) {
  assert.match(
    migration,
    new RegExp(
      `REVOKE ALL PRIVILEGES ON FUNCTION ${functionSignature}\\s+FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;`,
    ),
    `${functionSignature} must explicitly revoke service_role`,
  )
}
assert.doesNotMatch(
  migration,
  /CREATE(?: OR REPLACE)? TRIGGER[^;]*\b(?:ON\s+)?auth[.]users\b/is,
  'the P2-L migration must not create an auth.users trigger',
)
assert.doesNotMatch(
  `${migration}\n${schemaTest}\n${invitationTest}`,
  /pg_catalog[.](?:nullif|coalesce|extract)\s*\(/i,
  'migration and pgTAP SQL expressions must not be schema-qualified as functions',
)
assert.doesNotMatch(
  migration,
  /UPDATE public[.]membership_invitations(?:\s+AS\s+[a-z_]+)?[\s\S]{0,500}?\n\s+AND expires_at <= v_now;/,
  'PL/pgSQL expiry updates must qualify expires_at with the target-table alias',
)
assert.doesNotMatch(
  migration,
  /\bv_(?:inserted|existing_updated_at)\b|EXIT insert_invitation;/,
  'the invitation implementation must not retain dead control-flow state',
)
assert.match(
  migration,
  /INSERT INTO public[.]membership_invitations[\s\S]*?EXCEPTION WHEN unique_violation THEN\s*SELECT i[.]id/,
  'only the unique-conflict handler may enter invitation conflict resolution',
)
assert.match(
  migration,
  /set_config\('rebuy[.]invite[.]op', 'create_audit', true\);[\s\S]*?RETURN QUERY SELECT v_new_invitation_id, v_expires_at;\s*RETURN;\s*END LOOP;/,
  'a successful insert must audit and return from inside the retry loop',
)

const executorPolicyStart = migration.indexOf(
  'CREATE POLICY profiles_executor_self_select',
)
const executorPolicyEnd = migration.indexOf(
  'REVOKE ALL PRIVILEGES ON TABLE',
  executorPolicyStart,
)
assert.ok(
  executorPolicyStart > -1 && executorPolicyEnd > executorPolicyStart,
  'the executor policy boundary must be present',
)
const executorPolicies = migration.slice(executorPolicyStart, executorPolicyEnd)
assert.doesNotMatch(
  executorPolicies,
  /(?<!\(SELECT )pg_catalog[.]current_setting\(/,
  'executor policies must cache current_setting calls in scalar SELECT init plans',
)

for (const [indexName, columns] of [
  [
    'memberships_source_invitation_idx',
    'source_invitation_id, organization_id, organization_type',
  ],
  [
    'membership_invitations_accepted_membership_idx',
    'accepted_membership_id, accepted_user_id, organization_id, organization_type',
  ],
  [
    'audit_logs_invitation_idx',
    'invitation_id, organization_id, organization_type',
  ],
  [
    'audit_logs_membership_idx',
    'membership_id, organization_id, organization_type',
  ],
]) {
  const whitespaceTolerantColumns = columns
    .split(/,\s*/)
    .join('\\s*,\\s*')
  assert.match(
    migration,
    new RegExp(
      `CREATE INDEX ${indexName}\\s+ON public[.][a-z_]+ \\(\\s*${whitespaceTolerantColumns}\\s*\\);`,
    ),
    `${indexName} must cover its composite foreign key in leading-column order`,
  )
}

for (const [testName, testSource] of [
  ['schema security pgTAP', schemaTest],
  ['invitation flow pgTAP', invitationTest],
]) {
  assert.match(
    testSource,
    /SET LOCAL search_path = pg_catalog, public, extensions;/,
    `${testName} must resolve pgTAP from the Supabase extensions schema`,
  )
}
assert.match(
  seed,
  /'00000000-0000-4000-8000-000000000106', 'member[.]invite'/,
  'seed must keep the canonical member.invite permission id',
)
assert.match(
  invitationTest,
  /'00000000-0000-4000-8000-000000000106', 'member[.]invite'/,
  'invitation fixtures must reuse the seeded member.invite permission id',
)
assert.match(
  seed,
  /'00000000-0000-4000-8000-000000000105', 'member[.]read'/,
  'seed must keep the canonical member.read permission id',
)
assert.match(
  invitationTest,
  /'00000000-0000-4000-8000-000000000105', 'member[.]read'/,
  'invitation fixtures must reuse the seeded member.read permission id',
)

function readTomlStringArray(source, key) {
  const match = source.match(new RegExp(`^${key}\\s*=\\s*\\[([^\\]]*)\\]`, 'm'))
  assert.ok(match, `${key} must be declared in supabase/config.toml`)
  return Array.from(match[1].matchAll(/"([^"]+)"/g), (item) => item[1])
}

assert.deepEqual(
  readTomlStringArray(config, 'schemas'),
  ['public', 'graphql_public'],
  'the Data API schema allowlist must not expose private',
)
assert.deepEqual(
  readTomlStringArray(config, 'extra_search_path'),
  ['public', 'extensions'],
  'the Data API request search path must not include private',
)

for (const functionName of [
  'create_membership_invitation',
  'accept_membership_invitation',
]) {
  assert.match(
    migration,
    new RegExp(
      `CREATE OR REPLACE FUNCTION public[.]${functionName}\\([\\s\\S]*?SECURITY INVOKER[\\s\\S]*?SET search_path = ''`,
    ),
    `${functionName} must remain a SECURITY INVOKER wrapper with an empty search_path`,
  )
  assert.match(
    migration,
    new RegExp(
      `CREATE OR REPLACE FUNCTION private[.]${functionName}_impl\\([\\s\\S]*?SECURITY DEFINER[\\s\\S]*?SET search_path = ''`,
    ),
    `${functionName}_impl must remain a SECURITY DEFINER implementation with an empty search_path`,
  )
}

for (const helperName of ['rebuy_request_uid', 'rebuy_request_jwt']) {
  assert.match(
    migration,
    new RegExp(
      `CREATE OR REPLACE FUNCTION private[.]${helperName}\\(\\)[\\s\\S]*?SECURITY INVOKER[\\s\\S]*?SET search_path = ''`,
    ),
    `${helperName} must be a project-owned invoker helper with an empty search_path`,
  )
  assert.match(
    migration,
    new RegExp(
      `REVOKE ALL PRIVILEGES ON FUNCTION private[.]${helperName}\\(\\)[\\s\\S]*?FROM PUBLIC, anon, authenticated, service_role, rebuy_invite_executor;[\\s\\S]*?GRANT EXECUTE ON FUNCTION private[.]${helperName}\\(\\)[\\s\\S]*?TO authenticated, rebuy_invite_executor;`,
    ),
    `${helperName} must be executable only by the two required roles`,
  )
}
assert.match(
  migration,
  /private[.]rebuy_request_jwt\(\)[\s\S]*?current_setting\('request[.]jwt[.]claim', true\)[\s\S]*?current_setting\('request[.]jwt[.]claims', true\)/,
  'the request claims helper must mirror both supported Supabase request GUCs',
)
assert.doesNotMatch(
  migration,
  /(?:GRANT|REVOKE)[^;]*(?:ON SCHEMA auth|ON FUNCTION auth[.](?:uid|jwt)\(\))[^;]*rebuy_invite_executor/is,
  'the isolated executor must not depend on grants in the platform-owned auth schema',
)
assert.doesNotMatch(
  migration,
  /(?:SELECT|:=)\s*auth[.](?:uid|jwt)\(\)/,
  'P2-L policies and implementations must use the project-owned request helpers',
)

const ownerHandoffMatch = migration.match(
  /DO \$owner_handoff\$([\s\S]*?)\$owner_handoff\$;/,
)
assert.ok(
  ownerHandoffMatch,
  'private function owner handoff must be contained in one atomic DO statement',
)
const ownerHandoff = ownerHandoffMatch[1]
const privateImplementationAcl = migration.indexOf(
  'REVOKE ALL PRIVILEGES ON FUNCTION private.create_membership_invitation_impl(',
)
assert.ok(
  privateImplementationAcl > -1 && privateImplementationAcl < ownerHandoffMatch.index,
  'private implementation ACLs must be finalized while postgres still owns the functions',
)
const afterOwnerHandoff = migration.slice(
  ownerHandoffMatch.index + ownerHandoffMatch[0].length,
)
assert.doesNotMatch(
  afterOwnerHandoff,
  /(?:GRANT|REVOKE)[^;]*FUNCTION private[.](?:create|accept)_membership_invitation_impl/is,
  'the migration runner must not mutate implementation ACLs after owner handoff',
)
const ownerHandoffSteps = [
  'rebuy_owner_handoff_precondition_invalid',
  "EXECUTE 'GRANT rebuy_invite_executor TO postgres WITH INHERIT FALSE GRANTED BY CURRENT_USER'",
  "EXECUTE 'GRANT CREATE ON SCHEMA private TO rebuy_invite_executor GRANTED BY CURRENT_USER'",
  'rebuy_owner_handoff_temporary_capability_invalid',
  "EXECUTE 'ALTER FUNCTION private.create_membership_invitation_impl(uuid, uuid, integer, text, uuid, text, uuid) OWNER TO rebuy_invite_executor'",
  "EXECUTE 'ALTER FUNCTION private.accept_membership_invitation_impl(uuid) OWNER TO rebuy_invite_executor'",
  "EXECUTE 'REVOKE rebuy_invite_executor FROM postgres GRANTED BY CURRENT_USER'",
  "EXECUTE 'REVOKE CREATE ON SCHEMA private FROM rebuy_invite_executor GRANTED BY CURRENT_USER'",
  'rebuy_owner_handoff_final_state_invalid',
]
let previousOwnerHandoffStep = -1
for (const step of ownerHandoffSteps) {
  const position = ownerHandoff.indexOf(step)
  assert.ok(position > previousOwnerHandoffStep, `${step} must be ordered atomically`)
  previousOwnerHandoffStep = position
}
assert.match(
  ownerHandoff,
  /grantor_role[.]rolname = 'postgres'[\s\S]*?NOT pam[.]admin_option[\s\S]*?NOT pam[.]inherit_option[\s\S]*?pam[.]set_option/,
  'the temporary membership must have only SET capability and the current runner as grantor',
)
assert.match(
  ownerHandoff,
  /SELECT count\(\*\)[\s\S]*?\) <> 1[\s\S]*?grantor_role[.]rolname = 'supabase_admin'[\s\S]*?NOT pam[.]set_option[\s\S]*?pg_has_role\([\s\S]*?'postgres', 'rebuy_invite_executor', 'SET'[\s\S]*?has_schema_privilege\([\s\S]*?'rebuy_invite_executor', 'private', 'CREATE'[\s\S]*?pg_get_userbyid\(procedure[.]proowner\) = 'rebuy_invite_executor'/,
  'the final guard must restore bootstrap-only membership and remove temporary privileges before returning',
)
assert.equal(
  Array.from(
    migration.matchAll(/OWNER TO rebuy_invite_executor/g),
  ).length,
  2,
  'the migration may transfer exactly two object owners to the invitation executor',
)

const tempResultGrant = invitationTest.indexOf(
  'GRANT ALL PRIVILEGES ON TABLE\n  pg_temp.p2l_create_result,',
)
const firstAuthenticatedRoleSwitch = invitationTest.indexOf(
  'SET LOCAL ROLE authenticated;',
)
assert.ok(
  tempResultGrant > -1 && tempResultGrant < firstAuthenticatedRoleSwitch,
  'pgTAP result tables must be granted before switching to authenticated',
)

let pgTapRole = 'postgres'
let insidePgTapSqlLiteral = false
for (const [lineIndex, line] of invitationTest.split('\n').entries()) {
  const wasInsidePgTapSqlLiteral = insidePgTapSqlLiteral
  const sqlDelimiterCount = line.match(/\$sql\$/g)?.length ?? 0
  if (sqlDelimiterCount % 2 === 1) {
    insidePgTapSqlLiteral = !insidePgTapSqlLiteral
  }
  if (wasInsidePgTapSqlLiteral || sqlDelimiterCount > 0) continue
  if (/^RESET ROLE;\s*$/.test(line)) pgTapRole = 'postgres'
  if (/^SET LOCAL ROLE authenticated;\s*$/.test(line)) pgTapRole = 'authenticated'
  assert.ok(
    !(
      pgTapRole === 'authenticated' &&
      /^\s*FROM public[.](?:membership_invitations|membership_store_scopes|memberships|audit_logs)\b/.test(
        line,
      )
    ),
    `pgTAP line ${lineIndex + 1} must not bypass the no-direct-table-grant contract`,
  )
}

function extractCallArguments(source, callName) {
  const start = source.indexOf(`${callName}(`)
  assert.notEqual(start, -1, `${callName} call must exist`)

  const openParen = start + callName.length
  let depth = 0
  let inSingleQuote = false

  for (let index = openParen; index < source.length; index += 1) {
    const character = source[index]
    const next = source[index + 1]

    if (character === "'" && inSingleQuote && next === "'") {
      index += 1
      continue
    }
    if (character === "'") {
      inSingleQuote = !inSingleQuote
      continue
    }
    if (inSingleQuote) continue

    if (character === '(') depth += 1
    if (character === ')') {
      depth -= 1
      if (depth === 0) {
        return source.slice(openParen + 1, index)
      }
    }
  }

  assert.fail(`${callName} call must have balanced parentheses`)
}

function countTopLevelArguments(argumentsSource) {
  let depth = 0
  let inSingleQuote = false
  let argumentCount = argumentsSource.trim() === '' ? 0 : 1

  for (let index = 0; index < argumentsSource.length; index += 1) {
    const character = argumentsSource[index]
    const next = argumentsSource[index + 1]

    if (character === "'" && inSingleQuote && next === "'") {
      index += 1
      continue
    }
    if (character === "'") {
      inSingleQuote = !inSingleQuote
      continue
    }
    if (inSingleQuote) continue

    if (character === '(') depth += 1
    if (character === ')') depth -= 1
    if (character === ',' && depth === 0) argumentCount += 1
  }

  return argumentCount
}

const advisoryLockArguments = extractCallArguments(
  migration,
  'pg_catalog.pg_advisory_xact_lock',
)
assert.equal(
  countTopLevelArguments(advisoryLockArguments),
  1,
  'pg_advisory_xact_lock must use its supported single-bigint overload',
)
assert.match(
  advisoryLockArguments,
  /pg_catalog[.]hashtextextended\(\s*pg_catalog[.]concat\(\s*v_uid::text,\s*':',\s*v_invitation_org_id::text\s*\),\s*0\s*\)/,
  'the advisory key must combine the accepting user and organization',
)

const acceptImplementationStart = migration.indexOf(
  'CREATE OR REPLACE FUNCTION private.accept_membership_invitation_impl(',
)
const acceptWrapperStart = migration.indexOf(
  'CREATE OR REPLACE FUNCTION public.accept_membership_invitation(',
)
assert.ok(
  acceptImplementationStart > -1 && acceptWrapperStart > acceptImplementationStart,
  'the accept implementation must precede its public wrapper',
)
const acceptImplementation = migration.slice(
  acceptImplementationStart,
  acceptWrapperStart,
)
for (const leakedStatusCode of [
  'accepted_membership_not_active',
  'accepted_scope_not_active',
  'creator_membership_not_active',
  'creator_role_not_active',
  'creator_permission_revoked',
  'creator_scope_not_active',
  'invitation_email_mismatch',
  'membership_already_exists',
  'store_not_available',
]) {
  assert.doesNotMatch(
    acceptImplementation,
    new RegExp(`RAISE EXCEPTION '${leakedStatusCode}'`),
    `accept must not expose internal status code ${leakedStatusCode}`,
  )
}
assert.match(
  acceptImplementation,
  /i[.]target_email_normalized, i[.]idempotency_key,[\s\S]*?INTO[\s\S]*?v_target_email,[\s\S]*?v_invitation_idempotency_key, v_invitation_status/,
  'accept must load the persisted invitation idempotency key under the row lock',
)
assert.match(
  acceptImplementation,
  /SELECT s[.]status[\s\S]*?set_config\('rebuy[.]invite[.]store_id', '', true\)[\s\S]*?set_config\('rebuy[.]invite[.]scope_type', 'organization', true\)[\s\S]*?ms[.]scope_type = 'organization'[\s\S]*?set_config\([\s\S]*?'rebuy[.]invite[.]store_id', v_invitation_store_id::text, true[\s\S]*?set_config\('rebuy[.]invite[.]scope_type', 'store', true\)[\s\S]*?ms[.]scope_type = 'store'[\s\S]*?ms[.]store_id = v_invitation_store_id[\s\S]*?set_config\([\s\S]*?'rebuy[.]invite[.]scope_type', v_invitation_scope_type, true/,
  'store accept must validate creator organization scope, fall back to exact store scope, and restore invitation context',
)
assert.match(
  acceptImplementation,
  /set_config\(\s*'rebuy[.]invite[.]op', 'accept_invitation', true\s*\);[\s\S]*?set_config\(\s*'rebuy[.]invite[.]idempotency_key', v_invitation_idempotency_key::text, true\s*\);[\s\S]*?set_config\(\s*'rebuy[.]invite[.]created_at', v_invitation_created_at::text, true\s*\);[\s\S]*?UPDATE public[.]membership_invitations/,
  'accept must restore immutable invitation fields before the RLS-checked update',
)
assert.match(
  acceptImplementation,
  /set_config\(\s*'rebuy[.]invite[.]op', 'accept_audit', true\s*\);[\s\S]*?set_config\(\s*'rebuy[.]invite[.]created_at', v_now::text, true\s*\);[\s\S]*?INSERT INTO public[.]audit_logs/,
  'accept must bind the acceptance audit timestamp after restoring invitation fields',
)

for (const requiredAcceptCoverage of [
  'accept rejects missing AMR timestamp even when iat is present',
  'accept rejects stale OTP evidence',
  'accept does not disclose target-email mismatch details',
  'direct private accept also requires OTP in the first AMR entry',
  'store accept writes exactly one active store scope',
  'accepted store invitation retry succeeds',
  'accepted store invitation retry returns the original membership',
  'second invitation for an existing organization membership is unavailable',
  'creator exact store scope is active before store accept',
  'accept hides revoked creator membership details',
  'accept hides revoked creator permission details',
  'accept hides revoked creator scope details',
  'accept hides retired creator role details',
  'accept hides unassignable candidate role details',
  'accept hides suspended organization details',
  'accept hides suspended store details',
]) {
  assert.ok(
    invitationTest.includes(requiredAcceptCoverage),
    `pgTAP must cover: ${requiredAcceptCoverage}`,
  )
}

for (const requiredConcurrencyCoverage of [
  'same_invitation_concurrency',
  'multi_invitation_concurrency',
  'multi_accepted_invitations',
  'multi_sent_invitations',
  'stable_retry_lookup',
  'stable_retry_parse',
  'stable_retry_accepted_call',
  'stable_retry_accepted_exit',
  'stable_retry_accepted_result',
  'stable_retry_unavailable_call',
  'stable_retry_unavailable_exit',
  'stable_retry_unavailable_error',
  'cleanup',
  'cleanup_verify',
  'failure_cleanup',
  'P2L_INVITATION_CONCURRENCY_PASS',
]) {
  assert.ok(
    concurrencyTest.includes(requiredConcurrencyCoverage),
    `concurrency harness must cover: ${requiredConcurrencyCoverage}`,
  )
}

function assertOrdered(source, fragments, message) {
  let previousIndex = -1
  for (const fragment of fragments) {
    const nextIndex = source.indexOf(fragment, previousIndex + 1)
    assert.ok(nextIndex > previousIndex, `${message}: ${fragment}`)
    previousIndex = nextIndex
  }
}

const cleanupStart = concurrencyTest.indexOf('const cleanupSql = `')
const cleanupEnd = concurrencyTest.indexOf(
  'const cleanupVerificationSql = `',
  cleanupStart,
)
assert.ok(
  cleanupStart > -1 && cleanupEnd > cleanupStart,
  'concurrency cleanup SQL boundary must be present',
)
const concurrencyCleanup = concurrencyTest.slice(cleanupStart, cleanupEnd)
assertOrdered(
  concurrencyCleanup,
  [
    'BEGIN;',
    'DELETE FROM public.audit_logs',
    'DELETE FROM public.membership_store_scopes',
    'UPDATE public.memberships',
    'SET source_invitation_id = NULL',
    'DELETE FROM public.membership_invitations',
    'DELETE FROM public.memberships',
    'DELETE FROM public.stores',
    'DELETE FROM public.organizations',
    'DELETE FROM auth.users',
    'COMMIT;',
  ],
  'concurrency cleanup must break the invitation/membership cycle and delete in dependency order',
)
assert.doesNotMatch(
  concurrencyCleanup,
  /\b(?:TRUNCATE|CASCADE)\b|DELETE FROM public[.]profiles/i,
  'concurrency cleanup must stay fixture-scoped and rely on the auth.users profile cascade',
)
assert.match(
  migration,
  /user_id uuid PRIMARY KEY REFERENCES auth[.]users \(id\) ON DELETE CASCADE/,
  'profiles must retain the auth.users delete cascade used by concurrency cleanup',
)
assert.doesNotMatch(
  concurrencyTest,
  /[.]catch\(\(\) => undefined\)/,
  'concurrency cleanup failures must not be silently swallowed',
)
assertOrdered(
  concurrencyTest,
  [
    "stage = 'stable_retry_lookup'",
    'const acceptedMultiRaw = await runAdmin(',
    "stage = 'stable_retry_parse'",
    'assert.match(acceptedMultiRaw,',
    '[IDS.multiInvitationA, IDS.multiInvitationB].includes(',
    'const expectedAcceptedStoreId =',
    "stage = 'stable_retry_accepted_call'",
    'const retry = await runPsql(',
    "stage = 'stable_retry_accepted_exit'",
    'assert.equal(retry.signal, null)',
    'assert.equal(retry.code, 0)',
    "stage = 'stable_retry_accepted_result'",
    '`${acceptedMembershipId}|${IDS.organization}|${expectedAcceptedStoreId}|store`',
    "stage = 'stable_retry_unavailable_call'",
    'const unavailableRetry = await runPsql(',
    "stage = 'stable_retry_unavailable_exit'",
    'assert.equal(unavailableRetry.signal, null)',
    'assert.notEqual(unavailableRetry.code, 0)',
    "stage = 'stable_retry_unavailable_error'",
    'assert.match(unavailableRetry.stderr, /invitation_not_available/)',
    "stage = 'cleanup'",
    "await runAdmin(cleanupSql, 'cleanup')",
    "stage = 'cleanup_verify'",
    'await runAdmin(cleanupVerificationSql, stage)',
    'assert.deepEqual(cleanupState, emptyCleanupState)',
  ],
  'concurrency harness must bind every retry and cleanup assertion to a precise stage',
)
assert.match(
  concurrencyTest,
  /assert[.]match\(acceptedMultiRaw, \/\^\[0-9a-f-\]\{36\}\\\|\[0-9a-f-\]\{36\}\$\//,
  'accepted invitation lookup must parse exactly one invitation/membership row',
)
assert.match(
  concurrencyTest,
  /assert[.]doesNotMatch\(\s*unavailableRetry[.]stderr,\s*\/creator_\|role_not_\|permission_\|scope_not_\|store_not_\|membership_already\//,
  'unavailable retry must expose only the generic public error',
)
assert.match(
  concurrencyTest,
  /const failureStage = stage[\s\S]*?stage = 'failure_cleanup'[\s\S]*?cleanupOutcome = 'cleanup_pass'[\s\S]*?P2L_INVITATION_CONCURRENCY_FAIL:\$\{failureStage\}:\$\{cleanupOutcome\}/,
  'failure output must preserve the original stage and report verified cleanup outcome',
)

console.log('P2L_MIGRATION_STRUCTURE_PASS')
