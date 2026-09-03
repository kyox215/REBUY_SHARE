import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'

const DB_CONTAINER = 'supabase_db_rebuy-g2-a1-e2a-local-email-otp-exec'
const IDS = {
  sameApplicant: '20000000-0000-4000-8000-000000000001',
  conflictApplicant: '20000000-0000-4000-8000-000000000002',
  raceApplicant: '20000000-0000-4000-8000-000000000003',
  reviewer: '20000000-0000-4000-8000-000000000004',
  platform: '20000000-0000-4000-8000-000000000101',
  reviewerMembership: '20000000-0000-4000-8000-000000000201',
  sameApplication: '20000000-0000-4000-8000-000000000301',
  conflictApplication: '20000000-0000-4000-8000-000000000302',
  raceApplication: '20000000-0000-4000-8000-000000000303',
  sameKey: '20000000-0000-4000-8000-000000000401',
  conflictKeyA: '20000000-0000-4000-8000-000000000402',
  conflictKeyB: '20000000-0000-4000-8000-000000000403',
  saveKey: '20000000-0000-4000-8000-000000000404',
  withdrawKey: '20000000-0000-4000-8000-000000000405',
}

const applicantIds = [
  IDS.sameApplicant,
  IDS.conflictApplicant,
  IDS.raceApplicant,
]
const userIds = [...applicantIds, IDS.reviewer]
const applicationIds = [
  IDS.sameApplication,
  IDS.conflictApplication,
  IDS.raceApplication,
]
const sqlList = (values) => values.map((value) => `'${value}'`).join(', ')
const activeResults = new Set()

