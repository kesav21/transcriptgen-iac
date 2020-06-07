
output "frontend-url" {
  value = azurerm_app_service.frontend.default_site_hostname
}

output "backend-url" {
  value = azurerm_function_app.backend.default_hostname
}
