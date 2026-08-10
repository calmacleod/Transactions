<script>
  import { onDestroy, onMount } from "svelte"
  import { router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Checkbox } from "$lib/components/ui/checkbox"
  import { Input } from "$lib/components/ui/input"
  import { NativeSelect, NativeSelectOption } from "$lib/components/ui/native-select"
  import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "$lib/components/ui/table"
  import DatePicker from "../components/DatePicker.svelte"
  import Check from "@lucide/svelte/icons/check"
  import Download from "@lucide/svelte/icons/download"
  import Plus from "@lucide/svelte/icons/plus"
  import Trash2 from "@lucide/svelte/icons/trash-2"

  export let import_batch
  export let rows = []
  export let groups = []
  export let categories = []
  export let actions

  let draftRows = rows.map((row) => ({ ...row, category_id: row.category_id || "", notes: row.notes || "" }))
  let nextRowId = -1
  let selectedGroupKey = "all"
  let cableConsumer
  let classificationSubscription
  let classificationRuntimePromise
  let destroyed = false

  $: groupedRowIds = new Map(groups.map((group) => [group.key, new Set(group.row_ids)]))
  $: visibleRows = selectedGroupKey === "all" ? draftRows : draftRows.filter((row) => groupedRowIds.get(selectedGroupKey)?.has(row.id))
  $: includedRows = draftRows.filter((row) => row.duplicate ? row.include_duplicate : row.included)
  $: totalCents = includedRows.reduce((sum, row) => sum + Math.round(Number(row.amount || 0) * 100), 0)
  $: duplicateCount = draftRows.filter((row) => row.duplicate).length
  $: skippedCount = draftRows.filter((row) => row.duplicate ? !row.include_duplicate : !row.included).length
  $: classifiedCount = draftRows.filter((row) => row.classification_status === "classified").length
  $: groupOptions = [{ key: "all", label: "All rows", count: draftRows.length, duplicate_count: duplicateCount }, ...groups]
  $: commitLabel = includedRows.length > 0 ? `Import ${includedRows.length}` : "Finish without importing"
  $: readOnly = Boolean(import_batch.read_only || !import_batch.active)
  $: helpText = readOnly
    ? "This import is finished. You can review the mapped rows, source CSV values, and matched transactions."
    : "Review each CSV row before it becomes a transaction."

  onMount(() => {
    destroyed = false
    subscribeToClassification()
  })

  onDestroy(() => {
    destroyed = true
    classificationSubscription?.unsubscribe()
    cableConsumer?.disconnect()
  })

  function addRow() {
    if (readOnly) return

    draftRows = [
      ...draftRows,
      {
        id: nextRowId--,
        row_number: draftRows.length + 1,
        occurred_on: "",
        description: "",
        amount: "",
        direction: "debit",
        card_last4: "",
        category_id: "",
        notes: "",
        raw_data: {},
        classification_status: "manual",
        classification_reason: "Added manually in import preview.",
        classification_confidence: null,
        included: true,
        include_duplicate: false,
        duplicate: null,
      },
    ]
  }

  function removeRow(row) {
    if (readOnly) return

    draftRows = draftRows.filter((draftRow) => draftRow.id !== row.id).map((draftRow, rowIndex) => ({ ...draftRow, row_number: rowIndex + 1 }))
  }

  function commitImport() {
    if (readOnly || !actions.commit) return

    router.post(
      actions.commit,
      {
        import: {
          rows: draftRows.map((row) => ({
            id: row.id > 0 ? row.id : null,
            occurred_on: row.occurred_on,
            description: row.description,
            amount: row.amount,
            direction: row.direction,
            card_last4: row.card_last4,
            category_id: row.category_id,
            notes: row.notes,
            included: row.duplicate ? row.include_duplicate : row.included,
            include_duplicate: row.include_duplicate,
          })),
        },
      },
      { preserveScroll: true }
    )
  }

  function formattedTotal(cents) {
    return new Intl.NumberFormat("en-CA", { style: "currency", currency: "CAD" }).format(cents / 100)
  }

  function setInclude(row, value) {
    if (readOnly) return

    row.included = value
    if (!value) row.include_duplicate = false
    draftRows = draftRows
  }

  function setIncludeDuplicate(row, value) {
    if (readOnly) return

    row.include_duplicate = value
    row.included = value
    draftRows = draftRows
  }

  function rawCells(row) {
    const raw = row.raw_data || {}
    if (!Object.keys(raw).length) return []

    return [
      ["Date", raw.occurred_on],
      ["Description", raw.description],
      ["Debit", raw.debit],
      ["Credit", raw.credit],
      ["Card", raw.card_number || raw.card_last4],
    ].filter(([, value]) => value !== undefined && value !== null && String(value).length)
  }

  function classificationLabel(row) {
    if (row.classification_status === "classified") return row.category_id ? "Auto-classified" : "Reviewed"
    if (row.classification_status === "failed") return "Classification failed"
    if (row.classification_status === "manual") return "Manual row"

    return "Classifying"
  }

  function duplicateStatusLabel(row) {
    return row.include_duplicate ? "Importing duplicate" : "Skipped duplicate"
  }

  function matchedTransactionSummary(row) {
    const transaction = row.duplicate?.transaction
    if (!transaction) return row.duplicate?.detail

    return `${transaction.amount_label} · ${transaction.category?.name || "Unclassified"} · ${transaction.occurred_on_label}`
  }

  async function subscribeToClassification() {
    if (readOnly || !actions.classification_stream) return

    await ensureClassificationRuntime()
    if (destroyed) {
      cableConsumer?.disconnect()
      return
    }

    classificationSubscription = cableConsumer.subscriptions.create(actions.classification_stream, {
      received(data) {
        if (data.type !== "row_classified") return

        draftRows = draftRows.map((row) => {
          if (row.id !== data.row.id) return row

          return {
            ...row,
            category_id: data.row.category_id || "",
            category: data.row.category,
            classification_status: data.row.classification_status,
            classification_confidence: data.row.classification_confidence,
            classification_reason: data.row.classification_reason,
          }
        })
      },
    })
  }

  async function ensureClassificationRuntime() {
    if (!classificationRuntimePromise) {
      classificationRuntimePromise = import("@rails/actioncable").then((cable) => {
        cableConsumer = cableConsumer || cable.createConsumer()
      })
    }

    await classificationRuntimePromise
  }
