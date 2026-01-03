# Repository Guidelines

## Project Structure & Module Organization
- `Package.swift` defines a SwiftPM macOS app (minimum macOS 13) with a single executable target.
- `Sources/Picnic/` contains all Swift source files for the app (status bar UI, capture pipeline, editor, etc.).
- `Sources/Picnic/Resources/` holds bundled assets like `AppIcon.icns` and `picniclogo.png`.
- `build/` and `buildandcopy-logs/` are generated artifacts; keep them out of reviews unless debugging builds.

## Build, Test, and Development Commands
- `swift build` — builds the Debug configuration into the SwiftPM build folder.
- `swift run` — runs the executable directly from SwiftPM (useful for quick iteration).
- `./buildandcopy --dev` — builds, codesigns, and installs `Picnic.app` into `/Applications` (default is Debug).
- `./buildandcopy --prod` — Release build and install.
- `./buildandcopy --bundle-id com.example.picnic` — override bundle identifier when needed.

## Coding Style & Naming Conventions
- Swift style matches the existing code: 4-space indentation, braces on the same line, and `final class` where applicable.
- Type names use UpperCamelCase; properties and methods use lowerCamelCase.
- File names generally match their primary type (e.g., `AppDelegate.swift`).
- No formatter or linter is configured—keep changes consistent with nearby code.

## Testing Guidelines
- No test target is present. If adding tests, create `Tests/` with XCTest and name files `*Tests.swift`.
- Prefer focused unit tests for view models and helpers; avoid UI automation unless required.

## Commit & Pull Request Guidelines
- This checkout has no Git history available, so no enforced convention is visible.
- Use short, imperative commit messages (e.g., “Add capture hotkey handling”).
- PRs should describe intent, include reproduction steps for UI changes, and add screenshots for visual updates.

## Security & Configuration Tips
- Screen Recording permission can reset if the app is ad-hoc signed. Provide a signing identity via `SIGN_IDENTITY`, `--sign-id`, or `.signing-identity`.
- Use `BUNDLE_ID` when testing multiple installations to avoid permission collisions.
