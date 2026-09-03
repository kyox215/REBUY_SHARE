import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

const read = (relative) =>
  readFile(fileURLToPath(new URL(relative, import.meta.url)), 'utf8')

const [migration, roles, seed, gate, schemaTest, workflowTest, concurrency] = await Promise.all([
  read('../../supabase/migrations/20260903170000_p4_wholesale_catalog_pricing_inventory.sql'),
  read('../../supabase/roles.sql'),
  read('../../supabase/seed.sql'),
  read('../../docs/stages/P4-商品定价库存与批发资格Gate.md'),
  read('../../supabase/tests/p4_schema_security.test.sql'),
  read('../../supabase/tests/p4_workflow.test.sql'),
  read('./run-p4-inventory-concurrency.mjs'),
])

const tables = [
  'wholesale_applications',
  'wholesale_application_private',
  'wholesale_qualifications',
  'wholesale_application_events',
  'categories',
  'products',
  'product_variants',
  'listings',
  'listing_prices',
  'listing_price_tiers',
  'inventory_levels',
  'secondhand_units',
  'catalog_events',
  'inventory_events',
  'p4_idempotency_keys',
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
  roles,
  /CREATE ROLE rebuy_business_executor\s+NOLOGIN\s+NOSUPERUSER\s+NOCREATEDB\s+NOCREATEROLE\s+NOINHERIT\s+NOREPLICATION\s+NOBYPASSRLS;/,
)
assert.doesNotMatch(migration, /(?:CREATE|ALTER) ROLE rebuy_business_executor/)
assert.match(migration, /rebuy_business_executor_invalid/)
assert.doesNotMatch(
  `${roles}\n${migration}`,
  /(?:GRANT|ALTER DEFAULT PRIVILEGES)[^;]*\bservice_role\b/is,
)
assert.match(
  migration,
  /REVOKE ALL PRIVILEGES ON TABLE[\s\S]*?public[.]p4_idempotency_keys[\s\S]*?FROM PUBLIC, anon, authenticated, service_role, rebuy_business_executor;/,
)
assert.doesNotMatch(migration, /GRANT\s+(?:DELETE|TRUNCATE|REFERENCES|TRIGGER)\b/i)
assert.doesNotMatch(
  migration,
  /GRANT SELECT, INSERT, UPDATE ON TABLE public[.](?:organizations|memberships|membership_store_scopes)/,
)
assert.doesNotMatch(
  migration,
  /GRANT SELECT ON TABLE public[.](?:role_definitions|permissions|role_permissions)/,
)
assert.match(migration, /GRANT SELECT, INSERT ON TABLE public[.]p4_idempotency_keys/)
assert.match(migration, /GRANT SELECT \(display_name\) ON TABLE public[.]stores/)

