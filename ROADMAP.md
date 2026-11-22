# Unchair — Roadmap

> A native macOS companion for people who work or study at a computer: focus sessions, sit/stand alternation, hydration, eye breaks, and gentle movement reminders — without becoming one more thing that nags you.

## Vision

Unchair helps you keep a healthy rhythm at the desk. It lives in the menu bar, feels like part of macOS, and is smart about *when* to interrupt: never during a call, a presentation, or deep focus, and never with three reminders at once.

**Launch target:** macOS, in English, Spanish, and Portuguese (Brazil).
**Later:** Windows and Linux, reusing the core logic.

## Product principles

1. **Native first.** SwiftUI, system materials, SF Symbols, standard settings window, system notifications. No custom chrome imitating macOS.
2. **Respect attention.** Every reminder can be snoozed or skipped. Reminders are coalesced. Unchair pauses itself when you are away, presenting, or in a meeting.
3. **Sensible defaults, everything configurable.** Defaults come from the available evidence (see below), and users can change them all.
4. **Private by default.** All data stays on-device. No account, no analytics unless opt-in.
5. **Portable core.** Business logic lives in a pure Swift package with no UI or platform imports, so it can be reused on other platforms.

## Tech stack

| Area | Choice |
|---|---|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI, AppKit only where needed |
| Minimum OS | macOS 14 Sonoma (adopt macOS 26 Liquid Glass behind availability checks) |
| Menu bar | `MenuBarExtra` (window style) |
| Notifications | `UserNotifications` with actionable categories |
| Persistence | `UserDefaults` for settings, SwiftData for history |
| Charts | Swift Charts |
| System integration | App Intents (Shortcuts, Focus filters), WidgetKit, `SMAppService` (launch at login) |
| Localization | String Catalogs (`.xcstrings`): `en` (source), `es`, `pt-BR` |
| Tests | Swift Testing for `UnchairCore`, XCTest UI tests for critical flows |
| CI | GitHub Actions (build + test on macOS runner) |

### Architecture

```
Unchair/
├── Unchair.xcodeproj
├── App/                      # macOS app target (SwiftUI, AppKit glue)
│   ├── MenuBar/
│   ├── Settings/
│   ├── Notifications/        # UNUserNotificationCenter adapter
│   ├── SystemSignals/        # idle, sleep/wake, fullscreen, mic/camera, Focus
│   └── Resources/Localizable.xcstrings
├── Packages/
│   └── UnchairCore/          # Pure Swift — no SwiftUI/AppKit imports
│       ├── Timers/           # Pomodoro, Flowtime state machines
│       ├── Reminders/        # Sit/stand, water, eyes, stretch, posture
│       ├── Scheduler/        # Coalescing, quiet rules, snooze
│       ├── Clock/            # WallClock, SystemClock, TestClock
│       └── Stats/            # Aggregation models
├── Widgets/                  # WidgetKit extension
└── Intents/                  # App Intents (can live in the app target)
```

**Key design rule:** `UnchairCore` takes an injectable `WallClock` and a `SystemState` input (idle, in-meeting, fullscreen, Focus active) and outputs *events* (“show water reminder”, “start break”). The app layer turns events into notifications and UI. This keeps the core fully unit-testable and portable.

## Evidence-based defaults

| Feature | Default | Rationale |
|---|---|---|
| Pomodoro | 25 min focus / 5 min break, 15–20 min long break every 4 cycles | Familiar classic. Research supports regular breaks but finds nothing special about 25 min, so presets (25/5, 50/10, 90/20) and custom values are provided. |
| Flowtime mode | Break = ~20% of focus time | Self-paced breaks performed comparably in recent studies; good for deep work. |
| Sit/stand | 45 min sitting / 15 min standing | Recommendations range from 5–20 min/hour to 30–45 min/hour standing. Prolonged standing (2h+) caused low back pain in lab studies, so the goal is *alternating*, not maximizing standing. |
| Sit/stand sync | On | Posture switches happen at Pomodoro boundaries so they don't break focus. |
| Water | Reminder every 60 min, daily goal 2.0 L (configurable) | No evidence-based interval exists. EFSA reference: ~2.0 L/day (women) and ~2.5 L/day (men) total water intake, including food. |
| Eye breaks (20-20-20) | **Off** by default, or merged into Pomodoro breaks | Evidence is mixed (one small study found no effect, another found short-term relief). Cheap and commonly requested, but adds notification load. |
| Stretch / mobility | Suggested during long breaks | Low cost, fits naturally into existing breaks. |

