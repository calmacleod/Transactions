import { expect, test } from "@playwright/test"

test.beforeEach(async ({ page }) => {
  const browserErrors = []

  page.on("pageerror", (error) => browserErrors.push(error.message))
  page.on("console", (message) => {
    if (message.type() === "error") browserErrors.push(message.text())
  })

  page.browserErrors = browserErrors
  await signIn(page)
})

test.afterEach(async ({ page }) => {
  expect(page.browserErrors).toEqual([])
})

test("dashboard renders without runtime errors and exposes primary controls", async ({ page }) => {
  await page.goto("/")

  await expect(page.getByRole("heading", { name: "Spending dashboard" })).toBeVisible()
  await expect(page.getByRole("button", { name: "Classify pending" })).toBeVisible()
  await expect(page.getByRole("button", { name: "Generate insights" })).toBeVisible()
  await expect(page.getByRole("link", { name: /Month spend/i })).toBeVisible()
  await expect(page.getByRole("heading", { name: "Category allocation" })).toBeVisible()
  await expect(page.getByRole("heading", { name: "Latest transactions" })).toBeVisible()

  await expectNoViewportOverflow(page)
  await expectNoUnnamedVisibleButtons(page)
})

test("dashboard desktop layout does not clip the latest transaction table", async ({ page }) => {
  await page.setViewportSize({ width: 1180, height: 768 })
  await page.goto("/")

  const latestPanel = page.getByTestId("latest-transactions-panel")
  await expect(latestPanel).toBeVisible()

  await expectElementFitsItsBox(page, "[data-testid='latest-transactions-scroll']")
  await expectNoViewportOverflow(page)
})

test("internal navigation links prefetch Inertia payloads", async ({ page }) => {
  await page.goto("/")

  const prefetchRequest = page.waitForRequest((request) => {
    return request.url().includes("/transactions") && request.headers().purpose === "prefetch"
  })

  await page.getByRole("link", { name: /^Transactions$/ }).first().hover()
  await prefetchRequest
})

test("sidebar active state follows Inertia navigation without reload", async ({ page }) => {
  await page.goto("/")

  const dashboardLink = page.getByRole("link", { name: /^Dashboard$/ }).first()
  const transactionsLink = page.getByRole("link", { name: /^Transactions$/ }).first()
  const insightsLink = page.getByRole("link", { name: /^Insights$/ }).first()

  await expect(dashboardLink).toHaveClass(/bg-primary/)

  await transactionsLink.click()
  await expect(page.getByRole("heading", { name: "Transactions" })).toBeVisible()
  await expect(transactionsLink).toHaveClass(/bg-primary/)
  await expect(dashboardLink).not.toHaveClass(/bg-primary/)

  await insightsLink.click()
  await expect(page.getByRole("heading", { name: "Insights" })).toBeVisible()
  await expect(insightsLink).toHaveClass(/bg-primary/)
  await expect(transactionsLink).not.toHaveClass(/bg-primary/)
})

test("app chrome navigation starts on mouse down", async ({ page }) => {
  await page.goto("/")

  const transactionsLink = page.getByRole("link", { name: /^Transactions$/ }).first()
  const box = await transactionsLink.boundingBox()
  expect(box).not.toBeNull()

  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2)
  await page.mouse.down()
  await expect(page.getByRole("heading", { name: "Transactions" })).toBeVisible()
  await page.mouse.up()
})

test("jobs navigation leaves the Inertia shell for Mission Control", async ({ page }) => {
  await page.goto("/")

  await page.getByRole("link", { name: /^Jobs$/ }).click()

  await expect(page).toHaveURL(/\/admin\/jobs/)
  await expect(page.locator("#app")).toHaveCount(0)
  await expect(page.locator("body")).toContainText("Pending jobs")
})

