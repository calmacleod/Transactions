import { createInertiaApp } from '@inertiajs/svelte'
import './application.css'

createInertiaApp({
  pages: "../pages",

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
