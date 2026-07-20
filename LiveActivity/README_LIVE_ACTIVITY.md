# PLAN — Live Activity (protótipo)

> ⚠️ **Isto é um PROTÓTIPO.** Os arquivos Swift aqui em `LiveActivity/` **não
> estão** conectados a nenhum target do Xcode ainda. O `project.pbxproj` e o
> `Podfile` **não foram tocados** de propósito (adicionar target de extensão à
> mão quebraria o build do CI). O titular precisa fazer os passos abaixo no
> Xcode uma única vez.

Live Activity que mostra, na tela de bloqueio / Dynamic Island, um card "ao vivo"
de um plantão de saúde em andamento: cronômetro decorrido, nome da instituição,
próxima marcação (intervalo/volta/saída) e local.

Botões interativos (App Intents) ficam para a **v2** — não estão aqui.

Requer **iOS 16.1+**.

---

## 1. Arquivos deste protótipo

| Arquivo | Target de destino | Papel |
|---|---|---|
| `PlantaoAttributes.swift` | **App _e_ Widget Extension** (ambos) | Modelo de dados: atributos estáticos + `ContentState` dinâmico |
| `PlantaoLiveActivity.swift` | **Widget Extension** | UI SwiftUI: lock screen + Dynamic Island (compact/minimal/expanded) |
| `LiveActivityManager.swift` | **App** | Helper start/update/end via ActivityKit |
| `PlanLiveActivityPlugin.swift` | **App** | Plugin Capacitor exposto ao JS |
| `PlanLiveActivityPlugin.m` | **App** | Registro Objective-C do plugin (obrigatório p/ Capacitor achar) |

---

## 2. Passo a passo no Xcode (titular faz uma vez)

### 2.1. Criar a Widget Extension

1. Abra `ios/App/App.xcworkspace` no Xcode.
2. **File ▸ New ▸ Target… ▸ Widget Extension**.
3. Nome sugerido: `PlanWidgets`. **Desmarque** "Include Configuration
   Intent" (não precisamos por enquanto). **Marque** "Include Live Activity"
   se a opção aparecer (Xcode 15+).
4. Ao perguntar sobre ativar o scheme, clique **Activate**.
5. O Xcode cria uma pasta `PlanWidgets/` com um `PlanWidgetsBundle.swift` de
   exemplo. **Apague** o arquivo de exemplo (nós temos o nosso
   `PlanWidgetBundle` com `@main` dentro de `PlantaoLiveActivity.swift`), ou,
   se preferir manter o bundle gerado, remova o `@main` do nosso arquivo e
   adicione `PlantaoLiveActivity()` ao bundle gerado. **Só pode existir um
   `@main`** na extensão.

### 2.2. Adicionar os arquivos-fonte aos targets certos

Arraste os arquivos de `LiveActivity/` para dentro do projeto no Xcode (ou
**Add Files to "App"…**). Ao adicionar, cuide do **Target Membership** (painel
File Inspector, à direita):

- `PlantaoAttributes.swift` → **App** ✅ **e** **PlanWidgets** ✅ (os dois)
- `PlantaoLiveActivity.swift` → **PlanWidgets** ✅ (só a extensão)
- `LiveActivityManager.swift` → **App** ✅
- `PlanLiveActivityPlugin.swift` → **App** ✅
- `PlanLiveActivityPlugin.m` → **App** ✅

> Dica: você pode manter os arquivos fisicamente em `LiveActivity/` e só
> referenciá-los; ou movê-los para dentro das pastas dos targets. O que importa
> é o Target Membership.

### 2.3. Ativar Live Activities no Info.plist do target **App**

Adicione ao `ios/App/App/Info.plist`:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

(Opcional, para updates de alta frequência via push:)

