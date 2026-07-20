//
//  LiveActivityManager.swift
//  PLAN — Live Activity (protótipo)
//
//  Helper que encapsula o ciclo de vida de uma `Activity<PlantaoAttributes>`
//  (start / update / end) via ActivityKit.
//
//  ⚠️ Este arquivo pertence ao target **"App"** (não à Widget Extension).
//  Marque `PlantaoAttributes.swift` como membro dos DOIS targets para que o
//  tipo seja visível aqui e na extensão.
//
//  Requer iOS 16.1+.
//

import ActivityKit
import Foundation
import os

@available(iOS 16.1, *)
public final class LiveActivityManager {

    public static let shared = LiveActivityManager()
    private init() {}

    private let log = Logger(subsystem: "br.com.planescala.app", category: "LiveActivity")

    /// Activity atualmente ativa iniciada por este processo (se houver).
    private var activity: Activity<PlantaoAttributes>?

    // MARK: - Disponibilidade

    /// `true` se o usuário permite Live Activities e o SO suporta.
    public var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Start

    /// Inicia uma Live Activity de plantão.
    /// - Returns: o `id` da Activity criada (útil para o backend endereçar updates via push).
    /// - Throws: `LiveActivityError` se desabilitado, ou erros do ActivityKit.
    @discardableResult
    public func start(
        instituicaoNome: String,
        entradaISO: String,
        saidaPrevistaISO: String,
        local: String,
        proximaMarcacaoLabel: String,
        proximaMarcacaoHorarioISO: String?,
        statusLabel: String,
        staleAfterSeconds: TimeInterval? = nil
    ) throws -> String {
        guard areActivitiesEnabled else {
            throw LiveActivityError.notEnabled
        }

        // Evita duplicatas: se já houver uma ativa, encerra antes de recriar.
        if activity != nil {
            log.info("start() chamado com Activity já ativa — encerrando a anterior.")
            endImmediately()
        }

        let attributes = PlantaoAttributes(
            instituicaoNome: instituicaoNome,
            entradaISO: entradaISO,
            saidaPrevistaISO: saidaPrevistaISO,
            local: local
        )

        let state = PlantaoAttributes.ContentState(
            proximaMarcacaoLabel: proximaMarcacaoLabel,
            proximaMarcacaoHorarioISO: proximaMarcacaoHorarioISO,
            statusLabel: statusLabel
        )

        do {
            let newActivity: Activity<PlantaoAttributes>
            if #available(iOS 16.2, *) {
                // API 16.2+: `ActivityContent` com `staleDate` opcional.
                let staleDate = staleAfterSeconds.map { Date().addingTimeInterval($0) }
                let content = ActivityContent(state: state, staleDate: staleDate)
                newActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: .token // habilita push updates; ver README (APNs)
                )
            } else {
                // API 16.1: assinatura legada com `contentState:`.
                newActivity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: .token
                )
            }
            activity = newActivity
            observePushToken(for: newActivity)
            log.info("Live Activity iniciada id=\(newActivity.id, privacy: .public)")
            return newActivity.id
        } catch {
            log.error("Falha ao iniciar Live Activity: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    // MARK: - Update

    /// Atualiza o estado dinâmico da Activity ativa (localmente, sem push).
    public func update(
        proximaMarcacaoLabel: String,
        proximaMarcacaoHorarioISO: String?,
        statusLabel: String,
        staleAfterSeconds: TimeInterval? = nil,
        alert: AlertConfiguration? = nil
    ) async {
        guard let activity = activity else {
            log.warning("update() sem Activity ativa.")
            return
        }

        let state = PlantaoAttributes.ContentState(
            proximaMarcacaoLabel: proximaMarcacaoLabel,
            proximaMarcacaoHorarioISO: proximaMarcacaoHorarioISO,
            statusLabel: statusLabel
        )

        if #available(iOS 16.2, *) {
            let staleDate = staleAfterSeconds.map { Date().addingTimeInterval($0) }
            let content = ActivityContent(state: state, staleDate: staleDate)
            await activity.update(content, alertConfiguration: alert)
        } else {
            await activity.update(using: state)
        }
        log.info("Live Activity atualizada id=\(activity.id, privacy: .public)")
    }

    // MARK: - End

    /// Encerra a Activity ativa com um estado final opcional.
    /// - Parameter dismissAfterSeconds: quanto tempo o card permanece visível
    ///   após encerrar (nil = política padrão do sistema, ~até 4h).
    public func end(
        finalStatusLabel: String? = nil,
        dismissAfterSeconds: TimeInterval? = 0
    ) async {
        guard let activity = activity else {
            log.warning("end() sem Activity ativa.")
            return
        }

        let dismissal: ActivityUIDismissalPolicy = {
            guard let secs = dismissAfterSeconds else { return .default }
            if secs <= 0 { return .immediate }
            return .after(Date().addingTimeInterval(secs))
        }()

        if #available(iOS 16.2, *) {
            // Deriva estado final a partir do atual, sobrescrevendo o status.
            let base = activity.content.state
            let finalState = PlantaoAttributes.ContentState(
                proximaMarcacaoLabel: base.proximaMarcacaoLabel,
                proximaMarcacaoHorarioISO: base.proximaMarcacaoHorarioISO,
                statusLabel: finalStatusLabel ?? "Plantão encerrado"
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: dismissal)
        } else {
            await activity.end(dismissalPolicy: dismissal)
        }

        self.activity = nil
        log.info("Live Activity encerrada.")
    }

    /// Encerramento síncrono "fire-and-forget" (usado internamente ao recriar).
    private func endImmediately() {
        guard let activity = activity else { return }
        self.activity = nil
        Task {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: - Recuperação de estado

    /// Reassocia a Activity ativa após o app reabrir (o sistema mantém a Activity
    /// viva mesmo com o app fechado). Chame no `didFinishLaunching`.
    public func restoreActiveActivityIfNeeded() {
        if activity == nil, let running = Activity<PlantaoAttributes>.activities.first {
            activity = running
            observePushToken(for: running)
            log.info("Activity reassociada após relaunch id=\(running.id, privacy: .public)")
        }
    }

    // MARK: - Push token

    /// Observa o push token desta Activity e o envia ao backend.
    /// O backend usa esse token para endereçar updates/end via APNs (liveactivity).
    private func observePushToken(for activity: Activity<PlantaoAttributes>) {
        Task {
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                log.info("Push token da Activity: \(token, privacy: .private)")
                // TODO(produção): POST para o backend Django, associando token à Activity.id.
                // await PlanAPI.registerLiveActivityToken(activityId: activity.id, token: token)
            }
        }
    }
}

// MARK: - Erros

@available(iOS 16.1, *)
public enum LiveActivityError: LocalizedError {
    case notEnabled

    public var errorDescription: String? {
        switch self {
        case .notEnabled:
            return "Live Activities estão desativadas nas configurações do iPhone."
        }
    }
}
