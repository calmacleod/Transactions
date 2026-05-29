<script>
  import { router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import ModelSelect from "../components/ModelSelect.svelte"

  export let selected_model
  export let selectable_models = []
  export let usage
  export let recent_requests = []
  export let actions

  let preferred_ai_model = selected_model

  function save() {
    router.patch(actions.update, { user: { preferred_ai_model } }, { preserveScroll: true, preserveState: true })
  }
</script>

<svelte:head>
  <title>AI Settings - Transactions</title>
</svelte:head>

<div class="mx-auto max-w-4xl space-y-6">
  <div>
    <p class="text-sm font-semibold uppercase text-primary">AI settings</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-normal text-foreground">Your AI usage</h1>
    <p class="mt-2 text-sm leading-6 text-muted-foreground">Choose from the models made available by an admin and monitor your usage.</p>
  </div>

  <section class="grid gap-3 sm:grid-cols-3">
    <Card>
      <CardHeader>
        <p class="text-xs font-medium uppercase text-muted-foreground">Requests this month</p>
        <CardTitle class="text-2xl">{usage.month_count}</CardTitle>
      </CardHeader>
    </Card>
    <Card>
      <CardHeader>
        <p class="text-xs font-medium uppercase text-muted-foreground">Remaining</p>
        <CardTitle class="text-2xl">{usage.remaining_requests === null ? "Unlimited" : usage.remaining_requests}</CardTitle>
      </CardHeader>
    </Card>
    <Card>
      <CardHeader>
        <p class="text-xs font-medium uppercase text-muted-foreground">Estimated cost</p>
        <CardTitle class="money-value text-2xl">{usage.estimated_cost_label}</CardTitle>
      </CardHeader>
    </Card>
  </section>

  <Card>
    <CardHeader>
      <CardTitle class="text-lg">Model</CardTitle>
    </CardHeader>
    <CardContent>
      <form class="space-y-4" on:submit|preventDefault={save}>
        <ModelSelect id="preferred-ai-model" label="Preferred model" bind:value={preferred_ai_model} models={selectable_models} />
        {#if !selectable_models.length}
          <p class="text-sm text-muted-foreground">No user-selectable models are configured yet.</p>
        {/if}
        <Button type="submit" disabled={!selectable_models.length}>Save AI settings</Button>
      </form>
    </CardContent>
  </Card>

  <Card>
    <CardHeader>
      <CardTitle class="text-lg">Recent AI requests</CardTitle>
    </CardHeader>
    <CardContent class="grid gap-2">
      {#each recent_requests as request}
        <div class="grid gap-2 rounded-lg border border-border bg-background px-3 py-2 text-sm sm:grid-cols-[8rem_minmax(0,1fr)_7rem_6rem] sm:items-center">
          <div>
            <p class="font-semibold capitalize text-foreground">{request.feature}</p>
            <p class="text-xs text-muted-foreground">{request.created_at_label}</p>
          </div>
          <p class="min-w-0 truncate text-muted-foreground">{request.model || "No model recorded"}</p>
          <p class="money-value text-muted-foreground">{request.estimated_cost_label}</p>
          <Badge variant={request.successful ? "success" : "destructive"}>{request.successful ? "success" : "failed"}</Badge>
        </div>
      {:else}
        <p class="text-sm text-muted-foreground">No AI requests have been logged yet.</p>
      {/each}
    </CardContent>
  </Card>
</div>
