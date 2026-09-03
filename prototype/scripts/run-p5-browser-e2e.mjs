import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { spawn } from 'node:child_process'

const APP_ORIGIN = 'http://127.0.0.1:3000'
const MAILPIT_ORIGIN = 'http://127.0.0.1:55324'
const DEBUG_ORIGIN = 'http://127.0.0.1:9225'
const DB_CONTAINER = 'supabase_db_rebuy-g2-a1-e2a-local-email-otp-exec'
const email = `p5-browser-${randomUUID().replaceAll('-', '').slice(0, 16)}@rebuy.test`
const otherEmail = `p5-browser-other-${randomUUID().replaceAll('-', '').slice(0, 16)}@rebuy.test`
const seenMailIds = new Set()
let socket
let stage = 'browser_connect'
let wholesaleFixtureTouched = false
let seedInventoryChanged = false
let orderPath = ''

let nextId = 1
const pending = new Map()
const browserErrors = []

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
      const { resolve, reject } = pending.get(message.id)
      pending.delete(message.id)
      if (message.error) reject(new Error(message.error.message))
      else resolve(message.result)
      return
    }
    if (message.method === 'Runtime.exceptionThrown') {
      browserErrors.push(message.params?.exceptionDetails?.text ?? 'runtime_exception')
    }
    if (message.method === 'Log.entryAdded' && message.params?.entry?.level === 'error') {
      browserErrors.push(message.params.entry.text)
    }
    if (message.method === 'Runtime.consoleAPICalled' && message.params?.type === 'error') {
      browserErrors.push('console_error')
    }
  })
}

function send(method, params = {}) {
  const id = nextId++
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject })
    socket.send(JSON.stringify({ id, method, params }))
  })
}

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
    child.on('error', () => reject(new Error(`${label}_spawn_failed`)))
    child.on('close', (code, signal) => {
      if (code !== 0 || signal) reject(new Error(`${label}_failed`))
      else resolve(stdout.trim())
    })
    child.stdin.end(sql)
  })
}

const wholesaleFixtureCleanupSql = `
BEGIN;
UPDATE public.wholesale_applications
  SET status = 'rejected', organization_id = NULL, owner_membership_id = NULL,
    qualification_id = NULL, decided_at = pg_catalog.statement_timestamp()
  WHERE id = '92000000-0000-4000-8000-000000000401';
DELETE FROM public.wholesale_qualifications
  WHERE id = '92000000-0000-4000-8000-000000000402';
DELETE FROM public.wholesale_applications
  WHERE id = '92000000-0000-4000-8000-000000000401';
DELETE FROM public.membership_store_scopes
  WHERE id = '92000000-0000-4000-8000-000000000301';
DELETE FROM public.memberships
  WHERE id IN ('92000000-0000-4000-8000-000000000201',
    '92000000-0000-4000-8000-000000000202');
DELETE FROM public.organizations
  WHERE id IN ('92000000-0000-4000-8000-000000000101',
    '92000000-0000-4000-8000-000000000102');
COMMIT;
`

