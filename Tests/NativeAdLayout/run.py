#!/usr/bin/env python3
"""Run only inside simulator_session.py; this script never boots/stops devices."""
import json, os, subprocess, sys, time
from pathlib import Path

udid = sys.argv[1]
assert udid == os.environ['SIMULATOR_UDID']
cli = ['xcrun', 'simctl', '--set', os.environ['SIMULATOR_DEVICE_SET']]
out = Path('Design/NativeAdBoundsReview').resolve()
def sim(*args, check=True, timeout=60):
    return subprocess.run([*cli, *args], check=check, capture_output=True, text=True, timeout=timeout)
sim('install', udid, str(Path('.build/GrowthDerivedData/Build/Products/Debug-iphonesimulator/promise_timer.app').resolve()), timeout=90)
container = Path(sim('get_app_container', udid, 'max.promise-timer', 'data').stdout.strip())
original_size = sim('ui', udid, 'content_size').stdout.strip()
started_app = False

def launch(screen):
    global started_app
    if started_app:
        sim('terminate', udid, 'max.promise-timer', check=False, timeout=20)
    started = time.time()
    sim('launch', udid, 'max.promise-timer', '-pochi-review-appearance', screen, '-AppleLanguages', '(ja)', '-AppleLocale', 'ja_JP')
    started_app = True
    return started

def report(name, started):
    path = container / 'tmp' / name
    deadline = time.monotonic() + 75
    while time.monotonic() < deadline:
        if path.exists() and path.stat().st_mtime >= started:
            return json.loads(path.read_text())
        time.sleep(1)
    raise RuntimeError('No fresh report: ' + name)

try:
    sim('ui', udid, 'content_size', 'large')
    data = report('pochi-native-layout-regression.json', launch('native-layout-check'))
    (out / 'layout-regression.json').write_text(json.dumps(data, indent=2) + '\n')
    assert data['cases'] == 32 and not data['failures'], data
    print('32 layout cases passed; collapsed views rejected; large text expands the card.', flush=True)
    for size, name in [('large', 'native-normal'), ('accessibility-extra-extra-extra-large', 'native-largest')]:
        changed = time.time()
        sim('ui', udid, 'content_size', size)
        # Enlarge the live, already-registered ad without restarting or requesting another ad.
        data = report('pochi-native-ad-check.json', launch('native') if size == 'large' else changed)
        assert data['registered'] and data['assetsFit'] and data['height'] >= data['requiredHeight'], data
        if size == 'large':
            normal_font_size = data['headlinePointSize']
        else:
            assert data['headlinePointSize'] > normal_font_size, data
        (out / (name + '.json')).write_text(json.dumps(data, indent=2) + '\n')
        time.sleep(15)
        sim('io', udid, 'screenshot', str(out / (name + '.png')))
        print(name + ': registered only after all assets fit.', flush=True)
finally:
    sim('ui', udid, 'content_size', original_size)
