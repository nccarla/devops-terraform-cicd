#!/usr/bin/env bash
# Crea el backend remoto (Clase 16) y rellena backend.hcl / environment.auto.tfvars
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

echo ">> Suscripción: $SUBSCRIPTION_ID"

echo ">> Registrando Microsoft.Network y Microsoft.ManagedIdentity (puede tardar)"
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.ManagedIdentity --wait
az provider register --namespace Microsoft.Storage --wait

echo ">> Resource Group del state"
az group create --name "$STATE_RG" --location "$LOCATION" -o none

echo ">> Storage Account $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$STATE_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false -o none

STORAGE_ACCOUNT_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$STATE_RG" --query id -o tsv)
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

echo ">> Rol Storage Blob Data Contributor para tu usuario"
az role assignment create \
  --assignee-object-id "$USER_OBJECT_ID" \
  --assignee-principal-type User \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ACCOUNT_ID" -o none || echo "   (ya existía)"

echo ">> Esperando propagación de RBAC y creando container"
for i in $(seq 1 12); do
  if az storage container create --name "$STATE_CONTAINER" --account-name "$STORAGE_ACCOUNT" --auth-mode login -o none 2>/dev/null; then
    echo "   container listo"; break
  fi
  echo "   aún sin permisos, reintento en 20s ($i/12)"; sleep 20
done

echo ">> Escribiendo backend.hcl y environment.auto.tfvars"
for ENV in development production; do
  D="../terraform/environments/$ENV"
  [ "$ENV" = development ] && RG="$DEV_RG" || RG="$PROD_RG"
  sed -i.bak "s/REEMPLAZAR_STORAGE_ACCOUNT/${STORAGE_ACCOUNT}/" "$D/backend.hcl"
  sed -i.bak -e "s/REEMPLAZAR_REGION/${LOCATION}/" \
             -e "s/rg-orders-[a-z]*-REEMPLAZAR_SUFIJO/${RG}/" "$D/environment.auto.tfvars"
  rm -f "$D"/*.bak
done

echo ""
echo "LISTO. Siguiente paso: aplicar development y production desde tu máquina (ver README)."
