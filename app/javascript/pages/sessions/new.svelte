<script>
  import { router } from "@inertiajs/svelte"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Input } from "$lib/components/ui/input"
  import { Label } from "$lib/components/ui/label"
  import AuthLayout from "../AuthLayout.svelte"

  export let email_address = ""
  export let actions

  let email = email_address || ""
  let password = ""

  function submit() {
    router.post(actions.session, { email_address: email, password })
  }
</script>

<AuthLayout>
  <Card>
    <CardHeader>
      <p class="text-xs font-semibold uppercase tracking-wider text-primary">Admin access</p>
      <CardTitle class="text-2xl">Sign in</CardTitle>
      <p class="text-sm leading-6 text-muted-foreground">Use the admin credential seeded from your environment.</p>
    </CardHeader>

    <CardContent>
      <form class="space-y-5" on:submit|preventDefault={submit}>
        <div class="space-y-1.5">
          <Label for="email_address">Email</Label>
          <Input id="email_address" type="email" required autofocus autocomplete="username" bind:value={email} />
        </div>

        <div class="space-y-1.5">
          <Label for="password">Password</Label>
          <Input id="password" type="password" required autocomplete="current-password" maxlength="72" bind:value={password} />
        </div>

        <Button type="submit" class="w-full">Sign in</Button>
      </form>
      <Button type="button" variant="ghost" class="mt-3 w-full" onclick={() => router.visit(actions.new_registration)}>Join with invitation</Button>
    </CardContent>
  </Card>
</AuthLayout>