test("transactions page keeps dense controls usable on desktop and mobile", async ({ page }) => {
  await page.goto("/transactions")

  await expect(page.getByRole("heading", { name: "Transactions" })).toBeVisible()
  await expect(page.getByRole("button", { name: "Apply filters" })).toBeVisible()
  await expect(page.getByRole("button", { name: "Save" })).toBeVisible()
  await expect(page.getByRole("columnheader", { name: "Description" })).toBeVisible()
  await expect(page.getByRole("columnheader", { name: "Confidence" })).toHaveCount(0)
  await expect(page.locator(".confidence-chip").first()).toBeVisible()
  await expectDesktopCategoryPickersAreLazy(page)
  await expectTransactionDetailsStayInDescriptionColumn(page)
  await expectButtonsFeelNative(page)

  await expectNoViewportOverflow(page)
  await expectNoUnnamedVisibleButtons(page)

  await page.setViewportSize({ width: 390, height: 844 })
  await page.reload()

  await expect(page.getByRole("heading", { name: "Transactions" })).toBeVisible()
  await expect(page.getByLabel("Search")).toBeVisible()
  await expect(page.getByRole("columnheader", { name: "Description" })).toHaveCount(0)

  const mobileRow = page.getByTestId("mobile-transaction-row").first()
  await expect(mobileRow).toBeVisible()
  await expect(mobileRow).toContainText(/May \d{1,2}, 2026/)
  await expect(mobileRow).toContainText("65%")
  await expect(mobileRow).toContainText(/NEIGHBOURHOOD RESTAURANT|LOCAL GROCERY MARKET/)
  await expect(mobileRow).toContainText(/\$[0-9]+\.[0-9]{2}/)
  await expect(mobileRow.getByRole("combobox")).toBeVisible()

  await mobileRow.click({ position: { x: 44, y: 20 } })
  await expect(page.getByText("1 selected")).toBeVisible()
  await expectNoViewportOverflow(page)
})

test("mobile title bar stays fixed without covering page content", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto("/transactions")

  const header = page.locator("header").first()
  const heading = page.getByRole("heading", { name: "Transactions" })

  await expect(header).toBeVisible()
  await expect(heading).toBeVisible()

  const initial = await measureFixedHeader(page, header, heading)
  expect(initial.position).toBe("fixed")
  expect(initial.headerTop).toBeLessThanOrEqual(1)
  expect(initial.headingTop).toBeGreaterThan(initial.headerBottom)

  await page.evaluate(() => window.scrollTo(0, 640))

  const scrolled = await measureFixedHeader(page, header, heading)
  expect(scrolled.position).toBe("fixed")
  expect(scrolled.headerTop).toBeLessThanOrEqual(1)
  expect(scrolled.headerBottom).toBeCloseTo(initial.headerBottom, 1)
})

test("pwa manifest, icon, and service worker registration are intact", async ({ page, request }) => {
  const manifestResponse = await request.get("/manifest.json")
  expect(manifestResponse.ok()).toBe(true)

  const manifest = await manifestResponse.json()
  expect(manifest.display).toBe("standalone")
  expect(manifest.start_url).toBe("/")
  expect(manifest.scope).toBe("/")
  expect(manifest.theme_color).toBe("#fafaf6")
  expect(manifest.background_color).toBe("#fafaf6")
  expect(manifest.icons).toEqual(
    expect.arrayContaining([
      expect.objectContaining({ src: "/icon-20260526.svg", type: "image/svg+xml", sizes: "any" }),
      expect.objectContaining({ src: "/icon-20260526.png", type: "image/png", sizes: "512x512", purpose: "maskable" }),
    ])
  )

  const iconResponse = await request.get("/icon-20260526.png")
  expect(iconResponse.ok()).toBe(true)
  expect(iconResponse.headers()["content-type"]).toContain("image/png")

  const serviceWorkerResponse = await request.get("/service-worker.js")
  expect(serviceWorkerResponse.ok()).toBe(true)
  const serviceWorker = await serviceWorkerResponse.text()
  expect(serviceWorker).toContain("transactions-pwa-v3")
  expect(serviceWorker).not.toContain("/manifest.json")
  expect(serviceWorker).not.toContain("/icon.png")

  await page.goto("/")

  await expect
    .poll(async () => {
      return page.evaluate(async () => {
        if (!("serviceWorker" in navigator)) return "unsupported"

        const registration = await navigator.serviceWorker.getRegistration()
        const worker = registration?.active || registration?.waiting || registration?.installing

        return worker?.scriptURL || "missing"
      })
    })
    .toContain("/service-worker.js")
})

