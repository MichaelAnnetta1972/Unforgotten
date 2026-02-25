import UIKit
import UserNotifications
import UserNotificationsUI
import SwiftUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    private var hostingController: UIHostingController<NotificationContentView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content

        let data = NotificationData(
            category: content.categoryIdentifier,
            title: content.title,
            body: content.body,
            userInfo: content.userInfo
        )

        let contentView = NotificationContentView(data: data)

        // Remove previous hosting controller if re-receiving
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        let hosting = UIHostingController(rootView: contentView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        // Add tap gesture to open the app
        let tap = UITapGestureRecognizer(target: self, action: #selector(openApp))
        view.addGestureRecognizer(tap)

        // Inset the hosting view so content isn't clipped at edges
        let horizontalInset: CGFloat = 12
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalInset),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalInset),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController = hosting

        // Calculate preferred content size from SwiftUI layout
        let availableWidth = view.bounds.width - (horizontalInset * 2)
        let targetSize = hosting.view.systemLayoutSizeFitting(
            CGSize(width: availableWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        preferredContentSize = CGSize(width: view.bounds.width, height: targetSize.height)
    }

    @objc private func openApp() {
        extensionContext?.performNotificationDefaultAction()
    }

    func didReceive(
        _ response: UNNotificationResponse,
        completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void
    ) {
        // Forward all actions to the main app's notification handler
        completion(.dismissAndForwardAction)
    }
}
