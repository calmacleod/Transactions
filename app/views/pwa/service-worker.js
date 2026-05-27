const CACHE_NAME = "transactions-pwa-v4"
const ASSET_PATH_PATTERN = /^\/vite(?:-[^/]+)?\/assets\//

self.addEventListener("install", (event) => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    Promise.all([
      caches.keys().then((keys) => {
        return Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
      }),
      self.registration.navigationPreload?.enable(),
    ]).then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  const request = event.request

  if (request.method !== "GET") return

  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  if (request.mode === "navigate") {
    event.respondWith(
      Promise.resolve(event.preloadResponse).then((preloadResponse) => {
        return preloadResponse || fetch(request)
      })
    )
    return
  }

  if (ASSET_PATH_PATTERN.test(url.pathname)) {
    event.respondWith(cacheFirst(request))
  }
})

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
