"""Exercise the actual SwiftUI URL callback in an installed iOS simulator app."""
import json
import pathlib
import subprocess
import time
import atexit

BUNDLE = "dev.accesshub.sidestoretest"

def run(*args, check=True):
    return subprocess.run(args, check=check, capture_output=True, text=True, timeout=240).stdout.strip()

devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json"))["devices"]
device = next(d for runtime, group in sorted(devices.items(), reverse=True)
              if "iOS" in runtime for d in group if d["name"].startswith("iPhone"))
udid = device["udid"]
run("xcrun", "simctl", "boot", udid, check=False)
run("xcrun", "simctl", "bootstatus", udid, "-b")
def capture_evidence():
    run("xcrun", "simctl", "io", udid, "screenshot", "build/storefront-simulator.png", check=False)
    log = run("xcrun", "simctl", "spawn", udid, "log", "show", "--last", "3m", "--style", "compact",
              "--predicate", 'process == "AccessHubTest"', check=False)
    pathlib.Path("build/storefront-runtime.log").write_text(log)
atexit.register(capture_evidence)
app = "build/Simulator/Build/Products/Debug-iphonesimulator/AccessHubTest.app"
run("xcrun", "simctl", "install", udid, app)
container = pathlib.Path(run("xcrun", "simctl", "get_app_container", udid, BUNDLE, "data"))
receipt = container / "Library/Caches/storefront-launch.json"

def open_and_wait(count):
    run("xcrun", "simctl", "openurl", udid, "storefrontdemo://open")
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        try:
            value = json.loads(receipt.read_text())
            if value["count"] == count:
                return value
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        time.sleep(.25)
    raise AssertionError(f"SwiftUI did not receive URL #{count}")

first = open_and_wait(1)
print("PASS: cold launch delivered storefrontdemo://open via SwiftUI", flush=True)
warm = open_and_wait(2)
assert warm["pid"] == first["pid"], "Warm launch unexpectedly restarted app"
print("PASS: already-running launch delivered without restarting", flush=True)
run("xcrun", "simctl", "launch", udid, "com.apple.mobilesafari")
time.sleep(2)
background = open_and_wait(3)
assert background["pid"] == first["pid"], "Background launch unexpectedly restarted app"
print("PASS: background launch delivered to existing app", flush=True)
run("xcrun", "simctl", "terminate", udid, BUNDLE)
restarted = open_and_wait(4)
assert restarted["pid"] != first["pid"], "Expected a fresh process after termination"
print("PASS: terminated app restarted and received URL", flush=True)
run("xcrun", "simctl", "openurl", udid, "storefrontdemo://wrong-host")
time.sleep(2)
assert json.loads(receipt.read_text())["count"] == 4, "Wrong host was accepted"
print("PASS: unsupported host ignored", flush=True)
run("xcrun", "simctl", "io", udid, "screenshot", "build/storefront-simulator.png")
pathlib.Path("build/storefront-simulator-results.json").write_text(json.dumps({
    "device": device["name"], "cold": True, "warm": True, "background": True,
    "terminated": True, "unsupportedHostRejected": True,
    "scope": "Native URL delivery; authorized Home routing covered separately by JS tests. Physical iPhone required for signing, layout, Face ID and app-switcher privacy."
}, indent=2))
