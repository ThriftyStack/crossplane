mock_provider "authentik" {
  mock_resource "authentik_provider_oauth2" {
    defaults = {
      id = "7"
    }
  }
}

mock_provider "vault" {
  mock_data "vault_kv_secret_v2" {
    defaults = {
      data = {
        "a-client-id" = "client-a"
        "a"           = "secret-a"
        "b-client-id" = "client-b"
        "b"           = "secret-b"
      }
    }
  }
}

variables {
  vault_mount = "infra"
  apps = {
    a = {
      name          = "A"
      group         = "Test"
      scopes        = ["email"]
      redirects     = [{ matching_mode = "strict", url = "https://a.example/cb", redirect_uri_type = "authorization" }]
      client_id     = { path = "clients", key = "a-client-id" }
      client_secret = { path = "clients", key = "a" }
    }
    b = {
      name           = "B"
      group          = "Test"
      scopes         = ["email"]
      redirects      = [{ matching_mode = "strict", url = "https://b.example/cb", redirect_uri_type = "authorization" }]
      client_id      = { path = "clients", key = "b-client-id" }
      client_secret  = { path = "clients", key = "b" }
      email_verified = true
    }
  }
}

run "only_opted_in_apps_get_the_verified_email_mapping" {
  command = apply

  assert {
    condition     = length(authentik_property_mapping_provider_scope.verified_email) == 1 && strcontains(authentik_property_mapping_provider_scope.verified_email[0].expression, "not get_current_tenant().default_user_change_email")
    error_message = "One verified-email mapping must exist when an app opts in."
  }

  assert {
    condition = alltrue([
      contains(authentik_provider_oauth2.this["b"].property_mappings, authentik_property_mapping_provider_scope.verified_email[0].id),
      !contains(authentik_provider_oauth2.this["b"].property_mappings, data.authentik_property_mapping_provider_scope.default["email"].id),
      contains(authentik_provider_oauth2.this["a"].property_mappings, data.authentik_property_mapping_provider_scope.default["email"].id),
      !contains(authentik_provider_oauth2.this["a"].property_mappings, authentik_property_mapping_provider_scope.verified_email[0].id),
    ])
    error_message = "Only the opted-in app may receive email_verified=true; every other app keeps Authentik's managed email mapping."
  }
}

run "no_opt_in_means_no_verified_mapping" {
  command = plan

  variables {
    apps = {
      a = {
        name          = "A"
        group         = "Test"
        scopes        = ["email"]
        redirects     = [{ matching_mode = "strict", url = "https://a.example/cb", redirect_uri_type = "authorization" }]
        client_id     = { path = "clients", key = "a-client-id" }
        client_secret = { path = "clients", key = "a" }
      }
    }
  }

  assert {
    condition     = length(authentik_property_mapping_provider_scope.verified_email) == 0
    error_message = "Without an opt-in, no mapping may assert a verified email."
  }
}
