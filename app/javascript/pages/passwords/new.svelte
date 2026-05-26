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
</script>

<AuthLayout>
  <Card>
    <CardHeader>
      <CardTitle class="text-2xl">Forgot your password?</CardTitle>
      <p class="text-sm text-muted-foreground">Send reset instructions to your admin email address.</p>
    </CardHeader>

    <CardContent>
      <form class="space-y-5" on:submit|preventDefault={() => router.post(actions.passwords, { email_address: email })}>
        <div class="space-y-1.5">
          <Label for="email_address">Email</Label>
          <Input id="email_address" type="email" required autofocus autocomplete="username" placeholder="Enter your email address" bind:value={email} />
        </div>

        <Button type="submit" class="w-full">Email reset instructions</Button>
      </form>
    </CardContent>
  </Card>
</AuthLayout>
