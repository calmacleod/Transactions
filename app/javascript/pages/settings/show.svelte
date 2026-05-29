<script>
  import { router } from "@inertiajs/svelte"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Checkbox } from "$lib/components/ui/checkbox"
  import { Label } from "$lib/components/ui/label"
  import { NativeSelect, NativeSelectOption } from "$lib/components/ui/native-select"

  export let reminder
  export let import_retention = { retain_uploaded_csv: true }
  export let days = []
  export let hours = []
  export let actions

  let form = {
    csv_reminder_enabled: reminder.enabled,
    csv_reminder_wday: reminder.wday,
    csv_reminder_hour: reminder.hour,
    retain_uploaded_csv: import_retention.retain_uploaded_csv,
  }

  function submit() {
    router.patch(actions.update, { user: form })
  }
</script>

<svelte:head>
  <title>Settings - Transactions</title>
</svelte:head>

<div class="mx-auto max-w-3xl space-y-6">
  <div>
    <p class="text-sm font-semibold uppercase text-primary">Preferences</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-normal text-foreground">Settings</h1>
    <p class="mt-2 text-sm leading-6 text-muted-foreground">Control upload reminders and CSV retention for your account.</p>
  </div>

  <Card>
    <CardHeader>
      <CardTitle class="text-lg">CSV reminder</CardTitle>
      <p class="text-sm leading-6 text-muted-foreground">Current schedule: {reminder.label}</p>
    </CardHeader>
    <CardContent>
      <form class="space-y-5" on:submit|preventDefault={submit}>
        <label class="flex items-center gap-3 rounded-lg border border-border bg-background p-3">
          <Checkbox bind:checked={form.csv_reminder_enabled} />
          <span>
            <span class="block text-sm font-medium text-foreground">Email me when new transaction data is due</span>
            <span class="block text-sm text-muted-foreground">Default delivery is Monday at 9:00 AM.</span>
          </span>
        </label>

        <div class="grid gap-4 sm:grid-cols-2">
          <div class="space-y-1.5">
            <Label for="reminder-day">Day</Label>
            <NativeSelect id="reminder-day" bind:value={form.csv_reminder_wday} class="w-full">
              {#each days as day}
                <NativeSelectOption value={day.value}>{day.label}</NativeSelectOption>
              {/each}
            </NativeSelect>
          </div>
          <div class="space-y-1.5">
            <Label for="reminder-hour">Time</Label>
            <NativeSelect id="reminder-hour" bind:value={form.csv_reminder_hour} class="w-full">
              {#each hours as hour}
                <NativeSelectOption value={hour.value}>{hour.label}</NativeSelectOption>
              {/each}
            </NativeSelect>
          </div>
        </div>

        {#if reminder.last_sent_at_label}
          <p class="text-sm text-muted-foreground">Last sent {reminder.last_sent_at_label}.</p>
        {/if}

        <Button type="submit">Save settings</Button>
      </form>
    </CardContent>
  </Card>

  <Card>
    <CardHeader>
      <CardTitle class="text-lg">Import files</CardTitle>
      <p class="text-sm leading-6 text-muted-foreground">Original CSV files are retained with each import batch so you can download and audit them later.</p>
    </CardHeader>
    <CardContent>
      <form class="space-y-5" on:submit|preventDefault={submit}>
        <label class="flex items-center gap-3 rounded-lg border border-border bg-background p-3">
          <Checkbox bind:checked={form.retain_uploaded_csv} />
          <span>
            <span class="block text-sm font-medium text-foreground">Keep uploaded CSV files</span>
            <span class="block text-sm text-muted-foreground">Turn this off to store only parsed import rows and transaction records.</span>
          </span>
        </label>

        <Button type="submit">Save settings</Button>
      </form>
    </CardContent>
  </Card>
</div>
