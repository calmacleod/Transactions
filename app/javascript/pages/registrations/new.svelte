<script>
  import { router, usePage } from "@inertiajs/svelte"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Input } from "$lib/components/ui/input"
  import { Label } from "$lib/components/ui/label"
  import AuthLayout from "../AuthLayout.svelte"

  export let email_address = ""
  export let invite_code = ""
  export let actions

  const page = usePage()
  $: auth = page.props.auth || {}

  let form = {
    email_address: email_address || "",
    invite_code: invite_code || "",
    password: "",
    password_confirmation: "",
  }

  function submit() {
    router.post(actions.registration, { user: form })
  }

  function signOutToAcceptInvite() {
    router.delete(actions.session, {
      data: { return_to: `${window.location.pathname}${window.location.search}` },
    })
  }
</script>

<AuthLayout>
  {#if auth.authenticated}
    <Card>
      <CardHeader>
        <p class="text-xs font-semibold uppercase tracking-wider text-primary">Already signed in</p>
        <CardTitle class="text-2xl">Accept invitation?</CardTitle>
        <p class="text-sm leading-6 text-muted-foreground">
          You are signed in as {auth.email}. Sign out first to create an account with this invitation.
        </p>
      </CardHeader>

      <CardContent class="space-y-3">
        <Button type="button" class="w-full" onclick={signOutToAcceptInvite}>Sign out and continue</Button>
        <Button type="button" variant="ghost" class="w-full" onclick={() => router.visit(actions.root)}>Stay signed in</Button>
      </CardContent>
    </Card>
  {:else}
    <Card>
      <CardHeader>
        <p class="text-xs font-semibold uppercase tracking-wider text-primary">Invitation required</p>
        <CardTitle class="text-2xl">Join Transactions</CardTitle>
        <p class="text-sm leading-6 text-muted-foreground">Create an account with the one-time code from your invitation email.</p>
      </CardHeader>

      <CardContent>
        <form class="space-y-5" on:submit|preventDefault={submit}>
          <div class="space-y-1.5">
            <Label for="email_address">Email</Label>
            <Input id="email_address" type="email" required autofocus autocomplete="username" bind:value={form.email_address} />
          </div>

          <div class="space-y-1.5">
            <Label for="invite_code">One-time code</Label>
            <Input id="invite_code" type="text" required autocomplete="one-time-code" bind:value={form.invite_code} />
          </div>

          <div class="space-y-1.5">
            <Label for="password">Password</Label>
            <Input id="password" type="password" required autocomplete="new-password" maxlength="72" bind:value={form.password} />
          </div>

          <div class="space-y-1.5">
            <Label for="password_confirmation">Confirm password</Label>
            <Input id="password_confirmation" type="password" required autocomplete="new-password" maxlength="72" bind:value={form.password_confirmation} />
          </div>

          <Button type="submit" class="w-full">Create account</Button>
        </form>

        <Button type="button" variant="ghost" class="mt-3 w-full" onclick={() => router.visit(actions.new_session)}>Back to sign in</Button>
      </CardContent>
    </Card>
  {/if}
</AuthLayout>
