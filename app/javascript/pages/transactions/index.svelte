<script>
  import { onMount } from "svelte"
  import { Link, router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Input } from "$lib/components/ui/input"
  import { Label } from "$lib/components/ui/label"
  import { NativeSelect, NativeSelectOption } from "$lib/components/ui/native-select"
  import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "$lib/components/ui/table"
  import Layout from "../Layout.svelte"
  import { withQuery } from "$lib/formatters"
  import Check from "@lucide/svelte/icons/check"
  import Search from "@lucide/svelte/icons/search"
  import X from "@lucide/svelte/icons/x"

  export let categories = []
  export let saved_queries = []
  export let selected_saved_query_id = null
  export let filter_params = {}
  export let quick_ranges = []
  export let filter_active = false
  export let date_summary = ""
  export let transactions = []
  export let pagination
  export let per_page
  export let per_page_options = []
  export let actions

  let filters = { ...filter_params, saved_query_id: selected_saved_query_id || "" }
  let saveName = ""
  let selectedIds = new Set()
  let bulkCategoryId = ""
  let dragSelecting = false
  let dragSelectionMode = null
  let shiftDown = false
  let lastShiftHoverId = null
  let suppressNextRowClick = false

  $: selectedTransactions = transactions.filter((transaction) => selectedIds.has(transaction.id))
  $: selectedTotal = selectedTransactions.reduce((sum, transaction) => sum + Number(transaction.signed_amount_cents || 0), 0)
  $: allVisibleSelected = transactions.length > 0 && transactions.every((transaction) => selectedIds.has(transaction.id))

  onMount(() => {
    const stopDrag = () => {
      dragSelecting = false
      dragSelectionMode = null
      lastShiftHoverId = null
    }

    const selectRowUnderPointer = (event) => {
      if (!dragSelecting) return

      const row = document.elementFromPoint(event.clientX, event.clientY)?.closest("[data-transaction-row-id]")
      if (!row) return

      applyTransactionSelection(Number(row.dataset.transactionRowId), dragSelectionMode)
      event.preventDefault()
    }

    const handleKeyDown = (event) => {
      if (event.key === "Shift") shiftDown = true
    }

    const handleKeyUp = (event) => {
      if (event.key === "Shift") {
        shiftDown = false
        dragSelecting = false
        dragSelectionMode = null
        lastShiftHoverId = null
      }
    }

    document.addEventListener("pointermove", selectRowUnderPointer)
    document.addEventListener("pointerup", stopDrag)
    window.addEventListener("keydown", handleKeyDown, true)
    window.addEventListener("keyup", handleKeyUp, true)
    window.addEventListener("blur", stopDrag)

    return () => {
      document.removeEventListener("pointermove", selectRowUnderPointer)
      document.removeEventListener("pointerup", stopDrag)
      window.removeEventListener("keydown", handleKeyDown, true)
      window.removeEventListener("keyup", handleKeyUp, true)
      window.removeEventListener("blur", stopDrag)
    }
  })

  function applyFilters() {
    router.get(actions.index, compact(filters), { preserveState: true })
  }

  function clearFilters() {
    router.get(actions.index)
  }

  function quickRange(value) {
    const params = { ...filter_params, quick_range: value }
    delete params.start_date
    delete params.end_date
    router.get(actions.index, params)
  }

  function compact(values) {
    return Object.fromEntries(Object.entries(values).filter(([, value]) => value !== "" && value !== null && value !== undefined))
  }

  function toggleAll() {
    selectedIds = allVisibleSelected ? new Set() : new Set(transactions.map((transaction) => transaction.id))
  }

  function toggleTransaction(id) {
    const next = new Set(selectedIds)
    next.has(id) ? next.delete(id) : next.add(id)
    selectedIds = next
  }

  function selectTransaction(id) {
    if (selectedIds.has(id)) return
    selectedIds = new Set([...selectedIds, id])
  }

  function unselectTransaction(id) {
    if (!selectedIds.has(id)) return
    const next = new Set(selectedIds)
    next.delete(id)
    selectedIds = next
  }

  function applyTransactionSelection(id, mode) {
    if (mode === "remove") {
      unselectTransaction(id)
    } else {
      selectTransaction(id)
    }
  }

  function startRowDrag(event, transaction) {
    if (!event.shiftKey || event.button !== 0) return

    dragSelectionMode = selectedIds.has(transaction.id) ? "remove" : "add"
    dragSelecting = true
    shiftDown = true
    lastShiftHoverId = transaction.id
    applyTransactionSelection(transaction.id, dragSelectionMode)
    suppressNextRowClick = true
    event.preventDefault()
  }

  function hoverRow(event, transaction) {
    const shiftActive = event.shiftKey || event.getModifierState?.("Shift") || shiftDown
    if (!dragSelecting && !shiftActive) return

    shiftDown = shiftActive
    if (dragSelecting) {
      applyTransactionSelection(transaction.id, dragSelectionMode)
    } else if (lastShiftHoverId !== transaction.id) {
      lastShiftHoverId = transaction.id
      toggleTransaction(transaction.id)
    } else {
      return
    }
    event.preventDefault()
  }

  function toggleTransactionFromRow(event, transaction) {
    if (suppressNextRowClick) {
      suppressNextRowClick = false
      return false
    }

    if (!(event.target instanceof Element)) return false
    if (event.target.closest("a, button, input, label, select, textarea")) return false

    toggleTransaction(transaction.id)
    return true
  }

  function toggleTransactionFromRowKeydown(event, transaction) {
    if (!["Enter", " "].includes(event.key)) return

    if (toggleTransactionFromRow(event, transaction)) {
      event.preventDefault()
    }
  }

  function updateCategory(transaction, categoryId) {
    router.patch(transaction.update_path, { expense_transaction: { category_id: categoryId } }, { preserveScroll: true })
  }

  function bulkUpdate() {
    router.patch(actions.bulk_update, {
      bulk_transaction: {
        category_id: bulkCategoryId,
        transaction_ids: Array.from(selectedIds),
      },
    })
  }

  function saveFilter() {
    if (!saveName.trim()) return
    router.post(actions.save_query, { name: saveName, filters: compact(filter_params) })
  }

  function destroySavedQuery(query) {
    router.delete(query.destroy_path)
  }

  function formatSigned(cents) {
    const sign = cents < 0 ? "-" : ""
    const value = Math.abs(cents) / 100
    return `${sign}${new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(value)}`
  }

  function confidencePercent(label) {
    const value = Number.parseInt(label, 10)
    return Number.isFinite(value) ? Math.max(0, Math.min(value, 100)) : 0
  }

  function confidenceStyle(label) {
    return `--confidence: ${confidencePercent(label)}%`
  }
