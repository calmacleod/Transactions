<script>
  import { Link } from "@inertiajs/svelte"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Progress } from "$lib/components/ui/progress"
  import TrendingUp from "@lucide/svelte/icons/trending-up"

  export let months = []
  export let monthly_totals = []
  export let category_rows = []
  export let max_month_cents = 0
  export let max_category_cents = 0

  $: yearGroups = buildYearGroups(months)

  function percent(value, max, floor = 0) {
    if (!max) return floor
    return Math.max(Math.round((Number(value || 0) / max) * 100), floor)
  }

  function buildYearGroups(months) {
    return months.reduce((groups, month) => {
      const year = month.year || month.value?.slice(0, 4) || ""
      const previousGroup = groups[groups.length - 1]

      if (previousGroup?.year === year) {
        previousGroup.count += 1
      } else {
        groups.push({ year, count: 1 })
      }

      return groups
    }, [])
  }
</script>

<svelte:head>
  <title>Spending - Transactions</title>
</svelte:head>

<section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
  <div>
    <p class="text-xs font-semibold uppercase tracking-wider text-primary">Spend history</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">Monthly spending</h1>
    <p class="mt-2 text-sm text-muted-foreground">All recorded months and category movement over time.</p>
  </div>
  <span class="inline-flex h-9 items-center gap-2 rounded-lg border border-border bg-background px-3 text-sm text-muted-foreground">
    <TrendingUp class="size-4" />
    {months.length} month{months.length === 1 ? "" : "s"} on record
  </span>
</section>

<Card class="mb-4">
  <CardHeader class="border-b border-border">
    <CardTitle class="text-sm">All months</CardTitle>
  </CardHeader>
  <CardContent>
    <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      {#each monthly_totals as month}
        <Link href={month.filters_path} prefetch cacheFor="30s" class="rounded-lg border border-border bg-background p-3 transition-colors hover:bg-muted/50">
          <div class="flex items-center justify-between gap-3">
            <p class="text-sm font-semibold text-foreground">{month.label}</p>
            <p class="money-value text-sm font-semibold text-foreground">{month.amount_label}</p>
          </div>
          <Progress value={percent(month.cents, max_month_cents)} class="mt-3 h-2" />
        </Link>
      {/each}
    </div>
  </CardContent>
</Card>

<Card class="overflow-hidden">
  <CardHeader class="border-b border-border">
    <CardTitle class="text-sm">Category spend by month</CardTitle>
  </CardHeader>
  <CardContent class="p-0">
    <div class="overflow-x-auto">
      <table class="w-full min-w-[72rem] text-sm">
        <thead class="border-b border-border bg-muted text-xs text-muted-foreground">
          <tr>
            <th rowspan="2" class="sticky left-0 z-10 w-56 bg-muted px-4 py-3 text-left align-bottom font-medium">Category</th>
            {#each yearGroups as group}
              <th colspan={group.count} class="border-b border-border px-3 py-2 text-center font-semibold text-foreground">{group.year}</th>
            {/each}
            <th rowspan="2" class="w-32 px-4 py-3 text-right align-bottom font-medium">Total</th>
          </tr>
          <tr>
            {#each months as month}
              <th class="w-32 px-3 py-3 text-right font-medium">{month.short_label || month.label}</th>
            {/each}
          </tr>
        </thead>
        <tbody class="divide-y divide-border">
          {#each category_rows as row}
            <tr>
              <td class="sticky left-0 z-10 bg-card px-4 py-3">
                <div class="flex items-center gap-2">
                  <span class="size-2.5 rounded-sm" style={`background-color: ${row.category.color}`}></span>
                  <span class="font-medium text-foreground">{row.category.name}</span>
                </div>
              </td>
              {#each row.months as month}
                <td class="px-3 py-3 text-right">
                  <Link href={month.filters_path} prefetch cacheFor="30s" class="block rounded-md bg-background px-2 py-1 hover:bg-muted/60">
                    <span class="money-value text-xs font-medium text-foreground">{month.amount_label}</span>
                    <span class="mt-1 block h-1 rounded-full bg-muted">
                      <span class="block h-1 rounded-full bg-primary" style={`width: ${percent(month.cents, max_category_cents)}%`}></span>
                    </span>
                  </Link>
                </td>
              {/each}
              <td class="px-4 py-3 text-right font-semibold text-foreground">{row.total_label}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </CardContent>
</Card>
