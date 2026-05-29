<script>
  import { router } from "@inertiajs/svelte"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Input } from "$lib/components/ui/input"
  import { Label } from "$lib/components/ui/label"
  import BriefcaseBusiness from "@lucide/svelte/icons/briefcase-business"
  import Bot from "@lucide/svelte/icons/bot"
  import Gauge from "@lucide/svelte/icons/gauge"
  import MailPlus from "@lucide/svelte/icons/mail-plus"
  import AdminBreadcrumbs from "../AdminBreadcrumbs.svelte"

  export let metrics
  export let users = []
  export let invitations = []
  export let actions

  let email_address = ""

  function inviteUser() {
    router.post(actions.invite, { user_invitation: { email_address } }, {
      preserveScroll: true,
      onSuccess: () => {
        email_address = ""
      },
    })
  }
</script>

<svelte:head>
  <title>Admin - Transactions</title>
</svelte:head>

<div class="space-y-6">
  <AdminBreadcrumbs items={[{ label: "Admin" }]} />

  <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
    <div>
      <p class="text-sm font-semibold uppercase text-primary">Control plane</p>
      <h1 class="mt-1 text-3xl font-semibold tracking-normal text-foreground">Admin</h1>
      <p class="mt-2 max-w-2xl text-sm leading-6 text-muted-foreground">Manage access, inspect app-level AI spend, and jump into operational tools.</p>
    </div>

    <div class="flex flex-wrap gap-2">
      <a href={actions.jobs} data-turbo="false" target="_blank" rel="noreferrer">
        <Button type="button" variant="outline"><BriefcaseBusiness class="size-4" /> Jobs</Button>
      </a>
      {#if actions.email_previews}
        <a href={actions.email_previews} target="_blank" rel="noreferrer">
          <Button type="button" variant="outline">Email previews</Button>
        </a>
      {/if}
      {#if actions.first_time_flow_preview}
        <Button type="button" variant="outline" onclick={() => router.visit(actions.first_time_flow_preview)}>First-time flow</Button>
      {/if}
      <Button type="button" variant="outline" onclick={() => router.visit(actions.ai_controls)}><Gauge class="size-4" /> AI controls</Button>
      <Button type="button" variant="outline" onclick={() => router.visit(actions.models)}><Bot class="size-4" /> Models</Button>
    </div>
  </div>

  <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
    <Card>
      <CardHeader>
        <p class="text-xs font-medium uppercase text-muted-foreground">Users</p>
        <CardTitle class="text-2xl">{metrics.user_count}</CardTitle>
      </CardHeader>
    </Card>
    <Card>
      <CardHeader>
        <p class="text-xs font-medium uppercase text-muted-foreground">Admins</p>
        <CardTitle class="text-2xl">{metrics.admin_count}</CardTitle>
      </CardHeader>
    </Card>
    <Card>
      <CardHeader>
        <p class="text-xs font-medium uppercase text-muted-foreground">Pending invites</p>
        <CardTitle class="text-2xl">{metrics.pending_invitation_count}</CardTitle>
      </CardHeader>
    </Card>
    <Card>
      <CardHeader>
        <p class="text-xs font-medium uppercase text-muted-foreground">Total AI spend</p>
        <CardTitle class="money-value text-2xl">{metrics.total_ai_spend_label}</CardTitle>
      </CardHeader>
    </Card>
  </div>

  <Card>
    <CardHeader>
      <CardTitle class="text-lg">Invite user</CardTitle>
    </CardHeader>
    <CardContent>
      <form class="grid gap-3 sm:grid-cols-[1fr_auto] sm:items-end" on:submit|preventDefault={inviteUser}>
        <div class="space-y-1.5">
          <Label for="invite-email">Email</Label>
          <Input id="invite-email" type="email" required bind:value={email_address} autocomplete="email" />
        </div>
        <Button type="submit"><MailPlus class="size-4" /> Send invite</Button>
      </form>
    </CardContent>
  </Card>

  <Card>
    <CardHeader>
      <CardTitle class="text-lg">Users</CardTitle>
    </CardHeader>
    <CardContent>
      <div class="overflow-x-auto">
        <table class="w-full min-w-[760px] text-left text-sm">
          <thead class="border-b border-border text-xs uppercase text-muted-foreground">
            <tr>
              <th class="py-2 pr-4 font-medium">Email</th>
              <th class="py-2 pr-4 font-medium">Role</th>
              <th class="py-2 pr-4 font-medium">Transactions</th>
              <th class="py-2 pr-4 font-medium">AI spend</th>
              <th class="py-2 pr-4 font-medium">CSV reminder</th>
              <th class="py-2 font-medium">Created</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-border">
            {#each users as user}
              <tr>
                <td class="py-3 pr-4 font-medium text-foreground">{user.email_address}</td>
                <td class="py-3 pr-4 text-muted-foreground">{user.role_label}</td>
                <td class="py-3 pr-4 text-muted-foreground">{user.transaction_count}</td>
                <td class="money-value py-3 pr-4 text-muted-foreground">{user.ai_spend_label}</td>
                <td class="py-3 pr-4 text-muted-foreground">{user.csv_reminder_label}</td>
                <td class="py-3 text-muted-foreground">{user.created_at_label}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </CardContent>
  </Card>

  <Card>
    <CardHeader>
      <CardTitle class="text-lg">Recent invitations</CardTitle>
    </CardHeader>
    <CardContent>
      <div class="grid gap-2">
        {#each invitations as invitation}
          <div class="grid gap-1 rounded-lg border border-border bg-background p-3 text-sm sm:grid-cols-[1fr_auto] sm:items-center">
            <div>
              <p class="font-medium text-foreground">{invitation.email_address}</p>
              <p class="text-muted-foreground">Invited {invitation.created_at_label}; expires {invitation.expires_at_label}</p>
            </div>
            <p class="font-medium text-muted-foreground">{invitation.status}</p>
          </div>
        {:else}
          <p class="text-sm text-muted-foreground">No invitations yet.</p>
        {/each}
      </div>
    </CardContent>
  </Card>
</div>
