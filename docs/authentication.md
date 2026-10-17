# Authentication

Snowplow supports OAuth authorization code with PKCE for interactive console
sessions and OAuth client credentials for unattended automation. If no grant is
selected, `Connect-Snowplow` uses authorization code. Existing calls that supply
`-ClientCredential` continue to use client credentials.

| | Authorization code (+ PKCE) | Client credentials |
|---|---|---|
| Intended for | An administrator using Snowplow interactively | CI/CD, scheduled tasks, and other unattended automation |
| Identity | The signed-in human user | The user bound to the OAuth application; use a dedicated service account |
| Browser | Required, unless completing the printed URL manually | Not required |
| Secret handling | No client secret is sent from the workstation | Store the client ID and secret in SecretManagement or a CI secret store |
| Audit trail | Attributable to the signed-in person | Attributable to the service account |
| Avoid for | Headless jobs and CI | Day-to-day interactive work under a personal account |

Admins working interactively should use authorization code. Unattended work
should use client credentials bound to a dedicated, least-privilege service
account, never a named person's account. Never commit a client secret or place
one directly in a script.

## Authorization code with PKCE

In ServiceNow, open **System OAuth > Application Registry**, choose **New**, and
create an OAuth API endpoint for external clients. Configure the application as
a public client that uses PKCE, and register the redirect URI exactly as
`http://127.0.0.1:8765/callback`. Snowplow always uses S256 PKCE and validates
the returned state. Grant only the scopes and ServiceNow roles the administrator
needs. Set **Refresh token lifespan** to the duration appropriate for your
organization's reauthentication policy.

Connect with the client ID; no client secret is needed on the workstation:

```powershell
Connect-Snowplow -Instance dev12345 -ClientId '<oauth-client-id>'
```

Snowplow listens on `127.0.0.1:8765` for up to two minutes and opens the system
browser. Use another registered redirect port with `-RedirectPort`, for example:

```powershell
Connect-Snowplow -Instance dev12345 -ClientId '<oauth-client-id>' -RedirectPort 8766
```

Register the matching URI, `http://127.0.0.1:8766/callback`, in ServiceNow.
When `-NoBrowser` is used, Snowplow prints the authorization URL; complete sign-in
in a browser and paste the full redirect URL into the prompt. The URL includes
temporary authorization data, so do not share it.

Refresh tokens are persisted by default, keyed to the instance and client ID,
under Snowplow's per-user data directory. The directory and token file are
restricted to the current user on Unix-like systems; Windows uses the current
user's application data directory and its inherited permissions. The file
contains the refresh token as JSON and relies on those filesystem permissions
rather than encrypting it at rest. Removing the saved token file signs the
client out. Refresh tokens are bearer credentials: protect the account and
device, and set an appropriate **Refresh token lifespan** in ServiceNow.

## Client credentials

In **System OAuth > Application Registry**, create an OAuth API endpoint for
external clients and enable the client credentials grant. Bind it to a dedicated
ServiceNow service account with only the roles required for the automation.
Configure the required OAuth scopes and record the client ID and generated
client secret. Do not bind the application to a named administrator.

Store the client credential in a SecretManagement vault:

```powershell
$client = Get-Credential -UserName '<oauth-client-id>'
Set-Secret -Name SnowplowOAuth -Secret $client
Connect-Snowplow -Instance dev12345 -ClientCredentialSecretName SnowplowOAuth -ClientCredentials
```

Or pass a `PSCredential` supplied securely by your automation environment:

```powershell
Connect-Snowplow -Instance dev12345 -ClientCredential $client -ClientCredentials
```

For CI/CD, use the platform's secret store and an automation-specific service
account. Do not put client secrets in source control, command history, logs,
verbose/debug output, or error messages. For SecretManagement and SecretStore
setup, see [Linux with PowerShell](linux.md); the SecretManagement commands are
cross-platform.

## Troubleshooting

- **Redirect URI mismatch:** the scheme, host, port, and `/callback` path must
  match the URI registered in ServiceNow. If changing `-RedirectPort`, register
  the new port first.
- **Port in use or blocked:** choose another `-RedirectPort` and register its
  corresponding callback. A local firewall or endpoint policy may block the
  loopback listener.
- **No browser / SSH session:** use `-NoBrowser` and paste the complete callback
  URL from the browser. If there is no interactive user to complete sign-in,
  use client credentials instead.
- **Scope or access errors:** ensure the OAuth application grants the requested
  scopes and its user has the required ServiceNow roles and API access.
- **Expired or revoked refresh token:** Snowplow clears the rejected token and
  reports that you must run `Connect-Snowplow` again to sign in.
- **Sign out persisted authorization:** remove the per-user
  `oauth-tokens.json` file in Snowplow's data directory.
