
provider "azurerm" {
  features {}
}

provider "azuread" {
}

locals {
  prefix = "transcriptgen"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "${local.prefix}-rg"
  location = "West US"
}

resource "azurerm_app_service_plan" "main" {
  name                = "${local.prefix}-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku {
    tier = "Free"
    size = "F1"
  }
}

resource "azurerm_app_service" "frontend" {
  name                = "${local.prefix}-frontend"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  app_service_plan_id = azurerm_app_service_plan.main.id
}

resource "azurerm_storage_account" "main" {
  name                     = "${local.prefix}storage"
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  blob_properties {
    cors_rule {
      # A list of headers that are allowed to be a part of the cross-origin request.
      allowed_headers = ["*"]
      # A list of http headers that are allowed to be executed by the origin. Valid options are DELETE, GET, HEAD, MERGE, POST, OPTIONS, PUT or PATCH.
      allowed_methods = ["DELETE", "GET", "HEAD", "MERGE", "POST", "OPTIONS", "PUT", "PATCH"]
      # A list of origin domains that will be allowed by CORS.
      allowed_origins = ["*"]
      # A list of response headers that are exposed to CORS clients.
      exposed_headers = ["content-length"]
      # The number of seconds the client should cache a preflight response.
      max_age_in_seconds = 200
    }
  }
}

resource "azurerm_storage_container" "test" {
  name                 = "testcontainer"
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_application_insights" "backend" {
  name                = "${local.prefix}-backend-insights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "Node.JS"
}

resource "azurerm_function_app" "backend" {
  name                       = "${local.prefix}-backend"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  app_service_plan_id        = azurerm_app_service_plan.main.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  version                    = "~3"
  app_settings = {
    StorageAccountName             = azurerm_storage_account.main.name
    StorageAccountKey              = azurerm_storage_account.main.primary_access_key
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.backend.instrumentation_key
    # FUNCTIONS_EXTENSION_VERSION = "~3"
    FUNCTIONS_WORKER_RUNTIME        = "node"
    WEBSITE_NODE_DEFAULT_VERSION    = "~12"
    WEBSITE_ENABLE_SYNC_UPDATE_SITE = null
    WEBSITE_RUN_FROM_PACKAGE        = null
  }
  site_config {
    cors {
      allowed_origins = [
        "http://localhost:4200",
        format("http://%s", azurerm_app_service.frontend.default_site_hostname),
        format("https://%s", azurerm_app_service.frontend.default_site_hostname),
      ]
    }
  }
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_ENABLE_SYNC_UPDATE_SITE"],
      app_settings["WEBSITE_RUN_FROM_PACKAGE"]
    ]
  }

}

resource "azurerm_media_services_account" "main" {
  name                = "${local.prefix}media"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  storage_account {
    id         = azurerm_storage_account.main.id
    is_primary = true
  }
}

resource "azuread_application" "main" {
  name = "${local.prefix}-ad"
}

resource "azuread_service_principal" "main" {
  application_id = azuread_application.main.application_id
}

resource "random_password" "service_principal_main" {
  length = 16
}

resource "azuread_service_principal_password" "main" {
  service_principal_id = azuread_service_principal.main.id
  value                = random_password.service_principal_main.result
  end_date             = "2099-01-01T01:02:03Z"
}

resource "azurerm_role_definition" "media_read_assets" {
  name  = "media-read-assets"
  scope = azurerm_media_services_account.main.id
  permissions {
    actions = [
      "Microsoft.Media/mediaServices/assets/write",
      "Microsoft.Media/mediaServices/transforms/read",
      "Microsoft.Media/mediaServices/transforms/write",
      "Microsoft.Media/mediaServices/transforms/jobs/read",
      "Microsoft.Media/mediaServices/transforms/jobs/write"
    ]
  }
  assignable_scopes = [
    azurerm_media_services_account.main.id
  ]
}

resource "azurerm_role_assignment" "service_principal_media" {
  scope              = azurerm_media_services_account.main.id
  role_definition_id = azurerm_role_definition.media_read_assets.id
  principal_id       = azuread_service_principal.main.object_id
}
