//
//  AttributionManager.swift
//  Sketchly
//
//  Handles Apple Search Ads attribution via AdServices framework
//

import Foundation
import AdServices

@MainActor
final class AttributionManager {
    static let shared = AttributionManager()

    private let hasRequestedAttributionKey = "com.appfactory.sketchly.hasRequestedAttribution"
    private let attributionTokenKey = "com.appfactory.sketchly.attributionToken"

    private var hasRequestedAttribution: Bool {
        get { UserDefaults.standard.bool(forKey: hasRequestedAttributionKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasRequestedAttributionKey) }
    }

    var storedAttributionToken: String? {
        UserDefaults.standard.string(forKey: attributionTokenKey)
    }

    private init() {}

    func requestAttributionIfNeeded() async {
        guard !hasRequestedAttribution else {
            #if DEBUG
            print("[Attribution] Already requested attribution, skipping")
            #endif
            return
        }

        await requestAttribution()
    }

    private func requestAttribution() async {
        hasRequestedAttribution = true

        do {
            let token = try AAAttribution.attributionToken()
            UserDefaults.standard.set(token, forKey: attributionTokenKey)

            #if DEBUG
            print("[Attribution] Successfully obtained attribution token: \(token.prefix(50))...")
            #endif

            await sendAttributionToBackend(token: token)
        } catch {
            handleAttributionError(error)
        }
    }

    private func sendAttributionToBackend(token: String) async {
        #if DEBUG
        print("[Attribution] Token ready to send to backend: \(token.prefix(50))...")
        #endif
        // TODO: Implement actual backend call
    }

    private func handleAttributionError(_ error: Error) {
        let nsError = error as NSError
        #if DEBUG
        print("[Attribution] Error: \(error.localizedDescription) (code: \(nsError.code))")
        #endif
    }
}
