//
//  PlantaoLiveActivity.swift
//  PLAN — Live Activity (protótipo)
//
//  Define o Widget (`ActivityConfiguration`) usado para renderizar a Live
//  Activity do plantão na tela de bloqueio e na Dynamic Island.
//
//  ⚠️ Este arquivo pertence ao target da **Widget Extension** (NÃO ao target
//  "App"). Ver README_LIVE_ACTIVITY.md para o passo a passo de criação do target.
//
//  Requer iOS 16.1+. As APIs de Dynamic Island (`DynamicIsland`,
//  `dynamicIsland:`) fazem parte do WidgetKit + ActivityKit.
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Identidade visual PLAN

private enum PlanColors {
    /// Fundo escuro da marca (#101828).
    static let fundo = Color(red: 0x10 / 255, green: 0x18 / 255, blue: 0x28 / 255)
    /// Verde da marca (#0F6E56).
    static let verde = Color(red: 0x0F / 255, green: 0x6E / 255, blue: 0x56 / 255)
    /// Verde mais claro para acentos sobre fundo escuro.
    static let verdeClaro = Color(red: 0x2E / 255, green: 0xB8 / 255, blue: 0x8F / 255)
    static let textoPrimario = Color.white
    static let textoSecundario = Color.white.opacity(0.72)
}

// MARK: - Widget principal

@available(iOS 16.1, *)
struct PlantaoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlantaoAttributes.self) { context in
            // Tela de bloqueio + banner (iOS 16 antes do Dynamic Island / iPhones sem DI).
            PlantaoLockScreenView(context: context)
                .activityBackgroundTint(PlanColors.fundo)
                .activitySystemActionForegroundColor(PlanColors.verdeClaro)

        } dynamicIsland: { context in
            DynamicIsland {
                // Região expandida (usuário toca/segura a ilha).
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label {
                            Text(context.attributes.instituicaoNome)
                                .font(.headline)
                                .foregroundStyle(PlanColors.textoPrimario)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "cross.case.fill")
                                .foregroundStyle(PlanColors.verdeClaro)
                        }
                        Text(context.attributes.local)
                            .font(.caption2)
                            .foregroundStyle(PlanColors.textoSecundario)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Decorrido")
                            .font(.caption2)
                            .foregroundStyle(PlanColors.textoSecundario)
                        Text(
                            timerInterval: context.attributes.entradaDate...context.attributes.saidaPrevistaDate,
                            countsDown: false
                        )
                        .font(.system(.title3, design: .rounded).monospacedDigit())
                        .foregroundStyle(PlanColors.textoPrimario)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        proximaMarcacaoView(context: context)
                        Spacer(minLength: 8)
                        statusChip(context.state.statusLabel)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                // Lado esquerdo compacto: ícone da marca.
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(PlanColors.verdeClaro)
            } compactTrailing: {
                // Lado direito compacto: cronômetro decorrido.
                Text(
                    timerInterval: context.attributes.entradaDate...context.attributes.saidaPrevistaDate,
                    countsDown: false
                )
                .font(.system(.body, design: .rounded).monospacedDigit())
                .foregroundStyle(PlanColors.textoPrimario)
                .frame(maxWidth: 56)
            } minimal: {
                // Estado minimal (várias Activities): só o ícone tingido.
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(PlanColors.verdeClaro)
            }
            .widgetURL(URL(string: "planescala://plantao/atual"))
            .keylineTint(PlanColors.verde)
        }
    }

    // MARK: - Subviews da Dynamic Island (expandida)

    @ViewBuilder
    private func proximaMarcacaoView(context: ActivityViewContext<PlantaoAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Próxima marcação")
                .font(.caption2)
                .foregroundStyle(PlanColors.textoSecundario)
            HStack(spacing: 4) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.caption2)
                    .foregroundStyle(PlanColors.verdeClaro)
                Text(context.state.proximaMarcacaoLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PlanColors.textoPrimario)
                if let data = context.state.proximaMarcacaoDate {
                    Text(data, style: .time)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(PlanColors.textoSecundario)
                }
            }
        }
    }

    @ViewBuilder
    private func statusChip(_ label: String) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(PlanColors.verdeClaro)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(PlanColors.verde.opacity(0.25))
            )
    }
}

