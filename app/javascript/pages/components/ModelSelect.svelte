<script>
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import ChevronDown from "@lucide/svelte/icons/chevron-down"

  export let id
  export let label
  export let value = ""
  export let models = []

  let open = false

  $: selectedModel = models.find((model) => model.model_id === value)

  function selectModel(model) {
    value = model.model_id
    open = false
  }
</script>

<div class="relative space-y-1.5">
  {#if label}
    <label for={id} class="text-sm leading-none font-medium">{label}</label>
  {/if}
  <Button id={id} type="button" variant="outline" class="h-auto min-h-11 w-full justify-between gap-3 px-3 py-2 text-left" onclick={() => (open = !open)} aria-expanded={open} aria-haspopup="listbox">
    <span class="min-w-0">
      {#if selectedModel}
        <span class="block truncate text-sm font-medium text-foreground">{selectedModel.name}</span>
        <span class="mt-0.5 block truncate font-mono text-xs text-muted-foreground">{selectedModel.model_id}</span>
      {:else}
        <span class="block text-sm font-medium text-muted-foreground">Choose a model</span>
      {/if}
    </span>
    <ChevronDown class="size-4 shrink-0 text-muted-foreground" />
  </Button>

  {#if open}
    <div class="absolute z-30 mt-1 max-h-96 w-full overflow-auto rounded-lg border border-border bg-popover p-1 shadow-lg" role="listbox" aria-labelledby={id}>
      {#each models as model}
        <button type="button" class={`w-full rounded-md px-3 py-2 text-left hover:bg-muted ${model.model_id === value ? "bg-muted" : ""}`} role="option" aria-selected={model.model_id === value} onclick={() => selectModel(model)}>
          <span class="block text-sm font-semibold text-foreground">{model.name}</span>
          <span class="mt-0.5 block font-mono text-xs text-muted-foreground">{model.model_id}</span>
          <span class="mt-2 flex flex-wrap gap-1">
            <Badge variant="secondary">{model.provider}</Badge>
            {#if model.context_window_label}
              <Badge variant="secondary">{model.context_window_label} ctx</Badge>
            {/if}
            {#each model.capabilities.slice(0, 4) as capability}
              <Badge variant="secondary">{capability.replaceAll("_", " ")}</Badge>
            {/each}
          </span>
          <span class="money-value mt-2 block text-xs text-muted-foreground">{model.price_label} per 1M input/output tokens</span>
        </button>
      {:else}
        <p class="px-3 py-2 text-sm text-muted-foreground">No models are available yet.</p>
      {/each}
    </div>
  {/if}
</div>
