<script>
  import { Link } from "@inertiajs/svelte"
  import ChevronRight from "@lucide/svelte/icons/chevron-right"

  export let items = []
</script>

<nav class="mb-4 flex flex-wrap items-center gap-1 text-sm text-muted-foreground" aria-label="Breadcrumb">
  {#each items as item, index}
    {#if index > 0}
      <ChevronRight class="size-4" aria-hidden="true" />
    {/if}

    {#if item.href && index < items.length - 1}
      <Link href={item.href} class="font-medium hover:text-foreground">{item.label}</Link>
    {:else}
      <span class="font-medium text-foreground" aria-current="page">{item.label}</span>
    {/if}
  {/each}
</nav>
