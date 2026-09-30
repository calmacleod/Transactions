import { expect, test } from "@playwright/test"

test("offline transaction rendering stays bounded while search covers the entire snapshot", async ({ page }) => {
  await page.goto("/session/new")
  await page.getByLabel("Email").fill("one@example.com")
  await page.getByLabel("Password").fill("password")
  await page.getByRole("button", { name: "Sign in" }).click()
  await expect(page.getByRole("heading", { name: "Spending dashboard" })).toBeVisible()
  await page.goto("/offline")
  await expect(page.getByRole("button", { name: "Transactions", exact: true })).toBeVisible()
  await page.evaluate(() => {
    const transactions = Array.from({ length: 1000 }, (_, id) => ({
      id, description: `Render audit merchant ${id}`, occurred_on_label: "Sep 30, 2026", amount_label: "$10.00", category: { name: "Audit", color: "#64748b" },
    }))
    window.dispatchEvent(new CustomEvent("transactions-offline-snapshot", { detail: { generated_at: new Date().toISOString(), pages: { transactions: { transactions } } } }))
  })
  const started = Date.now()
  await page.getByRole("button", { name: "Transactions", exact: true }).click()
  await expect(page.getByTestId("offline-transaction")).toHaveCount(25)
  await expect(page.getByText("Page 1 of 40", { exact: true })).toBeVisible()
  console.log(JSON.stringify({ render_ms: Date.now() - started, nodes: await page.locator("*").count() }))
  await page.getByRole("button", { name: "Next", exact: true }).click()
  await expect(page.getByText("Render audit merchant 25", { exact: true })).toBeVisible()
  await page.getByPlaceholder("Search offline transactions").fill("Render audit merchant 999")
  await expect(page.getByTestId("offline-transaction")).toHaveCount(1)
  await expect(page.getByText("Render audit merchant 999", { exact: true })).toBeVisible()
  await expect(page.getByText("Page 1 of 1", { exact: true })).toBeVisible()
  await expect(page.getByRole("button", { name: "Next", exact: true })).toBeDisabled()
  await page.getByPlaceholder("Search offline transactions").fill("missing merchant")
  await expect(page.getByTestId("offline-transaction")).toHaveCount(0)
  await expect(page.getByRole("button", { name: "Previous", exact: true })).toBeDisabled()
})

test("import preview mounts one layout and preserves edits when the viewport changes", async ({ page }) => {
  await page.goto("/session/new")
  await page.getByLabel("Email").fill("one@example.com")
  await page.getByLabel("Password").fill("password")
  await page.getByRole("button", { name: "Sign in" }).click()
  await expect(page.getByRole("heading", { name: "Spending dashboard" })).toBeVisible()
  await page.getByRole("link", { name: "Imports", exact: true }).click()
  await page.route("**/imports/*/preview", async (route) => {
    const response = await route.fetch()
    const data = await response.json()
    data.props.import_batch = { ...data.props.import_batch, filename: "render-review.csv", active: true, read_only: false }
    data.props.rows = ["ONE", "TWO", "THREE"].map((name, index) => ({
      id: index + 1, row_number: index + 1, occurred_on: "2026-09-10", description: `RENDER REVIEW ${name}`,
      amount: "10.00", direction: "debit", card_last4: "2222", included: true, classification_status: "manual", raw_data: {},
    }))
    data.props.groups = []
    data.props.actions.classification_stream = null
    await route.fulfill({ response, json: data })
  })
  await page.locator('a[href$="/preview"]').first().click()
  await expect(page.getByRole("heading", { name: "render-review.csv", exact: true })).toBeVisible()
  await expect(page.getByRole("button", { name: /^Select date for row/ })).toHaveCount(3)
  await page.locator("table input").first().fill("EDITED REVIEW ROW")
  await page.getByRole("heading", { name: "render-review.csv", exact: true }).click()
  await page.getByRole("button", { name: "Select date for row 1", exact: true }).click()
  await expect(page.getByRole("dialog", { name: "Select date for row 1", exact: true })).toBeVisible()
  await page.getByRole("button", { name: "Next month", exact: true }).click()
  await page.getByRole("dialog", { name: "Select date for row 1", exact: true }).getByRole("button", { name: "15", exact: true }).click()
  await expect(page.getByRole("dialog")).toHaveCount(0)
  await page.setViewportSize({ width: 390, height: 844 })
  await expect(page.getByRole("button", { name: /^Select date for row/ })).toHaveCount(3)
  await expect.poll(() => page.locator("input").evaluateAll((inputs) => inputs.filter((input) => input.value === "EDITED REVIEW ROW").length)).toBe(1)
  await page.setViewportSize({ width: 1280, height: 720 })
  await expect.poll(() => page.locator("input").evaluateAll((inputs) => inputs.filter((input) => input.value === "EDITED REVIEW ROW").length)).toBe(1)
})
