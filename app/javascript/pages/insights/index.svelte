<script>
  import { router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { badgeVariant } from "$lib/formatters"
  import Lightbulb from "@lucide/svelte/icons/lightbulb"
  import RefreshCcw from "@lucide/svelte/icons/refresh-ccw"

  export let insights = []
  export let actions
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
      <Card>
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
          <p class="mt-4 text-xs font-medium text-muted-foreground">{insight.starts_on} to {insight.ends_on}</p>
        </CardContent>
      </Card>
    {/each}
  </div>
