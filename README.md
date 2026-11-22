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

### From the terminal

```sh
scripts/run.sh      # build a Debug copy and open it
scripts/check.sh    # run everything CI runs: format, lint, tests, build
```

`scripts/run.sh` quits any other running copy of Unchair first (from Xcode or `/Applications`), since they share settings and the global shortcut. Reopen `/Applications/Unchair.app` when you're done testing. Options, which can be combined:

| Option | What it does |
|---|---|
| `--sample` | A month of in-memory sample history in Statistics (your data is untouched) |
| `--fullscreen` | Shows a full-screen reminder right after launch |
| `--lang es` | Runs in a language: `en`, `es`, or `pt-BR` |

### Notes

The project signs to run locally by default. To run with your own Apple Developer account, set your team in **Signing & Capabilities**. With a team set, the App Group is enabled automatically and widgets show live data (see [Config/README.md](Config/README.md)).

Run Unchair from Xcode or from `/Applications`. macOS refuses notification permission for apps launched from temporary folders.

In Xcode, the same options are launch arguments (Debug builds only): add `-UnchairSampleData` or `-UnchairDemoFullScreen` under **Edit Scheme → Run → Arguments**, and pick a language under **Options → App Language**.

## Project structure

```
App/                      macOS app target (SwiftUI)
├── MenuBar/              Menu bar extra UI
├── Settings/             Settings window
├── Statistics/           Statistics window (Swift Charts)
├── FullScreen/           Optional full-screen breaks and reminders
├── History/              SwiftData history and export
├── Notifications/        Actionable notifications
├── SystemSignals/        Idle, sleep, lock, meetings, full screen
├── Intents/              Focus filter and Shortcuts actions
├── System/               Launch at login, global shortcut, widget publishing
└── Resources/            Assets, sounds, and String Catalogs
Widgets/                  WidgetKit extension
Config/                   Entitlements and widget Info.plist
Packages/UnchairCore/     Platform-independent logic (Foundation only)
Unchair.xcodeproj/
```

`App/` is a folder-synchronized group: files added to it on disk show up in Xcode automatically, with no project file changes.

`UnchairCore` must not import SwiftUI, AppKit, or other Apple platform frameworks, so it can be reused on Windows and Linux later. Time-dependent code takes a `WallClock` so tests can use `TestClock` instead of real time.

## Common tasks

| Task | Command |
|---|---|
| Build and open the app | `scripts/run.sh` |
| Run every CI check | `scripts/check.sh` |
| Run core tests | `swift test --package-path Packages/UnchairCore` |
| Run all tests via Xcode | `xcodebuild test -project Unchair.xcodeproj -scheme Unchair` |
| Build the app | `xcodebuild build -project Unchair.xcodeproj -scheme Unchair` |
| Check formatting | `swiftformat --lint .` |
| Apply formatting | `swiftformat .` |
| Lint | `swiftlint --strict` |

## App icon

The icon is a layered Icon Composer file (`App/Resources/AppIcon.icon`), so macOS 26 can render it in the Default, Dark, Clear, and Tinted styles. Open it in Icon Composer to edit; the layers are plain SVGs in `Assets/`. Older macOS versions get a generated `.icns`.

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

## License

Unchair is available under the [MIT License](LICENSE).
