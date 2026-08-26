<script>
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { badgeVariant } from "$lib/formatters"
  import ArrowDown from "@lucide/svelte/icons/arrow-down"
  import ArrowUp from "@lucide/svelte/icons/arrow-up"
  import CircleAlert from "@lucide/svelte/icons/circle-alert"
  import CircleCheck from "@lucide/svelte/icons/circle-check"
  import Lightbulb from "@lucide/svelte/icons/lightbulb"
  import RefreshCcw from "@lucide/svelte/icons/refresh-ccw"
  import Repeat2 from "@lucide/svelte/icons/repeat-2"
  import SearchCheck from "@lucide/svelte/icons/search-check"
  import WalletCards from "@lucide/svelte/icons/wallet-cards"
  import X from "@lucide/svelte/icons/x"

  export let insights = []
  export let overview = {}
  export let period = {}
  export let actions

  let selectedInsight = null
  let regenerationState = "idle"
  let regenerationMessage = ""

  $: overviewCards = [
    { label: overview.spend?.label || "Spend", value: overview.spend?.value || "$0.00", note: overview.month_label, icon: WalletCards },
    {
      label: "Versus prior month",
      value: overview.change?.value || "$0.00",
      note: overview.change?.percent == null ? "No prior baseline" : `${overview.change.percent}% ${overview.change.direction}`,
      icon: overview.change?.direction === "down" ? ArrowDown : ArrowUp,
      positive: overview.change?.direction === "down",
    },
    { label: overview.recurring?.label || "Recurring baseline", value: overview.recurring?.value || "$0.00", note: "Stable repeat merchants", icon: Repeat2 },
    { label: "Unusual purchases", value: overview.unusual_count || 0, note: `${overview.unclassified?.value || "$0.00"} unclassified`, icon: SearchCheck },
  ]

  async function regenerate() {
    if (regenerationState === "submitting") return

    regenerationState = "submitting"
    regenerationMessage = ""

    try {
      const response = await fetch(actions.regenerate, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "",
        },
      })
      const payload = await response.json().catch(() => ({}))

      if (!response.ok) throw new Error(payload.message || "Request failed")

      regenerationState = "queued"
      regenerationMessage = payload.message || "Insight regeneration queued."
    } catch (_error) {
      regenerationState = "error"
      regenerationMessage = "Insight regeneration could not be queued. Please try again."
    }
  }
</script>

<svelte:head>
  <title>Insights - Transactions</title>
</svelte:head>

