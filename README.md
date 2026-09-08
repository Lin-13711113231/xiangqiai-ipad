# XiangqiAI

An offline, native SwiftUI Xiangqi application for Apple-silicon iPad. The UI calls Pikafish through a thin Objective-C++ bridge; the engine runs directly in-process using the bundled `pikafish.nnue` network and iPad CPU threads.

## Build

The repository contains a self-contained Xcode project and a GitHub Actions workflow. Dispatch **Build XiangqiAI IPA** or push to the repository. The workflow builds an unsigned `XiangqiAI.app`, wraps it as:

```
Payload/XiangqiAI.app
```

and uploads `XiangqiAI.ipa` as the `XiangqiAI-IPA` artifact.

No browser, WKWebView, JavaScript, WebAssembly, local HTTP server, or cloud engine is used.

## Rules and cyclic positions

Swift owns ordinary legal move validation (palace, horse-leg, elephant-eye and river, cannon screen, flying generals, check evasion, and terminal no-legal-move positions). A played game retains its **initial FEN and every UCI move**, rather than flattening the current position to a FEN. That complete sequence is passed to Pikafish's upstream `Position::rule_judge()` implementation through a narrow public `Engine::rule_judgement()` wrapper. Consequently, long check, long chase, protected-piece and mutual-chase exceptions, mixed check/chase cycles, ordinary cyclic draws, and the engine's 60-move adjudication follow Pikafish's WXF rule implementation. The analysis tab intentionally has no game-history adjudication because it analyses an arbitrary snapshot.

## Licensing

Pikafish is GPLv3. Its source is vendored under `vendor/Pikafish` and its GPL notice, authors, and README are included under `XiangqiAI/LICENSES`. Anyone distributing a derived app must meet Pikafish's GPLv3 source-availability obligations. The `pikafish.nnue` file is bundled from the official Pikafish Networks release and should be redistributed only in accordance with the upstream project's terms.

The vendored-source changes are deliberately narrow: (1) a `PIKAFISH_EMBEDDED_APP` guard in `vendor/Pikafish/src/nnue/network.cpp` makes an invalid NNUE network raise an exception for the in-process iPad build rather than calling `exit()` (standalone behavior remains unchanged without that definition); and (2) `vendor/Pikafish/src/engine.h/.cpp` adds a read-only `Engine::rule_judgement()` façade over upstream `Position::rule_judge()` so the app can display WXF cyclic-position results without reimplementing Pikafish search or chase logic.

## Local macOS build

```sh
python3 scripts/generate_xcode_project.py
xcodebuild -project XiangqiAI.xcodeproj -scheme XiangqiAI -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
```