---

## Phases

### Phase 0 — Foundations ✅

Goal: a skeleton that builds, tests, and localizes from day one.

- [x] Create Xcode project `Unchair` (macOS app, SwiftUI lifecycle, menu bar–only via `LSUIElement`)
- [x] Create local Swift package `UnchairCore` and link it to the app
- [x] Injectable `WallClock` protocol + `TestClock`
- [x] `Localizable.xcstrings` with `en`, `es`, `pt-BR` added (English as source; all UI strings via `String(localized:)` / `LocalizedStringKey`)
- [x] App icon placeholder, bundle ID, signing set up
- [x] SwiftLint/SwiftFormat config
- [x] GitHub Actions: build + run `UnchairCore` tests
- [x] `README.md` with build instructions

**Done when:** an empty menu bar item appears, the core package has a passing test, and CI is green.

### Phase 1 — MVP: Focus + Posture + Water ✅ *(pending: full-workday dogfooding)*

Goal: something you can use every day yourself.

- [x] **Pomodoro engine** in `UnchairCore`: states (idle, focus, short break, long break, paused), cycle counting, presets, custom durations
- [x] **Menu bar UI:** remaining time in the menu bar (optional), start/pause/skip/reset, current phase
- [x] **Notifications:** request permission, phase-change notifications with actions (*Start break*, *Skip*, *+5 min*)
- [x] **Sit/stand reminders:** configurable sit and stand durations, sync-with-Pomodoro option, *Done* / *Snooze* actions
- [x] **Water reminders:** interval, daily goal, *I drank* action logs a glass (configurable glass size)
- [x] **Settings window** (`Settings` scene): General, Focus, Posture, Hydration tabs
- [x] **Launch at login** via `SMAppService`
- [x] Persist settings and today's water log in `UserDefaults` (JSON-encoded `UnchairSettings`)
- [x] Unit tests for all state machines (transitions, pause/resume, skips, day rollover)

**Done when:** you run Unchair for a full workday without needing to touch the code.

### Phase 2 — Smart interruptions ✅ *(pending: a day full of calls)*

Goal: the app knows when *not* to bother you. This is the main differentiator.

- [x] **Reminder scheduler** with coalescing: reminders due within a window are merged into one notification
- [x] **Global snooze / quiet mode** (“Pause reminders for 30 min / 1 h / until tomorrow”)
- [x] **Idle detection:** pause timers after N minutes without input (`CGEventSource.secondsSinceLastEventType`), resume or reset on return; treat being away as a natural break
- [x] **Sleep/wake and screen lock handling** (`NSWorkspace` notifications)
- [x] **Meeting detection:** defer reminders while microphone/camera is in use (per-process CoreAudio input state on macOS 14.2+, device fallback; CoreMediaIO for the camera) — *works in the sandbox; the camera needs the camera entitlement, which doesn't capture anything*
- [x] **Fullscreen / presentation detection:** defer reminders when the frontmost app is fullscreen — *uses window bounds and owner only, which need no Screen Recording permission*
- [x] **Focus filter** (`SetFocusFilterIntent`): users choose what Unchair does per Focus mode
- [x] **Working hours:** reminders only on chosen days and hours

**Known limitations / follow-ups**

- [ ] Watching a video without touching the keyboard counts as being away. Detect display-sleep assertions (`IOPMCopyAssertionsByProcess`) to treat media playback as presence.
- [ ] Full screen detection is only verified to build; test it with Keynote, browsers, and video players.
- [ ] Optionally re-remind once if a suggestion is ignored for a long time.

**Done when:** a day full of calls produces zero badly timed reminders.

### Phase 3 — More wellbeing ✅

- [x] **Eye breaks (20-20-20)**, off by default, with an option to merge into Pomodoro breaks
- [x] **Stretch suggestions** during long breaks (small curated set, localized, with SF Symbols or simple illustrations)
- [x] **Posture check** — gentle, widely spaced reminder
- [x] **End-of-day wrap-up:** notification at the end of working hours with a summary (focus sessions, standing time, water)
- [x] **Optional full-screen break overlay** for users who want to be forced to stop (skippable, accessible)
- [x] Custom notification sounds (subtle, system-like)