async function provisionWholesaleFixture() {
  wholesaleFixtureTouched = true
  const userId = await runPsql(
    `SELECT id FROM auth.users WHERE email = '${email}' LIMIT 1;`,
    'wholesale_user_lookup',
  )
  assert.match(userId, /^[0-9a-f-]{36}$/i, 'browser user must resolve to one UUID')
  await runPsql(`
    ${wholesaleFixtureCleanupSql}
    BEGIN;
    INSERT INTO public.organizations (id, organization_type, display_name, status, created_by)
    VALUES
      ('92000000-0000-4000-8000-000000000101', 'platform',
        'P5 Browser Platform', 'active', '90000000-0000-4000-8000-000000000001'),
      ('92000000-0000-4000-8000-000000000102', 'wholesale',
        'P5 Browser Wholesale', 'active', '${userId}');
    INSERT INTO public.memberships (id, user_id, organization_id, organization_type,
      role_definition_id, role_version, status, valid_from)
    VALUES
      ('92000000-0000-4000-8000-000000000201',
        '90000000-0000-4000-8000-000000000001',
        '92000000-0000-4000-8000-000000000101', 'platform',
        '00000000-0000-4000-8000-000000000205', 1, 'active',
        pg_catalog.statement_timestamp() - INTERVAL '1 hour'),
      ('92000000-0000-4000-8000-000000000202', '${userId}',
        '92000000-0000-4000-8000-000000000102', 'wholesale',
        '00000000-0000-4000-8000-000000000201', 1, 'active',
        pg_catalog.statement_timestamp() - INTERVAL '1 hour');
    INSERT INTO public.membership_store_scopes (id, membership_id,
      organization_id, organization_type, store_id, scope_type, status)
    VALUES ('92000000-0000-4000-8000-000000000301',
      '92000000-0000-4000-8000-000000000202',
      '92000000-0000-4000-8000-000000000102', 'wholesale', NULL,
      'organization', 'active');
    INSERT INTO public.wholesale_applications (id, applicant_user_id,
      company_name, country_code, status, assigned_reviewer_membership_id,
      assigned_at, submitted_at)
    VALUES ('92000000-0000-4000-8000-000000000401', '${userId}',
      'P5 Browser Wholesale', 'IT', 'under_review',
      '92000000-0000-4000-8000-000000000201',
      pg_catalog.statement_timestamp() - INTERVAL '1 hour',
      pg_catalog.statement_timestamp() - INTERVAL '2 hours');
    INSERT INTO public.wholesale_qualifications (id, source_application_id,
      organization_id, organization_type, status, valid_from, valid_until,
      reason_code, version)
    VALUES ('92000000-0000-4000-8000-000000000402',
      '92000000-0000-4000-8000-000000000401',
      '92000000-0000-4000-8000-000000000102', 'wholesale', 'active',
      pg_catalog.statement_timestamp() - INTERVAL '1 hour',
      pg_catalog.statement_timestamp() + INTERVAL '30 days',
      'approved_checks_complete', 1);
    UPDATE public.wholesale_applications SET status = 'approved',
      organization_id = '92000000-0000-4000-8000-000000000102',
      owner_membership_id = '92000000-0000-4000-8000-000000000202',
      qualification_id = '92000000-0000-4000-8000-000000000402',
      decided_at = pg_catalog.statement_timestamp()
    WHERE id = '92000000-0000-4000-8000-000000000401';
    COMMIT;
  `, 'wholesale_fixture_setup')
}

async function setSeedPhoneInventory(onHand, label) {
  assert.equal(Number.isInteger(onHand) && onHand >= 0, true)
  const result = await runPsql(`
    UPDATE public.inventory_levels
    SET on_hand = ${onHand}, version = version + 1,
      updated_at = pg_catalog.statement_timestamp()
    WHERE id = '90000000-0000-4000-8000-000000000801'
    RETURNING on_hand;
  `, label)
  assert.equal(result, String(onHand), `${label}_result`)
}

async function evaluate(expression) {
  const result = await send('Runtime.evaluate', {
    expression,
    awaitPromise: true,
    returnByValue: true,
  })
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.text)
  return result.result?.value
}

async function waitFor(expression, label, timeoutMs = 15000) {
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
  await new Promise((resolve) => setTimeout(resolve, 250))
}

async function clickText(selector, text) {
  const clicked = await evaluate(`(() => {
    const node = [...document.querySelectorAll(${JSON.stringify(selector)})]
      .find((item) => item.textContent.trim().includes(${JSON.stringify(text)}));
    if (!node) return false;
    node.click();
    return true;
  })()`)
  assert.equal(clicked, true, `missing clickable text: ${text}`)
}

async function fill(selector, value) {
  const filled = await evaluate(`(() => {
    const node = document.querySelector(${JSON.stringify(selector)});
    if (!node) return false;
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    setter.call(node, ${JSON.stringify(value)});
    node.dispatchEvent(new Event('input', { bubbles: true }));
    node.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  })()`)
  assert.equal(filled, true, `missing input: ${selector}`)
}

async function pressEnter(selector) {
  const focused = await evaluate(`(() => {
    const node = document.querySelector(${JSON.stringify(selector)});
    if (!node) return false;
    node.focus();
    return document.activeElement === node;
  })()`)
  assert.equal(focused, true, `cannot focus input: ${selector}`)
  await send('Input.dispatchKeyEvent', {
    type: 'rawKeyDown', key: 'Enter', code: 'Enter',
    windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13,
  })
  await send('Input.dispatchKeyEvent', {
    type: 'char', key: 'Enter', code: 'Enter', text: '\r',
    windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13,
  })
  await send('Input.dispatchKeyEvent', {
    type: 'keyUp', key: 'Enter', code: 'Enter',
    windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13,
  })
}

