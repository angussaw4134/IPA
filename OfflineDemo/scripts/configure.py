"""Generate a small, dependency-free Xcode project for the offline demo."""
from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parents[1]
objects = {}
def ref(number): return f'{number:024X}'
def add(number, text): objects[ref(number)] = text
def refs(*numbers): return '(' + ', '.join(ref(n) for n in numbers) + ')'

add(1, f'isa = PBXProject; attributes = {{LastUpgradeCheck = 1600;}}; buildConfigurationList = {ref(10)}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = {ref(2)}; productRefGroup = {ref(4)}; projectDirPath = ""; projectRoot = ""; targets = {refs(5,41)};')
add(2, f'isa = PBXGroup; children = {refs(3,4,53)}; sourceTree = "<group>";')
add(3, f'isa = PBXGroup; children = {refs(6,7,8,21,23)}; path = App; sourceTree = "<group>";')
add(4, f'isa = PBXGroup; children = {refs(9,42)}; name = Products; sourceTree = "<group>";')
add(5, f'isa = PBXNativeTarget; buildConfigurationList = {ref(11)}; buildPhases = {refs(12,13,14)}; buildRules = (); dependencies = (); name = WinterStudio; productName = WinterStudio; productReference = {ref(9)}; productType = "com.apple.product-type.application";')
for n, kind, path in [(6,'sourcecode.swift','WinterStudioApp.swift'), (7,'text.plist.xml','Info.plist'), (8,'folder.assetcatalog','Assets.xcassets'), (21,'sourcecode.swift','DemoAccess.swift'), (23,'text.json','activation-public-key.json'), (43,'sourcecode.swift','OfflineDemoUITests.swift')]:
    add(n, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = "{path}"; sourceTree = "<group>";')
for n, kind, path in [(9,'wrapper.application','WinterStudio.app'), (42,'wrapper.cfbundle','OfflineDemoUITests.xctest')]:
    add(n, f'isa = PBXFileReference; explicitFileType = {kind}; includeInIndex = 0; path = {path}; sourceTree = BUILT_PRODUCTS_DIR;')
for n, configs in [(10,(17,18)),(11,(19,20)),(48,(49,50))]:
    add(n, f'isa = XCConfigurationList; buildConfigurations = {refs(*configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
for n, kind, files in [(12,'Sources',(15,24)),(13,'Frameworks',()),(14,'Resources',(16,26)),(45,'Sources',(44,)),(46,'Frameworks',()),(47,'Resources',())]:
    add(n, f'isa = PBX{kind}BuildPhase; buildActionMask = 2147483647; files = {refs(*files)}; runOnlyForDeploymentPostprocessing = 0;')
for n, file in [(15,6),(16,8),(24,21),(26,23),(44,43)]:
    add(n, f'isa = PBXBuildFile; fileRef = {ref(file)};')
for n, name in [(17,'Debug'),(18,'Release')]:
    options = 'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;' if name=='Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; SWIFT_COMPILATION_MODE = wholemodule;'
    add(n, f'isa = XCBuildConfiguration; buildSettings = {{CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 16.0; SWIFT_VERSION = 5.0; {options}}}; name = {name};')
for n, name in [(19,'Debug'),(20,'Release')]:
    add(n, f'isa = XCBuildConfiguration; buildSettings = {{ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGNING_ALLOWED = NO; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = App/Info.plist; PRODUCT_BUNDLE_IDENTIFIER = dev.accesshub.winterstudio.offline; PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");}}; name = {name};')
add(41, f'isa = PBXNativeTarget; buildConfigurationList = {ref(48)}; buildPhases = {refs(45,46,47)}; buildRules = (); dependencies = {refs(52)}; name = OfflineDemoUITests; productName = OfflineDemoUITests; productReference = {ref(42)}; productType = "com.apple.product-type.bundle.ui-testing";')
for n, name in [(49,'Debug'),(50,'Release')]:
    add(n, f'isa = XCBuildConfiguration; buildSettings = {{CODE_SIGNING_ALLOWED = NO; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = dev.accesshub.winterstudio.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 1; TEST_TARGET_NAME = WinterStudio; IPHONEOS_DEPLOYMENT_TARGET = 16.0; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks");}}; name = {name};')
add(51, f'isa = PBXContainerItemProxy; containerPortal = {ref(1)}; proxyType = 1; remoteGlobalIDString = {ref(5)}; remoteInfo = WinterStudio;')
add(52, f'isa = PBXTargetDependency; target = {ref(5)}; targetProxy = {ref(51)};')
add(53, f'isa = PBXGroup; children = {refs(43)}; path = tests; sourceTree = "<group>";')
project = ROOT/'WinterStudio.xcodeproj'
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(f'{key} = {{{value}}};' for key,value in objects.items()) + f'\n}}; rootObject = {ref(1)};}}\n')
scheme_dir = project/'xcshareddata'/'xcschemes'
scheme_dir.mkdir(parents=True,exist_ok=True)
app_ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref(5)}" BuildableName="WinterStudio.app" BlueprintName="WinterStudio" ReferencedContainer="container:WinterStudio.xcodeproj"/>'
test_ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref(41)}" BuildableName="OfflineDemoUITests.xctest" BlueprintName="OfflineDemoUITests" ReferencedContainer="container:WinterStudio.xcodeproj"/>'
(scheme_dir/'WinterStudio.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
info = {
 'CFBundleDisplayName':'3377 Christmas Demo','CFBundleName':'WinterStudio',
 'CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)',
 'CFBundlePackageType':'APPL','CFBundleInfoDictionaryVersion':'6.0',
 'CFBundleShortVersionString':'1.1','CFBundleVersion':'3','LSRequiresIPhoneOS':True,
 'UILaunchScreen':{'UIColorName':'LaunchBackground'},'UIRequiredDeviceCapabilities':['arm64'],
 'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'],'UIUserInterfaceStyle':'Dark',
 'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False,'UISceneConfigurations':{}},
 'CFBundleURLTypes':[{'CFBundleTypeRole':'Viewer','CFBundleURLName':'dev.accesshub.winterstudio.offline','CFBundleURLSchemes':['winterstudiodemo']}]
}
with (ROOT/'App'/'Info.plist').open('wb') as f: plistlib.dump(info,f)
print('Generated WinterStudio.xcodeproj and offline Info.plist')
