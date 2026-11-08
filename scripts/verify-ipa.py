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
    assert info.get("NSFaceIDUsageDescription"), "Missing Face ID permission description"
    assert len(ipa.read(prefix + "NativeLogin.js")) > 1000, "Missing native login integration"
    assert ipa.read(prefix + "privacy-cover.png").startswith(b"\x89PNG\r\n\x1a\n"), "Missing privacy cover"
print("Verified device IPA, arm64 executable, website configuration, Face ID declaration and bundled login/privacy resources.")
