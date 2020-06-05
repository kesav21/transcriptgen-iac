
output "aad_tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "aad_application_id" {
  value = azuread_application.main.application_id
}

output "aad_service_principal_password" {
  value = random_password.service_principal_main.result
}

output "aad_subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}

output "ams_account_name" {
  value = azurerm_media_services_account.main.name
}

output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "frontend-url" {
  value = azurerm_app_service.frontend.default_site_hostname
}

output "backend-url" {
  value = azurerm_function_app.backend.default_hostname
}
