# XiangqiAI

An offline, native SwiftUI Xiangqi application for Apple-silicon iPad. The UI calls Pikafish through a thin Objective-C++ bridge; the engine runs directly in-process using the bundled `pikafish.nnue` network and iPad CPU threads.

## Build

The repository contains a self-contained Xcode project and a GitHub Actions workflow. Dispatch **Build XiangqiAI IPA** or push to the repository. The workflow builds an unsigned `XiangqiAI.app`, wraps it as:

```
Payload/XiangqiAI.app
```

and uploads `XiangqiAI.ipa` as the `XiangqiAI-IPA` artifact.

No browser, WKWebView, JavaScript, WebAssembly, local HTTP server, or cloud engine is used.

## Licensing

Pikafish is GPLv3. Its source is vendored under `vendor/Pikafish` and its GPL notice, authors, and README are included under `XiangqiAI/LICENSES`. Anyone distributing a derived app must meet Pikafish's GPLv3 source-availability obligations. The `pikafish.nnue` file is bundled from the official Pikafish Networks release and should be redistributed only in accordance with the upstream project's terms.

## Local macOS build

```sh
python3 scripts/generate_xcode_project.py
xcodebuild -project XiangqiAI.xcodeproj -scheme XiangqiAI -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
```