test("transaction quick filters perform Inertia visits", async ({ page }) => {
  await page.goto("/transactions")

  await page.getByRole("button", { name: "Last 30 days" }).click()

  await expect(page).toHaveURL(/quick_range=last_30_days/)
  await expect(page.getByRole("button", { name: "Last 30 days" })).toBeVisible()
})

test("transaction rows only shift-select during a left-button drag", async ({ page }) => {
  await page.goto("/transactions")

  const rows = page.locator("[data-transaction-row-id]")
  await expect(rows.first()).toBeVisible()

  await rows.first().click({ position: { x: 120, y: 20 } })
  await expect(page.getByText("1 selected")).toBeVisible()
  await rows.first().click({ position: { x: 120, y: 20 } })
  await expect(page.getByText("1 selected")).toHaveCount(0)

  await page.keyboard.down("Shift")
  await rows.first().hover()
  await expect(page.getByText("1 selected")).toHaveCount(0)
  await page.keyboard.up("Shift")

  const firstBox = await rows.first().boundingBox()
  const secondBox = await rows.nth(1).boundingBox()
  expect(firstBox).not.toBeNull()
  expect(secondBox).not.toBeNull()

  await page.mouse.move(firstBox.x + firstBox.width / 2, firstBox.y + firstBox.height / 2)
  await page.keyboard.down("Shift")
  await page.mouse.down()
  await page.mouse.move(secondBox.x + secondBox.width / 2, secondBox.y + secondBox.height / 2, { steps: 8 })
  await page.mouse.up()
  await page.keyboard.up("Shift")

  await expect(page.getByText("2 selected")).toBeVisible()

  await page.mouse.move(secondBox.x + secondBox.width / 2, secondBox.y + secondBox.height / 2)
  await page.keyboard.down("Shift")
  await page.mouse.down()
  await page.mouse.move(firstBox.x + firstBox.width / 2, firstBox.y + firstBox.height / 2, { steps: 8 })
  await page.mouse.up()
  await page.keyboard.up("Shift")

  await expect(page.locator("tbody input[type='checkbox']:checked")).toHaveCount(0)
  await expect(page.getByText("2 selected")).toHaveCount(0)
})

test("selected transaction bulk actions float over the viewport", async ({ page }) => {
  await page.goto("/transactions")

  await page.locator("[data-transaction-row-id]").first().click({ position: { x: 120, y: 20 } })

  const bulkBar = page.getByText("1 selected").locator("xpath=ancestor::*[@data-slot='card'][1]")
  await expect(bulkBar).toBeVisible()

  const position = await bulkBar.evaluate((element) => {
    const styles = window.getComputedStyle(element)
    const rect = element.getBoundingClientRect()

    return {
      position: styles.position,
      bottomGap: window.innerHeight - rect.bottom,
      top: rect.top,
    }
  })

  expect(position.position).toBe("fixed")
  expect(position.bottomGap).toBeLessThan(32)
  expect(position.top).toBeGreaterThan(0)
})

test("theme toggle persists dark mode in local storage", async ({ page }) => {
  await page.goto("/")

  await expect.poll(() => currentThemeColor(page)).toBe("#fafaf6")
  await page.getByRole("button", { name: "Switch to dark mode" }).click()
  await expect(page.locator("html")).toHaveClass(/dark/)
  await expect.poll(() => page.evaluate(() => window.localStorage.getItem("transactions-theme"))).toBe("dark")
  await expect.poll(() => currentThemeColor(page)).toBe("#100d06")

  await page.reload()
  await expect(page.locator("html")).toHaveClass(/dark/)
  await expect(page.getByRole("button", { name: "Switch to light mode" })).toBeVisible()
  await expect.poll(() => currentThemeColor(page)).toBe("#100d06")
})

test("secondary pages render without blank or broken Inertia content", async ({ page }) => {
  for (const path of ["/insights", "/models"]) {
    await page.goto(path)
    await expect(page.locator("#app")).not.toBeEmpty()
    await expectNoViewportOverflow(page)
    await expectNoUnnamedVisibleButtons(page)
  }
})

async function signIn(page) {
  await page.goto("/session/new")
  await page.getByLabel("Email").fill("one@example.com")
  await page.getByLabel("Password").fill("password")
  await page.getByRole("button", { name: "Sign in" }).click()
  await expect(page.getByRole("heading", { name: "Spending dashboard" })).toBeVisible()
}

