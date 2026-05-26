<script>
  import { router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Input } from "$lib/components/ui/input"
  import { Label } from "$lib/components/ui/label"
  import { NativeSelect, NativeSelectOption } from "$lib/components/ui/native-select"
  import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "$lib/components/ui/table"
  import Layout from "../Layout.svelte"
  import Braces from "@lucide/svelte/icons/braces"
  import Eye from "@lucide/svelte/icons/eye"
  import RefreshCcw from "@lucide/svelte/icons/refresh-ccw"
  import Server from "@lucide/svelte/icons/server"
  import Sparkles from "@lucide/svelte/icons/sparkles"

  export let stats
  export let providers = []
  export let models = []
  export let filters = {}
  export let capped = false
  export let actions

  let form = { ...filters }

  $: statCards = [
    { label: "Available models", value: stats.available_models, icon: Sparkles },
    { label: "Providers", value: stats.providers, icon: Server },
    { label: "Structured output", value: stats.structured_output, icon: Braces },
    { label: "Vision", value: stats.vision, icon: Eye },
  ]

  function applyFilters() {
    router.get(actions.index, Object.fromEntries(Object.entries(form).filter(([, value]) => value)))
  }
</script>

<Layout>
  <section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
    <div>
      <p class="text-xs font-semibold uppercase tracking-wider text-primary">RubyLLM registry</p>
      <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">Models</h1>
      <p class="mt-2 text-sm text-muted-foreground">Browse imported provider metadata, capabilities, context windows, and pricing.</p>
    </div>

    <Button onclick={() => router.post(actions.refresh)}>
      <RefreshCcw class="size-4" />
      Refresh models
    </Button>
  </section>

  <section class="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
    {#each statCards as stat}
      <Card>
        <CardContent>
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{stat.label}</p>
              <p class="mt-2 text-2xl font-semibold tracking-tight text-foreground">{stat.value}</p>
            </div>
            <span class="grid size-9 place-items-center rounded-lg bg-accent text-accent-foreground">
              <svelte:component this={stat.icon} class="size-4" />
            </span>
          </div>
        </CardContent>
      </Card>
    {/each}
  </section>

  <Card class="mb-4">
    <CardContent>
      <form class="grid gap-3 md:grid-cols-[1fr_220px_220px_auto]" on:submit|preventDefault={applyFilters}>
        <div class="space-y-1.5">
          <Label for="query">Search</Label>
          <Input id="query" type="search" bind:value={form.query} placeholder="Model, family, or ID" />
        </div>
        <div class="space-y-1.5">
          <Label for="provider">Provider</Label>
          <NativeSelect id="provider" bind:value={form.provider} class="w-full">
            <NativeSelectOption value="">All providers</NativeSelectOption>
            {#each providers as provider}
              <NativeSelectOption value={provider.name}>{provider.name} ({provider.count})</NativeSelectOption>
            {/each}
          </NativeSelect>
        </div>
        <div class="space-y-1.5">
          <Label for="capability">Capability</Label>
          <NativeSelect id="capability" bind:value={form.capability} class="w-full">
            <NativeSelectOption value="">All capabilities</NativeSelectOption>
            <NativeSelectOption value="structured_output">Structured output</NativeSelectOption>
            <NativeSelectOption value="function_calling">Function calling</NativeSelectOption>
            <NativeSelectOption value="vision">Vision</NativeSelectOption>
            <NativeSelectOption value="reasoning">Reasoning</NativeSelectOption>
          </NativeSelect>
        </div>
        <div class="flex items-end gap-2">
          <Button type="submit">Filter</Button>
          <Button type="button" variant="outline" onclick={() => router.get(actions.index)}>Clear</Button>
        </div>
      </form>
    </CardContent>
  </Card>

  <Card>
    <CardHeader class="border-b border-border">
      <CardTitle class="text-sm">Model catalog</CardTitle>
    </CardHeader>
    <div class="overflow-x-auto">
      <Table class="min-w-[70rem]">
        <TableHeader>
          <TableRow>
            <TableHead>Model</TableHead>
            <TableHead>Provider</TableHead>
            <TableHead>I/O</TableHead>
            <TableHead>Capabilities</TableHead>
            <TableHead class="text-right">Context</TableHead>
            <TableHead class="text-right">Input / Output</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {#each models as model}
            <TableRow>
              <TableCell>
                <p class="font-semibold text-foreground">{model.name}</p>
                <p class="mt-1 font-mono text-xs text-muted-foreground">{model.model_id}</p>
                {#if model.family}<p class="mt-1 text-xs text-muted-foreground">{model.family}</p>{/if}
              </TableCell>
              <TableCell class="whitespace-nowrap text-muted-foreground">{model.provider}</TableCell>
              <TableCell class="text-xs text-muted-foreground">
                <p>In: {model.input_modalities.join(", ")}</p>
                <p class="mt-1">Out: {model.output_modalities.join(", ")}</p>
              </TableCell>
              <TableCell class="max-w-xs">
                <div class="flex flex-wrap gap-1.5">
                  {#each model.capabilities as capability}
                    <Badge variant="secondary">{capability.replaceAll("_", " ")}</Badge>
                  {/each}
                </div>
              </TableCell>
              <TableCell class="whitespace-nowrap text-right text-muted-foreground">{model.context_window_label || ""}</TableCell>
              <TableCell class="money-value text-right text-muted-foreground">{model.price_label}</TableCell>
            </TableRow>
          {/each}
        </TableBody>
      </Table>
    </div>
  </Card>

  {#if capped}
    <p class="mt-4 text-sm text-muted-foreground">Showing the first 250 matching models. Narrow the filters to inspect a smaller set.</p>
  {/if}
</Layout>
