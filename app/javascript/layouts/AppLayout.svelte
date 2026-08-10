<script>
  import { onMount } from "svelte"
  import { Link, router, usePage } from "@inertiajs/svelte"
  import { Button } from "$lib/components/ui/button"
  import { Separator } from "$lib/components/ui/separator"
  import { Sheet, SheetContent, SheetHeader, SheetTitle } from "$lib/components/ui/sheet"
  import { applyAccentColor, applyTheme, storedAccentColor, storedTheme } from "$lib/theme"
  import BarChart3 from "@lucide/svelte/icons/bar-chart-3"
  import CreditCard from "@lucide/svelte/icons/credit-card"
  import History from "@lucide/svelte/icons/history"
  import LayoutDashboard from "@lucide/svelte/icons/layout-dashboard"
  import Lightbulb from "@lucide/svelte/icons/lightbulb"
  import LogOut from "@lucide/svelte/icons/log-out"
  import Menu from "@lucide/svelte/icons/menu"
  import Moon from "@lucide/svelte/icons/moon"
  import PiggyBank from "@lucide/svelte/icons/piggy-bank"
  import PanelLeftClose from "@lucide/svelte/icons/panel-left-close"
  import PanelLeftOpen from "@lucide/svelte/icons/panel-left-open"
  import Settings from "@lucide/svelte/icons/settings"
  import Shield from "@lucide/svelte/icons/shield"
  import Sparkles from "@lucide/svelte/icons/sparkles"
  import Tags from "@lucide/svelte/icons/tags"
  import TrendingUp from "@lucide/svelte/icons/trending-up"
  import Sun from "@lucide/svelte/icons/sun"

  const navLinkClass = "group flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors"
  const navPrefetch = "hover"
  const flashDismissDelay = 4_000
  const sidebarPreviewDelay = 450
  const page = usePage()

  let auth = page.props.auth || {}
  let paths = page.props.paths || {}
  let flash = page.props.flash || {}
  let visibleFlash = { ...flash }
  let currentPath = page.url || "/"
  let navItems = navItemsFor(paths)
  let flashDismissTimer
  let sidebarPreviewTimer

  let mobileOpen = false
  let sidebarCollapsed = false
  let sidebarPreviewOpen = false
  let sidebarPreviewSuppressed = false
  let onboardingStep = 0
  let onboardingDismissedLocally = false
  let theme = "light"
  let accentColor = "#0f766e"
  let online = typeof navigator === "undefined" ? true : navigator.onLine

  $: sidebarExpanded = !sidebarCollapsed || sidebarPreviewOpen
  $: offlineModePath = paths.offline || "/offline"
  $: offlineMode = currentPath === offlineModePath || currentPath.startsWith(`${offlineModePath}?`)
  $: navigationLocked = offlineMode || !online
  $: onboardingSteps = onboardingStepsFor(paths)
  $: currentOnboardingStep = onboardingSteps[Math.min(onboardingStep, onboardingSteps.length - 1)]
  $: showOnboarding = auth.authenticated && auth.onboarding_required && !onboardingDismissedLocally

  onMount(() => {
    syncPageState(page)
    const stopTrackingNavigation = router.on("navigate", (event) => syncPageState(event.detail.page))
    setTheme(storedTheme())
    accentColor = applyAccentColor(storedAccentColor())
    sidebarCollapsed = window.localStorage.getItem("transactions-sidebar-collapsed") === "true"
    window.addEventListener("mousemove", clearSidebarSuppressionAfterPointerLeaves)
    window.addEventListener("transactions-theme-change", syncThemeState)
    window.addEventListener("online", syncOnlineState)
    window.addEventListener("offline", syncOnlineState)

    return () => {
      stopTrackingNavigation()
      clearFlashTimer()
      clearSidebarPreviewTimer()
      window.removeEventListener("mousemove", clearSidebarSuppressionAfterPointerLeaves)
      window.removeEventListener("transactions-theme-change", syncThemeState)
      window.removeEventListener("online", syncOnlineState)
      window.removeEventListener("offline", syncOnlineState)
    }
  })

  function syncPageState(nextPage) {
    auth = nextPage.props.auth || {}
    paths = nextPage.props.paths || {}
    onboardingDismissedLocally = onboardingLocallyDismissed(auth)
    if (!auth.onboarding_required) onboardingStep = 0
    flash = nextPage.props.flash || {}
    visibleFlash = { ...flash }
    scheduleFlashDismiss()
    currentPath = nextPage.url || window.location.pathname + window.location.search || "/"
    navItems = navItemsFor(paths)
  }

  function scheduleFlashDismiss() {
    clearFlashTimer()
    if (!visibleFlash.notice && !visibleFlash.alert) return

    flashDismissTimer = window.setTimeout(() => {
      visibleFlash = {}
      flashDismissTimer = null
    }, flashDismissDelay)
  }

  function clearFlashTimer() {
    if (!flashDismissTimer) return

    window.clearTimeout(flashDismissTimer)
    flashDismissTimer = null
  }

  function navItemsFor(nextPaths) {
    const items = [
      { label: "Dashboard", href: nextPaths.root || "/", icon: LayoutDashboard },
      { label: "Transactions", href: nextPaths.transactions || "/transactions", icon: CreditCard },
      { label: "Imports", href: nextPaths.imports || "/imports", icon: History },
      { label: "Spending", href: nextPaths.spending || "/spending", icon: TrendingUp },
      { label: "Budgets", href: nextPaths.budgets || "/budgets", icon: PiggyBank },
      { label: "Subcategories", href: nextPaths.subcategories || "/subcategories", icon: Tags },
      { label: "Insights", href: nextPaths.insights || "/insights", icon: Lightbulb },
      { label: "AI settings", href: nextPaths.ai_preferences || "/ai_preferences", icon: Sparkles },
      { label: "Settings", href: nextPaths.settings || "/settings", icon: Settings },
    ]

    if (auth.admin) {
      items.push({ label: "Admin", href: nextPaths.admin || "/admin", icon: Shield })
    }

    return items
  }

  function onboardingStepsFor(nextPaths) {
    return [
      {
        label: "Import",
        title: "Bring in a card CSV",
        description: "Open Imports, upload a headerless CSV, then review the parsed rows before committing them as transactions.",
        action: "Open imports",
        path: nextPaths.imports || "/imports",
        icon: History,
      },
      {
        label: "Review",
        title: "Clean up the ledger",
        description: "Use Transactions to filter, search, bulk select, edit categories, add subcategories, and keep notes on unusual purchases.",
        action: "Open transactions",
        path: nextPaths.transactions || "/transactions",
        icon: CreditCard,
      },
      {
        label: "Budget",
        title: "Set category guardrails",
        description: "Set monthly targets in Budgets, then jump from any budget line back to the exact transactions behind the spend.",
        action: "Open budgets",
        path: nextPaths.budgets || "/budgets",
        icon: PiggyBank,
      },
      {
        label: "Automate",
        title: "Tune reminders and AI",
        description: "Settings controls CSV reminders. AI settings lets you choose model behavior when provider keys are configured.",
        action: "Open settings",
        path: nextPaths.settings || "/settings",
        icon: Settings,
      },
    ]
  }

  function setTheme(value) {
    theme = applyTheme(value)
  }

  function toggleTheme() {
    setTheme(theme === "dim" ? "light" : "dim")
  }

  function syncThemeState(event) {
    if (event.detail?.theme) theme = event.detail.theme
    if (event.detail?.accentColor) accentColor = event.detail.accentColor
  }

  function toggleSidebarCollapsed() {
    sidebarCollapsed = !sidebarCollapsed
    sidebarPreviewOpen = false
    sidebarPreviewSuppressed = sidebarCollapsed
    clearSidebarPreviewTimer()
    window.localStorage.setItem("transactions-sidebar-collapsed", String(sidebarCollapsed))
  }

  function startSidebarPreview() {
    if (!sidebarCollapsed || sidebarPreviewOpen || sidebarPreviewSuppressed) return

    clearSidebarPreviewTimer()
    sidebarPreviewTimer = window.setTimeout(() => {
      sidebarPreviewOpen = true
      sidebarPreviewTimer = null
    }, sidebarPreviewDelay)
  }

  function closeSidebarPreview() {
    clearSidebarPreviewTimer()
    sidebarPreviewOpen = false
    sidebarPreviewSuppressed = false
  }

  function clearSidebarPreviewTimer() {
    if (!sidebarPreviewTimer) return

    window.clearTimeout(sidebarPreviewTimer)
    sidebarPreviewTimer = null
  }

  function clearSidebarSuppressionAfterPointerLeaves(event) {
    if (!sidebarPreviewSuppressed || event.clientX <= 80) return

    sidebarPreviewSuppressed = false
  }

  function signOut() {
    if (navigationLocked) return

    router.delete(paths.session)
  }

  function isActive(href, path, rootPath = "/") {
    if (href === rootPath || href === "/") return path === "/" || path.startsWith("/?")
    return path === href || path.startsWith(`${href}?`) || path.startsWith(`${href}/`)
  }

  function navPrefetchMode(item) {
    if (navigationLocked) return false
    return item.fullReload ? false : navPrefetch
  }

  function syncOnlineState() {
    online = navigator.onLine
  }

  function navKey(item) {
    return item.label.toLowerCase().replaceAll(" ", "-")
  }

  function lockedNavLabel(item) {
    return `${item.label} unavailable while offline`
  }

  function desktopNavClass(item, expanded, locked = false) {
    const layoutClass = expanded ? "grid w-full grid-cols-[3rem_1fr] text-left" : "grid w-9 justify-self-center grid-cols-[2.25rem]"
    if (locked) return `group h-9 cursor-not-allowed items-center rounded-lg p-0 text-sm font-medium text-muted-foreground/50 opacity-70 ${layoutClass}`

    const stateClass = isActive(item.href, currentPath, paths.root || "/") ? "border border-primary/40 bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:bg-muted hover:text-foreground"

    return `group h-9 items-center rounded-lg p-0 text-sm font-medium transition-colors ${layoutClass} ${stateClass}`
  }

  function mobileNavClass(item, locked = false) {
    if (locked) return `${navLinkClass} cursor-not-allowed text-muted-foreground/50 opacity-70`

    return `${navLinkClass} ${isActive(item.href, currentPath, paths.root || "/") ? "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:bg-muted hover:text-foreground"}`
  }

  function desktopSidebarClass(expanded, collapsed, previewOpen) {
    const overlayClass = collapsed && previewOpen ? "shadow-xl" : "shadow-sm"

    return `fixed inset-y-0 left-0 z-30 hidden border-r border-border/80 bg-card px-2 py-4 ${overlayClass} xl:flex xl:flex-col`
  }

  function mainClass() {
    return "app-main min-w-0 px-4 pb-5 pt-[calc(4.5rem+env(safe-area-inset-top))] sm:px-6 lg:px-8 xl:py-5"
  }

  function mouseDownNavigate(event, href, options = {}) {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    event.preventDefault()
    if (options.closeMobile) mobileOpen = false
    if (navigationLocked) return

    if (!online && href !== paths.offline) {
      router.visit(paths.offline || "/offline")
      return
    }
    router.visit(href)
  }

  function ignoreMouseClickAfterMouseDown(event, options = {}) {
    if (event.detail > 0) {
      event.preventDefault()
      return
    }

    if (options.closeMobile) mobileOpen = false
  }

  function dismissOnboarding(nextPath = null) {
    onboardingDismissedLocally = true
    rememberOnboardingDismissal(auth)
    auth = { ...auth, onboarding_required: false }

    router.patch(paths.onboarding, {}, {
      preserveScroll: true,
      onSuccess: () => {
        if (nextPath) router.visit(nextPath)
      },
    })
  }

  function nextOnboardingStep() {
    onboardingStep = Math.min(onboardingStep + 1, onboardingSteps.length - 1)
  }

  function previousOnboardingStep() {
    onboardingStep = Math.max(onboardingStep - 1, 0)
  }

  function onboardingStorageKey(nextAuth) {
    return `transactions-onboarding-dismissed:${nextAuth?.email || "current"}`
  }

  function onboardingLocallyDismissed(nextAuth) {
    if (typeof window === "undefined") return false

    return window.localStorage.getItem(onboardingStorageKey(nextAuth)) === "true"
  }

  function rememberOnboardingDismissal(nextAuth) {
    if (typeof window === "undefined") return

    window.localStorage.setItem(onboardingStorageKey(nextAuth), "true")
  }
