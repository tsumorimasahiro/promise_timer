"""Run the actual archive/store code on macOS, with image bytes supplied by a stub.
UIKit rendering and the SwiftUI share sheet require a device and are not covered.
"""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[2]
out = root / '.build' / 'MemoryRegression'
out.mkdir(parents=True, exist_ok=True)
source = (root / 'promise_timer/PochiMemories.swift').read_text()
source = source.split('struct PochiAlbumAchievement: Identifiable {')[0]
source = source.replace('import SwiftUI', 'import Foundation').replace('import UIKit', '')
# Only the platform image boundary is replaced. All archive/selection/save logic is unchanged.
source += '''
struct UIImage {
    let data: Data
    init(data: Data) { self.data = data }
    init?(contentsOfFile path: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        self.data = data
    }
    func pngData() -> Data? { data }
}
'''
(out / 'MemoryStore.swift').write_text(source)
cmd = ['xcrun', 'swiftc', '-parse-as-library', '-module-cache-path', str(root / '.build/ModelTestCache')]
cmd += [str(root / ('promise_timer/' + name)) for name in ['HabitModels.swift', 'PochiWorldModels.swift', 'PochiLifeHabits.swift']]
cmd += [str(out / 'MemoryStore.swift'), str(root / 'Tests/MemoryRegression/main.swift'), '-o', str(out / 'run')]
subprocess.run(cmd, check=True, cwd=root)
subprocess.run([str(out / 'run')], check=True, cwd=root)