### Phase 4 — Insights & system integration ✅ *(widgets need a developer team for live data)*

- [x] **History** with SwiftData: focus sessions, posture switches, water intake, skipped/snoozed reminders
- [x] **Stats view** with Swift Charts: daily/weekly focus time, standing time, hydration goal progress, streaks
- [x] **Widgets** (WidgetKit): current timer, today's progress (desktop and Notification Center) — *live data needs the App Group, which needs a developer team; see `Config/README.md`*
- [x] **App Intents / Shortcuts:** *Start focus*, *Start break*, *Log water*, *Pause reminders*, *Get today's stats*
- [x] **Keyboard shortcut** to start/pause from anywhere (Carbon hot key, no Accessibility permission; ⌃⌥⌘P by default)
- [x] Data export (CSV/JSON)

**Follow-ups from Phases 3–4**

- [x] A custom shortcut recorder instead of a fixed list of combinations
- [x] Eye break and posture check rows in the menu bar panel
- Interactive widget buttons and end-to-end widget testing moved to *Needs an Apple Developer account* below

### Phase 5 — Launch (v1.0)

- [ ] **Onboarding:** 3–4 screens: what Unchair does, notification permission, pick a preset (Student / Office / Deep work), launch at login
- [ ] **Full localization:** review every string in `es` and `pt-BR` with native speakers; check truncation in all three languages; localize App Store metadata and screenshots
- [ ] **Accessibility:** VoiceOver labels, Dynamic Type where applicable, Reduce Motion, sufficient contrast, full keyboard navigation
- [ ] **Distribution decision** (see open questions): App Store (sandboxed) and/or Developer ID + notarization + Sparkle updates
- [ ] Privacy policy (data stays on device), App Store privacy labels
- [ ] Landing page (EN/ES/PT), support email, feedback channel
- [ ] Crash reporting (opt-in or Xcode Organizer only)
- [ ] TestFlight beta → feedback round → 1.0 release

### Phase 6 — Beyond macOS (exploratory)

- [ ] Confirm `UnchairCore` builds on Linux and Windows (Swift toolchain) in CI
- [ ] Evaluate UI options per platform (native Windows UI, GTK on Linux, or a shared web-based UI using the core via a C/FFI layer)
- [ ] Map platform equivalents: tray icon, notifications, idle detection, Focus Assist / Do Not Disturb
- [ ] Optional sync between devices (iCloud on Apple platforms first)

---

## Needs an Apple Developer account *(do last)*

These depend on signing with a team (US$ 99/year). Until then, Unchair is shared as a free, ad-hoc signed beta.

- [ ] Set `DEVELOPMENT_TEAM` (the App Group turns on automatically, see `Config/README.md`)
- [ ] Test widgets end to end with live data
- [ ] Interactive widget buttons (start/pause, log water) through App Intents, signaling the app through the App Group
- [ ] Developer ID signing and notarization for public downloads
- [ ] Optional: App Store build (without Sparkle)

## What to build first (concrete order)

1. Phase 0 skeleton + CI
2. Pomodoro state machine in `UnchairCore` with tests
3. Menu bar UI driving the Pomodoro engine
4. Notifications with actions
5. Sit/stand reminders synced to Pomodoro
6. Water reminders + daily goal
7. Settings window
8. Reminder coalescing + idle detection (the first “smart” features — the earlier the better, because they shape the scheduler design)

Use it daily from step 4 onward. Your own annoyance is the best backlog.

## Open questions

- **Distribution:** App Store only, direct download only, or both? The App Store sandbox may limit meeting/fullscreen detection, so check these APIs early (Phase 2 spike).
- **Business model:** free, paid upfront, or freemium (e.g., stats/widgets as Pro)?
- **Minimum macOS version:** 14 is assumed; raising it to 15 or 26 simplifies the code but shrinks the audience.
- **Menu bar–only vs. Dock icon:** default to menu bar only, with an optional Dock icon setting?
- **Sound and haptics:** which sounds, and should there be a “silent” visual-only mode?

## Success metrics (post-launch)

- Day-7 and day-30 retention
- % of reminders acted on vs. snoozed/skipped (high skip rate = too noisy)
- % of users who disable a reminder type entirely
- App Store rating and review themes per language
