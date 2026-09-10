#!/usr/bin/env python3
"""Run the real deferred-check code from an upstream or patched Swift source."""
import pathlib
import subprocess
import sys
import tempfile

source = pathlib.Path(sys.argv[1]).read_text()
start = source.find("var deferredRecheck:")
if start == -1:
    start = source.index("func recheck(after")
code = source[start:source.index("\nfunc tick() {", start)]
cancel = "cancelRecheck();" if "func cancelRecheck()" in code else ""
harness = f"""
import Foundation
{code}
func expect(_ value: Bool, _ message: String) {{
    if !value {{ fputs(message + "\\n", stderr); exit(1) }}
}}
var ticks = 0
func tick() {{ {cancel} ticks += 1 }}
func wait(_ seconds: Double) {{
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
}}
// A transition burst needs one final observation, not one per event.
for _ in 0..<100 {{ recheck(after: 0.02) }}
wait(0.1)
expect(ticks == 1, "burst produced \\(ticks) checks instead of one")
// A nearer deadline replaces a later one without retaining stale work.
ticks = 0
recheck(after: 0.2)
recheck(after: 0.01)
wait(0.1)
expect(ticks == 1, "earlier deadline did not converge")
wait(0.2)
expect(ticks == 1, "superseded deadline still fired")
// Repeated later requests must not postpone an already pending check.
ticks = 0
recheck(after: 0.01)
for _ in 0..<100 {{ recheck(after: 0.2) }}
wait(0.1)
expect(ticks == 1, "later requests postponed the check")
wait(0.2)
expect(ticks == 1, "later requests queued duplicate checks")
print("deferred-check behavior passed")
"""
with tempfile.TemporaryDirectory(prefix="rgo-borders-recheck-") as directory:
    path = pathlib.Path(directory)
    (path / "main.swift").write_text(harness)
    subprocess.run(["/usr/bin/xcrun", "swiftc", str(path / "main.swift"), "-o", str(path / "test")], check=True)
    subprocess.run([str(path / "test")], check=True)
