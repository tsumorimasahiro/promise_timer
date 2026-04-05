//
//  Promise_Timer_WidgetLiveActivity.swift
//  Promise​Timer​Widget
//
//  Created by 津守将弘 on 2026/04/04.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Promise_Timer_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Promise_Timer_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Promise_Timer_WidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension Promise_Timer_WidgetAttributes {
    fileprivate static var preview: Promise_Timer_WidgetAttributes {
        Promise_Timer_WidgetAttributes(name: "World")
    }
}

extension Promise_Timer_WidgetAttributes.ContentState {
    fileprivate static var smiley: Promise_Timer_WidgetAttributes.ContentState {
        Promise_Timer_WidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Promise_Timer_WidgetAttributes.ContentState {
         Promise_Timer_WidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Promise_Timer_WidgetAttributes.preview) {
   Promise_Timer_WidgetLiveActivity()
} contentStates: {
    Promise_Timer_WidgetAttributes.ContentState.smiley
    Promise_Timer_WidgetAttributes.ContentState.starEyes
}
