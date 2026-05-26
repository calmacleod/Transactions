<script>
  import { router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Input } from "$lib/components/ui/input"
  import { Label } from "$lib/components/ui/label"
  import X from "@lucide/svelte/icons/x"

  export let subcategories = []
  export let actions

  let name = ""
  let color = "#71717a"

  function createSubcategory() {
    if (!name.trim()) return
    router.post(actions.create, { transaction_subcategory: { name, color } }, { preserveScroll: true })
    name = ""
  }

  function destroySubcategory(subcategory) {
    router.delete(subcategory.destroy_path, { preserveScroll: true })
  }
</script>

<section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
  <div>
    <p class="text-xs font-semibold uppercase tracking-wider text-primary">Transaction labels</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">Subcategories</h1>
    <p class="mt-2 text-sm text-muted-foreground">Manage reusable subcategory chips for transactions.</p>
  </div>
</section>

<Card class="mb-4">
  <CardHeader class="border-b border-border">
    <CardTitle class="text-sm">Add subcategory</CardTitle>
  </CardHeader>
  <CardContent>
    <form class="flex flex-col gap-3 sm:flex-row sm:items-end" on:submit|preventDefault={createSubcategory}>
      <div class="min-w-0 flex-1 space-y-1.5">
        <Label for="subcategory-name">Name</Label>
        <Input id="subcategory-name" bind:value={name} placeholder="Gift" />
      </div>
      <div class="space-y-1.5">
        <Label for="subcategory-color">Color</Label>
        <Input id="subcategory-color" type="color" bind:value={color} class="h-8 w-16 p-1" />
      </div>
      <Button type="submit">Add</Button>
    </form>
  </CardContent>
</Card>

<Card>
  <CardHeader class="border-b border-border">
    <CardTitle class="text-sm">Available chips</CardTitle>
  </CardHeader>
  <CardContent>
    <div class="flex flex-wrap gap-2">
      {#each subcategories as subcategory}
        <Badge variant="outline" class="h-7 gap-1.5 pl-2 pr-1">
          <span class="size-2 rounded-full" style={`background-color: ${subcategory.color}`}></span>
          {subcategory.name}
          <button type="button" class="rounded-full p-0.5 text-muted-foreground hover:bg-muted hover:text-foreground" aria-label={`Delete ${subcategory.name}`} on:click={() => destroySubcategory(subcategory)}>
            <X class="size-3" />
          </button>
        </Badge>
      {/each}
    </div>
  </CardContent>
</Card>
