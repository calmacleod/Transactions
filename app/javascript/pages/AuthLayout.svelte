<script>
  import { usePage } from "@inertiajs/svelte"

  const page = usePage()
  $: flash = page.props.flash || {}
</script>

<main class="min-h-screen px-4 py-8 text-foreground sm:px-6" data-app-chrome data-auth-shell>
  <div class="mx-auto flex min-h-[calc(100vh-4rem)] max-w-md items-center">
    <div class="w-full rounded-2xl border border-border/60 bg-card/55 p-3 shadow-2xl shadow-foreground/5 backdrop-blur-xl sm:p-4">
      {#if flash.notice}
        <div class="mb-4 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">{flash.notice}</div>
      {/if}

      {#if flash.alert}
        <div class="mb-4 rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800">{flash.alert}</div>
      {/if}

      <div class="mb-5 flex items-center gap-3 px-1">
        <span class="size-9 rounded-lg" data-brand-mark></span>
        <div>
          <p class="text-sm font-semibold text-foreground">Transactions</p>
          <p class="text-xs text-muted-foreground">Expense control</p>
        </div>
      </div>

      <slot />
    </div>
  </div>
</main>
