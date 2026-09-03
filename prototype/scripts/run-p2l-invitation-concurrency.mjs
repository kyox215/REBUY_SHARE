import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'

const DB_CONTAINER =
  'supabase_db_rebuy-g2-a1-e2a-local-email-otp-exec'
const IDS = {
  creator: '10000000-0000-4000-8000-000000000001',
  sameTarget: '10000000-0000-4000-8000-000000000002',
  multiTarget: '10000000-0000-4000-8000-000000000003',
  organization: '10000000-0000-4000-8000-000000000101',
  storeA: '10000000-0000-4000-8000-000000000201',
  storeB: '10000000-0000-4000-8000-000000000202',
  creatorMembership: '10000000-0000-4000-8000-000000000301',
  creatorScope: '10000000-0000-4000-8000-000000000401',
  sameInvitation: '10000000-0000-4000-8000-000000000501',
  multiInvitationA: '10000000-0000-4000-8000-000000000502',
  multiInvitationB: '10000000-0000-4000-8000-000000000503',
}

function startPsql(sql) {
  const child = spawn(
    'docker',
    [
      'exec',
      '-i',
      DB_CONTAINER,
      'psql',
      '-X',
      '-q',
      '-v',
      'ON_ERROR_STOP=1',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-A',
      '-t',
    ],
    { stdio: ['pipe', 'pipe', 'pipe'] },
  )

  let stdout = ''
  let stderr = ''
  child.stdout.setEncoding('utf8')
  child.stderr.setEncoding('utf8')
  child.stdout.on('data', (chunk) => {
    stdout += chunk
    if (stdout.length > 131_072) child.kill('SIGTERM')
  })
  child.stderr.on('data', (chunk) => {
    stderr += chunk
    if (stderr.length > 131_072) child.kill('SIGTERM')
  })
  child.stdin.end(sql)

  const result = new Promise((resolve, reject) => {
    child.on('error', reject)
    child.on('close', (code, signal) => {
      resolve({ code, signal, stdout, stderr })
    })
  })
  return { child, result, readStdout: () => stdout }
}

async function runPsql(sql) {
  return startPsql(sql).result
}

async function runAdmin(sql, stage) {
  const result = await runPsql(sql)
  assert.equal(result.signal, null, `${stage}:signal`)
  assert.equal(result.code, 0, `${stage}:exit`)
  return result.stdout.trim()
}

function claimsSql(userId, email) {
  return `
DO $claims$
BEGIN
  PERFORM pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', '${userId}',
      'email', '${email}',
      'is_anonymous', false,
      'amr', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'method', 'otp',
          'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
        )
      )
    )::text,
    true
  );
END
$claims$;
`
}

function acceptSql(invitationId, userId, email) {
  return `
BEGIN;
SET LOCAL ROLE authenticated;
${claimsSql(userId, email)}
SELECT membership_id::text || '|' || organization_id::text || '|' ||
       COALESCE(store_id::text, '') || '|' || scope_type
FROM public.accept_membership_invitation('${invitationId}');
COMMIT;
`
}

function lockSql(userId) {
  return `
BEGIN;
SELECT pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended(
    pg_catalog.concat('${userId}', ':', '${IDS.organization}'), 0
  )
);
SELECT 'LOCK_READY';
SELECT pg_catalog.pg_sleep(2);
COMMIT;
`
}

