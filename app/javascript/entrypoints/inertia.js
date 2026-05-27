import { createInertiaApp } from '@inertiajs/svelte'
import Layout from '../layouts/AppLayout.svelte'
import './application.css'

const warmRouteChunks = [
  () => import("../pages/transactions/index.svelte"),
  () => import("../pages/spending/index.svelte"),
  () => import("../pages/budgets/index.svelte"),
  () => import("../pages/dashboard/index.svelte"),
]

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
    navigator.serviceWorker.register("/service-worker.js").catch(() => {})
  })
}

window.addEventListener("load", () => {
  scheduleIdleWork(() => {
    warmRouteChunks.forEach((loadChunk) => loadChunk().catch(() => {}))
  })
})

function scheduleIdleWork(callback) {
  if ("requestIdleCallback" in window) {
    window.requestIdleCallback(callback, { timeout: 2500 })
  } else {
    window.setTimeout(callback, 1000)
  }
}
