# Daily memory persistence regression

Run `python3 Tests/MemoryRegression/run.py` from the repository root.

The runner compiles the actual store/model portion of PochiMemories.swift on macOS.
Only the UIKit image boundary is replaced with a data stub. All production archive,
selection, and file-write logic is used unchanged. Each run uses a UUID temporary
directory and removes only that directory. Actual user data is never opened.

Checks: automatic photo deduplication, special-moment priority, manually chosen
photo priority, protection from automatic replacement, reload, original-file
retention, yesterday rejection, old archive compatibility, metadata write failure,
and corrupt-archive protection.

This does not validate PNG encoding, SpriteKit capture, SwiftUI layout, or the iOS
share sheet. Those require simulator/device confirmation.

Workout renewal: only captures explicitly marked as training photos may become daily photos. Legacy idle/story photos are hidden. Backfill and idle capture are rejected; atomic-save/corrupt-archive protections still apply.