</script>

<div class="min-h-screen bg-background text-foreground" style={`--sidebar-offset: ${sidebarCollapsed ? "4rem" : "14rem"}; --sidebar-width: ${sidebarExpanded ? "14rem" : "4rem"}; --current-accent: ${accentColor};`} data-app-chrome>
  <aside class={desktopSidebarClass(sidebarExpanded, sidebarCollapsed, sidebarPreviewOpen)} style="width: var(--sidebar-width)" data-testid="desktop-sidebar" onmouseenter={startSidebarPreview} onmouseleave={closeSidebarPreview}>
    <div class={sidebarExpanded ? "grid grid-cols-[3rem_1fr_2.25rem] items-center" : "grid grid-cols-[3rem] items-center"}>
      {#if navigationLocked}
      <div class={sidebarExpanded ? "col-span-2 grid h-9 min-w-0 cursor-not-allowed grid-cols-[3rem_1fr] items-center opacity-80" : "grid h-9 w-full cursor-not-allowed grid-cols-[3rem] items-center opacity-80"} aria-label="Transactions dashboard unavailable while offline" title={sidebarExpanded ? undefined : "Transactions"} data-testid="locked-sidebar-brand">
        <span class="grid size-9 place-items-center justify-self-center rounded-lg bg-primary text-primary-foreground shadow-sm" data-brand-mark data-testid="sidebar-brand-icon">
          <BarChart3 class="size-5" />
        </span>
        {#if sidebarExpanded}
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-foreground">Transactions</span>
          <span class="block text-xs text-muted-foreground">Expense control</span>
        </span>
        {/if}
      </div>
      {:else}
      <Link href={paths.root || "/"} prefetch cacheFor="30s" draggable="false" class={sidebarExpanded ? "col-span-2 grid h-9 min-w-0 grid-cols-[3rem_1fr] items-center" : "grid h-9 w-full grid-cols-[3rem] items-center"} aria-label="Transactions dashboard" title={sidebarExpanded ? undefined : "Transactions"} onmousedown={(event) => mouseDownNavigate(event, paths.root || "/")} onclick={ignoreMouseClickAfterMouseDown}>
        <span class="grid size-9 place-items-center justify-self-center rounded-lg bg-primary text-primary-foreground shadow-sm" data-brand-mark data-testid="sidebar-brand-icon">
          <BarChart3 class="size-5" />
        </span>
        {#if sidebarExpanded}
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-foreground">Transactions</span>
          <span class="block text-xs text-muted-foreground">Expense control</span>
        </span>
        {/if}
      </Link>
      {/if}
      {#if sidebarExpanded}
        <Button variant="ghost" size="icon" class="shrink-0 text-muted-foreground" aria-label={sidebarCollapsed ? "Pin expanded sidebar" : "Collapse sidebar"} title={sidebarCollapsed ? "Pin expanded sidebar" : "Collapse sidebar"} onclick={toggleSidebarCollapsed}>
          {#if sidebarCollapsed}
            <PanelLeftOpen class="size-4" />
          {:else}
            <PanelLeftClose class="size-4" />
          {/if}
        </Button>
      {/if}
    </div>

    <Separator class="my-4" />

    {#if auth.authenticated}
      {#if navigationLocked && sidebarExpanded}
        <div class="mb-3 rounded-lg border border-border bg-muted/40 px-3 py-2 text-xs text-muted-foreground" data-testid="offline-sidebar-lock">
          Sidebar navigation is locked while offline.
        </div>
      {/if}
      <nav class="grid gap-1">
        {#each navItems as item}
          {#if navigationLocked}
            <button type="button" disabled class={desktopNavClass(item, sidebarExpanded, true)} aria-label={lockedNavLabel(item)} title={sidebarExpanded ? undefined : item.label} data-testid={`locked-nav-${navKey(item)}`}>
              <span class="grid size-9 place-items-center justify-self-center" data-testid={`sidebar-icon-${navKey(item)}`}>
                <svelte:component this={item.icon} class="size-4" />
              </span>
              {#if sidebarExpanded}<span>{item.label}</span>{/if}
            </button>
          {:else if item.fullReload}
            <a href={item.href} data-turbo="false" target={item.newTab ? "_blank" : undefined} rel={item.newTab ? "noreferrer" : undefined} draggable="false" class={desktopNavClass(item, sidebarExpanded)} data-active-nav={isActive(item.href, currentPath, paths.root || "/")} aria-label={item.label} title={sidebarExpanded ? undefined : item.label}>
              <span class="grid size-9 place-items-center justify-self-center" data-testid={`sidebar-icon-${navKey(item)}`}>
                <svelte:component this={item.icon} class="size-4" />
              </span>
              {#if sidebarExpanded}<span>{item.label}</span>{/if}
            </a>
          {:else}
            <Link
              href={item.href}
              prefetch={navPrefetchMode(item)}
              cacheFor="1m"
              draggable="false"
              onmousedown={(event) => mouseDownNavigate(event, item.href)}
              onclick={ignoreMouseClickAfterMouseDown}
              class={desktopNavClass(item, sidebarExpanded)}
              data-active-nav={isActive(item.href, currentPath, paths.root || "/")}
              aria-label={item.label}
              title={sidebarExpanded ? undefined : item.label}
            >
              <span class="grid size-9 place-items-center justify-self-center" data-testid={`sidebar-icon-${navKey(item)}`}>
                <svelte:component this={item.icon} class="size-4" />
              </span>
              {#if sidebarExpanded}<span>{item.label}</span>{/if}
            </Link>
          {/if}
        {/each}
      </nav>
    {/if}

    {#if auth.authenticated}
      <div class="mt-auto">
        <Separator class="my-4" />
        {#if !sidebarExpanded}
          <Button variant="ghost" size="icon" class="mb-1 w-full text-muted-foreground" onclick={toggleSidebarCollapsed} aria-label="Expand sidebar" title="Expand sidebar">
            <PanelLeftOpen class="size-4" />
          </Button>
        {/if}
        <Button variant="ghost" class={sidebarExpanded ? "mb-1 w-full justify-start text-muted-foreground" : "mb-1 w-full justify-center px-2 text-muted-foreground"} onclick={toggleTheme} aria-label={`Switch to ${theme === "dim" ? "light" : "dim"} mode`} title={sidebarExpanded ? undefined : `Switch to ${theme === "dim" ? "light" : "dim"} mode`}>
          {#if theme === "dim"}
            <Sun class="size-4" />
            {#if sidebarExpanded}Light mode{/if}
          {:else}
            <Moon class="size-4" />
            {#if sidebarExpanded}Dim mode{/if}
          {/if}
        </Button>
        <Button variant="ghost" class={sidebarExpanded ? "w-full justify-start text-muted-foreground" : "w-full justify-center px-2 text-muted-foreground"} onclick={signOut} disabled={navigationLocked} aria-label="Sign out" title={sidebarExpanded ? undefined : "Sign out"}>
          <LogOut class="size-4" />
          {#if sidebarExpanded}Sign out{/if}
        </Button>
      </div>
    {/if}
  </aside>

  <header class="fixed inset-x-0 top-0 z-40 flex h-[calc(3.5rem+env(safe-area-inset-top))] items-center gap-3 border-b border-border/80 bg-background px-4 pt-[env(safe-area-inset-top)] shadow-sm xl:hidden">
    <Button variant="outline" size="icon" aria-label="Open navigation" onclick={() => (mobileOpen = true)}>
      <Menu class="size-4" />
    </Button>
    {#if navigationLocked}
    <div class="flex cursor-not-allowed items-center gap-3 opacity-80" aria-label="Transactions dashboard unavailable while offline" data-testid="locked-mobile-brand">
      <span class="grid size-9 place-items-center rounded-lg bg-primary text-primary-foreground shadow-sm" data-brand-mark>
        <BarChart3 class="size-5" />
      </span>
      <span class="min-w-0">
        <span class="block text-sm font-semibold text-foreground">Transactions</span>
        <span class="block text-xs text-muted-foreground">Expense control</span>
      </span>
    </div>
    {:else}
    <Link href={paths.root || "/"} prefetch cacheFor="30s" draggable="false" class="flex items-center gap-3" onmousedown={(event) => mouseDownNavigate(event, paths.root || "/")} onclick={ignoreMouseClickAfterMouseDown}>
      <span class="grid size-9 place-items-center rounded-lg bg-primary text-primary-foreground shadow-sm" data-brand-mark>
        <BarChart3 class="size-5" />
      </span>
      <span class="min-w-0">
        <span class="block text-sm font-semibold text-foreground">Transactions</span>
        <span class="block text-xs text-muted-foreground">Expense control</span>
      </span>
    </Link>
    {/if}
    <Button variant="outline" size="icon" class="ml-auto" aria-label={`Switch to ${theme === "dim" ? "light" : "dim"} mode`} onclick={toggleTheme}>
      {#if theme === "dim"}
        <Sun class="size-4" />
      {:else}
        <Moon class="size-4" />
      {/if}
    </Button>
  </header>

  <Sheet bind:open={mobileOpen}>
    <SheetContent side="left" class="w-80 p-4">
      <SheetHeader class="sr-only">
        <SheetTitle>Navigation</SheetTitle>
      </SheetHeader>
      {#if navigationLocked}
      <div class="flex cursor-not-allowed items-center gap-3 opacity-80" aria-label="Transactions dashboard unavailable while offline" data-testid="locked-sheet-brand">
        <span class="grid size-9 place-items-center rounded-lg bg-primary text-primary-foreground shadow-sm" data-brand-mark>
          <BarChart3 class="size-5" />
        </span>
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-foreground">Transactions</span>
          <span class="block text-xs text-muted-foreground">Expense control</span>
        </span>
      </div>
      {:else}
      <Link href={paths.root || "/"} prefetch cacheFor="30s" draggable="false" class="flex items-center gap-3" onmousedown={(event) => mouseDownNavigate(event, paths.root || "/", { closeMobile: true })} onclick={(event) => ignoreMouseClickAfterMouseDown(event, { closeMobile: true })}>
        <span class="grid size-9 place-items-center rounded-lg bg-primary text-primary-foreground shadow-sm" data-brand-mark>
          <BarChart3 class="size-5" />
        </span>
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-foreground">Transactions</span>
          <span class="block text-xs text-muted-foreground">Expense control</span>
        </span>
      </Link>
      {/if}
      <Separator class="my-4" />
      {#if auth.authenticated}
        <nav class="grid gap-1">
          {#each navItems as item}
            {#if navigationLocked}
              <button type="button" disabled class={mobileNavClass(item, true)} aria-label={lockedNavLabel(item)} data-testid={`locked-mobile-nav-${navKey(item)}`}>
                <svelte:component this={item.icon} class="size-4" />
                <span>{item.label}</span>
              </button>
            {:else if item.fullReload}
              <a href={item.href} data-turbo="false" target={item.newTab ? "_blank" : undefined} rel={item.newTab ? "noreferrer" : undefined} draggable="false" class={mobileNavClass(item)} data-active-nav={isActive(item.href, currentPath, paths.root || "/")}>
                <svelte:component this={item.icon} class="size-4" />
                <span>{item.label}</span>
              </a>
            {:else}
              <Link
                href={item.href}
                prefetch={navPrefetchMode(item)}
                cacheFor="1m"
                draggable="false"
                onmousedown={(event) => mouseDownNavigate(event, item.href, { closeMobile: true })}
                onclick={(event) => ignoreMouseClickAfterMouseDown(event, { closeMobile: true })}
                class={mobileNavClass(item)}
                data-active-nav={isActive(item.href, currentPath, paths.root || "/")}
              >
                <svelte:component this={item.icon} class="size-4" />
                <span>{item.label}</span>
              </Link>
            {/if}
          {/each}
        </nav>
      {/if}
      {#if auth.authenticated}
        <div class="mt-6">
          <Button variant="ghost" class="mb-1 w-full justify-start text-muted-foreground" onclick={toggleTheme} aria-label={`Switch to ${theme === "dim" ? "light" : "dim"} mode`}>
            {#if theme === "dim"}
              <Sun class="size-4" />
              Light mode
            {:else}
              <Moon class="size-4" />
              Dim mode
            {/if}
          </Button>
          <Button variant="ghost" class="w-full justify-start text-muted-foreground" onclick={signOut} disabled={navigationLocked}>
            <LogOut class="size-4" />
            Sign out
          </Button>
        </div>
      {/if}
    </SheetContent>
  </Sheet>

  <main class={mainClass()}>
    <div class="mx-auto w-full max-w-[1500px]">
      {#if visibleFlash.notice}
        <div class="mb-4 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">{visibleFlash.notice}</div>
      {/if}

      {#if visibleFlash.alert}
        <div class="mb-4 rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800">{visibleFlash.alert}</div>
      {/if}

      <slot />
    </div>
  </main>

  {#if showOnboarding}
    <div class="fixed inset-0 z-50 grid place-items-center bg-background/85 p-4 backdrop-blur-sm" role="dialog" aria-modal="true" aria-label="Transactions guided walkthrough">
      <div class="grid w-full max-w-3xl overflow-hidden rounded-lg border border-border bg-card shadow-xl md:grid-cols-[16rem_minmax(0,1fr)]">
        <div class="border-b border-border bg-muted p-4 md:border-b-0 md:border-r">
          <div class="flex items-center gap-3">
            <span class="grid size-10 shrink-0 place-items-center rounded-lg bg-primary text-primary-foreground" data-brand-mark>
              <BarChart3 class="size-5" />
            </span>
            <div class="min-w-0">
              <p class="text-sm font-semibold text-foreground">First run</p>
              <p class="text-xs text-muted-foreground">Guided setup</p>
            </div>
          </div>

          <ol class="mt-5 grid gap-2">
            {#each onboardingSteps as step, index}
              <li>
                <button type="button" class={`flex w-full items-center gap-2 rounded-lg border px-3 py-2 text-left text-sm transition-colors ${index === onboardingStep ? "border-primary bg-background text-foreground shadow-sm" : "border-transparent text-muted-foreground hover:bg-background/80 hover:text-foreground"}`} onclick={() => (onboardingStep = index)}>
                  <span class={`grid size-6 shrink-0 place-items-center rounded-md text-xs font-semibold ${index === onboardingStep ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"}`}>{index + 1}</span>
                  <span>{step.label}</span>
                </button>
              </li>
            {/each}
          </ol>
        </div>

        <div class="p-5 sm:p-6">
          <div class="flex items-start gap-4">
            <span class="grid size-11 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary">
              <svelte:component this={currentOnboardingStep.icon} class="size-5" />
            </span>
            <div class="min-w-0">
              <p class="text-xs font-semibold uppercase tracking-wide text-primary">Step {onboardingStep + 1} of {onboardingSteps.length}</p>
              <h2 class="mt-1 text-2xl font-semibold tracking-normal text-foreground">{currentOnboardingStep.title}</h2>
              <p class="mt-2 text-sm leading-6 text-muted-foreground">{currentOnboardingStep.description}</p>
            </div>
          </div>

          <div class="mt-6 rounded-lg border border-border bg-background p-4 text-sm text-muted-foreground">
            {#if onboardingStep === 0}
              Start here when you have a statement export. Duplicate detection and classification run before rows become permanent.
            {:else if onboardingStep === 1}
              This is the main working screen: saved views, quick ranges, custom dates, bulk category edits, and AI chat all use the current filtered set.
            {:else if onboardingStep === 2}
              Budget rows are shortcuts. Each category links back to matching debit transactions for the selected month.
            {:else}
              Configure reminders first, then add provider keys and model preferences only if you want AI-assisted classification or insights.
            {/if}
          </div>

          <div class="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:items-center">
            <Button type="button" variant="ghost" onclick={() => dismissOnboarding()}>Dismiss permanently</Button>
            <div class="flex gap-2 sm:ml-auto">
              <Button type="button" variant="outline" onclick={previousOnboardingStep} disabled={onboardingStep === 0}>Back</Button>
              {#if onboardingStep < onboardingSteps.length - 1}
                <Button type="button" variant="outline" onclick={nextOnboardingStep}>Next</Button>
              {:else}
                <Button type="button" variant="outline" onclick={() => dismissOnboarding()}>Finish</Button>
              {/if}
              <Button type="button" onclick={() => dismissOnboarding(currentOnboardingStep.path)}>{currentOnboardingStep.action}</Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  @media (min-width: 1280px) {
    .app-main {
      margin-left: var(--sidebar-offset);
    }
  }
</style>