</script>

<Layout>
  <section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
    <div>
      <p class="text-xs font-semibold uppercase tracking-wider text-primary">Transaction ledger</p>
      <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">Transactions</h1>
      <p class="mt-2 text-sm text-muted-foreground">Filter, inspect, save common views, and reclassify imported records.</p>
    </div>
    <Badge variant="outline" class="h-8 px-3 text-sm">
      <span class="font-semibold text-foreground">{pagination.count}</span>
      matching records
    </Badge>
  </section>

  <Card class="mb-4">
    <CardHeader class="border-b border-border">
      <div class="flex flex-wrap items-center gap-2">
        {#each quick_ranges as range}
          <Button type="button" size="sm" variant={filter_params.quick_range === range.value ? "default" : "outline"} onclick={() => quickRange(range.value)}>{range.label}</Button>
        {/each}
        <Button type="button" size="sm" variant="ghost" class="ml-auto" onclick={clearFilters}>Clear</Button>
      </div>
    </CardHeader>

    <CardContent>
      <form class="grid gap-4" on:submit|preventDefault={applyFilters}>
        <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-6">
          <div class="space-y-1.5 xl:col-span-2">
            <Label for="query">Search</Label>
            <div class="relative">
              <Search class="pointer-events-none absolute left-2.5 top-2 size-4 text-muted-foreground" />
              <Input id="query" type="search" bind:value={filters.query} placeholder="Merchant or memo" class="pl-8" />
            </div>
          </div>
          <div class="space-y-1.5">
            <Label for="start_date">From</Label>
            <Input id="start_date" type="date" bind:value={filters.start_date} />
          </div>
          <div class="space-y-1.5">
            <Label for="end_date">To</Label>
            <Input id="end_date" type="date" bind:value={filters.end_date} />
          </div>
          <div class="space-y-1.5">
            <Label for="direction">Type</Label>
            <NativeSelect id="direction" bind:value={filters.direction} class="w-full">
              <NativeSelectOption value="">All</NativeSelectOption>
              <NativeSelectOption value="debit">Debits</NativeSelectOption>
              <NativeSelectOption value="credit">Credits</NativeSelectOption>
            </NativeSelect>
          </div>
          <div class="space-y-1.5">
            <Label for="classified">Status</Label>
            <NativeSelect id="classified" bind:value={filters.classified} class="w-full">
              <NativeSelectOption value="">Any</NativeSelectOption>
              <NativeSelectOption value="classified">Classified</NativeSelectOption>
              <NativeSelectOption value="unclassified">Unclassified</NativeSelectOption>
            </NativeSelect>
          </div>
          <div class="space-y-1.5 xl:col-span-2">
            <Label for="category_id">Category</Label>
            <NativeSelect id="category_id" bind:value={filters.category_id} class="w-full">
              <NativeSelectOption value="">All categories</NativeSelectOption>
              {#each categories as category}
                <NativeSelectOption value={category.id}>{category.name}</NativeSelectOption>
              {/each}
            </NativeSelect>
          </div>
          <div class="space-y-1.5">
            <Label for="day_of_week">Day</Label>
            <NativeSelect id="day_of_week" bind:value={filters.day_of_week} class="w-full">
              <NativeSelectOption value="">Any day</NativeSelectOption>
              {#each ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"] as day, index}
                <NativeSelectOption value={index}>{day}</NativeSelectOption>
              {/each}
            </NativeSelect>
          </div>
          <div class="space-y-1.5">
            <Label for="min_amount">Min</Label>
            <Input id="min_amount" type="number" bind:value={filters.min_amount} step="0.01" placeholder="0.00" />
          </div>
          <div class="space-y-1.5">
            <Label for="max_amount">Max</Label>
            <Input id="max_amount" type="number" bind:value={filters.max_amount} step="0.01" placeholder="500.00" />
          </div>
          <div class="space-y-1.5 xl:col-span-2">
            <Label for="saved_query_id">Saved</Label>
            <NativeSelect id="saved_query_id" bind:value={filters.saved_query_id} class="w-full">
              <NativeSelectOption value="">No saved filter</NativeSelectOption>
              {#each saved_queries as query}
                <NativeSelectOption value={query.id}>{query.name}</NativeSelectOption>
              {/each}
            </NativeSelect>
          </div>
        </div>

        <div class="flex flex-wrap gap-2">
          <Button type="submit">Apply filters</Button>
          <Button type="button" variant="outline" onclick={clearFilters}>Reset</Button>
        </div>
      </form>
    </CardContent>
  </Card>

  <section class="mb-4 grid gap-3 xl:grid-cols-[minmax(0,1fr)_420px]">
    {#if filter_active}
      <Card>
        <CardContent class="text-sm text-muted-foreground">{date_summary}</CardContent>
      </Card>
    {/if}

    <Card class={filter_active ? "" : "xl:col-start-2"}>
      <CardContent>
        <form class="flex gap-2" on:submit|preventDefault={saveFilter}>
          <Input bind:value={saveName} placeholder="Save this filter as..." class="min-w-0 flex-1" />
          <Button type="submit">Save</Button>
        </form>
      </CardContent>
    </Card>
  </section>

  {#if saved_queries.length}
    <section class="mb-4 flex flex-wrap gap-2">
      {#each saved_queries as query}
        <Badge variant="outline" class="h-8 gap-0 overflow-hidden p-0">
          <Link href={query.path} prefetch cacheFor="30s" class="px-3 py-1.5 hover:text-foreground">{query.name}</Link>
          <button type="button" class="border-l border-border px-2.5 py-1.5 text-muted-foreground hover:text-foreground" aria-label={`Delete ${query.name}`} on:click={() => destroySavedQuery(query)}>
            <X class="size-3" />
          </button>
        </Badge>
      {/each}
    </section>
  {/if}

  <Card class="mb-4 overflow-hidden">
    <div class="divide-y divide-border md:hidden" data-testid="mobile-transactions-list">
      {#if transactions.length}
        {#each transactions as transaction}
          <div
            data-testid="mobile-transaction-row"
            class={`grid cursor-pointer gap-2 px-3 py-3 ${selectedIds.has(transaction.id) ? "bg-accent/70" : ""}`}
            role="button"
            tabindex="0"
            aria-pressed={selectedIds.has(transaction.id)}
            on:click={(event) => toggleTransactionFromRow(event, transaction)}
            on:keydown={(event) => toggleTransactionFromRowKeydown(event, transaction)}
          >
            <div class="grid grid-cols-[auto_minmax(0,1fr)_auto] items-start gap-2">
              <input type="checkbox" class="mt-0.5 size-4 rounded border-input accent-primary" aria-label={`Select ${transaction.description}`} checked={selectedIds.has(transaction.id)} on:change={() => toggleTransaction(transaction.id)} />
              <div class="min-w-0">
                <div class="flex min-w-0 items-center gap-2">
                  <span class="whitespace-nowrap text-xs font-medium text-muted-foreground">{transaction.occurred_on_label}</span>
                  <span
                    class="mobile-confidence-chip inline-flex h-5 min-w-0 max-w-24 items-center truncate rounded-full px-2 text-[11px] font-medium"
                    style={confidenceStyle(transaction.confidence_label)}
                    data-pending={transaction.confidence_label === "Pending" ? "true" : undefined}
                  >
                    {transaction.confidence_label}
                  </span>
                </div>
                <p class="mt-1 line-clamp-2 text-sm font-medium leading-5 text-foreground">{transaction.description}</p>
              </div>
              <p class={`money-value text-right text-sm font-semibold ${transaction.amount_class}`}>{transaction.amount_label}</p>
            </div>

            <div class="grid grid-cols-[1rem_minmax(0,1fr)] gap-2">
              <span aria-hidden="true"></span>
              <NativeSelect value={transaction.category_id || ""} class="h-9 w-full text-xs" onchange={(event) => updateCategory(transaction, event.currentTarget.value)}>
                <NativeSelectOption value="">Unclassified</NativeSelectOption>
                {#each categories as category}
                  <NativeSelectOption value={category.id}>{category.name}</NativeSelectOption>
                {/each}
              </NativeSelect>
            </div>
          </div>
        {/each}
      {:else}
        <p class="px-4 py-8 text-center text-sm text-muted-foreground">No matching transactions.</p>
      {/if}
    </div>

    <div class="hidden md:block">
      <Table class="min-w-[64rem]">
        <TableHeader>
          <TableRow>
            <TableHead class="w-16 pl-6 pr-4">
              <input type="checkbox" class="size-4 rounded border-input accent-primary" aria-label="Select all visible transactions" checked={allVisibleSelected} on:change={toggleAll} />
            </TableHead>
            <TableHead>Date</TableHead>
            <TableHead>Description</TableHead>
            <TableHead>Category</TableHead>
            <TableHead class="text-right">Amount</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {#if transactions.length}
            {#each transactions as transaction}
              <TableRow
                data-transaction-row-id={transaction.id}
                class={`cursor-pointer ${selectedIds.has(transaction.id) ? "bg-accent/70" : ""} ${shiftDown || dragSelecting ? "cursor-cell select-none hover:bg-primary/10" : ""}`}
                on:click={(event) => toggleTransactionFromRow(event, transaction)}
                onpointerdown={(event) => startRowDrag(event, transaction)}
                onpointerenter={(event) => hoverRow(event, transaction)}
                onpointermove={(event) => hoverRow(event, transaction)}
              >
                <TableCell class="w-16 pl-6 pr-4">
                  <input type="checkbox" class="size-4 rounded border-input accent-primary" aria-label={`Select ${transaction.description}`} checked={selectedIds.has(transaction.id)} on:change={() => toggleTransaction(transaction.id)} />
                </TableCell>
                <TableCell class="whitespace-nowrap text-muted-foreground">{transaction.occurred_on_label}</TableCell>
                <TableCell>
                  <div class="flex flex-wrap items-center gap-2">
                    <p class="font-medium text-foreground">{transaction.description}</p>
                    <span
                      class="confidence-chip inline-flex h-5 items-center rounded-full px-2 text-[11px] font-medium"
                      style={confidenceStyle(transaction.confidence_label)}
                      data-pending={transaction.confidence_label === "Pending" ? "true" : undefined}
                    >
                      {transaction.confidence_label}
                    </span>
                  </div>
                  {#if transaction.classification_reason}
                    <p class="mt-1 max-w-xl text-xs leading-5 text-muted-foreground">{transaction.classification_reason}</p>
                  {/if}
                </TableCell>
                <TableCell>
                  <NativeSelect value={transaction.category_id || ""} class="w-48" onchange={(event) => updateCategory(transaction, event.currentTarget.value)}>
                    <NativeSelectOption value="">Unclassified</NativeSelectOption>
                    {#each categories as category}
                      <NativeSelectOption value={category.id}>{category.name}</NativeSelectOption>
                    {/each}
                  </NativeSelect>
                </TableCell>
                <TableCell class={`money-value pr-6 text-right font-semibold ${transaction.amount_class}`}>{transaction.amount_label}</TableCell>
              </TableRow>
            {/each}
          {:else}
            <TableRow>
              <TableCell colspan="5" class="text-center text-sm text-muted-foreground">No matching transactions.</TableCell>
            </TableRow>
          {/if}
        </TableBody>
      </Table>
    </div>

    <div class="flex flex-col gap-3 border-t border-border px-4 py-3 text-sm text-muted-foreground lg:flex-row lg:items-center">
      <p>
        {#if pagination.count > 0}
          Showing <span class="money-value font-semibold text-foreground">{pagination.from}-{pagination.to}</span> of <span class="money-value font-semibold text-foreground">{pagination.count}</span>
        {:else}
          Showing <span class="money-value font-semibold text-foreground">0</span> records
        {/if}
      </p>

      <form class="flex items-center gap-2 lg:ml-auto" on:change={(event) => router.get(withQuery(actions.index, { ...filter_params, saved_query_id: selected_saved_query_id, limit: event.currentTarget.limit.value }))}>
        <Label for="limit">Rows</Label>
        <NativeSelect id="limit" name="limit" value={per_page} class="w-24">
          {#each per_page_options as option}
            <NativeSelectOption value={option.value}>{option.label}</NativeSelectOption>
          {/each}
        </NativeSelect>
      </form>

      {#if pagination.pages > 1}
        <nav class="flex flex-wrap gap-1" aria-label="Transactions pages">
          {#if pagination.prev_path}<Button href={pagination.prev_path} variant="outline" size="sm">Previous</Button>{/if}
          {#each pagination.pages_series as page}
            {#if page.gap}
              <span class="px-2 py-1">...</span>
            {:else}
              <Button href={page.path} variant={page.current ? "default" : "outline"} size="sm" aria-current={page.current ? "page" : undefined}>{page.label}</Button>
            {/if}
          {/each}
          {#if pagination.next_path}<Button href={pagination.next_path} variant="outline" size="sm">Next</Button>{/if}
        </nav>
      {/if}
    </div>
  </Card>

  {#if selectedIds.size}
    <Card class="fixed bottom-4 left-4 right-4 z-50 border-primary/30 shadow-2xl xl:left-[calc(16rem+1rem)]">
      <CardContent class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <p class="text-sm font-semibold text-foreground">{selectedIds.size} selected</p>
          <p class="text-xs text-muted-foreground">Total <span class="money-value font-semibold text-foreground">{formatSigned(selectedTotal)}</span></p>
        </div>

        <form class="flex flex-col gap-2 sm:flex-row sm:items-end" on:submit|preventDefault={bulkUpdate}>
          <div class="space-y-1.5">
            <Label for="bulk-category">Reclassify</Label>
            <NativeSelect id="bulk-category" bind:value={bulkCategoryId} class="w-full sm:w-56">
              <NativeSelectOption value="">Unclassified</NativeSelectOption>
              {#each categories as category}
                <NativeSelectOption value={category.id}>{category.name}</NativeSelectOption>
              {/each}
            </NativeSelect>
          </div>
          <Button type="submit">
            <Check class="size-4" />
            Apply
          </Button>
          <Button type="button" variant="outline" onclick={() => (selectedIds = new Set())}>Clear</Button>
        </form>
      </CardContent>
    </Card>
  {/if}
</Layout>
