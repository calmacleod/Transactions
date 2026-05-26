<script>
  import { router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { badgeVariant } from "$lib/formatters"
  import Lightbulb from "@lucide/svelte/icons/lightbulb"
  import RefreshCcw from "@lucide/svelte/icons/refresh-ccw"
  import X from "@lucide/svelte/icons/x"

  export let insights = []
  export let actions

  let selectedInsight = null
</script>

  <section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
    <div>
      <p class="text-xs font-semibold uppercase tracking-wider text-primary">Recent analysis</p>
      <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">Insights</h1>
      <p class="mt-2 text-sm text-muted-foreground">Month-to-month observations generated from imported transactions.</p>
    </div>
    <Button onclick={() => router.post(actions.regenerate)}>
      <RefreshCcw class="size-4" />
      Regenerate
    </Button>
  </section>

  <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
    {#each insights as insight}
      <Card class="cursor-pointer transition-colors hover:border-primary/40" onclick={() => (selectedInsight = insight)}>
        <CardHeader>
          <div class="flex items-start justify-between gap-4">
            <span class="grid size-9 place-items-center rounded-lg bg-accent text-accent-foreground">
              <Lightbulb class="size-4" />
            </span>
            <Badge variant={badgeVariant(insight.severity)}>{insight.severity}</Badge>
          </div>
          <CardTitle class="text-base">{insight.title}</CardTitle>
        </CardHeader>
        <CardContent>
          <p class="text-sm leading-6 text-muted-foreground">{insight.body}</p>
          <div class="mt-4 flex flex-wrap items-center gap-2 text-xs font-medium text-muted-foreground">
            <span>{insight.starts_on} to {insight.ends_on}</span>
            <Badge variant={insight.generation_source === "ai" ? "success" : "secondary"}>{insight.generation_source_label}</Badge>
            {#if insight.transactions?.length}
              <Badge variant="outline">{insight.transactions.length} linked</Badge>
            {/if}
          </div>
        </CardContent>
      </Card>
    {/each}
  </div>

  {#if selectedInsight}
    <div class="fixed inset-0 z-50 grid place-items-center bg-background/80 p-4 backdrop-blur-sm" role="dialog" aria-modal="true" aria-label={selectedInsight.title} tabindex="-1" onclick={() => (selectedInsight = null)} onkeydown={(event) => { if (event.key === "Escape") selectedInsight = null }}>
      <Card class="max-h-[90vh] w-full max-w-3xl overflow-hidden" onclick={(event) => event.stopPropagation()}>
        <CardHeader class="border-b border-border">
          <div class="flex items-start gap-3">
            <span class="grid size-9 shrink-0 place-items-center rounded-lg bg-accent text-accent-foreground">
              <Lightbulb class="size-4" />
            </span>
            <div class="min-w-0 flex-1">
              <CardTitle class="text-base">{selectedInsight.title}</CardTitle>
              <p class="mt-2 text-sm leading-6 text-muted-foreground">{selectedInsight.body}</p>
            </div>
            <Button type="button" variant="ghost" size="icon" aria-label="Close" onclick={() => (selectedInsight = null)}>
              <X class="size-4" />
            </Button>
          </div>
        </CardHeader>
        <CardContent class="max-h-[60vh] overflow-y-auto">
          {#if selectedInsight.transactions?.length}
            <div class="grid gap-2">
              {#each selectedInsight.transactions as transaction}
                <div class="grid gap-2 rounded-lg border border-border px-3 py-2 text-sm md:grid-cols-[8rem_minmax(0,1fr)_9rem] md:items-center">
                  <div class="text-xs font-medium text-muted-foreground">{transaction.occurred_on_label}</div>
                  <div class="min-w-0">
                    <p class="truncate font-medium text-foreground">{transaction.merchant_name || transaction.description}</p>
                    <p class="mt-1 truncate text-xs text-muted-foreground">{transaction.category?.name || "Unclassified"}</p>
                  </div>
                  <p class={`money-value text-right font-semibold ${transaction.amount_class}`}>{transaction.amount_label}</p>
                </div>
              {/each}
            </div>
          {:else}
            <p class="text-sm text-muted-foreground">No specific transactions were linked to this insight.</p>
          {/if}
        </CardContent>
      </Card>
    </div>
  {/if}
