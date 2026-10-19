# Valores NO sensibles del ambiente (sí se versiona para que el pipeline los use).
# El subscription_id NO va aquí: se pasa con la variable de entorno TF_VAR_subscription_id.
location            = "southcentralus"
resource_group_name = "rg-orders-dev-cnc01"
application_name    = "orders-platform"

additional_tags = {
  owner = "platform-team"
}
