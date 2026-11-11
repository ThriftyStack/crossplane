# Authentik identity

Manages Authentik groups, OAuth2 and proxy applications, entitlements, policy
bindings, and the `oke` proxy outpost via the Authentik API. Does not deploy
the Authentik containers or the outpost workload.

Group names follow [ADR-0001](https://www.notion.so/400972443c708191aafbc0a9a1f7dc8a):
`homelab-users` and `homelab-admins`. Proxmox consumes the entitlement name
`proxmox-admins` from the `groups` claim. whoami is a proxy provider on
outpost `oke` (Longhorn was retired on 2026-11-08, gcloud-home-infra ADR-0018).

`adoption_ids` in `terraform.tfvars` holds the live Proxmox, Grafana, and
Vault entitlement pbm uuids, the Grafana, Proxmox, and Vault OAuth2 provider
numeric pks, the whoami proxy provider numeric pk, the `oke` outpost uuid,
and the groups scope-mapping pk for the live mapping named Homelab application
entitlement groups. Grafana, Proxmox, Vault, and whoami applications import
by slug.
Imports use those values for objects that already exist. whoami has no
entitlements. Its external host is `https://whoami.oci.devoops.uk`, and the
`oke` outpost `authentik_host` is `https://auth.devoops.uk`.

Auth chain: projected service account token (audience `vault-oke`) → Vault
JWT role `crossplane-system_provider-opentofu` on mount `jwt-management` →
Vault `infra/authentik` key `tofu-api-token` → Authentik API.

Crossplane Workspace `authentik` applies this directory. Local validation is
`make check`. The Workspace sets `vault_addr` to `https://vault.devoops.uk`.
State stays in the GCS prefix `crossplane/authentik`.

The opt-in `email_verified` OAuth2 flag swaps the managed email mapping for
"Homelab administrator-managed email". That mapping sends `email_verified: true`
only while System > Settings forbids users from changing their own email
(`default_user_change_email`, false since before 2026-11-10). Vaultwarden is the
only app using the flag: 1.37.5 refuses an SSO signup unless the claim is
`true`, and Authentik's managed email mapping always sends `false`. The setting
is read at token time, not managed here. `authentik_system_settings` (provider
2026.5.1) cannot read a server whose `flags` object is empty: it fails with
"no value given for required property core_default_app_access", and that
failure blocked the whole Workspace.

The opt-in `mfa` OAuth2 flag gives that app's provider the authorization flow
`homelab-provider-authorization-mfa`. Its one stage asks for a WebAuthn or TOTP
device on every authorization, even inside an existing Authentik session, so
other apps keep their sign-in unchanged. A user with no enrolled device is
denied: the stage never offers enrolment, which would let a stolen password
register its own device. Enrol a device (User settings > MFA Devices) before
enabling the flag for an app you use. Vaultwarden is the only app using it.

Vaultwarden's client needs Vault `infra/authentik/clients` keys
`vaultwarden-client-id` and `vaultwarden` before this applies, or the provider
preconditions fail. The same pair goes into gcloud-home-infra's
`infra/oke/vaultwarden`.
