<script>
  import { onMount } from "svelte"
  import { router } from "@inertiajs/svelte"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Progress } from "$lib/components/ui/progress"

  export let run = null

  let current = run
  let timer

  $: current = run || current

  function refresh() {
    if (!current?.active) return

    fetch(current.show_path, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then((payload) => {
        current = payload.classification_run
        if (!current?.active && timer) window.clearInterval(timer)
      })
  }

  onMount(() => {
    if (current?.active) timer = window.setInterval(refresh, 2000)
    return () => {
      if (timer) window.clearInterval(timer)
    }
  })
</script>

{#if current}
  <Card class="mb-4">
    <CardHeader class="border-b border-border">
      <div>
        <CardTitle class="text-sm">Classification</CardTitle>
        <p class="mt-1 text-sm text-muted-foreground">{current.status_label}</p>
      </div>

      <div class="flex flex-wrap gap-2">
        {#if current.cancellable}
          <Button variant="outline" size="sm" onclick={() => router.patch(current.cancel_path)}>Stop</Button>
        {/if}
        <Button variant="outline" size="sm" onclick={() => router.patch(current.dismiss_path)}>Dismiss</Button>
      </div>
    </CardHeader>

    <CardContent class="grid gap-3">
      <Progress value={current.progress_percent} class="h-2" />

      <div class="flex flex-wrap gap-2 text-xs text-muted-foreground sm:gap-4">
        <span><strong>{current.processed_count}</strong> / {current.total_count} processed</span>
        <span><strong>{current.classified_count}</strong> classified</span>
        <span><strong>{current.rule_based_count}</strong> fast pass</span>
        {#if current.failed_count > 0}
          <span><strong>{current.failed_count}</strong> failed</span>
        {/if}
      </div>

      {#if current.notes}
        <p class="text-xs text-destructive">{current.notes}</p>
      {/if}
    </CardContent>
  </Card>
{/if}
