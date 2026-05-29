export const themeStorageKey = "transactions-theme"
export const accentStorageKey = "transactions-accent-color"
export const defaultAccentColor = "#0f766e"

export const themeColors = {
  light: "#fafaf6",
  dim: "#3b3429",
}

export const accentPresets = [
  { name: "Ledger", value: "#0f766e" },
  { name: "Mint", value: "#059669" },
  { name: "Ocean", value: "#2563eb" },
  { name: "Violet", value: "#7c3aed" },
  { name: "Rose", value: "#be185d" },
  { name: "Copper", value: "#c2410c" },
]

export function normalizedTheme(value) {
  return value === "dim" || value === "dark" ? "dim" : "light"
}

export function storedTheme() {
  if (typeof window === "undefined") return "light"

  const savedTheme = window.localStorage.getItem(themeStorageKey)
  if (savedTheme) return normalizedTheme(savedTheme)

  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dim" : "light"
}

export function normalizeAccentColor(value) {
  if (typeof value !== "string") return defaultAccentColor

  const trimmed = value.trim()
  if (/^#[0-9a-f]{6}$/i.test(trimmed)) return trimmed.toLowerCase()
  if (/^#[0-9a-f]{3}$/i.test(trimmed)) {
    return `#${trimmed[1]}${trimmed[1]}${trimmed[2]}${trimmed[2]}${trimmed[3]}${trimmed[3]}`.toLowerCase()
  }

  return defaultAccentColor
}

export function storedAccentColor() {
  if (typeof window === "undefined") return defaultAccentColor

  return normalizeAccentColor(window.localStorage.getItem(accentStorageKey) || defaultAccentColor)
}

export function accentForegroundColor(hexColor) {
  const normalized = normalizeAccentColor(hexColor).slice(1)
  const red = parseInt(normalized.slice(0, 2), 16) / 255
  const green = parseInt(normalized.slice(2, 4), 16) / 255
  const blue = parseInt(normalized.slice(4, 6), 16) / 255
  const luminance = [red, green, blue]
    .map((channel) => (channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4))
    .reduce((sum, channel, index) => sum + channel * [0.2126, 0.7152, 0.0722][index], 0)

  return luminance > 0.42 ? "#11140f" : "#fffaf0"
}

export function applyAccentColor(value = storedAccentColor()) {
  if (typeof document === "undefined") return defaultAccentColor

  const color = normalizeAccentColor(value)
  const root = document.documentElement
  const isDim = root.classList.contains("dark")

  root.style.setProperty("--user-accent", color)
  root.style.setProperty("--primary", color)
  root.style.setProperty("--primary-foreground", accentForegroundColor(color))
  root.style.setProperty("--ring", `color-mix(in oklch, ${color} 72%, var(--foreground))`)
  root.style.setProperty("--accent", `color-mix(in oklch, ${color} ${isDim ? "30%" : "16%"}, var(--background))`)
  root.style.setProperty("--accent-foreground", `color-mix(in oklch, ${color} ${isDim ? "38%" : "70%"}, var(--foreground))`)

  return color
}

export function saveAccentColor(value) {
  const color = applyAccentColor(value)
  window.localStorage.setItem(accentStorageKey, color)
  window.dispatchEvent(new CustomEvent("transactions-theme-change", { detail: { accentColor: color } }))

  return color
}

export function resetAccentColor() {
  window.localStorage.removeItem(accentStorageKey)
  return saveAccentColor(defaultAccentColor)
}

export function applyTheme(value = storedTheme()) {
  const theme = normalizedTheme(value)

  document.documentElement.classList.toggle("dark", theme === "dim")
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", themeColors[theme])
  document.querySelector('meta[name="msapplication-TileColor"]')?.setAttribute("content", themeColors[theme])
  window.localStorage.setItem(themeStorageKey, theme)
  applyAccentColor(storedAccentColor())
  window.dispatchEvent(new CustomEvent("transactions-theme-change", { detail: { theme } }))

  return theme
}
