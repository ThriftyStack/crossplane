mock_provider "authentik" {
  mock_data "authentik_flow" {
    defaults = {
      id = "flow-1"
    }
  }

  mock_resource "authentik_provider_proxy" {
    defaults = {
      id = "7"
    }
  }

  mock_resource "authentik_application" {
    defaults = {
      uuid = "app-uuid"
    }
  }

  mock_resource "authentik_outpost" {
    defaults = {
      id = "outpost-uuid"
    }
  }
}

variables {
  outposts = {}
}

run "adopts_whoami_and_oke" {
  command = plan

  variables {
    apps = {
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
  }

  assert {
    condition = alltrue([
      authentik_provider_proxy.this["whoami"].name == "whoami (OKE internal)",
      authentik_provider_proxy.this["whoami"].external_host == "https://whoami.oci.devoops.uk",
      authentik_provider_proxy.this["whoami"].internal_host == "http://whoami.whoami.svc.cluster.local",
      authentik_provider_proxy.this["whoami"].authorization_flow == "flow-1",
      authentik_provider_proxy.this["whoami"].invalidation_flow == "flow-1",
      authentik_application.this["whoami"].slug == "whoami",
      authentik_application.this["whoami"].group == "Infrastructure",
      authentik_application.this["whoami"].protocol_provider == 7,
      authentik_outpost.this["oke"].name == "oke",
      authentik_outpost.this["oke"].protocol_providers == tolist([7]),
      jsondecode(authentik_outpost.this["oke"].config).authentik_host == "https://auth.devoops.uk",
      length(authentik_application_entitlement.this) == 0,
    ])
    error_message = "The whoami proxy, its application, and the oke outpost must keep the adopted names and hosts."
  }
}

run "keeps_entitlement_name" {
  command = plan

  variables {
    apps = {
      whoami = {
        name          = "whoami (OKE internal)"
        group         = "Infrastructure"
        external_host = "https://whoami.oci.devoops.uk"
        internal_host = "http://whoami.whoami.svc.cluster.local"
        entitlements = {
          whoami_viewers = "whoami-viewers"
        }
      }
    }
  }

  assert {
    condition     = authentik_application_entitlement.this["whoami_viewers"].name == "whoami-viewers"
    error_message = "Entitlement names must be copied unchanged. Consumers match the string, not the configuration key."
  }
}
