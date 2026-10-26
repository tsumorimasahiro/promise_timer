import Foundation

let expected: [String: PochiRoomActivity] = [
    "water": .drink, "stretch": .stretch, "exercise": .stretch, "bath": .wash,
    "rest": .rest, "breath": .breathe, "outside": .stroll, "breakfast": .eat,
    "teeth": .selfCare, "sleep": .sleep, "sleepRoutine": .sleep, "walk": .stroll,
    "clean": .clean, "dishes": .clean, "laundry": .clean, "prepare": .study,
    "plants": .joy, "reading": .read, "readingPage": .read, "study": .study,
    "studyQuestion": .study, "language": .study, "journal": .study, "focus": .study,
    "message": .joy, "thanks": .joy, "hobby": .joy, "music": .listen, "photo": .pose
]
for (id, expected) in expected {
    let preset = HabitPreset(id: id, title: "Localized template", iconName: "sparkles", tintName: .peach)
    precondition(PochiPromiseReaction.activity(for: preset) == expected, id)
}
let custom: [(String, String, PochiRoomActivity)] = [
    ("ヨガをする", "figure.run", .stretch), ("ゆっくり休む", "bed.double.fill", .rest),
    ("水を飲む", "moon.fill", .drink), ("植物に水をあげる", "drop.fill", .joy),
    ("Water the plants", "drop.fill", .joy), ("Take a shower", "sparkles", .wash),
    ("Read a book", "sparkles", .read), ("Study mathematics", "sparkles", .study),
    ("Take a walk", "figure.run", .stroll), ("Running", "figure.walk", .exercise),
    ("Sleep early", "sparkles", .sleep), ("Dinner", "sparkles", .eat),
    ("명상", "sparkles", .breathe), ("물 마시기", "sparkles", .drink),
    ("拉伸", "sparkles", .stretch), ("吃飯", "sparkles", .eat),
    ("閱讀", "sparkles", .read), ("休息", "sparkles", .rest),
    ("My promise", "drop.fill", .drink), ("My promise", "figure.walk", .stroll),
    ("My promise", "sparkles", .joy), ("お皿洗い", "drop.fill", .clean)
]
for (title, icon, expected) in custom {
    let preset = HabitPreset(title: title, iconName: icon, tintName: .peach)
    precondition(PochiPromiseReaction.activity(for: preset) == expected, title)
}
precondition(PochiRoomActivity.read.learningActivity == .study)
precondition(PochiRoomActivity.stroll.learningActivity == .exercise)
precondition(PochiRoomActivity.stretch.learningActivity == .exercise)
precondition(PochiRoomActivity.wash.learningActivity == .selfCare)
var routine = PochiDailyRoutine()
routine.didComplete(.stroll)
precondition(routine.next(phase: .daytime, now: 0, world: .init(), habits: .init()).move == .cozyRest)
print("PASS: 29 template reactions, 22 multilingual/custom promises, content before icon, learning families and calm follow-up")
