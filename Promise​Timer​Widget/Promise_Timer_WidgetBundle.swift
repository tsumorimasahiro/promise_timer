//
//  Promise_Timer_WidgetBundle.swift
//  PromiseTimerWidget
//
//  Created by 津守将弘 on 2026/04/04.
//

import WidgetKit
import SwiftUI

@main
struct Promise_Timer_WidgetBundle: WidgetBundle {
    var body: some Widget {
        HabitCardWidget()
        Promise_Timer_WidgetControl()
        Promise_Timer_WidgetLiveActivity()
    }
}
