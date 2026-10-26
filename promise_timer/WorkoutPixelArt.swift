import Foundation

/// Pixel-authored exercise figures on a 24 × 24 grid. No stroked curves or SF Symbols.
enum WorkoutPixelArt {
    struct Pixel { let x: Int; let y: Int; let tone: Int }
    static let names = ["squat", "pushup", "crunch", "plank", "sidePlank", "birdDog", "deadBug", "lunge", "dumbbell.fill", "bridge", "calf"]
    static func pixels(for name: String) -> [Pixel] {
        let data: ((Int, Int), [[Int]])
        switch name {
        case "squat", "figure.strengthtraining.traditional": data = ((10, 4), [[10,7,11,12,6,14,10,20,15,20],[10,8,15,10,19,9]])
        case "pushup", "figure.strengthtraining.functional": data = ((4, 8), [[7,10,16,12,21,18],[8,11,8,18,4,18],[2,21,22,21]])
        case "crunch": data = ((7, 10), [[8,13,12,18,16,13,21,18],[8,13,4,15],[2,21,22,21]])
        case "plank": data = ((4, 8), [[7,10,17,11,21,17],[8,10,6,17,3,17],[2,21,22,21]])
        case "sidePlank": data = ((6, 7), [[8,10,14,15,21,18],[8,10,5,18,2,18],[8,10,14,4],[2,21,22,21]])
        case "birdDog": data = ((6, 8), [[8,11,15,11,22,6],[9,11,2,6],[9,11,9,19],[15,11,17,19]])
        case "deadBug": data = ((5, 17), [[8,18,15,18,18,11,22,12],[9,18,9,8],[15,18,16,10,13,6],[2,21,22,21]])
        case "lunge": data = ((11, 4), [[11,7,11,12,6,13,6,20,2,20],[11,12,17,19,22,19],[11,8,16,10]])
        case "bridge": data = ((4, 17), [[7,18,13,11,18,12,21,19],[7,18,13,19],[2,21,22,21]])
        case "calf": data = ((11, 3), [[11,6,11,12,9,20,13,20],[11,12,16,19],[11,8,6,11],[4,23,20,23]])
        default: data = ((11, 3), [[11,6,11,12,7,21],[11,12,16,21],[11,8,17,11,20,7],[18,5,22,9],[11,8,5,12]])
        }
        var grid = Array(repeating: 0, count: 24 * 24)
        func paint(_ x: Int, _ y: Int, _ tone: Int) {
            if (0..<24).contains(x), (0..<24).contains(y) { grid[y * 24 + x] = tone }
        }
        // Each joint and limb is drawn in square pixels, including the stepped diagonals.
        for limb in data.1 {
            let mat = limb.count == 4 && limb[1] == limb[3] && limb[1] >= 21
            for i in stride(from: 0, to: limb.count - 2, by: 2) {
                var x = limb[i], y = limb[i + 1]
                let endX = limb[i + 2], endY = limb[i + 3]
                let dx = abs(endX - x), dy = -abs(endY - y)
                let sx = x < endX ? 1 : -1, sy = y < endY ? 1 : -1
                var error = dx + dy
                while true {
                    paint(x, y, mat ? 3 : 1)
                    if !mat { paint(x + 1, y, 1); paint(x, y + 1, 1) }
                    if x == endX && y == endY { break }
                    let twice = error * 2
                    if twice >= dy { error += dy; x += sx }
                    if twice <= dx { error += dx; y += sy }
                }
            }
        }
        let head = [".XX.", "XXXX", "XXXX", ".XX."]
        for (y, row) in head.enumerated() {
            for (x, dot) in row.enumerated() where dot == "X" { paint(data.0.0 + x - 1, data.0.1 + y - 1, 2) }
        }
        return grid.enumerated().compactMap { index, tone in
            tone == 0 ? nil : Pixel(x: index % 24, y: index / 24, tone: tone)
        }
    }
}
