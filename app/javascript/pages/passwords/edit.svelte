<script>
  import { router } from "@inertiajs/svelte"
  import { Button } from "$lib/components/ui/button"
  import { Card, CardContent, CardHeader, CardTitle } from "$lib/components/ui/card"
  import { Input } from "$lib/components/ui/input"
  import { Label } from "$lib/components/ui/label"
  import AuthLayout from "../AuthLayout.svelte"

  export let actions

  let password = ""
  let passwordConfirmation = ""

  function submit() {
    router.put(actions.password, {
      password,
      password_confirmation: passwordConfirmation,
    })
  }
</script>

<AuthLayout>
  <Card>
    <CardHeader>
      <CardTitle class="text-2xl">Update your password</CardTitle>
      <p class="text-sm text-muted-foreground">Choose a new password for this account.</p>
    </CardHeader>

    <CardContent>
      <form class="space-y-5" on:submit|preventDefault={submit}>
        <div class="space-y-1.5">
          <Label for="password">New password</Label>
          <Input id="password" type="password" required autocomplete="new-password" placeholder="Enter new password" maxlength="72" bind:value={password} />
        </div>

        <div class="space-y-1.5">
          <Label for="password_confirmation">Repeat new password</Label>
          <Input id="password_confirmation" type="password" required autocomplete="new-password" placeholder="Repeat new password" maxlength="72" bind:value={passwordConfirmation} />
        </div>

        <Button type="submit" class="w-full">Save</Button>
      </form>
    </CardContent>
  </Card>
</AuthLayout>
