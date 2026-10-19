#!/usr/bin/env bash
# Clase 17 – secciones 4.2 a 4.6: identidades, credenciales federadas y RBAC
# REQUISITO: los Resource Groups de development y production ya deben existir
#            (se crean con el primer terraform apply local).
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

ISSUER="https://token.actions.githubusercontent.com"
AUD="api://AzureADTokenExchange"
REPO="repo:${GITHUB_OWNER}/${GITHUB_REPO}"

echo ">> Resource Group de identidades"
az group create --name "$IDENTITY_RG" --location "$LOCATION" -o none

echo ">> 4 managed identities"
for ID in "$DEV_PLAN_ID" "$DEV_APPLY_ID" "$PROD_PLAN_ID" "$PROD_APPLY_ID"; do
  az identity create --name "$ID" --resource-group "$IDENTITY_RG" --location "$LOCATION" -o none
done

get() { az identity show --name "$1" --resource-group "$IDENTITY_RG" --query "$2" -o tsv; }
DEV_PLAN_CLIENT_ID=$(get "$DEV_PLAN_ID" clientId);     DEV_PLAN_PRINCIPAL_ID=$(get "$DEV_PLAN_ID" principalId)
DEV_APPLY_CLIENT_ID=$(get "$DEV_APPLY_ID" clientId);   DEV_APPLY_PRINCIPAL_ID=$(get "$DEV_APPLY_ID" principalId)
PROD_PLAN_CLIENT_ID=$(get "$PROD_PLAN_ID" clientId);   PROD_PLAN_PRINCIPAL_ID=$(get "$PROD_PLAN_ID" principalId)
PROD_APPLY_CLIENT_ID=$(get "$PROD_APPLY_ID" clientId); PROD_APPLY_PRINCIPAL_ID=$(get "$PROD_APPLY_ID" principalId)

fed() { # identidad nombre subject
  az identity federated-credential create \
    --name "$2" --identity-name "$1" --resource-group "$IDENTITY_RG" \
    --issuer "$ISSUER" --subject "$3" --audiences "$AUD" -o none \
    || echo "   ($2 en $1 ya existía)"
}

echo ">> Credenciales federadas de PLAN (pull_request y main)"
for ID in "$DEV_PLAN_ID" "$PROD_PLAN_ID"; do
  fed "$ID" github-pr   "${REPO}:pull_request"
  fed "$ID" github-main "${REPO}:ref:refs/heads/main"
done

echo ">> Credenciales federadas de APPLY (environments)"
fed "$DEV_APPLY_ID"  github-development "${REPO}:environment:development"
fed "$PROD_APPLY_ID" github-production  "${REPO}:environment:production"

role() { # principal rol scope
  az role assignment create --assignee-object-id "$1" --assignee-principal-type ServicePrincipal \
    --role "$2" --scope "$3" -o none || echo "   (rol $2 ya existía)"
}

echo ">> Acceso al state (Storage Blob Data Contributor sobre el container)"
STORAGE_ACCOUNT_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$STATE_RG" --query id -o tsv)
STATE_CONTAINER_SCOPE="${STORAGE_ACCOUNT_ID}/blobServices/default/containers/${STATE_CONTAINER}"
for P in "$DEV_PLAN_PRINCIPAL_ID" "$DEV_APPLY_PRINCIPAL_ID" "$PROD_PLAN_PRINCIPAL_ID" "$PROD_APPLY_PRINCIPAL_ID"; do
  role "$P" "Storage Blob Data Contributor" "$STATE_CONTAINER_SCOPE"
done

echo ">> Permisos sobre los ambientes"
DEV_RG_ID=$(az group show --name "$DEV_RG" --query id -o tsv)
PROD_RG_ID=$(az group show --name "$PROD_RG" --query id -o tsv)
role "$DEV_PLAN_PRINCIPAL_ID"   "Reader"      "$DEV_RG_ID"
role "$PROD_PLAN_PRINCIPAL_ID"  "Reader"      "$PROD_RG_ID"
role "$DEV_APPLY_PRINCIPAL_ID"  "Contributor" "$DEV_RG_ID"
role "$PROD_APPLY_PRINCIPAL_ID" "Contributor" "$PROD_RG_ID"

cat > ../github-variables.txt <<OUT
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
DEV_PLAN_CLIENT_ID=$DEV_PLAN_CLIENT_ID
DEV_APPLY_CLIENT_ID=$DEV_APPLY_CLIENT_ID
PROD_PLAN_CLIENT_ID=$PROD_PLAN_CLIENT_ID
PROD_APPLY_CLIENT_ID=$PROD_APPLY_CLIENT_ID
OUT

echo ""
echo "================ VARIABLES PARA GITHUB ================"
cat ../github-variables.txt
echo "======================================================="
echo "(guardadas en github-variables.txt — ese archivo NO se sube, está en .gitignore)"
