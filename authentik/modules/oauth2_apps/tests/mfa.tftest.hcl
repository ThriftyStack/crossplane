mock_provider "authentik" {
  mock_resource "authentik_provider_oauth2" {
    defaults = {
      id = "7"
    }
  }
  mock_resource "authentik_flow" {
    defaults = {
      uuid = "mfa-flow"
    }
  }
  mock_data "authentik_flow" {
    defaults = {
      id = "default-flow"
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
      scopes        = ["openid"]
      redirects     = [{ matching_mode = "strict", url = "https://a.example/cb", redirect_uri_type = "authorization" }]
      client_id     = { path = "clients", key = "a-client-id" }
      client_secret = { path = "clients", key = "a" }
    }
    b = {
      name          = "B"
      group         = "Test"
      scopes        = ["openid"]
      redirects     = [{ matching_mode = "strict", url = "https://b.example/cb", redirect_uri_type = "authorization" }]
      client_id     = { path = "clients", key = "b-client-id" }
      client_secret = { path = "clients", key = "b" }
      mfa           = true
    }
  }
}

run "only_opted_in_apps_use_the_mfa_flow" {
  command = apply

  assert {
    condition     = authentik_provider_oauth2.this["b"].authorization_flow == "mfa-flow" && authentik_provider_oauth2.this["a"].authorization_flow == "default-flow"
    error_message = "Only the app with mfa = true may use the MFA authorization flow."
  }

  assert {
    condition = alltrue([
      authentik_flow.mfa_authorization[0].designation == "authorization",
      authentik_flow_stage_binding.mfa[0].target == authentik_flow.mfa_authorization[0].uuid,
      authentik_flow_stage_binding.mfa[0].stage == authentik_stage_authenticator_validate.mfa[0].id,
    ])
    error_message = "The MFA flow must be an authorization flow bound to the validation stage."
  }

  assert {
    condition = alltrue([
      authentik_stage_authenticator_validate.mfa[0].not_configured_action == "deny",
      authentik_stage_authenticator_validate.mfa[0].last_auth_threshold == "seconds=0",
      toset(authentik_stage_authenticator_validate.mfa[0].device_classes) == toset(["webauthn", "totp"]),
    ])
    error_message = "The stage must deny users without a device, ask every time, and accept only WebAuthn and TOTP."
  }
}

run "no_mfa_objects_without_an_opted_in_app" {
  command = apply

  variables {
    apps = {
      a = {
        name          = "A"
        group         = "Test"
        scopes        = ["openid"]
        redirects     = [{ matching_mode = "strict", url = "https://a.example/cb", redirect_uri_type = "authorization" }]
        client_id     = { path = "clients", key = "a-client-id" }
        client_secret = { path = "clients", key = "a" }
      }
    }
  }

  assert {
    condition     = length(authentik_flow.mfa_authorization) == 0 && length(authentik_stage_authenticator_validate.mfa) == 0 && length(authentik_flow_stage_binding.mfa) == 0
    error_message = "No MFA flow or stage may exist when no app opts in."
  }
}
