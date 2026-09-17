#!/usr/bin/env bash
set -euo pipefail

# Exercise real Launch Services with a slow AppKit launch. Only the recipient
# bundle changes; the production launch/request implementation runs unchanged.
source_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d /tmp/macshot-launch-test.XXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
bundle="$test_dir/Fixture.app"
bundle_id="dev.rgo.macshot-launch-test.$$"
mkdir -p "$bundle/Contents/MacOS"
cat > "$bundle/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleExecutable</key><string>fixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
cat > "$test_dir/fixture.swift" <<'EOF'
import AppKit
class Delegate: NSObject, NSApplicationDelegate {
    private var ready = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        Thread.sleep(forTimeInterval: 0.5)
        ready = true
        let readyFile = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("ready")
        try! "ready".write(to: readyFile, atomically: true, encoding: .utf8)
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        let result = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("result")
        try! (ready ? "PASS" : "FAIL: URL arrived before launch completed").write(
            to: result, atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }
}
let delegate = Delegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
EOF
/usr/bin/xcrun swiftc "$test_dir/fixture.swift" -o "$bundle/Contents/MacOS/fixture"
sed -e "s|/Applications/macshot.app|$bundle|" \
    -e "s|com.sw33tlie.macshot.macshot|$bundle_id|" \
    "$source_dir/macshot-launch.swift" > "$test_dir/launcher.swift"
/usr/bin/xcrun swiftc "$test_dir/launcher.swift" -o "$test_dir/launcher"

# The old binding must reproduce the race, or this fixture cannot guard it.
/usr/bin/open -W -a "$bundle" 'macshot://capture'
if ! /usr/bin/grep -q '^FAIL:' "$test_dir/result"; then
    echo 'FAIL: direct cold launch did not reproduce the startup race' >&2
    exit 1
fi
echo "Old direct URL: $(cat "$test_dir/result")"

for action in capture ocr; do
    for attempt in {1..11}; do
        rm -f "$test_dir/result" "$test_dir/ready"
        if [ "$attempt" -eq 11 ]; then
            /usr/bin/open -g -a "$bundle"
            for poll in {1..100}; do
                if [ -f "$test_dir/ready" ]; then break; fi
                sleep 0.05
            done
            test -f "$test_dir/ready"
        fi
        "$test_dir/launcher" "$action"
        # Wait for the fixture to finish handling the asynchronously sent URL.
        for poll in {1..100}; do
            if [ -f "$test_dir/result" ] && ! /usr/bin/pgrep -f "^$bundle/Contents/MacOS/fixture$" >/dev/null; then
                break
            fi
            sleep 0.05
        done
        if [ "$(cat "$test_dir/result")" != PASS ]; then
            cat "$test_dir/result" >&2
            exit 1
        fi
    done
    echo "$action: 10/10 cold launches and 1 warm launch delivered after AppKit setup"
done
