import { createInertiaApp } from '@inertiajs/svelte'
import Layout from '../layouts/AppLayout.svelte'
import './application.css'

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
  },
})

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch(() => {})
  })
}