async function expectNoViewportOverflow(page) {
  const overflow = await page.evaluate(() => {
    return {
      documentWidth: document.documentElement.scrollWidth,
      viewportWidth: document.documentElement.clientWidth,
      bodyWidth: document.body.scrollWidth,
    }
  })

  expect(overflow.documentWidth, JSON.stringify(overflow)).toBeLessThanOrEqual(overflow.viewportWidth + 1)
  expect(overflow.bodyWidth, JSON.stringify(overflow)).toBeLessThanOrEqual(overflow.viewportWidth + 1)
}

async function currentThemeColor(page) {
  return page.evaluate(() => document.querySelector('meta[name="theme-color"]')?.getAttribute("content"))
}

async function expectElementFitsItsBox(page, selector) {
  const measurements = await page.locator(selector).evaluate((element) => {
    const rect = element.getBoundingClientRect()
    return {
      clientWidth: element.clientWidth,
      scrollWidth: element.scrollWidth,
      rectWidth: rect.width,
      text: element.textContent?.trim().replace(/\s+/g, " ").slice(0, 120),
    }
  })

  expect(measurements.scrollWidth, JSON.stringify(measurements)).toBeLessThanOrEqual(measurements.clientWidth + 1)
}

async function expectNoUnnamedVisibleButtons(page) {
  const unnamedButtons = await page.locator("button:visible").evaluateAll((buttons) => {
    return buttons
      .map((button) => ({
        text: button.textContent?.trim(),
        ariaLabel: button.getAttribute("aria-label"),
        title: button.getAttribute("title"),
        html: button.outerHTML.slice(0, 160),
      }))
      .filter((button) => !button.text && !button.ariaLabel && !button.title)
  })

  expect(unnamedButtons).toEqual([])
}

async function expectButtonsFeelNative(page) {
  const offenders = await page.locator("button:visible, [data-slot='button']:visible").evaluateAll((elements) => {
    return elements
      .map((element) => {
        const styles = window.getComputedStyle(element)

        return {
          text: element.textContent?.trim(),
          ariaLabel: element.getAttribute("aria-label"),
          draggable: element.draggable,
          userSelect: styles.userSelect,
          webkitUserSelect: styles.webkitUserSelect,
          touchAction: styles.touchAction,
          html: element.outerHTML.slice(0, 180),
        }
      })
      .filter((element) => element.draggable || !["none", "contain"].includes(element.userSelect) || element.touchAction !== "manipulation")
  })

  expect(offenders).toEqual([])
}

async function expectDesktopCategoryPickersAreLazy(page) {
  const row = page.locator("[data-transaction-row-id]").first()
  await expect(row.getByRole("combobox")).toHaveCount(0)

  const categoryButton = row.getByRole("button", { name: /Change category for/i })
  await expect(categoryButton).toBeVisible()
  await categoryButton.click()
  await expect(row.getByRole("combobox")).toBeVisible()
}

async function expectTransactionDetailsStayInDescriptionColumn(page) {
  const rows = page.locator("[data-transaction-row-id]")
  await expect(rows.first()).toBeVisible()

  const overflowingRows = await rows.evaluateAll((elements) => {
    return elements
      .map((element) => {
        const cells = element.querySelectorAll("td")
        const reason = cells[2].querySelector("p.mt-1")

        return {
          reasonClientWidth: reason.clientWidth,
          reasonScrollWidth: reason.scrollWidth,
          descriptionRight: cells[2].getBoundingClientRect().right,
          categoryLeft: cells[3].getBoundingClientRect().left,
          text: reason.textContent?.trim().slice(0, 100),
        }
      })
      .filter((row) => row.reasonScrollWidth > row.reasonClientWidth + 1 || row.descriptionRight > row.categoryLeft + 1)
  })

  expect(overflowingRows).toEqual([])
}

async function measureFixedHeader(page, header, heading) {
  const position = await header.evaluate((element) => window.getComputedStyle(element).position)
  const headerBox = await header.boundingBox()
  const headingBox = await heading.boundingBox()

  expect(headerBox).not.toBeNull()
  expect(headingBox).not.toBeNull()

  return {
    position,
    headerTop: headerBox.y,
    headerBottom: headerBox.y + headerBox.height,
    headingTop: headingBox.y,
  }
}
