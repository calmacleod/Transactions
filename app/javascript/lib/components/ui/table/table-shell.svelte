<script>
  import { cn } from "$lib/utils"

  let className = ""
  export { className as class }
</script>

<div class={cn("w-full overflow-x-auto", className)} {...$$restProps}>
  <slot />
</div>
