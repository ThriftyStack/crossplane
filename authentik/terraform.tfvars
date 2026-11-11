roles = {}

groups = {
  homelab_users = {
    name = "homelab-users"
  }
  homelab_admins = {
    name    = "homelab-admins"
    parents = ["homelab_users"]
  }
  bookstack_editors = {
    name    = "bookstack-editors"
    parents = ["homelab_users"]
  }
}

oauth2_apps = {
  grafana = {
    name   = "Grafana"
    group  = "Observability"
    scopes = ["openid", "profile", "email", "entitlements"]
    redirects = [
      { matching_mode = "strict", url = "https://grafana.adminio.biz/login/generic_oauth", redirect_uri_type = "authorization" },
      { matching_mode = "strict", url = "https://grafana.adminio.biz/logout", redirect_uri_type = "logout" },
    ]
    client_id     = { path = "authentik/clients", key = "grafana-client-id" }
    client_secret = { path = "authentik/clients", key = "grafana" }
    logout_method = "frontchannel"
    logout_uri    = "https://grafana.adminio.biz/logout"
    entitlements = {
      grafana_admins  = "Grafana Admins"
      grafana_editors = "Grafana Editors"
      grafana_viewers = "Grafana Viewers"
    }
  }
  vault = {
    name   = "Vault"
    group  = "Infrastructure"
    scopes = ["openid", "email", "groups"]
    redirects = [
      { matching_mode = "strict", url = "https://vault.devoops.uk/ui/vault/auth/authentik/oidc/callback", redirect_uri_type = "authorization" },
      { matching_mode = "strict", url = "http://localhost:8250/oidc/callback", redirect_uri_type = "authorization" },
    ]
    client_id     = { path = "authentik/clients", key = "vault-client-id" }
    client_secret = { path = "authentik/clients", key = "vault" }
    entitlements = {
      vault_admins = "Vault Admins"
    }
  }
  proxmox = {
    name   = "Proxmox"
    group  = "Infrastructure"
    scopes = ["openid", "profile", "email", "groups"]
    redirects = [
      { matching_mode = "strict", url = "https://pve.adminio.biz:8006", redirect_uri_type = "authorization" },
    ]
    client_id     = { path = "proxmox-oidc", key = "authentik-client-id" }
    client_secret = { path = "proxmox-oidc", key = "authentik" }
    # PVE maps this groups-claim value to group proxmox-admins-authentik.
    entitlements = {
      proxmox_admins = "proxmox-admins"
    }
  }
  # MinIO reads the groups claim as policy names, so entitlement names must be
  # exact MinIO policy names. A user with no entitlement is refused at login.
  minio = {
    name   = "MinIO"
    group  = "Infrastructure"
    scopes = ["openid", "profile", "email", "groups"]
    redirects = [
      { matching_mode = "strict", url = "https://minio-ui.adminio.biz:9001/oauth_callback", redirect_uri_type = "authorization" },
    ]
    client_id     = { path = "minio-oidc", key = "authentik-client-id" }
    client_secret = { path = "minio-oidc", key = "authentik" }
    entitlements = {
      minio_admins = "consoleAdmin"
    }
  }
  # BookStack maps these groups-claim values onto its Admin/Editor/Viewer roles
  # (gcloud-home-infra images/bookstack). Removal applies at the next login.
  bookstack = {
    name   = "BookStack"
    group  = "Documentation"
    scopes = ["openid", "profile", "email", "groups"]
    redirects = [
      { matching_mode = "strict", url = "https://bookstack.oci.devoops.uk/oidc/callback", redirect_uri_type = "authorization" },
    ]
    client_id     = { path = "authentik/clients", key = "bookstack-client-id" }
    client_secret = { path = "authentik/clients", key = "bookstack" }
    entitlements = {
      bookstack_admins  = "bookstack-admins"
      bookstack_editors = "bookstack-editors"
      bookstack_readers = "bookstack-readers"
    }
  }
  # Password manager (gcloud-home-infra k8s/oke/vaultwarden). SSO only; the
  # master password still decrypts the vault. offline_access gives Vaultwarden
  # the refresh token it needs to outlive the 10-minute access token.
  vaultwarden = {
    name   = "Vaultwarden"
    group  = "Security"
    scopes = ["openid", "profile", "email", "offline_access"]
    redirects = [
      { matching_mode = "strict", url = "https://passwords.oci.devoops.uk/identity/connect/oidc-signin", redirect_uri_type = "authorization" },
    ]
    client_id      = { path = "authentik/clients", key = "vaultwarden-client-id" }
    client_secret  = { path = "authentik/clients", key = "vaultwarden" }
    email_verified = true
    # Every SSO login asks for the YubiKey or TOTP (gcloud-home-infra
    # docs/plans/vaultwarden-hardening.md). Enrol a device before enabling.
    mfa = true
  }
}

