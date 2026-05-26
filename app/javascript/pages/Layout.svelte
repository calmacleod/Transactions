<script>
  import { onMount } from "svelte"
  import { Link, router, usePage } from "@inertiajs/svelte"
  import { Button } from "$lib/components/ui/button"
  import { Separator } from "$lib/components/ui/separator"
  import { Sheet, SheetContent, SheetHeader, SheetTitle } from "$lib/components/ui/sheet"
  import BarChart3 from "@lucide/svelte/icons/bar-chart-3"
  import Bot from "@lucide/svelte/icons/bot"
  import BriefcaseBusiness from "@lucide/svelte/icons/briefcase-business"
  import CreditCard from "@lucide/svelte/icons/credit-card"
  import LayoutDashboard from "@lucide/svelte/icons/layout-dashboard"
  import Lightbulb from "@lucide/svelte/icons/lightbulb"
  import LogOut from "@lucide/svelte/icons/log-out"
  import Menu from "@lucide/svelte/icons/menu"
  import Moon from "@lucide/svelte/icons/moon"
  import Sun from "@lucide/svelte/icons/sun"

  const navLinkClass = "group flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors"
  const page = usePage()

  $: auth = page.props.auth || {}
  $: paths = page.props.paths || {}
  $: flash = page.props.flash || {}
  $: currentPath = page.url || "/"
  $: navItems = [
    { label: "Dashboard", href: paths.root || "/", icon: LayoutDashboard },
    { label: "Transactions", href: paths.transactions || "/transactions", icon: CreditCard },
    { label: "Insights", href: paths.insights || "/insights", icon: Lightbulb },
    { label: "Models", href: paths.models || "/models", icon: Bot },
    { label: "Jobs", href: paths.jobs || "/admin/jobs", icon: BriefcaseBusiness, fullReload: true },
  ]

  let mobileOpen = false
  let theme = "light"

  onMount(() => {
    const savedTheme = window.localStorage.getItem("transactions-theme")
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    setTheme(savedTheme || (prefersDark ? "dark" : "light"))
  })

  function setTheme(value) {
    theme = value === "dark" ? "dark" : "light"
    document.documentElement.classList.toggle("dark", theme === "dark")
    window.localStorage.setItem("transactions-theme", theme)
  }

  function toggleTheme() {
    setTheme(theme === "dark" ? "light" : "dark")
  }

  function signOut() {
    router.delete(paths.session)
  }

  function isActive(href) {
    if (href === paths.root || href === "/") return currentPath === "/" || currentPath.startsWith("/?")
    return currentPath === href || currentPath.startsWith(`${href}?`)
  }
</script>