async function waitForLock(blocker) {
  const deadline = Date.now() + 10_000
  while (!blocker.readStdout().includes('LOCK_READY')) {
    if (Date.now() >= deadline) throw new Error('lock_timeout')
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
}

async function runConcurrentAccepts({ userId, email, invitationIds }) {
  const blocker = startPsql(lockSql(userId))
  await waitForLock(blocker)
  const attempts = invitationIds.map((invitationId) =>
    runPsql(acceptSql(invitationId, userId, email)),
  )
  const [blockerResult, results] = await Promise.all([
    blocker.result,
    Promise.all(attempts),
  ])
  assert.equal(blockerResult.code, 0, 'lock_release:exit')
  assert.equal(blockerResult.signal, null, 'lock_release:signal')
  return results
}

const cleanupSql = `
BEGIN;
DELETE FROM public.audit_logs
WHERE invitation_id IN (
  '${IDS.sameInvitation}', '${IDS.multiInvitationA}', '${IDS.multiInvitationB}'
);
DELETE FROM public.membership_store_scopes
WHERE organization_id = '${IDS.organization}';
UPDATE public.memberships
SET source_invitation_id = NULL
WHERE organization_id = '${IDS.organization}'
  AND source_invitation_id IN (
    '${IDS.sameInvitation}', '${IDS.multiInvitationA}', '${IDS.multiInvitationB}'
  );
DELETE FROM public.membership_invitations
WHERE organization_id = '${IDS.organization}';
DELETE FROM public.memberships
WHERE organization_id = '${IDS.organization}';
DELETE FROM public.stores
WHERE organization_id = '${IDS.organization}';
DELETE FROM public.organizations
WHERE id = '${IDS.organization}';
DELETE FROM auth.users
WHERE id IN ('${IDS.creator}', '${IDS.sameTarget}', '${IDS.multiTarget}');
COMMIT;
`

const cleanupVerificationSql = `
SELECT pg_catalog.jsonb_build_object(
  'audit_logs', (SELECT count(*) FROM public.audit_logs WHERE invitation_id IN ('${IDS.sameInvitation}', '${IDS.multiInvitationA}', '${IDS.multiInvitationB}')),
  'scopes', (SELECT count(*) FROM public.membership_store_scopes WHERE organization_id = '${IDS.organization}'),
  'memberships', (SELECT count(*) FROM public.memberships WHERE organization_id = '${IDS.organization}'),
  'invitations', (SELECT count(*) FROM public.membership_invitations WHERE organization_id = '${IDS.organization}'),
  'stores', (SELECT count(*) FROM public.stores WHERE organization_id = '${IDS.organization}'),
  'organizations', (SELECT count(*) FROM public.organizations WHERE id = '${IDS.organization}'),
  'profiles', (SELECT count(*) FROM public.profiles WHERE user_id IN ('${IDS.creator}', '${IDS.sameTarget}', '${IDS.multiTarget}')),
  'users', (SELECT count(*) FROM auth.users WHERE id IN ('${IDS.creator}', '${IDS.sameTarget}', '${IDS.multiTarget}'))
)::text;
`

const emptyCleanupState = {
  audit_logs: 0,
  scopes: 0,
  memberships: 0,
  invitations: 0,
  stores: 0,
  organizations: 0,
  profiles: 0,
  users: 0,
}

const setupSql = `
${cleanupSql}
INSERT INTO auth.users (
  id, email, raw_app_meta_data, raw_user_meta_data, role, aud
)
VALUES
  ('${IDS.creator}', 'p2l-concurrent-creator@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.sameTarget}', 'p2l-concurrent-same@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.multiTarget}', 'p2l-concurrent-multi@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated');

INSERT INTO public.organizations (
  id, organization_type, display_name, status, created_by
)
VALUES (
  '${IDS.organization}', 'merchant', 'P2L Concurrent Org', 'active', '${IDS.creator}'
);

INSERT INTO public.stores (
  id, organization_id, organization_type, display_name, slug, status
)
VALUES
  ('${IDS.storeA}', '${IDS.organization}', 'merchant', 'P2L Concurrent A', 'p2l-concurrent-a', 'active'),
  ('${IDS.storeB}', '${IDS.organization}', 'merchant', 'P2L Concurrent B', 'p2l-concurrent-b', 'active');

INSERT INTO public.memberships (
  id, user_id, organization_id, organization_type,
  role_definition_id, role_version, status, valid_from
)
VALUES (
  '${IDS.creatorMembership}', '${IDS.creator}', '${IDS.organization}', 'merchant',
  '00000000-0000-4000-8000-000000000201', 1, 'active',
  pg_catalog.statement_timestamp() - INTERVAL '1 hour'
);

INSERT INTO public.membership_store_scopes (
  id, membership_id, organization_id, organization_type,
  scope_type, status
)
VALUES (
  '${IDS.creatorScope}', '${IDS.creatorMembership}', '${IDS.organization}',
  'merchant', 'organization', 'active'
);

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
VALUES
  (
    '${IDS.sameInvitation}', '${IDS.organization}', 'merchant', NULL,
    '00000000-0000-4000-8000-000000000201', 1, NULL, NULL,
    'organization', 'p2l-concurrent-same@rebuy.test',
    '10000000-0000-4000-8000-000000000601',
    '${IDS.creatorMembership}', '${IDS.creator}',
    '00000000-0000-4000-8000-000000000201', 1, NULL, NULL,
    'active', 'sent', pg_catalog.statement_timestamp() + INTERVAL '1 hour',
    pg_catalog.statement_timestamp(), pg_catalog.statement_timestamp()
  ),
  (
    '${IDS.multiInvitationA}', '${IDS.organization}', 'merchant', '${IDS.storeA}',
    '00000000-0000-4000-8000-000000000202', 1, NULL, NULL,
    'store', 'p2l-concurrent-multi@rebuy.test',
    '10000000-0000-4000-8000-000000000602',
    '${IDS.creatorMembership}', '${IDS.creator}',
    '00000000-0000-4000-8000-000000000201', 1, NULL, NULL,
    'active', 'sent', pg_catalog.statement_timestamp() + INTERVAL '1 hour',
    pg_catalog.statement_timestamp(), pg_catalog.statement_timestamp()
  ),
  (
    '${IDS.multiInvitationB}', '${IDS.organization}', 'merchant', '${IDS.storeB}',
    '00000000-0000-4000-8000-000000000202', 1, NULL, NULL,
    'store', 'p2l-concurrent-multi@rebuy.test',
    '10000000-0000-4000-8000-000000000603',
    '${IDS.creatorMembership}', '${IDS.creator}',
    '00000000-0000-4000-8000-000000000201', 1, NULL, NULL,
    'active', 'sent', pg_catalog.statement_timestamp() + INTERVAL '1 hour',
    pg_catalog.statement_timestamp(), pg_catalog.statement_timestamp()
  );
`

let stage = 'setup'
try {
  await runAdmin(setupSql, stage)

  stage = 'same_invitation_concurrency'
  const sameResults = await runConcurrentAccepts({
    userId: IDS.sameTarget,
    email: 'p2l-concurrent-same@rebuy.test',
    invitationIds: [IDS.sameInvitation, IDS.sameInvitation],
  })
  assert.ok(sameResults.every((result) => result.code === 0))
  const sameOutputs = sameResults.map((result) => result.stdout.trim())
  assert.equal(sameOutputs[0], sameOutputs[1])
  assert.match(sameOutputs[0], /^[0-9a-f-]{36}\|[0-9a-f-]{36}\|\|organization$/)

  stage = 'multi_invitation_concurrency'
  const multiResults = await runConcurrentAccepts({
    userId: IDS.multiTarget,
    email: 'p2l-concurrent-multi@rebuy.test',
    invitationIds: [IDS.multiInvitationA, IDS.multiInvitationB],
  })
  const multiSuccesses = multiResults.filter((result) => result.code === 0)
  const multiFailures = multiResults.filter((result) => result.code !== 0)
  assert.equal(multiSuccesses.length, 1)
  assert.equal(multiFailures.length, 1)
  assert.match(multiFailures[0].stderr, /invitation_not_available/)
  assert.doesNotMatch(
    multiFailures[0].stderr,
    /creator_|role_not_|permission_|scope_not_|store_not_|membership_already/,
  )

  stage = 'final_state'
  const finalState = JSON.parse(
    await runAdmin(
      `
SELECT pg_catalog.jsonb_build_object(
  'same_memberships', (SELECT count(*) FROM public.memberships WHERE user_id = '${IDS.sameTarget}' AND organization_id = '${IDS.organization}'),
  'same_scopes', (SELECT count(*) FROM public.membership_store_scopes AS ms JOIN public.memberships AS m ON m.id = ms.membership_id WHERE m.user_id = '${IDS.sameTarget}' AND m.organization_id = '${IDS.organization}'),
  'same_audits', (SELECT count(*) FROM public.audit_logs WHERE invitation_id = '${IDS.sameInvitation}' AND event_code = 'membership_invitation.accepted'),
  'multi_memberships', (SELECT count(*) FROM public.memberships WHERE user_id = '${IDS.multiTarget}' AND organization_id = '${IDS.organization}'),
  'multi_scopes', (SELECT count(*) FROM public.membership_store_scopes AS ms JOIN public.memberships AS m ON m.id = ms.membership_id WHERE m.user_id = '${IDS.multiTarget}' AND m.organization_id = '${IDS.organization}'),
  'multi_accepted_invitations', (SELECT count(*) FROM public.membership_invitations WHERE id IN ('${IDS.multiInvitationA}', '${IDS.multiInvitationB}') AND status = 'accepted'),
  'multi_sent_invitations', (SELECT count(*) FROM public.membership_invitations WHERE id IN ('${IDS.multiInvitationA}', '${IDS.multiInvitationB}') AND status = 'sent'),
  'multi_audits', (SELECT count(*) FROM public.audit_logs WHERE invitation_id IN ('${IDS.multiInvitationA}', '${IDS.multiInvitationB}') AND event_code = 'membership_invitation.accepted')
)::text;
`,
      stage,
    ),
  )
  assert.deepEqual(finalState, {
    same_memberships: 1,
    same_scopes: 1,
    same_audits: 1,
    multi_memberships: 1,
    multi_scopes: 1,
    multi_accepted_invitations: 1,
    multi_sent_invitations: 1,
    multi_audits: 1,
  })

  stage = 'stable_retry_lookup'
  const acceptedMultiRaw = await runAdmin(
    `
SELECT id::text || '|' || accepted_membership_id::text
FROM public.membership_invitations
WHERE id IN ('${IDS.multiInvitationA}', '${IDS.multiInvitationB}')
  AND status = 'accepted';
`,
    stage,
  )
  stage = 'stable_retry_parse'
  assert.match(acceptedMultiRaw, /^[0-9a-f-]{36}\|[0-9a-f-]{36}$/)
  const acceptedMulti = acceptedMultiRaw.split('|')
  assert.equal(acceptedMulti.length, 2)
  const [acceptedInvitationId, acceptedMembershipId] = acceptedMulti
  assert.ok(
    [IDS.multiInvitationA, IDS.multiInvitationB].includes(
      acceptedInvitationId,
    ),
  )
  assert.match(acceptedMembershipId, /^[0-9a-f-]{36}$/)
  const expectedAcceptedStoreId =
    acceptedInvitationId === IDS.multiInvitationA ? IDS.storeA : IDS.storeB
  stage = 'stable_retry_accepted_call'
  const retry = await runPsql(
    acceptSql(
      acceptedInvitationId,
      IDS.multiTarget,
      'p2l-concurrent-multi@rebuy.test',
    ),
  )
  stage = 'stable_retry_accepted_exit'
  assert.equal(retry.signal, null)
  assert.equal(retry.code, 0)
  stage = 'stable_retry_accepted_result'
  assert.equal(
    retry.stdout.trim(),
    `${acceptedMembershipId}|${IDS.organization}|${expectedAcceptedStoreId}|store`,
  )

  const unavailableMulti =
    acceptedInvitationId === IDS.multiInvitationA
      ? IDS.multiInvitationB
      : IDS.multiInvitationA
  stage = 'stable_retry_unavailable_call'
  const unavailableRetry = await runPsql(
    acceptSql(
      unavailableMulti,
      IDS.multiTarget,
      'p2l-concurrent-multi@rebuy.test',
    ),
  )
  stage = 'stable_retry_unavailable_exit'
  assert.equal(unavailableRetry.signal, null)
  assert.notEqual(unavailableRetry.code, 0)
  stage = 'stable_retry_unavailable_error'
  assert.match(unavailableRetry.stderr, /invitation_not_available/)
  assert.doesNotMatch(
    unavailableRetry.stderr,
    /creator_|role_not_|permission_|scope_not_|store_not_|membership_already/,
  )

  stage = 'cleanup'
  await runAdmin(cleanupSql, 'cleanup')
  stage = 'cleanup_verify'
  const cleanupState = JSON.parse(
    await runAdmin(cleanupVerificationSql, stage),
  )
  assert.deepEqual(cleanupState, emptyCleanupState)
  console.log('P2L_INVITATION_CONCURRENCY_PASS')
} catch {
  const failureStage = stage
  stage = 'failure_cleanup'
  let cleanupOutcome = 'cleanup_fail'
  try {
    const cleanupResult = await runPsql(cleanupSql)
    if (cleanupResult.signal === null && cleanupResult.code === 0) {
      const verificationResult = await runPsql(cleanupVerificationSql)
      if (
        verificationResult.signal === null &&
        verificationResult.code === 0 &&
        JSON.stringify(JSON.parse(verificationResult.stdout.trim())) ===
          JSON.stringify(emptyCleanupState)
      ) {
        cleanupOutcome = 'cleanup_pass'
      }
    }
  } catch {
    cleanupOutcome = 'cleanup_fail'
  }
  console.error(
    `P2L_INVITATION_CONCURRENCY_FAIL:${failureStage}:${cleanupOutcome}`,
  )
  process.exitCode = 1
}