const publicWrappers = [
  'save_wholesale_application',
  'get_my_wholesale_application',
  'list_wholesale_review_queue',
  'get_assigned_wholesale_application',
  'assign_wholesale_application',
  'review_wholesale_application',
  'change_wholesale_qualification',
  'withdraw_wholesale_application',
  'upsert_catalog_listing',
  'get_catalog_quote',
  'list_public_catalog',
  'adjust_inventory',
]
for (const wrapper of publicWrappers) {
  assert.match(
    migration,
    new RegExp(
      `CREATE OR REPLACE FUNCTION public[.]${wrapper}\\([\\s\\S]*?SECURITY INVOKER`,
    ),
    `${wrapper} must be a SECURITY INVOKER wrapper`,
  )
}
assert.doesNotMatch(
  migration,
  /CREATE OR REPLACE FUNCTION public[.]change_inventory_reservation\(/,
  'the P5-only reservation primitive must not be a public P4 RPC',
)

const implementations = [
  'save_wholesale_application_impl',
  'get_my_wholesale_application_impl',
  'list_wholesale_review_queue_impl',
  'get_assigned_wholesale_application_impl',
  'assign_wholesale_application_impl',
  'review_wholesale_application_impl',
  'change_wholesale_qualification_impl',
  'withdraw_wholesale_application_impl',
  'upsert_catalog_listing_impl',
  'get_catalog_quote_impl',
  'list_public_catalog_impl',
  'adjust_inventory_impl',
  'change_inventory_reservation_impl',
]
for (const implementation of implementations) {
  assert.match(
    migration,
    new RegExp(
      `CREATE OR REPLACE FUNCTION private[.]${implementation}\\([\\s\\S]*?SECURITY DEFINER(?:\\n| )SET search_path = ''`,
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
  'get_my_wholesale_application_impl',
  'list_wholesale_review_queue_impl',
  'get_assigned_wholesale_application_impl',
  'get_catalog_quote_impl',
  'list_public_catalog_impl',
]) {
  assert.match(
    migration,
    new RegExp(
      `CREATE OR REPLACE FUNCTION private[.]${implementation}\\([\\s\\S]*?LANGUAGE plpgsql VOLATILE SECURITY DEFINER`,
    ),
  )
}

assert.match(
  migration,
  /UPDATE public[.]wholesale_application_private AS wap[\s\S]*?WHERE wap[.]application_id = v_application_id/,
)

assert.match(
  migration,
  /PRIMARY KEY \(actor_user_id, idempotency_key\)/,
  'P4 idempotency must be actor-global across operations',
)
for (const operation of [
  'wholesale.save',
  'wholesale.assign',
  'wholesale.review',
  'wholesale.withdraw',
  'qualification.change',
  'catalog.upsert',
  'inventory.adjust',
  'inventory.reserve',
  'inventory.release',
  'inventory.sell',
]) {
  assert.match(migration, new RegExp(`'${operation.replace('.', '[.]')}'`))
}
assert.match(migration, /result_on_hand integer/)
assert.match(migration, /result_reserved integer/)
assert.match(migration, /result_available integer/)
assert.match(
  migration,
  /CREATE OR REPLACE FUNCTION private[.]change_inventory_reservation_impl\(\s*p_listing_id uuid,\s*p_quantity integer,\s*p_action text,\s*p_expected_version integer,/,
)
assert.match(
  migration,
  /IF v_inventory[.]version <> p_expected_version[\s\S]*?IF v_unit[.]version <> p_expected_version/,
)
assert.doesNotMatch(
  migration,
  /GRANT EXECUTE ON FUNCTION private[.]change_inventory_reservation_impl[\s\S]*?TO authenticated;/,
)
assert.match(
  migration,
  /CREATE OR REPLACE FUNCTION private[.]rebuy_p4_reset_context\([\s\S]*?PERFORM private[.]rebuy_business_reset_context\(\)/,
)
assert.match(
  migration,
  /CREATE OR REPLACE FUNCTION private[.]rebuy_business_reset_context\([\s\S]*?'rebuy[.]business[.]authorized'[\s\S]*?'rebuy[.]p4[.]authorized'/,
)
for (const sharedPolicy of [
  'organizations_business_select',
  'organizations_business_insert_merchant',
  'stores_business_select',
  'stores_business_update_merchant',
  'memberships_business_select',
  'memberships_business_insert_owner',
  'membership_store_scopes_business_insert_owner',
  'membership_store_scopes_business_select_owner',
]) {
  assert.match(
    migration,
    new RegExp(`DROP POLICY ${sharedPolicy}\\s+ON public[.]`),
    `${sharedPolicy} must be replaced instead of duplicated`,
  )
}
assert.doesNotMatch(
  migration,
  /CREATE POLICY (?:organizations|stores|memberships)_p4_|CREATE POLICY membership_scopes_p4_all/,
)

assert.match(migration, /currency_code text NOT NULL DEFAULT 'EUR'/)
assert.match(migration, /CONSTRAINT listing_prices_currency_check CHECK \(currency_code = 'EUR'\)/)
assert.match(migration, /audience = 'wholesale' AND minimum_quantity >= 2/)
assert.match(migration, /p_wholesale_cents > p_retail_cents/)
assert.match(migration, /v_tier_min <= v_previous_min/)
assert.match(migration, /v_tier_price > v_previous_price/)
assert.match(
  migration,
  /UPDATE public[.]listing_prices AS lp\s+SET status = 'superseded',[\s\S]*?WHERE lp[.]listing_id = v_listing_id AND lp[.]status = 'active'/,
)
assert.match(migration, /listing_id uuid NOT NULL UNIQUE/)
assert.match(migration, /IF p_quantity <> 1 THEN RAISE EXCEPTION 'secondhand_quantity_must_be_one'/)
assert.match(migration, /on_hand >= 0 AND reserved >= 0 AND reserved <= on_hand/)
assert.match(
  migration,
  /v_result_on_hand := v_inventory[.]on_hand::bigint \+ p_quantity_delta::bigint;[\s\S]*?v_result_on_hand > 1000000[\s\S]*?UPDATE public[.]inventory_levels AS il\s+SET on_hand = v_result_on_hand::integer/,
)
assert.match(migration, /'inventory[.]sold'/)
assert.match(
  migration,
  /v_available := COALESCE\(v_available, 0\);\s+IF v_available <= 0 THEN\s+RAISE EXCEPTION 'catalog_listing_not_available'/,
)
for (const index of [
  'wholesale_applications_applicant_idx',
  'wholesale_qualifications_org_context_idx',
  'products_org_context_idx',
  'product_variants_product_context_idx',
  'listings_org_context_idx',
  'listings_store_context_idx',
  'listings_product_context_idx',
  'listings_variant_context_idx',
  'listing_prices_listing_context_idx',
  'catalog_events_listing_context_idx',
  'inventory_events_listing_context_idx',
  'inventory_events_inventory_listing_idx',
  'inventory_events_secondhand_listing_idx',
]) {
  assert.match(migration, new RegExp(`CREATE INDEX ${index}`))
}

assert.match(
  migration,
  /CREATE OR REPLACE FUNCTION private[.]get_catalog_quote_impl[\s\S]*?rebuy_p4_active_wholesale_qualification\(v_uid\)[\s\S]*?audience = 'wholesale'[\s\S]*?audience = 'retail'/,
)
assert.match(
  migration,
  /q[.]status = 'active'[\s\S]*?q[.]valid_from <= pg_catalog[.]statement_timestamp\(\)[\s\S]*?q[.]valid_until > pg_catalog[.]statement_timestamp\(\)[\s\S]*?o[.]status = 'active'/,
)
assert.match(migration, /v_uid = v_application[.]applicant_user_id/)
assert.match(migration, /'wholesale_application[.]read_assigned'/)
assert.match(migration, /'wholesale_application[.]review'/)
assert.match(migration, /'wholesale_qualification[.]manage'/)
assert.match(
  migration,
  /v_membership[.]role_scope_type = 'organization'[\s\S]*?v_membership[.]role_scope_type = 'store'/,
)
assert.match(
  migration,
  /CREATE OR REPLACE FUNCTION private[.]adjust_inventory_impl[\s\S]*?v_store_status IS DISTINCT FROM 'active'/,
)
assert.match(
  migration,
  /INSERT INTO public[.]organizations[\s\S]*?INSERT INTO public[.]memberships[\s\S]*?INSERT INTO public[.]membership_store_scopes[\s\S]*?INSERT INTO public[.]wholesale_qualifications[\s\S]*?UPDATE public[.]wholesale_applications/,
)

assert.doesNotMatch(
  migration,
  /(?<!SELECT )pg_catalog[.]current_setting\('rebuy[.]p4/,
  'all P4 RLS context lookups must use init-plan SELECT wrapping',
)
assert.match(
  migration,
  /CREATE POLICY inventory_events_p4_all[\s\S]*?actor_user_id::text = \(SELECT pg_catalog[.]current_setting\('rebuy[.]p4[.]actor_user_id'/,
)
assert.match(migration, /pg_advisory_xact_lock\([\s\S]*?p4-idempotency/)
assert.match(migration, /catalog[.]listing_deactivated/)
assert.match(migration, /'catalog:store-slug:'[\s\S]*?'catalog:org-sku:'[\s\S]*?'catalog:unit-serial:'/)
assert.match(migration, /EXCEPTION\s+WHEN unique_violation THEN\s+RAISE EXCEPTION 'catalog_unique_conflict'/)
assert.match(migration, /WHEN integrity_constraint_violation THEN\s+RAISE EXCEPTION 'catalog_integrity_conflict'/)
assert.doesNotMatch(migration, /CREATE(?: OR REPLACE)? TRIGGER[^;]*auth[.]users/is)
assert.doesNotMatch(migration, /\b(?:phone|address|tax|bank|document_blob|secret|token|cookie|otp)\b/i)

for (const permission of [
  'catalog.write',
  'listing.publish',
  'pricing.write',
  'inventory.adjust',
  'wholesale_application.assign',
  'wholesale_application.read_assigned',
  'wholesale_application.review',
  'wholesale_qualification.manage',
]) {
  assert.match(seed, new RegExp(`'${permission.replace('.', '[.]')}'`))
}
assert.match(seed, /'wholesale_reviewer', 'platform', 1, 'platform'/)
for (const category of ['electronics', 'phone-accessories', 'secondhand', 'computers']) {
  assert.match(seed, new RegExp(`'${category}'`))
}
assert.match(seed, /No auth[.]users, identity, email, tenant, store, membership, listing, price, or inventory rows[.]/)
assert.match(gate, /P4 提供受控原子预留\/释放 primitive，P5 仅在提交订单事务中调用/)
assert.match(gate, /final independent GO 前不得关闭 P4 或打开 P5/)
assert.match(schemaTest, /external roles have no effective P4 table privileges/)
assert.match(schemaTest, /external roles have no effective P4 column privileges/)
assert.match(schemaTest, /P5-only reservation primitive is inaccessible to every external role/)
assert.match(schemaTest, /at most one permissive policy per public table action/)
assert.match(schemaTest, /every P4 foreign key has a full leading-column covering index/)
assert.match(schemaTest, /executor receives no widened table-level ACL on existing catalogs or idempotency rows/)
assert.match(schemaTest, /executor retains only the required effective columns on shared authorization catalogs/)
assert.match(schemaTest, /authenticated-only private implementations have exact direct-parity ACLs/)
assert.match(schemaTest, /private public-catalog implementations preserve exact direct-parity ACLs/)
assert.match(workflowTest, /active qualified owner receives the automatic wholesale tier quote/)
assert.match(workflowTest, /suspended qualification immediately falls back to retail price/)
assert.match(workflowTest, /old inventory retry returns its original quantities and version after later changes/)
assert.match(workflowTest, /old inventory retry revalidates current merchant membership/)
assert.match(workflowTest, /old catalog retry revalidates current merchant membership/)
assert.match(workflowTest, /old needs-info key returns the original result after resubmission clears assignment/)
assert.match(workflowTest, /old needs-info retry does not roll back the current application state/)
assert.match(workflowTest, /mid-approval failure leaves no partial wholesale organization/)
assert.match(workflowTest, /an applicant cannot be assigned to review the own application/)
assert.match(workflowTest, /assigned reviewer can reject without creating wholesale business objects/)
assert.match(workflowTest, /applicant can withdraw an unassigned submitted application/)
assert.match(workflowTest, /old review retry revalidates the historical review actor membership/)
assert.match(workflowTest, /catalog update publishes a new listing and price version/)
assert.match(workflowTest, /stale expected listing version is rejected/)
assert.match(workflowTest, /platform reviewer cannot write another tenant catalog/)
assert.match(workflowTest, /store-scoped merchant member cannot write another store/)
assert.match(workflowTest, /suspended store makes its listing unavailable/)
assert.match(workflowTest, /suspended merchant organization makes its listing unavailable/)
assert.match(workflowTest, /inactive product makes its listing unavailable/)
assert.match(workflowTest, /inactive variant makes its listing unavailable/)
assert.match(workflowTest, /inactive listing is not publicly quotable/)
assert.match(workflowTest, /invalid listing slug is rejected before any write/)
assert.match(workflowTest, /invalid synthetic SKU is rejected before any write/)
assert.match(workflowTest, /direct save implementation preserves wrapper idempotency parity/)
assert.match(workflowTest, /direct assignment implementation preserves wrapper idempotency parity/)
assert.match(workflowTest, /direct review implementation rejects a non-assigned reviewer/)
assert.match(workflowTest, /direct qualification implementation preserves wrapper idempotency parity/)
assert.match(workflowTest, /direct catalog implementation rejects another tenant actor/)
assert.match(workflowTest, /direct inventory implementation preserves historical result parity/)
assert.match(
  workflowTest,
  /GRANT rebuy_business_executor TO postgres\s+WITH INHERIT FALSE GRANTED BY CURRENT_USER/,
)
assert.match(workflowTest, /test-only reservation role membership is removed before rollback/)
assert.match(workflowTest, /CREATE TEMP TABLE p4_error_result/)
assert.match(workflowTest, /VALUES \(SQLSTATE, SQLERRM\)/)
for (const expectedError of [
  'P0001:inventory_quantity_conflict',
  'P0001:secondhand_quantity_must_be_one',
  'P0001:secondhand_state_conflict',
]) {
  assert.match(workflowTest, new RegExp(expectedError))
}

let executorRoleActive = false
let executorRoleBlock = ''
let executorRoleBlockCount = 0
for (const [lineIndex, rawLine] of workflowTest.split('\n').entries()) {
  const line = rawLine.trim()
  if (line === 'SET LOCAL ROLE rebuy_business_executor;') {
    assert.equal(
      executorRoleActive,
      false,
      `nested executor role scope at workflow line ${lineIndex + 1}`,
    )
    executorRoleActive = true
    executorRoleBlock = `${line}\n`
    executorRoleBlockCount += 1
    continue
  }
  if (!executorRoleActive) continue
  if (/^SELECT\s+(?:is|isnt|ok|not_ok|throws_ok|lives_ok|results_eq|set_eq|bag_eq|row_eq|cmp_ok|pass|fail)\s*\(/.test(line)) {
    assert.fail(`pgTAP assertion executed under executor role at workflow line ${lineIndex + 1}`)
  }
  if (line === 'RESET ROLE;') {
    assert.match(
      executorRoleBlock,
      /private[.]change_inventory_reservation_impl\(/,
      `executor role scope at workflow line ${lineIndex + 1} is not reservation-only`,
    )
    executorRoleActive = false
    executorRoleBlock = ''
    continue
  }
  executorRoleBlock += `${line}\n`
}
assert.equal(executorRoleActive, false, 'executor role scope must be reset before test completion')
assert.equal(executorRoleBlockCount, 10, 'workflow must have ten bounded reservation executor scopes')
assert.match(workflowTest, /inventory adjustment retry rejects a suspended store/)
assert.match(workflowTest, /same actor-global key cannot cross from catalog to inventory operation/)
assert.match(workflowTest, /sold secondhand unit cannot return to available/)
assert.match(
  workflowTest,
  /public[.]get_catalog_quote\(\s*\(SELECT listing_id FROM pg_temp[.]p4_standard_listing_target\), 10\s*\)\),\s*'retail',\s*'revoked qualification immediately falls back to retail'/,
  'post-secondhand wholesale fallback must quote the preserved standard listing target',
)
assert.match(workflowTest, /repeated legal adjustments cannot exceed the bounded total stock ceiling/)
assert.match(workflowTest, /standard sale emits one distinct sold audit event/)
assert.match(workflowTest, /standard release preserves on-hand while returning reserved stock to availability/)
assert.match(workflowTest, /same-key standard release retry returns its original result without another mutation/)
assert.match(workflowTest, /standard listing with zero available stock is not publicly quotable/)
assert.match(workflowTest, /reserved secondhand unit is not publicly quotable by known listing id/)
assert.match(workflowTest, /sold secondhand unit is not publicly quotable by known listing id/)
assert.match(workflowTest, /duplicate store slug maps to a bounded catalog error/)
assert.match(workflowTest, /duplicate organization SKU maps to a bounded catalog error/)
assert.match(workflowTest, /duplicate secondhand serial maps to a bounded catalog error/)
assert.match(workflowTest, /a subsequent P3 RPC clears stale P4 RLS context/)
assert.match(workflowTest, /a subsequent P4 RPC clears stale P3 RLS context/)
assert.match(concurrency, /same_key_standard_reservation/)
assert.match(
  concurrency,
  /DO \$claims\$\s+BEGIN\s+PERFORM pg_catalog[.]set_config\(\s*'request[.]jwt[.]claims'/,
  'concurrency claims setup must not emit worker-specific AMR timestamps to stdout',
)
assert.doesNotMatch(
  concurrency,
  /SELECT pg_catalog[.]set_config\(\s*'request[.]jwt[.]claims'/,
  'worker stdout must contain only the comparable reservation result',
)
assert.match(concurrency, /REVOKE rebuy_business_executor FROM postgres/)
assert.match(concurrency, /postgres_executor_membership/)
assert.match(
  concurrency,
  /REVOKE rebuy_business_executor FROM postgres GRANTED BY CURRENT_USER;\s+DO \$cleanup_role\$[\s\S]*?count\(\*\)[\s\S]*?member_role[.]rolname = 'postgres'[\s\S]*?grantor_role[.]rolname = 'supabase_admin'[\s\S]*?grantor_role[.]rolname = 'postgres'[\s\S]*?pg_has_role\('postgres', 'rebuy_business_executor', 'SET'\)[\s\S]*?\$cleanup_role\$;\s+BEGIN;/,
)
assert.match(concurrency, /supabase_admin_executor_bootstrap/)
assert.match(concurrency, /executor_postgres_membership_total/)
assert.match(concurrency, /postgres_grantor_executor_membership/)
assert.match(concurrency, /grantor_role[.]rolname = 'supabase_admin'/)
assert.match(concurrency, /different_key_standard_oversell/)
assert.match(concurrency, /different_key_secondhand_unique_winner/)
assert.match(concurrency, /pg_stat_activity/)
assert.match(concurrency, /wait_event_type = 'Lock'/)
assert.match(concurrency, /ERROR:\\s\+inventory_version_conflict/)
assert.match(concurrency, /deadlock detected\|statement timeout\|lock timeout/)
assert.match(concurrency, /P4_INVENTORY_CONCURRENCY_FAIL:\$\{failureStage\}:\$\{cleanupError \? 'cleanup_fail' : 'cleanup_pass'\}/)

console.log('P4 migration structure checks passed.')