<section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
  <div>
    <p class="text-xs font-semibold uppercase tracking-wider text-primary">Decision support</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">Insights</h1>
    <p class="mt-2 max-w-3xl text-sm text-muted-foreground">Changes, risks, and recurring commitments that differ from your normal spending—not a restatement of totals. Analysis through {period.analysis_month_label}.</p>
  </div>
  <div class="flex flex-col items-start gap-2 lg:items-end">
    <Button onclick={regenerate} disabled={regenerationState === "submitting"}>
      <RefreshCcw class="size-4" />
      {regenerationState === "submitting" ? "Queuing…" : "Regenerate"}
    </Button>
    {#if regenerationMessage}
      <p
        class={`flex max-w-sm items-center gap-1.5 text-xs font-medium ${regenerationState === "error" ? "text-destructive" : "text-emerald-700 dark:text-emerald-400"}`}
        role="status"
        aria-live="polite"
        data-testid="regeneration-feedback"
      >
        {#if regenerationState === "error"}
          <CircleAlert class="size-3.5 shrink-0" />
        {:else}
          <CircleCheck class="size-3.5 shrink-0" />
        {/if}
        {regenerationMessage}
      </p>
    {/if}
  </div>
</section>

<section class="mb-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
  {#each overviewCards as item (item.label)}
    <Card>
      <CardContent>
        <div class="flex items-start justify-between gap-3">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{item.label}</p>
            <p class={`money-display mt-2 text-2xl font-semibold ${item.positive ? "text-emerald-600 dark:text-emerald-400" : "text-foreground"}`}>{item.value}</p>
            <p class="mt-1 text-xs text-muted-foreground">{item.note}</p>
          </div>
          <span class="grid size-9 place-items-center rounded-lg bg-accent text-accent-foreground">
            <svelte:component this={item.icon} class="size-4" />
          </span>
        </div>
      </CardContent>
    </Card>
  {/each}
</section>

{#if insights.length}
  <div class="grid gap-4 lg:grid-cols-2">
    {#each insights as insight (insight.id)}
      <Card
        class="cursor-pointer transition-colors hover:border-primary/40"
        data-testid={`insight-card-${insight.id}`}
        role="button"
        tabindex="0"
        onclick={() => (selectedInsight = insight)}
        onkeydown={(event) => { if (event.key === "Enter" || event.key === " ") selectedInsight = insight }}
      >
        <CardHeader class="border-b border-border">
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <Badge variant="outline">{insight.kind_label}</Badge>
              <CardTitle class="mt-3 text-base leading-6">{insight.title}</CardTitle>
            </div>
            <Badge variant={badgeVariant(insight.severity)}>{insight.severity}</Badge>
          </div>
        </CardHeader>
        <CardContent class="grid gap-4">
          <div class="grid grid-cols-2 gap-3 rounded-lg border border-border bg-background p-3">
            <div>
              <p class="text-xs font-medium text-muted-foreground">{insight.metric?.label}</p>
              <p class="money-value mt-1 text-xl font-semibold text-foreground">{insight.metric?.value}</p>
            </div>
            <div class="border-l border-border pl-3">
              <p class="text-xs font-medium text-muted-foreground">{insight.metric?.comparison_label}</p>
              <p class="money-value mt-1 text-sm font-semibold text-foreground">{insight.metric?.comparison_value}</p>
              {#if insight.metric?.delta}
                <p class="mt-1 text-xs text-muted-foreground">Difference {insight.metric.delta}</p>
              {/if}
            </div>
          </div>
          <p class="text-sm leading-6 text-muted-foreground">{insight.body}</p>
          <div class="rounded-lg bg-muted/60 px-3 py-2 text-sm leading-6 text-foreground">
            <span class="font-semibold">Next:</span> {insight.action}
          </div>
          <div class="flex flex-wrap items-center gap-2 text-xs font-medium text-muted-foreground">
            <Badge variant={insight.generation_source === "ai" ? "success" : "secondary"}>{insight.generation_source_label}</Badge>
            {#if insight.transactions?.length}
              <Badge variant="outline">{insight.transactions.length} evidence transaction{insight.transactions.length === 1 ? "" : "s"}</Badge>
            {/if}
            <span class="ml-auto">Review details</span>
          </div>
        </CardContent>
      </Card>
    {/each}
  </div>
{:else}
  <Card>
    <CardContent class="grid place-items-center gap-3 px-4 py-14 text-center">
      <span class="grid size-10 place-items-center rounded-lg bg-muted text-muted-foreground"><Lightbulb class="size-5" /></span>
      <div>
        <p class="font-semibold text-foreground">No meaningful changes yet</p>
        <p class="mt-1 max-w-xl text-sm leading-6 text-muted-foreground">More month-to-month history is needed before the app can identify a baseline shift, unusual purchase, recurring commitment, or budget risk.</p>
      </div>
    </CardContent>
  </Card>
{/if}

{#if selectedInsight}
  <div class="fixed inset-0 z-50 grid place-items-center bg-background/80 p-4 backdrop-blur-sm" role="dialog" aria-modal="true" aria-label={selectedInsight.title} tabindex="-1" onclick={() => (selectedInsight = null)} onkeydown={(event) => { if (event.key === "Escape") selectedInsight = null }}>
    <Card class="max-h-[92vh] w-full max-w-4xl overflow-hidden" onclick={(event) => event.stopPropagation()}>
      <CardHeader class="border-b border-border">
        <div class="flex items-start gap-3">
          <span class="grid size-9 shrink-0 place-items-center rounded-lg bg-accent text-accent-foreground"><Lightbulb class="size-4" /></span>
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap gap-2">
              <Badge variant="outline">{selectedInsight.kind_label}</Badge>
              <Badge variant={badgeVariant(selectedInsight.severity)}>{selectedInsight.severity}</Badge>
            </div>
            <CardTitle class="mt-3 text-lg">{selectedInsight.title}</CardTitle>
            <p class="mt-2 text-sm leading-6 text-muted-foreground">{selectedInsight.body}</p>
          </div>
          <Button type="button" variant="ghost" size="icon" aria-label="Close" onclick={() => (selectedInsight = null)}><X class="size-4" /></Button>
        </div>
      </CardHeader>
      <CardContent class="max-h-[65vh] overflow-y-auto">
        <div class="mb-4 grid gap-3 rounded-lg border border-border bg-background p-3 sm:grid-cols-2">
          <div>
            <p class="text-xs font-medium text-muted-foreground">{selectedInsight.metric?.label}</p>
            <p class="money-display mt-1 text-2xl font-semibold text-foreground">{selectedInsight.metric?.value}</p>
          </div>
          <div>
            <p class="text-xs font-medium text-muted-foreground">{selectedInsight.metric?.comparison_label}</p>
            <p class="money-value mt-1 text-lg font-semibold text-foreground">{selectedInsight.metric?.comparison_value}</p>
          </div>
        </div>
        <div class="mb-5 rounded-lg bg-muted px-3 py-3 text-sm leading-6 text-foreground"><span class="font-semibold">Recommended next step:</span> {selectedInsight.action}</div>

        <div class="mb-3 flex items-center justify-between gap-3">
          <h2 class="text-sm font-semibold text-foreground">Supporting transactions</h2>
          <Button href={selectedInsight.evidence_path} variant="outline" size="sm">View all evidence</Button>
        </div>
        {#if selectedInsight.transactions?.length}
          <div class="grid gap-2">
            {#each selectedInsight.transactions as transaction (transaction.id)}
              <div class="grid gap-2 rounded-lg border border-border bg-background px-3 py-2 text-sm md:grid-cols-[8rem_minmax(0,1fr)_8rem_auto] md:items-center">
                <div class="text-xs font-medium text-muted-foreground">{transaction.occurred_on_label}</div>
                <div class="min-w-0">
                  <p class="truncate font-medium text-foreground">{transaction.merchant_name || transaction.description}</p>
                  <p class="mt-1 truncate text-xs text-muted-foreground">{transaction.category?.name || "Unclassified"}</p>
                </div>
                <p class={`money-value text-right font-semibold ${transaction.amount_class}`}>{transaction.amount_label}</p>
                <Button href={transaction.view_path} variant="ghost" size="sm">Open</Button>
              </div>
            {/each}
          </div>
        {:else}
          <p class="text-sm text-muted-foreground">This finding is based on an aggregate comparison. Use the evidence filter to review the underlying period.</p>
        {/if}
      </CardContent>
    </Card>
  </div>
{/if}