async function readNextOtp(mailbox = email) {
  const deadline = Date.now() + 15000
  while (Date.now() < deadline) {
    const search = await fetch(`${MAILPIT_ORIGIN}/api/v1/search?query=${encodeURIComponent(`to:${mailbox}`)}`)
      .then((response) => response.json())
    for (const message of search.messages ?? []) {
      const id = message.ID ?? message.Id ?? message.id
      if (typeof id !== 'string' || seenMailIds.has(id)) continue
      seenMailIds.add(id)
      const detail = await fetch(`${MAILPIT_ORIGIN}/api/v1/message/${encodeURIComponent(id)}`)
        .then((response) => response.json())
      const match = [detail.Text, detail.HTML, detail.text, detail.html]
        .filter((value) => typeof value === 'string').join('\n').match(/\b\d{6}\b/)
      if (match) return match[0]
    }
    await new Promise((resolve) => setTimeout(resolve, 250))
  }
  throw new Error('mailpit_otp_timeout')
}

async function submitCurrentForm(buttonText) {
  await clickText('button[type="submit"]', buttonText)
}

try {
  await connectBrowser()
  await send('Page.enable')
  await send('Runtime.enable')
  await send('Log.enable')

  stage = 'unauthenticated_route_guard'
  await navigate('/cart')
  await waitFor(
    `location.pathname === '/account/login' && location.search.includes('next=%2Fcart')`,
    'unauthenticated-cart-redirect',
  )

  stage = 'signup'
  assert.match(await evaluate('document.body.innerText'), /登录[\s\S]*注册/)

  await clickText('button[role="tab"]', '注册')
  await waitFor(`document.body.innerText.includes('发送注册验证码')`, 'signup-tab')
  await fill('#login-email', email)
  await submitCurrentForm('发送注册验证码')
  await waitFor(`document.body.innerText.includes('验证码已发送')`, 'signup-otp-sent')
  const signupOtp = await readNextOtp()
  await fill('#login-otp', signupOtp)
  await submitCurrentForm('验证并完成注册')
  await waitFor(`location.pathname === '/cart'`, 'signup-cart-return')
  console.log('P5_BROWSER_SIGNUP_PASS')

  stage = 'empty_cart'
  assert.match(await evaluate('document.body.innerText'), /购物车还是空的/)
  assert.equal(await evaluate(`Boolean(document.querySelector('a[href="/"]'))`), true)
  console.log('P5_BROWSER_EMPTY_CART_PASS')
  await navigate('/')
  await waitFor(`document.body.innerText.includes('模块化智能手机')`, 'catalog-after-signup')

  stage = 'keyboard_search_and_history'
  await fill('input[name="q"]', '模块化')
  await pressEnter('input[name="q"]')
  await waitFor(`location.search.includes('q=')`, 'keyboard-search')
  assert.match(await evaluate('document.body.innerText'), /模块化智能手机/)
  await evaluate('history.back()')
  await waitFor(`location.pathname === '/' && !location.search.includes('q=')`, 'history-back')
  await send('Page.reload', { ignoreCache: true })
  await waitFor(`document.readyState === 'complete'`, 'desktop-reload')

  stage = 'invalid_cart_recovery'
  const initialPhonePut = await evaluate(`(() => {
    const listing = document.querySelector(
      'input[name="listing_id"][value="90000000-0000-4000-8000-000000000501"]',
    );
    if (!listing) return false;
    const quantity = listing.form.querySelector('input[name="quantity"]');
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    setter.call(quantity, '2');
    quantity.dispatchEvent(new Event('input', { bubbles: true }));
    listing.form.querySelector('button[type="submit"]').click();
    return true;
  })()`)
  assert.equal(initialPhonePut, true)
  await waitFor(`location.search.includes('notice=cart-updated')`, 'invalid-cart-seed')
  seedInventoryChanged = true
  await setSeedPhoneInventory(1, 'reduce_seed_inventory')
  await navigate('/cart')
  assert.match(await evaluate('document.body.innerText'), /当前不可结算/)
  const recoveryControl = await evaluate(`(() => {
    const article = [...document.querySelectorAll('article')]
      .find((node) => node.textContent.includes('模块化智能手机'));
    const quantity = article?.querySelector('input[name="quantity"]');
    const update = [...(article?.querySelectorAll('button[type="submit"]') ?? [])]
      .find((node) => node.textContent.trim().includes('更新'));
    return { quantity: quantity?.value, min: quantity?.min, max: quantity?.max,
      quantityDisabled: quantity?.disabled, updateDisabled: update?.disabled };
  })()`)
  assert.deepEqual(recoveryControl, {
    quantity: '1', min: '1', max: '1',
    quantityDisabled: false, updateDisabled: false,
  })
  await clickText('button[type="submit"]', '更新')
  await waitFor(`location.search.includes('notice=cart-updated')`, 'invalid-cart-recovered')
  assert.doesNotMatch(await evaluate('document.body.innerText'), /当前不可结算/)
  await setSeedPhoneInventory(24, 'restore_seed_inventory')
  seedInventoryChanged = false
  console.log('P5_BROWSER_INVALID_CART_RECOVERY_PASS')
  await navigate('/')

  stage = 'retail_cart'
  for (const listingId of [
    '90000000-0000-4000-8000-000000000501',
    '90000000-0000-4000-8000-000000000502',
  ]) {
    const submitted = await evaluate(`(() => {
      const input = document.querySelector('input[name="listing_id"][value="${listingId}"]');
      if (!input) return false;
      input.form.querySelector('button[type="submit"]').click();
      return true;
    })()`)
    assert.equal(submitted, true)
    await waitFor(`location.search.includes('notice=cart-updated')`, `cart-put:${listingId}`)
    await waitFor(`document.readyState === 'complete'`, `cart-put-ready:${listingId}`)
  }
  assert.match(await evaluate('document.body.innerText'), /购物车[\s\S]*2/)
  console.log('P5_BROWSER_CART_PUT_PASS')

  await clickText('a[href="/cart"]', '购物车')
  await waitFor(`location.pathname === '/cart'`, 'cart-page')
  const cartText = await evaluate('document.body.innerText')
  assert.match(cartText, /模块化智能手机/)
  assert.match(cartText, /USB-C 快充套装/)
  await clickText('a[href="/checkout"]', '继续结算')
  await waitFor(`location.pathname === '/checkout'`, 'checkout-page')
  assert.match(await evaluate('document.body.innerText'), /Aurora Mobile[\s\S]*Circuit Commons/)
  stage = 'checkout_double_submit'
  const doubleSubmitted = await evaluate(`(() => {
    const button = [...document.querySelectorAll('button[type="submit"]')]
      .find((node) => node.textContent.trim().includes('确认提交订单'));
    if (!button) return false;
    button.click();
    button.click();
    return true;
  })()`)
  assert.equal(doubleSubmitted, true, 'checkout submit button missing')
  await waitFor(`location.pathname.startsWith('/account/orders/') && location.search.includes('notice=order-created')`, 'checkout-submit', 20000)
  const orderText = await evaluate('document.body.innerText')
  assert.match(orderText, /订单已创建/)
  assert.match(orderText, /库存[\s\S]*已预留/)
  orderPath = await evaluate('location.pathname')
  assert.match(orderPath, /^\/account\/orders\/[0-9a-f-]{36}$/i)
  console.log('P5_BROWSER_CHECKOUT_PASS')

  stage = 'cancel_confirmation'
  const confirmed = await evaluate(`(() => {
    const checkbox = document.querySelector('input[name="confirm_cancel"]');
    if (!checkbox) return false;
    checkbox.click();
    return checkbox.checked;
  })()`)
  assert.equal(confirmed, true, 'cancel confirmation checkbox missing')
  await submitCurrentForm('取消整个订单')
  await waitFor(`location.search.includes('notice=order-cancelled')`, 'cancel-order', 20000)
  const cancelledText = await evaluate('document.body.innerText')
  assert.match(cancelledText, /订单已取消/)
  assert.match(cancelledText, /库存[\s\S]*已释放/)
  console.log('P5_BROWSER_CANCEL_PASS')

  stage = 'mobile_layout'
  await send('Emulation.setDeviceMetricsOverride', {
    width: 390,
    height: 844,
    deviceScaleFactor: 1,
    mobile: true,
  })
  await send('Page.reload', { ignoreCache: true })
  await waitFor(`document.readyState === 'complete'`, 'mobile-reload')
  assert.equal(await evaluate('document.documentElement.scrollWidth <= window.innerWidth'), true)
  console.log('P5_BROWSER_MOBILE_PASS')

  stage = 'cross_user_order_denied'
  await navigate('/account')
  await clickText('button', '退出当前账号')
  await waitFor(`location.pathname === '/account/login'`, 'logout')
  await clickText('button[role="tab"]', '注册')
  await waitFor(`document.body.innerText.includes('发送注册验证码')`, 'other-signup-tab')
  await fill('#login-email', otherEmail)
  await submitCurrentForm('发送注册验证码')
  await waitFor(`document.body.innerText.includes('验证码已发送')`, 'other-signup-otp-sent')
  const otherSignupOtp = await readNextOtp(otherEmail)
  await fill('#login-otp', otherSignupOtp)
  await submitCurrentForm('验证并完成注册')
  await waitFor(`location.pathname === '/'`, 'other-signup-redirect')
  await navigate(orderPath)
  await waitFor(
    `document.body.innerText.includes('This page could not be found')`,
    'cross-user-order-not-found',
  )
  console.log('P5_BROWSER_CROSS_USER_ORDER_DENIED_PASS')
  await navigate('/account')
  await clickText('button', '退出当前账号')
  await waitFor(`location.pathname === '/account/login'`, 'other-logout')

  stage = 'existing_user_login'
  await fill('#login-email', email)
  await submitCurrentForm('发送登录验证码')
  await waitFor(`document.body.innerText.includes('验证码已发送')`, 'login-otp-sent')
  const loginOtp = await readNextOtp()
  await fill('#login-otp', loginOtp)
  await submitCurrentForm('验证并登录')
  await waitFor(`location.pathname === '/'`, 'login-redirect')
  assert.equal(await evaluate(`Boolean(document.querySelector('a[href="/account"]'))`), true)
  console.log('P5_BROWSER_EXISTING_LOGIN_PASS')

  stage = 'wholesale_fixture'
  await provisionWholesaleFixture()
  stage = 'wholesale_catalog_moq'
  await navigate('/')
  await waitFor(`document.body.innerText.includes('已认证批发价')`, 'wholesale-price')
  const wholesaleCard = await evaluate(`(() => {
    const listing = document.querySelector(
      'input[name="listing_id"][value="90000000-0000-4000-8000-000000000501"]',
    );
    if (!listing) return null;
    const form = listing.form;
    const quantity = form.querySelector('input[name="quantity"]');
    const button = form.querySelector('button[type="submit"]');
    return {
      quantity: quantity?.value,
      min: quantity?.min,
      disabled: button?.disabled,
      text: form.closest('article')?.innerText,
    };
  })()`)
  assert.equal(wholesaleCard?.quantity, '5')
  assert.equal(wholesaleCard?.min, '5')
  assert.equal(wholesaleCard?.disabled, false)
  assert.match(wholesaleCard?.text ?? '', /已认证批发价[\s\S]*起订 5 件/)
  const wholesaleSubmitted = await evaluate(`(() => {
    const listing = document.querySelector(
      'input[name="listing_id"][value="90000000-0000-4000-8000-000000000501"]',
    );
    if (!listing) return false;
    listing.form.querySelector('button[type="submit"]').click();
    return true;
  })()`)
  assert.equal(wholesaleSubmitted, true)
  await waitFor(`location.search.includes('notice=cart-updated')`, 'wholesale-cart-put')
  assert.match(await evaluate('document.body.innerText'), /购物车[\s\S]*5/)
  console.log('P5_BROWSER_WHOLESALE_MOQ_PASS')

  stage = 'browser_error_check'
  const overlay = await evaluate(`Boolean(document.querySelector('[data-nextjs-dialog], .vite-error-overlay, #webpack-dev-server-client-overlay'))`)
  assert.equal(overlay, false)
  const actionableBrowserErrors = browserErrors.filter((message) =>
    !/WebSocket connection to .*\/_next\/hmr.*Page entered Back-Forward Cache[.]/.test(message),
  )
  assert.deepEqual(actionableBrowserErrors, [])
  console.log('P5_BROWSER_E2E_PASS')
} catch (error) {
  console.error(`P5_BROWSER_E2E_FAIL:${stage}`)
  console.error(error instanceof Error ? error.message : 'unknown_browser_failure')
  process.exitCode = 1
} finally {
  if (seedInventoryChanged) {
    try { await setSeedPhoneInventory(24, 'restore_seed_inventory_cleanup') } catch {
      console.error('P5_BROWSER_E2E_FAIL:seed_inventory_cleanup')
      process.exitCode = 1
    }
  }
  if (wholesaleFixtureTouched) {
    try { await runPsql(wholesaleFixtureCleanupSql, 'wholesale_fixture_cleanup') } catch {
      console.error('P5_BROWSER_E2E_FAIL:wholesale_fixture_cleanup')
      process.exitCode = 1
    }
  }
  if (socket) {
    try { await send('Browser.close') } catch {}
    socket.close()
  }
}
