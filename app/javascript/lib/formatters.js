export function buildQuery(params = {}) {
  const query = new URLSearchParams()

  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null || value === "") return
    query.set(key, value)
  })

  return query.toString()
}

export function withQuery(path, params = {}) {
  const query = buildQuery(params)
  return query ? `${path}?${query}` : path
}

export function moneyFromCents(cents = 0) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(Number(cents || 0) / 100)
}

export function badgeVariant(severity) {
  if (severity === "warning") return "warning"
  if (severity === "error" || severity === "failed") return "destructive"
  if (severity === "success" || severity === "complete") return "success"
  return "secondary"
}
