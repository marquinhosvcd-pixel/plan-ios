//
//  PlantaoAttributes.swift
//  PLAN — Live Activity (protótipo)
//
//  Descreve os dados de uma Live Activity de plantão de saúde.
//
//  Divisão dos dados (importante para performance/custo de push):
//   - Atributos ESTÁTICOS (`PlantaoAttributes`): definidos no start e nunca mudam
//     durante a vida da Activity (nome da instituição, horários planejados, local).
//   - Estado DINÂMICO (`ContentState`): tudo que muda ao longo do plantão e é
//     enviado em cada update (próxima marcação, status). Mantenha-o pequeno.
//
//  Requer iOS 16.1+. Este arquivo é compartilhado entre o app (target "App") e
//  a Widget Extension. Ao adicionar no Xcode, marque AMBOS os targets em
//  "Target Membership".
//
//  ⚠️ Não usar `Date` diretamente aqui e sim strings ISO-8601, porque o backend
//  Django enviará os updates como JSON (payload APNs) usando o mesmo formato.
//  As datas são decodificadas em `Date` no momento de montar a View.
//

import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct PlantaoAttributes: ActivityAttributes {

    // MARK: - Estado dinâmico (muda a cada update / push)
    public struct ContentState: Codable, Hashable {
        /// Rótulo humano da próxima marcação. Ex.: "Intervalo", "Volta do intervalo", "Saída".
        public var proximaMarcacaoLabel: String

        /// Horário previsto da próxima marcação, em ISO-8601 (ex.: "2026-07-20T18:00:00-03:00").
        /// Opcional: quando não há próxima marcação (fim do plantão), fica `nil`.
        public var proximaMarcacaoHorarioISO: String?

        /// Rótulo curto do status atual do plantão. Ex.: "Em andamento", "Em intervalo", "Encerrando".
        public var statusLabel: String

        public init(
            proximaMarcacaoLabel: String,
            proximaMarcacaoHorarioISO: String?,
            statusLabel: String
        ) {
            self.proximaMarcacaoLabel = proximaMarcacaoLabel
            self.proximaMarcacaoHorarioISO = proximaMarcacaoHorarioISO
            self.statusLabel = statusLabel
        }

        /// Converte o horário ISO da próxima marcação em `Date`, se presente/válido.
        public var proximaMarcacaoDate: Date? {
            guard let iso = proximaMarcacaoHorarioISO else { return nil }
            return PlantaoAttributes.isoFormatter.date(from: iso)
        }
    }

    // MARK: - Atributos estáticos (fixados no start)

    /// Nome da instituição/hospital do plantão. Ex.: "Santa Casa".
    public var instituicaoNome: String

    /// Horário de entrada (início do plantão) em ISO-8601. Base do cronômetro decorrido.
    public var entradaISO: String

    /// Horário previsto de saída em ISO-8601.
    public var saidaPrevistaISO: String

    /// Local/setor legível. Ex.: "Pronto-Socorro — Ala B".
    public var local: String

    public init(
        instituicaoNome: String,
        entradaISO: String,
        saidaPrevistaISO: String,
        local: String
    ) {
        self.instituicaoNome = instituicaoNome
        self.entradaISO = entradaISO
        self.saidaPrevistaISO = saidaPrevistaISO
        self.local = local
    }

    // MARK: - Conveniências de data

    /// Formatter ISO-8601 tolerante (com e sem fração de segundos).
    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Formatter de fallback sem fração de segundos.
    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseISO(_ value: String) -> Date? {
        isoFormatter.date(from: value) ?? isoFormatterNoFraction.date(from: value)
    }

    /// `Date` de entrada (início do plantão). Fallback: agora.
    public var entradaDate: Date {
        PlantaoAttributes.parseISO(entradaISO) ?? Date()
    }

    /// `Date` prevista de saída. Fallback: entrada + 12h.
    public var saidaPrevistaDate: Date {
        PlantaoAttributes.parseISO(saidaPrevistaISO)
            ?? entradaDate.addingTimeInterval(12 * 3600)
    }
}
