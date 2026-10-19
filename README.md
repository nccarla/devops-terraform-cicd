# Clase 17 – Terraform en CI/CD (desde cero)

Repositorio completo para la práctica guiada: módulo `network` (Clase 15), state remoto y dos ambientes (Clase 16), y pipelines con OIDC (Clase 17).

```
.
├── .github/workflows/
│   ├── terraform-pr.yml      ← fmt, validate y speculative plan en cada PR
│   └── terraform-cd.yml      ← saved plan → apply dev → saved plan → aprobación → apply prod
├── scripts/
│   ├── config.sh             ← ÚNICO archivo que editas
│   ├── 01-bootstrap-state.sh ← crea el Storage Account del state
│   └── 02-oidc-rbac.sh       ← crea identidades, federación OIDC y roles
└── terraform/
    ├── modules/network/
    └── environments/{development,production}/
```

---

## Paso 0 · Herramientas (una sola vez)

Instala en tu computadora:

| Herramienta | Verificar con |
|---|---|
| Git (en Windows trae **Git Bash**, úsalo para todo) | `git --version` |
| Azure CLI | `az version` |
| Terraform **1.12 o superior** | `terraform version` |
| Cuenta de GitHub | — |

> En Windows ejecuta **todos** los comandos en **Git Bash**, no en PowerShell ni CMD.

---

## Paso 1 · Crear el repositorio en GitHub

1. En GitHub → **New repository** → nombre `devops-terraform-cicd` → **Public** → sin README → *Create*.
   - Público porque en planes gratuitos *required reviewers* de environments solo funciona en repos públicos. El repo no contiene secretos.
2. Descomprime este proyecto en una carpeta y dentro de ella:

```bash
git init -b main
git remote add origin https://github.com/TU_USUARIO/devops-terraform-cicd.git
```

(No hagas push todavía.)

---

## Paso 2 · Editar `scripts/config.sh`

Cambia solo:

```bash
GITHUB_OWNER="TU_USUARIO_GITHUB"   # tu usuario exacto de GitHub
GITHUB_REPO="devops-terraform-cicd"
SUFIJO="cnc01"                     # minúsculas y números, único
LOCATION="eastus2"                 # una región que te permita tu suscripción
```

> `GITHUB_OWNER` y `GITHUB_REPO` deben coincidir **exactamente** con el repo; si no, OIDC falla con `AADSTS700213 / no matching federated identity`.

---

## Paso 3 · Login en Azure y crear el backend del state

```bash
az login
az account show --output table        # confirma la suscripción correcta
bash scripts/01-bootstrap-state.sh
```

Crea `rg-orders-tfstate`, el Storage Account `sttfstate<SUFIJO>`, el container `tfstate`, te da el rol **Storage Blob Data Contributor**, y rellena automáticamente `backend.hcl` y `environment.auto.tfvars` de cada ambiente.

> Si falla con "StorageAccountAlreadyTaken", cambia `SUFIJO` y vuelve a correrlo.

---

## Paso 4 · Primer apply local de los dos ambientes

Esto crea los Resource Groups, que el Paso 5 necesita para asignar permisos.

```bash
export TF_VAR_subscription_id=$(az account show --query id -o tsv)

# ---- development ----
cd terraform/environments/development
terraform init -backend-config=backend.hcl
terraform plan          # debe mostrar: 4 to add (RG, VNet, 2 subnets)
terraform apply         # escribe: yes

# ---- production ----
cd ../production
terraform init -backend-config=backend.hcl
terraform plan          # 4 to add, con 10.20.x.x
terraform apply

cd ../../..
```

### Lock file multiplataforma (importante)

El pipeline corre en Linux. Si generaste el lock en Windows/Mac, agrega los hashes de Linux:

```bash
for e in development production; do
  (cd terraform/environments/$e && terraform providers lock \
     -platform=linux_amd64 -platform=windows_amd64 \
     -platform=darwin_amd64 -platform=darwin_arm64)
done
```

Esto deja `.terraform.lock.hcl` en cada ambiente; **se versiona**.

---

## Paso 5 · Identidades, OIDC y RBAC

```bash
bash scripts/02-oidc-rbac.sh
```

Crea las 4 managed identities (`id-orders-{dev,prod}-{plan,apply}`), sus credenciales federadas:

| Identidad | Subject federado |
|---|---|
| dev-plan / prod-plan | `repo:OWNER/REPO:pull_request` y `repo:OWNER/REPO:ref:refs/heads/main` |
| dev-apply | `repo:OWNER/REPO:environment:development` |
| prod-apply | `repo:OWNER/REPO:environment:production` |

y los roles: **Storage Blob Data Contributor** sobre el container (las 4), **Reader** en el RG (plan), **Contributor** en el RG (apply).

Al final imprime 6 valores y los guarda en `github-variables.txt`.

---

## Paso 6 · Configurar GitHub

En el repo → **Settings**:

