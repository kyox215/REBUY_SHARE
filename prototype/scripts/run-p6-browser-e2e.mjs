import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { spawn } from 'node:child_process'

const APP_ORIGIN = 'http://127.0.0.1:3000'
const MAILPIT_ORIGIN = 'http://127.0.0.1:55324'
const DEBUG_ORIGIN = 'http://127.0.0.1:9225'
const DB_CONTAINER = 'supabase_db_rebuy-g2-a1-e2a-local-email-otp-exec'
const STORE_ID = '90000000-0000-4000-8000-000000000201'
const ORGANIZATION_ID = '90000000-0000-4000-8000-000000000101'
const MEMBERSHIP_ID = '62000000-0000-4000-8000-000000000101'
const SCOPE_ID = '62000000-0000-4000-8000-000000000102'
const suffix = randomUUID().replaceAll('-', '').slice(0, 10)
const email = `p6-browser-${suffix}@rebuy.test`
const sku = `SYN-SKU-P6-${suffix.toUpperCase()}`
const slug = `p6-browser-${suffix}`
const seenMailIds = new Set()
const browserErrors = []
let socket
let nextId = 1
let userId = ''
let listingId = ''
let merchantOrderId = ''
let stage = 'browser_connect'
const pending = new Map()

function runPsql(sql, label) {
  return new Promise((resolve, reject) => {
    const child = spawn('docker', [
      'exec', '-i', DB_CONTAINER, 'psql', '-X', '-q', '-v',
      'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres', '-A', '-t',
    ], { stdio: ['pipe', 'pipe', 'pipe'] })
    let stdout = ''
    let stderr = ''
    child.stdout.setEncoding('utf8')
    child.stderr.setEncoding('utf8')
    child.stdout.on('data', (chunk) => { stdout += chunk })
    child.stderr.on('data', (chunk) => { stderr += chunk })
    child.on('error', reject)
    child.on('close', (code, signal) => {
      if (code !== 0 || signal) reject(new Error(`${label}_failed:${stderr.trim()}`))
      else resolve(stdout.trim())
    })
    child.stdin.end(sql)
  })
}

function claimsSql() {
  return `
DO $claims$
BEGIN
  PERFORM pg_catalog.set_config('request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', '${userId}', 'email', '${email}', 'is_anonymous', false,
      'amr', pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'method', 'otp',
        'timestamp', EXTRACT(epoch FROM pg_catalog.statement_timestamp())
      ))
    )::text, true);
END
$claims$;
`
}

async function connectBrowser() {
  const target = await fetch(`${DEBUG_ORIGIN}/json/new?about:blank`, { method: 'PUT' })
    .then((response) => {
      if (!response.ok) throw new Error('browser_target_unavailable')
      return response.json()
    })
  socket = new WebSocket(target.webSocketDebuggerUrl)
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true })
    socket.addEventListener('error', reject, { once: true })
  })
  socket.addEventListener('message', (event) => {
    const message = JSON.parse(String(event.data))
    if (message.id && pending.has(message.id)) {
      const handlers = pending.get(message.id)
      pending.delete(message.id)
      if (message.error) handlers.reject(new Error(message.error.message))
      else handlers.resolve(message.result)
      return
    }
    if (message.method === 'Runtime.exceptionThrown') {
      browserErrors.push(message.params?.exceptionDetails?.text ?? 'runtime_exception')
    }
    if (message.method === 'Log.entryAdded' && message.params?.entry?.level === 'error') {
      browserErrors.push(message.params.entry.text)
    }
    if (message.method === 'Runtime.consoleAPICalled'
        && message.params?.type === 'error') browserErrors.push('console_error')
  })
}

function send(method, params = {}) {
  const id = nextId++
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject })
    socket.send(JSON.stringify({ id, method, params }))
  })
}

async function evaluate(expression) {
  const result = await send('Runtime.evaluate', {
    expression, awaitPromise: true, returnByValue: true,
  })
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.text)
  return result.result?.value
}

