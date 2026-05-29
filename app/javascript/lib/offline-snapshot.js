const DB_NAME = "transactions-offline"
const DB_VERSION = 1
const STORE_NAME = "snapshots"
const LATEST_KEY = "latest"
const REFRESH_INTERVAL_MS = 60 * 60 * 1000
const FETCHED_AT_KEY = "transactions-offline-snapshot-fetched-at"
const REFRESHED_AT_KEY = "transactions-offline-snapshot-refreshed-at"
let refreshPromise = null

export function warmOfflineSnapshot(path = "/offline/snapshot.json") {
  refreshOfflineSnapshot(path).catch(() => {})
}

export async function refreshOfflineSnapshot(path = "/offline/snapshot.json", { force = false } = {}) {
  if (refreshPromise) return refreshPromise

  const storedSnapshot = await loadOfflineSnapshot()
  if (!force && storedSnapshot && !shouldRefreshOfflineSnapshot()) return storedSnapshot

  refreshPromise = fetchAndStoreOfflineSnapshot(path).finally(() => {
    refreshPromise = null
  })

  return refreshPromise
}

async function fetchAndStoreOfflineSnapshot(path) {
  recordOfflineSnapshotFetchAttempt()

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
  const record = await loadOfflineSnapshotRecord()

  return record?.snapshot || null
}

function shouldRefreshOfflineSnapshot() {
  const refreshedAt = Date.parse(readStorageValue(REFRESHED_AT_KEY))
  if (!Number.isFinite(refreshedAt)) return true

  return Date.now() - refreshedAt >= REFRESH_INTERVAL_MS
}

async function loadOfflineSnapshotRecord() {
  const database = await openOfflineDatabase()

  return new Promise((resolve, reject) => {
    const request = database.transaction(STORE_NAME, "readonly").objectStore(STORE_NAME).get(LATEST_KEY)

    request.onsuccess = () => resolve(request.result || null)
    request.onerror = () => reject(request.error)
  })
}

export async function saveOfflineSnapshot(snapshot) {
  const database = await openOfflineDatabase()
  const timestamp = new Date().toISOString()
  writeStorageValue(FETCHED_AT_KEY, timestamp)

  return new Promise((resolve, reject) => {
    const transaction = database.transaction(STORE_NAME, "readwrite")
    const request = transaction.objectStore(STORE_NAME).put({ id: LATEST_KEY, snapshot, fetchedAt: timestamp, refreshedAt: timestamp })

    request.onerror = () => reject(request.error)
    transaction.oncomplete = () => {
      writeStorageValue(REFRESHED_AT_KEY, timestamp)
      resolve(snapshot)
    }
    transaction.onerror = () => reject(transaction.error)
  })
}

function recordOfflineSnapshotFetchAttempt() {
  writeStorageValue(FETCHED_AT_KEY, new Date().toISOString())
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
    // Snapshot refresh metadata is best-effort; IndexedDB remains the source of truth for snapshot data.
  }
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
