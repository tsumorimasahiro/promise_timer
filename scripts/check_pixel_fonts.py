#!/usr/bin/env python3
"""Guard app-owned typography. A static check, not a Swift parser or visual test."""
import plistlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FONT = 'PixelMplus12-Bold'


def code_mask(source):
    # Keep offsets/newlines for diagnostics, but ignore comments and string contents.
    tokens = r'//[^\n]*|/\*.*?\*/|""".*?"""|"(?:\\.|[^"\\])*"'
    def mask(match):
        value = match.group()
        blank = ''.join('\n' if c == '\n' else ' ' for c in value)
        return '"' + blank[1:-1] + '"' if value.startswith('"') else blank
    return re.sub(tokens, mask, source, flags=re.S)


def violations(source, central=False, navigation_helper=False):
    code = code_mask(source)
    errors = []
    def fail(offset, reason):
        errors.append((source.count('\n', 0, offset) + 1, reason))
    for match in re.finditer(r'\.font\s*\(', code):
        rest = code[match.end():].lstrip()
        icon = re.search(r'\bImage\s*\(\s*systemName\s*:\s*"[ ]*"\s*\)\s*$', code[:match.start()])
        if not rest.startswith('pochiPixelFont(') and not icon:
            fail(match.start(), 'Text must use pochiPixelFont; only a direct SF Symbol image may use a system font.')
    for match in re.finditer(r'\.font\s*=\s*([^\n;]+)', code):
        if not match.group(1).startswith('pochiPixelUIFont('):
            fail(match.start(), 'UIKit text must use pochiPixelUIFont.')
    if not central:
        for match in re.finditer(r'\b(?:UI)?Font\s*\(|\b(?:UI)?Font\s*\.|\.custom\s*\(|\.(?:systemFont|boldSystemFont|italicSystemFont|preferredFont|monospacedSystemFont|monospacedDigitSystemFont)\s*\(', code):
            fail(match.start(), 'Create fonts only in PochiTypography.swift; use the shared helpers.')
    for match in re.finditer(r'\.fontDesign\s*\(|\.environment\s*\(\s*\\\.font\b', code):
        fail(match.start(), 'Do not override the shared pixel typography environment/design.')
    for match in re.finditer(r'\.fontName\s*=\s*([^\n;]+)', code):
        original = source[match.start(1):match.end(1)].strip()
        if original != '"' + FONT + '"':
            fail(match.start(), 'SpriteKit labels must use PixelMplus12-Bold.')
    if not navigation_helper:
        for match in re.finditer(r'\.navigationTitle\s*\(', code):
            if not re.match(r'\s*""\s*\)', source[match.end():]):
                fail(match.start(), 'Use pochiNavigationTitle for visible navigation titles.')
    return errors


def check(root=ROOT):
    errors = []
    app = root / 'promise_timer'
    widgets = list(root.glob('*Widget'))
    for folder in [app, *widgets]:
        for path in sorted(folder.rglob('*.swift')):
            relative = path.relative_to(root)
            for line, reason in violations(path.read_text(),
                    central=path == app / 'PochiTypography.swift',
                    navigation_helper=path == app / 'PochiPixelUI.swift'):
                errors.append(f'{relative}:{line}: {reason}')
    entry = (app / 'promise_timerApp.swift').read_text()
    if not re.search(r'\.font\(\s*pochiPixelFont\(\.body\)\s*\)', entry):
        errors.append('App root must retain .font(pochiPixelFont(.body)).')
    typography = (app / 'PochiTypography.swift').read_text()
    if not re.search(r'\.custom\("' + FONT + r'"', typography) or not re.search(r'UIFont\(name: "' + FONT + r'"', typography):
        errors.append('Shared SwiftUI/UIKit helpers must use PixelMplus12-Bold.')
    for folder, info in [(app, root / 'AppInfo.plist'), *[(w, w / 'Info.plist') for w in widgets]]:
        fonts = plistlib.loads(info.read_bytes()).get('UIAppFonts', [])
        if fonts != [FONT + '.ttf'] or not (folder / (FONT + '.ttf')).is_file():
            errors.append(f'{info.relative_to(root)}: register and bundle the shared pixel font.')
        elif (folder / (FONT + '.ttf')).read_bytes() != (app / (FONT + '.ttf')).read_bytes():
            errors.append(f'{folder.name}: widget and app fonts must match.')
    return errors


if __name__ == '__main__':
    problems = check()
    print('\n'.join(problems) if problems else 'Pixel typography check passed (app + widget).')
    raise SystemExit(bool(problems))
