# Unchair

A native macOS menu bar companion for people who work or study at a computer: focus sessions, sit/stand alternation, hydration, and break reminders that know when not to interrupt.

> **Status:** early development. See [ROADMAP.md](ROADMAP.md) for the plan.

## Requirements

- macOS 14 Sonoma or later
- Xcode 26 or later (the project uses folder-synchronized groups and Swift 6)
- Optional, for linting: [SwiftLint](https://github.com/realm/SwiftLint) and [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)

  ```sh
  brew install swiftlint swiftformat
  ```

## Getting started

```sh
git clone https://github.com/Lukazovic/unchair.git
cd unchair
open Unchair.xcodeproj
```

Select the **Unchair** scheme and press **⌘R**. Unchair runs as a menu bar app (no Dock icon): look for the figure icon in the menu bar.

The project signs to run locally by default. To run with your own Apple Developer account, set your team in **Signing & Capabilities**.

## Project structure

```
App/                      macOS app target (SwiftUI)
├── MenuBar/              Menu bar extra UI
├── Settings/             Settings window
└── Resources/            Assets and Localizable.xcstrings
Packages/UnchairCore/     Platform-independent logic (Foundation only)
Unchair.xcodeproj/
```

`App/` is a folder-synchronized group: files added to it on disk show up in Xcode automatically, with no project file changes.

`UnchairCore` must not import SwiftUI, AppKit, or other Apple platform frameworks, so it can be reused on Windows and Linux later. Time-dependent code takes a `WallClock` so tests can use `TestClock` instead of real time.

## Common tasks

| Task | Command |
|---|---|
| Run core tests | `swift test --package-path Packages/UnchairCore` |
| Run all tests via Xcode | `xcodebuild test -project Unchair.xcodeproj -scheme Unchair` |
| Build the app | `xcodebuild build -project Unchair.xcodeproj -scheme Unchair` |
| Check formatting | `swiftformat --lint .` |
| Apply formatting | `swiftformat .` |
| Lint | `swiftlint --strict` |

## Localization

Unchair ships in **English** (source), **Spanish** (`es`), and **Brazilian Portuguese** (`pt-BR`).

- Write all code and UI strings in English.
- Use `Text("…")`, `String(localized: "…")`, or `LocalizedStringKey` for user-facing text.
- Building in Xcode adds new strings to `App/Resources/Localizable.xcstrings`. Add the Spanish and Portuguese translations in the String Catalog editor.
- To test a language, edit the scheme → **Run** → **Options** → **App Language**.

## Contributing

1. Keep `swiftformat --lint .`, `swiftlint --strict`, and the tests passing (CI checks all three).
2. Put logic in `UnchairCore` with tests. Keep the app target thin.
3. Use short, one-line commit messages in the imperative mood.
