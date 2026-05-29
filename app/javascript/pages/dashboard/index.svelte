<script>
  import { Link, router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Progress } from "$lib/components/ui/progress"
  import { Sheet, SheetContent, SheetDescription, SheetFooter, SheetHeader, SheetTitle } from "$lib/components/ui/sheet"
  import { Table, TableBody, TableCell, TableRow } from "$lib/components/ui/table"
  import CategoryBadge from "../components/CategoryBadge.svelte"
  import ClassificationRun from "../components/ClassificationRun.svelte"
  import { badgeVariant } from "$lib/formatters"
  import CalendarDays from "@lucide/svelte/icons/calendar-days"
  import CreditCard from "@lucide/svelte/icons/credit-card"
  import History from "@lucide/svelte/icons/history"
  import Sparkles from "@lucide/svelte/icons/sparkles"
  import Target from "@lucide/svelte/icons/target"
  import Upload from "@lucide/svelte/icons/upload"
  import UploadCloud from "@lucide/svelte/icons/upload-cloud"

  export let month_range
  export let metrics
  export let category_totals = []
  export let day_totals = []
  export let month_trend = []
  export let month_delta
  export let top_merchants = []
  export let recommendations = []
  export let transactions = []
  export let insights = []
  export let classification_run = null
  export let upload_prompt = { title: "Upload transactions", body: "Import your latest card CSV and review every row before it is added.", days_since_last_upload: null }
  export let unfinished_import = null
  export let actions

  let csvFile
  let uploadOpen = false
  let dragActive = false

  $: maxCategory = Math.max(...category_totals.map((item) => item.cents || 0), 0)
  $: maxDayCount = Math.max(...day_totals.map((item) => item.count || 0), 0)
  $: maxMonth = Math.max(...month_trend.map((item) => item.cents || 0), 0)
  $: uploadFileName = csvFile?.name || "No file selected"
  $: showUploadAlert = upload_prompt.days_since_last_upload !== null && upload_prompt.days_since_last_upload >= 3
  $: kpis = [
    { label: "Month spend", value: metrics.total_spend_label, note: month_range.label, href: actions.month_transactions, icon: CreditCard },
    { label: "Purchases", value: metrics.expense_count, note: `${metrics.transaction_count} total records`, href: actions.month_transactions, icon: CalendarDays },
    { label: "Average purchase", value: metrics.average_expense_label, note: "Debits only", href: actions.month_transactions, icon: Target },
    { label: "Unclassified", value: metrics.unclassified_count, note: `${metrics.category_count} categories configured`, href: actions.unclassified_transactions, icon: Sparkles },
  ]

  function percent(value, max, floor = 0) {
    if (!max) return floor
    return Math.max(Math.round((value / max) * 100), floor)
  }

  function importCsv() {
    if (!csvFile) return
    router.post(actions.import, { csv_file: csvFile }, { forceFormData: true, preserveScroll: true, preserveState: true })
  }

  function chooseFile(event) {
    csvFile = event.currentTarget.files?.[0]
  }

  function handleDrop(event) {
    event.preventDefault()
    dragActive = false
    csvFile = event.dataTransfer?.files?.[0]
  }
