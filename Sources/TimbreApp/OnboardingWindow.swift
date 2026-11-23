// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import TimbreCore
import TimbreDesignSystem

public enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case promise = 1
    case permissions = 2
    case ready = 3

    public var id: Int { rawValue }
}

public struct OnboardingWindow: View {
    @ObservedObject var appState: AppState
    @State private var step: OnboardingStep = {
        // Design review: `--onboarding-step 2` opens straight on that step.
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "--onboarding-step"), i + 1 < a.count, let n = Int(a[i + 1]), let s = OnboardingStep(rawValue: n) { return s }
        return .welcome
    }()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(appState: AppState) {
        self.appState = appState
    }

    private var colors: TimbreColors { .dark }

    /// Tall enough for the permissions step (three cards + hint) without scrolling at default text size.
    public static let windowHeight: CGFloat = 640

    public var body: some View {
        ZStack {
            colors.bg_canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, TimbreSpacing.s8)
                    .padding(.top, TimbreSpacing.s8)

                // The footer is pinned; only the step scrolls. A longer language (ES/PT) or a taller
                // step can never push "Voltar / Continuar" out of the window.
                ScrollView(.vertical, showsIndicators: false) {
                    stepContent
                        .padding(.horizontal, TimbreSpacing.s8)
                        .padding(.vertical, TimbreSpacing.s6)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
                    .padding(.horizontal, TimbreSpacing.s8)
                    .padding(.bottom, TimbreSpacing.s8)
            }
        }
        .frame(width: 720, height: OnboardingWindow.windowHeight)
        .tint(colors.accent_base)
        .surface(.dark)
        .preferredColorScheme(.dark)
    }


    private var header: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s3) {
            Text(appState.t("app.name"))
                .type(TimbreTypography.heroTitle)
                .foregroundStyle(colors.ink_primary)
                .accessibilityAddTraits(.isHeader)

            Text(appState.t("onboard.kicker").uppercased())
                .type(TimbreTypography.eyebrow)
                .foregroundStyle(colors.ink_muted)
                .tracking(1.2)

            stepIndicator
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: TimbreSpacing.s2) {
            ForEach(OnboardingStep.allCases) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? colors.accent_base : colors.line_strong)
                    .frame(width: s == step ? 28 : 10, height: 4)
                    .animation(reduceMotion ? nil : TimbreMotion.snappy, value: step)
                    .accessibilityLabel(stepLabel(s))
            }
        }
        .padding(.top, TimbreSpacing.s2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .promise:
            promiseStep
        case .permissions:
            permissionsStep
        case .ready:
            readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s5) {
            Text(appState.t("onboard.welcome.title"))
                .type(TimbreTypography.displayValue)
                .foregroundStyle(colors.ink_primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(appState.t("onboard.welcome.body"))
                .type(TimbreTypography.prose)
                .foregroundStyle(colors.ink_secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 480, alignment: .leading)

            VStack(alignment: .leading, spacing: TimbreSpacing.s2) {
                Text(appState.t("onboard.language"))
                    .type(TimbreTypography.caption)
                    .foregroundStyle(colors.ink_muted)
                TSegmented(options: TimbreLanguage.allCases.map { ($0, $0.displayName) }, selection: $appState.language)
            }
            .padding(.top, TimbreSpacing.s2)
        }
        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private var promiseStep: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s5) {
            Text(appState.t("onboard.promise.title"))
                .type(TimbreTypography.cardTitle)
                .foregroundStyle(colors.ink_primary)

            promiseRow(symbol: "lock.shield", text: appState.t("onboard.promise.local"))
            promiseRow(symbol: "arrow.uturn.backward", text: appState.t("onboard.promise.trace"))
            promiseRow(symbol: "checkmark.seal", text: appState.t("onboard.promise.honest"))
        }
        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s4) {
            Text(appState.t("onboard.permissions.title"))
                .type(TimbreTypography.cardTitle)
                .foregroundStyle(colors.ink_primary)

            Text(appState.t("onboard.permissions.body"))
                .type(TimbreTypography.prose)
                .foregroundStyle(colors.ink_secondary)
                .fixedSize(horizontal: false, vertical: true)

            permissionCard(
                title: appState.t("tcc.audio.title"),
                detail: appState.t("tcc.audio.why"),
                status: appState.t("tcc.status.pending"),
                required: true,
                pane: "audio"
            )
            permissionCard(
                title: appState.t("tcc.ax.title"),
                detail: appState.t("tcc.ax.why"),
                status: appState.accessibilityGranted ? appState.t("tcc.status.ok") : appState.t("tcc.status.optional"),
                required: false,
                pane: "accessibility"
            )
            permissionCard(
                title: appState.t("tcc.bt.title"),
                detail: appState.t("tcc.bt.why"),
                status: appState.t("tcc.status.optional"),
                required: false,
                pane: "bluetooth"
            )

            Text(appState.t("onboard.permissions.later"))
                .type(TimbreTypography.caption)
                .foregroundStyle(colors.ink_muted)
        }
        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s5) {
            Text(appState.t("onboard.ready.title"))
                .type(TimbreTypography.cardTitle)
                .foregroundStyle(colors.ink_primary)

            Text(appState.t("onboard.ready.body"))
                .type(TimbreTypography.prose)
                .foregroundStyle(colors.ink_secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520, alignment: .leading)

            Text(appState.t("onboard.ready.hint"))
                .type(TimbreTypography.monoValue)
                .foregroundStyle(colors.ink_muted)
        }
        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private var footer: some View {
        HStack(spacing: TimbreSpacing.s3) {
            if step != .welcome {
                Button(appState.t("onboard.back")) {
                    withAnimation(reduceMotion ? nil : TimbreMotion.standard) {
                        step = OnboardingStep(rawValue: step.rawValue - 1) ?? .welcome
                    }
                }
                .buttonStyle(.t(.secondary))
            }

            Spacer()

            switch step {
            case .welcome, .promise:
                Button(appState.t("onboard.next")) {
                    withAnimation(reduceMotion ? nil : TimbreMotion.enter) {
                        step = OnboardingStep(rawValue: step.rawValue + 1) ?? .ready
                    }
                }
                .buttonStyle(.t(.primary))
                .keyboardShortcut(.defaultAction)

            case .permissions:
                Button(appState.t("onboard.skip_perms")) {
                    withAnimation(reduceMotion ? nil : TimbreMotion.enter) {
                        step = .ready
                    }
                }
                .buttonStyle(.t(.secondary))
                Button(appState.t("onboard.next")) {
                    withAnimation(reduceMotion ? nil : TimbreMotion.enter) {
                        step = .ready
                    }
                }
                .buttonStyle(.t(.primary))
                .keyboardShortcut(.defaultAction)

            case .ready:
                Button(appState.t("onboard.finish_menubar")) {
                    appState.completeOnboarding(openStudio: false)
                }
                .buttonStyle(.t(.secondary))
                Button(appState.t("onboard.open_studio")) {
                    appState.completeOnboarding(openStudio: true)
                }
                .buttonStyle(.t(.primary))
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func promiseRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: TimbreSpacing.s3) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(colors.accent_strong)
                .frame(width: 28, height: 28)
                .background(colors.accent_subtle)
                .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous))
            Text(text)
                .type(TimbreTypography.prose)
                .foregroundStyle(colors.ink_secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func permissionCard(title: String, detail: String, status: String, required: Bool, pane: String) -> some View {
        HStack(alignment: .top, spacing: TimbreSpacing.s3) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: TimbreSpacing.s2) {
                    Text(title)
                        .type(TimbreTypography.body)
                        .foregroundStyle(colors.ink_primary)
                    Text(status)
                        .type(TimbreTypography.micro)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background((required ? colors.semantic_warning : colors.semantic_info).opacity(0.16))
                        .foregroundStyle(required ? colors.semantic_warning : colors.semantic_info)
                        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.badge))
                }
                Text(detail)
                    .type(TimbreTypography.caption)
                    .foregroundStyle(colors.ink_muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: TimbreSpacing.s3)
            Button(appState.t("tcc.open_settings")) {
                appState.openSystemSettingsTCC(pane)
                if pane == "accessibility" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        appState.setupMediaKeysIfGranted()
                    }
                }
            }
            .buttonStyle(.t(.secondary))
        }
        .padding(TimbreSpacing.s3)
        .background(colors.bg_surface)
        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous)
                .stroke(colors.line_default, lineWidth: 1)
        )
    }

    private func stepLabel(_ s: OnboardingStep) -> String {
        switch s {
        case .welcome: return appState.t("onboard.step.welcome")
        case .promise: return appState.t("onboard.step.promise")
        case .permissions: return appState.t("onboard.step.permissions")
        case .ready: return appState.t("onboard.step.ready")
        }
    }
}
