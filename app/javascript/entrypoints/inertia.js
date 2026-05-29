import { createInertiaApp, router } from '@inertiajs/svelte'
import { refreshOfflineSnapshot } from '../lib/offline-snapshot'
import Layout from '../layouts/AppLayout.svelte'
import './application.css'

const warmRouteChunks = [
  () => import("../pages/transactions/index.svelte"),
  () => import("../pages/spending/index.svelte"),
  () => import("../pages/budgets/index.svelte"),
  () => import("../pages/dashboard/index.svelte"),
  () => import("../pages/offline/show.svelte"),
]
let serviceWorkerRegistrationPromise = null

createInertiaApp({
  pages: "../pages",
  layout: (name) => {
    return name.startsWith("sessions/") || name.startsWith("passwords/") ? undefined : Layout
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

    await fetch("/offline", { credentials: "same-origin", headers: { Accept: "text/html" } })
    await refreshOfflineSnapshot()
  } catch (_error) {
    // Offline support is opportunistic; failed warmups should not interrupt normal app loads.
  }
}

async function ensureServiceWorkerRegistration() {
  serviceWorkerRegistrationPromise ||= navigator.serviceWorker.register("/service-worker.js").then(() => navigator.serviceWorker.ready)

  return serviceWorkerRegistrationPromise
}

function redirectToOfflinePage() {
  router.cancelAll({ async: true, prefetch: true, sync: true })

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