1. **Environments** → *New environment* → `development` (sin reglas).
2. **Environments** → *New environment* → `production` → marca **Required reviewers** → agrégate a ti → *Save protection rules*.
3. **Secrets and variables → Actions → pestaña Variables → New repository variable**. Crea las 6 (nombre exacto, valor de `github-variables.txt`):
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `DEV_PLAN_CLIENT_ID`
   - `DEV_APPLY_CLIENT_ID`
   - `PROD_PLAN_CLIENT_ID`
   - `PROD_APPLY_CLIENT_ID`

   > Son **Variables**, no Secrets: no son credenciales; la autorización viene de la federación + RBAC.

---

## Paso 7 · Primer push a `main`

```bash
git add .
git status        # verifica que NO aparezcan .terraform/, *.tfstate, tfplan ni github-variables.txt
git commit -m "Terraform con state remoto, ambientes y pipelines CI/CD"
git push -u origin main
```

Ve a **Actions → Terraform CD**. Como la infraestructura ya existe, ambos planes deben decir **No changes**. El job `apply-production` quedará en *Waiting* → **Review deployments → Approve**. Esto confirma que OIDC y los permisos funcionan.

---

## Paso 8 · Cambio de prueba (práctica 9.3)

```bash
git switch -c infra/add-cost-center-tag
```

En **ambos** archivos `terraform/environments/development/environment.auto.tfvars` y `terraform/environments/production/environment.auto.tfvars` cambia:

```hcl
additional_tags = {
  owner       = "platform-team"
  cost_center = "engineering"
}
```

```bash
git add .
git commit -m "Add infrastructure cost center tag"
git push -u origin infra/add-cost-center-tag
```

En GitHub → **Compare & pull request** → base `main` → *Create pull request*.

---

## Paso 9 · Evidencia de la PR (práctica 9.4) — toma capturas

En la pestaña **Checks** de la PR (workflow *Terraform PR*):

- [ ] `validate` verde → pasos **Format** y **Validate** (dev y prod)
- [ ] `plan-development` → abre *Speculative plan*: debe decir `Plan: 0 to add, 2 to change, 0 to destroy` (Resource Group y VNet en `~` update in-place con el tag nuevo; las subnets no llevan tags)
- [ ] `plan-production` → lo mismo, contra el state de producción
- [ ] Identidad usada: en *Initialize backend* aparece el `ARM_CLIENT_ID` = DEV_PLAN / PROD_PLAN
- [ ] State: `key = orders-development.tfstate` / `orders-production.tfstate`
- [ ] **Sin destrucciones** (`0 to destroy`)

Luego **Merge pull request**. En *Actions → Terraform CD*:

```
plan-development → apply-development → plan-production → (Approve) → apply-production
```

Captura el `terraform show` del saved plan y el apply de cada ambiente, y la pantalla de aprobación.

---

## Paso 10 · Comprobación posterior (práctica 9.5)

```bash
git switch main && git pull
export TF_VAR_subscription_id=$(az account show --query id -o tsv)

cd terraform/environments/development && terraform plan    # → No changes.
cd ../production && terraform plan                         # → No changes.
```

`No changes.` demuestra que configuración, state e infraestructura convergen.

---

## Problemas comunes

| Error | Causa / solución |
|---|---|
| `AADSTS700213` / `no matching federated identity record` | `GITHUB_OWNER`/`GITHUB_REPO` mal escritos, o el job de apply no tiene `environment:`. Revisa subjects en el portal: Managed Identity → Federated credentials. |
| `AuthorizationPermissionMismatch` en init | Rol de blob aún propagándose (espera 5 min) o falta Storage Blob Data Contributor. |
| `does not have authorization to perform action 'Microsoft.Resources/subscriptions/providers/register'` | Ya está resuelto con `resource_provider_registrations = "none"`; asegúrate de haber corrido el Paso 3 (registra Microsoft.Network). |
| `terraform fmt -check` falla | Corre `terraform fmt -recursive` en `terraform/` y haz commit. |
| Lock file sin hashes para `linux_amd64` | Repite el bloque *Lock file multiplataforma* del Paso 4 y haz commit. |
| Error `subscription_id` requerido en local | Te faltó `export TF_VAR_subscription_id=...` en esa terminal. |

## Diferencias respecto al texto de la clase (y por qué)

1. **`backend.tf` sin `use_cli = true`**: con ese valor fijo el backend intenta la sesión de Azure CLI también en el runner. Sin él, localmente usa `az login` igual y en el pipeline usa OIDC.
2. **`environment.auto.tfvars` versionado + `TF_VAR_subscription_id`**: `terraform.tfvars` está en `.gitignore`, así que el pipeline no tendría las variables. Los valores no sensibles van en `*.auto.tfvars` y la suscripción en una variable de entorno.
3. **`resource_provider_registrations = "none"`**: las identidades de plan solo tienen `Reader` en el RG; sin esto el provider intenta registrar providers a nivel suscripción y falla.

## Limpieza (al terminar el curso)

```bash
export TF_VAR_subscription_id=$(az account show --query id -o tsv)
(cd terraform/environments/production && terraform destroy)
(cd terraform/environments/development && terraform destroy)
az group delete -n rg-orders-identities --yes
az group delete -n rg-orders-tfstate --yes
```