</script>

  <section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
    <div class="max-w-3xl">
      <p class="text-xs font-semibold uppercase tracking-wider text-primary">Expense control</p>
      <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">Spending dashboard</h1>
      <p class="mt-2 text-sm text-muted-foreground">Current month activity, recent movement, and drill-downs into the transactions behind every number.</p>
    </div>

    <div class="flex flex-wrap gap-2">
      <Button href={actions.imports} variant="outline" size="lg">
        <History class="size-4" />
        Past imports
      </Button>
      <Button size="lg" onclick={() => (uploadOpen = true)}>
        <Upload class="size-4" />
        Upload transactions
      </Button>
    </div>
  </section>

  {#if showUploadAlert}
    <section class="mb-4 rounded-lg border border-amber-300 bg-amber-50 p-3 text-amber-950 dark:border-amber-700 dark:bg-amber-950/30 dark:text-amber-100">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p class="text-sm font-semibold">{upload_prompt.title}</p>
          <p class="mt-1 text-xs leading-5">{upload_prompt.body}</p>
        </div>
        <Button variant="outline" size="sm" class="border-amber-300 bg-amber-50 hover:bg-amber-100 dark:border-amber-700 dark:bg-amber-950/30 dark:hover:bg-amber-900/40" onclick={() => (uploadOpen = true)}>
          Upload CSV
        </Button>
      </div>
    </section>
  {/if}

  <Sheet bind:open={uploadOpen}>
    <SheetContent class="w-full p-5 sm:max-w-md">
      <SheetHeader>
        <SheetTitle>Upload transactions</SheetTitle>
        <SheetDescription>Choose a headerless card CSV. You will review every mapped row before anything is added.</SheetDescription>
      </SheetHeader>

      <form class="grid gap-4" onsubmit={(event) => {
        event.preventDefault()
        importCsv()
      }}>
        <label
          for="dashboard-csv-file"
          class={`grid min-h-44 cursor-pointer place-items-center rounded-lg border border-dashed p-5 text-center transition-colors ${dragActive ? "border-primary bg-primary/10" : "border-border bg-background hover:bg-muted"}`}
          ondragover={(event) => {
            event.preventDefault()
            dragActive = true
          }}
          ondragleave={() => (dragActive = false)}
          ondrop={handleDrop}
        >
          <span class="grid gap-3">
            <span class="mx-auto grid size-10 place-items-center rounded-lg bg-primary text-primary-foreground">
              <UploadCloud class="size-5" />
            </span>
            <span>
              <span class="block text-sm font-semibold text-foreground">Drop CSV here or choose a file</span>
              <span class="mt-1 block text-xs text-muted-foreground">{uploadFileName}</span>
            </span>
          </span>
        </label>
        <input id="dashboard-csv-file" aria-label="Upload transactions" type="file" accept=".csv,text/csv" class="sr-only" onchange={chooseFile} />

        <SheetFooter>
          <Button type="submit" class="w-full" disabled={!csvFile}>
            Review CSV
          </Button>
        </SheetFooter>
      </form>
    </SheetContent>
  </Sheet>

  {#if unfinished_import}
    <section class="mb-4 rounded-lg border border-amber-300 bg-amber-50 p-3 text-amber-950 dark:border-amber-700 dark:bg-amber-950/30 dark:text-amber-100">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p class="text-sm font-semibold">Finish importing {unfinished_import.filename}</p>
          <p class="mt-1 text-xs">Started {unfinished_import.created_at_label}. {unfinished_import.rows_count} row{unfinished_import.rows_count === 1 ? "" : "s"} still waiting for review.</p>
        </div>
        <Button href={unfinished_import.preview_path} variant="outline" size="sm" class="border-amber-300 bg-amber-50 hover:bg-amber-100 dark:border-amber-700 dark:bg-amber-950/30 dark:hover:bg-amber-900/40">Resume import</Button>
      </div>
    </section>
  {/if}

  <ClassificationRun run={classification_run} />

  <section class="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
    {#each kpis as kpi}
      <Card class="p-0 transition-colors hover:bg-muted/40">
        <Link href={kpi.href} prefetch cacheFor="30s" class="block p-4">
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{kpi.label}</p>
              <p class="money-display mt-2 text-2xl font-semibold text-foreground">{kpi.value}</p>
              <p class="mt-1 text-xs text-muted-foreground">{kpi.note}</p>
            </div>
            <span class="grid size-9 place-items-center rounded-lg bg-accent text-accent-foreground">
              <svelte:component this={kpi.icon} class="size-4" />
            </span>
          </div>
        </Link>
      </Card>
    {/each}
  </section>

  <section class="mb-4 grid gap-4 xl:grid-cols-[minmax(0,1.35fr)_minmax(22rem,0.65fr)]">
    <Card data-testid="latest-transactions-panel">
      <CardHeader class="border-b border-border">
        <div class="flex items-center justify-between gap-3">
          <CardTitle class="text-sm">Category allocation</CardTitle>
          <Button href={actions.month_transactions} variant="ghost" size="sm">All transactions</Button>
        </div>
      </CardHeader>
      <CardContent class="grid gap-2 pt-1">
        {#each category_totals.slice(0, 8) as item}
          <Link href={item.filters_path} prefetch cacheFor="30s" class="grid gap-3 rounded-lg bg-background px-2 py-2 transition-colors hover:bg-muted md:grid-cols-[12rem_minmax(0,1fr)_7rem] md:items-center">
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-foreground">{item.name}</p>
              <p class="text-xs text-muted-foreground">{item.count} transaction{item.count === 1 ? "" : "s"}</p>
            </div>
            <div class="flex items-center gap-3">
              <Progress value={percent(item.cents, maxCategory)} class="h-2" />
              <span class="w-10 text-right text-xs font-medium text-muted-foreground">{item.percent}%</span>
            </div>
            <div class="text-left md:text-right">
              <p class="money-value text-sm font-semibold text-foreground">{item.amount_label}</p>
              {#if item.budget_cents}
                <p class="text-xs text-muted-foreground">{item.budget_percent}% budget</p>
              {/if}
            </div>
          </Link>
        {/each}
      </CardContent>
    </Card>

    <Card>
      <CardHeader class="border-b border-border">
        <CardTitle class="text-sm">Cutback targets</CardTitle>
      </CardHeader>
      <CardContent class="grid gap-2 pt-1">
        {#each recommendations as recommendation}
          <Link href={recommendation.filters_path} prefetch cacheFor="30s" class="rounded-lg bg-background px-2 py-2 transition-colors hover:bg-muted">
            <div class="flex items-start justify-between gap-3">
              <h3 class="text-sm font-semibold text-foreground">{recommendation.title}</h3>
              <Badge variant={badgeVariant(recommendation.severity)}>{recommendation.severity}</Badge>
            </div>
            <p class="mt-1 text-xs leading-5 text-muted-foreground">{recommendation.body}</p>
          </Link>
        {/each}
      </CardContent>
    </Card>
  </section>

  <section class="mb-4 grid gap-4 xl:grid-cols-2">
    <Card>
      <CardHeader class="border-b border-border">
        <div class="flex items-center justify-between gap-3">
          <CardTitle class="text-sm">Day-of-week frequency</CardTitle>
          <span class="text-xs font-medium text-muted-foreground">click a day</span>
        </div>
      </CardHeader>
      <CardContent>
        <div class="mt-1 flex h-48 items-end gap-2">
          {#each day_totals as day}
            <Link href={day.filters_path} prefetch cacheFor="30s" class="flex min-w-0 flex-1 flex-col items-center gap-2 rounded-lg bg-background p-1 transition-colors hover:bg-muted">
              <div class="flex h-36 w-full items-end overflow-hidden rounded-lg bg-muted">
                <div class="w-full rounded-lg bg-gradient-to-t from-primary to-teal-500" style={`height: ${percent(day.count, maxDayCount, 6)}%`}></div>
              </div>
              <div class="text-center">
                <p class="text-xs font-semibold text-foreground">{day.name}</p>
                <p class="text-xs text-muted-foreground">{day.count}</p>
              </div>
            </Link>
          {/each}
        </div>
      </CardContent>
    </Card>

    <Card>
      <CardHeader class="border-b border-border">
        <div class="flex items-center justify-between gap-3">
          <CardTitle class="text-sm">Recent month movement</CardTitle>
          <Badge class="money-value" variant={month_delta.cents > 0 ? "destructive" : "success"}>{month_delta.cents > 0 ? "+" : ""}{month_delta.label}</Badge>
        </div>
      </CardHeader>
      <CardContent>
        <div class="mt-1 flex h-48 items-end gap-3">
          {#each month_trend as month}
            <Link href={month.filters_path} prefetch cacheFor="30s" class="flex min-w-0 flex-1 flex-col items-center gap-2 rounded-lg bg-background p-1 transition-colors hover:bg-muted">
              <div class="flex h-36 w-full items-end overflow-hidden rounded-lg bg-muted">
                <div class="w-full rounded-lg bg-gradient-to-t from-primary to-teal-500" style={`height: ${percent(month.cents, maxMonth, 6)}%`}></div>
              </div>
              <div class="text-center">
                <p class="text-xs font-semibold text-foreground">{month.label}</p>
                <p class="money-value text-xs text-muted-foreground">{month.amount_label}</p>
              </div>
            </Link>
          {/each}
        </div>
      </CardContent>
    </Card>
  </section>

  <section class="mb-4 grid gap-4 xl:grid-cols-[minmax(20rem,0.42fr)_minmax(0,0.58fr)]">
    <Card data-testid="top-merchants-panel">
      <CardHeader class="border-b border-border">
        <CardTitle class="text-sm">Top merchants</CardTitle>
      </CardHeader>
      <CardContent class="grid min-w-0 gap-1 pt-1">
        {#each top_merchants as merchant}
          <Link href={merchant.filters_path} prefetch cacheFor="30s" class="flex min-w-0 max-w-full items-center justify-between gap-3 rounded-lg bg-background px-2 py-2 transition-colors hover:bg-muted" data-testid="top-merchant-row">
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-foreground">{merchant.merchant_label}</p>
              <p class="text-xs text-muted-foreground">{merchant.count} purchase{merchant.count === 1 ? "" : "s"}</p>
            </div>
            <p class="money-value shrink-0 text-sm font-semibold text-foreground">{merchant.amount_label}</p>
          </Link>
        {/each}
      </CardContent>
    </Card>

    <Card>
      <CardHeader class="border-b border-border">
        <div class="flex items-center justify-between gap-3">
          <CardTitle class="text-sm">Latest transactions</CardTitle>
          <Button href={actions.month_transactions} variant="ghost" size="sm">View all</Button>
        </div>
      </CardHeader>
      <CardContent class="pt-0">
        <div data-testid="latest-transactions-scroll" class="overflow-x-auto">
          <Table class="table-fixed">
            <TableBody>
              {#each transactions as transaction}
                <TableRow>
                  <TableCell class="w-20 whitespace-nowrap text-muted-foreground">{transaction.short_date_label}</TableCell>
                  <TableCell class="min-w-0 truncate font-medium text-foreground">{transaction.description}</TableCell>
                  <TableCell class="w-36"><CategoryBadge category={transaction.category} /></TableCell>
                  <TableCell class={`money-value w-28 pr-5 text-right font-semibold ${transaction.amount_class}`}>{transaction.amount_label}</TableCell>
                </TableRow>
              {/each}
            </TableBody>
          </Table>
        </div>
      </CardContent>
    </Card>
  </section>

  <section class="grid gap-3 md:grid-cols-2">
    {#each insights as insight}
      <Card>
        <CardContent>
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-primary">{insight.starts_on_label}</p>
              <h3 class="mt-1 text-sm font-semibold text-foreground">{insight.title}</h3>
            </div>
            <Badge variant={badgeVariant(insight.severity)}>{insight.severity}</Badge>
          </div>
          <p class="mt-2 text-xs leading-5 text-muted-foreground">{insight.body}</p>
          <Badge class="mt-3" variant={insight.generation_source === "ai" ? "success" : "secondary"}>{insight.generation_source_label}</Badge>
        </CardContent>
      </Card>
    {/each}
  </section>
