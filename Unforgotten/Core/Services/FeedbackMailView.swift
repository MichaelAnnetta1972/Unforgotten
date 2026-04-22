import SwiftUI
import MessageUI
import UIKit

// MARK: - Feedback Kind
enum FeedbackKind: String, Identifiable {
    case bugReport
    case generalFeedback

    var id: String { rawValue }

    var subject: String {
        switch self {
        case .bugReport: return "[Bug Report] Unforgotten"
        case .generalFeedback: return "[Feedback] Unforgotten"
        }
    }

    var bodyPrefix: String {
        switch self {
        case .bugReport:
            return "Please describe the bug you encountered, including the steps to reproduce it:\n\n\n\n"
        case .generalFeedback:
            return "We'd love to hear your thoughts, suggestions, or feedback:\n\n\n\n"
        }
    }
}

// MARK: - Device Info Builder
enum FeedbackDeviceInfo {
    /// Build a diagnostic footer appended to every feedback email so we can
    /// reproduce issues without having to ask the user for their setup.
    static func footer() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let iosVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        let deviceName = UIDevice.current.name

        return """

        ---
        Please do not delete the information below — it helps us investigate your report.

        App Version: \(appVersion) (\(buildNumber))
        iOS Version: \(iosVersion)
        Device: \(deviceModel) (\(deviceName))
        """
    }
}

// MARK: - Mail Composer (UIViewControllerRepresentable)
/// SwiftUI wrapper around MFMailComposeViewController.
/// Only present this when `MFMailComposeViewController.canSendMail()` is true —
/// otherwise fall back to a mailto: URL.
struct FeedbackMailView: UIViewControllerRepresentable {
    let kind: FeedbackKind
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([AppConfiguration.feedbackEmail])
        controller.setSubject(kind.subject)
        controller.setMessageBody(kind.bodyPrefix + FeedbackDeviceInfo.footer(), isHTML: false)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) { [weak self] in
                self?.onDismiss()
            }
        }
    }
}

// MARK: - Feedback Presenter
/// Helper that decides whether to show the in-app mail composer or fall back
/// to a mailto: URL when the device has no Mail account configured.
enum FeedbackPresenter {
    /// Returns true if we should present the in-app composer sheet.
    /// If false, caller should open `mailtoURL(for:)` instead.
    static func canSendInAppMail() -> Bool {
        MFMailComposeViewController.canSendMail()
    }

    /// Build a mailto: URL as a fallback for devices without Mail configured.
    static func mailtoURL(for kind: FeedbackKind) -> URL? {
        let subject = kind.subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = (kind.bodyPrefix + FeedbackDeviceInfo.footer())
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(AppConfiguration.feedbackEmail)?subject=\(subject)&body=\(body)")
    }

    /// Attempt to open the mailto: URL. If that fails too (no mail client at all),
    /// copies the feedback address to the clipboard so the user can paste it elsewhere.
    /// Returns true if some action was taken.
    @MainActor
    static func openMailtoFallback(for kind: FeedbackKind) -> Bool {
        guard let url = mailtoURL(for: kind) else {
            UIPasteboard.general.string = AppConfiguration.feedbackEmail
            return false
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        } else {
            UIPasteboard.general.string = AppConfiguration.feedbackEmail
            return false
        }
    }
}
