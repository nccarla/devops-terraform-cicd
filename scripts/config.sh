#!/usr/bin/env bash
# Evita que Git Bash (Windows) convierta "/subscriptions/..." en rutas de disco
export MSYS_NO_PATHCONV=1
# ============================================================
#  EDITA SOLO ESTE ARCHIVO antes de correr los scripts
# ============================================================

# Tu usuario (u organización) de GitHub y el nombre del repo
GITHUB_OWNER="nccarla"
GITHUB_REPO="devops-terraform-cicd"

# Sufijo corto, solo minúsculas y números (ej. tus iniciales + 2 dígitos: cnc01)
SUFIJO="cnc01"

# Región permitida por tu suscripción (la misma que te funcionó en clases anteriores)
# Ej.: eastus, eastus2, centralus, westus2
LOCATION="southcentralus"

# ------------------------------------------------------------
# No hace falta tocar lo de abajo
# ------------------------------------------------------------
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

STATE_RG="rg-orders-tfstate"
STORAGE_ACCOUNT="sttfstate${SUFIJO}"     # 3-24 caracteres, minúsculas y números
STATE_CONTAINER="tfstate"

IDENTITY_RG="rg-orders-identities"
DEV_RG="rg-orders-dev-${SUFIJO}"
PROD_RG="rg-orders-prod-${SUFIJO}"

DEV_PLAN_ID="id-orders-dev-plan"
DEV_APPLY_ID="id-orders-dev-apply"
PROD_PLAN_ID="id-orders-prod-plan"
PROD_APPLY_ID="id-orders-prod-apply"
