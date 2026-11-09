#!/usr/bin/env python3
"""Generate the dependency-free macOS Xcode application project."""
from pathlib import Path
import hashlib
import json
root = Path(__file__).resolve().parent.parent
project = root / 'iPhoneRemote.xcodeproj'
project.mkdir(exist_ok=True)
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def q(text): return json.dumps(str(text))
objects = []
def obj(name, value):
    objects.append(f'{uid(name)} = {{ {value} }};')
    return uid(name)
files = sorted((root/'Sources').rglob('*.swift'))
refs=[]; builds=[]
for file in files:
    path=str(file.relative_to(root))
    ref=obj(path, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path)}; sourceTree = SOURCE_ROOT;')
    refs.append(ref)
    builds.append(obj(path+'build', f'isa = PBXBuildFile; fileRef = {ref};'))
product=obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = "iPhone Remote.app"; sourceTree = BUILT_PRODUCTS_DIR;')
products=obj('products',f'isa = PBXGroup; children = ({product}); name = Products; sourceTree = "<group>";')
plist=obj('plist','isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Config/Info.plist; sourceTree = SOURCE_ROOT;')
obj('main',f'isa = PBXGroup; children = ({",".join(refs+[plist,products])}); sourceTree = "<group>";')
sources=obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')
frameworks=obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
icon=obj('icon', 'isa = PBXFileReference; lastKnownFileType = image.icns; path = Assets/AppIcon.icns; sourceTree = SOURCE_ROOT;')
iconbuild=obj('iconbuild', f'isa = PBXBuildFile; fileRef = {icon};')
resources=obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({iconbuild}); runOnlyForDeploymentPostprocessing = 0;')
for mode in ['Debug','Release']:
    obj('project'+mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; }};')
    optimization = '-Onone' if mode=='Debug' else '-O'
    obj('target'+mode,f'''isa = XCBuildConfiguration; name = {mode}; buildSettings = {{
        PRODUCT_NAME = "iPhone Remote"; EXECUTABLE_NAME = iPhoneRemote;
        PRODUCT_BUNDLE_IDENTIFIER = it.local.iphoneremote;
        INFOPLIST_FILE = Config/Info.plist; GENERATE_INFOPLIST_FILE = NO;
        CODE_SIGN_IDENTITY = "-"; CODE_SIGN_STYLE = Manual;
        ENABLE_APP_SANDBOX = NO; ENABLE_HARDENED_RUNTIME = NO;
        SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = "{optimization}";
        COMBINE_HIDPI_IMAGES = YES; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";
    }};''')
for name in ['project','target']:
    obj(name+'config',f'isa = XCConfigurationList; buildConfigurations = ({uid(name+"Debug")},{uid(name+"Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfig")}; buildPhases = ({sources},{frameworks},{resources}); buildRules = (); dependencies = (); name = iPhoneRemote; productName = "iPhone Remote"; productReference = {product}; productType = "com.apple.product-type.application";')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {uid("projectconfig")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = {uid("main")}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")});')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+uid('project')+'; }\n')
schemes=project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
(schemes/'iPhoneRemote.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="iPhone Remote.app" BlueprintName="iPhoneRemote" ReferencedContainer="container:iPhoneRemote.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="iPhone Remote.app" BlueprintName="iPhoneRemote" ReferencedContainer="container:iPhoneRemote.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(project)
