export async function connectionAvailable() {
  if (typeof navigator === "undefined") return true
  if (!navigator.onLine) return false

  try {
    const response = await fetch("/up", {
      method: "HEAD",
      cache: "no-store",
      credentials: "same-origin",
    })

    return response.ok
  } catch (_error) {
    return false
  }
}
