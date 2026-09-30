import { expect, test } from "@playwright/test"

for (const layout of ["desktop", "mobile"]) {
  test(`manual import category survives a late classification update on ${layout}`, async ({ page }) => {
    await page.setViewportSize(layout === "mobile" ? { width: 390, height: 844 } : { width: 1280, height: 720 })
    let cableSocket
    let subscription
    await page.routeWebSocket(/\/cable(?:\?|$)/, (socket) => {
      cableSocket = socket
      socket.send(JSON.stringify({ type: "welcome" }))
      socket.onMessage((message) => {
        const command = JSON.parse(message)
        if (command.command === "subscribe") {
          subscription = command.identifier
          socket.send(JSON.stringify({ type: "confirm_subscription", identifier: subscription }))
        }
      })
    })

    await page.goto("/session/new")
    await page.getByLabel("Email").fill("one@example.com")
    await page.getByLabel("Password").fill("password")
    await page.getByRole("button", { name: "Sign in" }).click()
    await page.getByRole("button", { name: "Upload transactions" }).click()
    await page.getByRole("dialog", { name: "Upload transactions" }).getByLabel("Upload transactions").setInputFiles({
      name: `manual-${layout}.csv`, mimeType: "text/csv",
      buffer: Buffer.from(`2026-05-22,UNIQUE ${layout.toUpperCase()} MERCHANT #041,17.24,,2222\n`),
    })
    await page.getByRole("button", { name: "Review CSV" }).click()
    await expect(page).toHaveURL(/\/imports\/\d+\/preview/)
    subscription = undefined
    cableSocket = undefined
    await page.reload()

    const props = await page.locator('script[data-page="app"]').evaluate((element) => JSON.parse(element.textContent).props)
    const groceries = props.categories.find((category) => category.name === "Groceries")
    const restaurants = props.categories.find((category) => category.name === "Restaurants")
    const categorySelect = page.locator("select").filter({ has: page.locator("option", { hasText: "Unclassified" }) })
    await categorySelect.selectOption(String(groceries.id))
    await expect.poll(() => Boolean(subscription)).toBe(true)

    cableSocket.send(JSON.stringify({
      identifier: subscription,
      message: { type: "row_classified", row: {
        id: props.rows[0].id, category_id: restaurants.id, category: restaurants,
        classification_status: "classified", classification_reason: "Late automatic suggestion", classification_confidence: 0.8,
      } },
    }))
    await page.waitForTimeout(100)
    await expect(categorySelect).toHaveValue(String(groceries.id))
    await expect(page.getByText("Manually classified.", { exact: true })).toBeVisible()

    const committed = page.waitForRequest((request) => request.method() === "POST" && /\/imports\/\d+\/commit/.test(request.url()))
    await page.getByRole("button", { name: "Import 1", exact: true }).click()
    const request = await committed
    expect(request.postDataJSON().import.rows[0]).toMatchObject({ category_id: groceries.id, manually_classified: true })
    await expect(page.getByRole("heading", { name: "Spending dashboard" })).toBeVisible()
  })
}