```xml
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

### 2.4. Capabilities / assinatura

- A extensão herda o Team **7VJM86LHGV**. Confirme em
  **Signing & Capabilities** do target `PlanWidgets` que o Team está setado e o
  bundle id ficou `br.com.planescala.app.PlanWidgets` (o Xcode sugere
  automaticamente `<app-id>.<extensão>`).
- Para **push** de updates (seção 4), o target **App** precisa da capability
  **Push Notifications** (o app já usa `@capacitor/push-notifications`, então o
  entitlement de APNs provavelmente já existe — confirmar em
  `App.entitlements`).

### 2.5. CI

O CI vai buildar o novo scheme automaticamente **depois** que o titular commitar
o `project.pbxproj` alterado pelo Xcode. Enquanto esses passos não forem feitos,
os arquivos em `LiveActivity/` são inertes (não compilam junto) — seguro deixar
commitado.

---

## 3. Uso pelo lado web (JavaScript)

O plugin é registrado como `PlanLiveActivity`.

```js
import { registerPlugin } from '@capacitor/core';

const PlanLiveActivity = registerPlugin('PlanLiveActivity');

// 1. Checar suporte antes de usar (Android / iOS < 16.1 retornam supported:false)
const { supported, enabled } = await PlanLiveActivity.isSupported();
if (!supported || !enabled) return;

// 2. Iniciar quando o plantão começa
const { activityId } = await PlanLiveActivity.start({
  instituicaoNome: 'Santa Casa',
  entradaISO: '2026-07-20T07:00:00-03:00',
  saidaPrevistaISO: '2026-07-20T19:00:00-03:00',
  local: 'Pronto-Socorro — Ala B',
  proximaMarcacaoLabel: 'Intervalo',
  proximaMarcacaoHorarioISO: '2026-07-20T13:00:00-03:00', // opcional (pode ser null)
  statusLabel: 'Em andamento',
  // staleAfterSeconds: 3600,   // opcional: marca o card como "desatualizado" após X s
});
// Guarde activityId no backend para endereçar updates via push.

// 3. Atualizar quando bate o ponto (intervalo, volta, etc.)
await PlanLiveActivity.update({
  proximaMarcacaoLabel: 'Volta do intervalo',
  proximaMarcacaoHorarioISO: '2026-07-20T14:00:00-03:00',
  statusLabel: 'Em intervalo',
});

// 4. Encerrar quando o plantão termina
await PlanLiveActivity.end({
  finalStatusLabel: 'Plantão encerrado',
  // dismissAfterSeconds: 0,   // 0 = remove já; omitir = política padrão (~até 4h)
});
```

### Assinatura resumida

| Método | Args | Retorno |
|---|---|---|
| `isSupported()` | — | `{ supported: boolean, enabled: boolean }` |
| `start(opts)` | `instituicaoNome, entradaISO, saidaPrevistaISO, local, proximaMarcacaoLabel, statusLabel` (obrigatórios); `proximaMarcacaoHorarioISO?, staleAfterSeconds?` | `{ activityId: string }` |
| `update(opts)` | `proximaMarcacaoLabel, statusLabel` (obrigatórios); `proximaMarcacaoHorarioISO?, staleAfterSeconds?` | `void` |
| `end(opts?)` | `finalStatusLabel?, dismissAfterSeconds?` | `void` |

Todas as datas são **strings ISO-8601** (o mesmo formato que o backend usa),
para o cronômetro e a próxima marcação serem calculados no lado nativo.

---

## 4. Como o backend Django dispararia updates via APNs (só o desenho)

Updates locais (via `update()`) só funcionam com o app em foreground/rodando. Para
atualizar o card com o app **fechado** (o caso real: o médico não fica com o app
aberto durand o plantão inteiro), o update tem que vir por **push APNs** com o
tipo especial `liveactivity`.

Fluxo:

```
[App iOS]                         [Backend Django]                [APNs]
   |  start() cria a Activity          |                             |
   |  ActivityKit emite pushToken  --> | POST /api/live-activity/     |
   |  (LiveActivityManager                registra {activityId,       |
   |   .observePushToken)                 pushToken, userId}          |
   |                                   |                             |
   |                          (bateu horário do intervalo,           |
   |                           ou admin mudou a escala)              |
   |                                   |  monta payload e envia  -->  |
   |                                   |  headers:                    |
   |                                   |   apns-push-type: liveactivity
   |                                   |   apns-topic:                |
   |                                   |    br.com.planescala.app.push-type.liveactivity
   |                                   |   apns-priority: 10          |
   |  <-------- push chega, card atualiza sozinho -----------------  |
