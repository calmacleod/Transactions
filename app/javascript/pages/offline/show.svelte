<script>
  import { onMount } from "svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Progress } from "$lib/components/ui/progress"
  import { loadOfflineSnapshot, warmOfflineSnapshot } from "$lib/offline-snapshot"
  import { connectionAvailable } from "$lib/connection"
  import { badgeVariant } from "$lib/formatters"
  import BarChart3 from "@lucide/svelte/icons/bar-chart-3"
  import CreditCard from "@lucide/svelte/icons/credit-card"
  import Lightbulb from "@lucide/svelte/icons/lightbulb"
  import PiggyBank from "@lucide/svelte/icons/piggy-bank"
  import Tags from "@lucide/svelte/icons/tags"
  import TrendingUp from "@lucide/svelte/icons/trending-up"
  import Wifi from "@lucide/svelte/icons/wifi"
  import WifiOff from "@lucide/svelte/icons/wifi-off"

  export let snapshot_path = "/offline/snapshot.json"

  let snapshot = null
  let loading = true
  let activeView = "dashboard"
  let query = ""
  let online = typeof navigator === "undefined" ? true : navigator.onLine

  $: pages = snapshot?.pages || {}
  $: dashboard = pages.dashboard || {}
  $: transactionsPage = pages.transactions || {}
  $: spending = pages.spending || {}
  $: budgets = pages.budgets || {}
  $: insights = pages.insights || {}
  $: subcategories = pages.subcategories || {}
  $: transactions = transactionsPage.transactions || []
  $: visibleTransactions = filteredTransactions(transactions, query)
  $: generatedAt = snapshot?.generated_at ? new Date(snapshot.generated_at).toLocaleString() : ""
  $: maxMonthCents = spending.max_month_cents || 0
  $: views = [
    { value: "dashboard", label: "Dashboard", icon: BarChart3 },
    { value: "transactions", label: "Transactions", icon: CreditCard },
    { value: "spending", label: "Spending", icon: TrendingUp },
    { value: "budgets", label: "Budgets", icon: PiggyBank },
    { value: "insights", label: "Insights", icon: Lightbulb },
    { value: "subcategories", label: "Subcategories", icon: Tags },
  ]

  onMount(() => {
    let cancelled = false

    const syncConnectionState = async () => {
      const available = await connectionAvailable()
      if (!cancelled) online = available
    }

    window.addEventListener("online", syncConnectionState)
    window.addEventListener("offline", syncConnectionState)
    syncConnectionState()
    const connectionTimer = window.setInterval(syncConnectionState, 2_000)

    const loadSnapshot = async () => {
      try {
        const storedSnapshot = await loadOfflineSnapshot()
        if (!cancelled) snapshot = storedSnapshot

        if (navigator.onLine) {
          warmOfflineSnapshot(snapshot_path)
        }
      } finally {
        if (!cancelled) loading = false
      }
    }

    loadSnapshot()
    const handleSnapshotRefresh = (event) => {
      if (!cancelled) snapshot = event.detail
    }

    window.addEventListener("transactions-offline-snapshot", handleSnapshotRefresh)

    return () => {
      cancelled = true
      window.clearInterval(connectionTimer)
      window.removeEventListener("online", syncConnectionState)
      window.removeEventListener("offline", syncConnectionState)
      window.removeEventListener("transactions-offline-snapshot", handleSnapshotRefresh)
    }
  })

  function filteredTransactions(records, value) {
    const term = value.trim().toLowerCase()
    if (!term) return records

    return records.filter((transaction) => {
      return [
        transaction.description,
        transaction.merchant_name,
        transaction.category?.name,
        transaction.amount_label,
        transaction.occurred_on_label,
      ].some((field) => field?.toLowerCase().includes(term))
    })
  }

  function percent(value, max, floor = 0) {
    if (!max) return floor
    return Math.max(Math.round((Number(value || 0) / max) * 100), floor)
  }
</script>

