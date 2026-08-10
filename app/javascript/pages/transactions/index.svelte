<script>
  import { onMount, tick } from "svelte"
  import { router } from "@inertiajs/svelte"
  import { Badge } from "$lib/components/ui/badge"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Input } from "$lib/components/ui/input"
  import { Label } from "$lib/components/ui/label"
  import { NativeSelect, NativeSelectOption } from "$lib/components/ui/native-select"
  import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "$lib/components/ui/table"
  import { withQuery } from "$lib/formatters"
  import DatePicker from "../components/DatePicker.svelte"
  import Check from "@lucide/svelte/icons/check"
  import ChevronDown from "@lucide/svelte/icons/chevron-down"
  import ChevronUp from "@lucide/svelte/icons/chevron-up"
  import History from "@lucide/svelte/icons/history"
  import MessageSquare from "@lucide/svelte/icons/message-square"
  import NotebookPen from "@lucide/svelte/icons/notebook-pen"
  import Search from "@lucide/svelte/icons/search"
  import X from "@lucide/svelte/icons/x"
  import CategoryPicker from "./CategoryPicker.svelte"

  const BULK_CATEGORY_KEEP = "__keep__"
  const BULK_CATEGORY_CLEAR = "__clear__"
  const TRANSACTION_RESULT_PROPS = [
    "selected_saved_query_id",
    "filter_params",
    "filter_active",
    "date_summary",
    "sort",
    "transactions",
    "pagination",
    "per_page",
    "flash",
  ]
  const TRANSACTION_MUTATION_PROPS = ["transactions", "pagination", "flash"]

  export let categories = []
  export let subcategories = []
  export let saved_queries = []
  export let selected_saved_query_id = null
  export let filter_params = {}
  export let quick_ranges = []
  export let filter_active = false
  export let date_summary = ""
  export let transactions = []
  export let pagination
  export let sort = { field: "date", direction: "desc" }
  export let per_page
  export let per_page_options = []
  export let actions

  let filters = { ...filter_params, saved_query_id: selected_saved_query_id || "" }
  let saveName = ""
  let selectedIds = new Set()
  let bulkCategoryId = BULK_CATEGORY_KEEP
  let bulkSubcategoryId = ""
  let chatQuestion = ""
  let chatAnswer = ""
  let chatSource = ""
  let chatLoading = false
  let chatOpen = false
  let currentChatId = null
  let currentChatTitle = ""
  let chatMessages = []
  let chatTransactionIds = []
  let chatTransactions = []
  let chatReferencedTransactions = []
  let chatFocusedTransactionId = null
  let chatSubscription = null
  let chatHistoryOpen = false
  let chatHistory = []
  let chatHistoryLoading = false
  let chatHistoryLoaded = false
  let cableConsumer = null
  let chatRuntimePromise = null
  let markdownRuntimePromise = null
  let markdownParser = null
  let markdownSanitizer = null
  let filtersOpen = filter_active
  let dragSelecting = false
  let dragSelectionMode = null
  let editingNoteIds = new Set()
  let editingSubcategoryIds = new Set()
  let shiftDown = false
  let lastShiftHoverId = null
  let suppressNextRowClick = false
  let desktopLayout = typeof window !== "undefined" ? window.matchMedia("(min-width: 768px)").matches : true

  $: selectedTransactions = transactions.filter((transaction) => selectedIds.has(transaction.id))
  $: selectedTotal = selectedTransactions.reduce((sum, transaction) => sum + Number(transaction.signed_amount_cents || 0), 0)
  $: allVisibleSelected = transactions.length > 0 && transactions.every((transaction) => selectedIds.has(transaction.id))
  $: bulkHasAction = bulkCategoryId !== BULK_CATEGORY_KEEP || Boolean(bulkSubcategoryId)
  $: activeFilterLabels = Object.entries(compact(filter_params))
    .filter(([key]) => !["sort", "sort_direction"].includes(key))
    .map(([key, value]) => `${key.replaceAll("_", " ")}: ${value}`)
  $: referencedTransactionIds = referencedIdsFromMessages(chatMessages)
  $: referencedTransactions = mergedReferencedTransactions(chatReferencedTransactions, chatTransactions, referencedTransactionIds)

  onMount(() => {
    const layoutMedia = window.matchMedia("(min-width: 768px)")
    const updateLayout = () => (desktopLayout = layoutMedia.matches)
    const stopDrag = () => {
      dragSelecting = false
      dragSelectionMode = null
      lastShiftHoverId = null
    }

    const selectRowUnderPointer = (event) => {
      if (!dragSelecting) return
      if ((event.buttons & 1) === 0) {
        stopDrag()
        return
      }

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
    layoutMedia.addEventListener("change", updateLayout)
    window.addEventListener("keydown", handleKeyDown, true)
    window.addEventListener("keyup", handleKeyUp, true)
    window.addEventListener("blur", stopDrag)
    updateLayout()

    return () => {
      chatSubscription?.unsubscribe()
      cableConsumer?.disconnect()
      document.removeEventListener("pointermove", selectRowUnderPointer)
      document.removeEventListener("pointerup", stopDrag)
      layoutMedia.removeEventListener("change", updateLayout)
      window.removeEventListener("keydown", handleKeyDown, true)
      window.removeEventListener("keyup", handleKeyUp, true)
      window.removeEventListener("blur", stopDrag)
    }
  })

  function applyFilters() {
    visitTransactions(actions.index, compact(filters))
  }

  function preventAndRun(event, callback) {
    event.preventDefault()
    callback()
  }

  function clearFilters() {
    visitTransactions(actions.index)
  }

  function quickRange(value) {
    const params = { ...filter_params, quick_range: value }
    delete params.start_date
    delete params.end_date
    visitTransactions(actions.index, params)
  }

  function visitTransactions(url, data = {}) {
    const scrollPosition = { x: window.scrollX, y: window.scrollY }

    router.get(url, data, {
      only: TRANSACTION_RESULT_PROPS,
      preserveScroll: true,
      preserveState: true,
      onSuccess: (page) => syncTransactionProps(page.props),
      onFinish: () => restoreScrollPosition(scrollPosition),
    })
  }

  function visitTransactionsPath(path) {
    const scrollPosition = { x: window.scrollX, y: window.scrollY }

    router.visit(path, {
      only: TRANSACTION_RESULT_PROPS,
      preserveScroll: true,
      preserveState: true,
      onSuccess: (page) => syncTransactionProps(page.props),
      onFinish: () => restoreScrollPosition(scrollPosition),
    })
  }

  function syncTransactionProps(nextProps) {
    categories = nextProps.categories || categories
    subcategories = nextProps.subcategories || subcategories
    saved_queries = nextProps.saved_queries || saved_queries
    selected_saved_query_id = nextProps.selected_saved_query_id || null
    filter_params = nextProps.filter_params || {}
    quick_ranges = nextProps.quick_ranges || quick_ranges
    filter_active = Boolean(nextProps.filter_active)
    date_summary = nextProps.date_summary || ""
    transactions = nextProps.transactions || []
    pagination = nextProps.pagination || pagination
    sort = nextProps.sort || sort
    per_page = nextProps.per_page || per_page
    per_page_options = nextProps.per_page_options || per_page_options
    actions = nextProps.actions || actions
    filters = { ...filter_params, saved_query_id: selected_saved_query_id || "" }
  }

  function restoreScrollPosition(position) {
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => window.scrollTo(position.x, position.y))
    })
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
    if (!dragSelecting) return
    if ((event.buttons & 1) === 0) {
      dragSelecting = false
      dragSelectionMode = null
      lastShiftHoverId = null
      return
    }

    shiftDown = event.shiftKey || event.getModifierState?.("Shift") || shiftDown
    applyTransactionSelection(transaction.id, dragSelectionMode)
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

  function runRowControl(event, callback) {
    event.stopPropagation()
    callback()
  }

  function updateCategory(transaction, categoryId) {
    router.patch(transaction.update_path, { expense_transaction: { category_id: categoryId } }, { only: TRANSACTION_MUTATION_PROPS, preserveScroll: true, preserveState: true })
  }

  function updateTransactionField(transaction, field, value) {
    if ((transaction[field] || "") === (value || "")) return

    transaction[field] = value
    router.patch(transaction.update_path, { expense_transaction: { [field]: value } }, { only: TRANSACTION_MUTATION_PROPS, preserveScroll: true, preserveState: true })
  }

  function sortPath(field) {
    const currentField = sort?.field || "date"
    const currentDirection = sort?.direction || "desc"
    const nextDirection = currentField === field && currentDirection === "desc" ? "asc" : "desc"

    return withQuery(actions.index, { ...filter_params, saved_query_id: selected_saved_query_id, limit: per_page, sort: field, sort_direction: nextDirection })
  }

  function sortTransactions(field) {
    visitTransactionsPath(sortPath(field))
  }

  function toggleNoteEditor(transaction) {
    const next = new Set(editingNoteIds)
    next.has(transaction.id) ? next.delete(transaction.id) : next.add(transaction.id)
    editingNoteIds = next
  }

  async function openSubcategoryEditor(transaction) {
    const next = new Set(editingSubcategoryIds)
    next.add(transaction.id)
    editingSubcategoryIds = next

    await tick()
    const select = document.querySelector(`[data-subcategory-select-id="${transaction.id}"]`)
    select?.focus()
    try {
      select?.showPicker?.()
    } catch (_error) {
      // Browser support and user-activation rules vary; focus still lands on the select.
    }
  }

  function closeSubcategoryEditor(transaction) {
    if (!editingSubcategoryIds.has(transaction.id)) return

    window.setTimeout(() => {
      const next = new Set(editingSubcategoryIds)
      next.delete(transaction.id)
      editingSubcategoryIds = next
    }, 0)
  }

  function transactionSubcategoryIds(transaction) {
    return (transaction.subcategories || []).map((subcategory) => subcategory.id)
  }

  function addSubcategory(transaction, subcategoryId) {
    if (!subcategoryId) return

    const selected = subcategories.find((subcategory) => `${subcategory.id}` === `${subcategoryId}`)
    if (!selected) return

    const currentIds = transactionSubcategoryIds(transaction)
    const nextIds = currentIds.includes(selected.id) ? currentIds : [...currentIds, selected.id]
    transaction.subcategories = subcategories.filter((subcategory) => nextIds.includes(subcategory.id))
    updateTransactionSubcategories(transaction, nextIds)
  }

  function removeSubcategory(transaction, subcategoryId) {
    const nextIds = transactionSubcategoryIds(transaction).filter((id) => id !== subcategoryId)
    transaction.subcategories = (transaction.subcategories || []).filter((subcategory) => subcategory.id !== subcategoryId)
    updateTransactionSubcategories(transaction, nextIds)
  }

  function updateTransactionSubcategories(transaction, nextIds) {
    const next = new Set(editingSubcategoryIds)
    next.delete(transaction.id)
    editingSubcategoryIds = next
    router.patch(transaction.update_path, { expense_transaction: { subcategory_ids: nextIds } }, { only: TRANSACTION_MUTATION_PROPS, preserveScroll: true, preserveState: true })
  }

  function saveNote(transaction, value) {
    updateTransactionField(transaction, "notes", value)
    const next = new Set(editingNoteIds)
    next.delete(transaction.id)
    editingNoteIds = next
  }

  function sortIcon(field) {
    if ((sort?.field || "date") !== field) return null
    return sort?.direction === "asc" ? ChevronUp : ChevronDown
  }

  async function openChat(transactionIds = []) {
    await ensureMarkdownRuntime()

    chatOpen = true
    chatQuestion = ""
    chatAnswer = ""
    chatSource = ""
    chatMessages = []
    currentChatId = null
    currentChatTitle = ""
    chatTransactionIds = transactionIds
    chatTransactions = transactions.filter((transaction) => transactionIds.includes(transaction.id))
    chatReferencedTransactions = []
    chatFocusedTransactionId = null
  }

  async function openChatHistory() {
    chatHistoryOpen = true
    await loadChatHistory(true)
  }

  async function loadChatHistory(force = false) {
    if (!actions.chats || (chatHistoryLoaded && !force)) return

    chatHistoryLoading = true
    try {
      const response = await fetch(actions.chats, { headers: { "Accept": "application/json" } })
      if (!response.ok) return

      const data = await response.json()
      chatHistory = data.chats || []
      chatHistoryLoaded = true
    } finally {
      chatHistoryLoading = false
    }
  }

  async function openExistingChat(chatId) {
    await ensureChatRuntime()

    chatHistoryOpen = false
    chatOpen = true
    chatAnswer = ""
    chatSource = ""
    chatLoading = false
    currentChatId = chatId
    chatFocusedTransactionId = null
    await loadChat(chatId)
    await subscribeToChat(chatId)
  }

  async function askChat() {
    const question = chatQuestion.trim()
    if (!question) return
    await ensureMarkdownRuntime()

    chatOpen = true
    chatLoading = true
    chatAnswer = ""
    chatSource = ""
    const temporaryId = `pending-${Date.now()}`
    chatMessages = [
      ...chatMessages,
      { id: `${temporaryId}-user`, role: "user", content: question, status: "complete", metadata: {} },
      { id: `${temporaryId}-assistant`, role: "assistant", content: "", status: "queued", metadata: {} },
    ]
    chatQuestion = ""

    try {
      const response = await fetch(actions.chat, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || "",
          "Accept": "application/json",
        },
        body: JSON.stringify({
          question,
          filters: compact(filter_params),
          transaction_ids: chatTransactionIds.length ? chatTransactionIds : Array.from(selectedIds),
          chat_id: currentChatId,
        }),
      })
      const data = await response.json()
      currentChatId = data.chat_id || currentChatId
      chatMessages = data.messages || chatMessages
      chatAnswer = data.answer || ""
      chatSource = data.source || ""
      if (currentChatId) {
        await subscribeToChat(currentChatId)
        loadChatHistory(true)
      }
    } catch (_error) {
      chatAnswer = "The chat request failed before Rails returned a response."
      chatSource = "automatic"
      chatMessages = chatMessages.map((message) => message.id === `${temporaryId}-assistant` ? { ...message, status: "failed", content: chatAnswer } : message)
    } finally {
      chatLoading = false
    }
  }

  async function subscribeToChat(chatId) {
    if (chatSubscription?.chatId === chatId) return

    await ensureChatRuntime()

    chatSubscription?.unsubscribe()
    chatSubscription = cableConsumer.subscriptions.create(
      { channel: "AiChatChannel", chat_id: chatId },
      {
        received(data) {
          handleChatEvent(data)
        },
      }
    )
    chatSubscription.chatId = chatId
    refreshChat(chatId)
  }

  async function ensureChatRuntime() {
    if (!chatRuntimePromise) {
      chatRuntimePromise = Promise.all([
        ensureMarkdownRuntime(),
        import("@rails/actioncable"),
      ]).then(([, cable]) => {
        cableConsumer = cableConsumer || cable.createConsumer()
      })
    }

    await chatRuntimePromise
  }

  async function ensureMarkdownRuntime() {
    if (!markdownRuntimePromise) {
      markdownRuntimePromise = Promise.all([
        import("marked"),
        import("dompurify"),
      ]).then(([markedModule, domPurifyModule]) => {
        markdownParser = markedModule.marked
        markdownSanitizer = domPurifyModule.default || domPurifyModule
      })
    }

    await markdownRuntimePromise
  }

  async function refreshChat(chatId) {
    if (!chatId) return

    await loadChat(chatId)
  }

  async function loadChat(chatId) {
    if (!actions.chat_template || !chatId) return

    const response = await fetch(actions.chat_template.replace(":id", chatId), { headers: { "Accept": "application/json" } })
    if (!response.ok) return

    const data = await response.json()
    currentChatTitle = data.title || currentChatTitle
    chatTransactionIds = data.transaction_ids || chatTransactionIds
    chatTransactions = data.transactions || chatTransactions
    chatReferencedTransactions = data.referenced_transactions || chatReferencedTransactions
    chatMessages = data.messages || chatMessages
  }

  function handleChatEvent(data) {
    if (data.type === "message" || data.type === "message_update") {
      upsertChatMessage(data.message)
      if (data.type === "message_update" && data.message?.role === "assistant" && data.message?.status === "complete") {
        refreshChat(currentChatId)
      }
    }
  }

  function upsertChatMessage(message) {
    const index = chatMessages.findIndex((existing) => existing.id === message.id)
    if (index === -1) {
      chatMessages = [...chatMessages, message]
    } else {
      chatMessages = chatMessages.map((existing, position) => position === index ? message : existing)
    }
  }

  function messageText(message) {
    if (message.content) return message.content
    if (message.role === "assistant" && ["queued", "thinking"].includes(message.status)) return "Thinking..."
    if (message.role === "tool" && message.status === "thinking") return "Running tool..."
    return ""
  }

  function messageClasses(message) {
    if (message.role === "user") return "ml-auto max-w-[85%] bg-primary text-primary-foreground"
    if (message.role === "tool") return "mx-auto max-w-[90%] border border-dashed border-border bg-muted text-muted-foreground"
    return "mr-auto max-w-[90%] bg-background text-foreground"
  }

  function messageRoleLabel(message) {
    if (message.role === "user") return "You"
    if (message.role === "tool") return message.metadata?.name ? message.metadata.name.replaceAll("_", " ") : "Tool"
    return "Assistant"
  }

  function renderMarkdown(message) {
    const source = messageText(message)
    if (!source) return ""
    if (!markdownParser || !markdownSanitizer) return escapeHtml(source)

    const html = markdownParser.parse(source, { gfm: true, breaks: true, async: false })
    const sanitized = markdownSanitizer.sanitize(html, { USE_PROFILES: { html: true } })

    return sanitized.replace(/\[\[transaction:(\d+)\]\]/gi, (_match, id) => {
      const safeId = Number.parseInt(id, 10)
      if (!Number.isFinite(safeId)) return ""

      return `<button type="button" class="chat-transaction-reference" data-transaction-reference-id="${safeId}">${transactionReferenceLabel(safeId)}</button>`
    })
  }

  function escapeHtml(value) {
    return value.replace(/[&<>"']/g, (character) => {
      return {
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        "\"": "&quot;",
        "'": "&#39;",
      }[character]
    })
  }

  function referencedIdsFromMessages(messages) {
    const ids = new Set()

    messages.forEach((message) => {
      ;(message.metadata?.referenced_transaction_ids || []).forEach((id) => ids.add(Number(id)))
      for (const match of message.content?.matchAll(/\[\[transaction:(\d+)\]\]/gi) || []) {
        ids.add(Number(match[1]))
      }
    })

    return Array.from(ids).filter(Number.isFinite)
  }

  function mergedReferencedTransactions(serverTransactions, attachedTransactions, ids) {
    const byId = new Map()
    ;[...serverTransactions, ...attachedTransactions].forEach((transaction) => {
      if (ids.includes(transaction.id)) byId.set(transaction.id, transaction)
    })

    return ids.map((id) => byId.get(id)).filter(Boolean)
  }

  function transactionReferenceLabel(id) {
    const transaction = [...chatReferencedTransactions, ...chatTransactions].find((item) => item.id === id)
    if (!transaction) return `Transaction #${id}`

    return `${transaction.short_date_label} · ${transaction.amount_label}`
  }

  function handleRenderedMessageClick(event) {
    const reference = event.target.closest?.("[data-transaction-reference-id]")
    if (!reference) return

    const id = Number.parseInt(reference.dataset.transactionReferenceId, 10)
    if (!Number.isFinite(id)) return

    event.preventDefault()
    chatFocusedTransactionId = id
    requestAnimationFrame(() => {
      document.querySelector(`[data-chat-transaction-id="${id}"]`)?.scrollIntoView({ block: "nearest", behavior: "smooth" })
    })
  }

  function focusChatTransaction(id) {
    chatFocusedTransactionId = id
  }

  function openSelectedChat() {
    const transactionIds = Array.from(selectedIds)
    openChat(transactionIds)
    selectedIds = new Set()
  }

  function transactionDescription(transaction) {
    return transaction.merchant_name || transaction.description
  }

  function transactionCategoryLabel(transaction) {
    const category = transaction.category?.name || "Unclassified"
    const subcategories = (transaction.subcategories || []).map((subcategory) => subcategory.name)

    return [category, ...subcategories].join(" / ")
  }

  function bulkUpdate() {
    if (!bulkHasAction) return

    const bulkTransaction = {
      transaction_ids: Array.from(selectedIds),
    }

    if (bulkCategoryId !== BULK_CATEGORY_KEEP) {
      bulkTransaction.category_id = bulkCategoryId === BULK_CATEGORY_CLEAR ? "" : bulkCategoryId
    }

    if (bulkSubcategoryId) {
      bulkTransaction.subcategory_ids = [bulkSubcategoryId]
    }

    router.patch(actions.bulk_update, {
      bulk_transaction: bulkTransaction,
    }, { only: TRANSACTION_MUTATION_PROPS, preserveScroll: true, preserveState: true })
  }

  function saveFilter() {
    if (!saveName.trim()) return
    router.post(actions.save_query, { name: saveName, filters: compact(filter_params) }, { preserveScroll: true, preserveState: true })
  }

  function destroySavedQuery(query) {
    router.delete(query.destroy_path, { preserveScroll: true, preserveState: true })
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
        <Button type="button" size="sm" variant="outline" class="ml-auto" onclick={() => (filtersOpen = !filtersOpen)}>
          {filtersOpen ? "Hide filters" : "Show filters"}
        </Button>
        <Button type="button" size="sm" variant="ghost" onclick={clearFilters}>Clear</Button>
      </div>
      {#if !filtersOpen}
        <div class="mt-3 flex flex-wrap gap-2 text-xs text-muted-foreground">
          {#if activeFilterLabels.length}
            {#each activeFilterLabels as label}
              <Badge variant="secondary">{label}</Badge>
            {/each}
          {:else}
            <span>No filters applied</span>
          {/if}
        </div>
      {/if}
    </CardHeader>

    {#if filtersOpen}
    <CardContent>
      <form class="grid gap-4" onsubmit={(event) => preventAndRun(event, applyFilters)}>
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
            <DatePicker id="start_date" bind:value={filters.start_date} ariaLabel="Select start date" />
          </div>
          <div class="space-y-1.5">
            <Label for="end_date">To</Label>
            <DatePicker id="end_date" bind:value={filters.end_date} ariaLabel="Select end date" />
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
            <Label for="subcategory">Subcategory</Label>
            <NativeSelect id="subcategory" bind:value={filters.subcategory_id} class="w-full">
              <NativeSelectOption value="">Any subcategory</NativeSelectOption>
              {#each subcategories as subcategory}
                <NativeSelectOption value={subcategory.id}>{subcategory.name}</NativeSelectOption>
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
    {/if}
  </Card>

  <section class="mb-4 grid gap-3 xl:grid-cols-[minmax(0,1fr)_420px]">
    {#if filter_active}
      <Card>
        <CardContent class="text-sm text-muted-foreground">{date_summary}</CardContent>
      </Card>
    {/if}

    <Card class={filter_active ? "" : "xl:col-start-2"}>
      <CardContent>
        <form class="flex gap-2" onsubmit={(event) => preventAndRun(event, saveFilter)}>
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
          <button type="button" class="px-3 py-1.5 hover:text-foreground" onclick={() => visitTransactionsPath(query.path)}>{query.name}</button>
          <button type="button" class="border-l border-border px-2.5 py-1.5 text-muted-foreground hover:text-foreground" aria-label={`Delete ${query.name}`} onclick={() => destroySavedQuery(query)}>
            <X class="size-3" />
          </button>
        </Badge>
      {/each}
    </section>
  {/if}

  <Card class="mb-4">
    <CardHeader class="border-b border-border">
      <div class="flex items-center gap-2">
        <MessageSquare class="size-4 text-primary" />
        <CardTitle class="text-sm">Discuss transactions</CardTitle>
      </div>
    </CardHeader>
    <CardContent class="grid gap-3">
      <form class="flex flex-col gap-2 lg:flex-row" onsubmit={(event) => preventAndRun(event, askChat)}>
        <Input bind:value={chatQuestion} placeholder={selectedIds.size ? `Ask about ${selectedIds.size} selected transactions...` : "Ask about the current filtered set..."} class="min-w-0 flex-1" onfocus={() => { if (selectedIds.size) chatTransactionIds = Array.from(selectedIds) }} />
        <Button type="submit" disabled={chatLoading}>{chatLoading ? "Asking..." : "Ask"}</Button>
        <Button type="button" variant="outline" onclick={() => openChat(Array.from(selectedIds))}>{selectedIds.size ? "Open selected chat" : "Open chat"}</Button>
        <Button type="button" variant="outline" onclick={openChatHistory}>
          <History class="size-4" />
          Past chats
        </Button>
      </form>
      {#if chatAnswer}
        <div class="rounded-lg border border-border bg-background px-3 py-2 text-sm leading-6 text-foreground">
          <div class="mb-1 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{chatSource === "ai" ? "AI generated" : "Automatic"}</div>
          {chatAnswer}
        </div>
      {/if}
    </CardContent>
  </Card>

  {#if chatHistoryOpen}
    <div class="fixed inset-0 z-50 grid place-items-end bg-background/70 p-3 backdrop-blur-sm lg:p-6" role="dialog" aria-modal="true" aria-label="Past transaction chats" tabindex="-1" onclick={() => (chatHistoryOpen = false)} onkeydown={(event) => { if (event.key === "Escape") chatHistoryOpen = false }}>
      <Card class="flex max-h-[82vh] w-full max-w-xl flex-col overflow-hidden" onclick={(event) => event.stopPropagation()}>
        <CardHeader class="border-b border-border">
          <div class="flex items-center gap-3">
            <History class="size-4 text-primary" />
            <div class="min-w-0 flex-1">
              <CardTitle class="text-sm">Past chats</CardTitle>
              <p class="mt-1 text-xs text-muted-foreground">Reopen a saved transaction conversation.</p>
            </div>
            <Button type="button" variant="ghost" size="icon" aria-label="Close past chats" onclick={() => (chatHistoryOpen = false)}>
              <X class="size-4" />
            </Button>
          </div>
        </CardHeader>
        <CardContent class="min-h-0 overflow-y-auto p-0">
          {#if chatHistoryLoading && !chatHistory.length}
            <p class="px-4 py-8 text-center text-sm text-muted-foreground">Loading chats...</p>
          {:else if chatHistory.length}
            <div class="divide-y divide-border">
              {#each chatHistory as chat}
                <button type="button" class="grid w-full gap-1 px-4 py-3 text-left hover:bg-muted/60" onclick={() => openExistingChat(chat.id)}>
                  <div class="flex min-w-0 items-center justify-between gap-3">
                    <span class="truncate text-sm font-medium text-foreground">{chat.title}</span>
                    <span class="shrink-0 text-xs text-muted-foreground">{chat.updated_at_label}</span>
                  </div>
                  <div class="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                    <span>{chat.transaction_count} transactions</span>
                    <span>{chat.message_count} messages</span>
                    {#if chat.model}
                      <span>{chat.model}</span>
                    {/if}
                  </div>
                  {#if chat.last_message}
                    <p class="line-clamp-2 text-xs leading-5 text-muted-foreground">{chat.last_message}</p>
                  {/if}
                </button>
              {/each}
            </div>
          {:else}
            <p class="px-4 py-8 text-center text-sm text-muted-foreground">No saved chats yet.</p>
          {/if}
        </CardContent>
      </Card>
    </div>
  {/if}

  {#if chatOpen}
    <div class="fixed inset-0 z-50 grid place-items-end bg-background/70 p-3 backdrop-blur-sm lg:p-6" role="dialog" aria-modal="true" aria-label="Transaction chat" tabindex="-1" onclick={() => (chatOpen = false)} onkeydown={(event) => { if (event.key === "Escape") chatOpen = false }}>
      <Card class="flex max-h-[92vh] w-full max-w-5xl flex-col overflow-hidden" onclick={(event) => event.stopPropagation()}>
        <CardHeader class="border-b border-border">
          <div class="flex items-center gap-3">
            <MessageSquare class="size-4 text-primary" />
            <div class="min-w-0 flex-1">
              <CardTitle class="truncate text-sm">{currentChatTitle || "Transaction chat"}</CardTitle>
              <p class="mt-1 text-xs text-muted-foreground">
                {chatTransactionIds.length ? `${chatTransactionIds.length} selected records attached` : "Filtered records attached"}
                {#if referencedTransactions.length}
                  · {referencedTransactions.length} referenced
                {/if}
              </p>
            </div>
            <Button type="button" variant="ghost" size="icon" aria-label="Close chat" onclick={() => (chatOpen = false)}>
              <X class="size-4" />
            </Button>
          </div>
        </CardHeader>
        <CardContent class="grid min-h-0 flex-1 gap-3 overflow-hidden p-3 lg:grid-cols-[minmax(0,1fr)_20rem] lg:p-4">
          <div class="flex min-h-0 flex-col gap-3">
            <div class="min-h-72 flex-1 space-y-4 overflow-y-auto rounded-lg border border-border bg-background p-3">
              {#if chatMessages.length}
                {#each chatMessages as message}
                  <div class={`rounded-lg px-3 py-2 text-sm leading-6 shadow-xs ${messageClasses(message)}`} data-status={message.status}>
                    <div class="mb-1 flex items-center gap-2 text-[11px] font-semibold uppercase tracking-wide opacity-70">
                      <span>{messageRoleLabel(message)}</span>
                      {#if ["queued", "thinking"].includes(message.status)}
                        <span class="inline-flex size-2 rounded-full bg-current opacity-70 animate-pulse"></span>
                      {/if}
                    </div>
                    {#if message.role === "assistant"}
                      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
                      <div class="chat-markdown prose prose-sm max-w-none dark:prose-invert" onclick={handleRenderedMessageClick}>
                        {@html renderMarkdown(message)}
                      </div>
                    {:else if message.role === "tool"}
                      <p class="text-xs uppercase tracking-wide">{messageText(message)}</p>
                    {:else}
                      <p class="whitespace-pre-wrap">{messageText(message)}</p>
                    {/if}
                  </div>
                {/each}
              {:else if chatAnswer}
                <div class="mr-auto max-w-[90%] rounded-lg bg-background px-3 py-2 text-sm leading-6 text-foreground">{chatAnswer}</div>
              {:else}
                <p class="px-2 py-8 text-center text-sm text-muted-foreground">Ask a question to start a saved conversation with these records attached.</p>
              {/if}
            </div>
            <form class="flex flex-col gap-2 sm:flex-row" onsubmit={(event) => preventAndRun(event, askChat)}>
              <Input bind:value={chatQuestion} placeholder="Ask a follow-up..." class="min-w-0 flex-1" />
              <Button type="submit" disabled={chatLoading}>{chatLoading ? "Asking..." : "Send"}</Button>
            </form>
          </div>

          <aside class="min-h-0 overflow-hidden rounded-lg border border-border bg-background">
            <div class="border-b border-border px-3 py-2">
              <h2 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Referenced transactions</h2>
            </div>
            <div class="max-h-56 space-y-2 overflow-y-auto p-2 lg:max-h-full">
              {#if referencedTransactions.length}
                {#each referencedTransactions as transaction}
                  <button
                    type="button"
                    class={`grid w-full gap-1 rounded-md border px-2 py-2 text-left transition-colors ${chatFocusedTransactionId === transaction.id ? "border-primary/50 bg-accent" : "border-border bg-background hover:bg-muted"}`}
                    data-chat-transaction-id={transaction.id}
                    onclick={() => focusChatTransaction(transaction.id)}
                  >
                    <div class="flex min-w-0 items-center justify-between gap-2">
                      <span class="truncate text-xs font-medium text-foreground">{transactionDescription(transaction)}</span>
                      <span class={`money-value shrink-0 text-xs font-semibold ${transaction.amount_class}`}>{transaction.amount_label}</span>
                    </div>
                    <div class="flex min-w-0 flex-wrap items-center gap-1.5 text-[11px] text-muted-foreground">
                      <span>{transaction.short_date_label}</span>
                      <span>{transactionCategoryLabel(transaction)}</span>
                    </div>
                  </button>
                {/each}
              {:else}
                <p class="px-2 py-6 text-center text-xs leading-5 text-muted-foreground">No specific transactions have been cited in this chat yet.</p>
              {/if}
            </div>
          </aside>
        </CardContent>
      </Card>
    </div>
  {/if}

  <Card class="mb-4 overflow-hidden">
    {#if !desktopLayout}
    <div class="divide-y divide-border" data-testid="mobile-transactions-list">
      {#if transactions.length}
        {#each transactions as transaction (transaction.id)}
          <div
            data-testid="mobile-transaction-row"
            class={`grid gap-2 px-3 py-2 ${selectedIds.has(transaction.id) ? "bg-accent" : ""}`}
            aria-pressed={selectedIds.has(transaction.id)}
          >
            <div class="grid grid-cols-[auto_minmax(0,1fr)_auto] items-start gap-2">
              <input type="checkbox" class="mt-0.5 size-4 rounded border-input accent-primary" aria-label={`Select ${transaction.description}`} checked={selectedIds.has(transaction.id)} onchange={() => toggleTransaction(transaction.id)} />
              <div class="min-w-0">
                <div class="flex min-w-0 items-center gap-2">
                  <span class="whitespace-nowrap text-xs font-medium text-muted-foreground">{transaction.occurred_on_label}</span>
                </div>
                <p class="mt-1 break-words text-sm font-medium leading-5 text-foreground" title={transaction.description}>{transaction.merchant_name || transaction.description}</p>
              </div>
              <p class={`money-value text-right text-sm font-semibold ${transaction.amount_class}`}>{transaction.amount_label}</p>
            </div>

            <div class="grid grid-cols-[1rem_minmax(0,1fr)] gap-2">
              <span aria-hidden="true"></span>
              <div class="grid gap-2">
                <CategoryPicker {categories} {transaction} className="h-9 w-full text-xs" selectClass="h-9 w-full text-xs" onChange={updateCategory} />
                <div class="flex flex-wrap items-center gap-1.5">
                  {#each transaction.subcategories || [] as subcategory}
                    <span class="inline-flex h-6 items-center gap-1.5 rounded-full border border-border bg-background px-2 text-xs font-medium text-foreground">
                      <span class="size-2 rounded-full" style={`background-color: ${subcategory.color}`}></span>
                      {subcategory.name}
                      <button type="button" class="text-muted-foreground hover:text-foreground" aria-label={`Remove ${subcategory.name}`} onpointerdown={(event) => event.stopPropagation()} onclick={(event) => runRowControl(event, () => removeSubcategory(transaction, subcategory.id))}>x</button>
                    </span>
                  {/each}
                  {#if editingSubcategoryIds.has(transaction.id)}
                    <NativeSelect value="" class="h-8 w-40 shrink-0 text-xs" data-subcategory-select-id={transaction.id} onpointerdown={(event) => event.stopPropagation()} onclick={(event) => event.stopPropagation()} onchange={(event) => addSubcategory(transaction, event.currentTarget.value)} onblur={() => closeSubcategoryEditor(transaction)}>
                      <NativeSelectOption value="">Add subcategory</NativeSelectOption>
                      {#each subcategories as subcategory}
                        {#if !transactionSubcategoryIds(transaction).includes(subcategory.id)}
                          <NativeSelectOption value={subcategory.id}>{subcategory.name}</NativeSelectOption>
                        {/if}
                      {/each}
                    </NativeSelect>
                  {:else}
                    <button type="button" class="inline-flex h-6 w-fit items-center gap-1.5 rounded-full border border-dashed border-border bg-background px-2 text-xs font-medium text-muted-foreground hover:bg-muted hover:text-foreground" onpointerdown={(event) => event.stopPropagation()} onclick={(event) => runRowControl(event, () => openSubcategoryEditor(transaction))}>
                      Add subcategory
                    </button>
                  {/if}
                  <span
                    class="mobile-confidence-chip inline-flex h-5 min-w-0 max-w-24 items-center truncate rounded-full px-2 text-[11px] font-medium"
                    style={confidenceStyle(transaction.confidence_label)}
                    data-pending={transaction.confidence_label === "Pending" ? "true" : undefined}
                  >
                    {transaction.confidence_label}
                  </span>
                  {#if !transaction.notes && !editingNoteIds.has(transaction.id)}
                    <button type="button" class="inline-flex h-6 w-fit items-center gap-1 rounded-md px-1 text-xs font-medium text-muted-foreground hover:bg-muted hover:text-foreground" onpointerdown={(event) => event.stopPropagation()} onclick={(event) => runRowControl(event, () => toggleNoteEditor(transaction))}>
                      <NotebookPen class="size-3.5" />
                      Add note
                    </button>
                  {/if}
                </div>
                {#if transaction.notes && !editingNoteIds.has(transaction.id)}
                  <div class="flex items-start gap-2 rounded-md bg-muted px-2 py-1.5 text-xs leading-5 text-muted-foreground">
                    <NotebookPen class="mt-0.5 size-3.5 shrink-0" />
                    <p class="min-w-0 flex-1 break-words">{transaction.notes}</p>
                    <button type="button" class="shrink-0 font-medium text-primary hover:underline" onpointerdown={(event) => event.stopPropagation()} onclick={(event) => runRowControl(event, () => toggleNoteEditor(transaction))}>Edit</button>
                  </div>
                {:else if editingNoteIds.has(transaction.id)}
                  <textarea class="min-h-16 w-full rounded-md border border-input bg-background px-3 py-2 text-xs shadow-xs outline-none transition-[color,box-shadow] focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50" placeholder="Notes" onpointerdown={(event) => event.stopPropagation()} onclick={(event) => event.stopPropagation()} onblur={(event) => saveNote(transaction, event.currentTarget.value)}>{transaction.notes || ""}</textarea>
                {/if}
              </div>
            </div>
          </div>
        {/each}
      {:else}
        <p class="px-4 py-8 text-center text-sm text-muted-foreground">No matching transactions.</p>
      {/if}
    </div>
    {/if}

    {#if desktopLayout}
    <div>
      <Table class="min-w-[64rem] table-fixed">
        <TableHeader>
          <TableRow>
            <TableHead class="w-16 pl-6 pr-4">
              <input type="checkbox" class="size-4 rounded border-input accent-primary" aria-label="Select all visible transactions" checked={allVisibleSelected} onchange={toggleAll} />
            </TableHead>
            <TableHead class="w-36">
              <Button type="button" variant="ghost" size="sm" class="-ml-2 h-7 px-2" onclick={() => sortTransactions("date")}>
                Date
                {#if sortIcon("date")}
                  <svelte:component this={sortIcon("date")} class="size-3.5" />
                {/if}
              </Button>
            </TableHead>
            <TableHead>Description</TableHead>
            <TableHead class="w-56">Category</TableHead>
            <TableHead class="w-32 text-right">
              <Button type="button" variant="ghost" size="sm" class="ml-auto h-7 px-2" onclick={() => sortTransactions("amount")}>
                Amount
                {#if sortIcon("amount")}
                  <svelte:component this={sortIcon("amount")} class="size-3.5" />
                {/if}
              </Button>
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {#if transactions.length}
            {#each transactions as transaction (transaction.id)}
              <TableRow
                data-transaction-row-id={transaction.id}
                class={`${selectedIds.has(transaction.id) ? "bg-accent" : ""} ${dragSelecting ? "cursor-cell select-none hover:bg-primary/10" : ""}`}
                onpointerdown={(event) => startRowDrag(event, transaction)}
                onpointerenter={(event) => hoverRow(event, transaction)}
                onpointermove={(event) => hoverRow(event, transaction)}
              >
                <TableCell class="w-16 py-1.5 pl-6 pr-3">
                  <input type="checkbox" class="size-4 rounded border-input accent-primary" aria-label={`Select ${transaction.description}`} checked={selectedIds.has(transaction.id)} onchange={() => toggleTransaction(transaction.id)} />
                </TableCell>
                <TableCell class="w-32 whitespace-nowrap py-1.5 text-xs text-muted-foreground">{transaction.occurred_on_label}</TableCell>
                <TableCell class="min-w-0 whitespace-normal py-1.5">
                  <div class="min-w-0">
                    <p class="min-w-0 break-words text-sm font-medium leading-5 text-foreground" title={transaction.description}>{transaction.merchant_name || transaction.description}</p>
                  </div>
                  <div class="mt-1 flex min-w-0 flex-wrap items-center gap-1.5">
                    {#each transaction.subcategories || [] as subcategory}
                      <span class="inline-flex h-5 shrink-0 items-center gap-1.5 rounded-full border border-border bg-background px-2 text-[11px] font-medium text-foreground">
                        <span class="size-2 rounded-full" style={`background-color: ${subcategory.color}`}></span>
                        {subcategory.name}
                        <button type="button" class="text-muted-foreground hover:text-foreground" aria-label={`Remove ${subcategory.name}`} onpointerdown={(event) => event.stopPropagation()} onclick={(event) => runRowControl(event, () => removeSubcategory(transaction, subcategory.id))}>x</button>
                      </span>
                    {/each}
                    {#if editingSubcategoryIds.has(transaction.id)}
                      <NativeSelect value="" class="h-7 w-36 shrink-0 text-xs" data-subcategory-select-id={transaction.id} onpointerdown={(event) => event.stopPropagation()} onclick={(event) => event.stopPropagation()} onchange={(event) => addSubcategory(transaction, event.currentTarget.value)} onblur={() => closeSubcategoryEditor(transaction)}>
                        <NativeSelectOption value="">Add subcategory</NativeSelectOption>
                        {#each subcategories as subcategory}
                          {#if !transactionSubcategoryIds(transaction).includes(subcategory.id)}
                            <NativeSelectOption value={subcategory.id}>{subcategory.name}</NativeSelectOption>
                          {/if}
                        {/each}
                      </NativeSelect>
                    {:else}
                      <button type="button" class="inline-flex h-5 shrink-0 items-center rounded-full border border-dashed border-border bg-background px-2 text-[11px] font-medium text-muted-foreground hover:bg-muted hover:text-foreground" onpointerdown={(event) => event.stopPropagation()} onclick={(event) => runRowControl(event, () => openSubcategoryEditor(transaction))}>
                          Add subcategory
                      </button>
                    {/if}
                    <span
                      class="confidence-chip inline-flex h-5 shrink-0 items-center rounded-full px-2 text-[11px] font-medium"
                      style={confidenceStyle(transaction.confidence_label)}
                      data-pending={transaction.confidence_label === "Pending" ? "true" : undefined}
                      title={transaction.classification_reason || undefined}
                    >
                      {transaction.confidence_label}
                    </span>
                    {#if !transaction.notes && !editingNoteIds.has(transaction.id)}
                      <button type="button" class="inline-flex h-6 shrink-0 items-center gap-1 rounded-md px-1 text-xs font-medium text-muted-foreground hover:bg-muted hover:text-foreground" onpointerdown={(event) => event.stopPropagation()} onclick={(event) => runRowControl(event, () => toggleNoteEditor(transaction))}>
                        <NotebookPen class="size-3.5" />
                        Add note
                      </button>
                    {/if}
                  </div>
                  {#if transaction.notes && !editingNoteIds.has(transaction.id)}
                    <div class="mt-1 flex items-start gap-2 rounded-md bg-muted px-2 py-1.5 text-xs leading-5 text-muted-foreground">
                      <NotebookPen class="mt-0.5 size-3.5 shrink-0" />
                      <p class="min-w-0 flex-1 break-words">{transaction.notes}</p>
                      <button type="button" class="shrink-0 font-medium text-primary hover:underline" onpointerdown={(event) => event.stopPropagation()} onclick={(event) => runRowControl(event, () => toggleNoteEditor(transaction))}>Edit</button>
                    </div>
                  {:else if editingNoteIds.has(transaction.id)}
                    <textarea class="mt-2 min-h-14 w-full rounded-md border border-input bg-background px-3 py-2 text-xs shadow-xs outline-none transition-[color,box-shadow] focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50" placeholder="Personal notes" onpointerdown={(event) => event.stopPropagation()} onclick={(event) => event.stopPropagation()} onblur={(event) => saveNote(transaction, event.currentTarget.value)}>{transaction.notes || ""}</textarea>
                  {/if}
                </TableCell>
                <TableCell class="w-48 py-1.5">
                  <CategoryPicker {categories} {transaction} className="h-7 w-40 text-xs" selectClass="h-7 w-40 text-xs" onChange={updateCategory} />
                </TableCell>
                <TableCell class={`money-value py-1.5 pr-6 text-right text-sm font-semibold ${transaction.amount_class}`}>{transaction.amount_label}</TableCell>
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
    {/if}

    <div class="flex flex-col gap-3 border-t border-border px-4 py-3 text-sm text-muted-foreground lg:flex-row lg:items-center">
      <p>
        {#if pagination.count > 0}
          Showing <span class="money-value font-semibold text-foreground">{pagination.from}-{pagination.to}</span> of <span class="money-value font-semibold text-foreground">{pagination.count}</span>
        {:else}
          Showing <span class="money-value font-semibold text-foreground">0</span> records
        {/if}
      </p>

      <form class="flex items-center gap-2 lg:ml-auto" onchange={(event) => visitTransactionsPath(withQuery(actions.index, { ...filter_params, saved_query_id: selected_saved_query_id, limit: event.currentTarget.limit.value }))}>
        <Label for="limit">Rows</Label>
        <NativeSelect id="limit" name="limit" value={per_page} class="w-24">
          {#each per_page_options as option}
            <NativeSelectOption value={option.value}>{option.label}</NativeSelectOption>
          {/each}
        </NativeSelect>
      </form>

      {#if pagination.pages > 1}
        <nav class="flex flex-wrap gap-1" aria-label="Transactions pages">
          {#if pagination.prev_path}<Button type="button" variant="outline" size="sm" onclick={() => visitTransactionsPath(pagination.prev_path)}>Previous</Button>{/if}
          {#each pagination.pages_series as page}
            {#if page.gap}
              <span class="px-2 py-1">...</span>
            {:else}
              <Button type="button" variant={page.current ? "default" : "outline"} size="sm" aria-current={page.current ? "page" : undefined} onclick={() => visitTransactionsPath(page.path)}>{page.label}</Button>
            {/if}
          {/each}
          {#if pagination.next_path}<Button type="button" variant="outline" size="sm" onclick={() => visitTransactionsPath(pagination.next_path)}>Next</Button>{/if}
        </nav>
      {/if}
    </div>
  </Card>

  {#if selectedIds.size && !chatOpen && !chatHistoryOpen}
    <Card class="fixed bottom-4 left-4 right-4 z-40 border-primary/30 shadow-2xl xl:left-[calc(16rem+1rem)]">
      <CardContent class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <p class="text-sm font-semibold text-foreground">{selectedIds.size} selected</p>
          <p class="text-xs text-muted-foreground">Total <span class="money-value font-semibold text-foreground">{formatSigned(selectedTotal)}</span></p>
        </div>

        <form class="flex flex-col gap-2 sm:flex-row sm:items-end" onsubmit={(event) => preventAndRun(event, bulkUpdate)}>
          <div class="space-y-1.5">
            <Label for="bulk-category">Category</Label>
            <NativeSelect id="bulk-category" bind:value={bulkCategoryId} class="w-full sm:w-56">
              <NativeSelectOption value={BULK_CATEGORY_KEEP}>No category change</NativeSelectOption>
              <NativeSelectOption value={BULK_CATEGORY_CLEAR}>Unclassified</NativeSelectOption>
              {#each categories as category}
                <NativeSelectOption value={category.id}>{category.name}</NativeSelectOption>
              {/each}
            </NativeSelect>
          </div>
          <div class="space-y-1.5">
            <Label for="bulk-subcategory">Add subcategory</Label>
            <NativeSelect id="bulk-subcategory" bind:value={bulkSubcategoryId} class="w-full sm:w-48">
              <NativeSelectOption value="">No subcategory</NativeSelectOption>
              {#each subcategories as subcategory}
                <NativeSelectOption value={subcategory.id}>{subcategory.name}</NativeSelectOption>
              {/each}
            </NativeSelect>
          </div>
          <Button type="submit" disabled={!bulkHasAction}>
            <Check class="size-4" />
            Apply
          </Button>
          <Button type="button" variant="outline" onclick={openSelectedChat}>
            <MessageSquare class="size-4" />
            Chat
          </Button>
          <Button type="button" variant="outline" onclick={() => (selectedIds = new Set())}>Clear</Button>
        </form>
      </CardContent>
    </Card>
  {/if}
