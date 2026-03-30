//
//  promise_timerApp.swift
//  promise_timer
//
//  Created by 津守将弘 on 2026/03/15.
//

import SwiftUI
import GoogleMobileAds

@main
struct promise_timerApp: App {
    init() {
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
