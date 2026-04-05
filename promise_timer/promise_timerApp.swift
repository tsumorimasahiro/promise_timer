//
//  promise_timerApp.swift
//  promise_timer
//
//  Created by 津守将弘 on 2026/03/15.
//

import SwiftUI
import GoogleMobileAds
import WidgetKit

@main
struct promise_timerApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                WidgetCenter.shared.reloadTimelines(ofKind: "PromiseTimerHabitCardWidget")
            }
        }
    }
}
