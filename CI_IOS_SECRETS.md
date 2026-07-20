# CI iOS — segredos do GitHub Actions

O workflow `.github/workflows/ios-build.yml` builda no runner **macos-26** (Xcode 26) e envia pro
App Store Connect assinando com o **cert de Distribuição + perfil "PLAN App Store" que já existem**.
Ele lê 7 segredos do repositório. Cadastre em **GitHub → Settings → Secrets and variables → Actions → New repository secret**.

Dados fixos (já embutidos no workflow, não precisam de segredo):
- Team ID: `7VJM86LHGV` · Bundle ID: `br.com.planescala.app` · Perfil: `PLAN App Store`

## Os 7 segredos

| Segredo | O que é | Como obter |
|---|---|---|
| `BUILD_CERTIFICATE_BASE64` | Cert **Apple Distribution** + chave privada, em `.p12`, base64 | ver passo 1 |
| `P12_PASSWORD` | senha que você definiu ao exportar o `.p12` | você escolhe no export |
| `PROVISIONING_PROFILE_BASE64` | perfil **PLAN App Store** (`.mobileprovision`), base64 | ver passo 2 |
| `KEYCHAIN_PASSWORD` | senha efêmera do keychain temporário do CI | qualquer string forte (só existe durante o build) |
| `APPSTORE_API_KEY_ID` | Key ID da chave de API do App Store Connect | ver passo 3 |
| `APPSTORE_API_ISSUER_ID` | Issuer ID da API | ver passo 3 |
| `APPSTORE_API_PRIVATE_KEY_BASE64` | o arquivo `AuthKey_XXXX.p8`, base64 | ver passo 3 |

---

## Passo 1 — exportar o certificado Apple Distribution (.p12)

No **seu Mac** (o cert já está no Keychain desta máquina, criado na sessão de 13/07):

1. Abra o app **Acesso às Chaves (Keychain Access)**.
2. Categoria **Meus certificados** → ache **Apple Distribution: Marcos… (7VJM86LHGV)**.
3. Expanda a setinha (tem que aparecer a chave privada junto). Selecione o certificado **e** a chave.
4. Botão direito → **Exportar 2 itens…** → formato **.p12** → salve como `dist.p12` e defina uma senha
   (essa senha vira o segredo `P12_PASSWORD`).
5. Gere o base64:
   ```bash
   base64 -i dist.p12 | pbcopy   # já copia pro clipboard → cole no segredo BUILD_CERTIFICATE_BASE64
   ```

## Passo 2 — baixar o perfil "PLAN App Store" (.mobileprovision)

1. https://developer.apple.com/account → **Certificates, IDs & Profiles** → **Profiles**.
2. Abra **PLAN App Store** → **Download**.
3. base64:
   ```bash
   base64 -i ~/Downloads/PLAN_App_Store.mobileprovision | pbcopy   # → PROVISIONING_PROFILE_BASE64
   ```

## Passo 3 — chave de API do App Store Connect (upload sem senha da conta)

1. https://appstoreconnect.apple.com → **Users and Access** → aba **Integrations** (ou "Keys") →
   **App Store Connect API** → **+** para gerar uma chave com papel **App Manager**.
2. Anote o **Key ID** (→ `APPSTORE_API_KEY_ID`) e o **Issuer ID** no topo (→ `APPSTORE_API_ISSUER_ID`).
3. Baixe o arquivo **`AuthKey_XXXXXX.p8`** (só dá pra baixar uma vez — guarde no cofre). base64:
   ```bash
   base64 -i ~/Downloads/AuthKey_XXXXXX.p8 | pbcopy   # → APPSTORE_API_PRIVATE_KEY_BASE64
   ```

## Passo 4 — KEYCHAIN_PASSWORD

Qualquer string aleatória forte, ex.:
```bash
openssl rand -base64 24 | pbcopy   # → KEYCHAIN_PASSWORD
```

---

## Rodar

Depois de cadastrar os 7 segredos: **Actions → "iOS — build & upload to App Store Connect" → Run workflow**
(ou empurre uma tag `git tag ios-v1 && git push --tags`). O build sobe pro App Store Connect (aparece
em TestFlight/"Builds" em ~10–30 min de processamento). Aí é só escolher a build na ficha e enviar pra revisão.

> Observação sobre versão: hoje o app está em `1.0 (1)`. Para reenviar após rejeição, suba o
> **build number** (`CURRENT_PROJECT_VERSION`) no `project.pbxproj` (ou automatize com
> `agvtool next-version` no workflow) — a Apple recusa builds com número repetido.
