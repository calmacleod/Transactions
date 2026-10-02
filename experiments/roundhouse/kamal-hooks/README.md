# Experimental deployment hooks

This directory intentionally has no executable hooks. The production
`.kamal/hooks/post-app-boot` warms a Rails server on port 3000; that hook does
not apply to the native service on port 3901. Kamal checks the native `/up`
endpoint before routing traffic. `verify-deployment` checks the public HTTPS
service, normal sign-in and page rendering after deployment.

Production keeps its existing hook directory.