<section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
  <div>
    <p class="text-xs font-semibold uppercase tracking-wider text-primary">Offline mode</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">Read-only copy</h1>
    <p class="mt-2 text-sm text-muted-foreground">
      {#if generatedAt}
        Snapshot saved {generatedAt}.
      {:else}
        No saved snapshot has been stored on this device yet.
      {/if}
    </p>
  </div>
  <div class="flex flex-col gap-2 lg:items-end">
    <div class="flex flex-wrap items-center gap-2">
      <Badge variant={online ? "success" : "warning"} class="h-7 gap-1.5" data-testid="offline-connection-badge">
        {#if online}
          <Wifi class="size-3.5" />
          Back online
        {:else}
          <WifiOff class="size-3.5" />
          Offline
        {/if}
      </Badge>
      <Badge variant="secondary" class="h-7">Read only</Badge>
      {#if online}
        <Button href="/" size="sm" data-testid="exit-offline-mode">Exit offline mode</Button>
      {/if}
    </div>
    <p class="max-w-md text-sm text-muted-foreground lg:text-right" data-testid="offline-connection-status">
      {#if online}
        Connection restored. It is safe to exit offline mode and return to the live app.
      {:else}
        Waiting for the connection to return before leaving offline mode.
      {/if}
    </p>
  </div>
</section>

{#if loading}
  <Card>
    <CardContent>
      <p class="text-sm text-muted-foreground">Loading offline data...</p>
    </CardContent>
  </Card>
{:else if !snapshot}
  <Card>
    <CardContent class="grid gap-3">
      <p class="text-sm font-semibold text-foreground">Offline data is not ready on this device.</p>
      <p class="text-sm text-muted-foreground">Open the app while online once so Transactions can save a local read-only copy.</p>
    </CardContent>
  </Card>
{:else}
  <div class="mb-4 flex gap-2 overflow-x-auto pb-1">
    {#each views as view}
      <Button type="button" variant={activeView === view.value ? "default" : "outline"} size="sm" onclick={() => (activeView = view.value)}>
        <svelte:component this={view.icon} class="size-4" />
        {view.label}
      </Button>
    {/each}
  </div>

  {#if activeView === "dashboard"}
    <section class="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      <Card>
        <CardContent>
          <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Month spend</p>
          <p class="money-display mt-2 text-2xl font-semibold text-foreground">{dashboard.metrics?.total_spend_label}</p>
          <p class="mt-1 text-xs text-muted-foreground">{dashboard.month_range?.label}</p>
        </CardContent>
      </Card>
      <Card>
        <CardContent>
          <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Purchases</p>
          <p class="money-display mt-2 text-2xl font-semibold text-foreground">{dashboard.metrics?.expense_count}</p>
          <p class="mt-1 text-xs text-muted-foreground">{dashboard.metrics?.transaction_count} total records</p>
        </CardContent>
      </Card>
      <Card>
        <CardContent>
          <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Average purchase</p>
          <p class="money-display mt-2 text-2xl font-semibold text-foreground">{dashboard.metrics?.average_expense_label}</p>
          <p class="mt-1 text-xs text-muted-foreground">Debits only</p>
        </CardContent>
      </Card>
      <Card>
        <CardContent>
          <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Unclassified</p>
          <p class="money-display mt-2 text-2xl font-semibold text-foreground">{dashboard.metrics?.unclassified_count}</p>
          <p class="mt-1 text-xs text-muted-foreground">{dashboard.metrics?.category_count} categories configured</p>
        </CardContent>
      </Card>
    </section>

    <section class="grid gap-4 xl:grid-cols-2">
      <Card>
        <CardHeader class="border-b border-border">
          <CardTitle class="text-sm">Category allocation</CardTitle>
        </CardHeader>
        <CardContent class="grid gap-2">
          {#each dashboard.category_totals || [] as item}
            <div class="grid gap-3 rounded-lg px-2 py-2 md:grid-cols-[12rem_minmax(0,1fr)_7rem] md:items-center">
              <div class="min-w-0">
                <p class="truncate text-sm font-medium text-foreground">{item.name}</p>
                <p class="text-xs text-muted-foreground">{item.count} transaction{item.count === 1 ? "" : "s"}</p>
              </div>
              <Progress value={item.percent} class="h-2" />
              <p class="money-value text-sm font-semibold text-foreground md:text-right">{item.amount_label}</p>
            </div>
          {/each}
        </CardContent>
      </Card>

      <Card>
        <CardHeader class="border-b border-border">
          <CardTitle class="text-sm">Latest transactions</CardTitle>
        </CardHeader>
        <CardContent class="grid gap-2">
          {#each dashboard.transactions || [] as transaction}
            <div class="grid gap-2 rounded-lg border border-border bg-background px-3 py-2 text-sm md:grid-cols-[6rem_minmax(0,1fr)_8rem] md:items-center">
              <p class="text-xs text-muted-foreground">{transaction.short_date_label}</p>
              <p class="truncate font-medium text-foreground">{transaction.merchant_name || transaction.description}</p>
              <p class={`money-value text-right font-semibold ${transaction.amount_class}`}>{transaction.amount_label}</p>
            </div>
          {/each}
        </CardContent>
      </Card>
    </section>
  {:else if activeView === "transactions"}
    <section class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <h2 class="text-xl font-semibold tracking-tight text-foreground">Transactions</h2>
        <p class="mt-1 text-sm text-muted-foreground">{visibleTransactions.length} of {transactions.length} records</p>
      </div>
      <input class="h-10 rounded-md border border-input bg-background px-3 text-sm shadow-xs outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 sm:w-72" placeholder="Search offline transactions" bind:value={query} />
    </section>
    <div class="grid gap-2">
      {#each visibleTransactions as transaction}
        <Card>
          <CardContent class="grid gap-2 md:grid-cols-[8rem_minmax(0,1fr)_10rem] md:items-center">
            <p class="text-xs font-medium text-muted-foreground">{transaction.occurred_on_label}</p>
            <div class="min-w-0">
              <p class="truncate text-sm font-semibold text-foreground">{transaction.merchant_name || transaction.description}</p>
              <p class="mt-1 text-xs text-muted-foreground">{transaction.category?.name || "Unclassified"}</p>
            </div>
            <p class={`money-value text-right text-sm font-semibold ${transaction.amount_class}`}>{transaction.amount_label}</p>
          </CardContent>
        </Card>
      {/each}
    </div>
  {:else if activeView === "spending"}
    <section class="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      {#each spending.monthly_totals || [] as month}
        <Card>
          <CardContent>
            <div class="flex items-center justify-between gap-3">
              <p class="text-sm font-semibold text-foreground">{month.label}</p>
              <p class="money-value text-sm font-semibold text-foreground">{month.amount_label}</p>
            </div>
            <Progress value={percent(month.cents, maxMonthCents)} class="mt-3 h-2" />
          </CardContent>
        </Card>
      {/each}
    </section>
    <Card>
      <CardHeader class="border-b border-border">
        <CardTitle class="text-sm">Category spend by month</CardTitle>
      </CardHeader>
      <CardContent class="grid gap-3">
        {#each spending.category_rows || [] as row}
          <div class="rounded-lg border border-border bg-background p-3">
            <div class="mb-3 flex items-center justify-between gap-3">
              <p class="text-sm font-semibold text-foreground">{row.category.name}</p>
              <p class="money-value text-sm font-semibold text-foreground">{row.total_label}</p>
            </div>
            <div class="grid gap-2 sm:grid-cols-2 xl:grid-cols-4">
              {#each row.months as month}
                <div class="rounded-md bg-muted px-2 py-1 text-xs">
                  <span class="text-muted-foreground">{month.month.slice(0, 7)}</span>
                  <span class="money-value float-right font-medium text-foreground">{month.amount_label}</span>
                </div>
              {/each}
            </div>
          </div>
        {/each}
      </CardContent>
    </Card>
  {:else if activeView === "budgets"}
    <Card>
      <CardHeader class="border-b border-border">
        <CardTitle class="text-sm">{budgets.month?.label}</CardTitle>
      </CardHeader>
      <CardContent class="grid gap-3">
        {#each budgets.categories || [] as category}
          <div class="grid min-w-0 gap-3 rounded-lg border border-border bg-background p-3 xl:grid-cols-[minmax(0,1fr)_minmax(0,12rem)] xl:items-center">
            <div class="min-w-0">
              <div class="flex items-center gap-2">
                <span class="size-2.5 rounded-sm" style={`background-color: ${category.color}`}></span>
                <p class="truncate text-sm font-semibold text-foreground">{category.name}</p>
                {#if category.remaining_cents < 0}
                  <Badge variant="destructive">over</Badge>
                {/if}
              </div>
              <Progress value={category.used_percent} class="mt-3 h-2" />
              <p class="mt-1 text-xs text-muted-foreground">{category.spent_label} spent, {category.remaining_label} remaining</p>
            </div>
            <p class="money-value text-sm font-semibold text-foreground xl:text-right">{category.budget_label}</p>
          </div>
        {/each}
      </CardContent>
    </Card>
  {:else if activeView === "insights"}
    <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
      {#each insights.insights || [] as insight}
        <Card>
          <CardHeader>
            <div class="flex items-start justify-between gap-4">
              <CardTitle class="text-base">{insight.title}</CardTitle>
              <Badge variant={badgeVariant(insight.severity)}>{insight.severity}</Badge>
            </div>
          </CardHeader>
          <CardContent>
            <p class="text-sm leading-6 text-muted-foreground">{insight.body}</p>
            <p class="mt-4 text-xs font-medium text-muted-foreground">{insight.starts_on} to {insight.ends_on}</p>
          </CardContent>
        </Card>
      {/each}
    </div>
  {:else if activeView === "subcategories"}
    <Card>
      <CardHeader class="border-b border-border">
        <CardTitle class="text-sm">Available chips</CardTitle>
      </CardHeader>
      <CardContent>
        <div class="flex flex-wrap gap-2">
          {#each subcategories.subcategories || [] as subcategory}
            <Badge variant="outline" class="h-7 gap-1.5 pl-2 pr-2">
              <span class="size-2 rounded-full" style={`background-color: ${subcategory.color}`}></span>
              {subcategory.name}
            </Badge>
          {/each}
        </div>
      </CardContent>
    </Card>
  {/if}
{/if}
