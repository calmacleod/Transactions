<script>
  import { router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Input } from "$lib/components/ui/input"
  import { Label } from "$lib/components/ui/label"
  import { Progress } from "$lib/components/ui/progress"
  import { withQuery } from "$lib/formatters"

  export let month
  export let categories = []
  export let unclassified
  export let actions

  let selectedMonth = month.value

  function updateBudget(category, value) {
    router.patch(category.update_path, { category: { monthly_budget: value } }, { preserveScroll: true, preserveState: true })
  }
</script>

<section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
  <div>
    <p class="text-xs font-semibold uppercase tracking-wider text-primary">Budget controls</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">Category budgets</h1>
    <p class="mt-2 text-sm text-muted-foreground">Set monthly targets and compare them against actual spending.</p>
  </div>
  <form class="flex w-full flex-wrap items-end gap-2 sm:w-auto" on:submit|preventDefault={() => router.get(withQuery(actions.index, { month: selectedMonth }), {}, { preserveScroll: true })}>
    <div class="min-w-0 flex-1 space-y-1.5 sm:w-44 sm:flex-none">
      <Label for="budget-month">Month</Label>
      <Input id="budget-month" type="month" bind:value={selectedMonth} class="w-full" />
    </div>
    <Button type="submit">View</Button>
  </form>
</section>

<Card class="mb-4">
  <CardHeader class="border-b border-border">
    <CardTitle class="text-sm">{month.label}</CardTitle>
  </CardHeader>
  <CardContent class="grid gap-3">
    {#each categories as category}
      <div class="grid min-w-0 gap-3 rounded-lg border border-border p-3 xl:grid-cols-[minmax(0,1fr)_minmax(8rem,12rem)_minmax(0,12rem)] xl:items-center">
        <a href={category.filters_path} class="min-w-0">
          <div class="flex items-center gap-2">
            <span class="size-2.5 rounded-sm" style={`background-color: ${category.color}`}></span>
            <p class="truncate text-sm font-semibold text-foreground">{category.name}</p>
            {#if category.remaining_cents < 0}
              <Badge variant="destructive">over</Badge>
            {/if}
          </div>
          <div class="mt-2 flex items-center gap-3">
            <Progress value={category.used_percent} class="h-2" />
            <span class="w-12 text-right text-xs font-medium text-muted-foreground">{category.used_percent}%</span>
          </div>
          <p class="mt-1 text-xs text-muted-foreground">{category.spent_label} spent, {category.remaining_label} remaining</p>
        </a>

        <div class="min-w-0 text-sm xl:text-right">
          <p class="font-semibold text-foreground">{category.budget_label}</p>
          <p class="text-xs text-muted-foreground">monthly target</p>
        </div>

        <form class="flex min-w-0 flex-wrap items-end gap-2 xl:justify-end" on:submit|preventDefault={(event) => updateBudget(category, event.currentTarget.monthly_budget.value)}>
          <div class="min-w-0 flex-1 space-y-1.5 sm:max-w-32 xl:flex-none">
            <Label for={`budget-${category.id}`} class="sr-only">Budget</Label>
            <Input id={`budget-${category.id}`} name="monthly_budget" type="number" step="0.01" min="0" value={category.monthly_budget} class="w-full" />
          </div>
          <Button type="submit" variant="outline" class="shrink-0">Save</Button>
        </form>
      </div>
    {/each}
  </CardContent>
</Card>

<Card>
  <CardContent>
    <a href={unclassified.filters_path} class="flex flex-col gap-1 text-sm sm:flex-row sm:items-center sm:justify-between">
      <span class="font-semibold text-foreground">{unclassified.name}</span>
      <span class="money-value font-semibold text-foreground">{unclassified.spent_label}</span>
    </a>
  </CardContent>
</Card>