```

**Payload de update** (APNs, JSON):

```json
{
  "aps": {
    "timestamp": 1752999600,
    "event": "update",
    "content-state": {
      "proximaMarcacaoLabel": "Volta do intervalo",
      "proximaMarcacaoHorarioISO": "2026-07-20T14:00:00-03:00",
      "statusLabel": "Em intervalo"
    },
    "alert": {
      "title": "Hora de voltar do intervalo",
      "body": "Santa Casa — Ala B"
    }
  }
}
```

- `content-state` tem que casar **exatamente** com o `ContentState` de
  `PlantaoAttributes.swift` (mesmas chaves, mesmos tipos). Por isso mantivemos
  ISO-string em vez de `Date`.
- Para **encerrar** por push: `"event": "end"` (opcionalmente com
  `dismissal-date`).
- Conexão com APNs tem que ser **token-based (JWT .p8)** — o tipo `liveactivity`
  exige. No Django, bibliotecas como `aioapns` / `apns2` ou um serviço
  (Firebase, OneSignal, Braze) fazem o envio.
- **push-to-start (iOS 17.2+):** dá pra iniciar a Activity **remotamente** (sem
  o app abrir), observando `pushToStartTokenUpdates` e enviando um push
  `liveactivity` com `"event": "start"` + `attributes` completos. Fora do escopo
  deste protótipo, mas o `LiveActivityManager` já está estruturado para receber
  essa extensão.

---

## 5. O que falta para produção

- [ ] **Criar o Widget Extension target no Xcode** e commitar o `project.pbxproj`
      (passos da seção 2). É o gargalo — nada roda sem isso.
- [ ] **APNs token-based (.p8)** + endpoint Django para registrar `pushToken`
      por Activity, e o worker que dispara os updates nos horários das marcações.
- [ ] **Enviar o pushToken ao backend**: o `observePushToken` já captura o token,
      falta o `POST` real (marcado com `TODO` no `LiveActivityManager.swift`).
- [ ] **Restaurar Activity no relaunch**: chamar
      `LiveActivityManager.shared.restoreActiveActivityIfNeeded()` no
      `application(_:didFinishLaunchingWithOptions:)` do `AppDelegate`.
- [ ] **v2 — botões interativos**: `App Intents` (`LiveActivityIntent`, iOS 16.2+
      / interatividade plena iOS 17+) para "Bater ponto" / "Iniciar intervalo"
      direto do card, sem abrir o app.
- [ ] **Localização real do local** no card (hoje é texto livre `local`).
- [ ] **Testes em device físico** — Live Activities **não** aparecem 100% no
      simulador para todos os estados (Dynamic Island só em iPhone 14 Pro+ / 15+).
- [ ] **Limites de conteúdo**: o payload de `content-state` tem limite de ~4KB;
      manter o `ContentState` enxuto.

---

## 6. Notas de API (versões)

- `ActivityConfiguration` + `DynamicIsland` — iOS 16.1.
- `Text(timerInterval:countsDown:)` para o cronômetro que corre sozinho no card
  (sem gastar push) — iOS 16.1. Usamos o intervalo `entrada...saidaPrevista`
  contando para cima.
- `ActivityContent` com `staleDate` e `Activity.update(_:alertConfiguration:)` —
  iOS 16.2 (o `LiveActivityManager` tem fallback para a API 16.1 legada).
- `pushType: .token` / `pushTokenUpdates` — iOS 16.1.
- `pushToStartTokenUpdates` (push-to-start) — iOS 17.2+.