</script>

<svelte:head>
  <title>Review {import_batch.filename} - Transactions</title>
</svelte:head>

<section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
  <div class="max-w-3xl">
    <p class="text-xs font-semibold uppercase tracking-wider text-primary">Import preview</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">{import_batch.filename}</h1>
    <p class="mt-2 text-sm text-muted-foreground">{helpText}</p>
  </div>

  <div class="flex flex-wrap gap-2">
    {#if actions.download}
      <Button href={actions.download} variant="outline">
        <Download class="size-4" />
        Original CSV
      </Button>
    {/if}
    {#if !readOnly}
      <Button variant="outline" onclick={addRow}>
        <Plus class="size-4" />
        Add row
      </Button>
      <Button onclick={commitImport} disabled={draftRows.length === 0 || !actions.commit}>
        <Check class="size-4" />
        {commitLabel}
      </Button>
    {/if}
  </div>
</section>

{#if readOnly}
  <section class="mb-4 rounded-lg border border-border bg-background p-3 text-foreground">
    <p class="text-sm font-semibold">Finished import</p>
    <p class="mt-1 text-xs leading-5 text-muted-foreground">
      This import was closed{import_batch.imported_at_label ? ` on ${import_batch.imported_at_label}` : ""}. It is no longer active and cannot be imported again from this preview.
    </p>
  </section>
{/if}

{#if duplicateCount > 0 && !readOnly}
  <section class="mb-4 rounded-lg border border-amber-300 bg-amber-50 p-3 text-amber-950 dark:border-amber-700 dark:bg-amber-950/30 dark:text-amber-100">
    <p class="text-sm font-semibold">{duplicateCount} duplicate row{duplicateCount === 1 ? "" : "s"} detected</p>
    <p class="mt-1 text-xs leading-5">Duplicates are selected to be skipped. Use each duplicate row's status control only when you intentionally want to import another copy.</p>
  </section>
{/if}

<section class="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
  <Card>
    <CardContent>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Rows</p>
      <p class="mt-2 text-2xl font-semibold text-foreground">{draftRows.length}</p>
    </CardContent>
  </Card>
  <Card>
    <CardContent>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Importing</p>
      <p class="mt-2 text-2xl font-semibold text-foreground">{includedRows.length}</p>
    </CardContent>
  </Card>
  <Card>
    <CardContent>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Skipped</p>
      <p class="mt-2 text-2xl font-semibold text-foreground">{skippedCount}</p>
    </CardContent>
  </Card>
  <Card>
    <CardContent>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Classified</p>
      <p class="mt-2 text-2xl font-semibold text-foreground">{classifiedCount}</p>
    </CardContent>
  </Card>
  <Card>
    <CardContent>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Preview total</p>
      <p class="money-display mt-2 text-2xl font-semibold text-foreground">{formattedTotal(totalCents)}</p>
    </CardContent>
  </Card>
</section>

<section class="mb-4 flex flex-wrap gap-2">
  {#each groupOptions as group}
    <Button variant={selectedGroupKey === group.key ? "default" : "outline"} size="sm" onclick={() => (selectedGroupKey = group.key)}>
      {group.label}
      <span class="ml-1 text-xs opacity-75">{group.count}</span>
      {#if group.duplicate_count}
        <span class="ml-1 rounded bg-amber-200 px-1 text-[0.7rem] text-amber-950">{group.duplicate_count} dup</span>
      {/if}
    </Button>
  {/each}
</section>

<Card>
  <CardHeader class="border-b border-border">
    <div class="flex items-center justify-between gap-3">
      <CardTitle class="text-sm">CSV rows ({visibleRows.length})</CardTitle>
      <Badge variant="secondary">{import_batch.status}</Badge>
    </div>
  </CardHeader>
  <CardContent class="p-0">
    <div class="space-y-2 p-3 md:hidden">
      {#each visibleRows as row, index (row.id)}
        <section class={`rounded-lg border p-3 ${row.duplicate ? "border-amber-200 bg-amber-50/70 dark:border-amber-800 dark:bg-amber-950/20" : "border-border bg-background"}`}>
          <div class="mb-2 flex items-start justify-between gap-3">
            <div class="min-w-0">
              <p class="text-[0.7rem] font-semibold uppercase tracking-wide text-muted-foreground">Row {row.row_number || index + 1}</p>
              <Input bind:value={row.description} class="mt-1 h-8 w-full min-w-0 font-medium" disabled={readOnly} onchange={() => (draftRows = draftRows)} />
            </div>
            <Input type="number" min="0" step="0.01" bind:value={row.amount} class="money-value h-8 w-24 shrink-0" disabled={readOnly} onchange={() => (draftRows = draftRows)} />
          </div>

          <div class="grid grid-cols-2 gap-2">
            <DatePicker bind:value={row.occurred_on} class="h-8" disabled={readOnly} ariaLabel={`Select date for row ${row.row_number || index + 1}`} onchange={() => (draftRows = draftRows)} />
            <NativeSelect bind:value={row.category_id} class="w-full" disabled={readOnly} onchange={() => (draftRows = draftRows)}>
              <NativeSelectOption value="">Unclassified</NativeSelectOption>
              {#each categories as category}
                <NativeSelectOption value={category.id}>{category.name}</NativeSelectOption>
              {/each}
            </NativeSelect>
          </div>

          <div class="mt-2 flex items-center gap-2">
            <NativeSelect bind:value={row.direction} class="w-28" size="sm" disabled={readOnly} onchange={() => (draftRows = draftRows)}>
              <NativeSelectOption value="debit">Debit</NativeSelectOption>
              <NativeSelectOption value="credit">Credit</NativeSelectOption>
            </NativeSelect>
            <Input bind:value={row.card_last4} maxlength="4" class="h-7 w-20" disabled={readOnly} onchange={() => (draftRows = draftRows)} />
            <Input bind:value={row.notes} class="h-7 min-w-0 flex-1" placeholder="Notes" disabled={readOnly} onchange={() => (draftRows = draftRows)} />
          </div>

          <div class="mt-2 rounded-md border border-border/80 bg-background px-2 py-1.5 text-xs">
            {#if row.duplicate}
              <div class="flex items-center justify-between gap-2">
                <div class="min-w-0">
                  <p class="font-semibold text-foreground">{duplicateStatusLabel(row)}</p>
                  <p class="line-clamp-2 text-muted-foreground">{row.duplicate.transaction ? `#${row.duplicate.transaction.id} · ${matchedTransactionSummary(row)}` : row.duplicate.detail}</p>
                </div>
                <Badge variant={row.include_duplicate ? "success" : "warning"}>{row.include_duplicate ? "Import" : "Skip"}</Badge>
              </div>
              <label class="mt-2 flex items-center gap-2 font-medium text-foreground">
                <Checkbox checked={row.include_duplicate} disabled={readOnly} onCheckedChange={(value) => setIncludeDuplicate(row, Boolean(value))} />
                {readOnly ? "Closed as skipped" : "Import anyway"}
              </label>
            {:else}
              <div class="flex items-center justify-between gap-2">
                <Badge variant={row.classification_status === "failed" ? "destructive" : "secondary"}>{classificationLabel(row)}</Badge>
                <label class="flex items-center gap-2 font-medium text-foreground">
                  <Checkbox checked={row.included} disabled={readOnly} onCheckedChange={(value) => setInclude(row, Boolean(value))} />
                  {readOnly ? "Closed row" : "Import row"}
                </label>
              </div>
              {#if row.classification_reason}
                <p class="mt-1 line-clamp-2 text-muted-foreground">{row.classification_reason}</p>
              {/if}
            {/if}
          </div>

          <div class="mt-2 grid gap-1 text-xs">
            {#if row.duplicate?.transaction}
              <details class="rounded-md border border-border bg-background px-2 py-1">
                <summary class="cursor-pointer font-medium text-foreground">Matched transaction</summary>
                <div class="mt-1 grid gap-1 text-muted-foreground">
                  <span>{row.duplicate.transaction.description}</span>
                  <span>{row.duplicate.transaction.occurred_on_label} · {row.duplicate.transaction.category?.name || "Unclassified"} · Card {row.duplicate.transaction.card_last4 || "none"}</span>
                  {#if row.duplicate.transaction.notes}
                    <span>{row.duplicate.transaction.notes}</span>
                  {/if}
                </div>
              </details>
            {/if}

            {#if rawCells(row).length}
              <details class="rounded-md border border-border bg-background px-2 py-1">
                <summary class="cursor-pointer font-medium text-foreground">CSV source</summary>
                <div class="mt-1 grid gap-1">
                  {#each rawCells(row) as [label, value]}
                    <div class="grid grid-cols-[4.25rem_minmax(0,1fr)] gap-2">
                      <span class="font-medium text-muted-foreground">{label}</span>
                      <span class="truncate text-foreground" title={String(value)}>{value}</span>
                    </div>
                  {/each}
                </div>
              </details>
            {/if}
          </div>
        </section>
      {/each}
    </div>

    <div class="hidden overflow-x-auto md:block">
      <Table class="min-w-[76rem] table-fixed text-xs">
        <TableHeader>
          <TableRow>
            <TableHead class="w-12">Row</TableHead>
            <TableHead class="w-[34rem]">Transaction</TableHead>
            <TableHead class="w-28">Amount</TableHead>
            <TableHead class="w-44">Category</TableHead>
            <TableHead class="w-[20rem]">Status</TableHead>
            <TableHead class="w-14"></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {#each visibleRows as row, index (row.id)}
            <TableRow class={row.duplicate ? "bg-amber-50/70 dark:bg-amber-950/20" : ""}>
              <TableCell class="text-muted-foreground">{row.row_number || index + 1}</TableCell>
              <TableCell>
                <div class="grid gap-1.5">
                  <div class="grid grid-cols-[8.5rem_minmax(0,1fr)] gap-2">
                    <DatePicker bind:value={row.occurred_on} size="sm" disabled={readOnly} ariaLabel={`Select date for row ${row.row_number || index + 1}`} onchange={() => (draftRows = draftRows)} />
                    <Input bind:value={row.description} class="h-7 w-full font-medium" disabled={readOnly} onchange={() => (draftRows = draftRows)} />
                  </div>
                  <div class="flex min-w-0 flex-wrap items-center gap-2">
                    <NativeSelect bind:value={row.direction} class="w-24" size="sm" disabled={readOnly} onchange={() => (draftRows = draftRows)}>
                      <NativeSelectOption value="debit">Debit</NativeSelectOption>
                      <NativeSelectOption value="credit">Credit</NativeSelectOption>
                    </NativeSelect>
                    <Input bind:value={row.card_last4} maxlength="4" class="h-7 w-20" disabled={readOnly} onchange={() => (draftRows = draftRows)} />
                    <Input bind:value={row.notes} class="h-7 min-w-40 flex-1" placeholder="Notes" disabled={readOnly} onchange={() => (draftRows = draftRows)} />

                    {#if rawCells(row).length}
                      <details class="min-w-36 rounded-md border border-border bg-background px-2 py-1">
                        <summary class="cursor-pointer text-[0.7rem] font-medium text-foreground">CSV source</summary>
                        <div class="mt-1 grid gap-1">
                          {#each rawCells(row) as [label, value]}
                            <div class="grid grid-cols-[4.25rem_minmax(0,1fr)] gap-2">
                              <span class="font-medium text-muted-foreground">{label}</span>
                              <span class="truncate text-foreground" title={String(value)}>{value}</span>
                            </div>
                          {/each}
                        </div>
                      </details>
                    {/if}
                  </div>
                </div>
              </TableCell>
              <TableCell>
                <Input type="number" min="0" step="0.01" bind:value={row.amount} class="money-value h-7 w-full" disabled={readOnly} onchange={() => (draftRows = draftRows)} />
              </TableCell>
              <TableCell>
                <NativeSelect bind:value={row.category_id} class="w-full" disabled={readOnly} onchange={() => (draftRows = draftRows)}>
                  <NativeSelectOption value="">Unclassified</NativeSelectOption>
                  {#each categories as category}
                    <NativeSelectOption value={category.id}>{category.name}</NativeSelectOption>
                  {/each}
                </NativeSelect>
              </TableCell>
              <TableCell>
                {#if row.duplicate}
                  <div class={`rounded-md border px-2 py-1.5 ${row.include_duplicate ? "border-emerald-200 bg-emerald-50 text-emerald-950 dark:border-emerald-800 dark:bg-emerald-950/30 dark:text-emerald-100" : "border-amber-200 bg-amber-50 text-amber-950 dark:border-amber-800 dark:bg-amber-950/30 dark:text-amber-100"}`}>
                    <div class="flex items-center justify-between gap-2">
                      <div class="min-w-0">
                        <p class="font-semibold leading-4">{duplicateStatusLabel(row)}</p>
                        <p class="line-clamp-2 text-[0.7rem] opacity-75">{row.duplicate.transaction ? `#${row.duplicate.transaction.id} · ${matchedTransactionSummary(row)}` : row.duplicate.detail}</p>
                      </div>
                      <Badge variant={row.include_duplicate ? "success" : "warning"}>{row.include_duplicate ? "Import" : "Skip"}</Badge>
                    </div>

                    {#if row.duplicate.transaction}
                      <details class="mt-1 rounded border border-amber-200/80 bg-background px-2 py-1 text-[0.7rem] text-foreground dark:border-amber-800/80">
                        <summary class="cursor-pointer font-medium">Matched transaction</summary>
                        <div class="mt-1 grid gap-1 text-muted-foreground">
                          <span class="truncate">{row.duplicate.transaction.description}</span>
                          <span>{row.duplicate.transaction.occurred_on_label} · {row.duplicate.transaction.category?.name || "Unclassified"} · Card {row.duplicate.transaction.card_last4 || "none"}</span>
                        </div>
                      </details>
                    {/if}

                    <label class="mt-1 flex items-center gap-2 font-medium">
                      <Checkbox checked={row.include_duplicate} disabled={readOnly} onCheckedChange={(value) => setIncludeDuplicate(row, Boolean(value))} />
                      {readOnly ? "Closed as skipped" : "Import anyway"}
                    </label>
                  </div>
                {:else}
                  <div class="rounded-md border border-border bg-background px-2 py-1.5">
                    <div class="flex items-center justify-between gap-2">
                      <Badge variant={row.classification_status === "failed" ? "destructive" : "secondary"}>{classificationLabel(row)}</Badge>
                      <label class="flex items-center gap-2 font-medium text-foreground">
                        <Checkbox checked={row.included} disabled={readOnly} onCheckedChange={(value) => setInclude(row, Boolean(value))} />
                        {readOnly ? "Closed" : "Import"}
                      </label>
                    </div>
                    {#if row.classification_reason}
                      <p class="mt-1 line-clamp-2 text-[0.7rem] leading-4 text-muted-foreground">{row.classification_reason}</p>
                    {/if}
                  </div>
                {/if}
              </TableCell>
              <TableCell class="text-right">
                {#if !readOnly}
                  <Button type="button" variant="ghost" size="icon" aria-label={`Remove row ${row.row_number || index + 1}`} onclick={() => removeRow(row)}>
                    <Trash2 class="size-4" />
                  </Button>
                {/if}
              </TableCell>
            </TableRow>
          {/each}
        </TableBody>
      </Table>
    </div>
  </CardContent>
</Card>
