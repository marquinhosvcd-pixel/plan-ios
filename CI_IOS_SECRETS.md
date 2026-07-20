# CI iOS — segredos do GitHub Actions

O workflow `.github/workflows/ios-build.yml` builda no runner **macos-26** (Xcode 26) e envia pro
App Store Connect usando **assinatura automática via chave de API** — o próprio Xcode cria/baixa o
certificado e o perfil no build (`-allowProvisioningUpdates`). Por isso só precisa de **3 segredos**
(a chave de API do App Store Connect), não os 7 do fluxo manual antigo.

Dados fixos (já no workflow): Team ID `7VJM86LHGV` · Bundle ID `br.com.planescala.app`.

## Os 3 segredos (já cadastrados nesta conta)

| Segredo | O que é |
|---|---|
| `APPSTORE_API_KEY_ID` | Key ID da chave de API (ex.: `25BSSV65YY`) |
| `APPSTORE_API_ISSUER_ID` | Issuer ID da API (UUID) |
| `APPSTORE_API_PRIVATE_KEY_BASE64` | o arquivo `AuthKey_XXXX.p8` em base64 |

Como obter (App Store Connect → Users and Access → Integrations → App Store Connect API): gerar uma
chave com papel **App Manager**, anotar Key ID + Issuer ID e baixar o `.p8` (download único). base64:
```bash
base64 -i ~/Downloads/AuthKey_XXXX.p8 | pbcopy
```

## Rodar
**Actions → "iOS — build & upload to App Store Connect" → Run workflow** (ou `git tag ios-v1 && git push --tags`).
O build cria o certificado/perfil, gera o IPA e sobe pro App Store Connect (aparece em TestFlight/"Builds"
em ~10–30 min). Depois é escolher a build na ficha e enviar pra revisão.

> Nota: a assinatura automática pode criar um novo certificado de Distribuição na conta no 1º build.
> Individual tem limite de certs; se um dia esgotar, revogue os antigos no developer.apple.com. Para
> builds 100% reproduzíveis no futuro, dá pra migrar pra cert+perfil persistidos (fastlane match).
