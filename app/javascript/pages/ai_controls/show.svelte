<script>
  import { router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Input } from "$lib/components/ui/input"
  import { Label } from "$lib/components/ui/label"
  import { NativeSelect, NativeSelectOption } from "$lib/components/ui/native-select"

  export let settings
  export let provider_status
  export let usage
  export let feature_statuses = []
  export let recent_requests = []
  export let actions

  let form = { ...settings }

  function save() {
    router.patch(actions.update, { ai_settings: form })
  }
</script>

<section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
  <div>
    <p class="text-xs font-semibold uppercase tracking-wider text-primary">AI visibility</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">AI controls</h1>
    <p class="mt-2 text-sm text-muted-foreground">Provider status, feature toggles, request limits, and recent AI usage.</p>
  </div>
  <Badge variant={provider_status.configured ? "success" : "warning"}>{provider_status.configured ? "Provider configured" : "No provider key"}</Badge>
</section>

<section class="mb-4 grid gap-4 xl:grid-cols-[minmax(0,0.45fr)_minmax(0,0.55fr)]">
  <Card>
    <CardHeader class="border-b border-border">
      <CardTitle class="text-sm">Controls</CardTitle>
    </CardHeader>
    <CardContent>
      <form class="grid gap-4" on:submit|preventDefault={save}>
        <div class="space-y-1.5">
          <Label for="ai-model">Model</Label>
          <Input id="ai-model" bind:value={form.model} placeholder="gpt-5-nano" />
        </div>
        <div class="grid gap-3 sm:grid-cols-3">
          <div class="space-y-1.5">
            <Label for="classification-enabled">Classification</Label>
            <NativeSelect id="classification-enabled" bind:value={form.classification_enabled}>
              <NativeSelectOption value="true">Enabled</NativeSelectOption>
              <NativeSelectOption value="false">Disabled</NativeSelectOption>
            </NativeSelect>
          </div>
          <div class="space-y-1.5">
            <Label for="insights-enabled">Insights</Label>
            <NativeSelect id="insights-enabled" bind:value={form.insights_enabled}>
              <NativeSelectOption value="true">Enabled</NativeSelectOption>
              <NativeSelectOption value="false">Disabled</NativeSelectOption>
            </NativeSelect>
          </div>
          <div class="space-y-1.5">
            <Label for="chat-enabled">Chat</Label>
            <NativeSelect id="chat-enabled" bind:value={form.chat_enabled}>
              <NativeSelectOption value="true">Enabled</NativeSelectOption>
              <NativeSelectOption value="false">Disabled</NativeSelectOption>
            </NativeSelect>
          </div>
        </div>
        <div class="space-y-1.5">
          <Label for="monthly-request-limit">Monthly request limit</Label>
          <Input id="monthly-request-limit" type="number" min="0" bind:value={form.monthly_request_limit} />
          <p class="text-xs text-muted-foreground">Use 0 for no app-level request cap.</p>
        </div>
        <Button type="submit">Save controls</Button>
      </form>
    </CardContent>
  </Card>

  <Card>
    <CardHeader class="border-b border-border">
      <CardTitle class="text-sm">Visibility</CardTitle>
    </CardHeader>
    <CardContent class="grid gap-4">
      <div class="grid gap-3 sm:grid-cols-3">
        <div class="rounded-lg border border-border p-3">
          <p class="text-xs text-muted-foreground">Requests this month</p>
          <p class="mt-1 text-2xl font-semibold text-foreground">{usage.month_count}</p>
        </div>
        <div class="rounded-lg border border-border p-3">
          <p class="text-xs text-muted-foreground">Successful</p>
          <p class="mt-1 text-2xl font-semibold text-foreground">{usage.month_success_count}</p>
        </div>
        <div class="rounded-lg border border-border p-3">
          <p class="text-xs text-muted-foreground">Remaining</p>
          <p class="mt-1 text-2xl font-semibold text-foreground">{usage.remaining_requests === null ? "Unlimited" : usage.remaining_requests}</p>
        </div>
      </div>
      <div class="rounded-lg border border-border p-3">
        <p class="text-xs text-muted-foreground">Estimated AI cost this month</p>
        <p class="money-value mt-1 text-2xl font-semibold text-foreground">{usage.estimated_cost_label}</p>
      </div>

      <div class="grid gap-2">
        {#each feature_statuses as feature}
          <div class="flex items-center justify-between gap-3 rounded-lg border border-border px-3 py-2">
            <div>
              <p class="text-sm font-semibold capitalize text-foreground">{feature.feature}</p>
              <p class="text-xs text-muted-foreground">{feature.request_count} request{feature.request_count === 1 ? "" : "s"} this month</p>
            </div>
            <Badge variant={feature.enabled ? "success" : "secondary"}>{feature.enabled ? "active" : "inactive"}</Badge>
          </div>
        {/each}
      </div>

      <div class="flex flex-wrap gap-2">
        <Badge variant={provider_status.openai ? "success" : "secondary"}>OpenAI</Badge>
        <Badge variant={provider_status.anthropic ? "success" : "secondary"}>Anthropic</Badge>
        <Badge variant={provider_status.gemini ? "success" : "secondary"}>Gemini</Badge>
      </div>
    </CardContent>
  </Card>
</section>

<Card>
  <CardHeader class="border-b border-border">
    <CardTitle class="text-sm">Recent AI requests</CardTitle>
  </CardHeader>
  <CardContent class="grid gap-2">
    {#if recent_requests.length}
      {#each recent_requests as request}
        <div class="grid gap-2 rounded-lg border border-border px-3 py-2 text-sm md:grid-cols-[9rem_minmax(0,1fr)_8rem_8rem_8rem] md:items-center">
          <div>
            <p class="font-semibold capitalize text-foreground">{request.feature}</p>
            <p class="text-xs text-muted-foreground">{request.created_at_label}</p>
          </div>
          <p class="min-w-0 truncate text-muted-foreground">{request.error_message || request.model || "No model recorded"}</p>
          <p class="text-xs text-muted-foreground">in {request.input_tokens || 0} / out {request.output_tokens || 0}</p>
          <p class="money-value text-xs font-medium text-muted-foreground">{request.estimated_cost_label}</p>
          <Badge variant={request.successful ? "success" : "destructive"}>{request.successful ? "success" : "failed"}</Badge>
        </div>
      {/each}
    {:else}
      <p class="text-sm text-muted-foreground">No AI requests have been logged yet.</p>
    {/if}
  </CardContent>
</Card>