function startPsql(sql) {
  const child = spawn(
    'docker',
    [
      'exec', '-i', DB_CONTAINER, 'psql', '-X', '-q', '-v',
      'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres', '-A', '-t',
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
  const rawResult = new Promise((resolve, reject) => {
    child.on('error', reject)
    child.on('close', (code, signal) => {
      resolve({ code, signal, stdout, stderr })
    })
  })
  const result = rawResult.finally(() => activeResults.delete(result))
  activeResults.add(result)
  return { result, readStdout: () => stdout }
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

const cleanupSql = `
BEGIN;
DELETE FROM public.merchant_applications
WHERE id IN (${sqlList(applicationIds)})
   OR applicant_user_id IN (${sqlList(applicantIds)});
DELETE FROM public.membership_store_scopes
WHERE membership_id IN (
  SELECT m.id FROM public.memberships AS m
  WHERE m.organization_id = '${IDS.platform}'
     OR m.organization_id IN (
       SELECT o.id FROM public.organizations AS o
       WHERE o.created_by IN (${sqlList(applicantIds)})
     )
);
DELETE FROM public.memberships
WHERE id = '${IDS.reviewerMembership}'
   OR organization_id = '${IDS.platform}'
   OR organization_id IN (
     SELECT o.id FROM public.organizations AS o
     WHERE o.created_by IN (${sqlList(applicantIds)})
   );
DELETE FROM public.stores
WHERE organization_id IN (
  SELECT o.id FROM public.organizations AS o
  WHERE o.created_by IN (${sqlList(applicantIds)})
);
DELETE FROM public.organizations
WHERE id = '${IDS.platform}' OR created_by IN (${sqlList(applicantIds)});
DELETE FROM public.profiles WHERE user_id IN (${sqlList(userIds)});
DELETE FROM auth.users WHERE id IN (${sqlList(userIds)});
COMMIT;
`

const cleanupVerificationSql = `
SELECT pg_catalog.jsonb_build_object(
  'applications', (SELECT count(*) FROM public.merchant_applications WHERE id IN (${sqlList(applicationIds)}) OR applicant_user_id IN (${sqlList(applicantIds)})),
  'private_rows', (SELECT count(*) FROM public.merchant_application_private WHERE application_id IN (${sqlList(applicationIds)}) OR applicant_user_id IN (${sqlList(applicantIds)})),
  'events', (SELECT count(*) FROM public.merchant_application_events WHERE application_id IN (${sqlList(applicationIds)})),
  'scopes', (SELECT count(*) FROM public.membership_store_scopes AS ms JOIN public.memberships AS m ON m.id = ms.membership_id JOIN public.organizations AS o ON o.id = m.organization_id WHERE o.id = '${IDS.platform}' OR o.created_by IN (${sqlList(applicantIds)})),
  'memberships', (SELECT count(*) FROM public.memberships AS m JOIN public.organizations AS o ON o.id = m.organization_id WHERE o.id = '${IDS.platform}' OR o.created_by IN (${sqlList(applicantIds)})),
  'stores', (SELECT count(*) FROM public.stores AS s JOIN public.organizations AS o ON o.id = s.organization_id WHERE o.created_by IN (${sqlList(applicantIds)})),
  'organizations', (SELECT count(*) FROM public.organizations WHERE id = '${IDS.platform}' OR created_by IN (${sqlList(applicantIds)})),
  'profiles', (SELECT count(*) FROM public.profiles WHERE user_id IN (${sqlList(userIds)})),
  'users', (SELECT count(*) FROM auth.users WHERE id IN (${sqlList(userIds)}))
)::text;
`

const setupSql = `
${cleanupSql}
INSERT INTO auth.users (
  id, email, raw_app_meta_data, raw_user_meta_data, role, aud
)
VALUES
  ('${IDS.sameApplicant}', 'p3-concurrent-same@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.conflictApplicant}', 'p3-concurrent-conflict@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.raceApplicant}', 'p3-concurrent-race@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated'),
  ('${IDS.reviewer}', 'p3-concurrent-reviewer@rebuy.test', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated');
INSERT INTO public.organizations (
  id, organization_type, display_name, status, created_by
)
VALUES (
  '${IDS.platform}', 'platform', 'P3 Concurrent Platform', 'active', '${IDS.reviewer}'
);
INSERT INTO public.memberships (
  id, user_id, organization_id, organization_type,
  role_definition_id, role_version, status, valid_from
)
VALUES (
  '${IDS.reviewerMembership}', '${IDS.reviewer}', '${IDS.platform}', 'platform',
  '00000000-0000-4000-8000-000000000204', 1, 'active',
  pg_catalog.statement_timestamp() - INTERVAL '1 hour'
);
INSERT INTO public.merchant_applications (
  id, applicant_user_id, display_name, country_code, requested_store_slug,
  status, assigned_reviewer_membership_id, assigned_at, submitted_at
)
VALUES
  ('${IDS.sameApplication}', '${IDS.sameApplicant}', 'P3 Same Key Merchant', 'IT', 'p3-same-key-store', 'under_review', '${IDS.reviewerMembership}', pg_catalog.statement_timestamp(), pg_catalog.statement_timestamp()),
  ('${IDS.conflictApplication}', '${IDS.conflictApplicant}', 'P3 Conflict Merchant', 'FR', 'p3-conflict-store', 'under_review', '${IDS.reviewerMembership}', pg_catalog.statement_timestamp(), pg_catalog.statement_timestamp()),
  ('${IDS.raceApplication}', '${IDS.raceApplicant}', 'P3 Race Merchant', 'DE', 'p3-race-store', 'draft', NULL, NULL, NULL);
INSERT INTO public.merchant_application_private (
  application_id, applicant_user_id, registration_reference, evidence_reference
)
VALUES
  ('${IDS.sameApplication}', '${IDS.sameApplicant}', 'SYN-CONCURRENT-SAME', 'synthetic://merchant/concurrent-same'),
  ('${IDS.conflictApplication}', '${IDS.conflictApplicant}', 'SYN-CONCURRENT-CONFLICT', 'synthetic://merchant/concurrent-conflict'),
  ('${IDS.raceApplication}', '${IDS.raceApplicant}', 'SYN-CONCURRENT-RACE', 'synthetic://merchant/concurrent-race');
`

function claimsSql(userId, email) {
  return `
DO $claims$
BEGIN
  PERFORM pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', '${userId}', 'email', '${email}', 'is_anonymous', false,
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

function approvalSql(applicationId, idempotencyKey) {
  return `
BEGIN;
SET LOCAL ROLE authenticated;
${claimsSql(IDS.reviewer, 'p3-concurrent-reviewer@rebuy.test')}
SELECT application_status || '|' || organization_id::text || '|' ||
  store_id::text || '|' || owner_membership_id::text
FROM public.review_merchant_application(
  '${applicationId}', 'approve', 'approved_checks_complete',
  '${idempotencyKey}'
);
COMMIT;
`
}

function saveSql() {
  return `
BEGIN;
SET LOCAL application_name = 'p3_save_withdraw_save';
SET LOCAL ROLE authenticated;
${claimsSql(IDS.raceApplicant, 'p3-concurrent-race@rebuy.test')}
SELECT application_id::text || '|' || application_status
FROM public.save_merchant_application(
  'P3 Race Merchant Updated', 'DE', 'p3-race-store',
  'SYN-CONCURRENT-RACE', 'synthetic://merchant/concurrent-race-updated',
  false, '${IDS.saveKey}'
);
COMMIT;
`
}

function withdrawSql() {
  return `
BEGIN;
SET LOCAL application_name = 'p3_save_withdraw_withdraw';
SET LOCAL ROLE authenticated;
${claimsSql(IDS.raceApplicant, 'p3-concurrent-race@rebuy.test')}
SELECT application_id::text || '|' || application_status
FROM public.withdraw_merchant_application(
  '${IDS.raceApplication}', '${IDS.withdrawKey}'
);
COMMIT;
`
}

function blockerSql(applicationId) {
  return `
BEGIN;
SELECT pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('${applicationId}', 0)
);
SELECT 'LOCK_READY';
SELECT pg_catalog.pg_sleep(3);
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

async function waitForDatabaseLock(applicationName) {
  const deadline = Date.now() + 2_500
  while (Date.now() < deadline) {
    const waiting = await runAdmin(
      `SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE application_name = '${applicationName}' AND wait_event_type = 'Lock';`,
      'wait_for_database_lock',
    )
    if (waiting === '1') return
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
  throw new Error('database_lock_timeout')
}

function parseApproval(output, stage) {
  assert.match(
    output,
    /^approved\|[0-9a-f-]{36}\|[0-9a-f-]{36}\|[0-9a-f-]{36}$/,
    `${stage}:result_shape`,
  )
  const [status, organizationId, storeId, ownerMembershipId] = output.split('|')
  return { status, organizationId, storeId, ownerMembershipId }
}

async function assertApprovalState(applicationId, applicantId, expected, stage) {
  const state = JSON.parse(
    await runAdmin(
      `
SELECT pg_catalog.jsonb_build_object(
  'application_status', a.status,
  'organization_id', a.organization_id,
  'store_id', a.store_id,
  'owner_membership_id', a.owner_membership_id,
  'approval_events', (SELECT count(*) FROM public.merchant_application_events AS e WHERE e.application_id = a.id AND e.event_code = 'merchant_application.approved'),
  'merchant_organizations', (SELECT count(*) FROM public.organizations AS o WHERE o.id = a.organization_id AND o.created_by = '${applicantId}' AND o.organization_type = 'merchant'),
  'merchant_stores', (SELECT count(*) FROM public.stores AS s WHERE s.id = a.store_id AND s.organization_id = a.organization_id),
  'owner_memberships', (SELECT count(*) FROM public.memberships AS m WHERE m.id = a.owner_membership_id AND m.organization_id = a.organization_id AND m.user_id = '${applicantId}' AND m.role_definition_id = '00000000-0000-4000-8000-000000000201'),
  'owner_scopes', (SELECT count(*) FROM public.membership_store_scopes AS ms WHERE ms.membership_id = a.owner_membership_id AND ms.organization_id = a.organization_id AND ms.scope_type = 'organization')
)
FROM public.merchant_applications AS a
WHERE a.id = '${applicationId}';
`,
      stage,
    ),
  )
  assert.equal(state.application_status, expected.status, `${stage}:status`)
  assert.equal(state.organization_id, expected.organizationId, `${stage}:organization_ref`)
  assert.equal(state.store_id, expected.storeId, `${stage}:store_ref`)
  assert.equal(
    state.owner_membership_id,
    expected.ownerMembershipId,
    `${stage}:owner_membership_ref`,
  )
  for (const key of [
    'approval_events', 'merchant_organizations', 'merchant_stores',
    'owner_memberships', 'owner_scopes',
  ]) {
    assert.equal(state[key], 1, `${stage}:${key}`)
  }
}

let failureStage = 'setup'
let primaryError
let cleanupError
try {
  await runAdmin(setupSql, 'setup')

  failureStage = 'same_key_approval'
  const sameBlocker = startPsql(blockerSql(IDS.sameApplication))
  await waitForLock(sameBlocker)
  const sameAttempts = [
    runPsql(approvalSql(IDS.sameApplication, IDS.sameKey)),
    runPsql(approvalSql(IDS.sameApplication, IDS.sameKey)),
  ]
  const [sameBlockerResult, sameResults] = await Promise.all([
    sameBlocker.result,
    Promise.all(sameAttempts),
  ])
  assert.equal(sameBlockerResult.signal, null, 'same_key:blocker_signal')
  assert.equal(sameBlockerResult.code, 0, 'same_key:blocker_exit')
  for (const result of sameResults) {
    assert.equal(result.signal, null, 'same_key:signal')
    assert.equal(result.code, 0, 'same_key:exit')
  }
  const sameOutputs = sameResults.map((result) => result.stdout.trim())
  assert.equal(sameOutputs[0], sameOutputs[1], 'same_key:stable_result')
  const sameApproval = parseApproval(sameOutputs[0], 'same_key')
  await assertApprovalState(
    IDS.sameApplication, IDS.sameApplicant, sameApproval, 'same_key_state',
  )

  failureStage = 'different_key_approval'
  const conflictBlocker = startPsql(blockerSql(IDS.conflictApplication))
  await waitForLock(conflictBlocker)
  const conflictAttempts = [
    runPsql(approvalSql(IDS.conflictApplication, IDS.conflictKeyA)),
    runPsql(approvalSql(IDS.conflictApplication, IDS.conflictKeyB)),
  ]
  const [conflictBlockerResult, conflictResults] = await Promise.all([
    conflictBlocker.result,
    Promise.all(conflictAttempts),
  ])
  assert.equal(conflictBlockerResult.signal, null, 'different_key:blocker_signal')
  assert.equal(conflictBlockerResult.code, 0, 'different_key:blocker_exit')
  for (const result of conflictResults) {
    assert.equal(result.signal, null, 'different_key:signal')
  }
  const successfulConflictResults = conflictResults.filter(
    (result) => result.code === 0,
  )
  const rejectedConflictResults = conflictResults.filter(
    (result) => result.code !== 0,
  )
  assert.equal(successfulConflictResults.length, 1, 'different_key:one_success')
  assert.equal(rejectedConflictResults.length, 1, 'different_key:one_rejection')
  assert.match(
    rejectedConflictResults[0].stderr,
    /ERROR:\s+merchant_application_state_conflict/,
    'different_key:expected_state_conflict',
  )
  assert.doesNotMatch(
    rejectedConflictResults[0].stderr,
    /deadlock detected|statement timeout|lock timeout/i,
    'different_key:no_lock_failure',
  )
  const conflictApproval = parseApproval(
    successfulConflictResults[0].stdout.trim(),
    'different_key',
  )
  await assertApprovalState(
    IDS.conflictApplication,
    IDS.conflictApplicant,
    conflictApproval,
    'different_key_state',
  )

  failureStage = 'save_withdraw_race'
  const raceBlocker = startPsql(blockerSql(IDS.raceApplication))
  await waitForLock(raceBlocker)
  const saveAttempt = runPsql(saveSql())
  await waitForDatabaseLock('p3_save_withdraw_save')
  const withdrawAttempt = runPsql(withdrawSql())
  const [raceBlockerResult, saveResult, withdrawResult] = await Promise.all([
    raceBlocker.result,
    saveAttempt,
    withdrawAttempt,
  ])
  assert.equal(raceBlockerResult.signal, null, 'save_withdraw:blocker_signal')
  assert.equal(raceBlockerResult.code, 0, 'save_withdraw:blocker_exit')
  assert.equal(saveResult.signal, null, 'save_withdraw:save_signal')
  assert.equal(saveResult.code, 0, 'save_withdraw:save_exit')
  assert.equal(withdrawResult.signal, null, 'save_withdraw:withdraw_signal')
  assert.equal(withdrawResult.code, 0, 'save_withdraw:withdraw_exit')
  assert.equal(
    saveResult.stdout.trim(),
    `${IDS.raceApplication}|draft`,
    'save_withdraw:save_result',
  )
  assert.equal(
    withdrawResult.stdout.trim(),
    `${IDS.raceApplication}|withdrawn`,
    'save_withdraw:withdraw_result',
  )
  const raceState = JSON.parse(
    await runAdmin(
      `
SELECT pg_catalog.jsonb_build_object(
  'applications', (SELECT count(*) FROM public.merchant_applications WHERE applicant_user_id = '${IDS.raceApplicant}'),
  'status', (SELECT status FROM public.merchant_applications WHERE id = '${IDS.raceApplication}'),
  'save_events', (SELECT count(*) FROM public.merchant_application_events WHERE application_id = '${IDS.raceApplication}' AND event_code = 'merchant_application.saved'),
  'withdraw_events', (SELECT count(*) FROM public.merchant_application_events WHERE application_id = '${IDS.raceApplication}' AND event_code = 'merchant_application.withdrawn')
)::text;
`,
      'save_withdraw_state',
    ),
  )
  assert.equal(raceState.applications, 1, 'save_withdraw:one_application')
  assert.equal(raceState.status, 'withdrawn', 'save_withdraw:terminal_status')
  assert.equal(raceState.save_events, 1, 'save_withdraw:one_save_event')
  assert.equal(raceState.withdraw_events, 1, 'save_withdraw:one_withdraw_event')
} catch (error) {
  primaryError = error
} finally {
  await Promise.allSettled([...activeResults])
  try {
    await runAdmin(cleanupSql, 'cleanup')
    const state = JSON.parse(
      await runAdmin(cleanupVerificationSql, 'cleanup_verification'),
    )
    for (const key of [
      'applications', 'private_rows', 'events', 'scopes', 'memberships',
      'stores', 'organizations', 'profiles', 'users',
    ]) {
      assert.equal(state[key], 0, `cleanup_verification:${key}`)
    }
  } catch (error) {
    cleanupError = error
  }
}

if (primaryError || cleanupError) {
  console.error(
    `P3_APPROVAL_CONCURRENCY_FAIL:${failureStage}:${cleanupError ? 'cleanup_fail' : 'cleanup_pass'}`,
  )
  process.exitCode = 1
} else {
  console.log('P3_APPROVAL_CONCURRENCY_PASS')
}
