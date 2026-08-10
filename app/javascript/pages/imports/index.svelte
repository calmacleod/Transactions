<script>
  import { router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "$lib/components/ui/table"
  import { badgeVariant } from "$lib/formatters"
  import CheckCircle2 from "@lucide/svelte/icons/check-circle-2"
  import Download from "@lucide/svelte/icons/download"
  import FileText from "@lucide/svelte/icons/file-text"
  import History from "@lucide/svelte/icons/history"
  import RotateCcw from "@lucide/svelte/icons/rotate-ccw"
  import Upload from "@lucide/svelte/icons/upload"

  export let import_batches = []
  export let actions

  $: totalRows = import_batches.reduce((sum, batch) => sum + Number(batch.rows_count || 0), 0)
  $: importedTransactions = import_batches.reduce((sum, batch) => sum + Number(batch.transactions_count || 0), 0)
  $: retainedFiles = import_batches.filter((batch) => batch.retained_file).length
  $: unfinishedCount = import_batches.filter((batch) => batch.unfinished).length

  function statusIcon(batch) {
    if (batch.status === "complete") return CheckCircle2
    return RotateCcw
  }
</script>

<svelte:head>
  <title>Imports - Transactions</title>
</svelte:head>

<section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
  <div class="max-w-3xl">
    <p class="text-xs font-semibold uppercase tracking-wider text-primary">Import history</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-foreground">Imports</h1>
    <p class="mt-2 text-sm text-muted-foreground">Review previous CSV uploads, resume unfinished previews, and download retained source files.</p>
  </div>

  <div class="flex flex-wrap gap-2">
    <Button href={actions.dashboard} variant="outline">Dashboard</Button>
    <Button onclick={() => router.visit(actions.dashboard)}>
      <Upload class="size-4" />
      Upload from dashboard
    </Button>
  </div>
</section>

<section class="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
  <Card>
    <CardContent>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Imports</p>
      <p class="mt-2 text-2xl font-semibold tracking-tight text-foreground">{import_batches.length}</p>
    </CardContent>
  </Card>
  <Card>
    <CardContent>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Rows reviewed</p>
      <p class="mt-2 text-2xl font-semibold tracking-tight text-foreground">{totalRows}</p>
    </CardContent>
  </Card>
  <Card>
    <CardContent>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Transactions added</p>
      <p class="mt-2 text-2xl font-semibold tracking-tight text-foreground">{importedTransactions}</p>
    </CardContent>
  </Card>
  <Card>
    <CardContent>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Retained files</p>
      <p class="mt-2 text-2xl font-semibold tracking-tight text-foreground">{retainedFiles}</p>
    </CardContent>
  </Card>
</section>

{#if unfinishedCount > 0}
  <section class="mb-4 rounded-lg border border-amber-300 bg-amber-50 p-3 text-amber-950 dark:border-amber-700 dark:bg-amber-950/30 dark:text-amber-100">
    <p class="text-sm font-semibold">{unfinishedCount} unfinished import{unfinishedCount === 1 ? "" : "s"}</p>
    <p class="mt-1 text-xs leading-5">Resume one of the previews below to finish reviewing the rows or close it out without importing.</p>
  </section>
{/if}

<Card>
  <CardHeader class="border-b border-border">
    <div class="flex items-center justify-between gap-3">
      <CardTitle class="flex items-center gap-2 text-sm"><History class="size-4" /> Import batches</CardTitle>
      <span class="text-xs font-medium text-muted-foreground">Latest 100</span>
    </div>
  </CardHeader>
  <CardContent class="p-0">
    {#if import_batches.length === 0}
      <div class="grid place-items-center gap-3 px-4 py-14 text-center">
        <span class="grid size-10 place-items-center rounded-lg bg-muted text-muted-foreground">
          <FileText class="size-5" />
        </span>
        <div>
          <p class="text-sm font-semibold text-foreground">No imports yet</p>
          <p class="mt-1 text-sm text-muted-foreground">Upload a CSV from the dashboard to start a review batch.</p>
        </div>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <Table class="min-w-[58rem]">
          <TableHeader>
            <TableRow>
              <TableHead>File</TableHead>
              <TableHead>Status</TableHead>
              <TableHead class="text-right">Rows</TableHead>
              <TableHead class="text-right">Imported</TableHead>
              <TableHead class="text-right">Skipped</TableHead>
              <TableHead>Uploaded</TableHead>
              <TableHead>Completed</TableHead>
              <TableHead class="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {#each import_batches as batch (batch.id)}
              <TableRow>
                <TableCell>
                  <div class="flex min-w-0 items-start gap-3">
                    <span class="mt-0.5 grid size-8 shrink-0 place-items-center rounded-lg bg-muted text-muted-foreground">
                      <svelte:component this={statusIcon(batch)} class="size-4" />
                    </span>
                    <div class="min-w-0">
                      <p class="truncate font-medium text-foreground">{batch.filename}</p>
                      {#if batch.retained_file}
                        <p class="mt-1 truncate text-xs text-muted-foreground">Source retained: {batch.source_file_label}</p>
                      {:else}
                        <p class="mt-1 text-xs text-muted-foreground">Source file not retained</p>
                      {/if}
                      {#if batch.notes}
                        <p class="mt-1 max-w-sm truncate text-xs text-destructive">{batch.notes}</p>
                      {/if}
                    </div>
                  </div>
                </TableCell>
                <TableCell>
                  <Badge variant={badgeVariant(batch.status)}>{batch.status_label}</Badge>
                </TableCell>
                <TableCell class="text-right tabular-nums">{batch.rows_count}</TableCell>
                <TableCell class="text-right tabular-nums">{batch.transactions_count}</TableCell>
                <TableCell class="text-right tabular-nums">{batch.skipped_count}</TableCell>
                <TableCell>
                  <p class="text-sm text-foreground">{batch.created_at_label}</p>
                  <p class="text-xs text-muted-foreground">{batch.created_at_time_label}</p>
                </TableCell>
                <TableCell>
                  {#if batch.imported_at_label}
                    <p class="text-sm text-foreground">{batch.imported_at_label}</p>
                    <p class="text-xs text-muted-foreground">{batch.imported_at_time_label}</p>
                  {:else}
                    <span class="text-sm text-muted-foreground">Not finished</span>
                  {/if}
                </TableCell>
                <TableCell>
                  <div class="flex justify-end gap-2">
                    <Button href={batch.preview_path} variant={batch.unfinished ? "default" : "outline"} size="sm">{batch.unfinished ? "Resume" : "View"}</Button>
                    {#if batch.download_path}
                      <Button href={batch.download_path} variant="outline" size="icon-sm" aria-label={`Download ${batch.filename}`}>
                        <Download class="size-3.5" />
                      </Button>
                    {/if}
                  </div>
                </TableCell>
              </TableRow>
            {/each}
          </TableBody>
        </Table>
      </div>
    {/if}
  </CardContent>
</Card>
