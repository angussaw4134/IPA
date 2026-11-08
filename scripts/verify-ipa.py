"""Reject simulator-only or malformed output before uploading an artifact."""
from pathlib import Path
import plistlib
import struct
import sys
import zipfile

path = Path(sys.argv[1])
with zipfile.ZipFile(path) as ipa:
    assert ipa.testzip() is None, "Corrupt IPA"
    prefix = "Payload/AccessHubTest.app/"
    info = plistlib.loads(ipa.read(prefix + "Info.plist"))
    assert info["CFBundlePackageType"] == "APPL"
    assert info["CFBundleIdentifier"] == "dev.accesshub.sidestoretest"
    assert info["CFBundleSupportedPlatforms"] == ["iPhoneOS"], "Not a device build"
    binary = ipa.read(prefix + info["CFBundleExecutable"])
    assert len(binary) > 4096, "Missing executable"
    # The device build is a thin arm64 Mach-O (not a simulator executable).
    magic, cpu = struct.unpack_from("<II", binary)
    assert magic == 0xFEEDFACF and cpu == 0x0100000C, "Expected arm64 Mach-O"
    assert info["TestWebsiteURL"].startswith("https://")
print("Verified device IPA structure, arm64 executable and website configuration.")