async function waitFor(expression, label, timeoutMs = 15_000) {
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    if (await evaluate(expression)) return
    await new Promise((resolve) => setTimeout(resolve, 100))
  }
  throw new Error(`browser_timeout:${label}`)
}

async function navigate(path) {
  await send('Page.navigate', { url: `${APP_ORIGIN}${path}` })
  await waitFor(`document.readyState === 'complete'`, `navigate:${path}`)
  await new Promise((resolve) => setTimeout(resolve, 200))
}

async function clickText(selector, value) {
  const clicked = await evaluate(`(() => {
    const node = [...document.querySelectorAll(${JSON.stringify(selector)})]
      .find((item) => item.textContent.trim().includes(${JSON.stringify(value)}));
    if (!node) return false;
    node.click();
    return true;
  })()`)
  assert.equal(clicked, true, `missing clickable text: ${value}`)
}

async function setField(selector, value) {
  const changed = await evaluate(`(() => {
    const node = document.querySelector(${JSON.stringify(selector)});
    if (!node) return false;
    const prototype = node instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype
      : node instanceof HTMLSelectElement ? HTMLSelectElement.prototype
      : HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(prototype, 'value').set;
    setter.call(node, ${JSON.stringify(value)});
    node.dispatchEvent(new Event('input', { bubbles: true }));
    node.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  })()`)
  assert.equal(changed, true, `missing field: ${selector}`)
}

async function pressEnter(selector) {
  assert.equal(await evaluate(`(() => {
    const node = document.querySelector(${JSON.stringify(selector)});
    if (!node) return false;
    node.focus();
    return document.activeElement === node;
  })()`), true)
  await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'Enter',
    code: 'Enter', windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13 })
  await send('Input.dispatchKeyEvent', { type: 'char', key: 'Enter',
    code: 'Enter', text: '\r', windowsVirtualKeyCode: 13,
    nativeVirtualKeyCode: 13 })
  await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Enter',
    code: 'Enter', windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13 })
}

async function readNextOtp() {
  const deadline = Date.now() + 15_000
  while (Date.now() < deadline) {
    const search = await fetch(`${MAILPIT_ORIGIN}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}`)
      .then((response) => response.json())
    for (const message of search.messages ?? []) {
      const id = message.ID ?? message.Id ?? message.id
      if (typeof id !== 'string' || seenMailIds.has(id)) continue
      seenMailIds.add(id)
      const detail = await fetch(`${MAILPIT_ORIGIN}/api/v1/message/${encodeURIComponent(id)}`)
        .then((response) => response.json())
      const match = [detail.Text, detail.HTML, detail.text, detail.html]
        .filter((entry) => typeof entry === 'string').join('\n').match(/\b\d{6}\b/)
      if (match) return match[0]
    }
    await new Promise((resolve) => setTimeout(resolve, 250))
  }
  throw new Error('mailpit_otp_timeout')
}

async function provisionMembership() {
  userId = await runPsql(`SELECT id FROM auth.users WHERE email = '${email}' LIMIT 1;`,
    'browser_user_lookup')
  assert.match(userId, /^[0-9a-f-]{36}$/i)
  await runPsql(`
    DELETE FROM public.membership_store_scopes WHERE id = '${SCOPE_ID}';
    DELETE FROM public.memberships WHERE id = '${MEMBERSHIP_ID}';
    INSERT INTO public.memberships (id, user_id, organization_id,
      organization_type, role_definition_id, role_version, status, valid_from)
    VALUES ('${MEMBERSHIP_ID}', '${userId}', '${ORGANIZATION_ID}', 'merchant',
      '00000000-0000-4000-8000-000000000201', 1, 'active',
      pg_catalog.statement_timestamp() - INTERVAL '1 hour');
    INSERT INTO public.membership_store_scopes (id, membership_id,
      organization_id, organization_type, store_id, scope_type, status)
    VALUES ('${SCOPE_ID}', '${MEMBERSHIP_ID}', '${ORGANIZATION_ID}', 'merchant',
      NULL, 'organization', 'active');
  `, 'merchant_membership_setup')
}

