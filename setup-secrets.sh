#!/usr/bin/env bash
# Cadastra os 3 segredos que faltam pro CI iOS (assinatura manual).
# Os outros 4 (chave de API + KEYCHAIN_PASSWORD) já estão cadastrados.
# Os valores ficam no SEU Mac; só o segredo criptografado sobe pro GitHub.
#
# ANTES de rodar, tenha em ~/Downloads:
#   1) dist.p12  — cert Apple Distribution exportado do Acesso às Chaves (com a chave privada)
#   2) PLAN_App_Store.mobileprovision — perfil baixado do developer.apple.com
#
# Uso:  bash ~/plan-ios/setup-secrets.sh
set -euo pipefail
REPO="marquinhosvcd-pixel/plan-ios"

ask_file () {
  local msg="$1" def="${2:-}" path
  read -r -p "$msg [${def}]: " path
  path="${path:-$def}"; path="${path/#\~/$HOME}"
  if [[ ! -f "$path" ]]; then echo "  ! arquivo não encontrado: $path" >&2; exit 1; fi
  echo "$path"
}

echo "==> 3 segredos restantes → $REPO"

P12=$(ask_file "Caminho do dist.p12" "$HOME/Downloads/dist.p12")
base64 -i "$P12" | gh secret set BUILD_CERTIFICATE_BASE64 --repo "$REPO"
echo "  ✓ BUILD_CERTIFICATE_BASE64"

read -r -s -p "Senha que você definiu ao exportar o .p12: " P12PW; echo
printf '%s' "$P12PW" | gh secret set P12_PASSWORD --repo "$REPO"
echo "  ✓ P12_PASSWORD"

PROF=$(ask_file "Caminho do perfil .mobileprovision" "$HOME/Downloads/PLAN_App_Store.mobileprovision")
base64 -i "$PROF" | gh secret set PROVISIONING_PROFILE_BASE64 --repo "$REPO"
echo "  ✓ PROVISIONING_PROFILE_BASE64"

echo; echo "==> Pronto. Segredos no repo:"; gh secret list --repo "$REPO"
echo "Agora avise o assistente que ele dispara o build."
