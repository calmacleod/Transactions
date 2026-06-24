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
  await expect(page.getByRole("button", { name: "Upload transactions" })).toBeVisible()
  await page.getByRole("button", { name: "Upload transactions" }).click()
  const uploadDialog = page.getByRole("dialog", { name: "Upload transactions" })
  await expect(uploadDialog.getByLabel("Upload transactions")).toBeAttached()
  await expect(page.getByRole("button", { name: "Review CSV" })).toBeVisible()
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

test("dashboard top merchants panel stays within the mobile viewport", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto("/")

  await expect(page.getByTestId("top-merchants-panel")).toBeVisible()

  await expectElementFitsItsBox(page, "[data-testid='top-merchants-panel']")
  await expectAllElementsFitTheirBoxes(page, "[data-testid='top-merchant-row']")
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
  await expect(page.getByRole("heading", { name: "Transactions", exact: true })).toBeVisible()
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
  await expect(page.getByRole("heading", { name: "Transactions", exact: true })).toBeVisible()
  await page.mouse.up()
})

test("desktop sidebar can collapse to an icon rail and preview on hover", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 720 })
  await page.goto("/")

  const sidebar = page.getByTestId("desktop-sidebar")
  await expect(sidebar).toBeVisible()

  const expandedWidth = await sidebar.evaluate((element) => element.getBoundingClientRect().width)
  expect(expandedWidth).toBeLessThan(256)
  expect(expandedWidth).toBeGreaterThan(200)
  const transactionsIcon = sidebar.getByTestId("sidebar-icon-transactions")
  const expandedIconBox = await transactionsIcon.boundingBox()
  expect(expandedIconBox).not.toBeNull()

  await page.getByRole("button", { name: "Collapse sidebar" }).click()
  await expect.poll(() => sidebar.evaluate((element) => element.getBoundingClientRect().width)).toBeLessThan(80)
  const activeRailLink = sidebar.getByRole("link", { name: "Dashboard", exact: true })
  const activeRailBox = await activeRailLink.boundingBox()
  expect(activeRailBox.width).toBeCloseTo(activeRailBox.height, 0)
  const collapsedIconBox = await transactionsIcon.boundingBox()
  expect(collapsedIconBox.width).toBeCloseTo(expandedIconBox.width, 0)
  expect(collapsedIconBox.height).toBeCloseTo(expandedIconBox.height, 0)
  expect(Math.abs(collapsedIconBox.x - expandedIconBox.x)).toBeLessThanOrEqual(1)

  const collapsedMainLeft = await page.locator("main").evaluate((element) => element.getBoundingClientRect().left)
  expect(collapsedMainLeft).toBeLessThan(90)

  await page.mouse.move(640, 360)
  await sidebar.getByRole("link", { name: "Transactions", exact: true }).hover()
  await expect.poll(() => sidebar.evaluate((element) => element.getBoundingClientRect().width)).toBeGreaterThan(200)
  await expect.poll(() => page.locator("main").evaluate((element) => element.getBoundingClientRect().left)).toBe(collapsedMainLeft)
  const previewIconBox = await transactionsIcon.boundingBox()
  expect(previewIconBox.width).toBeCloseTo(expandedIconBox.width, 0)
  expect(previewIconBox.height).toBeCloseTo(expandedIconBox.height, 0)
  expect(Math.abs(previewIconBox.x - expandedIconBox.x)).toBeLessThanOrEqual(1)

  await page.getByRole("button", { name: "Pin expanded sidebar" }).click()
  await expect.poll(() => page.locator("main").evaluate((element) => element.getBoundingClientRect().left)).toBeGreaterThan(200)
  const pinnedIconBox = await transactionsIcon.boundingBox()
  expect(pinnedIconBox.width).toBeCloseTo(expandedIconBox.width, 0)
  expect(pinnedIconBox.height).toBeCloseTo(expandedIconBox.height, 0)
  expect(Math.abs(pinnedIconBox.x - expandedIconBox.x)).toBeLessThanOrEqual(1)

  await page.mouse.move(640, 360)
  await expect.poll(() => sidebar.evaluate((element) => element.getBoundingClientRect().width)).toBeGreaterThan(200)
})

