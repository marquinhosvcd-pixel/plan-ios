//
//  PlanLiveActivityPlugin.m
//  PLAN — Live Activity (protótipo)
//
//  Registro Objective-C do plugin Capacitor. Sem este arquivo, o Capacitor NÃO
//  descobre o plugin Swift em runtime (a bridge lê os macros CAP_PLUGIN via ObjC).
//
//  ⚠️ Pertence ao target **"App"**. O nome passado em CAP_PLUGIN ("PlanLiveActivity")
//  é o mesmo usado no JS: registerPlugin('PlanLiveActivity').
//

#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(PlanLiveActivityPlugin, "PlanLiveActivity",
    CAP_PLUGIN_METHOD(isSupported, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(start, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(update, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(end, CAPPluginReturnPromise);
)
