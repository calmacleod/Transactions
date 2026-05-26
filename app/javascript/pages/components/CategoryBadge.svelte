<script>
  import { Badge } from "$lib/components/ui/badge"

  export let category = null
</script>

{#if category && category.id}
  <Badge variant="outline" class="gap-1.5">
    <span class="size-2 rounded-full" style={`background-color: ${category.color || "#52525b"}`}></span>
    {category.name}
  </Badge>
{:else}
  <Badge variant="secondary">Unclassified</Badge>
{/if}
