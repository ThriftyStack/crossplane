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

`authentik_system_settings.this` mirrors the live system settings read on
2026-11-10 and imports as `system_settings`. The provider PUTs every attribute
on create and update, so a value changed in the UI is reverted here unless it is
also changed in `main.tf`. It exists for `default_user_change_email = false`.
Users cannot change their own email, so the opt-in `email_verified` OAuth2 flag
can truthfully send `email_verified: true` through the "Homelab
administrator-managed email" scope mapping. Vaultwarden is the only app using
that flag: 1.37.5 refuses an SSO signup unless the claim is `true`, and
Authentik's managed email mapping always sends `false`.

Vaultwarden's client needs Vault `infra/authentik/clients` keys
`vaultwarden-client-id` and `vaultwarden` before this applies, or the provider
preconditions fail. The same pair goes into gcloud-home-infra's
`infra/oke/vaultwarden`.
