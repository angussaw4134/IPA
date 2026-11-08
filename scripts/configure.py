"""Generate the dependency-free Xcode project and its public configuration."""
import os
from pathlib import Path
import plistlib
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_URL = "https://3377test.erg3be.workers.dev/"


def website_url(value):
    value = value.strip()
    parsed = urlsplit(value)
    if (parsed.scheme != "https" or not parsed.hostname or parsed.username
            or parsed.password or parsed.port not in (None, 443)
            or parsed.path not in ("", "/") or parsed.query or parsed.fragment
            or not re.fullmatch(r"[A-Za-z0-9.-]+", parsed.hostname)
            or "." not in parsed.hostname):
        raise ValueError("Use a public HTTPS website address without a path, credentials, query or fragment.")
    return f"https://{parsed.hostname.lower()}/"


def configure():
    url = website_url(os.environ.get("WEBSITE_URL") or DEFAULT_URL)
    build = os.environ.get("GITHUB_RUN_NUMBER", "1")
    if not re.fullmatch(r"[1-9][0-9]*", build):
        raise ValueError("Build number must be a positive integer")
    info = {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleDisplayName": "𝖲ervice NSW",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "𝖲ervice NSW",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": build,
        "LSRequiresIPhoneOS": True,
        "UIRequiredDeviceCapabilities": ["arm64"],
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
        "UIUserInterfaceStyle": "Dark",
        "UILaunchScreen": {"UIColorName": "LaunchBackground"},
        "NSCameraUsageDescription": "Take a photo to upload to your test profile.",
        "NSPhotoLibraryUsageDescription": "Choose a photo to upload to your test profile.",
        "NSFaceIDUsageDescription": "Use Face ID to unlock this test app after signing in with your key and PIN.",
        "TestWebsiteURL": url,
    }
    (ROOT / "App/Info.plist").write_bytes(plistlib.dumps(info))

    # Stable IDs make changes easy to review. No third-party project generator is needed.
    project = '''// !$*UTF8*$!
{
 archiveVersion = 1;
 classes = {};
 objectVersion = 56;
 objects = {
  A00000000000000000000001 = {isa = PBXProject; attributes = {LastUpgradeCheck = 1600;}; buildConfigurationList = A00000000000000000000010; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = A00000000000000000000002; productRefGroup = A00000000000000000000004; projectDirPath = ""; projectRoot = ""; targets = (A00000000000000000000005);};
  A00000000000000000000002 = {isa = PBXGroup; children = (A00000000000000000000003, A00000000000000000000004); sourceTree = "<group>";};
  A00000000000000000000003 = {isa = PBXGroup; children = (A00000000000000000000006, A00000000000000000000007, A00000000000000000000008, A00000000000000000000021, A00000000000000000000022, A00000000000000000000023, A00000000000000000000027); path = App; sourceTree = "<group>";};
  A00000000000000000000004 = {isa = PBXGroup; children = (A00000000000000000000009); name = Products; sourceTree = "<group>";};
  A00000000000000000000005 = {isa = PBXNativeTarget; buildConfigurationList = A00000000000000000000011; buildPhases = (A00000000000000000000012, A00000000000000000000013, A00000000000000000000014); buildRules = (); dependencies = (); name = AccessHubTest; productName = AccessHubTest; productReference = A00000000000000000000009; productType = "com.apple.product-type.application";};
  A00000000000000000000006 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>";};
  A00000000000000000000007 = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>";};
  A00000000000000000000008 = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";};
  A00000000000000000000009 = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AccessHubTest.app; sourceTree = BUILT_PRODUCTS_DIR;};
  A00000000000000000000010 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000017, A00000000000000000000018); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
  A00000000000000000000011 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000019, A00000000000000000000020); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
  A00000000000000000000012 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (A00000000000000000000015, A00000000000000000000024, A00000000000000000000028); runOnlyForDeploymentPostprocessing = 0;};
  A00000000000000000000013 = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;};
  A00000000000000000000014 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (A00000000000000000000016, A00000000000000000000025, A00000000000000000000026); runOnlyForDeploymentPostprocessing = 0;};
  A00000000000000000000015 = {isa = PBXBuildFile; fileRef = A00000000000000000000006;};
  A00000000000000000000016 = {isa = PBXBuildFile; fileRef = A00000000000000000000008;};
  A00000000000000000000017 = {isa = XCBuildConfiguration; buildSettings = {CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 16.0; SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = "-Onone";}; name = Debug;};
  A00000000000000000000018 = {isa = XCBuildConfiguration; buildSettings = {CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 16.0; SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = "-O"; SWIFT_COMPILATION_MODE = wholemodule;}; name = Release;};
  A00000000000000000000019 = {isa = XCBuildConfiguration; buildSettings = {ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGNING_ALLOWED = NO; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = App/Info.plist; PRODUCT_BUNDLE_IDENTIFIER = dev.accesshub.sidestoretest; PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");}; name = Debug;};
  A00000000000000000000020 = {isa = XCBuildConfiguration; buildSettings = {ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGNING_ALLOWED = NO; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = App/Info.plist; PRODUCT_BUNDLE_IDENTIFIER = dev.accesshub.sidestoretest; PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");}; name = Release;};
  A00000000000000000000021 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NativeSecurity.swift; sourceTree = "<group>";};
  A00000000000000000000022 = {isa = PBXFileReference; lastKnownFileType = sourcecode.javascript; path = NativeLogin.js; sourceTree = "<group>";};
  A00000000000000000000023 = {isa = PBXFileReference; lastKnownFileType = image.png; path = "privacy-cover.png"; sourceTree = "<group>";};
  A00000000000000000000024 = {isa = PBXBuildFile; fileRef = A00000000000000000000021;};
  A00000000000000000000025 = {isa = PBXBuildFile; fileRef = A00000000000000000000022;};
  A00000000000000000000026 = {isa = PBXBuildFile; fileRef = A00000000000000000000023;};
  A00000000000000000000027 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NativeContentRules.swift; sourceTree = "<group>";};
  A00000000000000000000028 = {isa = PBXBuildFile; fileRef = A00000000000000000000027;};
 };
 rootObject = A00000000000000000000001;
}
'''
    project_dir = ROOT / "AccessHubTest.xcodeproj"
    scheme_dir = project_dir / "xcshareddata/xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    (project_dir / "project.pbxproj").write_text(project, encoding="utf-8")
    (scheme_dir / "AccessHubTest.xcscheme").write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
  <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
   <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000005" BuildableName="AccessHubTest.app" BlueprintName="AccessHubTest" ReferencedContainer="container:AccessHubTest.xcodeproj"/>
  </BuildActionEntry></BuildActionEntries>
 </BuildAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES">
  <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000005" BuildableName="AccessHubTest.app" BlueprintName="AccessHubTest" ReferencedContainer="container:AccessHubTest.xcodeproj"/></BuildableProductRunnable>
 </LaunchAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''', encoding="utf-8")
    print(f"Configured AccessHub Test for {url}")


if __name__ == "__main__":
    configure()
