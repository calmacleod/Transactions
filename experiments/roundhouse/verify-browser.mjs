import assert from 'node:assert/strict';
import {chromium, expect} from '@playwright/test';

const base = process.argv[2];
assert(base && /^http:\/\/127\.0\.0\.1:\d+$/.test(base),
  'Usage: node experiments/roundhouse/verify-browser.mjs http://127.0.0.1:<port>');
const browser = await chromium.launch({headless: true});
try {
  const page = await browser.newPage();
  const errors = [];
  const cableFrames = [];
  page.on('websocket', socket => socket.on('framereceived', frame => {
    cableFrames.push(JSON.parse(frame.payload.toString()));
  }));
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => {
    if (response.status() >= 500) errors.push(`${response.status()} ${response.url()}`);
  });
  await page.goto(base + '/session/new');
  await page.getByLabel('Email', {exact: true}).fill('spinel@example.test');
  await page.getByLabel('Password', {exact: true}).fill('spinel-local-experiment');
  await page.getByRole('button', {name: 'Sign in', exact: true}).click();
  await page.waitForURL(base + '/', {timeout: 15000});
  await page.getByRole('link', {name: 'Transactions', exact: true}).first().click();
  await page.waitForURL(base + '/transactions');
  for (const path of ['/', '/transactions', '/spending', '/imports', '/budgets',
    '/subcategories', '/insights', '/settings', '/ai_preferences', '/admin',
    '/admin/ai_controls', '/admin/models', '/offline']) {
    const response = await page.goto(base + path);
    assert.equal(response.status(), 200, path);
    assert.equal(new URL(page.url()).pathname, path);
    await page.locator('main').waitFor({state: 'visible', timeout: 10000});
    assert((await page.locator('main').innerText()).length > 30, path + ' empty page');
    console.log(path + ': rendered');
  }
  if (process.argv.includes('--chat')) {
    await page.goto(base + '/transactions');
    await page.getByPlaceholder('Ask about the current filtered set...').fill('Check my budget using a tool');
    await page.getByRole('button', {name: 'Ask', exact: true}).click();
    const chat = page.getByRole('dialog', {name: 'Transaction chat', exact: true});
    await expect(chat).toContainText('Local provider answer with $17.00', {timeout: 15000});
    await expect.poll(() => cableFrames.some(frame => frame.type === 'confirm_subscription')).toBe(true);
    cableFrames.length = 0;
    await page.getByPlaceholder('Ask a follow-up...').fill('Check my budget again');
    await chat.getByRole('button', {name: 'Send', exact: true}).click();
    await expect.poll(() => cableFrames.some(frame =>
      frame.message?.type === 'message_update' &&
      frame.message.message?.role === 'assistant' &&
      frame.message.message?.status === 'complete'), {timeout: 15000}).toBe(true);
    console.log('Configured chat UI, authenticated Cable subscription and live completed response: passed');
  }
  assert.deepEqual(errors, [], 'Browser/runtime errors');
  await page.goto(base + '/');
  await page.screenshot({path: 'tmp/roundhouse/native-dashboard.png', fullPage: true});
  console.log('Normal browser sign-in, Inertia navigation and thirteen Svelte pages: passed');
} finally {
  await browser.close();
}
