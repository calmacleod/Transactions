<script>
  import { onDestroy, onMount, tick } from "svelte"
  import { Button } from "$lib/components/ui/button"
  import CalendarIcon from "@lucide/svelte/icons/calendar"
  import ChevronLeft from "@lucide/svelte/icons/chevron-left"
  import ChevronRight from "@lucide/svelte/icons/chevron-right"
  import X from "@lucide/svelte/icons/x"

  let nextDatePickerId = 0

  export let id = `date-picker-${++nextDatePickerId}`
  export let value = ""
  export let disabled = false
  export let placeholder = "Select date"
  export let ariaLabel = "Select date"
  export let onchange = null
  export let min = null
  export let max = null
  export let size = "default"

  let className = ""
  export { className as class }

  let open = false
  let viewDate = startOfMonth(parseIsoDate(value) || new Date())
  let rootRef
  let triggerRef
  let panelRef
  let panelStyle = ""

  $: selectedDate = parseIsoDate(value)
  $: monthLabel = new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric" }).format(viewDate)
  $: weeks = calendarWeeks(viewDate)
  $: label = selectedDate ? new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(selectedDate) : placeholder
  $: controlSizeClass = size === "sm" ? "h-7 rounded-[min(var(--radius-md),10px)] text-sm" : "h-8 rounded-lg text-base md:text-sm"

  onMount(() => {
    window.addEventListener("pointerdown", closeWhenOutside, true)
    window.addEventListener("resize", positionPanel)
    window.addEventListener("scroll", positionPanel, true)
  })

  onDestroy(() => {
    window.removeEventListener("pointerdown", closeWhenOutside, true)
    window.removeEventListener("resize", positionPanel)
    window.removeEventListener("scroll", positionPanel, true)
  })

  async function toggleOpen() {
    if (disabled) return

    open = !open
    if (open) {
      viewDate = startOfMonth(selectedDate || new Date())
      await tick()
      positionPanel()
    }
  }

  function closeWhenOutside(event) {
    if (!open) return
    if (rootRef?.contains(event.target) || panelRef?.contains(event.target)) return

    open = false
  }

  function positionPanel() {
    if (!open || !triggerRef) return

    const rect = triggerRef.getBoundingClientRect()
    const width = 288
    const gutter = 12
    const left = Math.min(Math.max(gutter, rect.left), window.innerWidth - width - gutter)
    panelStyle = `top: ${rect.bottom + 6}px; left: ${left}px; width: ${width}px;`
  }

  function previousMonth() {
    viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1)
  }

  function nextMonth() {
    viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1)
  }

  function chooseDate(day) {
    if (disabled || isOutOfRange(day.date)) return

    value = toIsoDate(day.date)
    open = false
    dispatchChange()
  }

  function chooseToday() {
    chooseDate({ date: new Date() })
  }

  function clearDate() {
    if (disabled) return

    value = ""
    open = false
    dispatchChange()
  }

  function dispatchChange() {
    onchange?.({ currentTarget: { value } })
  }

  function parseIsoDate(dateValue) {
    if (!dateValue) return null

    const [year, month, day] = String(dateValue).split("-").map(Number)
    if (!year || !month || !day) return null

    return new Date(year, month - 1, day)
  }

  function toIsoDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    return `${year}-${month}-${day}`
  }

  function startOfMonth(date) {
    return new Date(date.getFullYear(), date.getMonth(), 1)
  }

  function calendarWeeks(month) {
    const first = startOfMonth(month)
    const cursor = new Date(first)
    cursor.setDate(first.getDate() - first.getDay())

    return Array.from({ length: 6 }, () =>
      Array.from({ length: 7 }, () => {
        const date = new Date(cursor)
        cursor.setDate(cursor.getDate() + 1)

        return {
          date,
          iso: toIsoDate(date),
          inMonth: date.getMonth() === month.getMonth(),
          selected: value === toIsoDate(date),
          today: toIsoDate(date) === toIsoDate(new Date()),
        }
      })
    )
  }

  function isOutOfRange(date) {
    const iso = toIsoDate(date)
    return (min && iso < min) || (max && iso > max)
  }
</script>

<div class={`relative min-w-0 ${className}`} bind:this={rootRef}>
  <button
    bind:this={triggerRef}
    id={id}
    type="button"
    class={`border-input bg-background text-foreground focus-visible:border-ring focus-visible:ring-ring/50 flex w-full min-w-0 items-center justify-between gap-2 border px-2.5 py-1 text-left shadow-xs outline-none transition-colors focus-visible:ring-3 disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 ${controlSizeClass}`}
    aria-haspopup="dialog"
    aria-expanded={open}
    aria-label={ariaLabel}
    {disabled}
    onclick={toggleOpen}
  >
    <span class={`min-w-0 truncate ${selectedDate ? "" : "text-muted-foreground"}`}>{label}</span>
    <CalendarIcon class="size-4 shrink-0 text-muted-foreground" />
  </button>
</div>

{#if open}
  <div
    bind:this={panelRef}
    class="fixed z-[70] rounded-lg border border-border bg-popover p-3 text-popover-foreground shadow-xl"
    style={panelStyle}
    role="dialog"
    aria-modal="false"
    aria-label={ariaLabel}
  >
    <div class="mb-3 flex items-center justify-between gap-2">
      <Button type="button" variant="ghost" size="icon-sm" aria-label="Previous month" onclick={previousMonth}>
        <ChevronLeft class="size-4" />
      </Button>
      <p class="text-sm font-semibold text-foreground">{monthLabel}</p>
      <Button type="button" variant="ghost" size="icon-sm" aria-label="Next month" onclick={nextMonth}>
        <ChevronRight class="size-4" />
      </Button>
    </div>

    <div class="grid grid-cols-7 gap-1 text-center text-[0.7rem] font-semibold uppercase text-muted-foreground">
      {#each ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"] as day}
        <span class="py-1">{day}</span>
      {/each}
    </div>

    <div class="mt-1 grid gap-1">
      {#each weeks as week}
        <div class="grid grid-cols-7 gap-1">
          {#each week as day}
            <button
              type="button"
              class={`grid size-8 place-items-center rounded-md text-sm transition-colors ${day.selected ? "bg-primary text-primary-foreground" : day.today ? "border border-primary/50 text-foreground" : day.inMonth ? "text-foreground hover:bg-muted" : "text-muted-foreground/50 hover:bg-muted/60"} ${isOutOfRange(day.date) ? "cursor-not-allowed opacity-35 hover:bg-transparent" : ""}`}
              disabled={isOutOfRange(day.date)}
              aria-pressed={day.selected}
              onclick={() => chooseDate(day)}
            >
              {day.date.getDate()}
            </button>
          {/each}
        </div>
      {/each}
    </div>

    <div class="mt-3 flex items-center justify-between gap-2">
      <Button type="button" variant="ghost" size="sm" onclick={clearDate}>
        <X class="size-3.5" />
        Clear
      </Button>
      <Button type="button" variant="outline" size="sm" onclick={chooseToday}>Today</Button>
    </div>
  </div>
{/if}
