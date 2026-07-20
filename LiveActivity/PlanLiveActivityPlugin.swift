//
//  PlanLiveActivityPlugin.swift
//  PLAN — Live Activity (protótipo)
//
//  Plugin nativo Capacitor que expõe start/update/end da Live Activity para o
//  lado web (JavaScript rodando dentro da WebView do wrapper).
//
//  ⚠️ Este arquivo pertence ao target **"App"**. Precisa do par de registro
//  Objective-C (`PlanLiveActivityPlugin.m`) para o Capacitor descobrir o plugin.
//
//  Assinatura JS (ver README_LIVE_ACTIVITY.md):
//
//    import { registerPlugin } from '@capacitor/core';
//    const PlanLiveActivity = registerPlugin('PlanLiveActivity');
//
//    await PlanLiveActivity.isSupported(); // { supported: boolean, enabled: boolean }
//
//    const { activityId } = await PlanLiveActivity.start({
//      instituicaoNome: 'Santa Casa',
//      entradaISO: '2026-07-20T07:00:00-03:00',
//      saidaPrevistaISO: '2026-07-20T19:00:00-03:00',
//      local: 'Pronto-Socorro — Ala B',
//      proximaMarcacaoLabel: 'Intervalo',
//      proximaMarcacaoHorarioISO: '2026-07-20T13:00:00-03:00',
//      statusLabel: 'Em andamento',
//    });
//
//    await PlanLiveActivity.update({
//      proximaMarcacaoLabel: 'Volta do intervalo',
//      proximaMarcacaoHorarioISO: '2026-07-20T14:00:00-03:00',
//      statusLabel: 'Em intervalo',
//    });
//
//    await PlanLiveActivity.end({ finalStatusLabel: 'Plantão encerrado' });
//

import Capacitor
import Foundation

@objc(PlanLiveActivityPlugin)
public class PlanLiveActivityPlugin: CAPPlugin {

    // MARK: - isSupported

    @objc func isSupported(_ call: CAPPluginCall) {
        if #available(iOS 16.1, *) {
            let enabled = LiveActivityManager.shared.areActivitiesEnabled
            call.resolve([
                "supported": true,
                "enabled": enabled
            ])
        } else {
            call.resolve([
                "supported": false,
                "enabled": false
            ])
        }
    }

    // MARK: - start

    @objc func start(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.reject("Live Activities requerem iOS 16.1 ou superior.", "UNSUPPORTED_OS")
            return
        }

        guard
            let instituicaoNome = call.getString("instituicaoNome"),
            let entradaISO = call.getString("entradaISO"),
            let saidaPrevistaISO = call.getString("saidaPrevistaISO"),
            let local = call.getString("local"),
            let proximaMarcacaoLabel = call.getString("proximaMarcacaoLabel"),
            let statusLabel = call.getString("statusLabel")
        else {
            call.reject("Parâmetros obrigatórios ausentes.", "INVALID_ARGS")
            return
        }

        // Opcional: pode vir nulo quando não há próxima marcação.
        let proximaISO = call.getString("proximaMarcacaoHorarioISO")
        let staleAfter = call.getDouble("staleAfterSeconds")

        do {
            let activityId = try LiveActivityManager.shared.start(
                instituicaoNome: instituicaoNome,
                entradaISO: entradaISO,
                saidaPrevistaISO: saidaPrevistaISO,
                local: local,
                proximaMarcacaoLabel: proximaMarcacaoLabel,
                proximaMarcacaoHorarioISO: proximaISO,
                statusLabel: statusLabel,
                staleAfterSeconds: staleAfter
            )
            call.resolve(["activityId": activityId])
        } catch let error as LiveActivityError {
            call.reject(error.localizedDescription, "NOT_ENABLED")
        } catch {
            call.reject("Falha ao iniciar Live Activity: \(error.localizedDescription)", "START_FAILED")
        }
    }

    // MARK: - update

    @objc func update(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.reject("Live Activities requerem iOS 16.1 ou superior.", "UNSUPPORTED_OS")
            return
        }

        guard
            let proximaMarcacaoLabel = call.getString("proximaMarcacaoLabel"),
            let statusLabel = call.getString("statusLabel")
        else {
            call.reject("Parâmetros obrigatórios ausentes.", "INVALID_ARGS")
            return
        }

        let proximaISO = call.getString("proximaMarcacaoHorarioISO")
        let staleAfter = call.getDouble("staleAfterSeconds")

        Task {
            await LiveActivityManager.shared.update(
                proximaMarcacaoLabel: proximaMarcacaoLabel,
                proximaMarcacaoHorarioISO: proximaISO,
                statusLabel: statusLabel,
                staleAfterSeconds: staleAfter
            )
            call.resolve()
        }
    }

    // MARK: - end

    @objc func end(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.reject("Live Activities requerem iOS 16.1 ou superior.", "UNSUPPORTED_OS")
            return
        }

        let finalStatus = call.getString("finalStatusLabel")
        let dismissAfter = call.getDouble("dismissAfterSeconds") // nil = política padrão

        Task {
            await LiveActivityManager.shared.end(
                finalStatusLabel: finalStatus,
                dismissAfterSeconds: dismissAfter
            )
            call.resolve()
        }
    }
}
