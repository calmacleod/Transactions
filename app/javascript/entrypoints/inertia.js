import { createInertiaApp, router } from '@inertiajs/svelte'
import { warmOfflineSnapshot } from '../lib/offline-snapshot'
import Layout from '../layouts/AppLayout.svelte'
import './application.css'

const warmRouteChunks = [
  () => import("../pages/transactions/index.svelte"),
  () => import("../pages/spending/index.svelte"),
  () => import("../pages/budgets/index.svelte"),
  () => import("../pages/dashboard/index.svelte"),
  () => import("../pages/offline/show.svelte"),
]
const OFFLINE_PAGE_REFRESH_INTERVAL_MS = 60 * 60 * 1000
const OFFLINE_PAGE_FETCHED_AT_KEY = "transactions-offline-page-fetched-at"
let serviceWorkerRegistrationPromise = null

createInertiaApp({
  pages: "../pages",
  layout: (name) => {
    return name.startsWith("sessions/") || name.startsWith("passwords/") || name.startsWith("registrations/") ? undefined : Layout
  },

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => {
      return { queryStringArrayFormat: "brackets" }
    },
    future: {
      useScriptElementForInitialPage: true,
      useDataInertiaHeadAttribute: true,
      useDialogForErrorModal: true,
      preserveEqualProps: true,
    },
  },
})

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    ensureServiceWorkerRegistration().catch(() => {})
  })
}

window.addEventListener("load", () => {
  scheduleIdleWork(() => {
    warmRouteChunks.forEach((loadChunk) => loadChunk().catch(() => {}))
    warmOfflineSupport(authenticatedPage())
  })
})

router.on("navigate", (event) => {
  scheduleIdleWork(() => warmOfflineSupport(authenticatedProps(event.detail.page.props)))
})

router.on("httpException", (event) => {
  if (!shouldHandleOfflineInertiaFailure()) return

  event.preventDefault()
  if (window.location.pathname !== "/offline") redirectToOfflinePage()
  return false
})

router.on("networkError", (event) => {
  if (!shouldHandleOfflineInertiaFailure()) return

  event.preventDefault()
  if (window.location.pathname !== "/offline") redirectToOfflinePage()
  return false
})

window.addEventListener("offline", redirectToOfflinePage)
window.addEventListener("load", () => {
  if (!navigator.onLine) redirectToOfflinePage()
})

function scheduleIdleWork(callback) {
  if ("requestIdleCallback" in window) {
    window.requestIdleCallback(callback, { timeout: 2500 })
  } else {
    window.setTimeout(callback, 1000)
  }
}

async function warmOfflineSupport(authenticated) {
  try {
    if ("serviceWorker" in navigator) {
      await ensureServiceWorkerRegistration()
    }

    if (!authenticated) return

    warmOfflineSnapshot()
    warmOfflinePage()
  } catch (_error) {
    // Offline support is opportunistic; failed warmups should not interrupt normal app loads.
  }
}

function warmOfflinePage() {
  if (!shouldRefreshOfflinePage()) return

  recordOfflinePageFetchAttempt()
  fetch("/offline", { credentials: "same-origin", headers: { Accept: "text/html" } }).catch(() => {})
}

function shouldRefreshOfflinePage() {
  const fetchedAt = Date.parse(readStorageValue(OFFLINE_PAGE_FETCHED_AT_KEY))
  if (!Number.isFinite(fetchedAt)) return true

  return Date.now() - fetchedAt >= OFFLINE_PAGE_REFRESH_INTERVAL_MS
}

function recordOfflinePageFetchAttempt() {
  writeStorageValue(OFFLINE_PAGE_FETCHED_AT_KEY, new Date().toISOString())
}

async function ensureServiceWorkerRegistration() {
  serviceWorkerRegistrationPromise ||= navigator.serviceWorker.register("/service-worker.js").then(() => navigator.serviceWorker.ready)

  return serviceWorkerRegistrationPromise
}

function redirectToOfflinePage() {
  if (window.location.pathname === "/offline") return
  if (window.location.pathname.startsWith("/session")) return
  if (window.location.pathname.startsWith("/passwords")) return
  if (window.location.pathname.startsWith("/registrations")) return

  window.location.assign("/offline")
}

function shouldHandleOfflineInertiaFailure() {
  return !navigator.onLine || window.location.pathname === "/offline"
}

function authenticatedPage() {
  const pageScript = document.querySelector('script[data-page="app"]')
  if (!pageScript?.textContent) return false

  try {
    return authenticatedProps(JSON.parse(pageScript.textContent).props)
  } catch (_error) {
    return false
  }
}

function authenticatedProps(props) {
  return Boolean(props?.auth?.authenticated)
}

function readStorageValue(key) {
  try {
    return window.localStorage.getItem(key)
  } catch (_error) {
    return null
  }
}

function writeStorageValue(key, value) {
  try {
    window.localStorage.setItem(key, value)
  } catch (_error) {
    // Offline warmup metadata is best-effort; missing storage should not affect navigation.
  }
}