<div class="min-h-screen bg-background text-foreground">
  <aside class="fixed inset-y-0 left-0 z-30 hidden w-64 border-r border-border bg-card/95 px-3 py-4 shadow-sm xl:flex xl:flex-col">
    <div class="px-2">
      <Link href={paths.root || "/"} prefetch cacheFor="30s" class="flex items-center gap-3">
        <span class="grid size-9 place-items-center rounded-lg bg-primary text-primary-foreground shadow-sm">
          <BarChart3 class="size-5" />
        </span>
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-foreground">Transactions</span>
          <span class="block text-xs text-muted-foreground">Expense control</span>
        </span>
      </Link>
    </div>

    <Separator class="my-4" />

    {#if auth.authenticated}
      <nav class="grid gap-1">
        {#each navItems as item}
          {#if item.fullReload}
            <a href={item.href} data-turbo="false" class={`${navLinkClass} ${isActive(item.href) ? "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:bg-muted hover:text-foreground"}`}>
              <svelte:component this={item.icon} class="size-4" />
              <span>{item.label}</span>
            </a>
          {:else}
            <Link
              href={item.href}
              prefetch
              cacheFor="30s"
              class={`${navLinkClass} ${isActive(item.href) ? "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:bg-muted hover:text-foreground"}`}
            >
              <svelte:component this={item.icon} class="size-4" />
              <span>{item.label}</span>
            </Link>
          {/if}
        {/each}
      </nav>
    {/if}

    {#if auth.authenticated}
      <div class="mt-auto">
        <Separator class="my-4" />
        <Button variant="ghost" class="mb-1 w-full justify-start text-muted-foreground" onclick={toggleTheme} aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} mode`}>
          {#if theme === "dark"}
            <Sun class="size-4" />
            Light mode
          {:else}
            <Moon class="size-4" />
            Dark mode
          {/if}
        </Button>
        <Button variant="ghost" class="w-full justify-start text-muted-foreground" onclick={signOut}>
          <LogOut class="size-4" />
          Sign out
        </Button>
      </div>
    {/if}
  </aside>

  <header class="fixed inset-x-0 top-0 z-40 flex h-[calc(3.5rem+env(safe-area-inset-top))] items-center gap-3 border-b border-border bg-background/95 px-4 pt-[env(safe-area-inset-top)] shadow-sm backdrop-blur xl:hidden">
    <Button variant="outline" size="icon" aria-label="Open navigation" onclick={() => (mobileOpen = true)}>
      <Menu class="size-4" />
    </Button>
    <Link href={paths.root || "/"} prefetch cacheFor="30s" class="flex items-center gap-3">
      <span class="grid size-9 place-items-center rounded-lg bg-primary text-primary-foreground shadow-sm">
        <BarChart3 class="size-5" />
      </span>
      <span class="min-w-0">
        <span class="block text-sm font-semibold text-foreground">Transactions</span>
        <span class="block text-xs text-muted-foreground">Expense control</span>
      </span>
    </Link>
    <Button variant="outline" size="icon" class="ml-auto" aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} mode`} onclick={toggleTheme}>
      {#if theme === "dark"}
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
      <Link href={paths.root || "/"} prefetch cacheFor="30s" class="flex items-center gap-3">
        <span class="grid size-9 place-items-center rounded-lg bg-primary text-primary-foreground shadow-sm">
          <BarChart3 class="size-5" />
        </span>
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-foreground">Transactions</span>
          <span class="block text-xs text-muted-foreground">Expense control</span>
        </span>
      </Link>
      <Separator class="my-4" />
      {#if auth.authenticated}
        <nav class="grid gap-1">
          {#each navItems as item}
            {#if item.fullReload}
              <a href={item.href} data-turbo="false" class={`${navLinkClass} ${isActive(item.href) ? "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:bg-muted hover:text-foreground"}`}>
                <svelte:component this={item.icon} class="size-4" />
                <span>{item.label}</span>
              </a>
            {:else}
              <Link
                href={item.href}
                prefetch
                cacheFor="30s"
                onclick={() => (mobileOpen = false)}
                class={`${navLinkClass} ${isActive(item.href) ? "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:bg-muted hover:text-foreground"}`}
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
          <Button variant="ghost" class="mb-1 w-full justify-start text-muted-foreground" onclick={toggleTheme} aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} mode`}>
            {#if theme === "dark"}
              <Sun class="size-4" />
              Light mode
            {:else}
              <Moon class="size-4" />
              Dark mode
            {/if}
          </Button>
          <Button variant="ghost" class="w-full justify-start text-muted-foreground" onclick={signOut}>
            <LogOut class="size-4" />
            Sign out
          </Button>
        </div>
      {/if}
    </SheetContent>
  </Sheet>

  <main class="min-w-0 px-4 pb-5 pt-[calc(4.5rem+env(safe-area-inset-top))] sm:px-6 lg:px-8 xl:ml-64 xl:py-5">
    <div class="mx-auto w-full max-w-[1500px]">
      {#if flash.notice}
        <div class="mb-4 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">{flash.notice}</div>
      {/if}

      {#if flash.alert}
        <div class="mb-4 rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800">{flash.alert}</div>
      {/if}

      <slot />
    </div>
  </main>
</div>