test("jobs navigation opens Mission Control in an admin modal", async ({ page }) => {
  await page.goto("/admin")

  await page.getByRole("button", { name: /^Jobs$/ }).click()

  const jobsDialog = page.getByRole("dialog", { name: "Jobs" })
  await expect(jobsDialog).toBeVisible()
  await expect(page).toHaveURL(/\/admin$/)
  await expect(jobsDialog.locator("iframe")).toHaveAttribute("src", "/admin/jobs")
  await expect(page.frameLocator("iframe[title='Jobs']").locator("body")).toContainText("Pending jobs")

  await page.getByRole("button", { name: "Close admin tool" }).click()
  await expect(jobsDialog).toBeHidden()
})

test("models sorting preserves the user's scroll position", async ({ page }) => {
  await page.setViewportSize({ width: 900, height: 520 })
  await page.goto("/admin/models")

  await expect(page.getByRole("heading", { name: "Models" })).toBeVisible()
  const catalogScroll = page.getByTestId("models-catalog-scroll")
  await expect(catalogScroll).toBeVisible()

  await page.evaluate(() => window.scrollTo(0, 155))
  const tableBefore = await catalogScroll.evaluate((element) => {
    element.scrollLeft = 260
    return element.scrollLeft
  })

  const before = await page.evaluate(() => window.scrollY)
  expect(before).toBeGreaterThan(0)

  await page.getByRole("button", { name: /Input \/ Output/ }).click()
  await expect(page).toHaveURL(/sort=price/)

  await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(before)
  await expect.poll(() => catalogScroll.evaluate((element) => element.scrollLeft)).toBe(tableBefore)
})

test("transactions page keeps dense controls usable on desktop and mobile", async ({ page }) => {
  await page.goto("/transactions")

  await expect(page.getByRole("heading", { name: "Transactions", exact: true })).toBeVisible()
  await page.getByRole("button", { name: "Show filters" }).click()
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

  await expect(page.getByRole("heading", { name: "Transactions", exact: true })).toBeVisible()
  await page.getByRole("button", { name: "Show filters" }).click()
  await expect(page.getByLabel("Search")).toBeVisible()
  await expect(page.getByRole("columnheader", { name: "Description" })).toHaveCount(0)

  const mobileRow = page.getByTestId("mobile-transaction-row").first()
  await expect(mobileRow).toBeVisible()
  await expect(mobileRow).toContainText(/May \d{1,2}, 2026/)
  await expect(mobileRow).toContainText("65%")
  await expect(mobileRow).toContainText(/NEIGHBOURHOOD RESTAURANT|LOCAL GROCERY MARKET/)
  await expect(mobileRow).toContainText(/\$[0-9]+\.[0-9]{2}/)
  await expect(mobileRow.getByRole("button", { name: /Change category for/i })).toBeVisible()

  await mobileRow.getByRole("checkbox").check()
  await expect(page.getByText("1 selected")).toBeVisible()
  await expectNoViewportOverflow(page)
})

test("transaction note and subcategory controls open from the row", async ({ page }) => {
  await page.goto("/transactions")

  const row = page.locator("[data-transaction-row-id]").nth(1)
  await expect(row).toBeVisible()

  await row.getByRole("button", { name: "Add note" }).click()
  await expect(row.locator("textarea[placeholder='Personal notes']")).toBeVisible()

  await row.getByRole("button", { name: "Add subcategory" }).click()
  const subcategorySelect = row.locator("select").first()
  await expect(subcategorySelect).toBeVisible()

  await subcategorySelect.selectOption({ label: "Gift" })
  await expect(row.getByText("Gift")).toBeVisible()
})

