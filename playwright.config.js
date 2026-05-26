import { defineConfig, devices } from "@playwright/test"

const port = process.env.PORT || 3100
const baseURL = process.env.PLAYWRIGHT_BASE_URL || `http://127.0.0.1:${port}`

export default defineConfig({
  testDir: "test/e2e",
  timeout: 30_000,
  expect: {
    timeout: 5_000,
  },
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  webServer: process.env.PLAYWRIGHT_BASE_URL
    ? undefined
    : {
        command: [
          "RAILS_ENV=test bin/vite clobber",
          "RAILS_ENV=test bin/vite build",
          "RAILS_ENV=test bin/rails db:prepare",
          "RAILS_ENV=test bin/rails db:fixtures:load",
          `RAILS_ENV=test bin/rails server -p ${port}`,
        ].join(" && "),
        url: baseURL,
        reuseExistingServer: !process.env.CI,
        timeout: 120_000,
      },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
})
