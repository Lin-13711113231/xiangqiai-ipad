#!/usr/bin/env python3
"""Regenerate the self-contained Xcode project without requiring XcodeGen/CocoaPods."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "XiangqiAI.xcodeproj"
PROJECT.mkdir(exist_ok=True)

def oid(key: str) -> str:
    return hashlib.sha1(key.encode()).hexdigest().upper()[:24]

def q(value: str) -> str:
    return value if all(c.isalnum() or c in "_./$()" for c in value) else '"' + value.replace('"', '\\"') + '"'

swift = [
    "XiangqiAI/XiangqiAIApp.swift", "XiangqiAI/Models/Piece.swift", "XiangqiAI/Models/Move.swift",
    "XiangqiAI/Models/BoardState.swift", "XiangqiAI/Models/GameRules.swift", "XiangqiAI/Engine/EngineManager.swift",
    "XiangqiAI/UI/BoardView.swift", "XiangqiAI/UI/GameView.swift", "XiangqiAI/UI/AnalysisView.swift", "XiangqiAI/UI/SettingsView.swift",
]
objcxx = ["XiangqiAI/Engine/PikafishBridge.mm"]
# The Makefile builds every C++ translation unit except the console entry point. Mirror that
# source set here so iOS links Pikafish's NNUE and bundled decompression implementation too.
pikafish = [
    path.relative_to(ROOT).as_posix()
    for path in sorted((ROOT / "vendor/Pikafish/src").rglob("*.cpp"))
    if path.name != "main.cpp" and "universal" not in path.parts
]
sources = swift + objcxx + pikafish
headers = ["XiangqiAI/Engine/PikafishBridge.h", "XiangqiAI/Engine/XiangqiAI-Bridging-Header.h"]
resources = ["XiangqiAI/Resources/pikafish.nnue", "XiangqiAI/LICENSES/Pikafish-GPL-3.0.txt", "XiangqiAI/LICENSES/Pikafish-AUTHORS.txt", "XiangqiAI/LICENSES/Pikafish-README.md"]
all_files = sources + headers + resources + ["XiangqiAI/Info.plist"]

refs = []
for path in all_files:
    typ = "text" if path.endswith((".h", ".plist", ".txt", ".md")) else "file"
    if path.endswith(".swift"): filetype = "sourcecode.swift"
    elif path.endswith(".mm"): filetype = "sourcecode.cpp.objcpp"
    elif path.endswith(".cpp"): filetype = "sourcecode.cpp.cpp"
    elif path.endswith(".nnue"): filetype = "file"
    elif path.endswith(".plist"): filetype = "text.plist.xml"
    else: filetype = "text"
    refs.append(f"\t\t{oid('ref:'+path)} /* {Path(path).name} */ = {{isa = PBXFileReference; lastKnownFileType = {filetype}; path = {q(path)}; sourceTree = SOURCE_ROOT; }};")

buildfiles = []
for path in sources + resources:
    buildfiles.append(f"\t\t{oid('build:'+path)} /* {Path(path).name} in {'Resources' if path in resources else 'Sources'} */ = {{isa = PBXBuildFile; fileRef = {oid('ref:'+path)} /* {Path(path).name} */; }};")

source_phase = "\n".join(f"\t\t\t\t{oid('build:'+p)} /* {Path(p).name} in Sources */," for p in sources)
resource_phase = "\n".join(f"\t\t\t\t{oid('build:'+p)} /* {Path(p).name} in Resources */," for p in resources)
children = "\n".join(f"\t\t\t\t{oid('ref:'+p)} /* {Path(p).name} */," for p in all_files)

project_id = oid("project")
target_id = oid("target")
main_group = oid("main-group")
sources_phase = oid("sources-phase")
resources_phase = oid("resources-phase")
frameworks_phase = oid("frameworks-phase")
product_ref = oid("product-ref")
project_debug = oid("project-debug")
project_release = oid("project-release")
target_debug = oid("target-debug")
target_release = oid("target-release")
project_config_list = oid("project-config-list")
target_config_list = oid("target-config-list")

pbx = f'''// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(buildfiles)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(refs)}
\t\t{product_ref} /* XiangqiAI.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = XiangqiAI.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXGroup section */
\t\t{main_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children}
\t\t\t\t{product_ref} /* XiangqiAI.app */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_id} /* XiangqiAI */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {target_config_list} /* Build configuration list for PBXNativeTarget "XiangqiAI" */;
\t\t\tbuildPhases = ({sources_phase} /* Sources */, {frameworks_phase} /* Frameworks */, {resources_phase} /* Resources */);
\t\t\tbuildRules = ();
\t\t\tdependencies = ();
\t\t\tname = XiangqiAI;
\t\t\tproductName = XiangqiAI;
\t\t\tproductReference = {product_ref} /* XiangqiAI.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{project_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{ LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = {{{target_id} = {{CreatedOnToolsVersion = 16.0;}};}}; }};
\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject "XiangqiAI" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (en, Base, "zh-Hans");
\t\t\tmainGroup = {main_group};
\t\t\tproductRefGroup = {main_group};
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = ({target_id} /* XiangqiAI */,);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase} /* Resources */ = {{ isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (
{resource_phase}
\t\t\t); runOnlyForDeploymentPostprocessing = 0; }};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_phase} /* Sources */ = {{ isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (
{source_phase}
\t\t\t); runOnlyForDeploymentPostprocessing = 0; }};
/* End PBXSourcesBuildPhase section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{frameworks_phase} /* Frameworks */ = {{ isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};
/* End PBXFrameworksBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{project_debug} /* Debug */ = {{ isa = XCBuildConfiguration; buildSettings = {{ CLANG_ENABLE_MODULES = YES; }}; name = Debug; }};
\t\t{project_release} /* Release */ = {{ isa = XCBuildConfiguration; buildSettings = {{ CLANG_ENABLE_MODULES = YES; }}; name = Release; }};
\t\t{target_debug} /* Debug */ = {{ isa = XCBuildConfiguration; buildSettings = {{
\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = "";
\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "c++20";
\t\t\tCLANG_CXX_LIBRARY = "libc++";
\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t// Mirrors Pikafish Makefile ARCH=apple-silicon: ARMv8 NEON, popcount, and dot-product NNUE kernels.
\t\t\tOTHER_CPLUSPLUSFLAGS = "$(inherited) -DUSE_NEON=8 -DUSE_POPCNT -DUSE_NEON_DOTPROD -DPIKAFISH_EMBEDDED_APP -DARCH=apple-silicon -march=armv8.2-a+dotprod";
\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\tDEVELOPMENT_TEAM = "";
\t\t\tGCC_PREPROCESSOR_DEFINITIONS = "$(inherited) IS_64BIT USE_PTHREADS";
\t\t\tHEADER_SEARCH_PATHS = "$(inherited) $(SRCROOT)/vendor/Pikafish/src";
\t\t\tINFOPLIST_FILE = XiangqiAI/Info.plist;
\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
\t\t\tMARKETING_VERSION = 1.0;
\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.XiangqiAI;
\t\t\tPRODUCT_NAME = XiangqiAI;
\t\t\tSDKROOT = iphoneos;
\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\tSWIFT_OBJC_BRIDGING_HEADER = XiangqiAI/Engine/XiangqiAI-Bridging-Header.h;
\t\t\tSWIFT_VERSION = 5.0;
\t\t\tTARGETED_DEVICE_FAMILY = 2;
\t\t}}; name = Debug; }};
\t\t{target_release} /* Release */ = {{ isa = XCBuildConfiguration; buildSettings = {{
\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = "";
\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "c++20";
\t\t\tCLANG_CXX_LIBRARY = "libc++";
\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t// Mirrors Pikafish Makefile ARCH=apple-silicon: ARMv8 NEON, popcount, and dot-product NNUE kernels.
\t\t\tOTHER_CPLUSPLUSFLAGS = "$(inherited) -DUSE_NEON=8 -DUSE_POPCNT -DUSE_NEON_DOTPROD -DPIKAFISH_EMBEDDED_APP -DARCH=apple-silicon -march=armv8.2-a+dotprod";
\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\tDEVELOPMENT_TEAM = "";
\t\t\tGCC_OPTIMIZATION_LEVEL = s;
\t\t\tGCC_PREPROCESSOR_DEFINITIONS = "$(inherited) IS_64BIT USE_PTHREADS NDEBUG";
\t\t\tHEADER_SEARCH_PATHS = "$(inherited) $(SRCROOT)/vendor/Pikafish/src";
\t\t\tINFOPLIST_FILE = XiangqiAI/Info.plist;
\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
\t\t\tMARKETING_VERSION = 1.0;
\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.XiangqiAI;
\t\t\tPRODUCT_NAME = XiangqiAI;
\t\t\tSDKROOT = iphoneos;
\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\tSWIFT_OBJC_BRIDGING_HEADER = XiangqiAI/Engine/XiangqiAI-Bridging-Header.h;
\t\t\tSWIFT_VERSION = 5.0;
\t\t\tTARGETED_DEVICE_FAMILY = 2;
\t\t}}; name = Release; }};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{project_config_list} /* Build configuration list for PBXProject "XiangqiAI" */ = {{ isa = XCConfigurationList; buildConfigurations = ({project_debug} /* Debug */, {project_release} /* Release */,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
\t\t{target_config_list} /* Build configuration list for PBXNativeTarget "XiangqiAI" */ = {{ isa = XCConfigurationList; buildConfigurations = ({target_debug} /* Debug */, {target_release} /* Release */,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
/* End XCConfigurationList section */
\t}};
\trootObject = {project_id} /* Project object */;
}}
'''
(PROJECT / "project.pbxproj").write_text(pbx, encoding="utf-8")
print(PROJECT / "project.pbxproj")