async function createCheckout() {
  const output = await runPsql(`
    BEGIN;
    ${claimsSql()}
    SET LOCAL ROLE authenticated;
    SELECT cart_id::text || '|' || cart_version::text
      FROM public.put_cart_item('${listingId}', 1, NULL, NULL,
        '62000000-0000-4000-8000-000000000301');
    SELECT batch_id::text FROM public.checkout_cart(1,
      'synthetic://delivery/p6-browser',
      '62000000-0000-4000-8000-000000000302');
    COMMIT;
  `, 'browser_checkout')
  const batchId = output.split('\n').at(-1)
  assert.match(batchId, /^[0-9a-f-]{36}$/i)
  merchantOrderId = await runPsql(`SELECT id FROM public.merchant_orders
    WHERE batch_id = '${batchId}' AND store_id = '${STORE_ID}';`,
  'browser_merchant_order_lookup')
  assert.match(merchantOrderId, /^[0-9a-f-]{36}$/i)
}

async function cleanup() {
  if (!userId) return
  await runPsql(`
    BEGIN;
    UPDATE public.carts SET status = 'abandoned', checkout_batch_id = NULL
      WHERE owner_user_id = '${userId}' AND status = 'checked_out';
    DELETE FROM public.merchant_after_sale_cases
      WHERE buyer_user_id = '${userId}' OR created_by = '${userId}';
    DELETE FROM public.merchant_operation_events WHERE actor_user_id = '${userId}';
    DELETE FROM public.p6_idempotency_keys WHERE actor_user_id = '${userId}';
    DELETE FROM public.order_events WHERE buyer_user_id = '${userId}';
    DELETE FROM public.order_items WHERE buyer_user_id = '${userId}';
    DELETE FROM public.merchant_orders WHERE buyer_user_id = '${userId}';
    DELETE FROM public.order_batches WHERE buyer_user_id = '${userId}';
    DELETE FROM public.p5_idempotency_keys WHERE actor_user_id = '${userId}';
    DELETE FROM public.cart_items WHERE owner_user_id = '${userId}';
    DELETE FROM public.carts WHERE owner_user_id = '${userId}';
    DELETE FROM public.p4_idempotency_keys WHERE actor_user_id = '${userId}';
    DELETE FROM public.inventory_events WHERE actor_user_id = '${userId}'
      OR listing_id IN (SELECT id FROM public.listings WHERE created_by = '${userId}');
    DELETE FROM public.catalog_events WHERE actor_user_id = '${userId}'
      OR listing_id IN (SELECT id FROM public.listings WHERE created_by = '${userId}');
    DELETE FROM public.listing_price_tiers WHERE listing_id IN (
      SELECT id FROM public.listings WHERE created_by = '${userId}');
    DELETE FROM public.listing_prices WHERE listing_id IN (
      SELECT id FROM public.listings WHERE created_by = '${userId}');
    DELETE FROM public.inventory_levels WHERE listing_id IN (
      SELECT id FROM public.listings WHERE created_by = '${userId}');
    DELETE FROM public.secondhand_units WHERE listing_id IN (
      SELECT id FROM public.listings WHERE created_by = '${userId}');
    DELETE FROM public.listings WHERE created_by = '${userId}';
    DELETE FROM public.product_variants WHERE product_id IN (
      SELECT id FROM public.products WHERE created_by = '${userId}');
    DELETE FROM public.products WHERE created_by = '${userId}';
    DELETE FROM public.membership_store_scopes WHERE id = '${SCOPE_ID}';
    DELETE FROM public.memberships WHERE id = '${MEMBERSHIP_ID}';
    DELETE FROM public.profiles WHERE user_id = '${userId}';
    DELETE FROM auth.users WHERE id = '${userId}';
    COMMIT;
  `, 'browser_cleanup')
}

