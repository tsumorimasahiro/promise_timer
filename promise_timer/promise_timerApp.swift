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

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-pochi-review-appearance"),
               ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
                PochiAppearanceReviewScreen(screen: ProcessInfo.processInfo.arguments[index + 1])
            } else if ProcessInfo.processInfo.arguments.contains("-pochi-review-premium") {
                PochiPremiumReviewScreen()
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                WidgetCenter.shared.reloadTimelines(ofKind: "PromiseTimerHabitCardWidget")
            }
        }
    }
}

#if DEBUG
/// Opens the real purchase view for review captures without modifying user data.
private struct PochiPremiumReviewScreen: View {
    @StateObject private var manager = SubscriptionManager()

    var body: some View {
        NavigationStack {
            UpgradeView(subscriptionManager: manager)
        }
    }
}
#endif