# Longhorn was retired on OKE on 2026-11-08 (gcloud-home-infra ADR-0018). The
# outpost now fronts the estate-internal whoami, which has no login of its own
# and only echoes request headers, so any homelab user may see it.
proxy_apps = {
  whoami = {
    name          = "whoami (OKE internal)"
    group         = "Infrastructure"
    external_host = "https://whoami.oci.devoops.uk"
    internal_host = "http://whoami.whoami.svc.cluster.local"
  }
}

outposts = {
  oke = {
    name           = "oke"
    authentik_host = "https://auth.devoops.uk"
    providers      = ["whoami"]
  }
}

policies = {}

bindings = {
  grafana           = { target_type = "oauth2_app", target = "grafana", subject_type = "group", subject = "homelab_users" }
  vault             = { target_type = "oauth2_app", target = "vault", subject_type = "group", subject = "homelab_admins" }
  proxmox           = { target_type = "oauth2_app", target = "proxmox", subject_type = "group", subject = "homelab_admins" }
  proxmox_admins    = { target_type = "entitlement", target = "proxmox_admins", subject_type = "group", subject = "homelab_admins" }
  whoami            = { target_type = "proxy_app", target = "whoami", subject_type = "group", subject = "homelab_users" }
  grafana_admins    = { target_type = "entitlement", target = "grafana_admins", subject_type = "group", subject = "homelab_admins" }
  grafana_viewers   = { target_type = "entitlement", target = "grafana_viewers", subject_type = "group", subject = "homelab_users" }
  vault_admins      = { target_type = "entitlement", target = "vault_admins", subject_type = "group", subject = "homelab_admins" }
  minio             = { target_type = "oauth2_app", target = "minio", subject_type = "group", subject = "homelab_admins" }
  minio_admins      = { target_type = "entitlement", target = "minio_admins", subject_type = "group", subject = "homelab_admins" }
  bookstack         = { target_type = "oauth2_app", target = "bookstack", subject_type = "group", subject = "homelab_users" }
  bookstack_admins  = { target_type = "entitlement", target = "bookstack_admins", subject_type = "group", subject = "homelab_admins" }
  bookstack_editors = { target_type = "entitlement", target = "bookstack_editors", subject_type = "group", subject = "bookstack_editors" }
  bookstack_readers = { target_type = "entitlement", target = "bookstack_readers", subject_type = "group", subject = "homelab_users" }
  vaultwarden       = { target_type = "oauth2_app", target = "vaultwarden", subject_type = "group", subject = "homelab_users" }
}

# Live IDs of existing Authentik objects this root adopts.
adoption_ids = {
  proxmox_admins_entitlement  = "857de816-5a3f-4983-a0a2-e1007957112f"
  grafana_admins_entitlement  = "e47b1636-a985-4768-a5fc-9df3653571d8"
  grafana_editors_entitlement = "789f9a5a-2442-4c58-8cfb-942fd0f95b32"
  grafana_viewers_entitlement = "4f0a5760-e234-40ed-bf1a-d883bc9f9656"
  vault_admins_entitlement    = "8a99e26c-da65-4c22-9b4c-1f61f89b9461"
  grafana_provider            = "6"
  proxmox_provider            = "5"
  vault_provider              = "4"
  whoami_provider             = "40"
  oke_outpost                 = "729e49a1-6b9f-4776-a2bf-71c4a824d69e"
  entitlement_groups_scope    = "a5ebb0c0-0c96-4105-9e50-f6d08fb0e25c"
}