test("mobile title bar stays fixed without covering page content", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto("/transactions")

  const header = page.locator("header").first()
  const heading = page.getByRole("heading", { name: "Transactions", exact: true })

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
  expect(serviceWorker).toContain("transactions-pwa-v7")
  expect(serviceWorker).toContain("transactions-pages-v2")
  expect(serviceWorker).toContain("VITE_PATH_PATTERN")
  expect(serviceWorker).toContain('OFFLINE_FALLBACK_PATH = "/offline"')
  expect(serviceWorker).toContain("isCacheableViteAsset")
  expect(serviceWorker).toContain("navigationPreload")
  expect(serviceWorker).not.toContain("vite-dev")
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

test("offline mode renders a read-only snapshot from the PWA cache", async ({ page, context }) => {
  await page.goto("/")

  await expect
    .poll(async () => {
      return page.evaluate(async () => {
        if (!("serviceWorker" in navigator)) return "unsupported"
        await navigator.serviceWorker.ready
        return navigator.serviceWorker.controller ? "controlled" : "ready"
      })
    })
    .not.toBe("unsupported")

  if (await page.evaluate(() => !navigator.serviceWorker.controller)) {
    await page.reload()
    await expect(page.getByRole("heading", { name: "Spending dashboard" })).toBeVisible()
  }

  await expect.poll(() => page.evaluate(async () => Boolean(await caches.match("/offline"))), { timeout: 15_000 }).toBe(true)
  await expect.poll(() => page.evaluate(hasStoredOfflineSnapshot), { timeout: 15_000 }).toBe(true)

  const appOrigin = await page.evaluate(() => window.location.origin)
  await context.setOffline(true)
  try {
    await expect(page.getByTestId("locked-nav-transactions")).toBeDisabled()
    await page.goto(`${appOrigin}/transactions`)
    await expect(page.getByRole("heading", { name: "Read-only copy" })).toBeVisible()
    await expect(page.getByTestId("offline-connection-badge")).toContainText("Offline")
    await expect(page.getByTestId("offline-connection-status")).toContainText("Waiting for the connection")
    await expect(page.getByTestId("locked-sidebar-brand")).toBeVisible()
    await expect(page.getByTestId("locked-nav-dashboard")).toBeDisabled()
    await expect(page.getByTestId("locked-nav-transactions")).toBeDisabled()
    await expect(page.getByRole("button", { name: "Upload transactions" })).toHaveCount(0)
    await expect(page.getByRole("button", { name: "Regenerate" })).toHaveCount(0)
    await expect(page.getByRole("button", { name: "Add" })).toHaveCount(0)
    await page.getByRole("button", { name: "Transactions", exact: true }).click()
    await expect(page.getByText("LOCAL GROCERY MARKET")).toBeVisible()
    await expect(page.getByPlaceholder("Search offline transactions")).toBeVisible()
    await expect(page.getByRole("button", { name: "Apply" })).toHaveCount(0)
    await expect(page.getByRole("button", { name: "Save" })).toHaveCount(0)
    await context.setOffline(false)
    await expect(page.getByTestId("offline-connection-badge")).toContainText("Back online")
    await expect(page.getByTestId("offline-connection-status")).toContainText("Connection restored")
    await expect(page.getByTestId("exit-offline-mode")).toBeVisible()
    await expect(page.getByTestId("locked-nav-dashboard")).toBeDisabled()
    expect(await offlineInertiaExceptionIsPrevented(page)).toBe(true)
    await expect(page.locator("iframe[srcdoc]")).toHaveCount(0)
  } finally {
    await context.setOffline(false)
    page.browserErrors = page.browserErrors.filter((message) => !message.includes("ERR_INTERNET_DISCONNECTED"))
  }
})

function offlineInertiaExceptionIsPrevented(page) {
  return page.evaluate(() => {
    const event = new CustomEvent("inertia:httpException", {
      cancelable: true,
      detail: { response: { data: "<html><body>offline fallback</body></html>" } },
    })

    document.dispatchEvent(event)

    return event.defaultPrevented
  })
}

function hasStoredOfflineSnapshot() {
  return Boolean(window.localStorage.getItem("transactions-offline-snapshot-refreshed-at"))
}

test("transaction quick filters perform Inertia visits", async ({ page }) => {
  await page.goto("/transactions")

  await page.getByRole("button", { name: "Last 30 days" }).click()

  await expect(page).toHaveURL(/quick_range=last_30_days/)
  await expect(page.getByRole("button", { name: "Last 30 days" })).toBeVisible()
})

test("transaction sort links can be toggled repeatedly", async ({ page }) => {
  await page.goto("/transactions")

  const dateSort = page.getByRole("button", { name: /^Date$/ })
  await dateSort.scrollIntoViewIfNeeded()
  const scrollBeforeSort = await page.evaluate(() => window.scrollY)

  await dateSort.click()
  await expect(page).toHaveURL(/sort_direction=asc/)
  await expect.poll(() => page.evaluate((expected) => Math.abs(window.scrollY - expected), scrollBeforeSort)).toBeLessThanOrEqual(20)

  await dateSort.click()
  await expect(page).toHaveURL(/sort_direction=desc/)
  await expect.poll(() => page.evaluate((expected) => Math.abs(window.scrollY - expected), scrollBeforeSort)).toBeLessThanOrEqual(20)
})

test("transaction rows do not select on plain row clicks", async ({ page }) => {
  await page.goto("/transactions")

  const rows = page.locator("[data-transaction-row-id]")
  await expect(rows.first()).toBeVisible()

  await rows.first().click({ position: { x: 120, y: 20 } })
  await expect(page.getByText("1 selected")).toHaveCount(0)

  await rows.first().getByRole("checkbox").check()
  await expect(page.getByText("1 selected")).toBeVisible()
})

test("selected transaction bulk actions float over the viewport", async ({ page }) => {
  await page.goto("/transactions")

  await page.locator("[data-transaction-row-id]").first().getByRole("checkbox").check()

  const bulkBar = page.getByText("1 selected").locator("xpath=ancestor::*[@data-slot='card'][1]")
  await expect(bulkBar).toBeVisible()
  await expect(bulkBar.getByLabel("Add subcategory")).toBeVisible()

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

test("theme toggle persists dim mode in local storage", async ({ page }) => {
  await page.goto("/")

  await expect.poll(() => currentThemeColor(page)).toBe("#fafaf6")
  await page.getByRole("button", { name: "Switch to dim mode" }).click()
  await expect(page.locator("html")).toHaveClass(/dark/)
  await expect.poll(() => page.evaluate(() => window.localStorage.getItem("transactions-theme"))).toBe("dim")
  await expect.poll(() => currentThemeColor(page)).toBe("#3b3429")

  await page.reload()
  await expect(page.locator("html")).toHaveClass(/dark/)
  await expect(page.getByRole("button", { name: "Switch to light mode" })).toBeVisible()
  await expect.poll(() => currentThemeColor(page)).toBe("#3b3429")
})

test("settings custom accent updates the app theme", async ({ page }) => {
  await page.goto("/settings")

  await page.getByLabel("Accent hex color").fill("#2563eb")
  await page.getByLabel("Accent hex color").blur()

  await expect.poll(() => page.evaluate(() => window.localStorage.getItem("transactions-accent-color"))).toBe("#2563eb")
  await expect.poll(() => page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--primary").trim())).toBe("#2563eb")
  await expect(page.getByText("#2563eb")).toBeVisible()
})

test("secondary pages render without blank or broken Inertia content", async ({ page }) => {
  for (const path of ["/imports", "/insights", "/admin/models"]) {
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

async function expectAllElementsFitTheirBoxes(page, selector) {
  const overflowingElements = await page.locator(selector).evaluateAll((elements) => {
    return elements
      .map((element) => {
        const rect = element.getBoundingClientRect()
        return {
          clientWidth: element.clientWidth,
          scrollWidth: element.scrollWidth,
          rectWidth: rect.width,
          text: element.textContent?.trim().replace(/\s+/g, " ").slice(0, 120),
        }
      })
      .filter((element) => element.scrollWidth > element.clientWidth + 1)
  })

  expect(overflowingElements).toEqual([])
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
        const description = cells[2].querySelector("p")

        return {
          descriptionClientWidth: description?.clientWidth || 0,
          descriptionScrollWidth: description?.scrollWidth || 0,
          descriptionRight: cells[2].getBoundingClientRect().right,
          categoryLeft: cells[3].getBoundingClientRect().left,
          text: description?.textContent?.trim().slice(0, 100),
        }
      })
      .filter((row) => row.descriptionScrollWidth > row.descriptionClientWidth + 1 || row.descriptionRight > row.categoryLeft + 1)
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
