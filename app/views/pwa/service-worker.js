const CACHE_NAME = "transactions-pwa-v6"
const PAGE_CACHE_NAME = "transactions-pages-v2"
const VITE_PATH_PATTERN = /^\/vite(?:-[^/]+)?\//
const OFFLINE_FALLBACK_PATH = "/offline"
const CACHEABLE_PAGE_PATHS = new Set([
  "/",
  "/transactions",
  "/spending",
  "/budgets",
  "/subcategories",
  "/insights",
  OFFLINE_FALLBACK_PATH,
])

self.addEventListener("install", (event) => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    Promise.all([
      caches.keys().then((keys) => {
        return Promise.all(keys.filter((key) => ![CACHE_NAME, PAGE_CACHE_NAME].includes(key)).map((key) => caches.delete(key)))
      }),
      self.registration.navigationPreload?.enable(),
    ]).then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  const request = event.request

  if (request.method !== "GET") return

  const url = new URL(request.url)
  const sameOrigin = url.origin === self.location.origin
  const viteAsset = isCacheableViteAsset(url, sameOrigin)
  if (!sameOrigin && !viteAsset) return

  if (sameOrigin && request.mode === "navigate") {
    event.respondWith(networkFirstNavigation(request, event.preloadResponse))
    return
  }

  if (sameOrigin && acceptsHtml(request) && isCacheablePagePath(url.pathname)) {
    event.respondWith(networkFirstPage(request))
    return
  }

  if (viteAsset) {
    event.respondWith(cacheFirst(request))
  }
})

async function networkFirstNavigation(request, preloadResponsePromise) {
  try {
    const preloadResponse = await preloadResponsePromise
    const response = preloadResponse || await fetch(request)
    cachePageResponse(request, response)

    return response
  } catch (_error) {
    return await caches.match(request) ||
      await caches.match(OFFLINE_FALLBACK_PATH) ||
      offlineFallbackResponse()
  }
}

async function networkFirstPage(request) {
  try {
    const response = await fetch(request)
    cachePageResponse(request, response)

    return response
  } catch (_error) {
    return await caches.match(request) ||
      await caches.match(OFFLINE_FALLBACK_PATH) ||
      offlineFallbackResponse()
  }
}

function cachePageResponse(request, response) {
  if (!response?.ok || !acceptsHtml(request)) return

  const url = new URL(request.url)
  if (!isCacheablePagePath(url.pathname)) return

  const responseCopy = response.clone()
  caches.open(PAGE_CACHE_NAME).then((cache) => cache.put(request, responseCopy))
}

function cacheFirst(request) {
  return caches.match(request).then((cachedResponse) => {
    if (cachedResponse) return cachedResponse

    return fetch(request).then((response) => {
      if (!response.ok) return response

      const responseCopy = response.clone()
      caches.open(CACHE_NAME).then((cache) => cache.put(request, responseCopy))

      return response
    })
  })
}

function acceptsHtml(request) {
  return request.headers.get("accept")?.includes("text/html")
}

function isCacheableViteAsset(url, sameOrigin) {
  if (!VITE_PATH_PATTERN.test(url.pathname)) return false
  if (sameOrigin) return true

  return isLocalDevelopmentHost(url.hostname)
}

function isLocalDevelopmentHost(hostname) {
  return ["localhost", "127.0.0.1", "::1"].includes(hostname)
}

function isCacheablePagePath(pathname) {
  return CACHEABLE_PAGE_PATHS.has(pathname)
}

function offlineFallbackResponse() {
  return new Response("Transactions is offline and no offline copy is available yet.", {
    status: 503,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  })
}
