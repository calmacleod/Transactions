const DB_NAME = "transactions-offline"
const DB_VERSION = 1
const STORE_NAME = "snapshots"
const LATEST_KEY = "latest"

export async function refreshOfflineSnapshot(path = "/offline/snapshot.json") {
  const response = await fetch(path, {
    credentials: "same-origin",
    headers: { Accept: "application/json" },
  })

  if (!response.ok) return null

  const snapshot = await response.json()
  await saveOfflineSnapshot(snapshot)
  window.dispatchEvent(new CustomEvent("transactions-offline-snapshot", { detail: snapshot }))

  return snapshot
}

export async function loadOfflineSnapshot() {
  const database = await openOfflineDatabase()

  return new Promise((resolve, reject) => {
    const request = database.transaction(STORE_NAME, "readonly").objectStore(STORE_NAME).get(LATEST_KEY)

    request.onsuccess = () => resolve(request.result?.snapshot || null)
    request.onerror = () => reject(request.error)
  })
}

export async function saveOfflineSnapshot(snapshot) {
  const database = await openOfflineDatabase()

  return new Promise((resolve, reject) => {
    const transaction = database.transaction(STORE_NAME, "readwrite")
    const request = transaction.objectStore(STORE_NAME).put({ id: LATEST_KEY, snapshot })

    request.onerror = () => reject(request.error)
    transaction.oncomplete = () => resolve(snapshot)
    transaction.onerror = () => reject(transaction.error)
  })
}

function openOfflineDatabase() {
  if (!("indexedDB" in window)) return Promise.reject(new Error("IndexedDB is unavailable"))

  return new Promise((resolve, reject) => {
    const request = window.indexedDB.open(DB_NAME, DB_VERSION)

    request.onupgradeneeded = () => {
      const database = request.result
      if (!database.objectStoreNames.contains(STORE_NAME)) {
        database.createObjectStore(STORE_NAME, { keyPath: "id" })
      }
    }

    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}
