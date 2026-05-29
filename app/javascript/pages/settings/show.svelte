<script>
  import { onMount } from "svelte"
  import { router } from "@inertiajs/svelte"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Checkbox } from "$lib/components/ui/checkbox"
  import { Label } from "$lib/components/ui/label"
  import { NativeSelect, NativeSelectOption } from "$lib/components/ui/native-select"
  import { accentPresets, applyAccentColor, applyTheme, defaultAccentColor, resetAccentColor, saveAccentColor, storedAccentColor, storedTheme } from "$lib/theme"
  import RotateCcw from "@lucide/svelte/icons/rotate-ccw"

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
  let appearanceTheme = "light"
  let accentColor = defaultAccentColor
  let accentInput = defaultAccentColor

  onMount(() => {
    appearanceTheme = applyTheme(storedTheme())
    accentColor = applyAccentColor(storedAccentColor())
    accentInput = accentColor
  })

  function submit() {
    router.patch(actions.update, { user: form })
  }

  function submitSettings(event) {
    event.preventDefault()
    submit()
  }

  function setAppearanceTheme(value) {
    appearanceTheme = applyTheme(value)
  }

  function setAccentColor(value) {
    accentColor = saveAccentColor(value)
    accentInput = accentColor
  }

  function resetAccent() {
    accentColor = resetAccentColor()
    accentInput = accentColor
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
      <CardTitle class="text-lg">Appearance</CardTitle>
      <p class="text-sm leading-6 text-muted-foreground">Tune the app chrome for this browser.</p>
    </CardHeader>
    <CardContent>
      <div class="grid gap-5">
        <div class="grid gap-2">
          <Label>Mode</Label>
          <div class="inline-grid w-fit grid-cols-2 gap-1 rounded-lg border border-border bg-background p-1">
            <Button type="button" variant={appearanceTheme === "light" ? "default" : "ghost"} size="sm" aria-pressed={appearanceTheme === "light"} onclick={() => setAppearanceTheme("light")}>Light</Button>
            <Button type="button" variant={appearanceTheme === "dim" ? "default" : "ghost"} size="sm" aria-pressed={appearanceTheme === "dim"} onclick={() => setAppearanceTheme("dim")}>Dim</Button>
          </div>
        </div>

        <div class="grid gap-3">
          <Label for="accent-color">Accent color</Label>
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
            <div class="flex items-center gap-2">
              <input id="accent-color" type="color" class="h-9 w-12 rounded-lg border border-border bg-background p-1" bind:value={accentInput} oninput={(event) => setAccentColor(event.currentTarget.value)} aria-label="Accent color" />
              <input type="text" class="h-9 w-32 rounded-lg border border-input bg-background px-2.5 text-sm text-foreground outline-none transition-colors focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50" value={accentInput} oninput={(event) => (accentInput = event.currentTarget.value)} onchange={(event) => setAccentColor(event.currentTarget.value)} aria-label="Accent hex color" />
              <Button type="button" variant="outline" size="icon" aria-label="Reset accent color" onclick={resetAccent}>
                <RotateCcw class="size-4" />
              </Button>
            </div>
            <div class="flex flex-wrap gap-2">
              {#each accentPresets as preset}
                <button
                  type="button"
                  class={`size-8 rounded-lg border transition-all ${accentColor === preset.value ? "border-foreground ring-2 ring-ring/50 ring-offset-2 ring-offset-background" : "border-border hover:scale-105"}`}
                  style={`background: ${preset.value};`}
                  aria-label={`Use ${preset.name} accent`}
                  aria-pressed={accentColor === preset.value}
                  onclick={() => setAccentColor(preset.value)}
                >
                  <span class="sr-only">{preset.name}</span>
                </button>
              {/each}
            </div>
          </div>
          <div class="overflow-hidden rounded-lg border border-border bg-background">
            <div class="h-2 bg-gradient-to-r from-primary via-accent to-secondary"></div>
            <div class="flex items-center justify-between gap-3 p-3">
              <div class="min-w-0">
                <p class="text-sm font-medium text-foreground">Current accent</p>
                <p class="font-mono text-xs text-muted-foreground">{accentColor}</p>
              </div>
              <span class="grid size-9 shrink-0 place-items-center rounded-lg bg-primary text-primary-foreground shadow-sm">Aa</span>
            </div>
          </div>
        </div>
      </div>
    </CardContent>
  </Card>

  <Card>
    <CardHeader>
      <CardTitle class="text-lg">CSV reminder</CardTitle>
      <p class="text-sm leading-6 text-muted-foreground">Current schedule: {reminder.label}</p>
    </CardHeader>
    <CardContent>
      <form class="space-y-5" onsubmit={submitSettings}>
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
      <form class="space-y-5" onsubmit={submitSettings}>
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
