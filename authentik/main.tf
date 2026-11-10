module "roles" {
  source = "./modules/roles"

  roles = var.roles
}

module "groups" {
  source = "./modules/groups"

  groups   = var.groups
  role_ids = module.roles.ids
}

module "oauth2_apps" {
  source = "./modules/oauth2_apps"

  apps        = var.oauth2_apps
  vault_mount = var.vault_secret_mount
}

module "proxy_apps" {
  source = "./modules/proxy_apps"

  apps     = var.proxy_apps
  outposts = var.outposts
}

module "policies" {
  source = "./modules/policies"

  application_ids       = module.oauth2_apps.application_ids
  bindings              = var.bindings
  entitlement_ids       = merge(module.oauth2_apps.entitlement_ids, module.proxy_apps.entitlement_ids)
  group_ids             = module.groups.ids
  policies              = var.policies
  proxy_application_ids = module.proxy_apps.application_ids
}

# A singleton: create is a full PUT and destroy is a no-op, and the provider
# writes its own default for any attribute left out, so every value here
# mirrors the live settings read on 2026-11-10. The one that matters is
# default_user_change_email = false: it is what makes the verified_email
# mapping (oauth2_apps email_verified) a true statement.
resource "authentik_system_settings" "this" {
  avatars                      = "gravatar,initials"
  default_user_change_name     = true
  default_user_change_email    = false
  default_user_change_username = false
  event_retention              = "days=365"
  reputation_lower_limit       = -5
  reputation_upper_limit       = 5
  footer_links                 = []
  gdpr_compliance              = true
  impersonation                = true
  default_token_duration       = "minutes=30"
  default_token_length         = 60
  pagination_default_page_size = 20
  pagination_max_page_size     = 100
  flags                        = jsonencode({})
}
