//
//  ATTService.swift
//  Sketchly
//
//  App Tracking Transparency permission flow
//

import Foundation
import AppTrackingTransparency

@MainActor
@Observable
final class ATTService {
    static let shared = ATTService()

    var status: ATTrackingManager.AuthorizationStatus = .notDetermined

    var isAuthorized: Bool {
        status == .authorized
    }

    var isNotDetermined: Bool {
        status == .notDetermined
    }

    private init() {}

    func checkCurrentStatus() {
        status = ATTrackingManager.trackingAuthorizationStatus
    }

    func requestIfNeeded(completion: ((Bool) -> Void)? = nil) async -> Bool {
        let current = ATTrackingManager.trackingAuthorizationStatus
        guard current == .notDetermined else {
            status = current
            let isAuth = current == .authorized
            completion?(isAuth)
            return isAuth
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let result = await ATTrackingManager.requestTrackingAuthorization()
        status = result
        let isAuth = result == .authorized

        #if DEBUG
        print("[ATTService] ATT authorization result: \(isAuth)")
        #endif

        completion?(isAuth)
        return isAuth
    }
}
