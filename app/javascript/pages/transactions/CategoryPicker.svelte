<script>
  import { tick } from "svelte"
  import { NativeSelect, NativeSelectOption } from "$lib/components/ui/native-select"
  import ChevronDown from "@lucide/svelte/icons/chevron-down"

  export let categories = []
  export let transaction
  export let className = ""
  export let selectClass = ""
  export let onChange = () => {}

  let editing = false
  let selectRef = null

  $: selectedCategory = transaction.category || categories.find((category) => category.id === transaction.category_id) || { id: null, name: "Unclassified" }
  $: selectedValue = transaction.category_id || ""

  async function startEditing() {
    if (editing) return

    editing = true
    await tick()
    selectRef?.focus()
    try {
      selectRef?.showPicker?.()
    } catch (_error) {
      // Browser support and user-activation rules vary; focus still lands on the select.
    }
  }

  function stopEditing() {
    window.setTimeout(() => (editing = false), 0)
  }

  function handleChange(event) {
    onChange(transaction, event.currentTarget.value)
    editing = false
  }
</script>

{#if editing}
  <NativeSelect
    bind:ref={selectRef}
    value={selectedValue}
    class={selectClass}
    onchange={handleChange}
    onblur={stopEditing}
    aria-label={`Change category for ${transaction.description}`}
  >
    <NativeSelectOption value="">Unclassified</NativeSelectOption>
    {#each categories as category}
      <NativeSelectOption value={category.id}>{category.name}</NativeSelectOption>
    {/each}
  </NativeSelect>
{:else}
  <button
    type="button"
    class={`inline-flex h-8 min-w-0 items-center justify-between gap-2 rounded-lg border border-input bg-background px-2.5 text-left text-sm text-foreground transition-colors hover:bg-muted focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 outline-none ${className}`}
    draggable="false"
    onclick={startEditing}
    onkeydown={(event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault()
        startEditing()
      }
    }}
    aria-label={`Change category for ${transaction.description}`}
  >
    <span class="min-w-0 truncate">{selectedCategory.name}</span>
    <ChevronDown class="size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
  </button>
{/if}
