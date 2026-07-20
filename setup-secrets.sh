#!/usr/bin/env bash
# Cadastra os 7 segredos do CI iOS no repo GitHub (via gh, já autenticado).
# Os valores ficam no SEU Mac; só o segredo criptografado sobe pro GitHub.
#
# ANTES de rodar, tenha em mãos (ver CI_IOS_SECRETS.md):
#   1) dist.p12      — cert Apple Distribution exportado do Acesso às Chaves (com a chave privada)
#   2) profile.mobileprovision — perfil "PLAN App Store" baixado do developer.apple.com
#   3) AuthKey_XXXX.p8 — chave de API do App Store Connect (+ Key ID e Issuer ID)
#
# Uso:  bash ~/plan-ios/setup-secrets.sh
set -euo pipefail

REPO="marquinhosvcd-pixel/plan-ios"
echo "==> Segredos do CI iOS → repo $REPO"
echo

ask_file () {  # $1 = mensagem, $2 = caminho sugerido
  local msg="$1" def="${2:-}" path
  read -r -p "$msg [${def}]: " path
  path="${path:-$def}"
  path="${path/#\~/$HOME}"
  if [[ ! -f "$path" ]]; then echo "  ! arquivo não encontrado: $path" >&2; exit 1; fi
  echo "$path"
}

# 1 + 2 — certificado .p12 (base64) + senha do .p12
P12=$(ask_file "Caminho do dist.p12" "$HOME/Downloads/dist.p12")
base64 -i "$P12" | gh secret set BUILD_CERTIFICATE_BASE64 --repo "$REPO"
echo "  ✓ BUILD_CERTIFICATE_BASE64"
read -r -s -p "Senha do .p12 (P12_PASSWORD): " P12PW; echo
printf '%s' "$P12PW" | gh secret set P12_PASSWORD --repo "$REPO"
echo "  ✓ P12_PASSWORD"

# 3 — perfil de provisionamento (base64)
PROF=$(ask_file "Caminho do perfil .mobileprovision" "$HOME/Downloads/PLAN_App_Store.mobileprovision")
base64 -i "$PROF" | gh secret set PROVISIONING_PROFILE_BASE64 --repo "$REPO"
echo "  ✓ PROVISIONING_PROFILE_BASE64"

# 4 — senha efêmera do keychain (gerada, não precisa guardar)
openssl rand -base64 24 | gh secret set KEYCHAIN_PASSWORD --repo "$REPO"
echo "  ✓ KEYCHAIN_PASSWORD (gerada automaticamente)"

# 5 + 6 — Key ID e Issuer ID da API do App Store Connect
read -r -p "APPSTORE_API_KEY_ID (ex.: ABC123XYZ): " KEYID
printf '%s' "$KEYID" | gh secret set APPSTORE_API_KEY_ID --repo "$REPO"
echo "  ✓ APPSTORE_API_KEY_ID"
read -r -p "APPSTORE_API_ISSUER_ID (UUID no topo da página de Keys): " ISSUER
printf '%s' "$ISSUER" | gh secret set APPSTORE_API_ISSUER_ID --repo "$REPO"
echo "  ✓ APPSTORE_API_ISSUER_ID"

# 7 — chave .p8 (base64)
P8=$(ask_file "Caminho do AuthKey_XXXX.p8" "$HOME/Downloads/AuthKey_${KEYID}.p8")
base64 -i "$P8" | gh secret set APPSTORE_API_PRIVATE_KEY_BASE64 --repo "$REPO"
echo "  ✓ APPSTORE_API_PRIVATE_KEY_BASE64"

echo
echo "==> Pronto. Conferindo:"
gh secret list --repo "$REPO"
echo
echo "Agora é só rodar o build: Actions → 'iOS — build & upload to App Store Connect' → Run workflow"
echo "(ou avise o assistente que ele dispara: gh workflow run ios-build.yml)"
