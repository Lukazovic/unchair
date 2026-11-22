import SwiftUI
import UnchairCore
import UserNotifications

/// First-launch walkthrough: what Unchair does, notification permission, a
/// starting profile, and launch at login.
struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case welcome
        case notifications
        case profile
        case finish
    }

    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .welcome
    @State private var profile: UsageProfile = .student
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var launchAtLogin = true

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .notifications: notifications
                case .profile: profilePicker
                case .finish: finish
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(32)
            .transition(reduceMotion ? .opacity : .push(from: .trailing))

            Divider()

            HStack {
                PageDots(count: Step.allCases.count, current: step.rawValue)
                Spacer()
                if step != .welcome {
                    Button("Back") { go(to: step.rawValue - 1) }
                }
                Button(step == .finish ? "Start Using Unchair" : "Continue", action: advance)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 520, height: 500)
        .task {
            notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Welcome to Unchair")
                .font(.largeTitle.weight(.semibold))
            Text("A gentle companion for long days at the computer. It lives in your menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                Feature(symbol: "timer", title: "Focus sessions", detail: "Pomodoro timer with breaks that fit you.")
                Feature(
                    symbol: "figure.stand",
                    title: "Sit and stand",
                    detail: "Reminders to alternate, timed with your breaks."
                )
                Feature(symbol: "drop.fill", title: "Water and eyes", detail: "Hydration goal and 20-20-20 eye breaks.")
                Feature(
                    symbol: "bell.slash",
                    title: "Never during calls",
                    detail: "Reminders wait while you're in a call or presenting."
                )
            }
            .padding(.top, 8)
        }
    }

    private var notifications: some View {
        VStack(spacing: 18) {
            StepIcon(symbol: "bell.badge")
            Text("Allow notifications")
                .font(.title.weight(.semibold))
            Text(Copy.onboardingNotifications)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            switch notificationStatus {
            case .authorized, .provisional, .ephemeral:
                Label("Notifications are on", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied:
                VStack(spacing: 8) {
                    Text("Notifications are turned off for Unchair.")
                        .foregroundStyle(.secondary)
                    Button("Open Notification Settings…") {
                        if let url =
                            URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
                        {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            default:
                Button("Allow Notifications") {
                    Task {
                        _ = await model.requestNotificationPermission()
                        notificationStatus = await UNUserNotificationCenter.current()
                            .notificationSettings().authorizationStatus
                    }
                }
                .controlSize(.large)
            }
        }
    }

    private var profilePicker: some View {
        VStack(spacing: 18) {
            Text("How do you work?")
                .font(.title.weight(.semibold))
            Text("Pick a starting point. You can fine-tune everything later in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(UsageProfile.allCases) { option in
                    ProfileCard(profile: option, isSelected: option == profile) {
                        profile = option
                    }
                }
            }
        }
    }

    private var finish: some View {
        VStack(spacing: 18) {
            StepIcon(symbol: "checkmark.seal")
            Text("You're all set")
                .font(.title.weight(.semibold))
            Text("Find Unchair in the menu bar, next to the clock.")
                .foregroundStyle(.secondary)

            Form {
                Toggle("Launch Unchair at login", isOn: $launchAtLogin)
                if let shortcut = model.globalShortcut {
                    LabeledContent("Start or pause focus from anywhere") {
                        Text(verbatim: shortcut.symbols)
                            .monospaced()
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: 120)
        }
    }

    // MARK: - Navigation

    private func advance() {
        if step == .finish {
            model.completeOnboarding(profile: profile)
            if launchAtLogin != LaunchAtLogin.isEnabled {
                try? LaunchAtLogin.setEnabled(launchAtLogin)
            }
            dismiss()
        } else {
            go(to: step.rawValue + 1)
        }
    }

    private func go(to index: Int) {
        guard let next = Step(rawValue: index) else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            step = next
        }
    }
}

// MARK: - Components

private struct Feature: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StepIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 52, weight: .light))
            .foregroundStyle(.tint)
            .frame(height: 72)
            .accessibilityHidden(true)
    }
}

private struct ProfileCard: View {
    let profile: UsageProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: profile.symbolName)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.title).font(.headline)
                    Text(profile.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .padding(12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.quaternary.opacity(0.5)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { index in
                Circle()
                    .fill(index == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(current + 1) of \(count)"))
    }
}

extension UsageProfile {
    var title: LocalizedStringKey {
        switch self {
        case .student: "Student"
        case .office: "Office"
        case .deepWork: "Deep Work"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .student: "25-minute sessions, eye breaks, and frequent water."
        case .office: "50-minute sessions on weekdays from 9 to 6, with posture checks."
        case .deepWork: "90-minute sessions and fewer, combined interruptions."
        }
    }

    var symbolName: String {
        switch self {
        case .student: "graduationcap"
        case .office: "briefcase"
        case .deepWork: "brain.head.profile"
        }
    }
}
