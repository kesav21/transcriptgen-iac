
provider "azurerm" {
  features {}
}

locals {
  prefix = "transcriptgen"
}

variable "mediacreds" {
  type = object({
    ApplicationId          = string
    ServicePrincipalSecret = string
    TenantId               = string
    SubscriptionId         = string
    AccountName            = string
    ResourceGroupName      = string
  })
}

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
      allowed_headers = ["*"]
      allowed_methods = ["DELETE", "GET", "HEAD", "MERGE", "POST", "OPTIONS", "PUT", "PATCH"]
      allowed_origins = ["*"]
      exposed_headers = ["content-length"]
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
  app_settings = merge(var.mediacreds, {
    StorageAccountName             = azurerm_storage_account.main.name
    StorageAccountKey              = azurerm_storage_account.main.primary_access_key
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.backend.instrumentation_key
    # FUNCTIONS_EXTENSION_VERSION = "~3"
    FUNCTIONS_WORKER_RUNTIME        = "node"
    WEBSITE_NODE_DEFAULT_VERSION    = "~12"
    WEBSITE_ENABLE_SYNC_UPDATE_SITE = null
    WEBSITE_RUN_FROM_PACKAGE        = null
  })
  site_config {
    cors {
      allowed_origins = [
        "*"
        # "http://localhost:4200",
        # format("http://%s", azurerm_app_service.frontend.default_site_hostname),
        # format("https://%s", azurerm_app_service.frontend.default_site_hostname),
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

