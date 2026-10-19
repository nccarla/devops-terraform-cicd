terraform {
  backend "azurerm" {
    # Autenticación contra Blob Storage con Entra ID (sin access keys).
    # Local: usa la sesión de "az login". Pipeline: usa OIDC (ARM_USE_OIDC).
    use_azuread_auth = true
  }
}