try {
  await connectBrowser()
  await send('Page.enable')
  await send('Runtime.enable')
  await send('Log.enable')

  stage = 'unauthenticated_merchant_guard'
  await navigate('/merchant')
  await waitFor(`location.pathname === '/account/login'
    && location.search.includes('next=%2Fmerchant')`, 'merchant-login-redirect')

  stage = 'merchant_signup_and_no_access'
  await clickText('button[role="tab"]', '注册')
  await setField('#login-email', email)
  await clickText('button[type="submit"]', '发送注册验证码')
  await waitFor(`document.body.innerText.includes('验证码已发送')`, 'signup-otp-sent')
  await setField('#login-otp', await readNextOtp())
  await clickText('button[type="submit"]', '验证并完成注册')
  await waitFor(`location.pathname === '/merchant/no-access'`, 'merchant-no-access', 20_000)
  assert.match(await evaluate('document.body.innerText'), /当前账号没有商家工作台权限/)

  stage = 'merchant_membership_and_dashboard'
  await provisionMembership()
  await navigate('/merchant')
  await waitFor(`document.body.innerText.includes('经营概览')`, 'merchant-dashboard')
  const dashboard = await evaluate('document.body.innerText')
  assert.match(dashboard, /维护商品[\s\S]*调整库存[\s\S]*处理订单[\s\S]*处理售后/)

  stage = 'product_create_and_search'
  await navigate(`/merchant/products?store=${STORE_ID}`)
  const createForm = 'form:has(input[name="product_kind"][value="standard"]):not(:has(input[name="listing_id"]))'
  for (const [name, value] of [
    ['internal_name', 'P6 Browser Product'], ['sku', sku],
    ['listing_slug', slug], ['title', 'P6 浏览器商品'],
    ['summary', '浏览器端创建的合成商家商品'], ['retail_cents', '1999'],
    ['initial_stock', '3'],
  ]) await setField(`${createForm} [name="${name}"]`, value)
  const submitted = await evaluate(`(() => {
    const form = document.querySelector(${JSON.stringify(createForm)});
    const button = [...form.querySelectorAll('button[type="submit"]')]
      .find((node) => node.textContent.includes('创建标准商品'));
    if (!button) return false;
    button.click();
    return true;
  })()`)
  assert.equal(submitted, true)
  await waitFor(`location.search.includes('notice=product-created')`, 'product-created', 20_000)
  assert.match(await evaluate('document.body.innerText'), /商品已创建/)
  listingId = await runPsql(`SELECT id FROM public.listings
    WHERE created_by = '${userId}' AND slug = '${slug}';`, 'browser_listing_lookup')
  assert.match(listingId, /^[0-9a-f-]{36}$/i)
  await setField('input[name="q"]', 'P6 浏览器商品')
  await pressEnter('input[name="q"]')
  await waitFor(`location.search.includes('q=')`, 'product-keyboard-search')
  assert.match(await evaluate('document.body.innerText'), /找到 1 件匹配商品/)

  stage = 'inventory_adjustment_reason'
  await navigate(`/merchant/inventory?store=${STORE_ID}`)
  const inventorySubmitted = await evaluate(`(() => {
    const hidden = document.querySelector('input[name="listing_id"][value="${listingId}"]');
    if (!hidden) return false;
    const form = hidden.form;
    const quantity = form.querySelector('[name="quantity_delta"]');
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    setter.call(quantity, '2');
    quantity.dispatchEvent(new Event('input', { bubbles: true }));
    form.querySelector('[name="reason_code"]').value = 'stock_received';
    form.querySelector('button[type="submit"]').click();
    return true;
  })()`)
  assert.equal(inventorySubmitted, true)
  await waitFor(`location.search.includes('notice=inventory-updated')`,
    'inventory-updated', 20_000)
  assert.match(await evaluate('document.body.innerText'), /库存已更新/)

  stage = 'merchant_order_fulfillment'
  await createCheckout()
  await navigate(`/merchant/orders/${merchantOrderId}?store=${STORE_ID}`)
  await clickText('button[type="submit"]', '接单')
  await waitFor(`location.search.includes('notice=order-accepted')`, 'order-accepted', 20_000)
  await clickText('button[type="submit"]', '登记发货')
  await waitFor(`location.search.includes('notice=order-shipped')`, 'order-shipped', 20_000)
  await clickText('button[type="submit"]', '确认完成')
  await waitFor(`location.search.includes('notice=order-completed')`, 'order-completed', 20_000)
  assert.match(await evaluate('document.body.innerText'), /订单已完成[\s\S]*库存已核销/)

  stage = 'merchant_after_sale'
  await clickText('button[type="submit"]', '创建售后')
  await waitFor(`location.search.includes('notice=after-sale-opened')`,
    'after-sale-opened', 20_000)
  await navigate(`/merchant/after-sales?store=${STORE_ID}`)
  await clickText('button[type="submit"]', '开始复核')
  await waitFor(`location.search.includes('notice=after-sale-start_review')`,
    'after-sale-reviewing', 20_000)
  await clickText('button[type="submit"]', '解决')
  await waitFor(`location.search.includes('notice=after-sale-resolve')`,
    'after-sale-resolved', 20_000)
  assert.match(await evaluate('document.body.innerText'), /已解决[\s\S]*replacement_recorded/)

  stage = 'merchant_audit_and_responsive_keyboard'
  await navigate(`/merchant/audit?store=${STORE_ID}`)
  const auditText = await evaluate('document.body.innerText')
  assert.match(auditText, /inventory.adjusted/)
  assert.match(auditText, /merchant_order.completed/)
  assert.match(auditText, /after_sale.resolved/)
  for (const [width, height] of [[390, 844], [430, 932], [768, 1024],
    [1024, 768], [1440, 900]]) {
    await send('Emulation.setDeviceMetricsOverride', {
      width, height, deviceScaleFactor: 1, mobile: width < 768,
    })
    await send('Page.reload', { ignoreCache: true })
    await waitFor(`document.readyState === 'complete'`, `responsive-${width}`)
    assert.equal(await evaluate('document.documentElement.scrollWidth <= window.innerWidth'),
      true, `horizontal overflow at ${width}px`)
  }
  await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'Tab',
    code: 'Tab', windowsVirtualKeyCode: 9, nativeVirtualKeyCode: 9 })
  await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Tab',
    code: 'Tab', windowsVirtualKeyCode: 9, nativeVirtualKeyCode: 9 })
  assert.equal(await evaluate('document.activeElement !== document.body'), true)
  await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'Escape',
    code: 'Escape', windowsVirtualKeyCode: 27, nativeVirtualKeyCode: 27 })
  await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Escape',
    code: 'Escape', windowsVirtualKeyCode: 27, nativeVirtualKeyCode: 27 })

  stage = 'browser_error_check'
  assert.equal(await evaluate(`Boolean(document.querySelector(
    '[data-nextjs-dialog], .vite-error-overlay, #webpack-dev-server-client-overlay'))`), false)
  const actionableErrors = browserErrors.filter((message) =>
    !/WebSocket connection to .*\/_next\/hmr.*Page entered Back-Forward Cache[.]/.test(message))
  assert.deepEqual(actionableErrors, [])
  console.log('P6_BROWSER_E2E_PASS')
} catch (error) {
  console.error(`P6_BROWSER_E2E_FAIL:${stage}`)
  console.error(error instanceof Error ? error.message : 'unknown_browser_failure')
  process.exitCode = 1
} finally {
  try { await cleanup() } catch (error) {
    console.error(`P6_BROWSER_E2E_FAIL:cleanup:${error.message}`)
    process.exitCode = 1
  }
  if (socket) {
    try { await send('Browser.close') } catch {}
    socket.close()
  }
}