// MARK: - Lock screen / banner

@available(iOS 16.1, *)
struct PlantaoLockScreenView: View {
    let context: ActivityViewContext<PlantaoAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                // Instituição + status
                HStack(spacing: 6) {
                    Image(systemName: "cross.case.fill")
                        .foregroundStyle(PlanColors.verdeClaro)
                    Text(context.attributes.instituicaoNome)
                        .font(.headline)
                        .foregroundStyle(PlanColors.textoPrimario)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(context.state.statusLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PlanColors.verdeClaro)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(PlanColors.verde.opacity(0.25)))
                }

                // Local
                Label {
                    Text(context.attributes.local)
                        .font(.subheadline)
                        .foregroundStyle(PlanColors.textoSecundario)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(PlanColors.textoSecundario)
                }

                // Próxima marcação
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(PlanColors.verdeClaro)
                    Text("Próxima: \(context.state.proximaMarcacaoLabel)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PlanColors.textoPrimario)
                    if let data = context.state.proximaMarcacaoDate {
                        Text(data, style: .time)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(PlanColors.textoSecundario)
                    }
                }
            }

            // Bloco do cronômetro decorrido
            VStack(alignment: .trailing, spacing: 2) {
                Text("Decorrido")
                    .font(.caption2)
                    .foregroundStyle(PlanColors.textoSecundario)
                Text(
                    timerInterval: context.attributes.entradaDate...context.attributes.saidaPrevistaDate,
                    countsDown: false
                )
                .font(.system(.title2, design: .rounded).monospacedDigit())
                .foregroundStyle(PlanColors.textoPrimario)
                .frame(maxWidth: 96)
                Text("de \(saidaPrevistaFormatada)")
                    .font(.caption2)
                    .foregroundStyle(PlanColors.textoSecundario)
            }
        }
        .padding(16)
    }

    private var saidaPrevistaFormatada: String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: context.attributes.saidaPrevistaDate)
    }
}

// MARK: - Bundle do Widget
//
// Se a Widget Extension só contém esta Live Activity, use este bundle como
// @main. Se você já tem outros widgets, adicione `PlantaoLiveActivity()` ao
// seu WidgetBundle existente em vez de declarar outro @main.

@available(iOS 16.1, *)
@main
struct PlanWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlantaoLiveActivity()
    }
}

// MARK: - Previews (Xcode 15+)

#if DEBUG
@available(iOS 17.0, *)
#Preview("Lock Screen", as: .content, using: PlantaoAttributes.previewSample) {
    PlantaoLiveActivity()
} contentStates: {
    PlantaoAttributes.ContentState.emAndamento
    PlantaoAttributes.ContentState.emIntervalo
}

@available(iOS 16.1, *)
extension PlantaoAttributes {
    static var previewSample: PlantaoAttributes {
        PlantaoAttributes(
            instituicaoNome: "Santa Casa",
            entradaISO: "2026-07-20T07:00:00-03:00",
            saidaPrevistaISO: "2026-07-20T19:00:00-03:00",
            local: "Pronto-Socorro — Ala B"
        )
    }
}

@available(iOS 16.1, *)
extension PlantaoAttributes.ContentState {
    static var emAndamento: PlantaoAttributes.ContentState {
        .init(
            proximaMarcacaoLabel: "Intervalo",
            proximaMarcacaoHorarioISO: "2026-07-20T13:00:00-03:00",
            statusLabel: "Em andamento"
        )
    }
    static var emIntervalo: PlantaoAttributes.ContentState {
        .init(
            proximaMarcacaoLabel: "Volta do intervalo",
            proximaMarcacaoHorarioISO: "2026-07-20T14:00:00-03:00",
            statusLabel: "Em intervalo"
        )
    }
}
#endif
