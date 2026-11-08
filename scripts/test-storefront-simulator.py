"""Exercise the actual SwiftUI URL callback in an installed iOS simulator app."""
import json
import pathlib
import subprocess
import atexit

BUNDLE = "dev.accesshub.sidestoretest"

def run(*args, check=True):
    return subprocess.run(args, check=check, capture_output=True, text=True, timeout=240).stdout.strip()

devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json"))["devices"]
sdk = run("xcrun", "--sdk", "iphonesimulator", "--show-sdk-version").replace(".", "-")
runtime_groups = sorted(devices.items(), key=lambda pair: (pair[0].endswith("iOS-" + sdk), pair[0]), reverse=True)
device = next(d for runtime, group in runtime_groups
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
with open("build/simulator-build.log", "w") as log:
    result = subprocess.run([
        "xcodebuild", "-project", "AccessHubTest.xcodeproj", "-scheme", "StorefrontLaunchTests",
        "-configuration", "Debug", "-sdk", "iphonesimulator", "-destination", f"platform=iOS Simulator,id={udid}",
        "-derivedDataPath", "build/Simulator", "-parallel-testing-enabled", "NO",
        "-resultBundlePath", "build/StorefrontTests.xcresult", "CODE_SIGNING_ALLOWED=YES",
        "CODE_SIGN_IDENTITY=-", "CODE_SIGNING_REQUIRED=YES", "test"
    ], stdout=log, stderr=subprocess.STDOUT, timeout=600)
if result.returncode:
    print("\n".join(pathlib.Path("build/simulator-build.log").read_text().splitlines()[-100:]))
    raise SystemExit(result.returncode)
print("PASS: XCTest cold, warm, background, terminated and unsupported-host checks", flush=True)
pathlib.Path("build/storefront-simulator-results.json").write_text(json.dumps({
    "device": device["name"], "cold": True, "warm": True, "background": True,
    "terminated": True, "unsupportedHostRejected": True,
    "scope": "Native URL delivery; authorized Home routing covered separately by JS tests. Physical iPhone required for signing, layout, Face ID and app-switcher privacy."
}, indent=2))
